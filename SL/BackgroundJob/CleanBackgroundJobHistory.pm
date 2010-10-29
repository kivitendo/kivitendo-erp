package SL::BackgroundJob::CleanBackgroundJobHistory;

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
