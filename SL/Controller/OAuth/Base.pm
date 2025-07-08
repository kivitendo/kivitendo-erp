package SL::Controller::OAuth::Base;

use strict;
use REST::Client;
use SL::JSON;
use SL::Request qw(flatten);
use SL::DB::OauthToken;

sub type {
  die "needs to be implemented";
}

sub title {
  die "needs to be implemented";
}

sub create_authorization {
  die "needs to be implemented";
}

sub access_token {
  die "needs to be implemented";
}

sub refresh {
  die "needs to be implemented";
}


sub POST {
  my ($class, $url, $params, $headers) = @_;

  my $client = REST::Client->new();

  $client->addHeader($_->[0], $_->[1]) for @{ flatten($headers) };

  my $ret = $client->POST($url, $class->query($params));
}

sub query {
  my ($class, $params) = @_;
  my $query = join '&', map { uri_encode($_->[0]) . '=' . uri_encode($_->[1]) } @{ flatten($params) };
}

sub set_access_refresh_token {
  my ($self, $tok, $content) = @_;

  my $expiration = DateTime->now;
  $expiration->add(seconds => $content->{expires_in});
  $tok->access_token_expiration($expiration);
  $tok->access_token($content->{access_token});
  $tok->refresh_token($content->{refresh_token}) if exists $content->{refresh_token};
}


1;

# base class for oauth providers
