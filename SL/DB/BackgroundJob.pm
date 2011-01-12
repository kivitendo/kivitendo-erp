package SL::DB::BackgroundJob;

use strict;

use DateTime::Event::Cron;
use English qw(-no_match_vars);

use SL::DB::MetaSetup::BackgroundJob;
use SL::DB::Manager::BackgroundJob;

use SL::DB::BackgroundJobHistory;

use SL::BackgroundJob::Test;

sub update_next_run_at {
  my $self = shift;

  my $cron = DateTime::Event::Cron->new_from_cron($self->cron_spec || '* * * * *');
  $self->update_attributes(next_run_at => $cron->next(DateTime->now_local));
  return $self;
}

sub run {
  my $self = shift;

  my $package = "SL::BackgroundJob::" . $self->package_name;
  my $run_at  = DateTime->now_local;
  my $history;

  my $ok = eval {
    my $result = $package->new->run($self);

    $history = SL::DB::BackgroundJobHistory
      ->new(package_name => $self->package_name,
            run_at       => $run_at,
            status       => 'success',
            result       => $result,
            data         => $self->data);
    $history->save;

    1;
  };

  if (!$ok) {
    $history = SL::DB::BackgroundJobHistory
      ->new(package_name => $self->package_name,
            run_at       => $run_at,
            status       => 'failure',
            error_col    => $EVAL_ERROR,
            data         => $self->data);
    $history->save;
  }

  $self->assign_attributes(last_run_at => $run_at)->update_next_run_at;

  return $history;
}

sub data_as_hash {
  my $self = shift;
  return {}                        if !$self->data;
  return $self->data               if ref($self->{data}) eq 'HASH';
  return YAML::Load($self->{data}) if !ref($self->{data});
  return {};
}

1;
