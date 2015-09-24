# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::PeriodicInvoice;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('periodic_invoices');

__PACKAGE__->meta->columns(
  ar_id             => { type => 'integer', not_null => 1 },
  config_id         => { type => 'integer', not_null => 1 },
  id                => { type => 'integer', not_null => 1, sequence => 'id' },
  itime             => { type => 'timestamp', default => 'now()' },
  period_start_date => { type => 'date', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  ar => {
    class       => 'SL::DB::Invoice',
    key_columns => { ar_id => 'id' },
  },

  config => {
    class       => 'SL::DB::PeriodicInvoicesConfig',
    key_columns => { config_id => 'id' },
  },
);

1;
;
