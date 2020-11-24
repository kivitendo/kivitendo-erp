package AttrDurationTestDummy;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'dummy',
  columns => [
    dummy => { type => 'numeric', precision => 2, scale => 12 },
    inty  => { type => 'integer' },
    miny  => { type => 'integer' },
  ]
);

use SL::DB::Helper::AttrDuration;

__PACKAGE__->attr_duration('dummy');
__PACKAGE__->attr_duration_minutes('inty', 'miny');

package main;

use Test::More tests => 130;
use Test::Exception;

use strict;

use lib 't';
use utf8;

use Data::Dumper;
use Support::TestSetup;
use SL::Locale;

sub new_item {
  return AttrDurationTestDummy->new(@_);
}

Support::TestSetup::login();
my $item;

$::locale = Locale->new('en');

### attr_duration

# Wenn das Attribut undef ist:
is(new_item->dummy,                    undef,  'uninitialized: raw');
is(new_item->dummy_as_hours,           0,      'uninitialized: as_hours');
is(new_item->dummy_as_minutes,         0,      'uninitialized: as_minutes');
is(new_item->dummy_as_duration_string, undef,  'uninitialized: as_duration_string');
is(new_item->dummy_as_man_days,        0,      'uninitialized: as_man_days');
is(new_item->dummy_as_man_days_unit,   'h',    'uninitialized: as_man_days_unit');
is(new_item->dummy_as_man_days_string, '0,00', 'uninitialized: as_man_days_string');

# Auslesen kleiner 8 Stunden:
is(new_item(dummy => 2.75)->dummy,                    2.75,   'initialized < 8: raw');
is(new_item(dummy => 2.75)->dummy_as_hours,           2,      'initialized < 8: as_hours');
is(new_item(dummy => 2.75)->dummy_as_minutes,         45,     'initialized < 8: as_minutes');
is(new_item(dummy => 2.75)->dummy_as_duration_string, '2,75', 'initialized < 8: as_duration_string');
is(new_item(dummy => 2.75)->dummy_as_man_days,        2.75,   'initialized < 8: as_man_days');
is(new_item(dummy => 2.75)->dummy_as_man_days_unit,   'h',    'initialized < 8: as_man_days_unit');
is(new_item(dummy => 2.75)->dummy_as_man_days_string, '2,75', 'initialized < 8: as_man_days_string');

# Auslesen größer 8 Stunden:
is(new_item(dummy => 12.5)->dummy,                    12.5,      'initialized > 8: raw');
is(new_item(dummy => 12.5)->dummy_as_hours,           12,        'initialized > 8: as_hours');
is(new_item(dummy => 12.5)->dummy_as_minutes,         30,        'initialized > 8: as_minutes');
is(new_item(dummy => 12.5)->dummy_as_duration_string, '12,50',   'initialized > 8: as_duration_string');
is(new_item(dummy => 12.5)->dummy_as_man_days,        1.5625,    'initialized > 8: as_man_days');
is(new_item(dummy => 12.5)->dummy_as_man_days_unit,   'man_day', 'initialized > 8: as_man_days_unit');
is(new_item(dummy => 12.5)->dummy_as_man_days_string, '1,56',    'initialized > 8: as_man_days_string');

$item = new_item(dummy => 2.25); $item->dummy_as_duration_string(undef);
is($item->dummy,                    undef, 'write as_duration_string undef read raw');
is($item->dummy_as_minutes,         0,     'write as_duration_string undef read as_minutes');
is($item->dummy_as_hours,           0,     'write as_duration_string undef read as_hours');
is($item->dummy_as_duration_string, undef, 'write as_duration_string undef read as_duration_string');

$item = new_item(dummy => 2.25); $item->dummy_as_duration_string("4,80");
is($item->dummy,                    4.8,    'write as_duration_string 4,80 read raw');
is($item->dummy_as_minutes,         48,     'write as_duration_string 4,80 read as_minutes');
is($item->dummy_as_hours,           4,      'write as_duration_string 4,80 read as_hours');
is($item->dummy_as_duration_string, "4,80", 'write as_duration_string 4,80 read as_duration_string');

