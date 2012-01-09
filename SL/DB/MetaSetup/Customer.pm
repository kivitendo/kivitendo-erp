# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Customer;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'customer',

  columns => [
    id             => { type => 'integer', not_null => 1, sequence => 'id' },
    name           => { type => 'text', not_null => 1 },
    department_1   => { type => 'varchar', length => 75 },
    department_2   => { type => 'varchar', length => 75 },
    street         => { type => 'varchar', length => 75 },
    zipcode        => { type => 'varchar', length => 10 },
    city           => { type => 'varchar', length => 75 },
    country        => { type => 'varchar', length => 75 },
    contact        => { type => 'text' },
    phone          => { type => 'varchar', length => 30 },
    fax            => { type => 'varchar', length => 30 },
    homepage       => { type => 'text' },
    email          => { type => 'text' },
    notes          => { type => 'text' },
    discount       => { type => 'float', precision => 4 },
    taxincluded    => { type => 'boolean' },
    creditlimit    => { type => 'numeric', default => '0', precision => 5, scale => 15 },
    terms          => { type => 'integer', default => '0' },
    customernumber => { type => 'text' },
    cc             => { type => 'text' },
    bcc            => { type => 'text' },
    business_id    => { type => 'integer' },
    taxnumber      => { type => 'text' },
    account_number => { type => 'text' },
    bank_code      => { type => 'text' },
    bank           => { type => 'text' },
    language       => { type => 'varchar', length => 5 },
    datevexport    => { type => 'integer' },
    itime          => { type => 'timestamp', default => 'now()' },
    mtime          => { type => 'timestamp' },
    obsolete       => { type => 'boolean', default => 'false' },
    username       => { type => 'varchar', length => 50 },
    user_password  => { type => 'text' },
    salesman_id    => { type => 'integer' },
    c_vendor_id    => { type => 'text' },
    klass          => { type => 'integer', default => '0' },
    language_id    => { type => 'integer' },
    payment_id     => { type => 'integer' },
    taxzone_id     => { type => 'integer', default => '0', not_null => 1 },
    greeting       => { type => 'text' },
    ustid          => { type => 'text' },
    direct_debit   => { type => 'boolean', default => 'false' },
    iban           => { type => 'varchar', length => 100 },
    bic            => { type => 'varchar', length => 100 },
    curr           => { type => 'character', length => 3 },
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
