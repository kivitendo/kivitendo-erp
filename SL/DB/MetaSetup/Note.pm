# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Note;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'notes',

  columns => [
    id           => { type => 'integer', not_null => 1, sequence => 'note_id' },
    subject      => { type => 'text' },
    body         => { type => 'text' },
    created_by   => { type => 'integer', not_null => 1 },
    trans_id     => { type => 'integer' },
    trans_module => { type => 'varchar', length => 10 },
    itime        => { type => 'timestamp', default => 'now()' },
    mtime        => { type => 'timestamp' },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,

  foreign_keys => [
    employee => {
      class       => 'SL::DB::Employee',
      key_columns => { created_by => 'id' },
    },
  ],
);

1;
;
