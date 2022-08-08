# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::FollowUpDone;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('follow_up_done');

__PACKAGE__->meta->columns(
  done_at      => { type => 'timestamp', default => 'now()', not_null => 1 },
  employee_id  => { type => 'integer' },
  follow_up_id => { type => 'integer', not_null => 1 },
  id           => { type => 'serial', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->unique_keys([ 'follow_up_id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  employee => {
    class       => 'SL::DB::Employee',
    key_columns => { employee_id => 'id' },
  },

  follow_up => {
    class       => 'SL::DB::FollowUp',
    key_columns => { follow_up_id => 'id' },
    rel_type    => 'one to one',
  },
);

1;
;
