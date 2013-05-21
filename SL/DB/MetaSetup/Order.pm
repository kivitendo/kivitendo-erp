# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Order;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'oe',

  columns => [
    id                      => { type => 'integer', not_null => 1, sequence => 'id' },
    ordnumber               => { type => 'text', not_null => 1 },
    transdate               => { type => 'date', default => 'now' },
    vendor_id               => { type => 'integer' },
    customer_id             => { type => 'integer' },
    amount                  => { type => 'numeric', precision => 5, scale => 15 },
    netamount               => { type => 'numeric', precision => 5, scale => 15 },
    reqdate                 => { type => 'date' },
    taxincluded             => { type => 'boolean' },
    shippingpoint           => { type => 'text' },
    notes                   => { type => 'text' },
    employee_id             => { type => 'integer' },
    closed                  => { type => 'boolean', default => 'false' },
    quotation               => { type => 'boolean', default => 'false' },
    quonumber               => { type => 'text' },
    cusordnumber            => { type => 'text' },
    intnotes                => { type => 'text' },
    department_id           => { type => 'integer' },
    itime                   => { type => 'timestamp', default => 'now()' },
    mtime                   => { type => 'timestamp' },
    shipvia                 => { type => 'text' },
    cp_id                   => { type => 'integer' },
    language_id             => { type => 'integer' },
    payment_id              => { type => 'integer' },
    delivery_customer_id    => { type => 'integer' },
    delivery_vendor_id      => { type => 'integer' },
    taxzone_id              => { type => 'integer' },
    proforma                => { type => 'boolean', default => 'false' },
    shipto_id               => { type => 'integer' },
    delivered               => { type => 'boolean', default => 'false' },
    globalproject_id        => { type => 'integer' },
    salesman_id             => { type => 'integer' },
    marge_total             => { type => 'numeric', precision => 5, scale => 15 },
    marge_percent           => { type => 'numeric', precision => 5, scale => 15 },
    transaction_description => { type => 'text' },
    currency_id             => { type => 'integer', not_null => 1 },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,

  foreign_keys => [
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

    vendor => {
      class       => 'SL::DB::Vendor',
      key_columns => { vendor_id => 'id' },
    },
  ],
);

1;
;
