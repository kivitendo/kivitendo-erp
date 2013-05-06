# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::ProjectStatus;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'project_status',

  columns => [
    id          => { type => 'serial', not_null => 1 },
    name        => { type => 'text', not_null => 1 },
    description => { type => 'text', not_null => 1 },
    position    => { type => 'integer', not_null => 1 },
    itime       => { type => 'timestamp', default => '06.05.2013 14:26:18.81159' },
    mtime       => { type => 'timestamp' },
  ],

  primary_key_columns => [ 'id' ],

  relationships => [
    project => {
      class      => 'SL::DB::Project',
      column_map => { id => 'project_status_id' },
      type       => 'one to many',
    },
  ],
);

1;
;
