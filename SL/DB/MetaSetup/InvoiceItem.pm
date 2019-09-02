# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::InvoiceItem;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('invoice');

__PACKAGE__->meta->columns(
  active_discount_source => { type => 'text', default => '', not_null => 1 },
  active_price_source    => { type => 'text', default => '', not_null => 1 },
  allocated              => { type => 'float', precision => 4, scale => 4 },
  assemblyitem           => { type => 'boolean', default => 'false' },
  base_qty               => { type => 'float', precision => 4, scale => 4 },
  cusordnumber           => { type => 'text' },
  deliverydate           => { type => 'date' },
  description            => { type => 'text' },
  discount               => { type => 'float', precision => 4, scale => 4 },
  donumber               => { type => 'text' },
  fxsellprice            => { type => 'numeric', precision => 15, scale => 5 },
  id                     => { type => 'integer', not_null => 1, sequence => 'invoiceid' },
  itime                  => { type => 'timestamp', default => 'now()' },
  lastcost               => { type => 'numeric', precision => 15, scale => 5 },
  longdescription        => { type => 'text' },
  marge_percent          => { type => 'numeric', precision => 15, scale => 5 },
  marge_price_factor     => { type => 'numeric', default => 1, precision => 15, scale => 5 },
  marge_total            => { type => 'numeric', precision => 15, scale => 5 },
  mtime                  => { type => 'timestamp' },
  ordnumber              => { type => 'text' },
  parts_id               => { type => 'integer' },
  position               => { type => 'integer', not_null => 1 },
  price_factor           => { type => 'numeric', default => 1, precision => 15, scale => 5 },
  price_factor_id        => { type => 'integer' },
  pricegroup_id          => { type => 'integer' },
  project_id             => { type => 'integer' },
  qty                    => { type => 'float', precision => 4, scale => 4 },
  sellprice              => { type => 'numeric', precision => 15, scale => 5 },
  serialnumber           => { type => 'text' },
  subtotal               => { type => 'boolean', default => 'false' },
  trans_id               => { type => 'integer' },
  transdate              => { type => 'text' },
  unit                   => { type => 'varchar', length => 20 },
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

  unit_obj => {
    class       => 'SL::DB::Unit',
    key_columns => { unit => 'name' },
  },
);

1;
;
