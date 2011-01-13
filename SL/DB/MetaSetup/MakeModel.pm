# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::MakeModel;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'makemodel',

  columns => [
    parts_id   => { type => 'integer' },
    model      => { type => 'text' },
    itime      => { type => 'timestamp', default => 'now()' },
    mtime      => { type => 'timestamp' },
    lastcost   => { type => 'numeric', precision => 5, scale => 15 },
    lastupdate => { type => 'date' },
    sortorder  => { type => 'integer' },
    make       => { type => 'integer' },
    id         => { type => 'serial', not_null => 1 },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,
);

1;
;
