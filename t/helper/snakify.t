use Test::More tests => 7;

use strict;

use lib 't';

use SL::Util qw(snakify);

is(snakify('Hello'),              'hello',                'Hello');
is(snakify('HelloWorld'),         'hello_world',          'helloWorld');
is(snakify('HelloWorld_'),        'hello_world_',         'helloWorld_');
is(snakify('charlieTheUnicorn'),  'charlie_the_unicorn',  'charlieTheUnicorn');
is(snakify('_CharlieTheUnicorn'), '_charlie_the_unicorn', '_CharlieTheUnicorn');
is(snakify('HEllo'),              'h_ello',               'HEllo');
is(snakify('HELlo'),              'h_e_llo',              'HELlo');
