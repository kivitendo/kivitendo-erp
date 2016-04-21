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

use List::Util qw(max);

use SL::Form;
use SL::Common;
use SL::MoreCommon qw(restore_form save_form);
use SL::ReportGenerator;

use strict;

sub report_generator_set_default_sort {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  my $default_sortorder   = shift;
  my $default_sortdir     = shift;

  $form->{sort}         ||= $default_sortorder;
  $form->{sortdir}        = $default_sortdir unless (defined $form->{sortdir});
  $form->{sortdir}        = $form->{sortdir} ? 1 : 0;

  $main::lxdebug->leave_sub();
}


sub report_generator_export_as_pdf {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  if ($form->{report_generator_pdf_options_set}) {
    my $saved_form = save_form();

    report_generator_do('PDF');

    if ($form->{report_generator_printed}) {
      restore_form($saved_form);
      $form->{MESSAGE} = $locale->text('The list has been printed.');
      report_generator_do('HTML');
    }

    $main::lxdebug->leave_sub();
    return;
  }

  my @form_values = $form->flatten_variables(grep { ($_ ne 'login') && ($_ ne 'password') } keys %{ $form });

  $form->get_lists('printers' => 'ALL_PRINTERS');
  map { $_->{selected} = $myconfig{default_printer_id} == $_->{id} } @{ $form->{ALL_PRINTERS} };

  $form->{copies} = max $myconfig{copies} * 1, 1;

  my $allow_font_selection = 1;
  eval { require PDF::API2; };
  $allow_font_selection = 0 if ($@);

  $form->{title} = $locale->text('PDF export -- options');
  $form->header();
  print $form->parse_html_template('report_generator/pdf_export_options', { 'HIDDEN'               => \@form_values,
                                                                            'ALLOW_FONT_SELECTION' => $allow_font_selection, });

  $main::lxdebug->leave_sub();
}

sub report_generator_export_as_csv {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  if ($form->{report_generator_csv_options_set}) {
    report_generator_do('CSV');
    $main::lxdebug->leave_sub();
    return;
  }

  my @form_values = $form->flatten_variables(grep { ($_ ne 'login') && ($_ ne 'password') } keys %{ $form });

  $form->{title} = $locale->text('CSV export -- options');
  $form->header();
  print $form->parse_html_template('report_generator/csv_export_options', { 'HIDDEN' => \@form_values });

  $main::lxdebug->leave_sub();
}

sub report_generator_back {
  $main::lxdebug->enter_sub();

  report_generator_do('HTML');

  $main::lxdebug->leave_sub();
}

sub report_generator_do {
  $main::lxdebug->enter_sub();

  my $format  = shift;

  my $form     = $main::form;
  my $locale   = $main::locale;

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

  $main::lxdebug->leave_sub();
}

sub report_generator_dispatcher {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  my $nextsub = $form->{report_generator_dispatch_to};
  if (!$nextsub) {
    $form->error($locale->text('report_generator_dispatch_to is not defined.'));
  }

  delete $form->{report_generator_dispatch_to};

  call_sub($nextsub);

  $main::lxdebug->leave_sub();
}

1;
