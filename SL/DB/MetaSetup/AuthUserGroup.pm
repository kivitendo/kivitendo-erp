# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::AuthUserGroup;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'user_group',

  columns => [
    user_id  => { type => 'integer', not_null => 1 },
    group_id => { type => 'integer', not_null => 1 },
  ],

  primary_key_columns => [ 'user_id', 'group_id' ],
);

1;
;
