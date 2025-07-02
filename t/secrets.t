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

$::lx_office_conf{secrets}{master_key} = undef;

throws_ok { SL::DB::Secret->new->encrypt("test") } qr/no master key for secrets configured/, "empty master password is not allowed";

$::lx_office_conf{secrets}{master_key} = "ultra secret master passphrase";


# simple db-less roundtrip

my $s1 = SL::DB::Secret->new(tag => "imap password", description => "password for the imap server");
$s1->encrypt("letmein");
my $pw_func = $s1->decrypt();

is $pw_func->(), "letmein";


# simple roundtrip with utf8 and database

my $s2 = SL::DB::Secret->new(tag => "raffle winner", description => "the winner of the raffle, drawn ahead of time. don't decode until October!");
$s2->encrypt("Rüdiger");
$s2->save;

my $s3 = SL::DB::Manager::Secret->find_by(tag => "raffle winner");
my $pw_func = $s3->decrypt;

is $pw_func->(), "Rüdiger";
is is_utf8($pw_func->()), 1;


# changing master password -> no useful data anymore

$::lx_office_conf{secrets}{master_key} = "123456";

my $s4 = SL::DB::Manager::Secret->find_by(tag => "raffle winner");

isnt $s4->decrypt->(), "Rüdiger";


done_testing();
