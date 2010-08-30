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
    phone          => { type => 'varchar', length => 30 },
    fax            => { type => 'varchar', length => 30 },
    homepage       => { type => 'text' },
    email          => { type => 'text' },
    notes          => { type => 'text' },
    terms          => { type => 'integer', default => '0' },
    taxincluded    => { type => 'boolean' },
    vendornumber   => { type => 'text' },
    cc             => { type => 'text' },
    bcc            => { type => 'text' },
    gifi_accno     => { type => 'text' },
    business_id    => { type => 'integer' },
    taxnumber      => { type => 'text' },
    discount       => { type => 'float', precision => 4 },
    creditlimit    => { type => 'numeric', precision => 5, scale => 15 },
    account_number => { type => 'varchar', length => 15 },
    bank_code      => { type => 'varchar', length => 10 },
    bank           => { type => 'text' },
    language       => { type => 'varchar', length => 5 },
    datevexport    => { type => 'integer' },
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
    direct_debit   => { type => 'boolean', default => 'false' },
    iban           => { type => 'varchar', length => 100 },
    bic            => { type => 'varchar', length => 100 },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,
);

1;
;
