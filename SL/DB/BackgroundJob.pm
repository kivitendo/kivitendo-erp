package SL::DB::BackgroundJob;

use strict;

use DateTime::Event::Cron;
use English qw(-no_match_vars);

use Rose::DB::Object::Helpers qw(as_tree);

use SL::DB::MetaSetup::BackgroundJob;
use SL::DB::Manager::BackgroundJob;

use SL::System::Process;
use SL::YAML;

__PACKAGE__->meta->initialize;

__PACKAGE__->before_save('_before_save_set_next_run_at');

sub _before_save_set_next_run_at {
  my ($self) = @_;

  $self->update_next_run_at if !$self->next_run_at;
  return 1;
}

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

  require SL::DB::BackgroundJobHistory;

  my $ok = eval {
    eval "require $package" or die $@;
    my $result = $package->new->run($self);

    $history = SL::DB::BackgroundJobHistory
      ->new(package_name => $self->package_name,
            run_at       => $run_at,
            status       => SL::DB::BackgroundJobHistory::SUCCESS(),
            result       => $result,
            data         => $self->data);
    $history->save;

    1;
  };

  if (!$ok) {
    my $error = $EVAL_ERROR;
    $history = SL::DB::BackgroundJobHistory
      ->new(package_name => $self->package_name,
            run_at       => $run_at,
            status       => SL::DB::BackgroundJobHistory::FAILURE(),
            error_col    => $error,
            data         => $self->data);
    $history->save;

    $::lxdebug->message(LXDebug->WARN(), "BackgroundJob ID " . $self->id . " execution error (first three lines): " . join("\n", (split(m/\n/, $error))[0..2]));
  }

  $self->assign_attributes(last_run_at => $run_at)->update_next_run_at;

  return $history;
}

sub data_as_hash {
  my $self = shift;

  $self->data(SL::YAML::Dump($_[0])) if @_;

  return {}                        if !$self->data;
  return $self->data               if ref($self->{data}) eq 'HASH';
  return SL::YAML::Load($self->{data}) if !ref($self->{data});
  return {};
}

sub set_data {
  my ($self, %data) = @_;

  $self->data(SL::YAML::Dump({
    %{ $self->data_as_hash },
    %data,
  }));

  $self;
}

sub validate {
  my ($self) = @_;

  my @errors;

  push @errors, $::locale->text('The execution type is invalid.') if ($self->type         || '') !~ m/^(?: once | interval )$/x;

  if (   (($self->package_name || '') !~ m/^ [A-Z][A-Za-z0-9]+ $/x)
      || ! -f (SL::System::Process::exe_dir() . "/SL/BackgroundJob/" . $self->package_name . ".pm")) {
    push @errors, $::locale->text('The package name is invalid.');
  }

  eval {
    DateTime::Event::Cron->new_from_cron($self->cron_spec || '* * * * *')->next(DateTime->now_local);
    1;
  } or push @errors, $::locale->text('The execution schedule is invalid.');

  return @errors;
}

1;
