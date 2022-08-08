# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::FollowUp;

use strict;

use SL::DB::MetaSetup::FollowUp;

__PACKAGE__->meta->add_relationships(
  follow_up_link => {
    type         => 'one to one',
    class        => 'SL::DB::FollowUpLink',
    column_map   => { id => 'follow_up_id' },
  },
  created_for_employees => {
    type       => 'many to many',
    map_class  => 'SL::DB::FollowUpCreatedForEmployee',
  },
  done => {
    type       => 'one to one',
    class      => 'SL::DB::FollowUpDone',
    column_map => { id => 'follow_up_id' },
  },
);

__PACKAGE__->meta->initialize;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

1;
