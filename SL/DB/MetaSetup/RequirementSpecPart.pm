# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::RequirementSpecPart;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('requirement_spec_parts');

__PACKAGE__->meta->columns(
  description         => { type => 'text', not_null => 1 },
  id                  => { type => 'serial', not_null => 1 },
  part_id             => { type => 'integer', not_null => 1 },
  position            => { type => 'integer', not_null => 1 },
  qty                 => { type => 'numeric', not_null => 1, precision => 15, scale => 5 },
  requirement_spec_id => { type => 'integer', not_null => 1 },
  unit_id             => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->foreign_keys(
  part => {
    class       => 'SL::DB::Part',
    key_columns => { part_id => 'id' },
  },

  requirement_spec => {
    class       => 'SL::DB::RequirementSpec',
    key_columns => { requirement_spec_id => 'id' },
  },

  unit => {
    class       => 'SL::DB::Unit',
    key_columns => { unit_id => 'id' },
  },
);

1;
;
