#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
######################################################################
#
# Mixin for controllers to use ReportGenerator things
#
######################################################################

use strict;

use List::Util qw(max);

use SL::Form;
use SL::Common;
use SL::MoreCommon;
use SL::ReportGenerator;

use Exporter 'import';
our @EXPORT = qw(
  action_report_generator_export_as_pdf action_report_generator_export_as_csv
  action_report_generator_back report_generator_do
);

sub action_report_generator_export_as_pdf {
  my ($self) = @_;
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
  $::form->header;
  print $::form->parse_html_template('report_generator/pdf_export_options', {
    'HIDDEN'               => \@form_values,
    'ALLOW_FONT_SELECTION' => SL::ReportGenerator->check_for_pdf_api, });
}

sub action_report_generator_export_as_csv {
  my ($self) = @_;
  if ($::form->{report_generator_csv_options_set}) {
    $self->report_generator_do('CSV');
    return;
  }

  my @form_values = $::form->flatten_variables(grep { ($_ ne 'login') && ($_ ne 'password') } keys %{ $::form });

  $::form->{title} = $::locale->text('CSV export -- options');
  $::form->header;
  print $::form->parse_html_template('report_generator/csv_export_options', { 'HIDDEN' => \@form_values });
}

sub action_report_generator_back {
  $_[0]->report_generator_do('HTML');
}

sub report_generator_set_default_sort {
  my ($default_sortorder, $default_sortdir) = @_;

  $::form->{sort}         ||= $default_sortorder;
  $::form->{sortdir}        = $default_sortdir unless (defined $::form->{sortdir});
  $::form->{sortdir}        = $::form->{sortdir} ? 1 : 0;
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

1;
