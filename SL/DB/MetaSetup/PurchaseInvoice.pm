# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::PurchaseInvoice;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'ap',

  columns => [
    id                      => { type => 'integer', not_null => 1, sequence => 'glid' },
    invnumber               => { type => 'text', not_null => 1 },
    transdate               => { type => 'date', default => 'now' },
    gldate                  => { type => 'date', default => 'now' },
    vendor_id               => { type => 'integer' },
    taxincluded             => { type => 'boolean', default => 'false' },
    amount                  => { type => 'numeric', precision => 5, scale => 15 },
    netamount               => { type => 'numeric', precision => 5, scale => 15 },
    paid                    => { type => 'numeric', precision => 5, scale => 15 },
    datepaid                => { type => 'date' },
    duedate                 => { type => 'date' },
    invoice                 => { type => 'boolean', default => 'false' },
    ordnumber               => { type => 'text' },
    notes                   => { type => 'text' },
    employee_id             => { type => 'integer' },
    quonumber               => { type => 'text' },
    intnotes                => { type => 'text' },
    department_id           => { type => 'integer' },
    itime                   => { type => 'timestamp', default => 'now()' },
    mtime                   => { type => 'timestamp' },
    shipvia                 => { type => 'text' },
    cp_id                   => { type => 'integer' },
    language_id             => { type => 'integer' },
    payment_id              => { type => 'integer' },
    storno                  => { type => 'boolean', default => 'false' },
    taxzone_id              => { type => 'integer' },
    type                    => { type => 'text' },
    orddate                 => { type => 'date' },
    quodate                 => { type => 'date' },
    globalproject_id        => { type => 'integer' },
    transaction_description => { type => 'text' },
    storno_id               => { type => 'integer' },
    direct_debit            => { type => 'boolean', default => 'false' },
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

    vendor => {
      class       => 'SL::DB::Vendor',
      key_columns => { vendor_id => 'id' },
    },
  ],
);

1;
;
