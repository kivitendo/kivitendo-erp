# @tag: background_jobs_clean_auth_sessions
# @description: Hintergrundjob zum Löschen abgelaufener Sessions
# @depends: release_3_1_0
package SL::DBUpgrade2::background_jobs_clean_auth_sessions;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::BackgroundJob::CleanAuthSessions;

sub run {
  my ($self) = @_;

  SL::BackgroundJob::CleanAuthSessions->create_job;

  return 1;
}

1;
