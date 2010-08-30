# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::DeliveryOrderItemsStock;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'delivery_order_items_stock',

  columns => [
    id                     => { type => 'integer', not_null => 1, sequence => 'id' },
    delivery_order_item_id => { type => 'integer', not_null => 1 },
    qty                    => { type => 'numeric', not_null => 1, precision => 5, scale => 15 },
    unit                   => { type => 'varchar', length => 20, not_null => 1 },
    warehouse_id           => { type => 'integer', not_null => 1 },
    bin_id                 => { type => 'integer', not_null => 1 },
    chargenumber           => { type => 'text' },
    itime                  => { type => 'timestamp', default => 'now()' },
    mtime                  => { type => 'timestamp' },
    bestbefore             => { type => 'date' },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,

  foreign_keys => [
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
  ],
);

1;
;
