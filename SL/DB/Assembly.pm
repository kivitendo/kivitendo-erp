# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Assembly;

use strict;

use SL::DB::MetaSetup::Assembly;

__PACKAGE__->meta->add_relationships(
  part => {
    type         => 'many to one',
    class        => 'SL::DB::Part',
    column_map   => { parts_id => 'id' },
  },
);

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

__PACKAGE__->meta->initialize;

1;
