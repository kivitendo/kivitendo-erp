#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
######################################################################
#
# Stuff that can be used from other modules
#
######################################################################

use SL::Form;
use SL::Common;
use SL::MoreCommon;
use SL::ReportGenerator;

sub export_as_pdf {
  $lxdebug->enter_sub();

  if ($form->{report_generator_pdf_options_set}) {
    report_generator_do('PDF');
    $lxdebug->leave_sub();
    return;
  }

  my @form_values;
  map { push @form_values, { 'key' => $_, 'value' => $form->{$_} } } keys %{ $form };

  $form->{title} = $locale->text('PDF export -- options');
  $form->header();
  print $form->parse_html_template('report_generator/pdf_export_options',
                                   { 'HIDDEN'         => \@form_values,
                                     'default_margin' => $form->format_amount(\%myconfig, 1.5) });

  $lxdebug->leave_sub();
}

sub export_as_csv {
  $lxdebug->enter_sub();

  if ($form->{report_generator_csv_options_set}) {
    report_generator_do('CSV');
    $lxdebug->leave_sub();
    return;
  }

  my @form_values;
  map { push @form_values, { 'key' => $_, 'value' => $form->{$_} } } keys %{ $form };

  $form->{title} = $locale->text('CSV export -- options');
  $form->header();
  print $form->parse_html_template('report_generator/csv_export_options', { 'HIDDEN' => \@form_values });

  $lxdebug->leave_sub();
}

sub report_generator_do {
  $lxdebug->enter_sub();

  my $format  = shift;

  my $nextsub = $form->{report_generator_nextsub};
  if (!$nextsub) {
    $form->error($locale->text('report_generator_nextsub is not defined.'));
  }

  foreach my $key (split m/ +/, $form->{report_generator_variable_list}) {
    $form->{$key} = $form->{"report_generator_hidden_${key}"};
  }

  $form->{report_generator_output_format} = $format;

  delete @{$form}{map { "report_generator_$_" } qw(nextsub variable_list)};

  call_sub($nextsub);

  $lxdebug->leave_sub();
}

1;
