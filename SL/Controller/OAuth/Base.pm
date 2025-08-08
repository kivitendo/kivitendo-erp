package SL::Controller::OAuth::Base;

use strict;
use REST::Client;
use SL::JSON;
use SL::Locale::String;
use SL::MoreCommon qw(uri_encode);
use SL::DB::OAuthToken;

sub type {
  die "needs to be implemented";
}

sub title {
  die "needs to be implemented";
}

sub create_authorization_url {
  die "needs to be implemented";
}

sub access_token {
  die "needs to be implemented";
}

sub refresh {
  die "needs to be implemented";
}

sub load_credentials {
  my ($class) = @_;

  my $regtype = $class->type();

  my %reg;

  my $conf = $::lx_office_conf{"oauth2_$regtype"} or
    die t8('Missing configuration section "oauth2_#1" in "config/kivitendo.conf"', $regtype);

  $reg{$_} = $conf->{$_} or
    die t8('Missing parameter "#1" of section "oauth2_#2" in "config/kivitendo.conf"', $_, $regtype)
    for qw(client_id client_secret redirect_uri);

  die t8('Parameter "redirect_uri = #1" of section "oauth2_#2" in config/kivitendo.conf must end in /oauth.pl', $reg{redirect_uri}, $regtype) unless ($reg{redirect_uri} =~ m/\/oauth.pl$/);

  \%reg;
}

sub POST {
  my ($class, $url, $params, $headers) = @_;

  my $client = REST::Client->new();

  $client->addHeader($_, $headers->{$_}) for keys %$headers;

  my $ret = $client->POST($url, $class->query($params));
}

sub POST_JSON {
  my ($class, $url, $data, $headers) = @_;

  my $client = REST::Client->new();

  $client->addHeader($_, $headers->{$_}) for keys %$headers;

  my $ret = $client->POST($url, to_json($data));
}



sub query {
  my ($class, $params) = @_;
  my $query = join '&', map { uri_encode($_) . '=' . uri_encode($params->{$_}) } keys %$params;
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
