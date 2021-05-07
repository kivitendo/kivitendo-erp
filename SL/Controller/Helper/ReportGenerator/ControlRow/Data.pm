package SL::Controller::Helper::ReportGenerator::ControlRow::Data;

use strict;

use parent qw(SL::Controller::Helper::ReportGenerator::ControlRow::Base);


sub validate_params {
  my ($self) = @_;

  my @errors;
  push @errors, 'type "data" needs a parameter "row" as hash ref' if !$self->params->{row} || ('HASH' ne ref $self->params->{row});

  return @errors;;
}

sub set_data {
  my ($self, $report) = @_;

  my %data;
  %data = map {
    my $def = $self->params->{row}->{$_};
    my $tmp;

    foreach my $attr (qw(raw_data data link class align)) {
      $tmp->{$attr} = $def->{$attr} if defined $def->{$attr};
    }
    $_ => $tmp;
  } keys %{ $self->params->{row} };

  $report->add_data(\%data);
}


1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::Helper::ReportGenerator::ControlRow::Data - an
implementaion of a control row class to display data

=head1 DESCRIPTION

This class implements a control row for the report generator helper to display
data. You can configure the way the data is displayed.

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
    my $total = $self->get_total($objects);
    push @$objects, make_control_row(
      "data",
      row => { duration => { data  => $total,
                             class => 'listtotal',
                             link  => '#info_for_total' } }
    );

    # Let report generator create the output.
    $self->report_generator_list_objects(
      report  => $report,
      objects => $objects,
    );
  }

=head1 PARAMETERS

This control row gets the paramter C<row>, which must a hash ref.
The keys are the column names for the fields you want to show your
data. The values are hash refs itself and can contain the keys
C<raw_data>, C<data>, C<link>, C<class> and C<align> which are passed
in the data added to the report.

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
