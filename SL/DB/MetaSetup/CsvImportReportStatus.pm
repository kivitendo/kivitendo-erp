# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::CsvImportReportStatus;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('csv_import_report_status');

__PACKAGE__->meta->columns(
  csv_import_report_id => { type => 'integer', not_null => 1 },
  id                   => { type => 'serial', not_null => 1 },
  row                  => { type => 'integer', not_null => 1 },
  type                 => { type => 'text', not_null => 1 },
  value                => { type => 'text' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->foreign_keys(
  csv_import_report => {
    class       => 'SL::DB::CsvImportReport',
    key_columns => { csv_import_report_id => 'id' },
  },
);

1;
;
