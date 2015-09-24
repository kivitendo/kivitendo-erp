# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::ProjectType;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('project_types');

__PACKAGE__->meta->columns(
  description => { type => 'text' },
  id          => { type => 'serial', not_null => 1 },
  internal    => { type => 'boolean', default => 'false', not_null => 1 },
  position    => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

1;
;
