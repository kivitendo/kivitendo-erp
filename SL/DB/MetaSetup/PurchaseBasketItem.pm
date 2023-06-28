# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::PurchaseBasketItem;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('purchase_basket_items');

__PACKAGE__->meta->columns(
  cleared    => { type => 'boolean', default => 'false', not_null => 1 },
  id         => { type => 'serial', not_null => 1 },
  itime      => { type => 'timestamp', default => 'now()' },
  mtime      => { type => 'timestamp' },
  orderer_id => { type => 'integer' },
  part_id    => { type => 'integer' },
  qty        => { type => 'numeric', not_null => 1, precision => 15, scale => 5 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  orderer => {
    class       => 'SL::DB::Employee',
    key_columns => { orderer_id => 'id' },
  },

  part => {
    class       => 'SL::DB::Part',
    key_columns => { part_id => 'id' },
  },
);

1;
;
