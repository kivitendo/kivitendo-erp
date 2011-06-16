# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::CsvImportProfile;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'csv_import_profiles',

  columns => [
    id         => { type => 'serial', not_null => 1 },
    name       => { type => 'text', not_null => 1 },
    type       => { type => 'varchar', length => 20, not_null => 1 },
    is_default => { type => 'boolean', default => 'false' },
  ],

  primary_key_columns => [ 'id' ],

  unique_key => [ 'name' ],
);

1;
;
