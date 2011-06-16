package SL::Auth::Password;

use strict;

use Carp;

sub hash {
  my ($class, %params) = @_;

  if (!$params{algorithm}) {
    $params{algorithm}          = 'SHA1';
    $params{fallback_algorithm} = 'MD5';
  }

  if ($params{algorithm} eq 'SHA1') {
    if (eval { require Digest::SHA1; 1 }) {
      return '{SHA1}' . Digest::SHA1::sha1_hex($params{password});

    } elsif ($params{fallback_algorithm}) {
      return $class->hash_password(%params, algorithm => $params{fallback_algorithm});

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

sub parse {
  my ($class, $password) = @_;

  return ($1, $2) if $password =~ m/^\{ ([^\}]+) \} (.+)/x;
  return ('CRYPT', $password);
}

1;
