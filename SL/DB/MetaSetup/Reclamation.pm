# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Reclamation;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('reclamations');

__PACKAGE__->meta->columns(
  amount                  => { type => 'numeric', precision => 15, scale => 5 },
  billing_address_id      => { type => 'integer' },
  closed                  => { type => 'boolean', default => 'false', not_null => 1 },
  contact_id              => { type => 'integer' },
  currency_id             => { type => 'integer', not_null => 1 },
  customer_id             => { type => 'integer' },
  cv_record_number        => { type => 'text' },
  delivered               => { type => 'boolean', default => 'false', not_null => 1 },
  delivery_term_id        => { type => 'integer' },
  department_id           => { type => 'integer' },
  employee_id             => { type => 'integer', not_null => 1 },
  exchangerate            => { type => 'numeric', precision => 15, scale => 5 },
  globalproject_id        => { type => 'integer' },
  id                      => { type => 'integer', not_null => 1, sequence => 'id' },
  intnotes                => { type => 'text' },
  itime                   => { type => 'timestamp', default => 'now()' },
  language_id             => { type => 'integer' },
  mtime                   => { type => 'timestamp' },
  netamount               => { type => 'numeric', precision => 15, scale => 5 },
  notes                   => { type => 'text' },
  payment_id              => { type => 'integer' },
  record_number           => { type => 'text', not_null => 1 },
  reqdate                 => { type => 'date' },
  salesman_id             => { type => 'integer' },
  shippingpoint           => { type => 'text' },
  shipto_id               => { type => 'integer' },
  shipvia                 => { type => 'text' },
  tax_point               => { type => 'date' },
  taxincluded             => { type => 'boolean', not_null => 1 },
  taxzone_id              => { type => 'integer', not_null => 1 },
  transaction_description => { type => 'text' },
  transdate               => { type => 'date', default => 'now()' },
  vendor_id               => { type => 'integer' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  billing_address => {
    class       => 'SL::DB::AdditionalBillingAddress',
    key_columns => { billing_address_id => 'id' },
  },

  contact => {
    class       => 'SL::DB::Contact',
    key_columns => { contact_id => 'cp_id' },
  },

  currency => {
    class       => 'SL::DB::Currency',
    key_columns => { currency_id => 'id' },
  },

  customer => {
    class       => 'SL::DB::Customer',
    key_columns => { customer_id => 'id' },
  },

  delivery_term => {
    class       => 'SL::DB::DeliveryTerm',
    key_columns => { delivery_term_id => 'id' },
  },

  department => {
    class       => 'SL::DB::Department',
    key_columns => { department_id => 'id' },
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

  payment => {
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

  taxzone => {
    class       => 'SL::DB::TaxZone',
    key_columns => { taxzone_id => 'id' },
  },

  vendor => {
    class       => 'SL::DB::Vendor',
    key_columns => { vendor_id => 'id' },
  },
);

1;
;
