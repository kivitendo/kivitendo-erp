# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Chart;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('chart');

__PACKAGE__->meta->columns(
  accno          => { type => 'text', not_null => 1 },
  category       => { type => 'character', length => 1 },
  charttype      => { type => 'character', default => 'A', length => 1 },
  datevautomatik => { type => 'boolean', default => 'false' },
  description    => { type => 'text' },
  id             => { type => 'integer', not_null => 1, sequence => 'id' },
  itime          => { type => 'timestamp', default => 'now()' },
  link           => { type => 'text', not_null => 1 },
  mtime          => { type => 'timestamp' },
  new_chart_id   => { type => 'integer' },
  pos_bilanz     => { type => 'integer' },
  pos_bwa        => { type => 'integer' },
  pos_er         => { type => 'integer' },
  pos_eur        => { type => 'integer' },
  taxkey_id      => { type => 'integer' },
  valid_from     => { type => 'date' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->unique_keys([ 'accno' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

1;
;
