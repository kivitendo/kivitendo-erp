# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::VariantPropertyValue;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('variant_property_values');

__PACKAGE__->meta->columns(
  abbreviation        => { type => 'varchar', length => 4, not_null => 1 },
  id                  => { type => 'serial', not_null => 1 },
  itime               => { type => 'timestamp', default => 'now()' },
  mtime               => { type => 'timestamp' },
  sortkey             => { type => 'integer', not_null => 1 },
  value               => { type => 'text', not_null => 1 },
  variant_property_id => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  variant_property => {
    class       => 'SL::DB::VariantProperty',
    key_columns => { variant_property_id => 'id' },
  },
);

1;
;