$item = new_item(dummy => 2.25); $item->dummy_as_minutes(12);
is($item->dummy,                    2.2,    'write as_minutes 12 read raw');
is($item->dummy_as_minutes,         12,     'write as_minutes 12 read as_minutes');
is($item->dummy_as_hours,           2,      'write as_minutes 12 read as_hours');
is($item->dummy_as_duration_string, "2,20", 'write as_minutes 12 read as_duration_string');

$item = new_item(dummy => 2.25); $item->dummy_as_hours(5);
is($item->dummy,                    5.25,   'write as_hours 5 read raw');
is($item->dummy_as_minutes,         15,     'write as_hours 5 read as_minutes');
is($item->dummy_as_hours,           5,      'write as_hours 5 read as_hours');
is($item->dummy_as_duration_string, "5,25", 'write as_hours 5 read as_duration_string');

$item = new_item(dummy => undef);
is($item->dummy,                    undef,  'write raw undef read raw');
is($item->dummy_as_man_days,        0,      'write raw undef read as_man_days');
is($item->dummy_as_man_days_unit,   'h',    'write raw undef read as_man_days_unit');
is($item->dummy_as_man_days_string, '0,00', 'write raw undef read as_man_days_string');

$item = new_item(dummy => 4);
is($item->dummy,                    4,      'write raw 4 read raw');
is($item->dummy_as_man_days,        4,      'write raw 4 read as_man_days');
is($item->dummy_as_man_days_unit,   'h',    'write raw 4 read as_man_days_unit');
is($item->dummy_as_man_days_string, '4,00', 'write raw 4 read as_man_days_string');

$item = new_item(dummy => 18);
is($item->dummy,                    18,        'write raw 18 read raw');
is($item->dummy_as_man_days,        2.25,      'write raw 18 read as_man_days');
is($item->dummy_as_man_days_unit,   'man_day', 'write raw 18 read as_man_days_unit');
is($item->dummy_as_man_days_string, '2,25',    'write raw 18 read as_man_days_string');

$item = new_item(dummy => 4);
is($item->dummy,                           4,     'should not change anything when writing undef: write raw 4 read raw');
is($item->dummy_as_man_days(undef),        undef, 'should not change anything when writing undef: write as_man_days undef return undef');
is($item->dummy,                           4,     'should not change anything when writing undef: read raw 2');
is($item->dummy_as_man_days_unit(undef),   undef, 'should not change anything when writing undef: write as_man_days_unit undef return undef');
is($item->dummy,                           4,     'should not change anything when writing undef: read raw 3');
is($item->dummy_as_man_days_string(undef), undef, 'should not change anything when writing undef: write as_man_days_string undef return undef');
is($item->dummy,                           4,     'should not change anything when writing undef: read raw 4');


$item = new_item;
is($item->dummy(2),                        2,      'parse less than a man day: write raw 2 read raw');
is($item->dummy_as_man_days(0.75),         0.75,   'parse less than a man day: write as_man_days 0.75 read as_man_days');
is($item->dummy_as_man_days_string('0,5'), '0,50', 'parse less than a man day: write as_man_days_string 0,5 read read as_man_days_string');

$item = new_item;
is($item->dummy(12),                        12,      'parse more than a man day: write raw 12 read raw');
is($item->dummy_as_man_days(13.25),         1.65625, 'parse more than a man day: write as_man_days 13.25 read as_man_days');
is($item->dummy_as_man_days_string('13,5'), '1,69',  'parse more than a man day: write as_man_days_string 13,5 read read as_man_days_string');

$item = new_item;
is($item->dummy(3.25),                 3.25, 'parse less than a man day with unit h: write raw 3.25 read raw');
is($item->dummy_as_man_days_unit('h'), 'h',  'parse less than a man day with unit h: write as_man_days_unit h read as_man_days_unit');
is($item->dummy,                       3.25, 'parse less than a man day with unit h: read raw');

$item = new_item;
is($item->dummy(3.25),                    3.25, 'parse less than a man day with unit hour: write raw 3.25 read raw');
is($item->dummy_as_man_days_unit('hour'), 'h',  'parse less than a man day with unit hour: write as_man_days_unit hour read as_man_days_unit');
is($item->dummy,                          3.25, 'parse less than a man day with unit hour: read raw');

