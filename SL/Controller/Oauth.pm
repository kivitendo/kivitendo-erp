package SL::Controller::Oauth;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::OauthToken;
use SL::Helper::Flash;
use SL::JSON;
use SL::Locale::String;
use SL::Request qw(flatten);
use REST::Client;
use SL::MoreCommon qw(uri_encode);
use Bytes::Random::Secure qw(random_bytes_base64);
use Digest::SHA qw(sha256_base64);
use MIME::Base64;

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw(config) ],
  'scalar --get_set_init' => [ qw(defaults) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('load_config', only => [ qw(edit update delete) ]);


sub test {
  my $t = SL::DB::OauthToken->new();
  $t->{registration} = 'microsoft';
  $t->{authflow} = 'authcode';
  $t->{email} = 'a';
  $t->{access_token_expiration} = DateTime->now;
  $t->{access_token} = 'a';
  $t->{refresh_token} = 'b';
  $t->save;
}

sub access_token_valid {
  my ($tok) = @_;
  return $tok->{access_token_expiration} > DateTime->now();
}

my $registrations = {
  microsoft => {
    authorize_endpoint => 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
    devicecode_endpoint => 'https://login.microsoftonline.com/common/oauth2/v2.0/devicecode',
    token_endpoint => 'https://login.microsoftonline.com/common/oauth2/v2.0/token',
    redirect_uri => 'https://login.microsoftonline.com/common/oauth2/nativeclient',
    tenant => 'common',
    imap_endpoint => 'outlook.office365.com',
    smtp_endpoint => 'smtp.office365.com',
    sasl_method => 'XOAUTH2',
    scope => 'offline_access https://outlook.office.com/IMAP.AccessAsUser.All ' .
             'https://outlook.office.com/POP.AccessAsUser.All ' .
             'https://outlook.office.com/SMTP.Send',
    client_id => '08162f7c-0fd2-4200-a84a-f25a4db0b584',
    client_secret => 'TxRBilcHdC6WGBee]fs?QR:SJ8nI[g82',
  },
};

sub refresh {
  my ($tok) = @_;

  my $reg = $registrations->{$tok->{registration}};

  my $params = {
    client_id     => $reg->{client_id},
    client_secret => $reg->{client_secret},
    tenant        => $reg->{tenant},
    grant_type    => 'refresh_token',
    refresh_token => $tok->{refresh_token},
  };

  my $url         = $reg->{token_endpoint};
  my $query       = join '&', map { uri_encode($_->[0]) . '=' . uri_encode($_->[1]) } @{ flatten($params) };
  $main::lxdebug->dump(0, 'params', $query);

  my $client = REST::Client->new();
  $client->addHeader('Content-Type', 'application/x-www-form-urlencoded');
  my $ret = $client->POST($url, $query);
  my $response_code = $ret->responseCode();
  die "Request failed, response code was: $response_code\n" . $ret->responseContent() unless $response_code eq '200';

  my $content = from_json($ret->responseContent());

  $main::lxdebug->dump(0, 'cont', $content);

  die "Server returned error_code $content->{error_code}" if (exists $content->{error_code});

  my $expiration = DateTime->now()->add(seconds => $content->{expires_in}); # Shall we refresh after half of the time?
  $tok->access_token_expiration($expiration);
  $tok->access_token($content->{access_token});
  $tok->refresh_token($content->{refresh_token}) if (exists $content->{refresh_token});
  $tok->save();

}


sub imap_sasl_string {
  my ($self, $db_id) = @_;

  my $tok = SL::DB::Manager::OauthToken->find_by(id => $db_id);

  if (!access_token_valid($tok)) {
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

  my $taxzones = SL::DB::Manager::OauthToken->get_all();

  $self->setup_list_action_bar;
  $self->render('oauth/list',
                title    => t8('List of OAuth2 tokens'),
                TOKENS => $taxzones);
}

sub action_new {
  my ($self) = @_;

  $self->config(SL::DB::OauthToken->new());
  $self->setup_list_action_bar();
  $self->render('oauth/form', title => 'Add new OAuth2 token');
}

sub action_create {
  my ($self) = @_;

  my $reg = $registrations->{microsoft}; #$tok->{registration}};

  my $email = $::form->{config}->{email};
  $self->config(SL::DB::OauthToken->new());
  $self->config->{email} = $email;
  my $redirect_uri = 'http://localhost:8080/';

  if ($::form->{config}->{authcode} eq '') {
    my $verifier = random_bytes_base64(90, q{});
    my $challenge = sha256_base64($verifier);
    $challenge =~ tr/+\//-_/; # URL safe BASE64: replace '+' -> '-' and '/' -> '_'

    ## use Crypt::Digest::SHA256 qw(sha256_b64u)
    ## my $challenge = sha256_b64u($verifier); # URL-safe BASE64

    my $params = {
      client_id     => $reg->{client_id},
      tenant        => $reg->{tenant},
      scope                 => $reg->{scope},
      login_hint            => $email,
      response_type         => 'code',
      redirect_uri          => $redirect_uri,
      code_challenge        => $challenge,
      code_challenge_method => 'S256',
    };
    my $url         = $reg->{authorize_endpoint};
    my $query       = join '&', map { uri_encode($_->[0]) . '=' . uri_encode($_->[1]) } @{ flatten($params) };

$main::lxdebug->dump(0, 'step 1 verifier: ', $verifier);

    $self->config->{verifier} = $verifier;
    $self->config->{challenge} = $challenge;
    $self->config->{authorize_link} = $url . '?' . $query;
  } else {
    my $tok = SL::DB::OauthToken->new();
    my $authcode = $::form->{config}->{authcode};
    $self->config->{authcode} = $authcode;
    my $verifier = $::form->{config}->{verifier};
    if (!$verifier) { die 'no $verfifier set'; }
    my $params = {
      client_id     => $reg->{client_id},
      tenant        => $reg->{tenant},
      scope                 => $reg->{scope},
      grant_type    => 'authorization_code',
      code          => $authcode,
      client_secret => $reg->{client_secret},
      redirect_uri          => $redirect_uri,
      code_verifier => $verifier,
    };
    my $url         = $reg->{token_endpoint};
    my $query       = join '&', map { uri_encode($_->[0]) . '=' . uri_encode($_->[1]) } @{ flatten($params) };
    $main::lxdebug->dump(0, 'params', $query);

    my $client = REST::Client->new();
    $client->addHeader('Content-Type', 'application/x-www-form-urlencoded');
    my $ret = $client->POST($url, $query);
    my $response_code = $ret->responseCode();
    $main::lxdebug->dump(0, 'response', $ret->responseContent());
    die "Request failed, response code was: $response_code\n" . $ret->responseContent() unless $response_code eq '200';

    my $content = from_json($ret->responseContent());

    $main::lxdebug->dump(0, 'cont', $content);

    die "Server returned error_code $content->{error_code}" if (exists $content->{error_code});

    my $expiration = DateTime->now()->add(seconds => $content->{expires_in}); # Shall we refresh after half of the time?
    $tok->access_token_expiration($expiration);
    $tok->access_token($content->{access_token});
    $tok->refresh_token($content->{refresh_token}) if (exists $content->{refresh_token});

    $tok->{registration} = 'microsoft';
    $tok->{authflow} = 'authcode';
    $tok->{email} = $email;


    $tok->save();

    $self->config->{message} = "Token received: $content";

  }

  $self->setup_list_action_bar();
  $self->render('oauth/form', title => 'Add new OAuth2 token');
  #die($main::lxdebug->dump(0, 'ver', [$::form, $verifier, $challenge, $url . '?' . $query]));
}

sub action_tokenin {
  my ($self) = @_;

  my $authcode = $::form->{code};

  die($main::lxdebug->dump(0, 'ver', [$authcode, $::form]));
}

#
# filters
#

sub check_auth {
  $::auth->assert('config');
}


sub setup_list_action_bar {
  my ($self) = @_;

  my $is_new = 1; #!$self->config->id;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
     action => [
        t8('Save'),
        submit    => [ '#form', { action => 'Oauth/' . ($is_new ? 'create' : 'update') } ],
#        checks    => [ 'kivi.validate_form' ],
        accesskey => 'enter',
      ],

      link => [
        t8('Add'),
        link => $self->url_for(action => 'new'),
      ],
    );
  }
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
