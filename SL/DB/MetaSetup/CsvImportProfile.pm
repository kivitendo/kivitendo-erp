# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::CsvImportProfile;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('csv_import_profiles');

__PACKAGE__->meta->columns(
  id         => { type => 'serial', not_null => 1 },
  is_default => { type => 'boolean', default => 'false' },
  login      => { type => 'text' },
  name       => { type => 'text', not_null => 1 },
  type       => { type => 'varchar', length => 20, not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

1;
;
