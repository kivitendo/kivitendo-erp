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



sub access_token_valid {
  my ($tok) = @_;
  my $exp = $tok->access_token_expiration;
  my $now = DateTime->now;
  return $exp > $now;
}

my $registrations = {
  microsoft => {
    authorize_endpoint => 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
    devicecode_endpoint => 'https://login.microsoftonline.com/common/oauth2/v2.0/devicecode',
    token_endpoint => 'https://login.microsoftonline.com/common/oauth2/v2.0/token',
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
  atlassian_jira => {
    authorize_endpoint => 'https://auth.atlassian.com/authorize',
    token_endpoint => 'https://auth.atlassian.com/oauth/token',
    scope => 'offline_access read:jira-work read:servicedesk-request',
    client_id => '',
    client_secret => '',
  },
};

sub set_access_refresh_token {
  my ($tok, $content) = @_;

  my $expiration = DateTime->now;
  $expiration->add(seconds => $content->{expires_in});
  $tok->access_token_expiration($expiration);
  $tok->access_token($content->{access_token});
  $tok->refresh_token($content->{refresh_token}) if (exists $content->{refresh_token});
}

sub refresh {
  my ($tok) = @_;

  my $reg = $registrations->{$tok->{registration}};

  my $client = REST::Client->new();
  my $params;
  my $query;

  if ($tok->registration eq 'microsoft') {
    $params = {
      grant_type    => 'refresh_token',
      client_id     => $tok->client_id,
      client_secret => $tok->client_secret,
      tenant        => $reg->{tenant},
      refresh_token => $tok->refresh_token,
    };

    $query = join '&', map { uri_encode($_->[0]) . '=' . uri_encode($_->[1]) } @{ flatten($params) };
    $client->addHeader('Content-Type', 'application/x-www-form-urlencoded');
  } elsif ($tok->registration eq 'atlassian_jira') {
     $params = {
      grant_type    => 'refresh_token',
      client_id     => $tok->client_id,
      client_secret => $tok->client_secret,
      refresh_token => $tok->refresh_token,
    };

    $query = to_json($params);
    $client->addHeader('Content-Type', 'application/json');
  }

  my $ret = $client->POST($reg->{token_endpoint}, $query);
  my $response_code = $ret->responseCode();
  die "Request failed, response code was: $response_code\n" . $ret->responseContent() unless $response_code eq '200';

  my $content = from_json($ret->responseContent());

  die "Server returned error_code $content->{error_code}" if (exists $content->{error_code});

  set_access_refresh_token($tok, $content);

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

sub http_bearer_auth_header {
  my ($db_id) = @_;

  my $tok = SL::DB::Manager::OauthToken->find_by(id => $db_id);

  if (!access_token_valid($tok)) {
    refresh($tok);
  }

  return 'Bearer ' . $tok->access_token;
}

sub atlassian_jira_cloudid {
  my ($token_db_id) = @_;

  my $bearer = http_bearer_auth_header($token_db_id);
  my $client = REST::Client->new();
  $client->addHeader('Authorization', $bearer);
  $client->addHeader('Accept', 'application/json');
  my $ret = $client->GET('https://api.atlassian.com/oauth/token/accessible-resources');
  my $response_code = $ret->responseCode();
  die "HTTP $response_code" unless $response_code eq '200';

  my $accessible_resources = from_json($ret->responseContent);
  my $cloudid = $accessible_resources->[0]{id};

  #return $cloudid;

  my $url;
  #$url = "https://api.atlassian.com/ex/jira/$cloudid/rest/api/3/project/search";
  #$ret = $client->GET($url);
  #$response_code = $ret->responseCode();
  #die "HTTP $response_code" unless $response_code eq '200';
  #return from_json($ret->responseContent);

  my $maxResults = 100;
  my $fields = "summary";
  my $jql = 'textfields ~ "Test case*"';
  $url = "https://api.atlassian.com/ex/jira/$cloudid/rest/api/3/search/jql?jql=" . uri_encode($jql) . "&maxResults=100&fields=id%2Cassignee%2Cauthor%2Ccreator%2Csummary%2Cresolution%2Cstatus%2Cpriority%2Ccreated%2Cupdated&expand=&reconcileIssues=";
  $ret = $client->GET($url);
  $response_code = $ret->responseCode();
  die "HTTP $response_code" unless $response_code eq '200';
  my $c = from_json($ret->responseContent);
  $main::lxdebug->dump(0, 'content', $c);
  my @a = map({{
    key        => $_->{key},
    summary    => $_->{fields}->{summary},
    creator    => $_->{fields}->{creator}->{displayName},
    assignee   => $_->{fields}->{assignee}->{displayName},
    priority   => $_->{fields}->{priority}->{name},
    created    => $_->{fields}->{created},
    updated    => $_->{fields}->{updated},
    status     => $_->{fields}->{status}->{name},
    resolution => $_->{fields}->{resolution}->{name},
  }} @{$c->{issues}});
  return \@a;
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
  my $reg = $registrations->{$regtype};

  $self->config(SL::DB::OauthToken->new());
  $self->config->{registration} = $::form->{oauth_type};
  $self->config->{$_} = $reg->{$_} for qw(client_id client_secret scope);
  $self->setup_add_action_bar();
  $self->render('oauth/form', title => 'Add new OAuth2 token');
}

sub random_b64u {
  # URL safe BASE64: replace '+' -> '-' and '/' -> '_'
  my ($n) = @_;
  my $b64 = random_bytes_base64($n, q{});
  $b64 =~ tr/+\//-_/;
  return $b64;
}

sub sha256_b64u {
  my ($x) = @_;
  my $hash = sha256_base64($x);
  $hash =~ tr/+\//-_/;
  return $hash;
}

sub action_create {
  my ($self) = @_;

  my $regtype = $::form->{registration};


  $self->config(SL::DB::OauthToken->new());

  my $redirect_uri = $::form->{config}->{redirect_uri};
  $redirect_uri .= '/' if ($redirect_uri !~ m/\/$/);
  $redirect_uri .= 'oauth.pl';

  my $reg = $registrations->{$regtype};
  my $tok = SL::DB::OauthToken->new();
  $tok->registration($regtype);
  $tok->authflow('authcode');
  $tok->redirect_uri($redirect_uri);
  $tok->tokenstate(random_b64u(14));

  $tok->$_($::form->{config}->{$_}) for qw(client_id client_secret scope);

  my $params;
  if ($regtype eq 'microsoft') {
    $tok->email($::form->{config}->{email});
    $self->config->{email} = $tok->email;
    $tok->verifier(random_bytes_base64(90, q{}));
    my $challenge = sha256_b64u($tok->verifier);

    $params = {
      client_id             => $tok->client_id,
      tenant                => $reg->{tenant},
      scope                 => $tok->scope,
      login_hint            => $tok->email,
      response_type         => 'code',
      redirect_uri          => $tok->redirect_uri,
      code_challenge        => $challenge,
      code_challenge_method => 'S256',
      state                 => $tok->tokenstate,
    };
  } elsif ($regtype eq 'atlassian_jira') {
    $params = {
      client_id     => $tok->client_id,
      scope         => $tok->scope,
      redirect_uri  => $tok->redirect_uri,
      state         => $tok->tokenstate,
      audience      => 'api.atlassian.com',
      response_type => 'code',
      prompt        => 'consent',
    };
  }
  my $url         = $reg->{authorize_endpoint};
  my $query       = join '&', map { uri_encode($_->[0]) . '=' . uri_encode($_->[1]) } @{ flatten($params) };

  $self->config->{authorize_link} = $url . '?' . $query;

  $tok->save();

  $self->render('oauth/forward', title => 'Add new OAuth2 token');
}


sub action_consume_authorization_code {
  my ($self) = @_;

  my $search_state = $::form->{state};
  my $tok = SL::DB::Manager::OauthToken->find_by(tokenstate => $search_state) or die "no token with state $search_state";
  my $reg = $registrations->{$tok->{registration}};

  $self->config($tok);
  $self->config->{email} = $tok->email;

  my $authcode = $::form->{code};

  my $client = REST::Client->new();
  my $query;

  if ($tok->registration eq 'microsoft') {
    my $params = {
      client_id     => $tok->client_id,
      tenant        => $reg->{tenant},
      scope         => $tok->scope,
      grant_type    => 'authorization_code',
      code          => $authcode,
      client_secret => $tok->client_secret,
      redirect_uri  => $tok->redirect_uri,
      code_verifier => $tok->verifier,
    };
    $query = join '&', map { uri_encode($_->[0]) . '=' . uri_encode($_->[1]) } @{ flatten($params) };

    $client->addHeader('Content-Type', 'application/x-www-form-urlencoded');
  } elsif ($tok->registration eq 'atlassian_jira') {
     my $params = {
      grant_type    => 'authorization_code',
      client_id     => $tok->client_id,
      client_secret => $tok->client_secret,
      code          => $authcode,
      redirect_uri  => $tok->redirect_uri,
    };
    $query = to_json($params);

    $client->addHeader('Content-Type', 'application/json');
  }
  my $ret = $client->POST($reg->{token_endpoint}, $query);
  my $response_code = $ret->responseCode();
  die "Request failed, response code was: $response_code\n" . $ret->responseContent() unless $response_code eq '200';

  my $content = from_json($ret->responseContent());

  die "Server returned error_code $content->{error_code}" if (exists $content->{error_code});

  set_access_refresh_token($tok, $content);

  $tok->tokenstate(undef);

  $tok->save();

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
