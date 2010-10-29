package SL::DB::BackgroundJob;

use strict;

use DateTime::Event::Cron;

use SL::DB::MetaSetup::BackgroundJob;
use SL::DB::Manager::BackgroundJob;

sub update_next_run_at {
  my $self = shift;

  my $cron = DateTime::Event::Cron->new_from_cron($self->cron_spec || '* * * * *');
  $self->update_attributes(next_run_at => $cron->next->set_time_zone($::locale->get_local_time_zone));
  return $self;
}

1;
