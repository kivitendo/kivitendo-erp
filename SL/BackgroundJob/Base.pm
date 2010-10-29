package SL::BackgroundJob::Base;

use strict;

use parent qw(Rose::Object);

use SL::DB::BackgroundJob;

sub create_standard_job {
  my $self_or_class = shift;
  my $cron_spec     = shift;

  my $package       = ref($self_or_class) || $self_or_class;
  $package          =~ s/SL::BackgroundJob:://;

  my %params        = (cron_spec    => $cron_spec || '* * * * *',
                       type         => 'interval',
                       active       => 1,
                       package_name => $package);

  my $job = SL::DB::Manager::BackgroundJob->find_by(package_name => $params{package_name});
  if (!$job) {
    $job = SL::DB::BackgroundJob->new(%params)->update_next_run_at;
  } else {
    $job->assign_attributes(%params)->update_next_run_at;
  }

  return $job;
}

1;
