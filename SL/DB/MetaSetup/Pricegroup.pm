# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Pricegroup;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('pricegroup');

__PACKAGE__->meta->columns(
  id         => { type => 'integer', not_null => 1, sequence => 'id' },
  pricegroup => { type => 'text', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->relationships(
  delivery_order_items => {
    class      => 'SL::DB::DeliveryOrderItem',
    column_map => { id => 'pricegroup_id' },
    type       => 'one to many',
  },

  invoice => {
    class      => 'SL::DB::InvoiceItem',
    column_map => { id => 'pricegroup_id' },
    type       => 'one to many',
  },

  orderitems => {
    class      => 'SL::DB::OrderItem',
    column_map => { id => 'pricegroup_id' },
    type       => 'one to many',
  },
);

# __PACKAGE__->meta->initialize;

1;
;
