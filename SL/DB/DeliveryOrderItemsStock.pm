# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::DeliveryOrderItemsStock;

use strict;

use SL::DB::MetaSetup::DeliveryOrderItemsStock;

for my $field (qw(qty)) {
  __PACKAGE__->attr_number($field, places => -2);
}

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

1;
