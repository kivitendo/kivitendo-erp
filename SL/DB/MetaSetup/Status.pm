# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Status;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('status');

__PACKAGE__->meta->columns(
  chart_id  => { type => 'integer' },
  emailed   => { type => 'boolean', default => 'false' },
  formname  => { type => 'text' },
  id        => { type => 'serial', not_null => 1 },
  itime     => { type => 'timestamp', default => 'now()' },
  mtime     => { type => 'timestamp' },
  printed   => { type => 'boolean', default => 'false' },
  spoolfile => { type => 'text' },
  trans_id  => { type => 'integer' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

1;
;
