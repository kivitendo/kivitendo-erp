# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::CsvImportProfileSetting;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('csv_import_profile_settings');

__PACKAGE__->meta->columns(
  csv_import_profile_id => { type => 'integer', not_null => 1 },
  id                    => { type => 'serial', not_null => 1 },
  key                   => { type => 'text', not_null => 1 },
  value                 => { type => 'text' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->unique_keys([ 'csv_import_profile_id', 'key' ]);

__PACKAGE__->meta->foreign_keys(
  csv_import_profile => {
    class       => 'SL::DB::CsvImportProfile',
    key_columns => { csv_import_profile_id => 'id' },
  },
);

1;
;
