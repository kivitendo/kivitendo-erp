package SL::DB::DeliveryOrderItem;

use strict;

use SL::DB::MetaSetup::DeliveryOrderItem;

for my $field (qw(qty sellprice discount base_qty lastcost price_factor marge_price_factor)) {
  __PACKAGE__->attr_number($field, places => -2);
}

__PACKAGE__->meta->make_manager_class;

# methods

sub part {
  # canonial alias for parts.
  return shift->parts;
}

1;
