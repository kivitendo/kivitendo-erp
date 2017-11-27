# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Inventory;

use strict;

use SL::DB::MetaSetup::Inventory;
use SL::DB::Manager::Inventory;

__PACKAGE__->meta->initialize;

# part accessor is badly named
sub part {
  goto &parts;
}

1;
