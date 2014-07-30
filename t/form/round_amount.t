use strict;
use Test::More;

use lib 't';
use Support::TestSetup;

Support::TestSetup::login();

my $config = {};

$config->{numberformat} = '1.000,00';

# Positive values
is($::form->round_amount(1.05, 2), '1.05', '1.05 @ 2');
is($::form->round_amount(1.05, 1), '1.1',  '1.05 @ 1');
is($::form->round_amount(1.05, 0), '1',    '1.05 @ 0');

is($::form->round_amount(1.045, 2), '1.05', '1.045 @ 2');
is($::form->round_amount(1.045, 1), '1',    '1.045 @ 1');
is($::form->round_amount(1.045, 0), '1',    '1.045 @ 0');

is($::form->round_amount(33.675, 2), '33.68', '33.675 @ 2');
is($::form->round_amount(33.675, 1), '33.7',  '33.675 @ 1');
is($::form->round_amount(33.675, 0), '34',    '33.675 @ 0');

is($::form->round_amount(44.9 * 0.75, 2), '33.68', '44.9 * 0.75 @ 2');
is($::form->round_amount(44.9 * 0.75, 1), '33.7',  '44.9 * 0.75 @ 1');
is($::form->round_amount(44.9 * 0.75, 0), '34',    '44.9 * 0.75 @ 0');

is($::form->round_amount(149.175, 2), '149.18', '149.175 @ 2');
is($::form->round_amount(149.175, 1), '149.2',  '149.175 @ 1');
is($::form->round_amount(149.175, 0), '149',    '149.175 @ 0');

is($::form->round_amount(198.90 * 0.75, 2), '149.18', '198.90 * 0.75 @ 2');
is($::form->round_amount(198.90 * 0.75, 1), '149.2',  '198.90 * 0.75 @ 1');
is($::form->round_amount(198.90 * 0.75, 0), '149',    '198.90 * 0.75 @ 0');

# Negative values
is($::form->round_amount(-1.05, 2), '-1.05', '-1.05 @ 2');
is($::form->round_amount(-1.05, 1), '-1.1',  '-1.05 @ 1');
is($::form->round_amount(-1.05, 0), '-1',    '-1.05 @ 0');

is($::form->round_amount(-1.045, 2), '-1.05', '-1.045 @ 2');
is($::form->round_amount(-1.045, 1), '-1',    '-1.045 @ 1');
is($::form->round_amount(-1.045, 0), '-1',    '-1.045 @ 0');

is($::form->round_amount(-33.675, 2), '-33.68', '33.675 @ 2');
is($::form->round_amount(-33.675, 1), '-33.7',  '33.675 @ 1');
is($::form->round_amount(-33.675, 0), '-34',    '33.675 @ 0');

is($::form->round_amount(-44.9 * 0.75, 2), '-33.68', '-44.9 * 0.75 @ 2');
is($::form->round_amount(-44.9 * 0.75, 1), '-33.7',  '-44.9 * 0.75 @ 1');
is($::form->round_amount(-44.9 * 0.75, 0), '-34',    '-44.9 * 0.75 @ 0');

is($::form->round_amount(-149.175, 2), '-149.18', '-149.175 @ 2');
is($::form->round_amount(-149.175, 1), '-149.2',  '-149.175 @ 1');
is($::form->round_amount(-149.175, 0), '-149',    '-149.175 @ 0');

is($::form->round_amount(-198.90 * 0.75, 2), '-149.18', '-198.90 * 0.75 @ 2');
is($::form->round_amount(-198.90 * 0.75, 1), '-149.2',  '-198.90 * 0.75 @ 1');
is($::form->round_amount(-198.90 * 0.75, 0), '-149',    '-198.90 * 0.75 @ 0');

done_testing;

1;
