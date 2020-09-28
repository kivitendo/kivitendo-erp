# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::GLTransaction;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('gl');

__PACKAGE__->meta->columns(
  cb_transaction => { type => 'boolean' },
  deliverydate   => { type => 'date' },
  department_id  => { type => 'integer' },
  description    => { type => 'text' },
  employee_id    => { type => 'integer' },
  gldate         => { type => 'date', default => 'now' },
  id             => { type => 'integer', not_null => 1, sequence => 'glid' },
  imported       => { type => 'boolean', default => 'false' },
  itime          => { type => 'timestamp', default => 'now()' },
  mtime          => { type => 'timestamp' },
  notes          => { type => 'text' },
  ob_transaction => { type => 'boolean' },
  reference      => { type => 'text' },
  storno         => { type => 'boolean', default => 'false' },
  storno_id      => { type => 'integer' },
  tax_point      => { type => 'date' },
  taxincluded    => { type => 'boolean' },
  transdate      => { type => 'date', default => 'now' },
  type           => { type => 'text' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  department => {
    class       => 'SL::DB::Department',
    key_columns => { department_id => 'id' },
  },

  employee => {
    class       => 'SL::DB::Employee',
    key_columns => { employee_id => 'id' },
  },

  storno_obj => {
    class       => 'SL::DB::GLTransaction',
    key_columns => { storno_id => 'id' },
  },
);

1;
;
