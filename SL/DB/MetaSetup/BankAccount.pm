# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::BankAccount;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'bank_accounts',

  columns => [
    id             => { type => 'integer', not_null => 1, sequence => 'id' },
    account_number => { type => 'varchar', length => 100 },
    bank_code      => { type => 'varchar', length => 100 },
    iban           => { type => 'varchar', length => 100 },
    bic            => { type => 'varchar', length => 100 },
    bank           => { type => 'text' },
    chart_id       => { type => 'integer', not_null => 1 },
  ],

  primary_key_columns => [ 'id' ],

  foreign_keys => [
    chart => {
      class       => 'SL::DB::Chart',
      key_columns => { chart_id => 'id' },
    },
  ],
);

1;
;
