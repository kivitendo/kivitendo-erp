# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::AssemblyInventoryPart;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('assembly_inventory_part');

__PACKAGE__->meta->columns(
  inventory_assembly_id => { type => 'integer', not_null => 1 },
  inventory_part_id     => { type => 'integer', not_null => 1 },
  itime                 => { type => 'timestamp', default => 'now()' },
  mtime                 => { type => 'timestamp' },
);

__PACKAGE__->meta->primary_key_columns([ 'inventory_assembly_id', 'inventory_part_id' ]);

__PACKAGE__->meta->unique_keys([ 'inventory_part_id', 'inventory_assembly_id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  inventory_assembly => {
    class       => 'SL::DB::Inventory',
    key_columns => { inventory_assembly_id => 'id' },
  },

  inventory_part => {
    class       => 'SL::DB::Inventory',
    key_columns => { inventory_part_id => 'id' },
  },
);

1;
;
