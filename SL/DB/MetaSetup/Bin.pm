# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Bin;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'bin',

  columns => [
    id           => { type => 'integer', not_null => 1, sequence => 'id' },
    warehouse_id => { type => 'integer', not_null => 1 },
    description  => { type => 'text' },
    itime        => { type => 'timestamp', default => 'now()' },
    mtime        => { type => 'timestamp' },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,

  foreign_keys => [
    warehouse => {
      class       => 'SL::DB::Warehouse',
      key_columns => { warehouse_id => 'id' },
    },
  ],
);

1;
;
