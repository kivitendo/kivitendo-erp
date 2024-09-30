# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::BankTransaction;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('bank_transactions');

__PACKAGE__->meta->columns(
  amount                => { type => 'numeric', not_null => 1, precision => 15, scale => 5 },
  cleared               => { type => 'boolean', default => 'false', not_null => 1 },
  currency_id           => { type => 'integer', not_null => 1 },
  end_to_end_id         => { type => 'text' },
  exchangerate          => { type => 'numeric', precision => 15, scale => 5 },
  id                    => { type => 'serial', not_null => 1 },
  invoice_amount        => { type => 'numeric', default => '0', precision => 15, scale => 5 },
  itime                 => { type => 'timestamp', default => 'now()' },
  local_bank_account_id => { type => 'integer', not_null => 1 },
  purpose               => { type => 'text' },
  qr_reference          => { type => 'text' },
  remote_account_number => { type => 'text' },
  remote_bank_code      => { type => 'text' },
  remote_name           => { type => 'text' },
  transaction_code      => { type => 'text' },
  transaction_id        => { type => 'integer' },
  transaction_text      => { type => 'text' },
  transdate             => { type => 'date', not_null => 1 },
  valutadate            => { type => 'date', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  currency => {
    class       => 'SL::DB::Currency',
    key_columns => { currency_id => 'id' },
  },

  local_bank_account => {
    class       => 'SL::DB::BankAccount',
    key_columns => { local_bank_account_id => 'id' },
  },
);

1;
;
