package SL::Controller::Helper::ReportGenerator::ControlRow::SimpleData;

use strict;

use parent qw(SL::Controller::Helper::ReportGenerator::ControlRow::Base);


sub validate_params {
  my ($self) = @_;

  my @errors;
  push @errors, 'type "simple_data" needs a parameter "data" as hash ref' if !$self->params->{data} || ('HASH' ne ref $self->params->{data});

  return @errors;
}

sub set_data {
  my ($self, $report) = @_;

  my %data = map {
    my $tmp;
    $tmp->{data} = $self->params->{data}->{$_};
    $_ => $tmp;
  } keys %{ $self->params->{data} };

  $report->add_data(\%data);
}


1;


__END__

=encoding utf-8

=head1 NAME

SL::Controller::Helper::ReportGenerator::ControlRow::SimpleData - an
implementaion of a control row class to display simple data

=head1 DESCRIPTION

This class implements a control row for the report generator helper to display
simple data. C<Simple> because you only have to provide the column and your data
as a string.

=head1 SYNOPSIS

  use SL::Controller::Helper::ReportGenerator;
  use SL::Controller::Helper::ReportGenerator::ControlRow qw(make_control_row);

  sub action_list {
    my ($self) = @_;

    # Set up the report generator instance. In this example this is
    # hidden in "prepare_report".
    my $report = $self->prepare_report;

    # Get objects from database.
    my $objects = SL::DB::Manager::TimeRecording->get_all(...);

    # Add a simple data
    push @$objects, make_control_row(
      "simple_data",
      data => { duration => 'Total sum of duration is not implemeted yet' }
    );

    # Let report generator create the output.
    $self->report_generator_list_objects(
      report  => $report,
      objects => $objects,
    );
  }

=head1 PARAMETERS

This control row gets the paramter C<data>, which must a hash ref.
The keys are the column names for the fields you want to show your
data. The values are the data.

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
