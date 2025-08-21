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


__END__

=pod

=encoding utf8

=head1 NAME

SL::Controller::OAuth::Base - Base class for OAuth providers

=head1 FUNCTIONS

=over 4

=item C<type>

This function returns the internal string representation of the provider
which is stored alongside each token in the database.

=item C<title>

This function returns a human readable description of the provider.

=item C<create_authorization_url>

This function returns an authorization URL for the interactive flow.

=item C<access_token>

This function performs the request to the provider to exchange an authcode
for a token.

=item C<refresh>

This function performs the request to the provider to refresh a token.


=back

=head1 AUTHOR

Niklas Schmidt E<lt>niklas@kivitendo.deE<gt>

=cut
