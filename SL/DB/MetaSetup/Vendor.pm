# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Vendor;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('vendor');

__PACKAGE__->meta->columns(
  account_number => { type => 'varchar', length => 15 },
  bank           => { type => 'text' },
  bank_code      => { type => 'varchar', length => 10 },
  bcc            => { type => 'text' },
  bic            => { type => 'varchar', length => 100 },
  business_id    => { type => 'integer' },
  cc             => { type => 'text' },
  city           => { type => 'varchar', length => 75 },
  contact        => { type => 'varchar', length => 75 },
  country        => { type => 'varchar', length => 75 },
  creditlimit    => { type => 'numeric', precision => 5, scale => 15 },
  currency_id    => { type => 'integer', not_null => 1 },
  department_1   => { type => 'varchar', length => 75 },
  department_2   => { type => 'varchar', length => 75 },
  direct_debit   => { type => 'boolean', default => 'false' },
  discount       => { type => 'float', precision => 4 },
  email          => { type => 'text' },
  fax            => { type => 'varchar', length => 30 },
  greeting       => { type => 'text' },
  homepage       => { type => 'text' },
  iban           => { type => 'varchar', length => 100 },
  id             => { type => 'integer', not_null => 1, sequence => 'id' },
  itime          => { type => 'timestamp', default => 'now()' },
  language       => { type => 'varchar', length => 5 },
  language_id    => { type => 'integer' },
  mtime          => { type => 'timestamp' },
  name           => { type => 'varchar', length => 75, not_null => 1 },
  notes          => { type => 'text' },
  obsolete       => { type => 'boolean', default => 'false' },
  payment_id     => { type => 'integer' },
  phone          => { type => 'text' },
  salesman_id    => { type => 'integer' },
  street         => { type => 'varchar', length => 75 },
  taxincluded    => { type => 'boolean' },
  taxnumber      => { type => 'text' },
  taxzone_id     => { type => 'integer', default => '0', not_null => 1 },
  terms          => { type => 'integer', default => '0' },
  user_password  => { type => 'varchar', length => 12 },
  username       => { type => 'varchar', length => 50 },
  ustid          => { type => 'varchar', length => 14 },
  v_customer_id  => { type => 'text' },
  vendornumber   => { type => 'text' },
  zipcode        => { type => 'varchar', length => 10 },
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

  language_obj => {
    class       => 'SL::DB::Language',
    key_columns => { language_id => 'id' },
  },

  payment => {
    class       => 'SL::DB::PaymentTerm',
    key_columns => { payment_id => 'id' },
  },
);

1;
;
