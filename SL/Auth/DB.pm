package SL::Auth::DB;

use DBI;

#use SL::Auth;
use SL::DBUtils;

sub new {
  $main::lxdebug->enter_sub();

  my $type = shift;
  my $self = {};

  $self->{auth} = shift;

  bless $self, $type;

  $main::lxdebug->leave_sub();

  return $self;
}

sub authenticate {
  $main::lxdebug->enter_sub();

  my $self       = shift;
  my $login      = shift;
  my $password   = shift;
  my $is_crypted = shift;

  my $dbh        = $self->{auth}->dbconnect();

  if (!$dbh) {
    $main::lxdebug->leave_sub();
    return SL::Auth::ERR_BACKEND;
  }

  my $query             = qq|SELECT password FROM auth."user" WHERE login = ?|;
  my ($stored_password) = $dbh->selectrow_array($query, undef, $login);

  $password        = crypt $password, substr($login, 0, 2)        if (!$password || !$is_crypted);
  $stored_password = crypt $stored_password, substr($login, 0, 2) if (!$stored_password);

  $main::lxdebug->leave_sub();

  return $password eq $stored_password ? SL::Auth::OK : SL::Auth::ERR_PASSWORD;
}

sub can_change_password {
  return 1;
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
    return SL::Auth::ERR_BACKEND
  }

  $password = crypt $password, substr($login, 0, 2) if (!$is_crypted);

  do_query($main::form, $dbh, qq|UPDATE auth."user" SET password = ? WHERE login = ?|, $password, $login);

  $dbh->commit();

  $main::lxdebug->leave_sub();

  return 1;
}

sub verify_config {
  return 1;
}

1;
