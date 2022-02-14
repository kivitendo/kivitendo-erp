# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::DeliveryOrderItemsStock;

use strict;

use SL::DB::MetaSetup::DeliveryOrderItemsStock;

__PACKAGE__->meta->add_relationship(
  inventory => {
    type         => 'one to one',
    class        => 'SL::DB::Inventory',
    column_map   => { id => 'delivery_order_items_stock_id' },
  },
  unit_obj => {
    type         => 'many to one',
    class        => 'SL::DB::Unit',
    column_map   => { unit => 'name' },
  },
);

__PACKAGE__->meta->initialize;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

1;
