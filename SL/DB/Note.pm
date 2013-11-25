# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Note;

use strict;

use SL::DB::MetaSetup::Note;


__PACKAGE__->meta->add_relationships(
  follow_up => {
    type         => 'one to one',
    class        => 'SL::DB::FollowUp',
    column_map   => { id => 'note_id' },
  },
);

__PACKAGE__->meta->initialize;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;


1;
