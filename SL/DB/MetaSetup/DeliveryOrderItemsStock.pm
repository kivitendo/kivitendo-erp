# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::DeliveryOrderItemsStock;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('delivery_order_items_stock');

__PACKAGE__->meta->columns(
  bestbefore             => { type => 'date' },
  bin_id                 => { type => 'integer', not_null => 1 },
  chargenumber           => { type => 'text' },
  delivery_order_item_id => { type => 'integer', not_null => 1 },
  id                     => { type => 'integer', not_null => 1, sequence => 'id' },
  itime                  => { type => 'timestamp', default => 'now()' },
  mtime                  => { type => 'timestamp' },
  qty                    => { type => 'numeric', not_null => 1, precision => 15, scale => 5 },
  unit                   => { type => 'varchar', length => 20, not_null => 1 },
  warehouse_id           => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  bin => {
    class       => 'SL::DB::Bin',
    key_columns => { bin_id => 'id' },
  },

  delivery_order_item => {
    class       => 'SL::DB::DeliveryOrderItem',
    key_columns => { delivery_order_item_id => 'id' },
  },

  warehouse => {
    class       => 'SL::DB::Warehouse',
    key_columns => { warehouse_id => 'id' },
  },
);

1;
;
