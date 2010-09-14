# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::UnitsLanguage;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'units_language',

  columns => [
    unit             => { type => 'varchar', length => 20, not_null => 1 },
    language_id      => { type => 'integer', not_null => 1 },
    localized        => { type => 'varchar', length => 20 },
    localized_plural => { type => 'varchar', length => 20 },
    id               => { type => 'serial', not_null => 1 },
  ],

  primary_key_columns => [ 'id' ],

  foreign_keys => [
    language => {
      class       => 'SL::DB::Language',
      key_columns => { language_id => 'id' },
    },

    unit_obj => {
      class       => 'SL::DB::Unit',
      key_columns => { unit => 'name' },
    },
  ],
);

1;
;
