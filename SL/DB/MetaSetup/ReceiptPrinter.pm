# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::ReceiptPrinter;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('receipt_printers');

__PACKAGE__->meta->columns(
  id         => { type => 'serial', not_null => 1 },
  ip_address => { type => 'text', not_null => 1 },
  name       => { type => 'text', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

1;
;
