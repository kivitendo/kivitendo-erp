# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::CsvImportReportRowStatus;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'csv_import_report_row_status',

  columns => [
    id                       => { type => 'serial', not_null => 1 },
    csv_import_report_row_id => { type => 'integer', not_null => 1 },
    type                     => { type => 'text', not_null => 1 },
    value                    => { type => 'text' },
  ],

  primary_key_columns => [ 'id' ],

  foreign_keys => [
    csv_import_report_row => {
      class       => 'SL::DB::CsvImportReportRow',
      key_columns => { csv_import_report_row_id => 'id' },
    },
  ],
);

1;
;
