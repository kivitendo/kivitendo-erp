# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::VariantProperty;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('variant_properties');

__PACKAGE__->meta->columns(
  abbreviation => { type => 'varchar', length => 4, not_null => 1 },
  id           => { type => 'serial', not_null => 1 },
  itime        => { type => 'timestamp', default => 'now()' },
  mtime        => { type => 'timestamp' },
  name         => { type => 'text', not_null => 1 },
  sortkey      => { type => 'integer' },
  unique_name  => { type => 'text', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->unique_keys([ 'unique_name' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

1;
;
