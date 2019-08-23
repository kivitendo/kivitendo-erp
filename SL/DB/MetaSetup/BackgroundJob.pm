# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::BackgroundJob;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('background_jobs');

__PACKAGE__->meta->columns(
  active       => { type => 'boolean' },
  cron_spec    => { type => 'varchar', length => 255 },
  data         => { type => 'text' },
  id           => { type => 'serial', not_null => 1 },
  last_run_at  => { type => 'timestamp' },
  next_run_at  => { type => 'timestamp' },
  node_id      => { type => 'text' },
  package_name => { type => 'varchar', length => 255 },
  type         => { type => 'varchar', length => 255 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

1;
;
