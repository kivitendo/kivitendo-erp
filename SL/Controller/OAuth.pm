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


sub imap_sasl_string {
  my ($self, $db_id) = @_;

  my $tok = SL::DB::OAuthToken->new(id => $db_id)->load();

  if (!$tok->is_valid) {
    refresh($tok);
  }

  my $username = $tok->email();
  my $access_token = $tok->access_token();

  my $oauth_sign = encode_base64("user=". $username ."\x01auth=Bearer ". $access_token ."\x01\x01", '');

  return $oauth_sign;
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

  $tok = SL::DB::Manager::OAuthToken->find_by(tokenstate => undef, registration => $target, employee_id => SL::DB::Manager::Employee->current->id)
    if ($params{allow_current_user});

  $tok = SL::DB::Manager::OAuthToken->find_by(tokenstate => undef, registration => $target, employee_id => undef)
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

SL::Controller::OAuth - OAuth2


Token, für die der interaktive Flow vollständig durchlaufen sind, haben den tokenstate NULL.


data model and control flow by Alexander Perlis Mutt OAuth2 token management script




use SL::Controller::OAuth;
use Mail::IMAPClient;

my $username = 'kivitendo.test@your.domain';

my $imap = Mail::IMAPClient->new(
  Server   => 'mail.domain',
  User     => $username,
  Ssl      => 1,
  Uid      => 1,
) or die "Cannot connect $@";

$imap->authenticate('XOAUTH2', sub { return SL::Controller::OAuth->imap_sasl_string(4); }) or die("Auth error: ". $imap->LastError);

my $folders = $imap->folders or die "List folders error: ", $imap->LastError, "\n";

print "Folders: @$folders\n";
Folders: Archiv Aufgaben Entw&APw-rfe Gel&APY-schte Elemente Gesendete Elemente Journal Junk-E-Mail Kalender Kalender/Feiertage in Deutschland Kalender/Geburtstage Kontakte Notizen Postausgang INBOX Trash Verlauf der Unterhaltung