$item = new_item;
is($item->dummy(3.25),                       3.25,      'parse more than a man day with unit man_day: write raw 3.25 read raw');
is($item->dummy_as_man_days_unit('man_day'), 'man_day', 'parse more than a man day with unit man_day: write as_man_days_unit man_day read as_man_days_unit');
is($item->dummy,                             26,        'parse more than a man day with unit man_day: read raw');

is(new_item->assign_attributes(dummy_as_man_days      => 3,         dummy_as_man_days_unit => 'h')->dummy,       3,  'assign_attributes hash 3h');
is(new_item->assign_attributes(dummy_as_man_days_unit => 'h',       dummy_as_man_days      => 3  )->dummy,       3,  'assign_attributes hash h3');

is(new_item->assign_attributes(dummy_as_man_days      => 3,         dummy_as_man_days_unit => 'man_day')->dummy, 24, 'assign_attributes hash 3man_day');
is(new_item->assign_attributes(dummy_as_man_days_unit => 'man_day', dummy_as_man_days      => 3        )->dummy, 24, 'assign_attributes hash man_day3');

is(new_item->assign_attributes('dummy_as_man_days',      3,         'dummy_as_man_days_unit', 'h')->dummy,       3,  'assign_attributes array 3h');
is(new_item->assign_attributes('dummy_as_man_days_unit', 'h',       'dummy_as_man_days',      3  )->dummy,       3,  'assign_attributes array h3');

is(new_item->assign_attributes('dummy_as_man_days',      3,         'dummy_as_man_days_unit', 'man_day')->dummy, 24, 'assign_attributes array 3man_day');
is(new_item->assign_attributes('dummy_as_man_days_unit', 'man_day', 'dummy_as_man_days',      3        )->dummy, 24, 'assign_attributes array man_day3');

is(new_item->assign_attributes(dummy_as_man_days_string => '5,25',    dummy_as_man_days_unit   => 'h'   )->dummy, 5.25,  'assign_attributes hash string 5,25h');
is(new_item->assign_attributes(dummy_as_man_days_unit   => 'h',       dummy_as_man_days_string => '5,25')->dummy, 5.25,  'assign_attributes hash string h5,25');

is(new_item->assign_attributes(dummy_as_man_days_string => '5,25',    dummy_as_man_days_unit   => 'man_day')->dummy, 42, 'assign_attributes hash string 5,25man_day');
is(new_item->assign_attributes(dummy_as_man_days_unit   => 'man_day', dummy_as_man_days_string => '5,25'   )->dummy, 42, 'assign_attributes hash string man_day5,25');

is(new_item->assign_attributes('dummy_as_man_days_string', '5,25', 'dummy_as_man_days_unit',   'h'   )->dummy, 5.25,  'assign_attributes array 5,25h');
is(new_item->assign_attributes('dummy_as_man_days_unit',   'h',    'dummy_as_man_days_string', '5,25')->dummy, 5.25,  'assign_attributes array h5,25');

is(new_item->assign_attributes('dummy_as_man_days_string', '5,25',    'dummy_as_man_days_unit',   'man_day')->dummy, 42, 'assign_attributes array 5,25man_day');
is(new_item->assign_attributes('dummy_as_man_days_unit',   'man_day', 'dummy_as_man_days_string', '5,25'   )->dummy, 42, 'assign_attributes array man_day5,25');

# Parametervalidierung
throws_ok { new_item()->dummy_as_man_days_unit('invalid') } qr/unknown.*unit/i, 'unknown unit';
lives_ok  { new_item()->dummy_as_man_days_unit('h')       } 'known unit h';
lives_ok  { new_item()->dummy_as_man_days_unit('hour')    } 'known unit hour';
lives_ok  { new_item()->dummy_as_man_days_unit('man_day') } 'known unit man_day';

### attr_duration_minutes

