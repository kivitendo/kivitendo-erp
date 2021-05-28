use Test::More tests => 25;

use lib 't';

use SL::X;

# check exception serialization

my @classes = qw(
  SL::X::DBError
  SL::X::Inventory::Allocation
  SL::X::ZUGFeRDValidation
);

# check basic mesage / error serialization

for my $error_class (@classes) {

  my $x = $error_class->new(message => "test message");

  is $x->error,   "test message", "$error_class(message): error works";
  is $x->message, "test message", "$error_class(message): message works";
  is "$x",        "test message", "$error_class(message): stringify works";

  my $x = $error_class->new(error => "test message");

  is $x->error,   "test message", "$error_class(error): error works";
  is $x->message, "test message", "$error_class(error): message works";
  is "$x",        "test message", "$error_class(error): stringify works";
}


# now create some classes with message templates and extra fields

my $x = SL::X::DBError->new(msg => "stuff", db_error => "broke");

is $x->error,   "stuff: broke", "template: error works";
is $x->message, "stuff: broke", "tempalte: message works";
is "$x",        "stuff: broke", "template: stringify works";


my $x = SL::X::Inventory::Allocation->new(code => "DEADCOFFEE", message => "something went wrong");

is $x->code,   "DEADCOFFEE", "extra fields work";



# check stack traces

sub a { b() }
sub b { c() }
sub c { d() }
sub d { e() }
sub e { f() }
sub f { SL::X::DBError->throw() }

eval {
  a();
} or do {
  if (my $e = SL::X::DBError->caught) {
    ok 1, "caught db error";
    ok $e->trace->as_string =~ /main::a/, "trace contains function a";
    ok $e->trace->as_string =~ /main::f/, "trace contains function f";

  } else {
    ok 0, "didn't catch db error";
  }
};
