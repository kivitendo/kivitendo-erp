# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::BankAccount;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('bank_accounts');

__PACKAGE__->meta->columns(
  account_number => { type => 'varchar', length => 100 },
  bank           => { type => 'text' },
  bank_code      => { type => 'varchar', length => 100 },
  bic            => { type => 'varchar', length => 100 },
  chart_id       => { type => 'integer', not_null => 1 },
  iban           => { type => 'varchar', length => 100 },
  id             => { type => 'integer', not_null => 1, sequence => 'id' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->foreign_keys(
  chart => {
    class       => 'SL::DB::Chart',
    key_columns => { chart_id => 'id' },
  },
);

1;
;
