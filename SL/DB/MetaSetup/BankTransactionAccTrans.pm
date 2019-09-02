# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::BankTransactionAccTrans;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('bank_transaction_acc_trans');

__PACKAGE__->meta->columns(
  acc_trans_id        => { type => 'bigint', not_null => 1 },
  ap_id               => { type => 'integer' },
  ar_id               => { type => 'integer' },
  bank_transaction_id => { type => 'integer', not_null => 1 },
  gl_id               => { type => 'integer' },
  itime               => { type => 'timestamp', default => 'now()' },
  mtime               => { type => 'timestamp' },
);

__PACKAGE__->meta->primary_key_columns([ 'bank_transaction_id', 'acc_trans_id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  acc_transaction => {
    class       => 'SL::DB::AccTransaction',
    key_columns => { acc_trans_id => 'acc_trans_id' },
  },

  ap => {
    class       => 'SL::DB::PurchaseInvoice',
    key_columns => { ap_id => 'id' },
  },

  ar => {
    class       => 'SL::DB::Invoice',
    key_columns => { ar_id => 'id' },
  },

  bank_transaction => {
    class       => 'SL::DB::BankTransaction',
    key_columns => { bank_transaction_id => 'id' },
  },

  gl => {
    class       => 'SL::DB::GLTransaction',
    key_columns => { gl_id => 'id' },
  },
);

1;
;
