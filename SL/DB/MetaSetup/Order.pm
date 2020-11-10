# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Order;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('oe');

__PACKAGE__->meta->columns(
  amount                  => { type => 'numeric', precision => 15, scale => 5 },
  closed                  => { type => 'boolean', default => 'false' },
  cp_id                   => { type => 'integer' },
  currency_id             => { type => 'integer', not_null => 1 },
  cusordnumber            => { type => 'text' },
  customer_id             => { type => 'integer' },
  delivered               => { type => 'boolean', default => 'false' },
  delivery_customer_id    => { type => 'integer' },
  delivery_term_id        => { type => 'integer' },
  delivery_vendor_id      => { type => 'integer' },
  department_id           => { type => 'integer' },
  employee_id             => { type => 'integer' },
  exchangerate            => { type => 'numeric', precision => 15, scale => 5 },
  expected_billing_date   => { type => 'date' },
  globalproject_id        => { type => 'integer' },
  id                      => { type => 'integer', not_null => 1, sequence => 'id' },
  intnotes                => { type => 'text' },
  itime                   => { type => 'timestamp', default => 'now()' },
  language_id             => { type => 'integer' },
  marge_percent           => { type => 'numeric', precision => 15, scale => 5 },
  marge_total             => { type => 'numeric', precision => 15, scale => 5 },
  mtime                   => { type => 'timestamp' },
  netamount               => { type => 'numeric', precision => 15, scale => 5 },
  notes                   => { type => 'text' },
  order_probability       => { type => 'integer', default => '0', not_null => 1 },
  ordnumber               => { type => 'text', not_null => 1 },
  payment_id              => { type => 'integer' },
  proforma                => { type => 'boolean', default => 'false' },
  quonumber               => { type => 'text' },
  quotation               => { type => 'boolean', default => 'false' },
  reqdate                 => { type => 'date' },
  salesman_id             => { type => 'integer' },
  shippingpoint           => { type => 'text' },
  shipto_id               => { type => 'integer' },
  shipvia                 => { type => 'text' },
  tax_point               => { type => 'date' },
  taxincluded             => { type => 'boolean' },
  taxzone_id              => { type => 'integer', not_null => 1 },
  transaction_description => { type => 'text' },
  transdate               => { type => 'date', default => 'now' },
  vendor_id               => { type => 'integer' },
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

  delivery_customer => {
    class       => 'SL::DB::Customer',
    key_columns => { delivery_customer_id => 'id' },
  },

  delivery_term => {
    class       => 'SL::DB::DeliveryTerm',
    key_columns => { delivery_term_id => 'id' },
  },

  delivery_vendor => {
    class       => 'SL::DB::Vendor',
    key_columns => { delivery_vendor_id => 'id' },
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
