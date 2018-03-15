use strict;
use Test::More;

use lib 't';

use_ok 'Support::TestSetup';
use SL::DATEV::CSV qw(check_text);
use Support::TestSetup;

use utf8;
Support::TestSetup::login();

my $ascii    = 'foobar 443334 hallo';
my $german   = 'üßäüö €';
my $croatia  = 'Kulašić hat viele €';
my $armenian = 'Հայերեն  ֏';

is 1,     SL::DATEV::CSV::check_encoding($ascii),    'ASCII Encoding';
is 1,     SL::DATEV::CSV::check_encoding($german),   'German umlaut, euro and ligatur Encoding';
is undef, SL::DATEV::CSV::check_encoding($croatia),  'croatia with euro Encoding';
is undef, SL::DATEV::CSV::check_encoding($armenian), 'armenian Encoding';

done_testing;
