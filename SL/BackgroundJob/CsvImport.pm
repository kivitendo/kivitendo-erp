package SL::BackgroundJob::CsvImport;

use strict;

use parent qw(SL::BackgroundJob::Base);

use YAML ();
use SL::DB::CsvImportProfile;
use SL::SessionFile::Random;

sub create_job {
  my ($self_or_class, %params) = @_;

  my $package       = ref($self_or_class) || $self_or_class;
  $package          =~ s/SL::BackgroundJob:://;

  my $profile = delete $params{profile} || SL::DB::CsvImportProfile->new;
  my $result  = delete $params{result}  || SL::SessionFile::Random->new;

  my %data = (
    profile => { $profile->flatten },
    result  => $result->file_name,
    %params,
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
  my ($self, $db_obj) = @_;

  if (!$self->{profile}) {
    $self->{profile} = SL::DB::CsvImportProfile->new;
    my $data = YAML::Load($db_obj->data);
    for (keys %$data) {
      $self->{profile}->set($_ => $data->{$_});
    }
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
  $c->profile($self->{profile});
  $c->test_and_import(test => $self->);


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
