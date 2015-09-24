# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::ProjectPhase;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('project_phases');

__PACKAGE__->meta->columns(
  budget_cost           => { type => 'numeric', default => '0', not_null => 1, precision => 15, scale => 5 },
  budget_minutes        => { type => 'integer', default => '0', not_null => 1 },
  description           => { type => 'text', not_null => 1 },
  end_date              => { type => 'date' },
  general_cost_per_hour => { type => 'numeric', default => '0', not_null => 1, precision => 15, scale => 5 },
  general_minutes       => { type => 'integer', default => '0', not_null => 1 },
  id                    => { type => 'serial', not_null => 1 },
  itime                 => { type => 'timestamp', default => 'now()' },
  mtime                 => { type => 'timestamp' },
  name                  => { type => 'text', not_null => 1 },
  project_id            => { type => 'integer' },
  start_date            => { type => 'date' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  project => {
    class       => 'SL::DB::Project',
    key_columns => { project_id => 'id' },
  },
);

1;
;
