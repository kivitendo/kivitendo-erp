use Test::More tests => 5;

use strict;
use lib 't';
use utf8;

use_ok 'SL::CTI';

{
  no warnings 'once';
  $::lx_office_conf{cti}->{international_dialing_prefix} = '00';
}

is SL::CTI->sanitize_number(number => '0371 5347 620'),        '03715347620';
is SL::CTI->sanitize_number(number => '0049(0)421-22232 22'),  '00494212223222';
is SL::CTI->sanitize_number(number => '+49(0)421-22232 22'),   '00494212223222';
is SL::CTI->sanitize_number(number => 'Tel: +49 40 809064 0'), '0049408090640';
