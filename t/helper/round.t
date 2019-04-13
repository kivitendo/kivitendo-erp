use Test::More tests => 9;

use lib 't';

use SL::Helper::Number qw(:all);

use_ok 'Support::TestSetup';

Support::TestSetup::login();

is(_round_number('3.231',2),'3.23');
is(_round_number('3.234',2),'3.23');
is(_round_number('3.235',2),'3.24');
is(_round_number('5.786',2),'5.79');
is(_round_number('2.342',2),'2.34');
is(_round_number('1.2345',2),'1.23');
is(_round_number('8.2345',2),'8.23');
is(_round_number('8.2350',2),'8.24');
