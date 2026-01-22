# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Country;

use strict;

use SL::DB::MetaSetup::Country;
use SL::DB::Manager::Country;
use SL::DB::Helper::ActsAsList (column_name => 'sortorder');

__PACKAGE__->meta->initialize;
__PACKAGE__->before_delete('can_be_deleted');

sub can_be_deleted {
  return 0;
}


1;
