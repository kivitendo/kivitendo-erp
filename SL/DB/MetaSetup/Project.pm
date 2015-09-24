# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Project;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('project');

__PACKAGE__->meta->columns(
  active               => { type => 'boolean', default => 'true' },
  billable_customer_id => { type => 'integer' },
  budget_cost          => { type => 'numeric', default => '0', not_null => 1, precision => 15, scale => 5 },
  budget_minutes       => { type => 'integer', default => '0', not_null => 1 },
  customer_id          => { type => 'integer' },
  description          => { type => 'text' },
  end_date             => { type => 'date' },
  id                   => { type => 'integer', not_null => 1, sequence => 'id' },
  itime                => { type => 'timestamp', default => 'now()' },
  mtime                => { type => 'timestamp' },
  order_value          => { type => 'numeric', default => '0', not_null => 1, precision => 15, scale => 5 },
  project_status_id    => { type => 'integer', not_null => 1 },
  project_type_id      => { type => 'integer', not_null => 1 },
  projectnumber        => { type => 'text' },
  start_date           => { type => 'date' },
  timeframe            => { type => 'boolean', default => 'false', not_null => 1 },
  valid                => { type => 'boolean', default => 'true' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->unique_keys([ 'projectnumber' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  billable_customer => {
    class       => 'SL::DB::Customer',
    key_columns => { billable_customer_id => 'id' },
  },

  customer => {
    class       => 'SL::DB::Customer',
    key_columns => { customer_id => 'id' },
  },

  project_status => {
    class       => 'SL::DB::ProjectStatus',
    key_columns => { project_status_id => 'id' },
  },

  project_type => {
    class       => 'SL::DB::ProjectType',
    key_columns => { project_type_id => 'id' },
  },
);

1;
;
