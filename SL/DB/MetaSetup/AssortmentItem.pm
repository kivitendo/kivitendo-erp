# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::AssortmentItem;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('assortment_items');

__PACKAGE__->meta->columns(
  assortment_id => { type => 'integer', not_null => 1 },
  charge        => { type => 'boolean', default => 'true' },
  itime         => { type => 'timestamp', default => 'now()' },
  mtime         => { type => 'timestamp' },
  parts_id      => { type => 'integer', not_null => 1 },
  position      => { type => 'integer', not_null => 1 },
  qty           => { type => 'float', not_null => 1, precision => 4, scale => 4 },
  unit          => { type => 'varchar', length => 20, not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'assortment_id', 'parts_id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  assortment => {
    class       => 'SL::DB::Part',
    key_columns => { assortment_id => 'id' },
  },

  part => {
    class       => 'SL::DB::Part',
    key_columns => { parts_id => 'id' },
  },

  unit_obj => {
    class       => 'SL::DB::Unit',
    key_columns => { unit => 'name' },
  },
);

1;
;
