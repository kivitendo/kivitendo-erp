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
use SL::OAuth;


#
# actions
#

sub action_list {
  my ($self) = @_;

  my $now = DateTime->now;

  my @tokens = @{SL::DB::Manager::OAuthToken->get_all(sort_by => 'registration,id ASC')};
  my @editable_tokens = map +{
    id            => $_->id,
    provider      => SL::OAuth::providers()->{$_->registration}->title,
    employee      => $_->employee ? $_->employee->safe_name : '',
    email         => $_->email,
    tokenstate    => $_->tokenstate ? t8('waiting for auth code') : 'OK',
    access_token  => _fmt_token_code($_->access_token),
    refresh_token => _fmt_token_code($_->refresh_token),
    expiration    => $_->access_token_expiration ? $_->access_token_expiration->epoch - $now->epoch : '',
  }, grep { $_->is_editable() } @tokens;

  $self->setup_list_action_bar;
  $self->render('oauth/list',
                title    => t8('List of OAuth2 tokens'),
                TOKENS => \@editable_tokens);
}

sub action_new {
  my ($self) = @_;

  $self->setup_add_action_bar();
  $self->render('oauth/form', title => t8('Add new OAuth2 token'), registration => $::form->{oauth_type} );
}

sub action_create {
  my ($self) = @_;

  my $regtype = $::form->{registration};
  my $provider = SL::OAuth::providers()->{$regtype} or die "unknown provider";

  my ($link, $tok) = $provider->create_authorization_url($::form->{config});

  if ($::form->{user_or_clientwide} eq 'user') {
    $tok->employee_id(SL::DB::Manager::Employee->current->id);
    die 'token has no employee_id, illegal state' unless $tok->employee_id;
  } else {
    $::auth->assert('admin');
  }

  $tok->save;

  return $self->redirect_to($link);
}

sub action_delete {
  my ($self) = @_;
  my $tok = $::form->{tok};
  my @token_ids_to_delete = map { $_->{id} } grep { $_->{delete} } @$tok;

  return $self->redirect_to(action => 'list') unless @token_ids_to_delete;

  my $tokens = SL::DB::Manager::OAuthToken->get_all(where => [ id => \@token_ids_to_delete ]);
  map {
    die 'token is not editable' unless $_->is_editable();
    $_->delete();
  } @$tokens;

  flash_later('info', t8('#1 OAuth tokens deleted', scalar(@$tokens)));
  $self->redirect_to(action => 'list');
}

sub action_consume_authorization_code {
  my ($self) = @_;

  my $search_state = $::form->{state} or die 'Request has no state parameter';
  my $auth_code    = $::form->{code}  or die 'Request has no code parameter';

  my $tok = SL::DB::Manager::OAuthToken->find_by(tokenstate => $search_state) or die "no token with state $search_state";
  my $provider = SL::OAuth::providers()->{$tok->registration} or die "unknown provider";

  my $ret = $provider->access_token($tok, $auth_code);

  my $response_code = $ret->responseCode();
  die "Request failed, response code was: $response_code" unless $response_code == 200;

  my $content = from_json($ret->responseContent);

  die "Server returned error_code $content->{error_code}" if (exists $content->{error_code});

  $tok->set_access_refresh_token($content);
  $tok->tokenstate(undef);
  $tok->save;

  flash_later('info', t8('OAuth token received: #1, database ID #2', $tok->registration, $tok->id));
  $self->redirect_to(action => 'list');
}


#
# helpers
#

sub _fmt_token_code {
  my ($code) = @_;
  $code ? t8('#1 bytes', length($code)) : t8('is missing');
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

  my $providers = SL::OAuth::configured_providers();
  my @btns = map { (
    link => [
      t8('Add') . ': ' . $providers->{$_}->title(),
      link => $self->url_for(action => 'new', oauth_type => $providers->{$_}->type()),
    ]
  ) } sort(keys(%$providers));

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Delete'),
        submit   => [ '#form', { action => "OAuth/delete" } ],
        confirm  => t8('Do you really want to delete this object?'),
      ],

      'separator',

      @btns);
  }
}


1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::Controller::OAuth - Client side OAuth2 token management

=head1 FUNCTIONS

=over 4

=item C<action_consume_authorization_code>

This is the controller action that is invoked from the dispatcher, when an
OAuth2 provider redirects the user's web browser to the redirect_uri. In
this case, the authorization code is transferred in the query parameter
C<code>.

=back

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
