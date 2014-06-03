package AttrTimestampTestDummy;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'dummy',
  columns => [ dummy => { type => 'timestamp' }, ]
);

use SL::DB::Helper::Attr;

package main;

use strict;

use Test::More;

use lib 't';
use utf8;

use Support::TestSetup;

sub new    { return AttrTimestampTestDummy->new(@_) }
sub new_dt { DateTime->new(year => 2014, month => 5, day => 31, hour => 23, minute => 9, second => 8, nanosecond => 12000000) }

Support::TestSetup::login();

$::myconfig{dateformat}   = 'dd.mm.yy';
$::myconfig{numberformat} = '1.000,00';

is(new->dummy,                 undef, 'uninitialized: raw');
is(new->dummy_as_timestamp,    undef, 'uninitialized: as_timestamp');
is(new->dummy_as_timestamp_s,  undef, 'uninitialized: as_timestamp_s');
is(new->dummy_as_timestamp_ms, undef, 'uninitialized: as_timestamp_ms');

is(new(dummy => new_dt())->dummy,                 new_dt(),                  'initialized with DateTime, raw');
is(new(dummy => new_dt())->dummy_as_timestamp,    '31.05.2014 23:09',        'initialized with DateTime: as_timestamp');
is(new(dummy => new_dt())->dummy_as_timestamp_s,  '31.05.2014 23:09:08',     'initialized with DateTime: as_timestamp_s');
is(new(dummy => new_dt())->dummy_as_timestamp_ms, '31.05.2014 23:09:08,012', 'initialized with DateTime: as_timestamp_ms');

is(new(dummy_as_timestamp => '31.05.2014')->dummy,            new_dt()->truncate(to => 'day'),    'initialized with string: as_timestamp, precision day');
is(new(dummy_as_timestamp => '31.05.2014 23')->dummy,         new_dt()->truncate(to => 'hour'),   'initialized with string: as_timestamp, precision hour');
is(new(dummy_as_timestamp => '31.05.2014 23:9')->dummy,       new_dt()->truncate(to => 'minute'), 'initialized with string: as_timestamp, precision minute');
is(new(dummy_as_timestamp => '31.05.2014 23:9:8')->dummy,     new_dt()->truncate(to => 'second'), 'initialized with string: as_timestamp, precision second');
is(new(dummy_as_timestamp => '31.05.2014 23:9:8,012')->dummy, new_dt(),                           'initialized with string: as_timestamp, precision millisecond');

is(new(dummy_as_timestamp_s => '31.05.2014')->dummy,            new_dt()->truncate(to => 'day'),    'initialized with string: as_timestamp_s, precision day');
is(new(dummy_as_timestamp_s => '31.05.2014 23')->dummy,         new_dt()->truncate(to => 'hour'),   'initialized with string: as_timestamp_s, precision hour');
is(new(dummy_as_timestamp_s => '31.05.2014 23:9')->dummy,       new_dt()->truncate(to => 'minute'), 'initialized with string: as_timestamp_s, precision minute');
is(new(dummy_as_timestamp_s => '31.05.2014 23:9:8')->dummy,     new_dt()->truncate(to => 'second'), 'initialized with string: as_timestamp_s, precision second');
is(new(dummy_as_timestamp_s => '31.05.2014 23:9:8,012')->dummy, new_dt(),                           'initialized with string: as_timestamp_s, precision millisecond');

is(new(dummy_as_timestamp_ms => '31.05.2014')->dummy,            new_dt()->truncate(to => 'day'),    'initialized with string: as_timestamp_ms, precision day');
is(new(dummy_as_timestamp_ms => '31.05.2014 23')->dummy,         new_dt()->truncate(to => 'hour'),   'initialized with string: as_timestamp_ms, precision hour');
is(new(dummy_as_timestamp_ms => '31.05.2014 23:9')->dummy,       new_dt()->truncate(to => 'minute'), 'initialized with string: as_timestamp_ms, precision minute');
is(new(dummy_as_timestamp_ms => '31.05.2014 23:9:8')->dummy,     new_dt()->truncate(to => 'second'), 'initialized with string: as_timestamp_ms, precision second');
is(new(dummy_as_timestamp_ms => '31.05.2014 23:9:8,012')->dummy, new_dt(),                           'initialized with string: as_timestamp_ms, precision millisecond');

my $item = new();
is($item->dummy_as_timestamp_ms('31.05.2014'),            '31.05.2014 00:00:00,000', 'return value of accessor as_timestamp_ms, precision day');
is($item->dummy_as_timestamp_ms('31.05.2014 23'),         '31.05.2014 23:00:00,000', 'return value of accessor as_timestamp_ms, precision hour');
is($item->dummy_as_timestamp_ms('31.05.2014 23:9'),       '31.05.2014 23:09:00,000', 'return value of accessor as_timestamp_ms, precision minute');
is($item->dummy_as_timestamp_ms('31.05.2014 23:9:8'),     '31.05.2014 23:09:08,000', 'return value of accessor as_timestamp_ms, precision second');
is($item->dummy_as_timestamp_ms('31.05.2014 23:9:8,012'), '31.05.2014 23:09:08,012', 'return value of accessor as_timestamp_ms, precision millisecond');

done_testing();
