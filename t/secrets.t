use strict;
use utf8;

use Encode qw(is_utf8);
use Test::More;
use Test::Exception;

use lib 't';
use Support::TestSetup;

Support::TestSetup::login();



require_ok('SL::DB::Secret');

# no master key => exception
{
  $::lx_office_conf{secrets}{master_key} = undef;

  throws_ok { SL::DB::Secret->new->encrypt("test") } qr/no master key for secrets configured/, "empty master password is not allowed";

  $::lx_office_conf{secrets}{master_key} = "ultra secret master passphrase";
}

# simple db-less roundtrip
{
  my $s1 = SL::DB::Secret->new(tag => "imap password", description => "password for the imap server");
  $s1->encrypt("letmein");
  my $pw_func = $s1->decrypt();

  is $pw_func->(), "letmein";
}

# simple roundtrip with utf8 and database
{
  my $s2 = SL::DB::Secret->new(tag => "raffle winner", description => "the winner of the raffle, drawn ahead of time. don't decode until October!");
  $s2->encrypt("Rüdiger");
  $s2->save;

  my $s3 = SL::DB::Manager::Secret->find_by(tag => "raffle winner");
  my $pw_func = $s3->decrypt;

  is $pw_func->(), "Rüdiger";
  is is_utf8($pw_func->()), 1;
}

# changing master password -> no useful data anymore
{
  $::lx_office_conf{secrets}{master_key} = "123456";

  my $s4 = SL::DB::Manager::Secret->find_by(tag => "raffle winner");

  isnt $s4->decrypt->(), "Rüdiger";
}

# setting master_key to non-ascii works
{
  $::lx_office_conf{secrets}{master_key} = "i8Σπ";

  my $s1 = SL::DB::Secret->new(tag => "imap password 2", description => "password for the imap server");
  $s1->encrypt("letmein");
  my $pw_func = $s1->decrypt();

  is $pw_func->(), "letmein";
}

# encoding of password with null byte works
{
  is   "mypasswd\0continues", "mypasswd\0continues";
  isnt "mypasswd\0continues", "mypasswd";

  my $s = SL::DB::Secret->new(tag => "null password", description => "null bytes");

  $s->encrypt("mypasswd\0continues");
  $s->save;
  $s->load;

  my $pw_func = $s->decrypt();

  is   $pw_func->(), "mypasswd\0continues";
  isnt $pw_func->(), "mypasswd";
}

# encoding binary password data works
{
  my $s = SL::DB::Secret->new(tag => "binary password", description => "binary data");

  $s->encrypt("\x{01}\x{de}\x{ad}\x{c0}\x{ff}\x{ee}");
  $s->save;
  $s->load;

  my $pw_func = $s->decrypt();

  is $pw_func->(), "\x{01}\x{de}\x{ad}\x{c0}\x{ff}\x{ee}";
}

done_testing();
