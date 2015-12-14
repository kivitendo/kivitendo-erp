# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::AuthUserGroup;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('user_group');
__PACKAGE__->meta->schema('auth');

__PACKAGE__->meta->columns(
  group_id => { type => 'integer', not_null => 1 },
  user_id  => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'user_id', 'group_id' ]);

__PACKAGE__->meta->foreign_keys(
  group => {
    class       => 'SL::DB::AuthGroup',
    key_columns => { group_id => 'id' },
  },

  user => {
    class       => 'SL::DB::AuthUser',
    key_columns => { user_id => 'id' },
  },
);

1;
;
