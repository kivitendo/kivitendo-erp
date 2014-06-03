use strict;

use Test::More;

use lib 't';
use Support::TestSetup;

Support::TestSetup::login();

my $dt = DateTime->new(year => 2014, month => 5, day => 31, hour => 23, minute => 9, second => 8, nanosecond => 12000000);

delete $::myconfig{numberformat};
delete $::myconfig{dateformat};

is($::locale->format_date_object($dt),                             '2014-05-31',              'defaults, no precision');
is($::locale->format_date_object($dt, precision => 'day'),         '2014-05-31',              'defaults, precision day');
is($::locale->format_date_object($dt, precision => 'hour'),        '2014-05-31 23',           'defaults, precision hour');
is($::locale->format_date_object($dt, precision => 'minute'),      '2014-05-31 23:09',        'defaults, precision minute');
is($::locale->format_date_object($dt, precision => 'second'),      '2014-05-31 23:09:08',     'defaults, precision second');
is($::locale->format_date_object($dt, precision => 'millisecond'), '2014-05-31 23:09:08.012', 'defaults, precision millisecond');

$::myconfig{numberformat} = '1.000,00';
$::myconfig{dateformat}   = 'dd.mm.yy';

is($::locale->format_date_object($dt),                             '31.05.2014',              'myconfig numberformat 1.000,00 dateformat dd.mm.yy, no precision');
is($::locale->format_date_object($dt, precision => 'day'),         '31.05.2014',              'myconfig numberformat 1.000,00 dateformat dd.mm.yy, precision day');
is($::locale->format_date_object($dt, precision => 'hour'),        '31.05.2014 23',           'myconfig numberformat 1.000,00 dateformat dd.mm.yy, precision hour');
is($::locale->format_date_object($dt, precision => 'minute'),      '31.05.2014 23:09',        'myconfig numberformat 1.000,00 dateformat dd.mm.yy, precision minute');
is($::locale->format_date_object($dt, precision => 'second'),      '31.05.2014 23:09:08',     'myconfig numberformat 1.000,00 dateformat dd.mm.yy, precision second');
is($::locale->format_date_object($dt, precision => 'millisecond'), '31.05.2014 23:09:08,012', 'myconfig numberformat 1.000,00 dateformat dd.mm.yy, precision millisecond');

is($::locale->format_date_object($dt, dateformat => 'mm/dd/yy'),                             '05/31/2014',              'myconfig numberformat 1.000,00, explicit dateformat mm/dd/yy, no precision');
is($::locale->format_date_object($dt, dateformat => 'mm/dd/yy', precision => 'day'),         '05/31/2014',              'myconfig numberformat 1.000,00, explicit dateformat mm/dd/yy, precision day');
is($::locale->format_date_object($dt, dateformat => 'mm/dd/yy', precision => 'hour'),        '05/31/2014 23',           'myconfig numberformat 1.000,00, explicit dateformat mm/dd/yy, precision hour');
is($::locale->format_date_object($dt, dateformat => 'mm/dd/yy', precision => 'minute'),      '05/31/2014 23:09',        'myconfig numberformat 1.000,00, explicit dateformat mm/dd/yy, precision minute');
is($::locale->format_date_object($dt, dateformat => 'mm/dd/yy', precision => 'second'),      '05/31/2014 23:09:08',     'myconfig numberformat 1.000,00, explicit dateformat mm/dd/yy, precision second');
is($::locale->format_date_object($dt, dateformat => 'mm/dd/yy', precision => 'millisecond'), '05/31/2014 23:09:08,012', 'myconfig numberformat 1.000,00, explicit dateformat mm/dd/yy, precision millisecond');

is($::locale->format_date_object($dt, dateformat => 'mm/dd/yy', numberformat => '1000.00'),                             '05/31/2014',              'explicit numberformat 1000.00 dateformat mm/dd/yy, no precision');
is($::locale->format_date_object($dt, dateformat => 'mm/dd/yy', numberformat => '1000.00', precision => 'day'),         '05/31/2014',              'explicit numberformat 1000.00 dateformat mm/dd/yy, precision day');
is($::locale->format_date_object($dt, dateformat => 'mm/dd/yy', numberformat => '1000.00', precision => 'hour'),        '05/31/2014 23',           'explicit numberformat 1000.00 dateformat mm/dd/yy, precision hour');
is($::locale->format_date_object($dt, dateformat => 'mm/dd/yy', numberformat => '1000.00', precision => 'minute'),      '05/31/2014 23:09',        'explicit numberformat 1000.00 dateformat mm/dd/yy, precision minute');
is($::locale->format_date_object($dt, dateformat => 'mm/dd/yy', numberformat => '1000.00', precision => 'second'),      '05/31/2014 23:09:08',     'explicit numberformat 1000.00 dateformat mm/dd/yy, precision second');
is($::locale->format_date_object($dt, dateformat => 'mm/dd/yy', numberformat => '1000.00', precision => 'millisecond'), '05/31/2014 23:09:08.012', 'explicit numberformat 1000.00 dateformat mm/dd/yy, precision millisecond');

done_testing;

1;
