# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::StockCountingItem;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('stock_counting_items');

__PACKAGE__->meta->columns(
  bin_id                  => { type => 'integer', not_null => 1 },
  comment                 => { type => 'text' },
  correction_inventory_id => { type => 'integer' },
  counted_at              => { type => 'timestamp', default => 'now()', not_null => 1 },
  counting_id             => { type => 'integer', not_null => 1 },
  employee_id             => { type => 'integer', not_null => 1 },
  id                      => { type => 'integer', not_null => 1, sequence => 'id' },
  itime                   => { type => 'timestamp', default => 'now()', not_null => 1 },
  mtime                   => { type => 'timestamp' },
  part_id                 => { type => 'integer', not_null => 1 },
  qty                     => { type => 'numeric', not_null => 1, precision => 25, scale => 5 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  bin => {
    class       => 'SL::DB::Bin',
    key_columns => { bin_id => 'id' },
  },

  correction_inventory => {
    class       => 'SL::DB::Inventory',
    key_columns => { correction_inventory_id => 'id' },
  },

  counting => {
    class       => 'SL::DB::StockCounting',
    key_columns => { counting_id => 'id' },
  },

  employee => {
    class       => 'SL::DB::Employee',
    key_columns => { employee_id => 'id' },
  },

  part => {
    class       => 'SL::DB::Part',
    key_columns => { part_id => 'id' },
  },
);

1;
;
