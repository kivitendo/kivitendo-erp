# @tag: emmvee_background_jobs_2
# @description: Hintergrundjobs einrichten
# @depends: emmvee_background_jobs
package SL::DBUpgrade2::emmvee_background_jobs_2;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::BackgroundJob::CleanBackgroundJobHistory;

sub run {
  SL::BackgroundJob::CleanBackgroundJobHistory->create_job;
  return 1;
}

1;
