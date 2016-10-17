package SL::DB::DeliveryOrderItem;

use strict;

use SL::DB::MetaSetup::DeliveryOrderItem;
use SL::DB::Helper::ActsAsList;
use SL::DB::Helper::LinkedRecords;
use SL::DB::Helper::RecordItem;
use SL::DB::Helper::CustomVariables (
  sub_module  => 'delivery_order_items',
  cvars_alias => 1,
  overloads   => {
    parts_id => {
      class => 'SL::DB::Part',
      module => 'IC',
    }
  },
);

__PACKAGE__->meta->make_manager_class;

__PACKAGE__->meta->add_relationship(
  delivery_order_stock_entries => {
    type         => 'one to many',
    class        => 'SL::DB::DeliveryOrderItemsStock',
    column_map   => { id => 'delivery_order_item_id' },
    manager_args => {
      with_objects => [ 'inventory' ]
    },
  },
);

__PACKAGE__->meta->initialize;

__PACKAGE__->configure_acts_as_list(group_by => [qw(delivery_order_id)]);

# methods

sub record { goto &delivery_order }

1;
