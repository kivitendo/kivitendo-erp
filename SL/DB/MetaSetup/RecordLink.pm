# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::RecordLink;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('record_links');

__PACKAGE__->meta->columns(
  from_id    => { type => 'integer', not_null => 1 },
  from_table => { type => 'varchar', length => 50, not_null => 1 },
  id         => { type => 'serial', not_null => 1 },
  itime      => { type => 'timestamp', default => 'now()' },
  to_id      => { type => 'integer', not_null => 1 },
  to_table   => { type => 'varchar', length => 50, not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

1;
;
