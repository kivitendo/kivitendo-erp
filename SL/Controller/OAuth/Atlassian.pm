package SL::Controller::OAuth::Atlassian;

use strict;
use parent qw(SL::Controller::OAuth::Base);

my $authorize_endpoint  = 'https://auth.atlassian.com/authorize';
my $devicecode_endpoint = 'https://auth.atlassian.com/oauth/token';
my $token_endpoint      = 'offline_access read:jira-work read:servicedesk-request';

sub type {
  "atlassian_jira";
}

sub title {
  "Atlassian Jira";
}

sub create_authorization {
  my ($self, $config) = @_;

  $self->config(SL::DB::OauthToken->new());

  my $redirect_uri = $::form->{config}->{redirect_uri};
  $redirect_uri .= '/' if ($redirect_uri !~ m/\/$/);
  $redirect_uri .= 'oauth.pl';

  my $tok = SL::DB::OauthToken->new(
    registration => $self->type,
    authflow     => 'authcode',
    redirect_uri => $redirect_uri,
    tokenstate   => random_bytes_b64u(14),
  );

  $tok->$_($config->{$_}) for qw(client_id client_secret scope);

  my %params = (
    client_id     => $tok->client_id,
    scope         => $tok->scope,
    redirect_uri  => $tok->redirect_uri,
    state         => $tok->tokenstate,
    audience      => 'api.atlassian.com',
    response_type => 'code',
    prompt        => 'consent',
  );

  return $authorize_endpoint . '?' . $self->query(\%params), $tok;
}

sub refresh {
  my ($self, $tok) = @_;

  my $client = REST::Client->new();

  my %params = (
    grant_type    => 'refresh_token',
    client_id     => $tok->client_id,
    client_secret => $tok->client_secret,
    refresh_token => $tok->refresh_token,
  );

  my %headers = (
    'Content-Type' => 'application/x-www-form-urlencoded',
  );

  $self->POST($token_endpoint, \%params, \%headers);
}

sub access_token {
  my ($self, $tok, $authcode) = @_;

  my %params = (
    grant_type    => 'authorization_code',
    client_id     => $tok->client_id,
    client_secret => $tok->client_secret,
    code          => $authcode,
    redirect_uri  => $tok->redirect_uri,
  );

  my %headers = (
    'Content-Type' => 'application/x-www-form-urlencoded',
  );

  return $self->POST($token_endpoint, \%params, \%headers);
}

