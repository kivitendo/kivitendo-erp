# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::PartPartsgroup;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('part_partsgroup');

__PACKAGE__->meta->columns(
  parts_id      => { type => 'integer', not_null => 1 },
  partsgroup_id => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'parts_id', 'partsgroup_id' ]);

__PACKAGE__->meta->foreign_keys(
  parts => {
    class       => 'SL::DB::Part',
    key_columns => { parts_id => 'id' },
  },

  partsgroup => {
    class       => 'SL::DB::PartsGroup',
    key_columns => { partsgroup_id => 'id' },
  },
);

1;
;
