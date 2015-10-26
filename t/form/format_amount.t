use strict;
use Test::More;

use lib 't';
use Support::TestSetup;

Support::TestSetup::login();

my $config = {};

$config->{numberformat} = '1.000,00';

is($::form->format_amount($config, '1e1', 2), '10,00', 'format 1e1 (numberformat: 1.000,00)');
is($::form->format_amount($config, 1000, 2), '1.000,00', 'format 1000 (numberformat: 1.000,00)');
is($::form->format_amount($config, 1000.1234, 2), '1.000,12', 'format 1000.1234 (numberformat: 1.000,00)');
is($::form->format_amount($config, 1000000000.1234, 2), '1.000.000.000,12', 'format 1000000000.1234 (numberformat: 1.000,00)');
is($::form->format_amount($config, -1000000000.1234, 2), '-1.000.000.000,12', 'format -1000000000.1234 (numberformat: 1.000,00)');


$config->{numberformat} = '1,000.00';

is($::form->format_amount($config, '1e1', 2), '10.00', 'format 1e1 (numberformat: 1,000.00)');
is($::form->format_amount($config, 1000, 2), '1,000.00', 'format 1000 (numberformat: 1,000.00)');
is($::form->format_amount($config, 1000.1234, 2), '1,000.12', 'format 1000.1234 (numberformat: 1,000.00)');
is($::form->format_amount($config, 1000000000.1234, 2), '1,000,000,000.12', 'format 1000000000.1234 (numberformat: 1,000.00)');
is($::form->format_amount($config, -1000000000.1234, 2), '-1,000,000,000.12', 'format -1000000000.1234 (numberformat: 1,000.00)');

# negative places

is($::form->format_amount($config, 1.00045, -2), '1.00045', 'negative places');
is($::form->format_amount($config, 1.00045, -5), '1.00045', 'negative places 2');
is($::form->format_amount($config, 1, -2), '1.00', 'negative places 3');

# bugs amd edge cases
$config->{numberformat} = '1.000,00';

is($::form->format_amount({ numberformat => '1.000,00' }, 0.00005), '0,00005', 'messing with small numbers and no precision');
is($::form->format_amount({ numberformat => '1.000,00' }, undef), '0', 'undef');
is($::form->format_amount({ numberformat => '1.000,00' }, ''), '0', 'empty string');
is($::form->format_amount({ numberformat => '1.000,00' }, undef, 2), '0,00', 'undef with precision');
is($::form->format_amount({ numberformat => '1.000,00' }, '', 2), '0,00', 'empty string with prcesion');

is($::form->format_amount($config, 0.545, 0), '1', 'rounding up with precision 0');
is($::form->format_amount($config, -0.545, 0), '-1', 'neg rounding up with precision 0');

is($::form->format_amount($config, 1.00), '1', 'autotrim to 0 places');

is($::form->format_amount($config, 10), '10', 'autotrim does not harm integers');
is($::form->format_amount($config, 10, 2), '10,00' , 'autotrim does not harm integers 2');
is($::form->format_amount($config, 10, -2), '10,00' , 'autotrim does not harm integers 3');
is($::form->format_amount($config, 10, 0), '10', 'autotrim does not harm integers 4');

is($::form->format_amount($config, 0, 0), '0' , 'trivial zero');
is($::form->format_amount($config, -0.002, 2), '0,00' , 'negative zero');
is($::form->format_amount($config, -0.002, 3), '-0,002' , 'negative zero');

# dash stuff

$config->{numberformat} = '1.000,00';

is($::form->format_amount($config, -350, 2, '-'), '(350,00)', 'dash -');


done_testing;

1;
