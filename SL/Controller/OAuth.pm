package SL::Controller::OAuth;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::OAuthToken;
use SL::Helper::Flash;
use SL::JSON;
use SL::Locale::String;
use SL::Controller::OAuth::Microsoft;
use SL::Controller::OAuth::Atlassian;
use SL::Controller::OAuth::GoogleCal;
use SL::Helper::Flash qw(flash_later);

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw(config) ],
);

my %providers = (
  microsoft      => 'SL::Controller::OAuth::Microsoft',
  atlassian_jira => 'SL::Controller::OAuth::Atlassian',
  google_cal     => 'SL::Controller::OAuth::GoogleCal',
);



sub refresh {
  my ($tok) = @_;
  my $provider = $providers{$tok->registration} or die "unknown provider";

  my $ret = $provider->refresh($tok);

  my $response_code = $ret->responseCode();
  die "Request failed, response code was: $response_code\n" . $ret->responseContent() unless $response_code eq '200';

  my $content = from_json($ret->responseContent());
  die "Server returned error_code $content->{error_code}" if exists $content->{error_code};

  $tok->set_access_refresh_token($content);
  $tok->save;
}



#
# actions
#

sub _fmt_token_code {
  my ($code) = @_;
  $code ? t8('#1 bytes', length($code)) : t8('is missing');
}

sub _fmt_employee {
  my ($id) = @_;
  my $e = SL::DB::Employee->new(id => $id)->load();

  $e->safe_name;
}

sub _token_is_editable {
  my ($tok) = @_;
  ($tok->employee_id == SL::DB::Manager::Employee->current->id) || $::auth->assert('admin', 'may_fail');
}

sub action_list {
  my ($self) = @_;

  my $now = DateTime->now;

  my @tokens = @{SL::DB::Manager::OAuthToken->get_all(sort_by => 'registration,id ASC')};
  @tokens = grep { _token_is_editable($_) } @tokens;
  @tokens = map { {
    id            => $_->id,
    provider      => $providers{$_->registration}->title,
    employee      => $_->employee_id && _fmt_employee($_->employee_id),
    email         => $_->email,
    tokenstate    => $_->tokenstate ? t8('waiting for auth code') : 'OK',
    access_token  => _fmt_token_code($_->access_token),
    refresh_token => _fmt_token_code($_->refresh_token),
    expiration    => $_->access_token_expiration ? $_->access_token_expiration->epoch - $now->epoch : '',
    scope         => $_->scope,
  } } @tokens;

  $self->setup_list_action_bar;
  $self->render('oauth/list',
                title    => t8('List of OAuth2 tokens'),
                TOKENS => \@tokens);
}

sub action_delete_token {
  my ($self) = @_;

  my $token = SL::DB::OAuthToken->new(id => $::form->{id})->load();
  die unless _token_is_editable($token);

  $token->delete;

  flash_later('info', t8('Token deleted'));
  $self->redirect_to(action => 'list');
}

sub action_new {
  my ($self) = @_;

  my $regtype = $::form->{oauth_type};

  $self->config({ registration => $::form->{oauth_type} });
  $self->setup_add_action_bar();
  $self->render('oauth/form', title => t8('Add new OAuth2 token'));
}

sub action_create {
  my ($self) = @_;

  my $regtype = $::form->{registration};
  my $provider = $providers{$regtype} or die "unknown provider";

  $self->config($::form->{config});
  my ($link, $tok) = $provider->create_authorization($self->config);

  if ($::form->{user_or_clientwide} eq 'user') {
    $tok->employee_id(SL::DB::Manager::Employee->current->id);
    die unless $tok->employee_id;
  } else {
    $::auth->assert('admin');
  }

  $self->{authorize_link} = $link;
  $tok->save;

  $self->render('oauth/forward', title => t8('Add new OAuth2 token'));
}


sub action_consume_authorization_code {
  my ($self) = @_;

  my $search_state = $::form->{state} or die 'Request has no state parameter';
  my $auth_code    = $::form->{code}  or die 'Request has no code parameter';

  my $tok = SL::DB::Manager::OAuthToken->find_by(tokenstate => $search_state) or die "no token with state $search_state";
  my $provider = $providers{$tok->registration} or die "unknown provider";

  my $ret = $provider->access_token($tok, $auth_code);

  my $response_code = $ret->responseCode();
  die "Request failed, response code was: $response_code\n" . $ret->responseContent() unless $response_code eq '200';

  my $content = from_json($ret->responseContent);

  die "Server returned error_code $content->{error_code}" if (exists $content->{error_code});

  $tok->set_access_refresh_token($content);
  $tok->tokenstate(undef);
  $tok->save;

  flash_later('info', t8('OAuth token received: #1, database ID #2', $tok->registration, $tok->id));
  $self->redirect_to(action => 'list');
}

