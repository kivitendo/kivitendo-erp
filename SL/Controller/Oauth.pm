package SL::Controller::Oauth;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::OauthToken;
use SL::Helper::Flash;
use SL::JSON;
use SL::Locale::String;
use REST::Client;
use SL::MoreCommon qw(uri_encode);
use SL::Controller::OAuth::Microsoft;
use SL::Controller::OAuth::Atlassian;

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw(config) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('load_config', only => [ qw(edit update delete) ]);

my %providers = (
  microsoft      => 'SL::Controller::OAuth::Microsoft',
  atlassian_jira => 'SL::Controller::OAuth::Atlassian',
);


sub access_token_valid {
  my ($tok) = @_;
  my $exp = $tok->access_token_expiration;
  my $now = DateTime->now;
  return $exp > $now;
}

sub load_credentials {
  my ($reg) = @_;
  # TODO: load client_id, client_secret, tenant etc for this
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
  my ($token_db_id, $jql) = @_;

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
  #my $jql = 'textfields ~ "Test case*"';
  $url = "https://api.atlassian.com/ex/jira/$cloudid/rest/api/3/search/jql?jql=" . uri_encode($jql) . "&maxResults=100&fields=id%2Cassignee%2Cauthor%2Ccreator%2Csummary%2Cresolution%2Cstatus%2Cpriority%2Ccreated%2Cupdated&expand=&reconcileIssues=";
  $ret = $client->GET($url);
  $response_code = $ret->responseCode();
  die "HTTP $response_code" unless $response_code eq '200';
  my $c = from_json($ret->responseContent);

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
  my $reg = load_credentials($regtype);

  $self->config(SL::DB::OauthToken->new());
  $self->config->{registration} = $::form->{oauth_type};
  $self->config->{$_} = $reg->{$_} for qw(client_id client_secret scope);
  $self->setup_add_action_bar();
  $self->render('oauth/form', title => 'Add new OAuth2 token');
}

sub action_create {
  my ($self) = @_;

  my $regtype = $::form->{registration};
  my $provider = $providers{$regtype} or die "unknown provider";

  my ($link, $tok) = $provider->create_authorization($self->config);

  $self->config->{authorize_link} = $link;
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
