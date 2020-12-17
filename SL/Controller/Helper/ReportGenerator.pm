package SL::Controller::Helper::ReportGenerator;

use strict;

use Carp;
use List::Util qw(max);

use SL::Common;
use SL::MoreCommon;
use SL::ReportGenerator;

use Exporter 'import';
our @EXPORT = qw(
  action_report_generator_export_as_pdf action_report_generator_export_as_csv
  action_report_generator_back report_generator_do
  report_generator_list_objects
);

sub _setup_action_bar {
  my ($self, $type) = @_;

  my $key   = $::form->{CONTROLLER_DISPATCH} ? 'action'                             : 'report_generator_form.report_generator_dispatch_to';
  my $value = $::form->{CONTROLLER_DISPATCH} ? $::form->{CONTROLLER_DISPATCH} . "/" : '';

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        $type eq 'pdf' ? $::locale->text('PDF export') : $::locale->text('CSV export'),
        submit => [ '#report_generator_form', { $key => "${value}report_generator_export_as_${type}" } ],
      ],
      action => [
        $::locale->text('Back'),
        submit => [ '#report_generator_form', { $key => "${value}report_generator_back" } ],
      ],
    );
  }
}

sub action_report_generator_export_as_pdf {
  my ($self) = @_;

  delete $::form->{action_report_generator_export_as_pdf};

  if ($::form->{report_generator_pdf_options_set}) {
    my $saved_form = save_form();

    $self->report_generator_do('PDF');

    if ($::form->{report_generator_printed}) {
      restore_form($saved_form);
      $::form->{MESSAGE} = $::locale->text('The list has been printed.');
      $self->report_generator_do('HTML');
    }

    return;
  }

  my @form_values = $::form->flatten_variables(grep { ($_ ne 'login') && ($_ ne 'password') } keys %{ $::form });

  $::form->get_lists('printers' => 'ALL_PRINTERS');
  map { $_->{selected} = $::myconfig{default_printer_id} == $_->{id} } @{ $::form->{ALL_PRINTERS} };

  $::form->{copies} = max $::myconfig{copies} * 1, 1;
  $::form->{title} = $::locale->text('PDF export -- options');

  _setup_action_bar($self, 'pdf'); # Sub not exported, therefore don't call via object.

  $::form->header;
  print $::form->parse_html_template('report_generator/pdf_export_options', {
    'HIDDEN'               => \@form_values,
    'ALLOW_FONT_SELECTION' => SL::ReportGenerator->check_for_pdf_api, });
}

sub action_report_generator_export_as_csv {
  my ($self) = @_;

  delete $::form->{action_report_generator_export_as_csv};

  if ($::form->{report_generator_csv_options_set}) {
    $self->report_generator_do('CSV');
    return;
  }

  my @form_values = $::form->flatten_variables(grep { ($_ ne 'login') && ($_ ne 'password') } keys %{ $::form });

  $::form->{title} = $::locale->text('CSV export -- options');

  _setup_action_bar($self, 'csv'); # Sub not exported, therefore don't call via object.

  $::form->header;
  print $::form->parse_html_template('report_generator/csv_export_options', { 'HIDDEN' => \@form_values });
}

sub action_report_generator_back {
  $_[0]->report_generator_do('HTML');
}

sub report_generator_do {
  my ($self, $format)  = @_;

  my $nextsub = $::form->{report_generator_nextsub};
  if (!$nextsub) {
    $::form->error($::locale->text('report_generator_nextsub is not defined.'));
  }

  foreach my $key (split m/ +/, $::form->{report_generator_variable_list}) {
    $::form->{$key} = $::form->{"report_generator_hidden_${key}"};
  }

  $::form->{report_generator_output_format} = $format;

  delete @{$::form}{map { "report_generator_$_" } qw(nextsub variable_list)};

  $self->_run_action($nextsub);
}

