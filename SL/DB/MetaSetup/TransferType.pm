# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::TransferType;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('transfer_type');

__PACKAGE__->meta->columns(
  description => { type => 'text' },
  direction   => { type => 'varchar', length => 10, not_null => 1 },
  id          => { type => 'integer', not_null => 1, sequence => 'id' },
  itime       => { type => 'timestamp', default => 'now()' },
  mtime       => { type => 'timestamp' },
  sortkey     => { type => 'integer' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

1;
;
