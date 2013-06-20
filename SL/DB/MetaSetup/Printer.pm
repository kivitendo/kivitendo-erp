# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Printer;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('printers');

__PACKAGE__->meta->columns(
  id                  => { type => 'integer', not_null => 1, sequence => 'id' },
  printer_description => { type => 'text', not_null => 1 },
  printer_command     => { type => 'text' },
  template_code       => { type => 'text' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->relationships(
  periodic_invoices_configs => {
    class      => 'SL::DB::PeriodicInvoicesConfig',
    column_map => { id => 'printer_id' },
    type       => 'one to many',
  },
);

# __PACKAGE__->meta->initialize;

1;
;
