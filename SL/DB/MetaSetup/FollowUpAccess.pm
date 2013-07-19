# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::FollowUpAccess;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('follow_up_access');

__PACKAGE__->meta->columns(
  id   => { type => 'serial', not_null => 1 },
  what => { type => 'integer', not_null => 1 },
  who  => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->foreign_keys(
  employee => {
    class       => 'SL::DB::Employee',
    key_columns => { what => 'id' },
  },

  employee_obj => {
    class       => 'SL::DB::Employee',
    key_columns => { who => 'id' },
  },
);

1;
;
