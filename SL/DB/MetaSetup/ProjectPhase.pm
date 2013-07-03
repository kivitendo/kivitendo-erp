# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::ProjectPhase;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('project_phases');

__PACKAGE__->meta->columns(
  budget_cost           => { type => 'numeric', default => '0', not_null => 1, precision => 5, scale => 15 },
  budget_minutes        => { type => 'integer', default => '0', not_null => 1 },
  description           => { type => 'text', not_null => 1 },
  end_date              => { type => 'date' },
  general_cost_per_hour => { type => 'numeric', default => '0', not_null => 1, precision => 5, scale => 15 },
  general_minutes       => { type => 'integer', default => '0', not_null => 1 },
  id                    => { type => 'serial', not_null => 1 },
  itime                 => { type => 'timestamp', default => '2013-05-08 09:11:09.704126' },
  mtime                 => { type => 'timestamp' },
  name                  => { type => 'text', not_null => 1 },
  project_id            => { type => 'integer' },
  start_date            => { type => 'date' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->foreign_keys(
  project => {
    class       => 'SL::DB::Project',
    key_columns => { project_id => 'id' },
  },
);

1;
;
