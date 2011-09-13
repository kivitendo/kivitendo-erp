package SL::DB::DeliveryOrderItem;

use strict;

use SL::DB::MetaSetup::DeliveryOrderItem;
use SL::DB::Helper::CustomVariables (
  sub_module  => 'delivery_order_item',
  cvars_alias => 1,
  overloads   => {
    parts_id => 'SL::DB::Part',
  },
);

__PACKAGE__->meta->make_manager_class;

# methods

sub part {
  # canonial alias for parts.
  return shift->parts;
}

1;
