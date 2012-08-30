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

done_testing;

1;
