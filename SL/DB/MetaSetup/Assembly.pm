# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Assembly;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'assembly',

  columns => [
    id          => { type => 'integer' },
    parts_id    => { type => 'integer' },
    qty         => { type => 'float', precision => 4 },
    bom         => { type => 'boolean' },
    itime       => { type => 'timestamp', default => 'now()' },
    mtime       => { type => 'timestamp' },
    variable    => { type => 'boolean', default => 'false', not_null => 1, remarks => 'true if this part of the assembly is variable, and can be modified' },
    item_id     => { type => 'integer', remarks => 'used to group parts in an assembly for exclusive options' },
    assembly_id => { type => 'serial', not_null => 1 },
  ],

  primary_key_columns => [ 'assembly_id' ],

  allow_inline_column_values => 1,
);

1;
;
