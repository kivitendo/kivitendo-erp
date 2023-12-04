# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::TranslationVariantProperty;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('translation_variant_properties');

__PACKAGE__->meta->columns(
  itime               => { type => 'timestamp', default => 'now()' },
  language_id         => { type => 'integer', not_null => 1 },
  mtime               => { type => 'timestamp' },
  name                => { type => 'text', not_null => 1 },
  variant_property_id => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'variant_property_id', 'language_id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  language => {
    class       => 'SL::DB::Language',
    key_columns => { language_id => 'id' },
  },

  variant_property => {
    class       => 'SL::DB::VariantProperty',
    key_columns => { variant_property_id => 'id' },
  },
);

1;
;
