# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Assembly;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('assembly');

__PACKAGE__->meta->columns(
  assembly_id => { type => 'serial', not_null => 1 },
  bom         => { type => 'boolean' },
  id          => { type => 'integer' },
  itime       => { type => 'timestamp', default => 'now()' },
  mtime       => { type => 'timestamp' },
  parts_id    => { type => 'integer' },
  qty         => { type => 'float', precision => 4 },
);

__PACKAGE__->meta->primary_key_columns([ 'assembly_id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

1;
;
