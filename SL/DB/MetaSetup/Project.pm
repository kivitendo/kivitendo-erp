# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Project;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'project',

  columns => [
    id            => { type => 'integer', not_null => 1, sequence => 'id' },
    projectnumber => { type => 'text' },
    description   => { type => 'text' },
    itime         => { type => 'timestamp', default => 'now()' },
    mtime         => { type => 'timestamp' },
    active        => { type => 'boolean', default => 'true' },
  ],

  primary_key_columns => [ 'id' ],

  unique_key => [ 'projectnumber' ],

  allow_inline_column_values => 1,
);

1;
;
