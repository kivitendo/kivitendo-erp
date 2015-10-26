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

is($::form->round_amount(64.475, 2), '64.48', '64.475 @ 2');
is($::form->round_amount(64.475, 1), '64.5',  '64.475 @ 1');
is($::form->round_amount(64.475, 0), '64',    '64.475 @ 0');

is($::form->round_amount(64.475499, 5), '64.4755', '64.475499 @ 5');
is($::form->round_amount(64.475499, 4), '64.4755', '64.475499 @ 4');
is($::form->round_amount(64.475499, 3), '64.475',  '64.475499 @ 3');
is($::form->round_amount(64.475499, 2), '64.48',   '64.475499 @ 2');
is($::form->round_amount(64.475499, 1), '64.5',    '64.475499 @ 1');
is($::form->round_amount(64.475499, 0), '64',      '64.475499 @ 0');

is($::form->round_amount(64.475999, 5), '64.476', '64.475999 @ 5');
is($::form->round_amount(64.475999, 4), '64.476', '64.475999 @ 4');
is($::form->round_amount(64.475999, 3), '64.476', '64.475999 @ 3');
is($::form->round_amount(64.475999, 2), '64.48',  '64.475999 @ 2');
is($::form->round_amount(64.475999, 1), '64.5',   '64.475999 @ 1');
is($::form->round_amount(64.475999, 0), '64',     '64.475999 @ 0');

is($::form->round_amount(44.9 * 0.75, 2), '33.68', '44.9 * 0.75 @ 2');
is($::form->round_amount(44.9 * 0.75, 1), '33.7',  '44.9 * 0.75 @ 1');
is($::form->round_amount(44.9 * 0.75, 0), '34',    '44.9 * 0.75 @ 0');

is($::form->round_amount(143.20, 2), '143.2', '143.20 @ 2');
is($::form->round_amount(143.20, 1), '143.2', '143.20 @ 1');
is($::form->round_amount(143.20, 0), '143',   '143.20 @ 0');

is($::form->round_amount(149.175, 2), '149.18', '149.175 @ 2');
is($::form->round_amount(149.175, 1), '149.2',  '149.175 @ 1');
is($::form->round_amount(149.175, 0), '149',    '149.175 @ 0');

is($::form->round_amount(198.90 * 0.75, 2), '149.18', '198.90 * 0.75 @ 2');
is($::form->round_amount(198.90 * 0.75, 1), '149.2',  '198.90 * 0.75 @ 1');
is($::form->round_amount(198.90 * 0.75, 0), '149',    '198.90 * 0.75 @ 0');

is($::form->round_amount(19610.975, 2), '19610.98', '19610.975 @ 2');

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

for my $sign (-1, 1) {
  for ("00000".."09999") {
    my $str = my $num = (99 * $sign) . $_;
    $num /= 100;                 # shift decimal
    $num /= 5; $num /= 3;        # calc a bit around
    $num *= 5; $num *= 3;        # dumdidum

    $str =~ s/(..)$/.$1/;       # insert dot
    $str =~ s/0+$//;            # remove trailing 0
    $str =~ s/\.$//;            # remove trailing .

    is $::form->round_amount($num, 2), $str, "round($num, 2) == $str";
  }
}

# what about number that might occur scientific notation?  yes we could just
# check round_amount(1e-12, 2) and watch it blow up, but where's the fun? lets
# check a few Cardano triplets. they are defined by:
#
# ∛(a + b√c) + ∛(a - b√c) - 1 = 0
#
# and the following are solutions for a,b,c:
# (2,1,5)
# (5,2,13)
# (8,3,21)
#
# now calc that, and see what our round makes of the remaining number near zero
#
for ([2,1,5], [5,2,13], [8,3,21]) {
  my ($a,$b,$c) = @$_;

  my $result = ($a + $b * sqrt $c)**(1/3) - ($b * sqrt($c) - $a)**(1/3) - 1;

  is $::form->round_amount($result, 2), '0', "$result => 0";
}

# round to any digit we like
my $pi = atan2 0, -1;
is $::form->round_amount($pi, 0),  '3',             "0 digits of π";
is $::form->round_amount($pi, 1),  '3.1',           "1 digit of π";
is $::form->round_amount($pi, 2),  '3.14',          "2 digits of π";
is $::form->round_amount($pi, 3),  '3.142',         "3 digits of π";
is $::form->round_amount($pi, 4),  '3.1416',        "4 digits of π";
is $::form->round_amount($pi, 5),  '3.14159',       "5 digits of π";
is $::form->round_amount($pi, 6),  '3.141593',      "6 digits of π";
is $::form->round_amount($pi, 7),  '3.1415927',     "7 digits of π";
is $::form->round_amount($pi, 8),  '3.14159265',    "8 digits of π";
is $::form->round_amount($pi, 9),  '3.141592654',   "9 digits of π";
is $::form->round_amount($pi, 10), '3.1415926536', "10 digits of π";

# A LOT of places:
is $::form->round_amount(1.2, 200), '1.2', '1.2 @ 200';

done_testing;

1;
