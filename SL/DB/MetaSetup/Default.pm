# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Default;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('defaults');

__PACKAGE__->meta->columns(
  accounting_method                         => { type => 'text' },
  address                                   => { type => 'text' },
  allow_new_purchase_delivery_order         => { type => 'boolean', default => 'true', not_null => 1 },
  allow_new_purchase_invoice                => { type => 'boolean', default => 'true', not_null => 1 },
  allow_sales_invoice_from_sales_order      => { type => 'boolean', default => 'true', not_null => 1 },
  allow_sales_invoice_from_sales_quotation  => { type => 'boolean', default => 'true', not_null => 1 },
  ap_changeable                             => { type => 'integer', default => 2, not_null => 1 },
  ap_chart_id                               => { type => 'integer' },
  ap_show_mark_as_paid                      => { type => 'boolean', default => 'true' },
  ar_changeable                             => { type => 'integer', default => 2, not_null => 1 },
  ar_chart_id                               => { type => 'integer' },
  ar_paid_accno_id                          => { type => 'integer' },
  ar_show_mark_as_paid                      => { type => 'boolean', default => 'true' },
  articlenumber                             => { type => 'text' },
  assemblynumber                            => { type => 'text' },
  assortmentnumber                          => { type => 'text' },
  balance_startdate_method                  => { type => 'text' },
  bcc_to_login                              => { type => 'boolean', default => 'false', not_null => 1 },
  bin_id                                    => { type => 'integer' },
  bin_id_ignore_onhand                      => { type => 'integer' },
  businessnumber                            => { type => 'text' },
  closedto                                  => { type => 'date' },
  cnnumber                                  => { type => 'text' },
  co_ustid                                  => { type => 'text' },
  coa                                       => { type => 'text' },
  company                                   => { type => 'text' },
  create_part_if_not_found                  => { type => 'boolean', default => 'false' },
  currency_id                               => { type => 'integer', not_null => 1 },
  customer_hourly_rate                      => { type => 'numeric', precision => 8, scale => 2 },
  customer_projects_only_in_sales           => { type => 'boolean', default => 'false', not_null => 1 },
  customernumber                            => { type => 'text' },
  datev_check_on_ap_transaction             => { type => 'boolean', default => 'true' },
  datev_check_on_ar_transaction             => { type => 'boolean', default => 'true' },
  datev_check_on_gl_transaction             => { type => 'boolean', default => 'true' },
  datev_check_on_purchase_invoice           => { type => 'boolean', default => 'true' },
  datev_check_on_sales_invoice              => { type => 'boolean', default => 'true' },
  disabled_price_sources                    => { type => 'array' },
  doc_database                              => { type => 'boolean', default => 'false' },
  doc_delete_printfiles                     => { type => 'boolean', default => 'false' },
  doc_files                                 => { type => 'boolean', default => 'false' },
  doc_files_rootpath                        => { type => 'text', default => './documents' },
  doc_max_filesize                          => { type => 'integer', default => 10000000 },
  doc_storage                               => { type => 'boolean', default => 'false' },
  doc_storage_for_attachments               => { type => 'text', default => 'Filesystem' },
  doc_storage_for_documents                 => { type => 'text', default => 'Filesystem' },
  doc_storage_for_images                    => { type => 'text', default => 'Filesystem' },
  doc_storage_for_shopimages                => { type => 'text', default => 'Filesystem' },
  doc_webdav                                => { type => 'boolean', default => 'false' },
  dunning_ar                                => { type => 'integer' },
  dunning_ar_amount_fee                     => { type => 'integer' },
  dunning_ar_amount_interest                => { type => 'integer' },
  duns                                      => { type => 'text' },
  email_journal                             => { type => 'integer', default => 2 },
  expense_accno_id                          => { type => 'integer' },
  fa_bufa_nr                                => { type => 'text' },
  fa_dauerfrist                             => { type => 'text' },
  fa_steuerberater_city                     => { type => 'text' },
  fa_steuerberater_name                     => { type => 'text' },
  fa_steuerberater_street                   => { type => 'text' },
  fa_steuerberater_tel                      => { type => 'text' },
  fa_voranmeld                              => { type => 'text' },
  feature_balance                           => { type => 'boolean', default => 'true', not_null => 1 },
  feature_datev                             => { type => 'boolean', default => 'true', not_null => 1 },
  feature_erfolgsrechnung                   => { type => 'boolean', default => 'false', not_null => 1 },
  feature_eurechnung                        => { type => 'boolean', default => 'true', not_null => 1 },
  feature_experimental                      => { type => 'boolean', default => 'true', not_null => 1 },
  feature_ustva                             => { type => 'boolean', default => 'true', not_null => 1 },
  fxgain_accno_id                           => { type => 'integer' },
  fxloss_accno_id                           => { type => 'integer' },
  gl_changeable                             => { type => 'integer', default => 2, not_null => 1 },
  global_bcc                                => { type => 'text', default => '' },
  id                                        => { type => 'serial', not_null => 1 },
  income_accno_id                           => { type => 'integer' },
  inventory_accno_id                        => { type => 'integer' },
  inventory_system                          => { type => 'text' },
  invnumber                                 => { type => 'text' },
  ir_changeable                             => { type => 'integer', default => 2, not_null => 1 },
  ir_show_mark_as_paid                      => { type => 'boolean', default => 'true' },
  is_changeable                             => { type => 'integer', default => 2, not_null => 1 },
  is_show_mark_as_paid                      => { type => 'boolean', default => 'true' },
  is_transfer_out                           => { type => 'boolean', default => 'false', not_null => 1 },
  itime                                     => { type => 'timestamp', default => 'now()' },
  language_id                               => { type => 'integer' },
  letternumber                              => { type => 'integer' },
  max_future_booking_interval               => { type => 'integer', default => 360 },
  mtime                                     => { type => 'timestamp' },
  normalize_part_descriptions               => { type => 'boolean', default => 'true' },
  normalize_vc_names                        => { type => 'boolean', default => 'true' },
  order_always_project                      => { type => 'boolean', default => 'false' },
  order_warn_duplicate_parts                => { type => 'boolean', default => 'true' },
  order_warn_no_deliverydate                => { type => 'boolean', default => 'true' },
  parts_image_css                           => { type => 'text', default => 'border:0;float:left;max-width:250px;margin-top:20px:margin-right:10px;margin-left:10px;' },
  parts_listing_image                       => { type => 'boolean', default => 'true' },
  parts_show_image                          => { type => 'boolean', default => 'true' },
  payments_changeable                       => { type => 'integer', default => '0', not_null => 1 },
  pdonumber                                 => { type => 'text' },
  ponumber                                  => { type => 'text' },
  precision                                 => { type => 'numeric', default => '0.01', not_null => 1, precision => 15, scale => 5 },
  profit_determination                      => { type => 'text' },
  project_status_id                         => { type => 'integer' },
  project_type_id                           => { type => 'integer' },
  purchase_delivery_order_show_delete       => { type => 'boolean', default => 'true' },
  purchase_order_show_delete                => { type => 'boolean', default => 'true' },
  quick_search_modules                      => { type => 'array' },
  reqdate_interval                          => { type => 'integer', default => '0' },
  require_transaction_description_ps        => { type => 'boolean', default => 'false', not_null => 1 },
  requirement_spec_section_order_part_id    => { type => 'integer' },
  revtrans                                  => { type => 'boolean', default => 'false' },
  rfqnumber                                 => { type => 'text' },
  rmanumber                                 => { type => 'text' },
  rndgain_accno_id                          => { type => 'integer' },
  rndloss_accno_id                          => { type => 'integer' },
  sales_delivery_order_show_delete          => { type => 'boolean', default => 'true' },
  sales_order_show_delete                   => { type => 'boolean', default => 'true' },
  sales_purchase_order_ship_missing_column  => { type => 'boolean', default => 'false' },
  sdonumber                                 => { type => 'text' },
  sepa_creditor_id                          => { type => 'text' },
  sepa_reference_add_vc_vc_id               => { type => 'boolean', default => 'false' },
  servicenumber                             => { type => 'text' },
  shipped_qty_fill_up                       => { type => 'boolean', default => 'true', not_null => 1 },
  shipped_qty_item_identity_fields          => { type => 'array', default => '{parts_id}', not_null => 1 },
  shipped_qty_require_stock_out             => { type => 'boolean', default => 'false', not_null => 1 },
  show_bestbefore                           => { type => 'boolean', default => 'false' },
  show_longdescription_select_item          => { type => 'boolean', default => 'false' },
  show_weight                               => { type => 'boolean', default => 'false', not_null => 1 },
  signature                                 => { type => 'text' },
  sonumber                                  => { type => 'text' },
  sqnumber                                  => { type => 'text' },
  stocktaking_bin_id                        => { type => 'integer' },
  stocktaking_cutoff_date                   => { type => 'date' },
  stocktaking_warehouse_id                  => { type => 'integer' },
  taxnumber                                 => { type => 'text' },
  templates                                 => { type => 'text' },
  transfer_default                          => { type => 'boolean', default => 'true' },
  transfer_default_ignore_onhand            => { type => 'boolean', default => 'false' },
  transfer_default_services                 => { type => 'boolean', default => 'true' },
  transfer_default_use_master_default_bin   => { type => 'boolean', default => 'false' },
  transfer_default_warehouse_for_assembly   => { type => 'boolean', default => 'false' },
  transport_cost_reminder_article_number_id => { type => 'integer' },
  vendornumber                              => { type => 'text' },
  version                                   => { type => 'varchar', length => 8 },
  vertreter                                 => { type => 'boolean', default => 'false' },
  warehouse_id                              => { type => 'integer' },
  warehouse_id_ignore_onhand                => { type => 'integer' },
  webdav                                    => { type => 'boolean', default => 'false' },
  webdav_documents                          => { type => 'boolean', default => 'false' },
  weightunit                                => { type => 'varchar', length => 5 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  ap_chart => {
    class       => 'SL::DB::Chart',
    key_columns => { ap_chart_id => 'id' },
  },

  ar_chart => {
    class       => 'SL::DB::Chart',
    key_columns => { ar_chart_id => 'id' },
  },

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

  project_status => {
    class       => 'SL::DB::ProjectStatus',
    key_columns => { project_status_id => 'id' },
  },

  project_type => {
    class       => 'SL::DB::ProjectType',
    key_columns => { project_type_id => 'id' },
  },

  requirement_spec_section_order_part => {
    class       => 'SL::DB::Part',
    key_columns => { requirement_spec_section_order_part_id => 'id' },
  },

  stocktaking_bin => {
    class       => 'SL::DB::Bin',
    key_columns => { stocktaking_bin_id => 'id' },
  },

  stocktaking_warehouse => {
    class       => 'SL::DB::Warehouse',
    key_columns => { stocktaking_warehouse_id => 'id' },
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
