# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::CsvImportReportRow;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'csv_import_report_rows',

  columns => [
    id                   => { type => 'serial', not_null => 1 },
    csv_import_report_id => { type => 'integer', not_null => 1 },
    col                  => { type => 'integer', not_null => 1 },
    row                  => { type => 'integer', not_null => 1 },
    value                => { type => 'text' },
  ],

  primary_key_columns => [ 'id' ],

  foreign_keys => [
    csv_import_report => {
      class       => 'SL::DB::CsvImportReport',
      key_columns => { csv_import_report_id => 'id' },
    },
  ],
);

1;
;
