# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::OrderItem;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('orderitems');

__PACKAGE__->meta->columns(
  trans_id           => { type => 'integer' },
  parts_id           => { type => 'integer' },
  description        => { type => 'text' },
  qty                => { type => 'float', precision => 4 },
  sellprice          => { type => 'numeric', precision => 5, scale => 15 },
  discount           => { type => 'float', precision => 4 },
  project_id         => { type => 'integer' },
  reqdate            => { type => 'date' },
  ship               => { type => 'float', precision => 4 },
  serialnumber       => { type => 'text' },
  id                 => { type => 'integer', not_null => 1, sequence => 'orderitemsid' },
  itime              => { type => 'timestamp', default => 'now()' },
  mtime              => { type => 'timestamp' },
  pricegroup_id      => { type => 'integer' },
  ordnumber          => { type => 'text' },
  transdate          => { type => 'text' },
  cusordnumber       => { type => 'text' },
  unit               => { type => 'varchar', length => 20 },
  base_qty           => { type => 'float', precision => 4 },
  subtotal           => { type => 'boolean', default => 'false' },
  longdescription    => { type => 'text' },
  marge_total        => { type => 'numeric', precision => 5, scale => 15 },
  marge_percent      => { type => 'numeric', precision => 5, scale => 15 },
  lastcost           => { type => 'numeric', precision => 5, scale => 15 },
  price_factor_id    => { type => 'integer' },
  price_factor       => { type => 'numeric', default => 1, precision => 5, scale => 15 },
  marge_price_factor => { type => 'numeric', default => 1, precision => 5, scale => 15 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
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

  order => {
    class       => 'SL::DB::Order',
    key_columns => { trans_id => 'id' },
  },
);

# __PACKAGE__->meta->initialize;

1;
;
