# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Printer;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('printers');

__PACKAGE__->meta->columns(
  id                  => { type => 'integer', not_null => 1, sequence => 'id' },
  printer_command     => { type => 'text' },
  printer_description => { type => 'text', not_null => 1 },
  template_code       => { type => 'text' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

1;
;
