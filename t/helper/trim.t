use Test::More tests => 11;

use strict;
use utf8;

use lib 't';

use SL::Util qw(trim);

is(trim("hello"),               "hello",         "hello");
is(trim("hello "),              "hello",         "hello ");
is(trim(" hello"),              "hello",         " hello");
is(trim(" hello "),             "hello",         " hello ");
is(trim(" h el lo "),           "h el lo",       " h el lo ");
is(trim("\n\t\rh\nello"),       "h\nello",       "line feed, horizontal tab, carriage return; line feed within word");
is(trim("\x{a0}h\nello"),       "h\nello",       "non-breaking space");
is(trim("h\nello\n\t\r"),       "h\nello",       "line feed, horizontal tab, carriage return; line feed within word");
is(trim("h\nello\x{a0}"),       "h\nello",       "non-breaking space");
is(trim("h\ne\x{a0}llo\x{a0}"), "h\ne\x{a0}llo", "non-breaking space within word");
is(trim(undef),                 undef,           "undef");
