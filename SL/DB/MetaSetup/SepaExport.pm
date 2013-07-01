# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::SepaExport;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('sepa_export');

__PACKAGE__->meta->columns(
  closed      => { type => 'boolean', default => 'false' },
  employee_id => { type => 'integer', not_null => 1 },
  executed    => { type => 'boolean', default => 'false' },
  id          => { type => 'serial', not_null => 1 },
  itime       => { type => 'timestamp', default => 'now()' },
  vc          => { type => 'varchar', length => 10 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  employee => {
    class       => 'SL::DB::Employee',
    key_columns => { employee_id => 'id' },
  },
);

1;
;
