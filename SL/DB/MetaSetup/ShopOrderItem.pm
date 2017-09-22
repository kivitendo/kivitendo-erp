# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::ShopOrderItem;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('shop_order_items');

__PACKAGE__->meta->columns(
  active_price_source => { type => 'text' },
  description         => { type => 'text' },
  id                  => { type => 'serial', not_null => 1 },
  partnumber          => { type => 'text' },
  position            => { type => 'integer' },
  price               => { type => 'numeric', precision => 15, scale => 5 },
  quantity            => { type => 'numeric', precision => 25, scale => 5 },
  shop_order_id       => { type => 'integer' },
  shop_trans_id       => { type => 'integer', not_null => 1 },
  tax_rate            => { type => 'numeric', precision => 15, scale => 2 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->foreign_keys(
  shop_order => {
    class       => 'SL::DB::ShopOrder',
    key_columns => { shop_order_id => 'id' },
  },
);

1;
;
