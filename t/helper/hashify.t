use Test::More tests => 52;

use strict;

use lib 't';

use_ok 'SL::Util';

sub numtest {
  my @result = SL::Util::_hashify(@_);
  return scalar(@result);
}

sub memtest {
  my $key    = shift;
  my $keep   = $_[0];
  my @result = SL::Util::_hashify(@_);
  splice @result, 0, $keep;

  return '<empty>'     if !@result;
  return '<odd-sized>' if scalar(@result) % 2;

  my %hash = @result;
  return $hash{$key};
}

my $href = { 42 => 54, unicorn => 'charlie' };
my %hash = ( 23 => 13, chunky  => 'bacon'   );

is(numtest(0, $href), 4, 'case A1');
is(numtest(0, %hash), 4, 'case A2');
is(numtest(1, $href), 1, 'case A3');
is(numtest(1, %hash), 4, 'case A4');
is(numtest(2, $href), 1, 'case A5');
is(numtest(2, %hash), 4, 'case A6');
is(numtest(3, $href), 1, 'case A7');
is(numtest(3, %hash), 4, 'case A8');
is(numtest(4, $href), 1, 'case A9');
is(numtest(4, %hash), 4, 'case A10');
is(numtest(5, $href), 1, 'case A11');
is(numtest(5, %hash), 4, 'case A12');

is(numtest(0, 'dummy1', $href), 2, 'case B1');
is(numtest(0, 'dummy1', %hash), 5, 'case B2');
is(numtest(1, 'dummy1', $href), 5, 'case B3');
is(numtest(1, 'dummy1', %hash), 5, 'case B4');
is(numtest(2, 'dummy1', $href), 2, 'case B5');
is(numtest(2, 'dummy1', %hash), 5, 'case B6');
is(numtest(3, 'dummy1', $href), 2, 'case B7');
is(numtest(3, 'dummy1', %hash), 5, 'case B8');
is(numtest(4, 'dummy1', $href), 2, 'case B9');
is(numtest(4, 'dummy1', %hash), 5, 'case B10');
is(numtest(5, 'dummy1', $href), 2, 'case B11');
is(numtest(5, 'dummy1', %hash), 5, 'case B12');

is(numtest(0, 'dummy1', 'dummy2', $href), 3, 'case C1');
is(numtest(0, 'dummy1', 'dummy2', %hash), 6, 'case C2');
is(numtest(1, 'dummy1', 'dummy2', $href), 3, 'case C3');
is(numtest(1, 'dummy1', 'dummy2', %hash), 6, 'case C4');
is(numtest(2, 'dummy1', 'dummy2', $href), 6, 'case C5');
is(numtest(2, 'dummy1', 'dummy2', %hash), 6, 'case C6');
is(numtest(3, 'dummy1', 'dummy2', $href), 3, 'case C7');
is(numtest(3, 'dummy1', 'dummy2', %hash), 6, 'case C8');
is(numtest(4, 'dummy1', 'dummy2', $href), 3, 'case C9');
is(numtest(4, 'dummy1', 'dummy2', %hash), 6, 'case C10');
is(numtest(5, 'dummy1', 'dummy2', $href), 3, 'case C11');
is(numtest(5, 'dummy1', 'dummy2', %hash), 6, 'case C12');

is(memtest(42,        0, $href), '54',          'case D1');
is(memtest(23,        0, %hash), '13',          'case D2');
is(memtest('unicorn', 0, $href), 'charlie',     'case D3');
is(memtest('chunky',  0, %hash), 'bacon',       'case D4');
is(memtest(42,        1, $href), '<empty>',     'case D5');
is(memtest(23,        1, %hash), '<odd-sized>', 'case D6');

is(memtest(42,        0, 'dummy1', $href), undef,         'case E1');
is(memtest(23,        0, 'dummy1', %hash), '<odd-sized>', 'case E2');
is(memtest('unicorn', 0, 'dummy1', $href), undef,         'case E3');
is(memtest(42,        1, 'dummy1', $href), '54',          'case E4');
is(memtest(23,        1, 'dummy1', %hash), '13',          'case E5');
is(memtest('unicorn', 1, 'dymmy1', $href), 'charlie',     'case E6');
is(memtest('chunky',  1, 'dummy1', %hash), 'bacon',       'case E7');
is(memtest(42,        2, 'dummy1', $href), '<empty>',     'case E8');
is(memtest(23,        2, 'dummy1', %hash), '<odd-sized>', 'case E9');
