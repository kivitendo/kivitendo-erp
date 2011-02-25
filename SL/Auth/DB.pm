package SL::Auth::DB;

use strict;

use Carp;

use SL::Auth::Constants qw(:all);
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

  my $dbh        = $self->{auth}->dbconnect();

  if (!$dbh) {
    $main::lxdebug->leave_sub();
    return ERR_BACKEND;
  }

  my $query             = qq|SELECT password FROM auth."user" WHERE login = ?|;
  my ($stored_password) = $dbh->selectrow_array($query, undef, $login);

  my ($algorithm, $algorithm2);

  # Empty password hashes in the database mean just that -- empty
  # passwords. Hash it for easier comparison.
  $stored_password               = $self->hash_password(password => $stored_password) unless $stored_password;
  ($algorithm, $stored_password) = $self->parse_password_entry($stored_password);
  ($algorithm2, $password)       = $self->parse_password_entry($self->hash_password(password => $password, algorithm => $algorithm, login => $login));

  $main::lxdebug->leave_sub();

  return $password eq $stored_password ? OK : ERR_PASSWORD;
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
    return ERR_BACKEND;
  }

  $password = $self->hash_password(password => $password) unless $is_crypted;

  do_query($main::form, $dbh, qq|UPDATE auth."user" SET password = ? WHERE login = ?|, $password, $login);

  $dbh->commit();

  $main::lxdebug->leave_sub();

  return 1;
}

sub verify_config {
  return 1;
}

sub hash_password {
  my ($self, %params) = @_;

  if (!$params{algorithm}) {
    $params{algorithm}          = 'SHA1';
    $params{fallback_algorithm} = 'MD5';
  }

  if ($params{algorithm} eq 'SHA1') {
    if (eval { require Digest::SHA1; 1 }) {
      return '{SHA1}' . Digest::SHA1::sha1_hex($params{password});

    } elsif ($params{fallback_algorithm}) {
      return $self->hash_password(%params, algorithm => $params{fallback_algorithm});

    } else {
      die 'Digest::SHA1 not available';
    }

  } elsif ($params{algorithm} eq 'MD5') {
    require Digest::MD5;
    return '{MD5}' . Digest::MD5::md5_hex($params{password});

  } elsif ($params{algorithm} eq 'CRYPT') {
    return '{CRYPT}' . crypt($params{password}, substr($params{login}, 0, 2));

  } else {
    croak 'Unsupported hash algorithm ' . $params{algorithm};
  }
}

sub parse_password_entry {
  my ($self, $password) = @_;

  return ($1, $2) if $password =~ m/^\{ ([^\}]+) \} (.+)/x;
  return ('CRYPT', $password);
}

1;
