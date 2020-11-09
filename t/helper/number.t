use Test::More tests => 173;

use lib 't';

use SL::Helper::Number qw(:ALL);

use_ok 'Support::TestSetup';

Support::TestSetup::login();

# format

sub test_format {
  my ($expected, $amount, $places, $numberformat, $dash, $comment) = @_;

  my $other_numberformat = $numberformat eq '1.000,00' ? '1,000.00' : '1.000,00';

  is (_format_number($amount, $places, numberformat => $numberformat, dash => $dash), $expected, "$comment - explicit");

  {
    local $::myconfig{numberformat} = $other_numberformat;
    is (_format_number($amount, $places, numberformat => $numberformat, dash => $dash), $expected, "$comment - explicit with different numberformat");
  }
  {
    local $::myconfig{numberformat} = $numberformat;
    is (_format_number($amount, $places, dash => $dash), $expected, "$comment - implicit numberformat");
  }

  # test _format_total
  if (($places // 0) == 2) {
    is (_format_total($amount, numberformat => $numberformat, dash => $dash), $expected, "$comment - explicit");

    {
      local $::myconfig{numberformat} = $other_numberformat;
      is (_format_total($amount, numberformat => $numberformat, dash => $dash), $expected, "$comment - explicit with different numberformat");
    }
    {
      local $::myconfig{numberformat} = $numberformat;
      is (_format_total($amount, dash => $dash), $expected, "$comment - implicit numberformat");
    }
  }
}


test_format('10,00', '1e1', 2, '1.000,00', undef, 'format 1e1 (numberformat: 1.000,00)');
test_format('1.000,00', 1000, 2, '1.000,00', undef, 'format 1000 (numberformat: 1.000,00)');
test_format('1.000,12', 1000.1234, 2, '1.000,00', undef,  'format 1000.1234 (numberformat: 1.000,00)');
test_format('1.000.000.000,12', 1000000000.1234, 2, '1.000,00', undef, 'format 1000000000.1234 (numberformat: 1.000,00)');
test_format('-1.000.000.000,12', -1000000000.1234, 2, '1.000,00', undef, 'format -1000000000.1234 (numberformat: 1.000,00)');

test_format('10.00', '1e1', 2, '1,000.00', undef, 'format 1e1 (numberformat: 1,000.00)');
test_format('1,000.00', 1000, 2, '1,000.00', undef, 'format 1000 (numberformat: 1,000.00)');
test_format('1,000.12', 1000.1234, 2, '1,000.00', undef, 'format 1000.1234 (numberformat: 1,000.00)');
test_format('1,000,000,000.12', 1000000000.1234, 2, '1,000.00', undef, 'format 1000000000.1234 (numberformat: 1,000.00)');
test_format('-1,000,000,000.12', -1000000000.1234, 2, '1,000.00', undef, 'format -1000000000.1234 (numberformat: 1,000.00)');

# negative places

test_format('1.00045', 1.00045, -2, '1,000.00', undef, 'negative places');
test_format('1.00045', 1.00045, -5, '1,000.00', undef, 'negative places 2');
test_format('1.00', 1, -2, '1,000.00', undef, 'negative places 3');

# bugs amd edge cases
test_format('0,00005', 0.00005, undef, '1.000,00', undef, 'messing with small numbers and no precision');
test_format('0', undef, undef, '1.000,00', undef, 'undef');
test_format('0', '', undef, '1.000,00', undef, 'empty string');
test_format('0,00', undef, 2, '1.000,00', undef, 'undef with precision');
test_format('0,00', '', 2, '1.000,00', undef, 'empty string with prcesion');

test_format('1', 0.545, 0, '1.000,00', undef, 'rounding up with precision 0');
test_format('-1', -0.545, 0, '1.000,00', undef, 'neg rounding up with precision 0');

test_format('1', 1.00, undef, '1.000,00', undef, 'autotrim to 0 places');

test_format('10', 10, undef, '1.000,00', undef, 'autotrim does not harm integers');
test_format('10,00', 10, 2, '1.000,00', undef, 'autotrim does not harm integers 2');
test_format('10,00', 10, -2, '1.000,00', undef, 'autotrim does not harm integers 3');
test_format('10', 10, 0, '1.000,00', undef, 'autotrim does not harm integers 4');

test_format('0', 0, 0, '1.000,00', undef, 'trivial zero');
test_format('0,00', -0.002, 2, '1.000,00', undef, 'negative zero');
test_format('-0,002', -0.002, 3, '1.000,00', undef, 'negative zero');

# dash

test_format('(350,00)', -350, 2, '1.000,00', '-', 'dash -');

# parse

sub test_parse {
  my ($expected, $amount, $numberformat, $comment) = @_;

  my $other_numberformat = $numberformat eq '1.000,00' ? '1,000.00' : '1.000,00';

  is (_parse_number($amount, numberformat => $numberformat), $expected, "$comment - explicit");

  {
    local $::myconfig{numberformat} = $other_numberformat;
    is (_parse_number($amount, numberformat => $numberformat), $expected, "$comment - explicit with different numberformat");
  }
  {
    local $::myconfig{numberformat} = $numberformat;
    is (_parse_number($amount), $expected, "$comment - implicit numberformat");
  }
}


test_parse(12345,     '12345',        '1.000,00', '12345 (numberformat: 1.000,00)');
test_parse(1234.5,    '1.234,5',      '1.000,00', '1.234,5 (numberformat: 1.000,00)');
test_parse(9871234.5, '9.871.234,5',  '1.000,00', '9.871.234,5 (numberformat: 1.000,00)');
test_parse(1234.5,    '1234,5',       '1.000,00', '1234,5 (numberformat: 1.000,00)');
test_parse(12345,     '012345',       '1.000,00', '012345 (numberformat: 1.000,00)');
test_parse(1234.5,    '01.234,5',     '1.000,00', '01.234,5 (numberformat: 1.000,00)');
test_parse(1234.5,    '01234,5',      '1.000,00', '01234,5 (numberformat: 1.000,00)');
test_parse(9871234.5, '09.871.234,5', '1.000,00', '09.871.234,5 (numberformat: 1.000,00)');

# round

is(_round_number('3.231',2),'3.23');
is(_round_number('3.234',2),'3.23');
is(_round_number('3.235',2),'3.24');
is(_round_number('5.786',2),'5.79');
is(_round_number('2.342',2),'2.34');
is(_round_number('1.2345',2),'1.23');
is(_round_number('8.2345',2),'8.23');
is(_round_number('8.2350',2),'8.24');


is(_round_total('3.231'),'3.23');
is(_round_total('3.234'),'3.23');
is(_round_total('3.235'),'3.24');
is(_round_total('5.786'),'5.79');
is(_round_total('2.342'),'2.34');
is(_round_total('1.2345'),'1.23');
is(_round_total('8.2345'),'8.23');
is(_round_total('8.2350'),'8.24');
