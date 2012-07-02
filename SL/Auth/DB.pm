package SL::Auth::DB;

use strict;

use Carp;
use Scalar::Util qw(weaken);

use SL::Auth::Constants qw(:all);
use SL::Auth::Password;
use SL::DBUtils;

sub new {
  $main::lxdebug->enter_sub();

  my $type = shift;
  my $self = {};

  $self->{auth} = shift;
  weaken $self->{auth};

  bless $self, $type;

  $main::lxdebug->leave_sub();

  return $self;
}

sub reset {
  # nothing to do here
}

sub authenticate {
  $main::lxdebug->enter_sub();

  my $self       = shift;
  my $login      = shift;
  my $password   = shift;

  my $stored_password = $self->{auth}->get_stored_password($login);

  my ($algorithm, $algorithm2);

  # Empty password hashes in the database mean just that -- empty
  # passwords. Hash it for easier comparison.
  $stored_password               = SL::Auth::Password->hash(password => $stored_password) unless $stored_password;
  ($algorithm, $stored_password) = SL::Auth::Password->parse($stored_password);
  ($algorithm2, $password)       = SL::Auth::Password->parse(SL::Auth::Password->hash(password => $password, algorithm => $algorithm, login => $login));

  $main::lxdebug->leave_sub();

  return $password eq $stored_password ? OK : ERR_PASSWORD;
}

sub can_change_password {
  return 1;
}

sub requires_cleartext_password {
  return 0;
}

sub change_password {
  $main::lxdebug->enter_sub();

  my $self       = shift;
  my $login      = shift;
  my $password   = shift;
  my $is_crypted = shift;

  my $dbh        = $self->{auth}->dbconnect();

  if (!$dbh) {
    $main::lxdebug->leave_sub();
    return ERR_BACKEND;
  }

  $password = SL::Auth::Password->hash(login => $login, password => $password) unless $is_crypted;

  do_query($main::form, $dbh, qq|UPDATE auth."user" SET password = ? WHERE login = ?|, $password, $login);

  $dbh->commit();

  $main::lxdebug->leave_sub();

  return 1;
}

sub verify_config {
  return 1;
}

1;
