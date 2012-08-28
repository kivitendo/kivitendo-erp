use strict;
use Test::More;

use lib 't';

use_ok('SL::Form');
require_ok('SL::Form');


package LxDebugMock;
sub enter_sub {};
sub leave_sub {};

$main::lxdebug = bless({}, 'LxDebugMock');

package main;


my $form = Form->new();


my $config = {};


$config->{numberformat} = '1.000,00';

is($form->format_amount($config, '1e1', 2), '10,00', 'blaa');
is($form->format_amount($config, 1000, 2), '1.000,00', 'blaa');
is($form->format_amount($config, 1000.1234, 2), '1.000,12', 'blaa');
is($form->format_amount($config, 1000000000.1234, 2), '1.000.000.000,12', 'blaa');
is($form->format_amount($config, -1000000000.1234, 2), '-1.000.000.000,12', 'blaa');


$config->{numberformat} = '1,000.00';

is($form->format_amount($config, '1e1', 2), '10.00', 'blaa');
is($form->format_amount($config, 1000, 2), '1,000.00', 'blaa');
is($form->format_amount($config, 1000.1234, 2), '1,000.12', 'blaa');
is($form->format_amount($config, 1000000000.1234, 2), '1,000,000,000.12', 'blaa');
is($form->format_amount($config, -1000000000.1234, 2), '-1,000,000,000.12', 'blaa');

done_testing;

1;
