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
__PACKAGE__->meta->add_relationship(
  unit_obj       => {
    type         => 'many to one',
    class        => 'SL::DB::Unit',
    column_map   => { unit => 'name' },
  },
);

__PACKAGE__->meta->initialize;

# methods

sub part {
  # canonial alias for parts.
  goto &parts;
}

1;
