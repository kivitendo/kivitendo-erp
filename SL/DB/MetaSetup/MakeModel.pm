# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::MakeModel;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('makemodel');

__PACKAGE__->meta->columns(
  id         => { type => 'serial', not_null => 1 },
  itime      => { type => 'timestamp', default => 'now()' },
  lastcost   => { type => 'numeric', precision => 5, scale => 15 },
  lastupdate => { type => 'date' },
  make       => { type => 'integer' },
  model      => { type => 'text' },
  mtime      => { type => 'timestamp' },
  parts_id   => { type => 'integer' },
  sortorder  => { type => 'integer' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

1;
;
