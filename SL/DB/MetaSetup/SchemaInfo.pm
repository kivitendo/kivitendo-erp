# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::SchemaInfo;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'schema_info',

  columns => [
    tag   => { type => 'text', not_null => 1 },
    login => { type => 'text' },
    itime => { type => 'timestamp', default => 'now()' },
  ],

  primary_key_columns => [ 'tag' ],

  allow_inline_column_values => 1,
);

1;
;
