# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Part;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('parts');

__PACKAGE__->meta->columns(
  id                 => { type => 'integer', not_null => 1, sequence => 'id' },
  partnumber         => { type => 'text', not_null => 1 },
  description        => { type => 'text' },
  listprice          => { type => 'numeric', precision => 5, scale => 15 },
  sellprice          => { type => 'numeric', precision => 5, scale => 15 },
  lastcost           => { type => 'numeric', precision => 5, scale => 15 },
  priceupdate        => { type => 'date', default => 'now' },
  weight             => { type => 'float', precision => 4 },
  notes              => { type => 'text' },
  makemodel          => { type => 'boolean', default => 'false' },
  assembly           => { type => 'boolean', default => 'false' },
  alternate          => { type => 'boolean', default => 'false' },
  rop                => { type => 'float', precision => 4 },
  inventory_accno_id => { type => 'integer' },
  income_accno_id    => { type => 'integer' },
  expense_accno_id   => { type => 'integer' },
  shop               => { type => 'boolean', default => 'false' },
  obsolete           => { type => 'boolean', default => 'false' },
  bom                => { type => 'boolean', default => 'false' },
  image              => { type => 'text' },
  drawing            => { type => 'text' },
  microfiche         => { type => 'text' },
  partsgroup_id      => { type => 'integer' },
  ve                 => { type => 'integer' },
  gv                 => { type => 'numeric', precision => 5, scale => 15 },
  itime              => { type => 'timestamp', default => 'now()' },
  mtime              => { type => 'timestamp' },
  unit               => { type => 'varchar', length => 20, not_null => 1 },
  formel             => { type => 'text' },
  not_discountable   => { type => 'boolean', default => 'false' },
  buchungsgruppen_id => { type => 'integer' },
  payment_id         => { type => 'integer' },
  ean                => { type => 'text' },
  price_factor_id    => { type => 'integer' },
  onhand             => { type => 'numeric', default => '0', precision => 5, scale => 25 },
  stockable          => { type => 'boolean', default => 'false' },
  has_sernumber      => { type => 'boolean', default => 'false' },
  warehouse_id       => { type => 'integer' },
  bin_id             => { type => 'integer' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->unique_keys([ 'partnumber' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  bin => {
    class       => 'SL::DB::Bin',
    key_columns => { bin_id => 'id' },
  },

  buchungsgruppen => {
    class       => 'SL::DB::Buchungsgruppe',
    key_columns => { buchungsgruppen_id => 'id' },
  },

  partsgroup => {
    class       => 'SL::DB::PartsGroup',
    key_columns => { partsgroup_id => 'id' },
  },

  payment => {
    class       => 'SL::DB::PaymentTerm',
    key_columns => { payment_id => 'id' },
  },

  price_factor => {
    class       => 'SL::DB::PriceFactor',
    key_columns => { price_factor_id => 'id' },
  },

  unit_obj => {
    class       => 'SL::DB::Unit',
    key_columns => { unit => 'name' },
  },

  warehouse => {
    class       => 'SL::DB::Warehouse',
    key_columns => { warehouse_id => 'id' },
  },
);

# __PACKAGE__->meta->initialize;

1;
;
