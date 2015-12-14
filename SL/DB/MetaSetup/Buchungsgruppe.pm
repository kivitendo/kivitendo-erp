# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Buchungsgruppe;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('buchungsgruppen');

__PACKAGE__->meta->columns(
  description        => { type => 'text' },
  id                 => { type => 'integer', not_null => 1, sequence => 'id' },
  inventory_accno_id => { type => 'integer', not_null => 1 },
  sortkey            => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->foreign_keys(
  inventory_accno => {
    class       => 'SL::DB::Chart',
    key_columns => { inventory_accno_id => 'id' },
  },
);

1;
;
