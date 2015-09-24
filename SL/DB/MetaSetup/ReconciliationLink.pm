# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::ReconciliationLink;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('reconciliation_links');

__PACKAGE__->meta->columns(
  acc_trans_id        => { type => 'bigint', not_null => 1 },
  bank_transaction_id => { type => 'integer', not_null => 1 },
  id                  => { type => 'integer', not_null => 1, sequence => 'id' },
  rec_group           => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->foreign_keys(
  acc_trans => {
    class       => 'SL::DB::AccTransaction',
    key_columns => { acc_trans_id => 'acc_trans_id' },
  },

  bank_transaction => {
    class       => 'SL::DB::BankTransaction',
    key_columns => { bank_transaction_id => 'id' },
  },
);

1;
;
