# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::ProjectRole;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('project_roles');

__PACKAGE__->meta->columns(
  description => { type => 'text', not_null => 1 },
  id          => { type => 'serial', not_null => 1 },
  itime       => { type => 'timestamp', default => '2013-05-08 09:11:09.704126' },
  mtime       => { type => 'timestamp' },
  name        => { type => 'text', not_null => 1 },
  position    => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

1;
;
