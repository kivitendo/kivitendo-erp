# @tag: background_jobs_3
# @description: Backgroundjob Cleanup einrichten
# @depends: emmvee_background_jobs_2
package SL::DBUpgrade2::background_jobs_3;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::BackgroundJob::BackgroundJobCleanup;

sub run {
  SL::BackgroundJob::BackgroundJobCleanup->create_job;
  return 1;
}

1;
