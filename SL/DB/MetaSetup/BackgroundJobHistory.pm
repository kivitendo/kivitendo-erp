# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::BackgroundJobHistory;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('background_job_histories');

__PACKAGE__->meta->columns(
  data         => { type => 'text' },
  error        => { type => 'text', alias => 'error_col' },
  id           => { type => 'serial', not_null => 1 },
  package_name => { type => 'varchar', length => 255 },
  result       => { type => 'text' },
  run_at       => { type => 'timestamp' },
  status       => { type => 'varchar', length => 255 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

1;
;
