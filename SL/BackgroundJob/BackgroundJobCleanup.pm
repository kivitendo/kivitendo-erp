package SL::BackgroundJob::BackgroundJobCleanup;

use strict;

use parent qw(SL::BackgroundJob::Base);

use SL::DB::BackgroundJob;

sub create_job {
  $_[0]->create_standard_job('0 3 * * *'); # daily at 3:00 am
}

sub run {
  SL::DB::Manager::BackgroundJob->cleanup;

  return 1;
}

1;

__END__

=encoding utf8

=head1 NAME

SL::BackgroundJob::BackgroundJobCleanup - Background job for
cleaning the background job table of all executed one time jobs

=head1 SYNOPSIS

This background job deletes old entries from the table
C<background_jobs>. This happens to background jobs that were
supposed to run only once and were already run.

The job is supposed to run once a day.

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
