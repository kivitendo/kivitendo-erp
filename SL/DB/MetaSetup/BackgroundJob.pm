# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::BackgroundJob;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('background_jobs');

__PACKAGE__->meta->columns(
  id           => { type => 'serial', not_null => 1 },
  type         => { type => 'varchar', length => 255 },
  package_name => { type => 'varchar', length => 255 },
  last_run_at  => { type => 'timestamp' },
  next_run_at  => { type => 'timestamp' },
  data         => { type => 'text' },
  active       => { type => 'boolean' },
  cron_spec    => { type => 'varchar', length => 255 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

# __PACKAGE__->meta->initialize;

1;
;
