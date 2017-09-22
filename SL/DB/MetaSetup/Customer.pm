# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Customer;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('customer');

__PACKAGE__->meta->columns(
  account_number            => { type => 'text' },
  bank                      => { type => 'text' },
  bank_code                 => { type => 'text' },
  bcc                       => { type => 'text' },
  bic                       => { type => 'text' },
  business_id               => { type => 'integer' },
  c_vendor_id               => { type => 'text' },
  cc                        => { type => 'text' },
  city                      => { type => 'text' },
  contact                   => { type => 'text' },
  country                   => { type => 'text' },
  creditlimit               => { type => 'numeric', default => '0', precision => 15, scale => 5 },
  currency_id               => { type => 'integer', not_null => 1 },
  customernumber            => { type => 'text' },
  delivery_term_id          => { type => 'integer' },
  department_1              => { type => 'text' },
  department_2              => { type => 'text' },
  depositor                 => { type => 'text' },
  direct_debit              => { type => 'boolean', default => 'false' },
  discount                  => { type => 'float', scale => 4 },
  email                     => { type => 'text' },
  fax                       => { type => 'text' },
  gln                       => { type => 'text' },
  greeting                  => { type => 'text' },
  homepage                  => { type => 'text' },
  hourly_rate               => { type => 'numeric', precision => 8, scale => 2 },
  iban                      => { type => 'text' },
  id                        => { type => 'integer', not_null => 1, sequence => 'id' },
  itime                     => { type => 'timestamp', default => 'now()' },
  language                  => { type => 'text' },
  language_id               => { type => 'integer' },
  mandate_date_of_signature => { type => 'date' },
  mandator_id               => { type => 'text' },
  mtime                     => { type => 'timestamp' },
  name                      => { type => 'text', not_null => 1 },
  notes                     => { type => 'text' },
  obsolete                  => { type => 'boolean', default => 'false' },
  order_lock                => { type => 'boolean', default => 'false' },
  payment_id                => { type => 'integer' },
  phone                     => { type => 'text' },
  pricegroup_id             => { type => 'integer' },
  salesman_id               => { type => 'integer' },
  street                    => { type => 'text' },
  taxincluded               => { type => 'boolean' },
  taxincluded_checked       => { type => 'boolean' },
  taxnumber                 => { type => 'text' },
  taxzone_id                => { type => 'integer', not_null => 1 },
  user_password             => { type => 'text' },
  username                  => { type => 'text' },
  ustid                     => { type => 'text' },
  zipcode                   => { type => 'text' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  business => {
    class       => 'SL::DB::Business',
    key_columns => { business_id => 'id' },
  },

  currency => {
    class       => 'SL::DB::Currency',
    key_columns => { currency_id => 'id' },
  },

  delivery_term => {
    class       => 'SL::DB::DeliveryTerm',
    key_columns => { delivery_term_id => 'id' },
  },

  language_obj => {
    class       => 'SL::DB::Language',
    key_columns => { language_id => 'id' },
  },

  payment => {
    class       => 'SL::DB::PaymentTerm',
    key_columns => { payment_id => 'id' },
  },

  pricegroup => {
    class       => 'SL::DB::Pricegroup',
    key_columns => { pricegroup_id => 'id' },
  },

  taxzone => {
    class       => 'SL::DB::TaxZone',
    key_columns => { taxzone_id => 'id' },
  },
);

1;
;
