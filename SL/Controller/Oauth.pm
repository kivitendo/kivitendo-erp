package SL::Controller::Oauth;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::OauthToken;
use SL::Helper::Flash;
use SL::JSON;
use SL::Locale::String;
use SL::Controller::OAuth::Microsoft;
use SL::Controller::OAuth::Atlassian;

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw(config) ],
);

__PACKAGE__->run_before('check_auth');

my %providers = (
  microsoft      => 'SL::Controller::OAuth::Microsoft',
  atlassian_jira => 'SL::Controller::OAuth::Atlassian',
);


sub load_credentials {
  my ($regtype) = @_;

  my %reg;

  my $conf = $::lx_office_conf{"oauth2_$regtype"} or
    die t8('Missing configuration section "oauth_#1" in "config/kivitendo.conf"', $regtype);

  $reg{$_} = $conf->{$_} for qw(client_id client_secret scope redirect_uri);

  # TODO: load client_id, client_secret, tenant etc for this
  \%reg;
}

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

  my $tok = SL::DB::Manager::OauthToken->find_by(id => $db_id);

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

sub action_list {
  my ($self) = @_;

  my $now = DateTime->now;

  my @tokens = map({ {
    id            => $_->id,
    registration  => $_->registration,
    scope         => $_->scope,
    email         => $_->email,
    tokenstate    => $_->tokenstate ? 'waiting for auth code' : 'OK',
    access_token  => $_->access_token ? (length($_->access_token) . ' bytes') : 'missing',
    refresh_token => $_->refresh_token ? (length($_->refresh_token) . ' bytes') : 'missing',
    expiration    => $_->access_token_expiration ? $_->access_token_expiration->epoch - $now->epoch : '',
  } } @{SL::DB::Manager::OauthToken->get_all()});

  $self->setup_list_action_bar;
  $self->render('oauth/list',
                title    => t8('List of OAuth2 tokens'),
                TOKENS => \@tokens);
}

sub action_new {
  my ($self) = @_;

  my $regtype = $::form->{oauth_type};
  my $reg = load_credentials($regtype);

  $self->config(SL::DB::OauthToken->new());
  $self->config->{registration} = $::form->{oauth_type};
  $self->config->{$_} = $reg->{$_} for qw(client_id client_secret scope redirect_uri);
  $self->setup_add_action_bar();
  $self->render('oauth/form', title => 'Add new OAuth2 token');
}

sub action_create {
  my ($self) = @_;

  my $regtype = $::form->{registration};
  my $provider = $providers{$regtype} or die "unknown provider";

  $self->config($::form->{config});
  my ($link, $tok) = $provider->create_authorization($self->config);

  $self->{authorize_link} = $link;
  $tok->save;

  $self->render('oauth/forward', title => 'Add new OAuth2 token');
}


sub action_consume_authorization_code {
  my ($self) = @_;

  my $search_state = $::form->{state};
  my $tok = SL::DB::Manager::OauthToken->find_by(tokenstate => $search_state) or die "no token with state $search_state";
  my $provider = $providers{$tok->registration} or die "unknown provider";

  $self->config($tok);
  $self->config->{email} = $tok->email;

  my $ret = $provider->access_token($tok, $::form->{code});

  my $response_code = $ret->responseCode();
  die "Request failed, response code was: $response_code\n" . $ret->responseContent() unless $response_code eq '200';

  my $content = from_json($ret->responseContent);

  die "Server returned error_code $content->{error_code}" if (exists $content->{error_code});

  $tok->set_access_refresh_token($content);
  $tok->tokenstate(undef);
  $tok->save;

  $self->config->{message} = 'Token received: database ID ' . $tok->id;
  $self->render('oauth/form', title => 'Add new OAuth2 token');
}

#
# filters
#

sub check_auth {
  $::auth->assert('config');
}


sub setup_add_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
     action => [
        t8('Save'),
        submit    => [ '#form', { action => 'Oauth/create' } ],
        accesskey => 'enter',
      ],
    );
  }
}

sub setup_list_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      link => [
        t8('Add') . ': Atlassian Jira',
        link => $self->url_for(action => 'new', oauth_type => 'atlassian_jira'),
      ],

      link => [
        t8('Add') . ': Microsoft E-Mail',
        link => $self->url_for(action => 'new', oauth_type => 'microsoft'),
      ],
    );
  }
}


sub access_token_for {
  my ($target) = @_;

  # wenn ja -> token
  # wenn expired -> try refresh und token
  # sonst: exception
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::Controller::Oauth - OAuth2

data model and control flow by Alexander Perlis Mutt OAuth2 token management script




use SL::Controller::Oauth;
use Mail::IMAPClient;

my $username = 'kivitendo.test@your.domain';

my $imap = Mail::IMAPClient->new(
  Server   => 'mail.domain',
  User     => $username,
  Ssl      => 1,
  Uid      => 1,
) or die "Cannot connect $@";

$imap->authenticate('XOAUTH2', sub { return SL::Controller::Oauth->imap_sasl_string(4); }) or die("Auth error: ". $imap->LastError);

my $folders = $imap->folders or die "List folders error: ", $imap->LastError, "\n";

print "Folders: @$folders\n";
Folders: Archiv Aufgaben Entw&APw-rfe Gel&APY-schte Elemente Gesendete Elemente Journal Junk-E-Mail Kalender Kalender/Feiertage in Deutschland Kalender/Geburtstage Kontakte Notizen Postausgang INBOX Trash Verlauf der Unterhaltung
