# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::SepaExport;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'sepa_export',

  columns => [
    id          => { type => 'serial', not_null => 1 },
    employee_id => { type => 'integer', not_null => 1 },
    executed    => { type => 'boolean', default => 'false' },
    closed      => { type => 'boolean', default => 'false' },
    itime       => { type => 'timestamp', default => 'now()' },
    vc          => { type => 'varchar', length => 10 },
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
