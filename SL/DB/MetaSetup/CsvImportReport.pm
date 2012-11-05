# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::CsvImportReport;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'csv_import_reports',

  columns => [
    id         => { type => 'serial', not_null => 1 },
    session_id => { type => 'text', not_null => 1 },
    profile_id => { type => 'integer', not_null => 1 },
    type       => { type => 'text', not_null => 1 },
    file       => { type => 'text', not_null => 1 },
  ],

  primary_key_columns => [ 'id' ],

  foreign_keys => [
    profile => {
      class       => 'SL::DB::CsvImportProfile',
      key_columns => { profile_id => 'id' },
    },
  ],
);

1;
;
