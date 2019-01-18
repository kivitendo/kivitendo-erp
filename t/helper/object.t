use strict;
use Test::More tests => 37;

use lib 't';

# to test delegate, test a few of these combinations:
#   target_class or object
#   target_method given or not
#   object or class invocation

{ package T::Helper::Object::Delegatee;
  sub test_simple { "simple" }
  sub test_class { "classic" }
  sub test_invocation { (ref $_[0] ? ref $_[0] : $_[0]) eq __PACKAGE__ }
  sub test_method { !!ref $_[0] }
  sub test_wantarray {
    if (!defined wantarray) {
      ${$_[1]} = 'void';
    } else {
      ${$_[1]} = wantarray ? 'list' : 'scalar';
    }
  }
  sub args { @_ }
}
my $delegatee = bless {}, "T::Helper::Object::Delegatee";

{
  package T::Helper::Object::Test1;
  use SL::Helper::Object (
    delegate => [
      obj => [ "test_simple", "test_invocation", "test_method", "test_wantarray", "args" ],
      obj => [ { target_method => "test_simple" }, "test_simple_renamed" ],
      "T::Helper::Object::Delegatee" => [ "test_class" ],
      "T::Helper::Object::Delegatee" => [ { target_method => "test_class" }, "test_class_renamed" ],
      "T::Helper::Object::Delegatee" => [ { target_method => "test_invocation" }, "test_class_invocation" ],
      "T::Helper::Object::Delegatee" => [ { target_method => "test_method" }, "test_function" ],
      obj => [ { target_method => 'test_wantarray', force_context => 'void' },   'test_void_context' ],
      obj => [ { target_method => 'test_wantarray', force_context => 'scalar' }, 'test_scalar_context' ],
      obj => [ { target_method => 'test_wantarray', force_context => 'list' },   'test_list_context' ],
      obj => [ { target_method => 'args', args => 'none' }, 'no_args' ],
      obj => [ { target_method => 'args', args => 'raw' }, 'raw_args' ],
      obj => [ { target_method => 'args', args => 'standard' }, 'standard_args' ],
      "T::Helper::Object::Delegatee" => [ { target_method => "args", args => 'raw' }, "raw_class_args" ],
      "T::Helper::Object::Delegatee" => [ { target_method => "args", args => 'standard' }, "standard_class_args" ],
      "T::Helper::Object::Delegatee" => [ { target_method => "args", args => 'standard', class_function => 1 }, "class_function_args" ],
    ],
  );
  sub obj { $_[0]{obj} }
};
my $obj1 = bless { obj => $delegatee }, "T::Helper::Object::Test1";

is $obj1->test_simple,           'simple',  'simple delegation works';
is $obj1->test_simple_renamed,   'simple',  'renamed delegation works';
is $obj1->test_class,            'classic', 'class delegation works';
is $obj1->test_class_renamed,    'classic', 'renamed class delegation works';
ok $obj1->test_invocation,       'object invocation works';
ok $obj1->test_class_invocation, 'class invocation works';
ok $obj1->test_method,           'method invocation works';
ok !$obj1->test_function,        'function invocation works';


#  3: args in [ none, raw,standard ]

is scalar $obj1->no_args("test"), 1, 'args none ignores args';
is [$obj1->raw_args("test")]->[0], $delegatee, 'args raw 1';
is [$obj1->raw_args("test")]->[1], $obj1,      'args raw 2';
is [$obj1->raw_args("test")]->[2], "test",     'args raw 3';
is scalar $obj1->raw_args("test"), 3, 'args raw args list';
is [$obj1->standard_args("test")]->[0], $delegatee, 'args standard 1';
is [$obj1->standard_args("test")]->[1], "test",     'args standard 1';
is scalar $obj1->standard_args("test"), 2, 'args standard args list';

is [$obj1->raw_class_args("test")]->[0], ref $delegatee, 'args raw 1';
is [$obj1->raw_class_args("test")]->[1], $obj1,          'args raw 2';
is [$obj1->raw_class_args("test")]->[2], "test",         'args raw 3';
is scalar $obj1->raw_class_args("test"), 3, 'args raw args list';
is [$obj1->standard_class_args("test")]->[0], ref $delegatee, 'args standard 1';
is [$obj1->standard_class_args("test")]->[1], "test",         'args standard 1';
is scalar $obj1->standard_class_args("test"), 2, 'args standard args list';

is [$obj1->class_function_args("test")]->[0], 'test', 'args class function standard 1';
is scalar $obj1->class_function_args("test"), 1, 'args class function standard args list';


#  4: force_context [ none, void, scalar, list ]

my $c;
$c = ''; $obj1->test_void_context(\$c);   is $c, 'void',   'force context void works';
$c = ''; $obj1->test_scalar_context(\$c); is $c, 'scalar', 'force context scalar works';
$c = ''; $obj1->test_list_context(\$c);   is $c, 'list',   'force context list works';

# and without forcing:
$c = ''; $obj1->test_wantarray(\$c);            is $c, 'void',   'natural context void works';
$c = ''; my $test = $obj1->test_wantarray(\$c); is $c, 'scalar', 'natural context scalar works';
$c = ''; my @test = $obj1->test_wantarray(\$c); is $c, 'list',   'natural context list works';


# try stupid stuff that should die

my $dies = 1;
eval { package T::Helper::Object::Test2;
  SL::Helper::Object->import(
    delegate => [ one => [], "two" ],
  );
  $dies = 0;
  1;
};
ok $dies, 'delegate with uneven number of args dies';

$dies = 1;
eval { package T::Helper::Object::Test3;
  SL::Helper::Object->import(
    delegate => {},
  );
  $dies = 0;
  1;
};
ok $dies, 'delegate with hashref dies';

$dies = 1;
eval { package T::Helper::Object::Test4;
  SL::Helper::Object->import(
    delegate => [
      "List::Util" => [ '{}; print "gotcha"' ],
    ],
  );
  $dies = 0;
  1;
};
ok $dies, 'code injection in method names dies';

$dies = 1;
eval { package T::Helper::Object::Test5;
  SL::Helper::Object->import(
    delegate => [
      "print 'this'" => [ 'test' ],
    ],
  );
  $dies = 0;
  1;
};
ok $dies, 'code injection in target dies';

$dies = 1;
eval { package T::Helper::Object::Test6;
  SL::Helper::Object->import(
    delegate => [
      "List::Util" => [ { target_method => 'system()' }, 'test' ],
    ],
  );
  $dies = 0;
  1;
};
ok $dies, 'code injection in target_method dies';

$dies = 1;
eval { package T::Helper::Object::Test6;
  SL::Helper::Object->import(
    delegate => [
      "List::Util" => [ { target_name => 'test2' }, 'test' ],
    ],
  );
  $dies = 0;
  1;
};
ok $dies, 'unknown parameter dies';

1;
