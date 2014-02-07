package SL::DB::DeliveryOrderItem;

use strict;

use SL::DB::MetaSetup::DeliveryOrderItem;
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

__PACKAGE__->meta->initialize;

# methods

1;
