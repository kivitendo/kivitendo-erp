# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::FollowUp;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'follow_ups',

  columns => [
    id               => { type => 'integer', not_null => 1, sequence => 'follow_up_id' },
    follow_up_date   => { type => 'date', not_null => 1 },
    created_for_user => { type => 'integer', not_null => 1 },
    done             => { type => 'boolean', default => 'false' },
    note_id          => { type => 'integer', not_null => 1 },
    created_by       => { type => 'integer', not_null => 1 },
    itime            => { type => 'timestamp', default => 'now()' },
    mtime            => { type => 'timestamp' },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,

  foreign_keys => [
    employee => {
      class       => 'SL::DB::Employee',
      key_columns => { created_for_user => 'id' },
    },

    employee_obj => {
      class       => 'SL::DB::Employee',
      key_columns => { created_by => 'id' },
    },

    note => {
      class       => 'SL::DB::Note',
      key_columns => { note_id => 'id' },
    },
  ],
);

1;
;
