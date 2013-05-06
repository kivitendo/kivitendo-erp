# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::ProjectParticipant;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'project_participants',

  columns => [
    id              => { type => 'serial', not_null => 1 },
    project_id      => { type => 'integer', not_null => 1 },
    employee_id     => { type => 'integer', not_null => 1 },
    project_role_id => { type => 'integer', not_null => 1 },
    minutes         => { type => 'integer', default => '0', not_null => 1 },
    cost_per_hour   => { type => 'numeric', precision => 5, scale => 15 },
    itime           => { type => 'timestamp', default => '06.05.2013 14:26:18.81159' },
    mtime           => { type => 'timestamp' },
  ],

  primary_key_columns => [ 'id' ],

  foreign_keys => [
    employee => {
      class       => 'SL::DB::Employee',
      key_columns => { employee_id => 'id' },
    },

    project => {
      class       => 'SL::DB::Project',
      key_columns => { project_id => 'id' },
    },

    project_role => {
      class       => 'SL::DB::ProjectRole',
      key_columns => { project_role_id => 'id' },
    },
  ],
);

1;
;
