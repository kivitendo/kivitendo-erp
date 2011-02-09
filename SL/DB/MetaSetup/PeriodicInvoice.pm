# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::PeriodicInvoice;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'periodic_invoices',

  columns => [
    id                => { type => 'integer', not_null => 1, sequence => 'id' },
    config_id         => { type => 'integer', not_null => 1 },
    ar_id             => { type => 'integer', not_null => 1 },
    period_start_date => { type => 'date', not_null => 1 },
    itime             => { type => 'timestamp', default => 'now()' },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,

  foreign_keys => [
    ar => {
      class       => 'SL::DB::Invoice',
      key_columns => { ar_id => 'id' },
    },

    config => {
      class       => 'SL::DB::PeriodicInvoicesConfig',
      key_columns => { config_id => 'id' },
    },
  ],
);

1;
;
