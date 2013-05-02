# @tag: self_test_background_job
# @description: Hintergrundjob für tägliche Selbsttests
# @depends: release_2_7_0
package SL::DBUpgrade2::self_test_background_job;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::BackgroundJob::SelfTest;

sub run {
  SL::BackgroundJob::SelfTest->create_job;
  return 1;
}

1;
