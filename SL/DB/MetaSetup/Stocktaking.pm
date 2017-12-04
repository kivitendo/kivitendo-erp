# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Stocktaking;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('stocktakings');

__PACKAGE__->meta->columns(
  bestbefore   => { type => 'date' },
  bin_id       => { type => 'integer', not_null => 1 },
  chargenumber => { type => 'text', default => '', not_null => 1 },
  comment      => { type => 'text' },
  cutoff_date  => { type => 'date', not_null => 1 },
  employee_id  => { type => 'integer', not_null => 1 },
  id           => { type => 'integer', not_null => 1, sequence => 'id' },
  inventory_id => { type => 'integer' },
  itime        => { type => 'timestamp', default => 'now()' },
  mtime        => { type => 'timestamp' },
  parts_id     => { type => 'integer', not_null => 1 },
  qty          => { type => 'numeric', not_null => 1, precision => 25, scale => 5 },
  warehouse_id => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  bin => {
    class       => 'SL::DB::Bin',
    key_columns => { bin_id => 'id' },
  },

  employee => {
    class       => 'SL::DB::Employee',
    key_columns => { employee_id => 'id' },
  },

  inventory => {
    class       => 'SL::DB::Inventory',
    key_columns => { inventory_id => 'id' },
  },

  parts => {
    class       => 'SL::DB::Part',
    key_columns => { parts_id => 'id' },
  },

  warehouse => {
    class       => 'SL::DB::Warehouse',
    key_columns => { warehouse_id => 'id' },
  },
);

1;
;
