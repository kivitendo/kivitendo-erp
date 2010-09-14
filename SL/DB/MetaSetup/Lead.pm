# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Lead;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'leads',

  columns => [
    id   => { type => 'integer', not_null => 1, sequence => 'id' },
    lead => { type => 'varchar', length => 50 },
  ],

  primary_key_columns => [ 'id' ],
);

1;
;
