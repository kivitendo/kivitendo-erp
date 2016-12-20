use Test::More tests => 17;

use strict;
use lib 't';
use utf8;

use_ok 'SL::CTI';

$::lx_office_conf{cti}->{international_dialing_prefix} = '00';
$::lx_office_conf{cti}->{dial_command}                 = 'dummy';

is SL::CTI->call_link(number => '0371 5347 620'),        'controller.pl?action=CTI/call&number=03715347620';
is SL::CTI->call_link(number => '0049(0)421-22232 22'),  'controller.pl?action=CTI/call&number=00494212223222';
is SL::CTI->call_link(number => '+49(0)421-22232 22'),   'controller.pl?action=CTI/call&number=00494212223222';
is SL::CTI->call_link(number => 'Tel: +49 40 809064 0'), 'controller.pl?action=CTI/call&number=0049408090640';

is SL::CTI->call_link(number => '0371 5347 620',        internal => 1), 'controller.pl?action=CTI/call&number=03715347620&internal=1';
is SL::CTI->call_link(number => '0049(0)421-22232 22',  internal => 1), 'controller.pl?action=CTI/call&number=00494212223222&internal=1';
is SL::CTI->call_link(number => '+49(0)421-22232 22',   internal => 1), 'controller.pl?action=CTI/call&number=00494212223222&internal=1';
is SL::CTI->call_link(number => 'Tel: +49 40 809064 0', internal => 1), 'controller.pl?action=CTI/call&number=0049408090640&internal=1';

$::lx_office_conf{cti}->{dial_command} = '';

is SL::CTI->call_link(number => '0371 5347 620'),        'callto://03715347620';
is SL::CTI->call_link(number => '0049(0)421-22232 22'),  'callto://00494212223222';
is SL::CTI->call_link(number => '+49(0)421-22232 22'),   'callto://00494212223222';
is SL::CTI->call_link(number => 'Tel: +49 40 809064 0'), 'callto://0049408090640';

is SL::CTI->call_link(number => '0371 5347 620',        internal => 1), 'callto://03715347620';
is SL::CTI->call_link(number => '0049(0)421-22232 22',  internal => 1), 'callto://00494212223222';
is SL::CTI->call_link(number => '+49(0)421-22232 22',   internal => 1), 'callto://00494212223222';
is SL::CTI->call_link(number => 'Tel: +49 40 809064 0', internal => 1), 'callto://0049408090640';
