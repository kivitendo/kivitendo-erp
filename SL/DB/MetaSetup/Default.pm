# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Default;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('defaults');

__PACKAGE__->meta->columns(
  accounting_method                       => { type => 'text' },
  address                                 => { type => 'text' },
  ap_changeable                           => { type => 'integer', default => 2, not_null => 1 },
  ap_show_mark_as_paid                    => { type => 'boolean', default => 'true' },
  ar_changeable                           => { type => 'integer', default => 2, not_null => 1 },
  ar_paid_accno_id                        => { type => 'integer' },
  ar_show_mark_as_paid                    => { type => 'boolean', default => 'true' },
  articlenumber                           => { type => 'text' },
  assemblynumber                          => { type => 'text' },
  audittrail                              => { type => 'boolean', default => 'false' },
  bin_id                                  => { type => 'integer' },
  bin_id_ignore_onhand                    => { type => 'integer' },
  businessnumber                          => { type => 'text' },
  closedto                                => { type => 'date' },
  cnnumber                                => { type => 'text' },
  co_ustid                                => { type => 'text' },
  coa                                     => { type => 'text' },
  company                                 => { type => 'text' },
  currency_id                             => { type => 'integer', not_null => 1 },
  customernumber                          => { type => 'text' },
  datev_check_on_ap_transaction           => { type => 'boolean', default => 'true' },
  datev_check_on_ar_transaction           => { type => 'boolean', default => 'true' },
  datev_check_on_gl_transaction           => { type => 'boolean', default => 'true' },
  datev_check_on_purchase_invoice         => { type => 'boolean', default => 'true' },
  datev_check_on_sales_invoice            => { type => 'boolean', default => 'true' },
  dunning_ar                              => { type => 'integer' },
  dunning_ar_amount_fee                   => { type => 'integer' },
  dunning_ar_amount_interest              => { type => 'integer' },
  duns                                    => { type => 'text' },
  expense_accno_id                        => { type => 'integer' },
  fxgain_accno_id                         => { type => 'integer' },
  fxloss_accno_id                         => { type => 'integer' },
  gl_changeable                           => { type => 'integer', default => 2, not_null => 1 },
  id                                      => { type => 'serial', not_null => 1 },
  income_accno_id                         => { type => 'integer' },
  inventory_accno_id                      => { type => 'integer' },
  inventory_system                        => { type => 'text' },
  invnumber                               => { type => 'text' },
  ir_changeable                           => { type => 'integer', default => 2, not_null => 1 },
  ir_show_mark_as_paid                    => { type => 'boolean', default => 'true' },
  is_changeable                           => { type => 'integer', default => 2, not_null => 1 },
  is_show_mark_as_paid                    => { type => 'boolean', default => 'true' },
  itime                                   => { type => 'timestamp', default => 'now()' },
  language_id                             => { type => 'integer' },
  max_future_booking_interval             => { type => 'integer', default => 360 },
  mtime                                   => { type => 'timestamp' },
  parts_image_css                         => { type => 'text', default => 'border:0;float:left;max-width:250px;margin-top:20px:margin-right:10px;margin-left:10px;' },
  parts_listing_image                     => { type => 'boolean', default => 'true' },
  parts_show_image                        => { type => 'boolean', default => 'true' },
  payments_changeable                     => { type => 'integer', default => '0', not_null => 1 },
  pdonumber                               => { type => 'text' },
  ponumber                                => { type => 'text' },
  profit_determination                    => { type => 'text' },
  purchase_delivery_order_show_delete     => { type => 'boolean', default => 'true' },
  purchase_order_show_delete              => { type => 'boolean', default => 'true' },
  revtrans                                => { type => 'boolean', default => 'false' },
  rfqnumber                               => { type => 'text' },
  rmanumber                               => { type => 'text' },
  sales_delivery_order_show_delete        => { type => 'boolean', default => 'true' },
  sales_order_show_delete                 => { type => 'boolean', default => 'true' },
  sdonumber                               => { type => 'text' },
  sepa_creditor_id                        => { type => 'text' },
  servicenumber                           => { type => 'text' },
  show_bestbefore                         => { type => 'boolean', default => 'false' },
  show_weight                             => { type => 'boolean', default => 'false', not_null => 1 },
  sonumber                                => { type => 'text' },
  sqnumber                                => { type => 'text' },
  taxnumber                               => { type => 'text' },
  templates                               => { type => 'text' },
  transfer_default                        => { type => 'boolean', default => 'true' },
  transfer_default_ignore_onhand          => { type => 'boolean', default => 'false' },
  transfer_default_use_master_default_bin => { type => 'boolean', default => 'false' },
  vendornumber                            => { type => 'text' },
  version                                 => { type => 'varchar', length => 8 },
  vertreter                               => { type => 'boolean', default => 'false' },
  warehouse_id                            => { type => 'integer' },
  warehouse_id_ignore_onhand              => { type => 'integer' },
  webdav                                  => { type => 'boolean', default => 'false' },
  webdav_documents                        => { type => 'boolean', default => 'false' },
  weightunit                              => { type => 'varchar', length => 5 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
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
);

1;
;
