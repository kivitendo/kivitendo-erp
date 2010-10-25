# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::AuthUserGroup;

use strict;

use SL::DB::MetaSetup::AuthUserGroup;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

__PACKAGE__->meta->schema('auth');

__PACKAGE__->meta->add_foreign_keys(
  user => {
    class       => 'SL::DB::AuthUser',
    key_columns => { user_id => 'id' },
  },

  group => {
    class       => 'SL::DB::AuthGroup',
    key_columns => { group_id => 'id' },
  },
);

__PACKAGE__->meta->initialize;

1;
