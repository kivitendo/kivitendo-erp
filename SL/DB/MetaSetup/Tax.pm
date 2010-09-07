# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Tax;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'tax',

  columns => [
    chart_id       => { type => 'integer' },
    rate           => { type => 'numeric', precision => 5, scale => 15 },
    taxnumber      => { type => 'text' },
    taxkey         => { type => 'integer' },
    taxdescription => { type => 'text' },
    itime          => { type => 'timestamp', default => 'now()' },
    mtime          => { type => 'timestamp' },
    id             => { type => 'integer', not_null => 1, sequence => 'id' },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,
);

1;
;
