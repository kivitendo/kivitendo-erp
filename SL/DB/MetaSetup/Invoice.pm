# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Invoice;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('ar');

__PACKAGE__->meta->columns(
  amount                    => { type => 'numeric', precision => 5, scale => 15 },
  cp_id                     => { type => 'integer' },
  currency_id               => { type => 'integer', not_null => 1 },
  cusordnumber              => { type => 'text' },
  customer_id               => { type => 'integer' },
  datepaid                  => { type => 'date' },
  delivery_customer_id      => { type => 'integer' },
  delivery_vendor_id        => { type => 'integer' },
  deliverydate              => { type => 'date' },
  department_id             => { type => 'integer' },
  direct_debit              => { type => 'boolean', default => 'false' },
  donumber                  => { type => 'text' },
  duedate                   => { type => 'date' },
  dunning_config_id         => { type => 'integer' },
  employee_id               => { type => 'integer' },
  gldate                    => { type => 'date', default => 'now' },
  globalproject_id          => { type => 'integer' },
  id                        => { type => 'integer', not_null => 1, sequence => 'glid' },
  intnotes                  => { type => 'text' },
  invnumber                 => { type => 'text', not_null => 1 },
  invnumber_for_credit_note => { type => 'text' },
  invoice                   => { type => 'boolean', default => 'false' },
  itime                     => { type => 'timestamp', default => 'now()' },
  language_id               => { type => 'integer' },
  marge_percent             => { type => 'numeric', precision => 5, scale => 15 },
  marge_total               => { type => 'numeric', precision => 5, scale => 15 },
  mtime                     => { type => 'timestamp' },
  netamount                 => { type => 'numeric', precision => 5, scale => 15 },
  notes                     => { type => 'text' },
  orddate                   => { type => 'date' },
  ordnumber                 => { type => 'text' },
  paid                      => { type => 'numeric', precision => 5, scale => 15 },
  payment_id                => { type => 'integer' },
  quodate                   => { type => 'date' },
  quonumber                 => { type => 'text' },
  salesman_id               => { type => 'integer' },
  shippingpoint             => { type => 'text' },
  shipto_id                 => { type => 'integer' },
  shipvia                   => { type => 'text' },
  storno                    => { type => 'boolean', default => 'false' },
  storno_id                 => { type => 'integer' },
  taxincluded               => { type => 'boolean' },
  taxzone_id                => { type => 'integer' },
  terms                     => { type => 'integer', default => '0' },
  transaction_description   => { type => 'text' },
  transdate                 => { type => 'date', default => 'now' },
  type                      => { type => 'text' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  contact => {
    class       => 'SL::DB::Contact',
    key_columns => { cp_id => 'cp_id' },
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

  dunning_config => {
    class       => 'SL::DB::DunningConfig',
    key_columns => { dunning_config_id => 'id' },
  },

  employee => {
    class       => 'SL::DB::Employee',
    key_columns => { employee_id => 'id' },
  },

  globalproject => {
    class       => 'SL::DB::Project',
    key_columns => { globalproject_id => 'id' },
  },

  language => {
    class       => 'SL::DB::Language',
    key_columns => { language_id => 'id' },
  },

  payment_terms => {
    class       => 'SL::DB::PaymentTerm',
    key_columns => { payment_id => 'id' },
  },

  salesman => {
    class       => 'SL::DB::Employee',
    key_columns => { salesman_id => 'id' },
  },

  shipto => {
    class       => 'SL::DB::Shipto',
    key_columns => { shipto_id => 'shipto_id' },
  },

  storno_obj => {
    class       => 'SL::DB::Invoice',
    key_columns => { storno_id => 'id' },
  },
);

1;
;
