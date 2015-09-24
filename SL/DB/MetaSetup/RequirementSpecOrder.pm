# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::RequirementSpecOrder;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('requirement_spec_orders');

__PACKAGE__->meta->columns(
  id                  => { type => 'serial', not_null => 1 },
  itime               => { type => 'timestamp', default => 'now()', not_null => 1 },
  mtime               => { type => 'timestamp', default => 'now()', not_null => 1 },
  order_id            => { type => 'integer', not_null => 1 },
  requirement_spec_id => { type => 'integer', not_null => 1 },
  version_id          => { type => 'integer' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->unique_keys([ 'requirement_spec_id', 'order_id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  order => {
    class       => 'SL::DB::Order',
    key_columns => { order_id => 'id' },
  },

  requirement_spec => {
    class       => 'SL::DB::RequirementSpec',
    key_columns => { requirement_spec_id => 'id' },
  },

  version => {
    class       => 'SL::DB::RequirementSpecVersion',
    key_columns => { version_id => 'id' },
  },
);

1;
;
