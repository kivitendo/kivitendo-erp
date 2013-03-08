# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::RequirementSpecDependency;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'requirement_spec_item_dependencies',

  columns => [
    depending_item_id => { type => 'integer', not_null => 1 },
    depended_item_id  => { type => 'integer', not_null => 1 },
  ],

  primary_key_columns => [ 'depending_item_id', 'depended_item_id' ],

  foreign_keys => [
    depended_item => {
      class       => 'SL::DB::RequirementSpecItem',
      key_columns => { depended_item_id => 'id' },
    },

    depending_item => {
      class       => 'SL::DB::RequirementSpecItem',
      key_columns => { depending_item_id => 'id' },
    },
  ],
);

1;
;
