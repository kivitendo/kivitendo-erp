# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::GLTransaction;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('gl');

__PACKAGE__->meta->columns(
  id             => { type => 'integer', not_null => 1, sequence => 'glid' },
  reference      => { type => 'text' },
  description    => { type => 'text' },
  transdate      => { type => 'date', default => 'now' },
  gldate         => { type => 'date', default => 'now' },
  employee_id    => { type => 'integer' },
  notes          => { type => 'text' },
  department_id  => { type => 'integer' },
  taxincluded    => { type => 'boolean' },
  itime          => { type => 'timestamp', default => 'now()' },
  mtime          => { type => 'timestamp' },
  type           => { type => 'text' },
  storno         => { type => 'boolean', default => 'false' },
  storno_id      => { type => 'integer' },
  ob_transaction => { type => 'boolean' },
  cb_transaction => { type => 'boolean' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  department => {
    class       => 'SL::DB::Department',
    key_columns => { department_id => 'id' },
  },

  storno_obj => {
    class       => 'SL::DB::GLTransaction',
    key_columns => { storno_id => 'id' },
  },
);

__PACKAGE__->meta->relationships(
  gl => {
    class      => 'SL::DB::GLTransaction',
    column_map => { id => 'storno_id' },
    type       => 'one to many',
  },
);

# __PACKAGE__->meta->initialize;

1;
;
