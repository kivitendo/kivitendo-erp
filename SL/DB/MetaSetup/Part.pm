# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Part;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('parts');

__PACKAGE__->meta->columns(
  assembly           => { type => 'boolean', default => 'false' },
  bin_id             => { type => 'integer' },
  bom                => { type => 'boolean', default => 'false' },
  buchungsgruppen_id => { type => 'integer' },
  description        => { type => 'text' },
  drawing            => { type => 'text' },
  ean                => { type => 'text' },
  expense_accno_id   => { type => 'integer' },
  formel             => { type => 'text' },
  gv                 => { type => 'numeric', precision => 15, scale => 5 },
  has_sernumber      => { type => 'boolean', default => 'false' },
  id                 => { type => 'integer', not_null => 1, sequence => 'id' },
  image              => { type => 'text' },
  income_accno_id    => { type => 'integer' },
  inventory_accno_id => { type => 'integer' },
  itime              => { type => 'timestamp', default => 'now()' },
  lastcost           => { type => 'numeric', precision => 15, scale => 5 },
  listprice          => { type => 'numeric', precision => 15, scale => 5 },
  makemodel          => { type => 'boolean', default => 'false' },
  microfiche         => { type => 'text' },
  mtime              => { type => 'timestamp' },
  not_discountable   => { type => 'boolean', default => 'false' },
  notes              => { type => 'text' },
  obsolete           => { type => 'boolean', default => 'false' },
  onhand             => { type => 'numeric', default => '0', precision => 25, scale => 5 },
  partnumber         => { type => 'text', not_null => 1 },
  partsgroup_id      => { type => 'integer' },
  payment_id         => { type => 'integer' },
  price_factor_id    => { type => 'integer' },
  priceupdate        => { type => 'date', default => 'now' },
  rop                => { type => 'float', scale => 4 },
  sellprice          => { type => 'numeric', precision => 15, scale => 5 },
  shop               => { type => 'boolean', default => 'false' },
  stockable          => { type => 'boolean', default => 'false' },
  unit               => { type => 'varchar', length => 20, not_null => 1 },
  ve                 => { type => 'integer' },
  warehouse_id       => { type => 'integer' },
  weight             => { type => 'float', scale => 4 },
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

  expense_account => {
    class       => 'SL::DB::Chart',
    key_columns => { expense_accno_id => 'id' },
  },

  income_account => {
    class       => 'SL::DB::Chart',
    key_columns => { income_accno_id => 'id' },
  },

  inventory_account => {
    class       => 'SL::DB::Chart',
    key_columns => { inventory_accno_id => 'id' },
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

1;
;
