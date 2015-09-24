# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::TaxzoneChart;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('taxzone_charts');

__PACKAGE__->meta->columns(
  buchungsgruppen_id => { type => 'integer', not_null => 1 },
  expense_accno_id   => { type => 'integer', not_null => 1 },
  id                 => { type => 'serial', not_null => 1 },
  income_accno_id    => { type => 'integer', not_null => 1 },
  itime              => { type => 'timestamp', default => 'now()' },
  taxzone_id         => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  buchungsgruppen => {
    class       => 'SL::DB::Buchungsgruppe',
    key_columns => { buchungsgruppen_id => 'id' },
  },

  expense_accno => {
    class       => 'SL::DB::Chart',
    key_columns => { expense_accno_id => 'id' },
  },

  income_accno => {
    class       => 'SL::DB::Chart',
    key_columns => { income_accno_id => 'id' },
  },

  taxzone => {
    class       => 'SL::DB::TaxZone',
    key_columns => { taxzone_id => 'id' },
  },
);

1;
;
