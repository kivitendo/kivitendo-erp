use strict;

use Test::More;

use lib 't';
use Support::TestSetup;

Support::TestSetup::login();

use_ok 'SL::Auth';

ok( SL::Auth::evaluate_rights_ary(['1']), 'simple: right');
ok(!SL::Auth::evaluate_rights_ary(['0']), 'simple: no right');
ok( SL::Auth::evaluate_rights_ary(['1', '|', 0]), 'simple: or');
ok( SL::Auth::evaluate_rights_ary(['0', '|', '1']), 'simple: or 2');
ok(!SL::Auth::evaluate_rights_ary(['1', '&', '0']), 'simple: and');
ok(!SL::Auth::evaluate_rights_ary(['0', '&', '1']), 'simple: and 2');
ok( SL::Auth::evaluate_rights_ary(['1', '&', '1']), 'simple: and 3');
ok(!SL::Auth::evaluate_rights_ary(['!', '1']), 'simple: not');
ok( SL::Auth::evaluate_rights_ary(['!', '0']), 'simple: not 2');
ok(!SL::Auth::evaluate_rights_ary(['!', '!', '0']), 'simple: double not');
ok( SL::Auth::evaluate_rights_ary(['!', ['0']]), 'not 1');
ok(!SL::Auth::evaluate_rights_ary(['!', ['1']]), 'not 2');
ok( SL::Auth::evaluate_rights_ary(['!', '!', ['1']]), 'double not');
ok( SL::Auth::evaluate_rights_ary([ '!', ['!', ['1', '&', '1'], '&', '!', '!', ['1', '|', '!', '1']] ]), 'something more coplex');

done_testing;

1;
