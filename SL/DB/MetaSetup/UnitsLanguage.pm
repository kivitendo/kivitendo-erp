# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::UnitsLanguage;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('units_language');

__PACKAGE__->meta->columns(
  id               => { type => 'serial', not_null => 1 },
  language_id      => { type => 'integer', not_null => 1 },
  localized        => { type => 'varchar', length => 20 },
  localized_plural => { type => 'varchar', length => 20 },
  unit             => { type => 'varchar', length => 20, not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->foreign_keys(
  language => {
    class       => 'SL::DB::Language',
    key_columns => { language_id => 'id' },
  },

  unit_obj => {
    class       => 'SL::DB::Unit',
    key_columns => { unit => 'name' },
  },
);

1;
;
