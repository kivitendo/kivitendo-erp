# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::GLTransaction;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'gl',

  columns => [
    id             => { type => 'integer', not_null => 1, sequence => 'glid' },
    reference      => { type => 'text' },
    description    => { type => 'text' },
    transdate      => { type => 'date', default => 'now' },
    gldate         => { type => 'date', default => 'now' },
    employee_id    => { type => 'integer' },
    notes          => { type => 'text' },
    department_id  => { type => 'integer', default => '0' },
    taxincluded    => { type => 'boolean' },
    itime          => { type => 'timestamp', default => 'now()' },
    mtime          => { type => 'timestamp' },
    type           => { type => 'text' },
    storno         => { type => 'boolean', default => 'false' },
    storno_id      => { type => 'integer' },
    ob_transaction => { type => 'boolean' },
    cb_transaction => { type => 'boolean' },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,

  foreign_keys => [
    storno_obj => {
      class       => 'SL::DB::GLTransaction',
      key_columns => { storno_id => 'id' },
    },
  ],
);

1;
;
