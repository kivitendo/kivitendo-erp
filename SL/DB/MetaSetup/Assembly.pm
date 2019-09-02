# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Assembly;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('assembly');

__PACKAGE__->meta->columns(
  assembly_id => { type => 'serial', not_null => 1 },
  bom         => { type => 'boolean' },
  id          => { type => 'integer', not_null => 1 },
  itime       => { type => 'timestamp', default => 'now()' },
  mtime       => { type => 'timestamp' },
  parts_id    => { type => 'integer', not_null => 1 },
  position    => { type => 'integer' },
  qty         => { type => 'float', precision => 4, scale => 4 },
);

__PACKAGE__->meta->primary_key_columns([ 'assembly_id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  assembly_part => {
    class       => 'SL::DB::Part',
    key_columns => { id => 'id' },
  },

  part => {
    class       => 'SL::DB::Part',
    key_columns => { parts_id => 'id' },
  },
);

1;
;
