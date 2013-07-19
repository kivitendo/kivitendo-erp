# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Inventory;

use strict;

use SL::DB::MetaSetup::Inventory;

__PACKAGE__->meta->initialize;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

# part accessor is badly named
sub part {
  goto &parts;
}

1;
