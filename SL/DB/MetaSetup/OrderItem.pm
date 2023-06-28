# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::OrderItem;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('orderitems');

__PACKAGE__->meta->columns(
  active_discount_source       => { type => 'text', default => '', not_null => 1 },
  active_price_source          => { type => 'text', default => '', not_null => 1 },
  base_qty                     => { type => 'float', precision => 4, scale => 4 },
  cusordnumber                 => { type => 'text' },
  description                  => { type => 'text' },
  discount                     => { type => 'float', precision => 4, scale => 4 },
  id                           => { type => 'integer', not_null => 1, sequence => 'orderitemsid' },
  itime                        => { type => 'timestamp', default => 'now()' },
  lastcost                     => { type => 'numeric', precision => 15, scale => 5 },
  longdescription              => { type => 'text' },
  marge_percent                => { type => 'numeric', precision => 15, scale => 5 },
  marge_price_factor           => { type => 'numeric', default => 1, precision => 15, scale => 5 },
  marge_total                  => { type => 'numeric', precision => 15, scale => 5 },
  mtime                        => { type => 'timestamp' },
  optional                     => { type => 'boolean', default => 'false' },
  orderer_id                   => { type => 'integer' },
  ordnumber                    => { type => 'text' },
  parts_id                     => { type => 'integer' },
  position                     => { type => 'integer', not_null => 1 },
  price_factor                 => { type => 'numeric', default => 1, precision => 15, scale => 5 },
  price_factor_id              => { type => 'integer' },
  pricegroup_id                => { type => 'integer' },
  project_id                   => { type => 'integer' },
  qty                          => { type => 'numeric', precision => 25, scale => 5 },
  recurring_billing_invoice_id => { type => 'integer' },
  recurring_billing_mode       => { type => 'enum', check_in => [ 'never', 'once', 'always' ], db_type => 'items_recurring_billing_mode', default => 'always', not_null => 1 },
  reqdate                      => { type => 'date' },
  sellprice                    => { type => 'numeric', precision => 15, scale => 5 },
  serialnumber                 => { type => 'text' },
  ship                         => { type => 'float', precision => 4, scale => 4 },
  subtotal                     => { type => 'boolean', default => 'false' },
  trans_id                     => { type => 'integer' },
  transdate                    => { type => 'text' },
  unit                         => { type => 'varchar', length => 20 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  order => {
    class       => 'SL::DB::Order',
    key_columns => { trans_id => 'id' },
  },

  orderer => {
    class       => 'SL::DB::Employee',
    key_columns => { orderer_id => 'id' },
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

  recurring_billing_invoice => {
    class       => 'SL::DB::Invoice',
    key_columns => { recurring_billing_invoice_id => 'id' },
  },

  unit_obj => {
    class       => 'SL::DB::Unit',
    key_columns => { unit => 'name' },
  },
);

1;
;
