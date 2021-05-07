package SL::Controller::Helper::ReportGenerator::ControlRow;

use strict;
use Carp;

use SL::Controller::Helper::ReportGenerator::ControlRow::ALL;

use Exporter 'import';
our @EXPORT = qw(
  make_control_row
);


sub make_control_row {
  my ($type, %args) = @_;

  my $class  = $SL::Controller::Helper::ReportGenerator::ControlRow::ALL::type_to_class{$type} // croak "unknown type $type";
  my $obj    = $class->new(params => \%args);
  my @errors = $obj->validate_params;
  croak join("\n", @errors) if @errors;

  return $obj;
}


1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::Helper::ReportGenerator::ControlRow - an interface for
report generator control rows

=head1 DESCRIPTION

ControlRow is an interface that allows generic control rows to be added
to objects for the C<SL::Controller::Helper::ReportGenerator>.

Each control row implementation can access the report and add data for a row.

=head1 SYNOPSIS

  package SL::Controller::TimeRecording;

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

    # And a simple total
    my $total = sum0 map { _round_total($_->duration_in_hours) } @$objects;
    push @$objects, make_control_row("simple_data", data => {duration => $total});

    # Let report generator create the output.
    $self->report_generator_list_objects(
      report  => $report,
      objects => $objects,
    );
  }


=head1 WRITING OWN CONTROL ROW CLASSES

See C<SL::Controller::Helper::ReportGenerator::ControlRow::Base>.

=head1 FUNCTIONS

=over 4

=item C<make_control_row TYPE %PARAMS>

Returns an instance of the control row class for the given type. This
object can be used as an element of objects to the report generator helper
(see C<SL::Controller::Helper::ReportGenerator>).

Available types are 'separator', 'data, 'simple_data' for now.

C<%PARAMS> depends on the type. See also:

L<SL::Controller::Helper::ReportGenerator::ControlRow::ALL>
L<SL::Controller::Helper::ReportGenerator::ControlRow::*>

=back

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
