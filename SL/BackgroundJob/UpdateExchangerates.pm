package SL::BackgroundJob::UpdateExchangerates;

use strict;
use utf8;

use parent qw(SL::BackgroundJob::Base);

use SL::DB::Exchangerate;
use SL::DB::Currency;

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(worker) ],
);


sub create_job {
  my $self_or_class = shift;

  my $package       = ref($self_or_class) || $self_or_class;
  $package          =~ s/SL::BackgroundJob:://;

  my $cron_spec     = ('35 4 * * *'); # every day at 4:35 am

  my $data = <<DATA;
module: FromYahoo
options:
  translate:
    £: GBP
DATA

  my %params = (cron_spec    => $cron_spec,
                type         => 'interval',
                active       => 1,
                package_name => $package,
                data         => $data);

  my $job = SL::DB::Manager::BackgroundJob->find_by(package_name => $params{package_name});
  if (!$job) {
    $job = SL::DB::BackgroundJob->new(%params)->update_next_run_at;
  } else {
    $job->assign_attributes(%params)->update_next_run_at;
  }

  return $job;
}

sub run {
  my ($self, $db_obj) = @_;

  my $params = $db_obj->data_as_hash;

  return $::locale->text('Parameter module must be given.') if !$params->{module};

  # instanciate worker for given module
  my $error;
  eval {
    my $worker_class = 'SL::BackgroundJob::UpdateExchangerates::' . $params->{module};
    eval "require $worker_class";
    $self->worker($worker_class->new(options => $params->{options}));
    1;
  } or do {
    $error = $::locale->text('Could not load class #1 (#2): "#3"', $params->{module}, 'SL/BackgroundJob/UpdateExchangerates', $@);
  };
  return $error if $error;

  my $default_currency = SL::DB::Currency->new(id => $::instance_conf->get_currency_id)->load;
  my $transdate = DateTime->today_local;
  my @rates_to_update;

  # collect currencies that should be updated
  foreach my $currency (@{SL::DB::Manager::Currency->get_all_sorted}) {
    next if $currency->id == $default_currency->id;

    my $exrate = SL::DB::Manager::Exchangerate->find_by(transdate => $transdate, currency_id => $currency->id);

    if (!$exrate) {
      push @rates_to_update, {from => $default_currency,
                              to   => $currency,
                              dir  => 'buy'};
      push @rates_to_update, {from => $default_currency,
                              to   => $currency,
                              dir  => 'sell'};
      next;
    }

    if (!$exrate->buy) {
      push @rates_to_update, {from => $default_currency,
                              to   => $currency,
                              dir  => 'buy'};
    }
    if (!$exrate->sell) {
      push @rates_to_update, {from => $default_currency,
                              to   => $currency,
                              dir  => 'sell'};
    }
  }

  return "updated: 0" if scalar @rates_to_update == 0;

  # update rates
  $self->worker->update_rates(\@rates_to_update);

  # save rates
  my @updated;
  foreach my $rate (@rates_to_update) {
    my $exrate = SL::DB::Manager::Exchangerate->find_by_or_create(transdate => $transdate, currency_id => $rate->{to}->id);

    next if !$exrate;           # should not happen

    if ($rate->{rate}) {
      $exrate->transdate($transdate) if !$exrate->transdate;
      $exrate->currency($rate->{to}) if !$exrate->currency;

      my $method = $rate->{dir};
      if (!$exrate->$method) {
        $exrate->$method($rate->{rate});
        $exrate->save;
        push @updated, $rate->{to}->name . " ($method: " . $rate->{rate} . ")";
      }
    }
  }

  return "updated: " . scalar @updated . ': ' . join ', ', @updated;
}


1;


__END__

=encoding utf8

=head1 NAME

SL::BackgroundJob::UpdateExchangerates - Background job for updating the
exchange rates for currencies

=head1 SYNOPSIS

This background job can update all exchange rates for currencies if the rates
are not already present for the current date.
A worker module must be given as data to the job (see documentation at
SL::BackgroundJob::UpdateExchangerates::Base and
SL::BackgroundJob::UpdateExchangerates::* as examples).
The worker will be used to get the actual rates from some kind of service.
Options to the worker can be given as data to the background job:

module: FromOpenexchangerates
options:
  api_id: 1234565789
  translate:
    £: GBP

=head1 Todo

Better error handling / error notification

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut

