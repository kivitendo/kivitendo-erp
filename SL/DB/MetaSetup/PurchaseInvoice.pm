# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::PurchaseInvoice;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('ap');

__PACKAGE__->meta->columns(
  amount                  => { type => 'numeric', default => '0', not_null => 1, precision => 15, scale => 5 },
  cp_id                   => { type => 'integer' },
  currency_id             => { type => 'integer', not_null => 1 },
  datepaid                => { type => 'date' },
  delivery_term_id        => { type => 'integer' },
  deliverydate            => { type => 'date' },
  department_id           => { type => 'integer' },
  direct_debit            => { type => 'boolean', default => 'false' },
  duedate                 => { type => 'date' },
  employee_id             => { type => 'integer' },
  gldate                  => { type => 'date', default => 'now' },
  globalproject_id        => { type => 'integer' },
  id                      => { type => 'integer', not_null => 1, sequence => 'glid' },
  intnotes                => { type => 'text' },
  invnumber               => { type => 'text', not_null => 1 },
  invoice                 => { type => 'boolean', default => 'false' },
  itime                   => { type => 'timestamp', default => 'now()' },
  language_id             => { type => 'integer' },
  mtime                   => { type => 'timestamp' },
  netamount               => { type => 'numeric', default => '0', not_null => 1, precision => 15, scale => 5 },
  notes                   => { type => 'text' },
  orddate                 => { type => 'date' },
  ordnumber               => { type => 'text' },
  paid                    => { type => 'numeric', default => '0', not_null => 1, precision => 15, scale => 5 },
  payment_id              => { type => 'integer' },
  quodate                 => { type => 'date' },
  quonumber               => { type => 'text' },
  shipvia                 => { type => 'text' },
  storno                  => { type => 'boolean', default => 'false' },
  storno_id               => { type => 'integer' },
  tax_point               => { type => 'date' },
  taxincluded             => { type => 'boolean', default => 'false' },
  taxzone_id              => { type => 'integer', not_null => 1 },
  transaction_description => { type => 'text' },
  transdate               => { type => 'date', default => 'now' },
  type                    => { type => 'text' },
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

  payment_terms => {
    class       => 'SL::DB::PaymentTerm',
    key_columns => { payment_id => 'id' },
  },

  storno_obj => {
    class       => 'SL::DB::PurchaseInvoice',
    key_columns => { storno_id => 'id' },
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
