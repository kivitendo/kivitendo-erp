# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Warehouse;

use strict;

use SL::DB::MetaSetup::Warehouse;

__PACKAGE__->meta->make_manager_class;

__PACKAGE__->meta->add_relationship(
  bins => {
    type         => 'one to many',
    class        => 'SL::DB::Bin',
    column_map   => { id => 'warehouse_id' },
  }
);

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
#__PACKAGE__->meta->make_manager_class;

__PACKAGE__->meta->initialize;

sub first_bin {
  return shift()->bins->[0];
}

1;
