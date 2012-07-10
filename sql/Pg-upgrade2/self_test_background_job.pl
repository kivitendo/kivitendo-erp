# @tag: self_test_background_job
# @description: Hintergrundjob für tägliche Selbsttests
# @depends: release_2_7_0
# @charset: utf-8

use strict;

use SL::BackgroundJob::SelfTest;

SL::BackgroundJob::SelfTest->create_job;

1;
