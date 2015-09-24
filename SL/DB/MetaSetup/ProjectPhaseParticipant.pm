# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::ProjectPhaseParticipant;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('project_phase_participants');

__PACKAGE__->meta->columns(
  cost_per_hour    => { type => 'numeric', precision => 15, scale => 5 },
  employee_id      => { type => 'integer', not_null => 1 },
  id               => { type => 'serial', not_null => 1 },
  itime            => { type => 'timestamp', default => 'now()' },
  minutes          => { type => 'integer', default => '0', not_null => 1 },
  mtime            => { type => 'timestamp' },
  project_phase_id => { type => 'integer', not_null => 1 },
  project_role_id  => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  employee => {
    class       => 'SL::DB::Employee',
    key_columns => { employee_id => 'id' },
  },

  project_phase => {
    class       => 'SL::DB::ProjectPhase',
    key_columns => { project_phase_id => 'id' },
  },

  project_role => {
    class       => 'SL::DB::ProjectRole',
    key_columns => { project_role_id => 'id' },
  },
);

1;
;
