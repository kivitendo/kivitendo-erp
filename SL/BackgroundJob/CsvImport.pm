package SL::BackgroundJob::CsvImport;

use strict;

use parent qw(SL::BackgroundJob::Base);

use SL::JSON;
use SL::YAML;
use SL::DB::CsvImportProfile;

sub create_job {
  my ($self_or_class, %params) = @_;

  my $package       = ref($self_or_class) || $self_or_class;
  $package          =~ s/SL::BackgroundJob:://;

  my %data = (
    %params,
    session_id => $::auth->get_session_id,
  );

  my $job = SL::DB::BackgroundJob->new(
    type         => 'once',
    active       => 1,
    package_name => $package,
    data         => SL::YAML::Dump(\%data),
  );

  return $job;
}

sub profile {
  my ($self) = @_;

  if (!$self->{profile}) {
    my $data = SL::YAML::Load($self->{db_obj}->data);
    $self->{profile} = SL::DB::Manager::CsvImportProfile->find_by(id => $data->{profile_id});
  }

  return $self->{profile};
}

sub run {
  my $self        = shift;
  $self->{db_obj} = shift;

  $self->do_import;
}

sub do_import {
  my ($self) = @_;

  require SL::Controller::CsvImport;
  my $c = SL::Controller::CsvImport->new;
  my $job = $self->{db_obj};

  $c->profile($self->profile);
  $c->mappings(SL::JSON::from_json($self->profile->get('json_mappings'))) if $self->profile->get('json_mappings');
  $c->type($job->data_as_hash->{type});
  $c->{employee_id} = $job->data_as_hash->{employee_id};

  my $test = $job->data_as_hash->{test};


  # $::locale->text('parsing csv')
  # $::locale->text('building data')
  # $::locale->text('saving data')
  # $::locale->text('building report')
  $self->track_progress(
    progress => 0,
    plan => {
      'parsing csv'     => 1,
      'building data'   => 2,
    ( 'saving data'     => 3, )x!$test,
      'building report' => ($test ? 3 : 4),
    },
    num_phases => ($test ? 3 : 4),
  );
  $c->add_progress_tracker($self);

  my $session_id = $job->data_as_hash->{session_id};

  $c->test_and_import(test => $test, session_id => $session_id);
  my $result;
  if ($c->errors) {
    $job->set_data(
      errors   => $c->errors,
    )->save;
    $result = $::locale->text('Import finished with errors.');
  } else {

    my $report_id = $c->save_report(session_id => $session_id, test => $test);
    $job->set_data(report_id => $report_id)->save;

    $c->track_progress(finished => 1);
    $result = $::locale->text('Import finished without errors.');
  }

  return $result;
}

sub track_progress {
  my ($self, %params) = @_;

  my $data = $self->{db_obj}->data_as_hash;
  my $progress = $data->{progress} || {};

  $progress->{$_} = $params{$_} for keys %params;
  $self->{db_obj}->set_data(progress => $progress);
  $self->{db_obj}->save;
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Background::CsvImport - backend for automatic imports of csv data

=head1 SYNOPSIS


use SL::BackgroundJob::CsvImport;


From a controller or external source:

  my $job = SL::BackgroundJob::CsvImport->create_job(
    file => $file,
    %import_options
  );

=head1 DESCRIPTION

=head1 FUNCTIONS

=head1 BUGS

=head1 AUTHOR

Sven Schoeling E<lt>s.schoeling@linet-services.deE<gt>

=cut
