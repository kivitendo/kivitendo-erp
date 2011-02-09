package SL::BackgroundJob::CleanBackgroundJobHistory;

use strict;

use parent qw(SL::BackgroundJob::Base);

use SL::DB::BackgroundJobHistory;

sub create_job {
  $_[0]->create_standard_job('0 3 * * *'); # daily at 3:00 am
}

sub run {
  my $self    = shift;
  my $db_obj  = shift;

  my $options = $db_obj->data_as_hash;
  $options->{retention_success} ||= 14;
  $options->{retention_failure} ||= 3 * 30;

  my $today = DateTime->today_local;

  for my $status (qw(success failure)) {
    SL::DB::Manager::BackgroundJobHistory->delete_all(where =>  [ status => $status,
                                                                  run_at => { lt => $today->clone->subtract(days => $options->{"retention_${status}"}) } ]);
  }

  return 1;
}

1;

__END__

=encoding utf8

=head1 NAME

SL::BackgroundJob::CleanBackgroundJobHistory - Background job for
cleaning the history table of all executed jobs

=head1 SYNOPSIS

This background job deletes old entries from the table
C<background_job_histories>. Each time a job is run an entry is
created in that table.

The associated C<SL::DB::BackgroundJob> instance's C<data> may be a
hash containing the retention periods for successful and failed
jobs. Both are the number of days a history entry is to be kept.  C<<
$data->{retention_success} >> defaults to 14.  C<<
$data->{retention_failure} >> defaults to 90.

The job is supposed to run once a day.

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
