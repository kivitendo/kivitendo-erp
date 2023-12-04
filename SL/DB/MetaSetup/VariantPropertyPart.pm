# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::VariantPropertyPart;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('variant_properties_parts');

__PACKAGE__->meta->columns(
  part_id             => { type => 'integer', not_null => 1 },
  variant_property_id => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'part_id', 'variant_property_id' ]);

__PACKAGE__->meta->unique_keys([ 'variant_property_id', 'part_id' ]);

__PACKAGE__->meta->foreign_keys(
  part => {
    class       => 'SL::DB::Part',
    key_columns => { part_id => 'id' },
  },

  variant_property => {
    class       => 'SL::DB::VariantProperty',
    key_columns => { variant_property_id => 'id' },
  },
);

1;
;
