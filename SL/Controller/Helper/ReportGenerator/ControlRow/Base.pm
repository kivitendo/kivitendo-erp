package SL::Controller::Helper::ReportGenerator::ControlRow::Base;

use strict;

use parent qw(SL::DB::Object);

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(params) ],
);


sub validate_params { die 'name needs to be implemented' }
sub set_data        { die 'name needs to be implemented' }


1;


__END__

=encoding utf-8

=head1 NAME

SL::Controller::Helper::ReportGenerator::ControlRow::Base - a base class
for report generator control row classes

=head1 DESCRIPTION

ControlRow is an interface that allows generic control rows to be added
to objects for the C<SL::Controller::Helper::ReportGenerator>. This is a
base class from which all control row classes are derived.

=head1 SYNOPSIS

Adding your own new control row of the type "only_dashes":

  package SL::Controller::Helper::ReportGenerator::ControlRow::OnlyDashes;

  use parent qw(SL::Controller::Helper::ReportGenerator::ControlRow::Base);

  sub validate_params { return; } # no params

  sub set_data {
    my ($self, $report) = @_;

    my %data = map { $_ => {data => '---'} } keys %{ $report->{columns} };

    $report->add_data(\%data);
  }

After that, you have to register your new class in
C<SL::Controller::Helper::ReportGenerator::ControlRow::ALL>:

  use SL::Controller::Helper::ReportGenerator::ControlRow::OnlyDashes;

  our %type_to_class = (
    ...,
    only_dashes => 'SL::Controller::Helper::ReportGenerator::ControlRow::OnlyDashes',
  );


=head1 WRITING OWN CONTROL ROW CLASSES

You can use C<SL::Controller::Helper::ReportGenerator::ControlRow::Base>
as parent of your module. You have to provide two methods:

=over 4

=item C<validate_params>

This method is used to validate any params used for your module.
You can access the params through the method C<params> which contains all
remaining params after the type of the call to make_control_row (see
C<SL::Controller::Helper::ReportGenerator::ControlRow>).

The method should return an array of error messages if there are any
errors. Otherwise it should return C<undef>.

=item C<set_data REPORT>

This method sould set the data for the report generator, which is handeled
over as argument.

=back

=head1 REGISTERING OWN CONTROL ROW CLASSES

See C<SL::Controller::Helper::ReportGenerator::ControlRow::ALL>. Here your
class should be included with C<use> and entered in the map C<%type_to_class>
with an appropiate name for it's type.


=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
