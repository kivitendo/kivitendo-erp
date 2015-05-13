use strict;
use Test::More;

use lib 't';
use Support::TestSetup;

Support::TestSetup::login();

my $config = {};

# Positive numbers
$config->{numberformat} = '1.000,00';

is($::form->parse_amount($config, '12345'),        12345,     '12345 (numberformat: 1.000,00)');
is($::form->parse_amount($config, '1.234,5'),      1234.5,    '1.234,5 (numberformat: 1.000,00)');
is($::form->parse_amount($config, '9.871.234,5'),  9871234.5, '9.871.234,5 (numberformat: 1.000,00)');
is($::form->parse_amount($config, '1234,5'),       1234.5,    '1234,5 (numberformat: 1.000,00)');
is($::form->parse_amount($config, '012345'),       12345,     '012345 (numberformat: 1.000,00)');
is($::form->parse_amount($config, '01.234,5'),     1234.5,    '01.234,5 (numberformat: 1.000,00)');
is($::form->parse_amount($config, '01234,5'),      1234.5,    '01234,5 (numberformat: 1.000,00)');
is($::form->parse_amount($config, '09.871.234,5'), 9871234.5, '09.871.234,5 (numberformat: 1.000,00)');

$config->{numberformat} = '1000,00';

is($::form->parse_amount($config, '12345'),        12345,     '12345 (numberformat: 1000,00)');
is($::form->parse_amount($config, '1.234,5'),      1234.5,    '1.234,5 (numberformat: 1000,00)');
is($::form->parse_amount($config, '9.871.234,5'),  9871234.5, '9.871.234,5 (numberformat: 1000,00)');
is($::form->parse_amount($config, '1234,5'),       1234.5,    '1234,5 (numberformat: 1000,00)');
is($::form->parse_amount($config, '012345'),       12345,     '012345 (numberformat: 1000,00)');
is($::form->parse_amount($config, '01.234,5'),     1234.5,    '01.234,5 (numberformat: 1000,00)');
is($::form->parse_amount($config, '01234,5'),      1234.5,    '01234,5 (numberformat: 1000,00)');
is($::form->parse_amount($config, '09.871.234,5'), 9871234.5, '09.871.234,5 (numberformat: 1000,00)');

$config->{numberformat} = '1,000.00';

is($::form->parse_amount($config, '12345'),        12345,     '12345 (numberformat: 1,000.00)');
is($::form->parse_amount($config, '1,234.5'),      1234.5,    '1,234.5 (numberformat: 1,000.00)');
is($::form->parse_amount($config, '9,871,234.5'),  9871234.5, '9,871,234,5 (numberformat: 1,000.00)');
is($::form->parse_amount($config, '1234.5'),       1234.5,    '1234.5 (numberformat: 1,000.00)');
is($::form->parse_amount($config, '012345'),       12345,     '012345 (numberformat: 1,000.00)');
is($::form->parse_amount($config, '01,234.5'),     1234.5,    '01,234.5 (numberformat: 1,000.00)');
is($::form->parse_amount($config, '01234.5'),      1234.5,    '01234.5 (numberformat: 1,000.00)');
is($::form->parse_amount($config, '09,871,234.5'), 9871234.5, '09,871,234,5 (numberformat: 1,000.00)');

$config->{numberformat} = '1000.00';

is($::form->parse_amount($config, '12345'),        12345,     '12345 (numberformat: 1000.00)');
is($::form->parse_amount($config, '1,234.5'),      1234.5,    '1,234.5 (numberformat: 1000.00)');
is($::form->parse_amount($config, '9,871,234.5'),  9871234.5, '9,871,234,5 (numberformat: 1000.00)');
is($::form->parse_amount($config, '1234.5'),       1234.5,    '1234.5 (numberformat: 1000.00)');
is($::form->parse_amount($config, '012345'),       12345,     '012345 (numberformat: 1000.00)');
is($::form->parse_amount($config, '01,234.5'),     1234.5,    '01,234.5 (numberformat: 1000.00)');
is($::form->parse_amount($config, '01234.5'),      1234.5,    '01234.5 (numberformat: 1000.00)');
is($::form->parse_amount($config, '09,871,234.5'), 9871234.5, '09,871,234,5 (numberformat: 1000.00)');

# Negative numbers
$config->{numberformat} = '1.000,00';

is($::form->parse_amount($config, '-12345'),        -12345,     '-12345 (numberformat: 1.000,00)');
is($::form->parse_amount($config, '-1.234,5'),      -1234.5,    '-1.234,5 (numberformat: 1.000,00)');
is($::form->parse_amount($config, '-9.871.234,5'),  -9871234.5, '-9.871.234,5 (numberformat: 1.000,00)');
is($::form->parse_amount($config, '-1234,5'),       -1234.5,    '-1234,5 (numberformat: 1.000,00)');
is($::form->parse_amount($config, '-012345'),       -12345,     '-012345 (numberformat: 1.000,00)');
is($::form->parse_amount($config, '-01.234,5'),     -1234.5,    '-01.234,5 (numberformat: 1.000,00)');
is($::form->parse_amount($config, '-01234,5'),      -1234.5,    '-01234,5 (numberformat: 1.000,00)');
is($::form->parse_amount($config, '-09.871.234,5'), -9871234.5, '-09.871.234,5 (numberformat: 1.000,00)');

$config->{numberformat} = '1000,00';

