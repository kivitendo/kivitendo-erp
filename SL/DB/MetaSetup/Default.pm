# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Default;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('defaults');

__PACKAGE__->meta->columns(
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
  accounting_method                       => { type => 'text' },
  inventory_system                        => { type => 'text' },
  profit_determination                    => { type => 'text' },
  dunning_ar_amount_fee                   => { type => 'integer' },
  dunning_ar_amount_interest              => { type => 'integer' },
  dunning_ar                              => { type => 'integer' },
  pdonumber                               => { type => 'text' },
  sdonumber                               => { type => 'text' },
  ar_paid_accno_id                        => { type => 'integer' },
  id                                      => { type => 'serial', not_null => 1 },
  language_id                             => { type => 'integer' },
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
  warehouse_id                            => { type => 'integer' },
  bin_id                                  => { type => 'integer' },
  max_future_booking_interval             => { type => 'integer', default => 360 },
  assemblynumber                          => { type => 'text' },
  show_weight                             => { type => 'boolean', default => 'false', not_null => 1 },
  transfer_default                        => { type => 'boolean', default => 'true' },
  transfer_default_use_master_default_bin => { type => 'boolean', default => 'false' },
  transfer_default_ignore_onhand          => { type => 'boolean', default => 'false' },
  warehouse_id_ignore_onhand              => { type => 'integer' },
  bin_id_ignore_onhand                    => { type => 'integer' },
  currency_id                             => { type => 'integer', not_null => 1 },
  company                                 => { type => 'text' },
  address                                 => { type => 'text' },
  taxnumber                               => { type => 'text' },
  co_ustid                                => { type => 'text' },
  duns                                    => { type => 'text' },
  sepa_creditor_id                        => { type => 'text' },
  templates                               => { type => 'text' },
  webdav                                  => { type => 'boolean', default => 'false' },
  webdav_documents                        => { type => 'boolean', default => 'false' },
  vertreter                               => { type => 'boolean', default => 'false' },
  parts_show_image                        => { type => 'boolean', default => 'true' },
  parts_listing_image                     => { type => 'boolean', default => 'true' },
  parts_image_css                         => { type => 'text', default => 'border:0;float:left;max-width:250px;margin-top:20px:margin-right:10px;margin-left:10px;' },
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

# __PACKAGE__->meta->initialize;

1;
;
