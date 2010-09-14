# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::PartsTax;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'partstax',

  columns => [
    parts_id => { type => 'integer' },
    chart_id => { type => 'integer' },
    itime    => { type => 'timestamp', default => 'now()' },
    mtime    => { type => 'timestamp' },
    id       => { type => 'serial', not_null => 1 },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,
);

1;
;
