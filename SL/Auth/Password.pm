package SL::Auth::Password;

use strict;

use Carp;
use Digest::SHA ();
use Encode ();
use PBKDF2::Tiny ();

sub hash_pkkdf2 {
  my ($class, %params) = @_;

  # PBKDF2::Tiny expects data to be in octets. Therefore we must
  # encode everything we hand over (login, password) to UTF-8.

  # This hash method uses a random hash and not just the user's login
  # for its salt. This is due to the official recommendation that at
  # least eight octets of random data should be used. Therefore we
  # must store the salt together with the hashed password. The format
  # in the database is:

  # {PBKDF2}salt-in-hex:hash-in-hex

  my $salt;

  if ((defined $params{stored_password}) && ($params{stored_password} =~ m/^\{PBKDF2\} ([0-9a-f]+) :/x)) {
    $salt = (split m{:}, Encode::encode('utf-8', $1), 2)[0];

  } else {
    my @login  = map { ord } split m{}, Encode::encode('utf-8', $params{login});
    my @random = map { int(rand(256)) } (0..16);

    $salt      = join '', map { sprintf '%02x', $_ } @login, @random;
  }

  my $hashed = "{PBKDF2}${salt}:" . join('', map { sprintf '%02x', ord } split m{}, PBKDF2::Tiny::derive('SHA-256', $salt, Encode::encode('utf-8', $params{password})));

  return $hashed;
}

sub hash {
  my ($class, %params) = @_;

  $params{algorithm} ||= 'PBKDF2';

  my $salt = $params{algorithm} =~ m/S$/ ? $params{login} : '';

  if ($params{algorithm} =~ m/^SHA256/) {
    return '{' . $params{algorithm} . '}' . Digest::SHA::sha256_hex($salt . $params{password});

  } elsif ($params{algorithm} =~ m/^PBKDF2/) {
    return $class->hash_pkkdf2(password => $params{password}, stored_password => $params{stored_password});

  } else {
    croak 'Unsupported hash algorithm ' . $params{algorithm};
  }
}

sub hash_if_unhashed {
  my ($class, %params) = @_;

  my ($algorithm, $password) = $class->parse($params{password}, 'NONE');

  return $params{password} unless $algorithm eq 'NONE';

  if ($params{look_up_algorithm}) {
    my $stored_password    = $params{auth}->get_stored_password($params{login});
    my ($stored_algorithm) = $class->parse($stored_password);
    $params{algorithm}     = $stored_algorithm;
  }

  return $class->hash(%params);
}

sub parse {
  my ($class, $password, $default_algorithm) = @_;

  return ($1, $2) if $password =~ m/^\{ ([^\}]+) \} (.+)/x;
  return ($default_algorithm || 'PBKDF2', $password);
}

1;