sub report_generator_list_objects {
  my ($self, %params) = @_;

  croak "Parameter 'objects' must exist and be an array reference"                if                      ref($params{objects}) ne 'ARRAY';
  croak "Parameter 'report' must exist and be an instance of SL::ReportGenerator" if                      ref($params{report})  ne 'SL::ReportGenerator';
  croak "Parameter 'options', if exists, must be a hash reference"                if $params{options} && (ref($params{options}) ne 'HASH');
  $params{layout} //= 1;

  my $column_defs = $params{report}->{columns};
  my @columns     = $params{report}->get_visible_columns('HTML');

  for my $obj (@{ $params{objects} || [] }) {
    my %data = map {
      my $def = $column_defs->{$_};
      my $tmp;
      $tmp->{raw_data} = $def->{raw_data} ? $def->{raw_data}->($obj) : '';
      $tmp->{data}     = $def->{sub}      ? $def->{sub}->($obj)
                       : $obj->can($_)    ? $obj->$_
                       :                    $obj->{$_};
      $tmp->{link}     = $def->{obj_link} ? $def->{obj_link}->($obj) : '';
      $_ => $tmp;
    } @columns;

    $params{data_callback}->(\%data) if $params{data_callback};

    $params{report}->add_data(\%data);
  }

  my %options            = %{ $params{options} || {} };
  $options{action_bar} //= $params{action_bar} // 1;

  if ($params{layout}) {
    return $params{report}->generate_with_headers(%options);
  } else {
    my $html = $params{report}->generate_html_content(action_bar => 0, %options);
    $self->render(\$html , { layout => 0, process => 0 });
  }
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::Controller::Helper::ReportGenerator - Mixin for controllers that
use the L<SL::ReportGenerator> class

=head1 SYNOPSIS

  package SL::Controller::Unicorn;

  use SL::Controller::Helper::ReportGenerator;

  sub action_list {
    my ($self) = @_;

    # Set up the report generator instance. In this example this is
    # hidden in "prepare_report".
    my $report = $self->prepare_report;

    # Get objects from database.
    my $orders = SL::DB::Manager::Order->get_all(...);

    # Let report generator create the output.
    $self->report_generator_list_objects(
      report  => $report,
      objects => $orders,
    );
  }

=head1 FUNCTIONS

=over 4

=item C<action_report_generator_back>

This is the controller action that's called from the one of the report
generator's 'export options' pages when the user clicks on the 'back'
button.

It is never called from a controller manually and should just work
as-is.

=item C<action_report_generator_export_as_csv>

This is the controller action that's called from the generated report
when the user wants to export as CSV. First the CSV export options are
shown and afterwards the CSV file is generated and offered for
download.

It is never called from a controller manually and should just work
as-is.

=item C<action_report_generator_export_as_pdf>

This is the controller action that's called from the generated report
when the user wants to export as PDF. First the PDF export options are
shown and afterwards the PDF file is generated and offered for
download.

It is never called from a controller manually and should just work
as-is.

=item C<report_generator_do>

This is a common function that's called from
L<action_report_generator_back>,
L<action_report_generator_export_as_csv> and
L<action_report_generator_export_as_pdf>. It handles common options
and report generation after options have been set.

It is never called from a controller manually and should just work
as-is.

=item C<report_generator_list_objects %params>

Iterates over all objects, creates the actual rows of data, hands them
over to the report generator and lets the report generator create the
output.

C<%params> can contain the following values:

=over 2

=item C<report>

Mandatory. An instance of L<SL::ReportGenerator> that has been set up
already (column definitions, title, sort handling etc).

=item C<objects>

Mandatory. An array reference of RDBO models to output.

=item C<data_callback>

Optional. A callback handler (code reference) that gets called for
each row before it is passed to the report generator. The row passed
will be the handler's first and only argument (a hash reference). It's
the same hash reference that's passed to
L<SL::ReportGenrator/add_data>.

=item C<options>

An optional hash reference that's passed verbatim to the function
L<SL::ReportGenerator/generate_with_headers>.

=item C<action_bar>

If the buttons for exporting PDF and/or CSV variants are included in
the action bar. Otherwise they're rendered at the bottom of the page.

The value can be either a specific action bar instance or simply 1 in
which case the default action bar is used:
C<$::request-E<gt>layout-E<gt>get('actionbar')>.

=back

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
