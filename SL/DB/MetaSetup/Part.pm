# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Part;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'parts',

  columns => [
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
    bin                => { type => 'text' },
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
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,

  foreign_keys => [
    buchungsgruppen => {
      class       => 'SL::DB::Buchungsgruppe',
      key_columns => { buchungsgruppen_id => 'id' },
    },
  ],
);

1;
;
