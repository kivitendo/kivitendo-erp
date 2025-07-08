package SL::Controller::OAuth::Microsoft;

use strict;
use parent qw(SL::Controller::OAuth::Base);


# TODO: make real object with state:
my $authorize_endpoint  = 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize';
my $devicecode_endpoint = 'https://login.microsoftonline.com/common/oauth2/v2.0/devicecode';
my $token_endpoint      = 'https://login.microsoftonline.com/common/oauth2/v2.0/token';
my $tenant              = 'common',
my $imap_endpoint       = 'outlook.office365.com';
my $smtp_endpoint       = 'smtp.office365.com';
my $sasl_method         = 'XOAUTH2';
my $scope               = join ' ',
  'offline_access https://outlook.office.com/IMAP.AccessAsUser.All',
  'https://outlook.office.com/POP.AccessAsUser.All',
  'https://outlook.office.com/SMTP.Send';

sub type {
  "microsoft"
}

sub title {
  "Microsoft E-Mail";
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
    verifier     => random_bytes_b64(90)
  );

  $tok->$_($config->{$_}) for qw(client_id client_secret scope email);

  my %params = (
    client_id             => $tok->client_id,
    tenant                => $tenant,
    scope                 => $tok->scope,
    login_hint            => $tok->email,
    response_type         => 'code',
    redirect_uri          => $tok->redirect_uri,
    code_challenge        => sha256_b64u($tok->verifier),
    code_challenge_method => 'S256',
    state                 => $tok->tokenstate,
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
    tenant        => $tenant,
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
    client_id     => $tok->client_id,
    tenant        => $tenant,
    scope         => $tok->scope,
    grant_type    => 'authorization_code',
    code          => $authcode,
    client_secret => $tok->client_secret,
    redirect_uri  => $tok->redirect_uri,
    code_verifier => $tok->verifier,
  );

  my %headers = (
    'Content-Type' => 'application/x-www-form-urlencoded',
  );

  return $self->POST($token_endpoint, \%params, \%headers);
}

