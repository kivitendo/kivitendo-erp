# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::FollowUpAccess;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'follow_up_access',

  columns => [
    who  => { type => 'integer', not_null => 1 },
    what => { type => 'integer', not_null => 1 },
    id   => { type => 'serial', not_null => 1 },
  ],

  primary_key_columns => [ 'id' ],

  foreign_keys => [
    employee => {
      class       => 'SL::DB::Employee',
      key_columns => { who => 'id' },
    },

    employee_obj => {
      class       => 'SL::DB::Employee',
      key_columns => { what => 'id' },
    },
  ],
);

1;
;
