# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Tax;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('tax');

__PACKAGE__->meta->columns(
  chart_categories => { type => 'text', not_null => 1 },
  chart_id         => { type => 'integer' },
  id               => { type => 'integer', not_null => 1, sequence => 'id' },
  itime            => { type => 'timestamp', default => 'now()' },
  mtime            => { type => 'timestamp' },
  rate             => { type => 'numeric', default => '0', not_null => 1, precision => 5, scale => 15 },
  taxdescription   => { type => 'text', not_null => 1 },
  taxkey           => { type => 'integer', not_null => 1 },
  taxnumber        => { type => 'text' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  chart => {
    class       => 'SL::DB::Chart',
    key_columns => { chart_id => 'id' },
  },
);

1;
;
