# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::AuthClient;

use strict;

use SL::DB::MetaSetup::AuthClient;
use SL::DB::Manager::AuthClient;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->schema('auth');

__PACKAGE__->meta->add_relationship(
  users => {
    type      => 'many to many',
    map_class => 'SL::DB::AuthUserGroup',
    map_from  => 'client',
    map_to    => 'user',
  },
  groups => {
    type      => 'many to many',
    map_class => 'SL::DB::AuthUserGroup',
    map_from  => 'client',
    map_to    => 'group',
  },
);

__PACKAGE__->meta->initialize;

1;
