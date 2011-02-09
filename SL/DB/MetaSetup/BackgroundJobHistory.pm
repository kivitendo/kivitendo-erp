# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::BackgroundJobHistory;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'background_job_histories',

  columns => [
    id           => { type => 'serial', not_null => 1 },
    package_name => { type => 'varchar', length => 255 },
    run_at       => { type => 'timestamp' },
    status       => { type => 'varchar', length => 255 },
    result       => { type => 'text' },
    error        => { type => 'text', alias => 'error_col' },
    data         => { type => 'text' },
  ],

  primary_key_columns => [ 'id' ],
);

1;
;
