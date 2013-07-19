# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::DeliveryOrderItem;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('delivery_order_items');

__PACKAGE__->meta->columns(
  base_qty           => { type => 'float', precision => 4 },
  cusordnumber       => { type => 'text' },
  delivery_order_id  => { type => 'integer', not_null => 1 },
  description        => { type => 'text' },
  discount           => { type => 'float', precision => 4 },
  id                 => { type => 'integer', not_null => 1, sequence => 'delivery_order_items_id' },
  itime              => { type => 'timestamp', default => 'now()' },
  lastcost           => { type => 'numeric', precision => 5, scale => 15 },
  longdescription    => { type => 'text' },
  marge_price_factor => { type => 'numeric', default => 1, precision => 5, scale => 15 },
  mtime              => { type => 'timestamp' },
  ordnumber          => { type => 'text' },
  parts_id           => { type => 'integer', not_null => 1 },
  price_factor       => { type => 'numeric', default => 1, precision => 5, scale => 15 },
  price_factor_id    => { type => 'integer' },
  pricegroup_id      => { type => 'integer' },
  project_id         => { type => 'integer' },
  qty                => { type => 'numeric', precision => 5, scale => 25 },
  reqdate            => { type => 'date' },
  sellprice          => { type => 'numeric', precision => 5, scale => 15 },
  serialnumber       => { type => 'text' },
  transdate          => { type => 'text' },
  unit               => { type => 'varchar', length => 20 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  delivery_order => {
    class       => 'SL::DB::DeliveryOrder',
    key_columns => { delivery_order_id => 'id' },
  },

  part => {
    class       => 'SL::DB::Part',
    key_columns => { parts_id => 'id' },
  },

  price_factor_obj => {
    class       => 'SL::DB::PriceFactor',
    key_columns => { price_factor_id => 'id' },
  },

  pricegroup => {
    class       => 'SL::DB::Pricegroup',
    key_columns => { pricegroup_id => 'id' },
  },

  project => {
    class       => 'SL::DB::Project',
    key_columns => { project_id => 'id' },
  },
);

1;
;
