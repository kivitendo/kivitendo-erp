use Test::More tests => 8;

use strict;

use lib 't';

use SL::Util qw(camelify);

is(camelify('hello'),                'Hello',             'hello');
is(camelify('hello_world'),          'HelloWorld',        'hello_world');
is(camelify('hello_world_'),         'HelloWorld_',       'hello_world_');
is(camelify('charlie_the_unicorn'),  'CharlieTheUnicorn', 'charlie_the_unicorn');
is(camelify('_charlie_the_unicorn'), 'CharlieTheUnicorn', '_charlie_the_unicorn');
is(camelify('hello__world'),         'HelloWorld',        'hello__world');
is(camelify('hELLO'),                'HELLO',             'hELLO');
is(camelify('hellO_worlD'),          'HellOWorlD',        'hellO_worlD');
