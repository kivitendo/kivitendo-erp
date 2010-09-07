# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::History;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'history_erp',

  columns => [
    id          => { type => 'integer', not_null => 1, sequence => 'id' },
    trans_id    => { type => 'integer' },
    employee_id => { type => 'integer' },
    addition    => { type => 'text' },
    what_done   => { type => 'text' },
    itime       => { type => 'timestamp', default => 'now()' },
    snumbers    => { type => 'text' },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,

  foreign_keys => [
    employee => {
      class       => 'SL::DB::Employee',
      key_columns => { employee_id => 'id' },
    },
  ],
);

1;
;
