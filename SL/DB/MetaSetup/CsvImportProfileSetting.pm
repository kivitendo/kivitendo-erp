# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::CsvImportProfileSetting;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'csv_import_profile_settings',

  columns => [
    id                    => { type => 'serial', not_null => 1 },
    csv_import_profile_id => { type => 'integer', not_null => 1 },
    key                   => { type => 'text', not_null => 1 },
    value                 => { type => 'text' },
  ],

  primary_key_columns => [ 'id' ],

  unique_key => [ 'csv_import_profile_id', 'key' ],

  foreign_keys => [
    csv_import_profile => {
      class       => 'SL::DB::CsvImportProfile',
      key_columns => { csv_import_profile_id => 'id' },
    },
  ],
);

1;
;
