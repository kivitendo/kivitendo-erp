package SL::Controller::Helper::ReportGenerator::ControlRow::Separator;

use strict;

use parent qw(SL::Controller::Helper::ReportGenerator::ControlRow::Base);


sub validate_params {
  return;
}

sub set_data {
  my ($self, $report) = @_;

  $report->add_separator();
}


1;


__END__

=encoding utf-8

=head1 NAME

SL::Controller::Helper::ReportGenerator::ControlRow::Separator - an
implementaion of a control row class to display a separator

=head1 DESCRIPTION

This class implements a control row for the report generator helper to display
a separator.

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

    # Add a separator
    push @$objects, make_control_row("separator");

    # Let report generator create the output.
    $self->report_generator_list_objects(
      report  => $report,
      objects => $objects,
    );
  }

=head1 PARAMETERS

This control row does not use any parameters.

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
