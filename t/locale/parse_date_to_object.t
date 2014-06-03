use strict;

use Test::More;

use lib 't';
use Support::TestSetup;

Support::TestSetup::login();

sub is_dt {
  my ($string, $expected, $msg, %args) = @_;

  is($::locale->format_date_object($::locale->parse_date_to_object($string, %args), numberformat => '1000.00', dateformat => 'yy-mm-dd', precision => 'millisecond'), $expected, $msg);
}

is($::locale->parse_date_to_object('in-valid!'), undef, 'defaults, invalid');

delete $::myconfig{numberformat};
delete $::myconfig{dateformat};

is_dt('2014-05-31',             '2014-05-31 00:00:00.000', 'defaults, no precision');
is_dt('2014-05-31 2',           '2014-05-31 02:00:00.000', 'defaults, precision hour');
is_dt('2014-05-31 2:04',        '2014-05-31 02:04:00.000', 'defaults, precision minute');
is_dt('2014-05-31 2:04:59',     '2014-05-31 02:04:59.000', 'defaults, precision second');
is_dt('2014-05-31 02:4:59.098', '2014-05-31 02:04:59.098', 'defaults, precision millisecond');
is_dt('2014-05-31 02:4:59.09',  '2014-05-31 02:04:59.090', 'defaults, precision centisecond');

$::myconfig{numberformat} = '1.000,00';
$::myconfig{dateformat}   = 'dd.mm.yy';

is_dt('31.05.2014',             '2014-05-31 00:00:00.000', 'myconfig numberformat 1.000,00 dateformat dd.mm.yy, no precision');
is_dt('31.05.2014 2',           '2014-05-31 02:00:00.000', 'myconfig numberformat 1.000,00 dateformat dd.mm.yy, precision hour');
is_dt('31.05.2014 2:04',        '2014-05-31 02:04:00.000', 'myconfig numberformat 1.000,00 dateformat dd.mm.yy, precision minute');
is_dt('31.05.2014 2:04:59',     '2014-05-31 02:04:59.000', 'myconfig numberformat 1.000,00 dateformat dd.mm.yy, precision second');
is_dt('31.05.2014 02:4:59,098', '2014-05-31 02:04:59.098', 'myconfig numberformat 1.000,00 dateformat dd.mm.yy, precision millisecond');

is_dt('05/31/2014',             '2014-05-31 00:00:00.000', 'myconfig numberformat 1.000,00 explicit dateformat mm/dd/yy, no precision',          dateformat => 'mm/dd/yy');
is_dt('05/31/2014 2',           '2014-05-31 02:00:00.000', 'myconfig numberformat 1.000,00 explicit dateformat mm/dd/yy, precision hour',        dateformat => 'mm/dd/yy');
is_dt('05/31/2014 2:04',        '2014-05-31 02:04:00.000', 'myconfig numberformat 1.000,00 explicit dateformat mm/dd/yy, precision minute',      dateformat => 'mm/dd/yy');
is_dt('05/31/2014 2:04:59',     '2014-05-31 02:04:59.000', 'myconfig numberformat 1.000,00 explicit dateformat mm/dd/yy, precision second',      dateformat => 'mm/dd/yy');
is_dt('05/31/2014 02:4:59,098', '2014-05-31 02:04:59.098', 'myconfig numberformat 1.000,00 explicit dateformat mm/dd/yy, precision millisecond', dateformat => 'mm/dd/yy');

is_dt('05/31/2014',             '2014-05-31 00:00:00.000', 'explicit numberformat 1000.00 explicit dateformat mm/dd/yy, no precision',          dateformat => 'mm/dd/yy', numberformat => '1000.00');
is_dt('05/31/2014 2',           '2014-05-31 02:00:00.000', 'explicit numberformat 1000.00 explicit dateformat mm/dd/yy, precision hour',        dateformat => 'mm/dd/yy', numberformat => '1000.00');
is_dt('05/31/2014 2:04',        '2014-05-31 02:04:00.000', 'explicit numberformat 1000.00 explicit dateformat mm/dd/yy, precision minute',      dateformat => 'mm/dd/yy', numberformat => '1000.00');
is_dt('05/31/2014 2:04:59',     '2014-05-31 02:04:59.000', 'explicit numberformat 1000.00 explicit dateformat mm/dd/yy, precision second',      dateformat => 'mm/dd/yy', numberformat => '1000.00');
is_dt('05/31/2014 02:4:59.098', '2014-05-31 02:04:59.098', 'explicit numberformat 1000.00 explicit dateformat mm/dd/yy, precision millisecond', dateformat => 'mm/dd/yy', numberformat => '1000.00');

done_testing;

1;
