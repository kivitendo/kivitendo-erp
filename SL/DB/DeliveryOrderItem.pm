package SL::DB::DeliveryOrderItem;

use strict;

use SL::DB::MetaSetup::DeliveryOrderItem;

__PACKAGE__->meta->make_manager_class;

# methods

sub part {
  # canonial alias for parts.
  return shift->parts;
}

1;
