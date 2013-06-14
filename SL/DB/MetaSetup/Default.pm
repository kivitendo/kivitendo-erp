# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Default;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'defaults',

  columns => [
    inventory_accno_id                      => { type => 'integer' },
    income_accno_id                         => { type => 'integer' },
    expense_accno_id                        => { type => 'integer' },
    fxgain_accno_id                         => { type => 'integer' },
    fxloss_accno_id                         => { type => 'integer' },
    invnumber                               => { type => 'text' },
    sonumber                                => { type => 'text' },
    weightunit                              => { type => 'varchar', length => 5 },
    businessnumber                          => { type => 'text' },
    version                                 => { type => 'varchar', length => 8 },
    closedto                                => { type => 'date' },
    revtrans                                => { type => 'boolean', default => 'false' },
    ponumber                                => { type => 'text' },
    sqnumber                                => { type => 'text' },
    rfqnumber                               => { type => 'text' },
    customernumber                          => { type => 'text' },
    vendornumber                            => { type => 'text' },
    audittrail                              => { type => 'boolean', default => 'false' },
    articlenumber                           => { type => 'text' },
    servicenumber                           => { type => 'text' },
    coa                                     => { type => 'text' },
    itime                                   => { type => 'timestamp', default => 'now()' },
    mtime                                   => { type => 'timestamp' },
    rmanumber                               => { type => 'text' },
    cnnumber                                => { type => 'text' },
    dunning_ar_amount_fee                   => { type => 'integer' },
    dunning_ar_amount_interest              => { type => 'integer' },
    dunning_ar                              => { type => 'integer' },
    pdonumber                               => { type => 'text' },
    sdonumber                               => { type => 'text' },
    ar_paid_accno_id                        => { type => 'integer' },
    id                                      => { type => 'serial', not_null => 1 },
    language_id                             => { type => 'integer' },
    accounting_method                       => { type => 'text' },
    inventory_system                        => { type => 'text' },
    profit_determination                    => { type => 'text' },
    datev_check_on_sales_invoice            => { type => 'boolean', default => 'true' },
    datev_check_on_purchase_invoice         => { type => 'boolean', default => 'true' },
    datev_check_on_ar_transaction           => { type => 'boolean', default => 'true' },
    datev_check_on_ap_transaction           => { type => 'boolean', default => 'true' },
    datev_check_on_gl_transaction           => { type => 'boolean', default => 'true' },
    payments_changeable                     => { type => 'integer', default => '0', not_null => 1 },
    is_changeable                           => { type => 'integer', default => 2, not_null => 1 },
    ir_changeable                           => { type => 'integer', default => 2, not_null => 1 },
    ar_changeable                           => { type => 'integer', default => 2, not_null => 1 },
    ap_changeable                           => { type => 'integer', default => 2, not_null => 1 },
    gl_changeable                           => { type => 'integer', default => 2, not_null => 1 },
    show_bestbefore                         => { type => 'boolean', default => 'false' },
    sales_order_show_delete                 => { type => 'boolean', default => 'true' },
    purchase_order_show_delete              => { type => 'boolean', default => 'true' },
    sales_delivery_order_show_delete        => { type => 'boolean', default => 'true' },
    purchase_delivery_order_show_delete     => { type => 'boolean', default => 'true' },
    is_show_mark_as_paid                    => { type => 'boolean', default => 'true' },
    ir_show_mark_as_paid                    => { type => 'boolean', default => 'true' },
    ar_show_mark_as_paid                    => { type => 'boolean', default => 'true' },
    ap_show_mark_as_paid                    => { type => 'boolean', default => 'true' },
    max_future_booking_interval             => { type => 'integer', default => 360 },
    assemblynumber                          => { type => 'text' },
    warehouse_id                            => { type => 'integer' },
    bin_id                                  => { type => 'integer' },
    company                                 => { type => 'text' },
    address                                 => { type => 'text' },
    taxnumber                               => { type => 'text' },
    co_ustid                                => { type => 'text' },
    duns                                    => { type => 'text' },
    sepa_creditor_id                        => { type => 'text' },
    templates                               => { type => 'text' },
    show_weight                             => { type => 'boolean', default => 'false', not_null => 1 },
    transfer_default                        => { type => 'boolean', default => 'true' },
    transfer_default_use_master_default_bin => { type => 'boolean', default => 'false' },
    transfer_default_ignore_onhand          => { type => 'boolean', default => 'false' },
    warehouse_id_ignore_onhand              => { type => 'integer' },
    bin_id_ignore_onhand                    => { type => 'integer' },
    currency_id                             => { type => 'integer', not_null => 1 },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,

  foreign_keys => [
    bin => {
      class       => 'SL::DB::Bin',
      key_columns => { bin_id => 'id' },
    },

    bin_obj => {
      class       => 'SL::DB::Bin',
      key_columns => { bin_id_ignore_onhand => 'id' },
    },

    currency => {
      class       => 'SL::DB::Currency',
      key_columns => { currency_id => 'id' },
    },

    warehouse => {
      class       => 'SL::DB::Warehouse',
      key_columns => { warehouse_id => 'id' },
    },

    warehouse_obj => {
      class       => 'SL::DB::Warehouse',
      key_columns => { warehouse_id_ignore_onhand => 'id' },
    },
  ],
);

1;
;
