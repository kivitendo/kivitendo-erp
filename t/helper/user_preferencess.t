use Test::More;
use Test::Exception;
use Test::Deep qw(bag cmp_deeply);

use strict;
use lib 't';

use Support::TestSetup;
use_ok 'SL::Helper::UserPreferences';

Support::TestSetup::login();

my $prefs;
$prefs = new_ok 'SL::Helper::UserPreferences', [ current_version => 1 ];


$prefs->store('test1', "val");
$prefs->store('test2', "val2");

cmp_deeply [ $prefs->get_keys ], bag('test1', 'test2'), 'get_keys works';

is $prefs->get('test1'), 'val', 'get works';
is $prefs->get_tuple('test2')->{value}, 'val2', 'get tuple works';
is $prefs->get_all->[1]{value}, 'val2', 'get all works';
is scalar @{ $prefs->get_all }, 2, 'get all works 2';

$prefs = new_ok 'SL::Helper::UserPreferences', [
  current_version => 2,
  upgrade_callbacks => {
    2 => sub { my ($val) = @_; $val . ' in space!'; }
  }
];

is $prefs->get('test1'), 'val in space!', 'upgrading works';

$prefs = new_ok 'SL::Helper::UserPreferences', [ current_version => 2 ];
is $prefs->get('test1'), 'val in space!', 'auto store back works';

$prefs = new_ok 'SL::Helper::UserPreferences', [ current_version => 1, namespace => 'namespace2' ];
is $prefs->get('test1'), undef, 'other namespace does not find prior data';

$prefs->store('test1', "namespace2 test");
is $prefs->get('test1'), 'namespace2 test', 'other namespace finds data with same key';

$prefs = new_ok 'SL::Helper::UserPreferences', [ current_version => 2 ];
is $prefs->get('test1'), 'val in space!', 'original namepsace is not affected';

$prefs = new_ok 'SL::Helper::UserPreferences', [ current_version => 1, login => 'demo2' ];
$prefs->store('test1', "login test");

$prefs = new_ok 'SL::Helper::UserPreferences', [ current_version => 2 ];
is $prefs->get('test1'), 'val in space!', 'original login is not affected';

$prefs->store('test1', 'new value');
is scalar @{ $prefs->get_all }, 2, 'storing an existing value overwrites';

my @array = $prefs->get_all;
is scalar @array, 1, 'get_all in list context returns 1 element';
isa_ok $array[0], 'ARRAY', 'get_all in list context returns 1 arrayref';

$prefs = new_ok 'SL::Helper::UserPreferences', [ current_version => 1 ];
dies_ok { $prefs->get('test1') } 'reading newer version dies';

$prefs = new_ok 'SL::Helper::UserPreferences', [ current_version => 2 ];
$prefs->delete('test1');
is $prefs->get('test1'), undef, 'deleting works';

$prefs->delete_all;
is $prefs->get('test2'), undef, 'delete_all works';

done_testing;
