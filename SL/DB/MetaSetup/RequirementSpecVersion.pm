# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::RequirementSpecVersion;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'requirement_spec_versions',

  columns => [
    id             => { type => 'serial', not_null => 1 },
    version_number => { type => 'integer' },
    description    => { type => 'text', not_null => 1 },
    comment        => { type => 'text' },
    order_date     => { type => 'date' },
    order_number   => { type => 'text' },
    order_id       => { type => 'integer' },
    itime          => { type => 'timestamp', default => 'now()' },
    mtime          => { type => 'timestamp' },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,

  foreign_keys => [
    order => {
      class       => 'SL::DB::Order',
      key_columns => { order_id => 'id' },
    },
  ],
);

1;
;
