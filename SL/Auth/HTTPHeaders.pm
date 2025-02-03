package SL::Auth::HTTPHeaders;

use List::MoreUtils qw(any);

use SL::Auth::Constants qw(:all);

use strict;

my @required_config_options = qw(secret_header secret user_header client_id_header);

sub new {
  my $type        = shift;
  my $self        = {};
  $self->{config} = shift;

  bless $self, $type;

  return $self;
}

sub reset {
  my ($self) = @_;
}

sub _env_var_for_header {
  my ($header) = @_;

  $header =~ s{-}{_}g;
  return $ENV{'HTTP_' . uc($header)};
}

sub _authenticate {
  my ($self, $type) = @_;

  my $secret = _env_var_for_header($self->{config}->{secret_header}) // '';
  if ($secret ne $self->{config}->{secret}) {
    $::lxdebug->message(LXDebug->DEBUG2(), "HTTPHeaders ${type}: bad secret sent by upstream server: $secret");
    return (ERR_BACKEND);
  }

  my $client_id = _env_var_for_header($self->{config}->{client_id_header});
  if (!$client_id) {
    $::lxdebug->message(LXDebug->DEBUG2(), "HTTPHeaders ${type}: no client ID header found");
    return (ERR_PASSWORD);
  }

  # $::auth->set_client();

  my $user = _env_var_for_header($self->{config}->{user_header});
  if (!$user) {
    $::lxdebug->message(LXDebug->DEBUG2(), "HTTPHeaders ${type}: no user name header found");
    return (ERR_PASSWORD);
  }

  $::lxdebug->message(LXDebug->DEBUG2(), "HTTPHeaders ${type}: OK client $client_id user $user");

  return (OK, $client_id, $user);
}

sub authenticate {
  my ($self) = @_;

  my ($status, $client, $login) = $self->_authenticate('authenticate');

  return $status;
}

sub can_change_password {
  return 0;
}

sub requires_cleartext_password {
  return 0;
}

sub change_password {
  return ERR_BACKEND;
}

sub verify_config {
  my $self = shift;
  my $cfg  = $self->{config};

  if (!$cfg) {
    die 'config/kivitendo.conf: Key "authentication/http_headers" is missing.';
  }

  foreach (@required_config_options) {
    next if $cfg->{$_};
    die 'config/kivitendo.conf: Missing parameter in "authentication/http_headers": ' . $_;
  }
}

=pod

=encoding utf8

=head1 NAME

SL::Auth::HTTPHeaders - Automatically log in users based on headers
sent by upstream servers

=head1 OVERVIEW

This module implements two modes for automatic log in for users:

=over 4

=item HTTP Basic Authentication

=item passing user name & client ID via arbitrary headers

=back

The module must be enabled in the configuration file by setting
C<authentication.module=HTTPHeaders>. It is then configured by the
sections C<authentication/http_basic> & C<authentication/http_headers>.

=head1 SUPPORTED AUTHENTICATION METHODS

=head2 User name & client ID in HTTP headers

Must be enabled by setting
C<authentication/http_headers.enabled=1>. If enabled, it relies on
upstream servers (web server, proxy server) doing the authentication
with SSO solutions like Authelia & Authentik. These solutions must
then send the user name of the authenticated user in an HTTP header &
the desired client ID in another header.

In order to ensure no malicious third party can simply set these
header values, a shared secret must be configured in the configuration
file & sent along in a third header field.

The names of all three headers as well as the shared secret must be
set in the configuration file's C<authentication/http_headers>
section.

This mode is mutually exclusive with the HTTP Basic Authentication
mentioned below.

=head2 HTTP Basic Authentication (RFC 7617)

Must be enabled by setting C<authentication/http_basic.enabled=1>. If
enabled, it relies on the web server doing the authentication for it &
passing the result in the C<Authorization> header, which turns into e
environment variable C<HTTP_AUTHORIZATION> according to the CGI
specifications.

This mode only supports using the default client as no way to pass the
desired client ID has been implemented yet.

This mode is mutually exclusive with the "User name & client ID in
HTTP headers" mode mentioned above.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet.deE<gt>

=cut

1;
