package SL::Controller::OAuth::GoogleCal;

use strict;
use parent qw(SL::Controller::OAuth::Base);
use SL::JSON;
use Crypt::PRNG qw(random_bytes_b64u);

my $authorize_endpoint  = 'https://accounts.google.com/o/oauth2/v2/auth';
my $token_endpoint      = 'https://oauth2.googleapis.com/token';
my $scope               = join ' ',
  'https://www.googleapis.com/auth/calendar.readonly';

sub type {
  "google_cal";
}

sub title {
  "Google Calendar";
}

sub create_authorization_url {
  my ($self, $config) = @_;

  my $cred = $self->load_credentials();

  my $tok = SL::DB::OAuthToken->new(
    registration => $self->type,
    tokenstate   => random_bytes_b64u(14),
  );

  my %params = (
    client_id     => $cred->{client_id},
    scope         => $scope,
    redirect_uri  => $cred->{redirect_uri},
    state         => $tok->tokenstate,
    response_type => 'code',
    prompt        => 'consent',
    access_type   => 'offline',
  );

  return $authorize_endpoint . '?' . $self->query(\%params), $tok;
}

sub refresh {
  my ($self, $tok) = @_;

  my $cred = $self->load_credentials();
  my $client = REST::Client->new();

  my %params = (
    grant_type    => 'refresh_token',
    client_id     => $cred->{client_id},
    client_secret => $cred->{client_secret},
    refresh_token => $tok->refresh_token,
  );

  my %headers = (
    'Content-Type' => 'application/json',
  );

  $self->POST_JSON($token_endpoint, \%params, \%headers);
}

sub access_token {
  my ($self, $tok, $authcode) = @_;

  my $cred = $self->load_credentials();

  my %params = (
    grant_type    => 'authorization_code',
    client_id     => $cred->{client_id},
    client_secret => $cred->{client_secret},
    code          => $authcode,
    redirect_uri  => $cred->{redirect_uri},
  );

  my %headers = (
    'Content-Type' => 'application/json',
  );

  return $self->POST_JSON($token_endpoint, \%params, \%headers);
}
