# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Vendor;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'vendor',

  columns => [
    id             => { type => 'integer', not_null => 1, sequence => 'id' },
    name           => { type => 'varchar', length => 75, not_null => 1 },
    department_1   => { type => 'varchar', length => 75 },
    department_2   => { type => 'varchar', length => 75 },
    street         => { type => 'varchar', length => 75 },
    zipcode        => { type => 'varchar', length => 10 },
    city           => { type => 'varchar', length => 75 },
    country        => { type => 'varchar', length => 75 },
    contact        => { type => 'varchar', length => 75 },
    phone          => { type => 'text' },
    fax            => { type => 'varchar', length => 30 },
    homepage       => { type => 'text' },
    email          => { type => 'text' },
    notes          => { type => 'text' },
    terms          => { type => 'integer', default => '0' },
    taxincluded    => { type => 'boolean' },
    vendornumber   => { type => 'text' },
    cc             => { type => 'text' },
    bcc            => { type => 'text' },
    business_id    => { type => 'integer' },
    taxnumber      => { type => 'text' },
    discount       => { type => 'float', precision => 4 },
    creditlimit    => { type => 'numeric', precision => 5, scale => 15 },
    account_number => { type => 'varchar', length => 15 },
    bank_code      => { type => 'varchar', length => 10 },
    bank           => { type => 'text' },
    language       => { type => 'varchar', length => 5 },
    itime          => { type => 'timestamp', default => 'now()' },
    mtime          => { type => 'timestamp' },
    obsolete       => { type => 'boolean', default => 'false' },
    username       => { type => 'varchar', length => 50 },
    user_password  => { type => 'varchar', length => 12 },
    salesman_id    => { type => 'integer' },
    v_customer_id  => { type => 'text' },
    language_id    => { type => 'integer' },
    payment_id     => { type => 'integer' },
    taxzone_id     => { type => 'integer', default => '0', not_null => 1 },
    greeting       => { type => 'text' },
    ustid          => { type => 'varchar', length => 14 },
    iban           => { type => 'varchar', length => 100 },
    bic            => { type => 'varchar', length => 100 },
    direct_debit   => { type => 'boolean', default => 'false' },
    currency_id    => { type => 'integer', not_null => 1 },
  ],

  primary_key_columns => [ 'id' ],

  foreign_keys => [
    business => {
      class       => 'SL::DB::Business',
      key_columns => { business_id => 'id' },
    },

    language_obj => {
      class       => 'SL::DB::Language',
      key_columns => { language_id => 'id' },
    },

    payment => {
      class       => 'SL::DB::PaymentTerm',
      key_columns => { payment_id => 'id' },
    },
  ],
);

1;
;
