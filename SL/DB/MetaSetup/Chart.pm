# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Chart;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'chart',

  columns => [
    id             => { type => 'integer', not_null => 1, sequence => 'id' },
    accno          => { type => 'text', not_null => 1 },
    description    => { type => 'text' },
    charttype      => { type => 'character', default => 'A', length => 1 },
    category       => { type => 'character', length => 1 },
    link           => { type => 'text' },
    gifi_accno     => { type => 'text' },
    taxkey_id      => { type => 'integer' },
    pos_ustva      => { type => 'integer' },
    pos_bwa        => { type => 'integer' },
    pos_bilanz     => { type => 'integer' },
    pos_eur        => { type => 'integer' },
    datevautomatik => { type => 'boolean', default => 'false' },
    itime          => { type => 'timestamp', default => 'now()' },
    mtime          => { type => 'timestamp' },
    new_chart_id   => { type => 'integer' },
    valid_from     => { type => 'date' },
  ],

  primary_key_columns => [ 'id' ],

  unique_key => [ 'accno' ],

  allow_inline_column_values => 1,
);

1;
;
