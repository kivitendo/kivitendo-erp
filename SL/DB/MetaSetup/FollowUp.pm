# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::FollowUp;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('follow_ups');

__PACKAGE__->meta->columns(
  created_by     => { type => 'integer', not_null => 1 },
  done           => { type => 'boolean', default => 'false' },
  follow_up_date => { type => 'date', not_null => 1 },
  id             => { type => 'integer', not_null => 1, sequence => 'follow_up_id' },
  itime          => { type => 'timestamp', default => 'now()' },
  mtime          => { type => 'timestamp' },
  note_id        => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  created_by_employee => {
    class       => 'SL::DB::Employee',
    key_columns => { created_by => 'id' },
  },

  note => {
    class       => 'SL::DB::Note',
    key_columns => { note_id => 'id' },
  },
);

1;
;
