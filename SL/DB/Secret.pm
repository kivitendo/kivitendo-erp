package SL::DB::Secret;

use strict;

use Crypt::Mode::CTR;
use Crypt::PRNG;
use Crypt::KeyDerivation;
use Encode qw(encode_utf8 decode_utf8 is_utf8);

use SL::DB::MetaSetup::Secret;
use SL::DB::Manager::Secret;

__PACKAGE__->meta->initialize;


use constant PBKDF2_HASH       => 'SHA256';
use constant PBKDF2_ITERATIONS => 600_000;
use constant AES_KEY_BITS      => 256;
use constant AES_KEY_BYTES     => AES_KEY_BITS / 8;
use constant SALT_LENGTH       => 16;
use constant IV_LENGTH         => 16;


sub encrypt {
  my ($self, $secret) = @_;

  my ($master_key, $salt) = _key();
  my $iv = Crypt::PRNG::random_bytes(IV_LENGTH);

  my $utf_flag = is_utf8($secret);
  my $bytes = $utf_flag ? encode_utf8($secret) : $secret;

  my $m = Crypt::Mode::CTR->new('AES');
  my $cipher = $m->encrypt($bytes, $master_key, $iv);

  $self->salt($salt);
  $self->iv($iv);
  $self->cipher($cipher);
  $self->utf_flag($utf_flag);

  $self;
}

sub decrypt {
  my ($self) = @_;

  my ($master_key) = _key($self->salt);

  my $m = Crypt::Mode::CTR->new('AES');
  my $bytes = $m->decrypt($self->cipher, $master_key, $self->iv);
  my $secret = $self->utf_flag ? decode_utf8($bytes) : $bytes;

  return sub { $secret };
}


### private

sub _key {
  my ($salt) = @_;

  my $passphrase = encode_utf8($::lx_office_conf{secrets}{master_key}) or die 'no master key for secrets configured';
  $salt //= Crypt::PRNG::random_string(SALT_LENGTH);
  my $stretched_key = Crypt::KeyDerivation::pbkdf2($passphrase, $salt, PBKDF2_ITERATIONS, PBKDF2_HASH, AES_KEY_BYTES);

  return ($stretched_key, $salt);
}


1;

=encoding utf-8

=head1 NAME

SL::DB::Secrets - API for storing sensitive data in the kivitendo database

=head1 SYNOPSIS

  use SL::DB::Secrets;

  # store

  my $s = SL::DB::Secrets->new(
    tag         => $unique_tag,  # required key
    description => $description, # optional
  );
  $s->encrypt($secret);
  $s->save;

  # load and decrypt

  my $pw_closure = SL::DB::Secrets->new(tag => $unique_tag)->load->decrypt;
  my $plaintext  = $pw_closure->();

=head1 DESCRIPTION

SL::DB::Secrets can be used to encrypt user supplied sensitive data
for storage in the database.

For example: You have a background job to retrieve emails, and that job needs an
imap password. Usually this would be stored in plaintext in the config of the
backgroundjob.

Using SL::DB::Secrets the actual key gets stored AES encrypted
and the config only needs to refer to the key tag or id.

the actual key gets passed as a closure to avoid leaking the key in dumps


=head1 SECURITY CHOICES

All cryptographic primitives are from L<CryptX>, available as C<libcryptx-perl>
on debian.

Passwords in the database are encrypted with AES in Counter Mode. AES was
chosen as an allround symmetric cipher. Counter mode was chosen because message
authentication is not needed, and because it doesn't require padding unlike
other block chaining modes.

The AES key itself is stretched from the provided master key at runtime with
PBKDF2 and a random 16 byte salt, so that the provided master passphrase
doesn't need to have the exact length of AES keys.

Salt length 16 is the current NIST recommendation for PBKDF2 derived keys.

Iteration count for PBKDF2 is the current OWASP recommentation of 600k. Beware
that this takes between 200-300ms on current systems and ~1s on older hardware
from 2010.

=head1 ENCODING

Encoding/decoding is perl utf8 flag aware and will preserve it.

=head1 CAVEATS

This modules is intended to secure database dumps.

It will NOT protect against priviliged access to a running instance of
kivitendo, nor against full system backups in which the master key can be
recovered.

=head1 BUGS

None yet :)

=head1 AUTHOR

Sven Schöling E<lt>sven.schoeling@googlemail.comE<gt>

=cut
