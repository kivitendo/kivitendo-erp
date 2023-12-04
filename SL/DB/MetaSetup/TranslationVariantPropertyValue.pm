# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::TranslationVariantPropertyValue;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('translation_variant_property_values');

__PACKAGE__->meta->columns(
  itime                     => { type => 'timestamp', default => 'now()' },
  language_id               => { type => 'integer', not_null => 1 },
  mtime                     => { type => 'timestamp' },
  value                     => { type => 'text', not_null => 1 },
  variant_property_value_id => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'variant_property_value_id', 'language_id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  language => {
    class       => 'SL::DB::Language',
    key_columns => { language_id => 'id' },
  },

  variant_property_value => {
    class       => 'SL::DB::VariantPropertyValue',
    key_columns => { variant_property_value_id => 'id' },
  },
);

1;
;
