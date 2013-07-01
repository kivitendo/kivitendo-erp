# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Buchungsgruppe;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('buchungsgruppen');

__PACKAGE__->meta->columns(
  description        => { type => 'text' },
  expense_accno_id_0 => { type => 'integer' },
  expense_accno_id_1 => { type => 'integer' },
  expense_accno_id_2 => { type => 'integer' },
  expense_accno_id_3 => { type => 'integer' },
  id                 => { type => 'integer', not_null => 1, sequence => 'id' },
  income_accno_id_0  => { type => 'integer' },
  income_accno_id_1  => { type => 'integer' },
  income_accno_id_2  => { type => 'integer' },
  income_accno_id_3  => { type => 'integer' },
  inventory_accno_id => { type => 'integer' },
  sortkey            => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

1;
;
