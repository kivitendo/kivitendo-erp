# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Bin;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('bin');

__PACKAGE__->meta->columns(
  description  => { type => 'text' },
  id           => { type => 'integer', not_null => 1, sequence => 'id' },
  itime        => { type => 'timestamp', default => 'now()' },
  mtime        => { type => 'timestamp' },
  warehouse_id => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  warehouse => {
    class       => 'SL::DB::Warehouse',
    key_columns => { warehouse_id => 'id' },
  },
);

1;
;
