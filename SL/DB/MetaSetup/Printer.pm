# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Printer;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'printers',

  columns => [
    id                  => { type => 'integer', not_null => 1, sequence => 'id' },
    printer_description => { type => 'text', not_null => 1 },
    printer_command     => { type => 'text' },
    template_code       => { type => 'text' },
  ],

  primary_key_columns => [ 'id' ],
);

1;
;
