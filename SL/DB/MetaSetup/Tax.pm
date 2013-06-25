# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Tax;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'tax',

  columns => [
    chart_id         => { type => 'integer' },
    rate             => { type => 'numeric', default => '0', not_null => 1, precision => 5, scale => 15 },
    taxnumber        => { type => 'text' },
    taxkey           => { type => 'integer', not_null => 1 },
    taxdescription   => { type => 'text', not_null => 1 },
    itime            => { type => 'timestamp', default => 'now()' },
    mtime            => { type => 'timestamp' },
    id               => { type => 'integer', not_null => 1, sequence => 'id' },
    chart_categories => { type => 'text', not_null => 1 },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,

  foreign_keys => [
    chart => {
      class       => 'SL::DB::Chart',
      key_columns => { chart_id => 'id' },
    },
  ],
);

1;
;