# Wenn das Attribut undef ist:
is(new_item->inty,                    undef,  'uninitialized: raw');
is(new_item->inty_as_hours,           0,      'uninitialized: as_hours');
is(new_item->inty_as_minutes,         0,      'uninitialized: as_minutes');
is(new_item->inty_as_duration_string, undef,  'uninitialized: as_duration_string');

# Auslesen kleiner 60 Minuten:
is(new_item(inty => 37)->inty,                    37,     'initialized < 60: raw');
is(new_item(inty => 37)->inty_as_hours,           0,      'initialized < 60: as_hours');
is(new_item(inty => 37)->inty_as_minutes,         37,     'initialized < 60: as_minutes');
is(new_item(inty => 37)->inty_as_duration_string, '0:37', 'initialized < 60: as_duration_string');

# Auslesen größer 60 Minuten:
is(new_item(inty => 145)->inty,                    145,    'initialized > 60: raw');
is(new_item(inty => 145)->inty_as_hours,           2,      'initialized > 60: as_hours');
is(new_item(inty => 145)->inty_as_minutes,         25,     'initialized > 60: as_minutes');
is(new_item(inty => 145)->inty_as_duration_string, '2:25', 'initialized > 60: as_duration_string');

$item = new_item(inty => 145); $item->inty_as_duration_string(undef);
is($item->inty,                    undef, 'write as_duration_string undef read raw');
is($item->inty_as_minutes,         0,     'write as_duration_string undef read as_minutes');
is($item->inty_as_hours,           0,     'write as_duration_string undef read as_hours');
is($item->inty_as_duration_string, undef, 'write as_duration_string undef read as_duration_string');

$item = new_item(inty => 145); $item->inty_as_duration_string('');
is($item->inty,                    undef, 'write as_duration_string "" read raw');
is($item->inty_as_minutes,         0,     'write as_duration_string "" read as_minutes');
is($item->inty_as_hours,           0,     'write as_duration_string "" read as_hours');
is($item->inty_as_duration_string, undef, 'write as_duration_string "" read as_duration_string');

$item = new_item(inty => 145); $item->inty_as_duration_string("3:21");
is($item->inty,                    201,    'write as_duration_string 3:21 read raw');
is($item->inty_as_minutes,         21,     'write as_duration_string 3:21 read as_minutes');
is($item->inty_as_hours,           3,      'write as_duration_string 3:21 read as_hours');
is($item->inty_as_duration_string, "3:21", 'write as_duration_string 3:21 read as_duration_string');

$item = new_item(inty => 145); $item->inty_as_duration_string("03:1");
is($item->inty,                    181,    'write as_duration_string 03:1 read raw');
is($item->inty_as_minutes,         1,      'write as_duration_string 03:1 read as_minutes');
is($item->inty_as_hours,           3,      'write as_duration_string 03:1 read as_hours');
is($item->inty_as_duration_string, "3:01", 'write as_duration_string 03:1 read as_duration_string');

local %::myconfig = (numberformat => "1.000,00");

$item = new_item(miny_in_hours => 2.5);
is($item->miny,                    150,    'write in_hours 2.5 read raw');
is($item->miny_as_minutes,         30,     'write in_hours 2.5 read as_minutes');
is($item->miny_as_hours,           2,      'write in_hours 2.5 read as_hours');
is($item->miny_in_hours,           2.5,    'write in_hours 2.5 read in_hours');
is($item->miny_in_hours_as_number, '2,50', 'write in_hours 2.5 read in_hours_as_number');

$item = new_item(miny_in_hours_as_number => '4,25');
is($item->miny,                    255,    'write in_hours_as_number 4,25 read raw');
is($item->miny_as_minutes,         15,     'write in_hours_as_number 4,25 read as_minutes');
is($item->miny_as_hours,           4,      'write in_hours_as_number 4,25 read as_hours');
is($item->miny_in_hours,           4.25,   'write in_hours_as_number 4,25 read in_hours');
is($item->miny_in_hours_as_number, '4,25', 'write in_hours_as_number 4,25 read in_hours_as_number');

# Parametervalidierung
throws_ok { new_item()->inty_as_duration_string('invalid') } qr/invalid.*format/i, 'invalid duration format';

done_testing();
