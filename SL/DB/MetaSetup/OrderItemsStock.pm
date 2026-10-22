# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::OrderItemsStock;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('order_items_stock');

__PACKAGE__->meta->columns(
  bestbefore    => { type => 'date' },
  bin_id        => { type => 'integer', not_null => 1 },
  chargenumber  => { type => 'text' },
  id            => { type => 'serial', not_null => 1 },
  itime         => { type => 'timestamp', default => 'now()', not_null => 1 },
  mtime         => { type => 'timestamp' },
  order_item_id => { type => 'integer', not_null => 1 },
  qty           => { type => 'numeric', not_null => 1, precision => 25, scale => 5 },
  unit          => { type => 'varchar', length => 20, not_null => 1 },
  warehouse_id  => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  bin => {
    class       => 'SL::DB::Bin',
    key_columns => { bin_id => 'id' },
  },

  order_item => {
    class       => 'SL::DB::OrderItem',
    key_columns => { order_item_id => 'id' },
  },

  unit_obj => {
    class       => 'SL::DB::Unit',
    key_columns => { unit => 'name' },
  },

  warehouse => {
    class       => 'SL::DB::Warehouse',
    key_columns => { warehouse_id => 'id' },
  },
);

1;

