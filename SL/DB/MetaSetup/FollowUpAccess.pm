# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::FollowUpAccess;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('follow_up_access');

__PACKAGE__->meta->columns(
  id   => { type => 'serial', not_null => 1 },
  what => { type => 'integer', not_null => 1 },
  who  => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->foreign_keys(
  to_follow_ups_by => {
    class       => 'SL::DB::Employee',
    key_columns => { what => 'id' },
  },

  with_access => {
    class       => 'SL::DB::Employee',
    key_columns => { who => 'id' },
  },
);

1;
;
