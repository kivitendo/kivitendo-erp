package SL::BackgroundJob::CsvImport;

use strict;

use parent qw(SL::BackgroundJob::Base);

use YAML ();
use SL::Controller::CsvImport;
use SL::DB::CsvImportProfile;
use SL::SessionFile::Random;

sub create_job {
  my ($self_or_class, %params) = @_;

  my $package       = ref($self_or_class) || $self_or_class;
  $package          =~ s/SL::BackgroundJob:://;

  my $profile = delete $params{profile} || SL::DB::CsvImportProfile->new;
  my $new_profile = $profile->clone_and_reset_deep;
  $new_profile->save;

  my %data = (
    %params,
    profile_id => $new_profile->id,
    session_id => $::auth->get_session_id,
  );

  my $job = SL::DB::BackgroundJob->new(
    type         => 'once',
    active       => 1,
    package_name => $package,
    data         => YAML::Dump(\%data),
  );

  return $job;
}

sub profile {
  my ($self) = @_;

  if (!$self->{profile}) {
    my $data = YAML::Load($self->{db_obj}->data);
    $self->{profile} = SL::DB::Manager::CsvImportProfile->find_by(id => $data->{profile_id});
  }

  return $self->{profile};
}

sub run {
  my $self        = shift;
  $self->{db_obj} = shift;

  $self->do_import;

  $self->cleanup;
}

sub do_import {
  my ($self) = @_;

  my $c = SL::Controller::CsvImport->new;

  $c->profile($self->profile);
  $c->type($self->{db_obj}->data_as_hash->{type});
  $c->add_progress_tracker($self);

  $c->test_and_import(test => 1, session_id => $self->{db_obj}->data_as_hash->{session_id});

  my $report_id = $c->save_report;
  $self->{db_obj}->set_data(report_id => $report_id);
  $self->{db_obj}->save;

  $c->track_progress(100);
}

sub track_progress {
  my ($self, $progress) = @_;

  $self->{db_obj}->set_data(progress => $progress);
  $self->{db_obj}->save;
}

sub cleanup {

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
