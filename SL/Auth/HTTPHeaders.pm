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

1;