sub setup_add_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
     action => [
        t8('Save'),
        submit    => [ '#form', { action => 'OAuth/create' } ],
        accesskey => 'enter',
      ],
    );
  }
}

sub setup_list_action_bar {
  my ($self) = @_;

  my @btns = map { (
    link => [
      t8('Add') . ': ' . $providers{$_}->title(),
      link => $self->url_for(action => 'new', oauth_type => $providers{$_}->type()),
    ]
  ) } sort(keys(%providers));

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(@btns);
  }
}


sub access_token_for {
  my ($target, %params) = @_;

  $params{allow_current_user} //= 1;
  $params{allow_client_wide}  //= 0;

  my $tok;

  $tok = SL::DB::Manager::OAuthToken->find_by(tokenstate => undef, registration => $target, email => $params{email}, employee_id => SL::DB::Manager::Employee->current->id)
    if ($params{allow_current_user});

  $tok = SL::DB::Manager::OAuthToken->find_by(tokenstate => undef, registration => $target, email => $params{email}, employee_id => undef)
    if (!$tok && $params{allow_client_wide});

  die 'no OAuth token' unless $tok;

  refresh($tok) unless $tok->is_valid();

  $tok->access_token;
  # wenn ja -> token
  # wenn expired -> try refresh und token
  # sonst: exception
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::Controller::OAuth - Client side OAuth2 token management

=head1 SYNOPSIS

  use Mail::IMAPClient;
  use SL::Controller::OAuth;

  sub oauth_imap_get_folders {

    my $server       = 'mail.domain';
    my $username     = 'kivitendo.test@your.domain';

    my $access_token = SL::Controller::OAuth::access_token_for('microsoft', allow_client_wide => 1, email => $username);

    my $sasl_string  = encode_base64("user=$username\x01auth=Bearer $access_token\x01\x01", '');

    my $imap = Mail::IMAPClient->new(
      Server   => $server,
      User     => $username,
      Ssl      => 1,
      Uid      => 1,
    ) or die "Cannot connect $@";

    $imap->authenticate('XOAUTH2', sub { return $sasl_string; }) or die('Auth error: ' . $imap->LastError);

    my @folders = @{$imap->folders or die 'List folders: ' . $imap->LastError};

    return \@folders;
  }

=head1 FUNCTIONS

=over 4

=item C<access_token_for>

This is a common function that retrieves an OAuth access token from the
database, refreshing it in the case it expired.  By default, the first
access token valid for the currently logged in user matching the given
target is returned.

=item C<action_consume_authorization_code>

This is the controller action that is invoked from the dispatcher, when an
OAuth2 provider redirects the user's web browser to the redirect_uri. In
this case, the authorization code is transferred in the query parameter
C<code>.

=back

=head1 TOKENSTATE

Each SL::DB::OAuthToken is in one of two distinct states: inflight
or complete.  When a user creates a new token, the token is first
stored in the database with a random C<tokenstate> value and a URL is
presented to the user in order to asynchronously perform a request to
the OAuth2 provider, retrieving an authentication code. Finally, using
the authentication code, an access token and optionally a refresh token
are retrieved from the provider.

This means that all tokens with a non-null C<tokenstate> are inflight
and conversely all tokens with a null/undef C<tokenstate> are completed.
Only completed tokens can be used for authentication.


=head1 LITERATURE

Alexander Perlis' Mutt OAuth2 token management script provides a rather
compact implementation in Python for fetching a single OAuth2 token
(no state parameter handling)


=head1 BUGS

When an OAuth2 provider redirects the user's web browser to our
dispatcher, the web browser does not send the session cookie as
sending the cookie would violate the SameSite=strict policy. The
user is asked to log in again and only then the controller action
C<action_consume_authorization_code> is called.  This works,
but can be unexpected for the user.

Possible solutions include:

1. Storing the session cookie just once, before redirecting to the OAuth2
provider, with SameSite=Lax.

2. Allowing unauthenticated (in the sense that no session cookie
is required) requests for just C<action_consume_authorization_code>,
processing and storing the token as implemented currently and then either
ending the request or clearing all form parameters and callbacks and
redirecting the user to us, now in compliance with the SameSite policy.
Care must be taken to prevent denial of service attacks by means of
guessing valid C<tokenstate> values of inflight tokens.

=head1 AUTHOR

Niklas Schmidt E<lt>niklas@kivitendo.deE<gt>

=cut
