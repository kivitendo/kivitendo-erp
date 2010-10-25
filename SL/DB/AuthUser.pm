# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::AuthUser;

use strict;

use SL::DB::MetaSetup::AuthUser;
use SL::DB::AuthUserGroup;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

__PACKAGE__->meta->schema('auth');

__PACKAGE__->meta->add_relationship(
  groups => {
    type      => 'many to many',
    map_class => 'SL::DB::AuthUserGroup',
    map_from  => 'user',
    map_to    => 'group',
  },
  configs => {
    type       => 'one to many',
    class      => 'SL::DB::AuthUserConfig',
    column_map => { id => 'user_id' },
  },
);

__PACKAGE__->meta->initialize;

1;
