# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::RequirementSpecStatus;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'requirement_spec_statuses',

  columns => [
    id          => { type => 'serial', not_null => 1 },
    name        => { type => 'text', not_null => 1 },
    description => { type => 'text', not_null => 1 },
    position    => { type => 'integer', not_null => 1 },
    itime       => { type => 'timestamp', default => 'now()' },
    mtime       => { type => 'timestamp' },
  ],

  primary_key_columns => [ 'id' ],

  unique_key => [ 'name', 'description' ],

  allow_inline_column_values => 1,
);

1;
;
