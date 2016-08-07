# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Price;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('prices');

__PACKAGE__->meta->columns(
  id            => { type => 'serial', not_null => 1 },
  parts_id      => { type => 'integer', not_null => 1 },
  price         => { type => 'numeric', precision => 15, scale => 5 },
  pricegroup_id => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->unique_keys([ 'parts_id', 'pricegroup_id' ]);

__PACKAGE__->meta->foreign_keys(
  parts => {
    class       => 'SL::DB::Part',
    key_columns => { parts_id => 'id' },
  },

  pricegroup => {
    class       => 'SL::DB::Pricegroup',
    key_columns => { pricegroup_id => 'id' },
  },
);

1;
;
