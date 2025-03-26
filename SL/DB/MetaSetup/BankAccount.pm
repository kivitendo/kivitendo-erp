# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::BankAccount;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('bank_accounts');

__PACKAGE__->meta->columns(
  account_number                  => { type => 'varchar', length => 100 },
  bank                            => { type => 'text' },
  bank_account_id                 => { type => 'varchar' },
  bank_code                       => { type => 'varchar', length => 100 },
  bic                             => { type => 'varchar', length => 100 },
  chart_id                        => { type => 'integer', not_null => 1 },
  iban                            => { type => 'varchar', length => 100 },
  id                              => { type => 'integer', not_null => 1, sequence => 'id' },
  name                            => { type => 'text' },
  obsolete                        => { type => 'boolean', default => 'false', not_null => 1 },
  qr_iban                         => { type => 'text' },
  reconciliation_starting_balance => { type => 'numeric', precision => 15, scale => 5 },
  reconciliation_starting_date    => { type => 'date' },
  sortkey                         => { type => 'integer', not_null => 1 },
  use_for_qrbill                  => { type => 'boolean', default => 'false', not_null => 1 },
  use_for_zugferd                 => { type => 'boolean', default => 'false', not_null => 1 },
  use_with_bank_import            => { type => 'boolean', default => 'true', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->unique_keys([ 'chart_id' ]);

__PACKAGE__->meta->foreign_keys(
  chart => {
    class       => 'SL::DB::Chart',
    key_columns => { chart_id => 'id' },
    rel_type    => 'one to one',
  },
);

1;
;
