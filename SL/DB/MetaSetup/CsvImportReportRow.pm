# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::CsvImportReportRow;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('csv_import_report_rows');

__PACKAGE__->meta->columns(
  id                   => { type => 'serial', not_null => 1 },
  csv_import_report_id => { type => 'integer', not_null => 1 },
  col                  => { type => 'integer', not_null => 1 },
  row                  => { type => 'integer', not_null => 1 },
  value                => { type => 'text' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->foreign_keys(
  csv_import_report => {
    class       => 'SL::DB::CsvImportReport',
    key_columns => { csv_import_report_id => 'id' },
  },
);

# __PACKAGE__->meta->initialize;

1;
;
