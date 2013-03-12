use Test::More tests => 14;
use Test::Exception;

use strict;

use lib 't';
use utf8;

use Data::Dumper;
use Support::TestSetup;

use_ok 'SL::PrefixedNumber';

sub n {
  return SL::PrefixedNumber->new(number => $_[0]);
}

is(n('FB4711'     )->get_next, 'FB4712',      'increment FB4711');
is(n('4711'       )->get_next, '4712',        'increment 4711');
is(n('FB54UFB4711')->get_next, 'FB54UFB4712', 'increment FB54UFB4711');
is(n('FB'         )->get_next, 'FB1',         'increment FB');
is(n(''           )->get_next, '1',           'increment ""');
is(n('0042-FB'    )->get_next, '0042-FB1',    'increment 0042-FB');
my $o = n('0042-FB');
$o->get_next;
is($o->get_next,               '0042-FB2',    'increment 0042-FB twice');

is(n('FB4711')->set_to(54), 'FB0054', 'set FB4711 to 54');
$o = n('FB4711');
$o->set_to(54);
is($o->get_next,            'FB0055', 'set FB4711 to 54 then increment');

is(n('FB121231')->get_current,                          'FB121231', 'set FB121231 get current');
is(n('FB121231')->format(42),                           'FB000042', 'set FB121231 format 42');
is(n('FB123123')->set_to_max('FB0711', 'FB911', 'FB8'), 'FB000911', 'set FB123123 max FB000911');

throws_ok { n()->get_next } qr/no.*number/i, 'get_next without number set';
