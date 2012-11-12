package SL::BackgroundJob::Base;

use strict;

use parent qw(Rose::Object);

use IO::Dir;
use SL::DB::BackgroundJob;
use SL::System::Process;

sub get_known_job_classes {
  tie my %dir_h, 'IO::Dir', File::Spec->catdir(File::Spec->splitdir(SL::System::Process->exe_dir), 'SL', 'BackgroundJob');
  return sort map { s/\.pm$//; $_ } grep { m/\.pm$/ && !m/(?: ALL | Base) \.pm$/x } keys %dir_h;
}

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

__END__

=encoding utf8

=head1 NAME

SL::BackgroundJob::Base - Base class for all background jobs

=head1 SYNOPSIS

All background jobs are derived from this class. Each job gets its own
class which must implement the C<run> method.

There are two types of background jobs: periodic jobs and jobs that
are run once. Periodic jobs have a CRON spec associated with them that
determines the points in time when the job is supposed to be run.

=head1 FUNCTIONS

=over 4

=item C<create_standard_job $cron_spec>

Creates or updates an entry in the database for the current job. If
the C<background_jobs> table contains an entry for the current class
(as determined by C<ref($self)>) then that entry is updated and
re-activated if it was disabled. Otherwise a new entry is created.

This function can be called both as a member or as a class function.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
