# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Note;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('notes');

__PACKAGE__->meta->columns(
  id           => { type => 'integer', not_null => 1, sequence => 'note_id' },
  subject      => { type => 'text' },
  body         => { type => 'text' },
  created_by   => { type => 'integer', not_null => 1 },
  trans_id     => { type => 'integer' },
  trans_module => { type => 'varchar', length => 10 },
  itime        => { type => 'timestamp', default => 'now()' },
  mtime        => { type => 'timestamp' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  employee => {
    class       => 'SL::DB::Employee',
    key_columns => { created_by => 'id' },
  },
);

__PACKAGE__->meta->relationships(
  follow_ups => {
    class      => 'SL::DB::FollowUp',
    column_map => { id => 'note_id' },
    type       => 'one to many',
  },
);

# __PACKAGE__->meta->initialize;

1;
;
