# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::PeriodicInvoicesConfig;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'periodic_invoices_configs',

  columns => [
    id          => { type => 'integer', not_null => 1, sequence => 'id' },
    oe_id       => { type => 'integer', not_null => 1 },
    periodicity => { type => 'varchar', length => 10, not_null => 1 },
    print       => { type => 'boolean', default => 'false' },
    printer_id  => { type => 'integer' },
    copies      => { type => 'integer' },
    active      => { type => 'boolean', default => 'true' },
    start_date  => { type => 'date' },
    ar_chart_id => { type => 'integer', not_null => 1 },
  ],

  primary_key_columns => [ 'id' ],

  foreign_keys => [
    ar_chart => {
      class       => 'SL::DB::Chart',
      key_columns => { ar_chart_id => 'id' },
    },

    oe => {
      class       => 'SL::DB::Order',
      key_columns => { oe_id => 'id' },
    },

    printer => {
      class       => 'SL::DB::Printer',
      key_columns => { printer_id => 'id' },
    },
  ],
);

1;
;
