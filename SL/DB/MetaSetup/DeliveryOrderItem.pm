# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::DeliveryOrderItem;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'delivery_order_items',

  columns => [
    id                 => { type => 'integer', not_null => 1, sequence => 'delivery_order_items_id' },
    delivery_order_id  => { type => 'integer', not_null => 1 },
    parts_id           => { type => 'integer', not_null => 1 },
    description        => { type => 'text' },
    qty                => { type => 'numeric', precision => 5, scale => 25 },
    sellprice          => { type => 'numeric', precision => 5, scale => 15 },
    discount           => { type => 'float', precision => 4 },
    project_id         => { type => 'integer' },
    reqdate            => { type => 'date' },
    serialnumber       => { type => 'text' },
    ordnumber          => { type => 'text' },
    transdate          => { type => 'text' },
    cusordnumber       => { type => 'text' },
    unit               => { type => 'varchar', length => 20 },
    base_qty           => { type => 'float', precision => 4 },
    longdescription    => { type => 'text' },
    lastcost           => { type => 'numeric', precision => 5, scale => 15 },
    price_factor_id    => { type => 'integer' },
    price_factor       => { type => 'numeric', default => 1, precision => 5, scale => 15 },
    marge_price_factor => { type => 'numeric', default => 1, precision => 5, scale => 15 },
    itime              => { type => 'timestamp', default => 'now()' },
    mtime              => { type => 'timestamp' },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,

  foreign_keys => [
    delivery_order => {
      class       => 'SL::DB::DeliveryOrder',
      key_columns => { delivery_order_id => 'id' },
    },

    parts => {
      class       => 'SL::DB::Part',
      key_columns => { parts_id => 'id' },
    },

    price_factor_obj => {
      class       => 'SL::DB::PriceFactor',
      key_columns => { price_factor_id => 'id' },
    },

    project => {
      class       => 'SL::DB::Project',
      key_columns => { project_id => 'id' },
    },
  ],
);

1;
;
