# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Default;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'defaults',

  columns => [
    inventory_accno_id                  => { type => 'integer' },
    income_accno_id                     => { type => 'integer' },
    expense_accno_id                    => { type => 'integer' },
    fxgain_accno_id                     => { type => 'integer' },
    fxloss_accno_id                     => { type => 'integer' },
    invnumber                           => { type => 'text' },
    sonumber                            => { type => 'text' },
    weightunit                          => { type => 'varchar', length => 5 },
    businessnumber                      => { type => 'text' },
    version                             => { type => 'varchar', length => 8 },
    curr                                => { type => 'text' },
    closedto                            => { type => 'date' },
    revtrans                            => { type => 'boolean', default => 'false' },
    ponumber                            => { type => 'text' },
    sqnumber                            => { type => 'text' },
    rfqnumber                           => { type => 'text' },
    customernumber                      => { type => 'text' },
    vendornumber                        => { type => 'text' },
    audittrail                          => { type => 'boolean', default => 'false' },
    articlenumber                       => { type => 'text' },
    servicenumber                       => { type => 'text' },
    coa                                 => { type => 'text' },
    itime                               => { type => 'timestamp', default => 'now()' },
    mtime                               => { type => 'timestamp' },
    rmanumber                           => { type => 'text' },
    cnnumber                            => { type => 'text' },
    dunning_ar_amount_fee               => { type => 'integer' },
    dunning_ar_amount_interest          => { type => 'integer' },
    dunning_ar                          => { type => 'integer' },
    pdonumber                           => { type => 'text' },
    sdonumber                           => { type => 'text' },
    ar_paid_accno_id                    => { type => 'integer' },
    id                                  => { type => 'serial', not_null => 1 },
    language_id                         => { type => 'integer' },
    accounting_method                   => { type => 'text' },
    inventory_system                    => { type => 'text' },
    profit_determination                => { type => 'text' },
    datev_check_on_sales_invoice        => { type => 'boolean', default => 'true' },
    datev_check_on_purchase_invoice     => { type => 'boolean', default => 'true' },
    datev_check_on_ar_transaction       => { type => 'boolean', default => 'true' },
    datev_check_on_ap_transaction       => { type => 'boolean', default => 'true' },
    datev_check_on_gl_transaction       => { type => 'boolean', default => 'true' },
    payments_changeable                 => { type => 'integer', default => '0', not_null => 1 },
    is_changeable                       => { type => 'integer', default => 2, not_null => 1 },
    ir_changeable                       => { type => 'integer', default => 2, not_null => 1 },
    ar_changeable                       => { type => 'integer', default => 2, not_null => 1 },
    ap_changeable                       => { type => 'integer', default => 2, not_null => 1 },
    gl_changeable                       => { type => 'integer', default => 2, not_null => 1 },
    show_bestbefore                     => { type => 'boolean', default => 'false' },
    sales_order_show_delete             => { type => 'boolean', default => 'true' },
    purchase_order_show_delete          => { type => 'boolean', default => 'true' },
    sales_delivery_order_show_delete    => { type => 'boolean', default => 'true' },
    purchase_delivery_order_show_delete => { type => 'boolean', default => 'true' },
    is_show_mark_as_paid                => { type => 'boolean', default => 'true' },
    ir_show_mark_as_paid                => { type => 'boolean', default => 'true' },
    ar_show_mark_as_paid                => { type => 'boolean', default => 'true' },
    ap_show_mark_as_paid                => { type => 'boolean', default => 'true' },
    assemblynumber                      => { type => 'text' },
    warehouse_id                        => { type => 'integer' },
    bin_id                              => { type => 'integer' },
  ],

  primary_key_columns => [ 'id' ],

  foreign_keys => [
    bin => {
      class       => 'SL::DB::Bin',
      key_columns => { bin_id => 'id' },
    },

    warehouse => {
      class       => 'SL::DB::Warehouse',
      key_columns => { warehouse_id => 'id' },
    },
  ],
);

1;
;
