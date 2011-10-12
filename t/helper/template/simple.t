#!/usr/bin/perl

use strict;
use lib 't';

use DateTime;
use Test::More;

use_ok qw(SL::Template::Simple);

my $t = SL::Template::Simple->new(form => {});

sub test ($$$$$) {
  my ($form, $template_array, $query, $result, $text) = @_;

  $t->{form} = bless $form, 'Form';
  $t->{form}->{TEMPLATE_ARRAYS} = $template_array  if $template_array;
  is_deeply $t->_get_loop_variable(@$query), $result, $text;
}

test { a => 1 }, {}, [ 'a', 0 ], 1, 'simple access';
test { }, { a => [ 1 ] }, [ 'a', 0, 0 ], 1, 'template access';
test { }, { a => [ 1..4 ] }, [ 'a', 0, 3 ], 4, 'template access > 1';
test { }, { a => [ [ 1 ] ] }, [ 'a', 0, 0, 0 ], 1, 'template access more than one layer';
test { }, { a => [ 1 ] }, [ 'a', 0, 3 ], undef, 'short circuit if array is missing';
test { a => 2 }, { a => [ 1 ] }, [ 'a', 0 ], 2, 'no template access ignores templates';
test { a => 2 }, { a => [ 1 ] }, [ 'a', 1 ], [ 1 ], 'array access returns array';

test { a => 2, TEMPLATE_ARRAY => [ a => [1] ] }, undef, [ 'a', 0, 0 ], 2 , 'wrong template_array gets ignored';
test { a => 2, TEMPLATE_ARRAY => 1 }, undef, [ 'a', 0, 0 ], 2 , 'wrong template_array gets ignored 2';

test { a => { b => 2 }, 'a.b' => 5 }, {}, [ 'a.b', 0 ], 2, 'dot access';
test { a => { b => { c => 5 } } }, {}, [ 'a.b.c', 0 ], 5, 'deep dot access';
test { a => { b => 2 } }, {}, [ 'a.b', 1 ], 2, 'dot access ignores array';
test { a => { b => 2 } }, { 'a.b' => 3 }, [ 'a.b', 0, 0 ], 2, 'dot access ignores template';

{ package LXOTestDummy; sub b { 5 } }
my $o = bless [], 'LXOTestDummy';

test { 'a.b' => 2, a => $o }, {}, [ 'a.b', 0 ], 5, 'dot object access';
test { 'a.b.b' => 2, a => { b => $o } }, {}, [ 'a.b.b', 0 ], 5, 'deep dot object access';
test { 'a.b.b' => 2, a => { b => $o } }, {}, [ 'a.c', 0 ], undef, 'dot hash does not shortcut';
test { 'a.b.b' => 2, a => { b => $o } }, {}, [ 'a.b.c', 0 ], '', 'dot object shortcuts to empty string';

test {}, { a => [ { b => 2 } ], 'a.b' => 5 },  [ 'a.b', 0, 0 ], 2, 'array dot access';
test {}, { a => [ { b => { c => 5 } } ] },  [ 'a.b.c', 0, 0 ], 5, 'array deep dot access';
test {}, { a => [ { b => 2 } ] }, [ 'a.b', 1, 0 ], 2, 'array dot access ignores array';
test { 'a.b' => 3 }, { a => [ { b => 2 } ] }, , [ 'a.b', 0, 0 ], 2, 'array dot access ignores template';

test {}, { a => [ $o ] },  [ 'a.b', 0, 0 ], 5, 'array dot object access';
test {}, { a => [ { b => $o } ] }, [ 'a.b.b', 0, 0 ], 5, 'array deep dot object access';
test {}, { a => [ { b => $o } ] },  [ 'a.c', 0, 0 ], undef, 'array dot hash does not shortcut';
test {}, { a => [ { b => $o } ] },  [ 'a.b.c', 0, 0 ], '', 'array dot object shortcuts to empty string';

done_testing();
