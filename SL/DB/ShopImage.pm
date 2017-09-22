# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::ShopImage;

use strict;

use SL::DB::MetaSetup::ShopImage;
use SL::DB::Manager::ShopImage;
use SL::DB::Helper::ActsAsList;

__PACKAGE__->meta->initialize;

__PACKAGE__->configure_acts_as_list(group_by => [qw(object_id)]);

1;
