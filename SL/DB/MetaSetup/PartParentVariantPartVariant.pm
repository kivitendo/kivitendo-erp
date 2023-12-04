# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::PartParentVariantPartVariant;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('parts_parent_variant_id_parts_variant_id');

__PACKAGE__->meta->columns(
  parent_variant_id => { type => 'integer', not_null => 1 },
  variant_id        => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'parent_variant_id', 'variant_id' ]);

__PACKAGE__->meta->unique_keys([ 'variant_id' ]);

__PACKAGE__->meta->foreign_keys(
  parent_variant => {
    class       => 'SL::DB::Part',
    key_columns => { parent_variant_id => 'id' },
  },

  variant => {
    class       => 'SL::DB::Part',
    key_columns => { variant_id => 'id' },
    rel_type    => 'one to one',
  },
);

1;
;