is($::form->parse_amount($config, '-12345'),        -12345,     '-12345 (numberformat: 1000,00)');
is($::form->parse_amount($config, '-1.234,5'),      -1234.5,    '-1.234,5 (numberformat: 1000,00)');
is($::form->parse_amount($config, '-9.871.234,5'),  -9871234.5, '-9.871.234,5 (numberformat: 1000,00)');
is($::form->parse_amount($config, '-1234,5'),       -1234.5,    '-1234,5 (numberformat: 1000,00)');
is($::form->parse_amount($config, '-012345'),       -12345,     '-012345 (numberformat: 1000,00)');
is($::form->parse_amount($config, '-01.234,5'),     -1234.5,    '-01.234,5 (numberformat: 1000,00)');
is($::form->parse_amount($config, '-01234,5'),      -1234.5,    '-01234,5 (numberformat: 1000,00)');
is($::form->parse_amount($config, '-09.871.234,5'), -9871234.5, '-09.871.234,5 (numberformat: 1000,00)');

$config->{numberformat} = '1,000.00';

is($::form->parse_amount($config, '-12345'),        -12345,     '-12345 (numberformat: 1,000.00)');
is($::form->parse_amount($config, '-1,234.5'),      -1234.5,    '-1,234.5 (numberformat: 1,000.00)');
is($::form->parse_amount($config, '-9,871,234.5'),  -9871234.5, '-9,871,234,5 (numberformat: 1,000.00)');
is($::form->parse_amount($config, '-1234.5'),       -1234.5,    '-1234.5 (numberformat: 1,000.00)');
is($::form->parse_amount($config, '-012345'),       -12345,     '-012345 (numberformat: 1,000.00)');
is($::form->parse_amount($config, '-01,234.5'),     -1234.5,    '-01,234.5 (numberformat: 1,000.00)');
is($::form->parse_amount($config, '-01234.5'),      -1234.5,    '-01234.5 (numberformat: 1,000.00)');
is($::form->parse_amount($config, '-09,871,234.5'), -9871234.5, '-09,871,234,5 (numberformat: 1,000.00)');

$config->{numberformat} = '1000.00';

is($::form->parse_amount($config, '-12345'),        -12345,     '-12345 (numberformat: 1000.00)');
is($::form->parse_amount($config, '-1,234.5'),      -1234.5,    '-1,234.5 (numberformat: 1000.00)');
is($::form->parse_amount($config, '-9,871,234.5'),  -9871234.5, '-9,871,234,5 (numberformat: 1000.00)');
is($::form->parse_amount($config, '-1234.5'),       -1234.5,    '-1234.5 (numberformat: 1000.00)');
is($::form->parse_amount($config, '-012345'),       -12345,     '-012345 (numberformat: 1000.00)');
is($::form->parse_amount($config, '-01,234.5'),     -1234.5,    '-01,234.5 (numberformat: 1000.00)');
is($::form->parse_amount($config, '-01234.5'),      -1234.5,    '-01234.5 (numberformat: 1000.00)');
is($::form->parse_amount($config, '-09,871,234.5'), -9871234.5, '-09,871,234,5 (numberformat: 1000.00)');

# Calculations
$config->{numberformat} = '1.000,00';

is($::form->parse_amount($config, '47/2+3,5*(4+5)'),                  55,    '47/2+3,5*(4+5) (numberformat: 1.000,00)');
is($::form->parse_amount($config, '047/002+003,05*(04+000005)'),      50.95, '047/002+003,05*(04+000005) (numberformat: 1.000,00)');
is($::form->parse_amount($config, '47 / 2+       3,5*( 4 + 5)'),      55,    '47 / 2+       3.,*( 4 + 5) (numberformat: 1.000,00)');
is($::form->parse_amount($config, '047/ 002+ 003,05 * (04 +000005)'), 50.95, '047/ 002+ 003,05 * (04 +000005) (numberformat: 1.000,00)');

$config->{numberformat} = '1,000.00';

is($::form->parse_amount($config, '47/2+3.5*(4+5)'),                  55,    '47/2+3.5*(4+5) (numberformat: 1,000.00)');
is($::form->parse_amount($config, '047/002+003.05*(04+000005)'),      50.95, '047/002+003.05*(04+000005) (numberformat: 1,000.00)');
is($::form->parse_amount($config, '47 / 2+       3.5*( 4 + 5)'),      55,    '47 / 2+       3.5*( 4 + 5) (numberformat: 1,000.00)');
is($::form->parse_amount($config, '047/ 002+ 003.05 * (04 +000005)'), 50.95, '047/ 002+ 003.05 * (04 +000005) (numberformat: 1,000.00)');

# Weird edge cases

$config->{numberformat} = '1.000,00';

is($::form->parse_amount($config, '-0+1'), 1, '-0+1 (numberformat: 1.000,00)');
is($::form->parse_amount($config, '-0+9'), 9, '-0+9 (numberformat: 1.000,00)');
is($::form->parse_amount($config, '20*0'), 0, '20*0 (numberformat: 1.000,00)');
is($::form->parse_amount($config, '20*0123'), 2460, '20*0123 (numberformat: 1.000,00)');
is($::form->parse_amount($config, '010+010'), 20, '010+010 (numberformat: 1.000,00)');
is($::form->parse_amount($config, '+(010*2)'), 20, '+(010*2) (numberformat: 1.000,00)');

done_testing;

1;
