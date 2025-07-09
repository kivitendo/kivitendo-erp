use strict;

use Test::More;

use lib 't';
use Support::TestSetup;

Support::TestSetup::login();

use_ok 'SL::Menu';

#my $menu = SL::Menu->new('user');
my $menu = 'SL::Menu';

my %node;
$node{id} = 'test_node';

$node{access} = 'sales_quotation_edit';
ok($menu->parse_access_string(\%node), 'simple parse granted');

$node{access} = 'no such right';
ok(!$menu->parse_access_string(\%node), 'simple parse not granted');

$node{access} = 'sales_quotation_edit)';
eval {$menu->parse_access_string(\%node); ok(0, 'detect missing opening parenthesis'); 1} or do { ok(1, 'detect missing opening parenthesis'); };

$node{access} = '(sales_quotation_edit';
eval {$menu->parse_access_string(\%node); ok(0, 'detect missing closing parenthesis'); 1} or do { ok(1, 'detect missing closing parenthesis'); };

$node{access} = 'sales_quotation_edit-';
eval {$menu->parse_access_string(\%node); ok(0, 'detect unrecognized token'); 1} or do { ok(1, 'detect unrecognized token'); };

$node{access} = 'sales_order_edit & sales_quotation_edit';
ok($menu->parse_access_string(\%node), 'grant and grant');

$node{access} = 'no_such_right & sales_quotation_edit';
ok(!$menu->parse_access_string(\%node), 'not grant and grant');

$node{access} = 'no_such_right & no_such_right';
ok(!$menu->parse_access_string(\%node), 'not grant and not grant');

$node{access} = 'sales_order_edit|sales_quotation_edit';
ok($menu->parse_access_string(\%node), 'grant or grant');

$node{access} = 'no_such_right | sales_quotation_edit';
ok($menu->parse_access_string(\%node), 'not grant or grant');

$node{access} = 'no_such_right | no_such_right';
ok(!$menu->parse_access_string(\%node), 'not grant or not grant');

$node{access} = '(sales_quotation_edit & sales_order_edit | (no_such_right & sales_order_edit))';
ok($menu->parse_access_string(\%node), 'parenthesis 1');

$node{access} = '(no_such_right & sales_order_edit | (no_such_right & sales_order_edit))';
ok(!$menu->parse_access_string(\%node), 'parenthesis 2');

$node{access} = '!no_such_right';
ok($menu->parse_access_string(\%node), 'simple negation 1');

$node{access} = '!sales_order_edit';
ok(!$menu->parse_access_string(\%node), 'simple negation 2');

$node{access} = '!!sales_order_edit';
ok($menu->parse_access_string(\%node), 'double negation');

$node{access} = '(no_such_right & sales_order_edit | !(no_such_right & sales_order_edit))';
ok($menu->parse_access_string(\%node), 'parenthesis with negation 1');

$node{access} = '(no_such_right & sales_order_edit | (!no_such_right | !sales_order_edit))';
ok($menu->parse_access_string(\%node), 'parenthesis with negation 2');

done_testing;

1;
