# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::RecordTemplate;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('record_templates');

__PACKAGE__->meta->columns(
  ar_ap_chart_id => { type => 'integer' },
  cb_transaction => { type => 'boolean', default => 'false', not_null => 1 },
  currency_id    => { type => 'integer', not_null => 1 },
  customer_id    => { type => 'integer' },
  department_id  => { type => 'integer' },
  description    => { type => 'text' },
  direct_debit   => { type => 'boolean', default => 'false', not_null => 1 },
  employee_id    => { type => 'integer' },
  id             => { type => 'serial', not_null => 1 },
  itime          => { type => 'timestamp', default => 'now()', not_null => 1 },
  mtime          => { type => 'timestamp', default => 'now()', not_null => 1 },
  notes          => { type => 'text' },
  ob_transaction => { type => 'boolean', default => 'false', not_null => 1 },
  ordnumber      => { type => 'text' },
  project_id     => { type => 'integer' },
  reference      => { type => 'text' },
  show_details   => { type => 'boolean', default => 'false', not_null => 1 },
  taxincluded    => { type => 'boolean', default => 'false', not_null => 1 },
  template_name  => { type => 'text', not_null => 1 },
  template_type  => { type => 'enum', check_in => [ 'ar_transaction', 'ap_transaction', 'gl_transaction' ], db_type => 'record_template_type', not_null => 1 },
  vendor_id      => { type => 'integer' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  ar_ap_chart => {
    class       => 'SL::DB::Chart',
    key_columns => { ar_ap_chart_id => 'id' },
  },

  currency => {
    class       => 'SL::DB::Currency',
    key_columns => { currency_id => 'id' },
  },

  customer => {
    class       => 'SL::DB::Customer',
    key_columns => { customer_id => 'id' },
  },

  department => {
    class       => 'SL::DB::Department',
    key_columns => { department_id => 'id' },
  },

  employee => {
    class       => 'SL::DB::Employee',
    key_columns => { employee_id => 'id' },
  },

  project => {
    class       => 'SL::DB::Project',
    key_columns => { project_id => 'id' },
  },

  vendor => {
    class       => 'SL::DB::Vendor',
    key_columns => { vendor_id => 'id' },
  },
);

1;
;
