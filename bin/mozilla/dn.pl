#=====================================================================
# LX-Office ERP
# Copyright (C) 2006
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (c) 1998-2002
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1335, USA.
#======================================================================
#
# Dunning process module
#
#======================================================================

use POSIX qw(strftime);

use SL::IS;
use SL::DN;
use SL::DB::Department;
use SL::DB::Dunning;
use SL::Helper::Flash qw(flash);
use SL::Locale::String qw(t8);
use SL::ReportGenerator;

require "bin/mozilla/common.pl";
require "bin/mozilla/reportgenerator.pl";
require "bin/mozilla/io.pl";

use strict;

1;

sub edit_config {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('config');

  DN->get_config(\%myconfig, \%$form);
  $form->get_lists('charts' => { 'key'       => 'ALL_CHARTS',
                                 'transdate' => 'current_date' });

  $form->{SELECT_AR_AMOUNT} = [];
  $form->{SELECT_AR}        = [];

  foreach my $chart (@{ $form->{ALL_CHARTS} }) {
    $chart->{LINKS} = { map { $_, 1 } split m/:/, $chart->{link} };

    if ($chart->{LINKS}->{AR}) {
      $chart->{AR_selected} = "selected" if $chart->{id} == $form->{AR};
      push @{ $form->{SELECT_AR} }, $chart;
    }

    if ($chart->{LINKS}->{AR_amount}) {
      $chart->{AR_amount_fee_selected}      = "selected" if $chart->{id} == $form->{AR_amount_fee};
      $chart->{AR_amount_interest_selected} = "selected" if $chart->{id} == $form->{AR_amount_interest};
      push @{ $form->{SELECT_AR_AMOUNT} }, $chart;
    }
  }

  $form->{title}      = $locale->text('Edit Dunning Process Config');
  $form->{callback} ||= build_std_url("action=edit_config");

  setup_dn_edit_config_action_bar();

  $form->header();
  print $form->parse_html_template("dunning/edit_config");

  $main::lxdebug->leave_sub();
}

sub add {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('dunning_edit');

  DN->get_config(\%myconfig, \%$form);

  $form->get_lists("departments" => "ALL_DEPARTMENTS");

  $form->{SHOW_DUNNING_LEVEL_SELECTION} = $form->{DUNNING}         && scalar @{ $form->{DUNNING} };
  $form->{SHOW_DEPARTMENT_SELECTION}    = $form->{ALL_DEPARTMENTS} && scalar @{ $form->{ALL_DEPARTMENTS} || [] };

  $form->{title}    = $locale->text('Start Dunning Process');

  setup_dn_add_action_bar();
  $form->header();

  print $form->parse_html_template("dunning/add");

  $main::lxdebug->leave_sub();
}

sub show_invoices {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('dunning_edit');

  DN->get_invoices(\%myconfig, \%$form);
  $form->{title} = $locale->text('Start Dunning Process');

  foreach my $row (@{ $form->{DUNNINGS} }) {
    $row->{DUNNING_CONFIG} = [ map +{ %{ $_ } }, @{ $form->{DUNNING_CONFIG} } ];

    if ($row->{next_dunning_config_id}) {
      map { $_->{SELECTED} = $_->{id} == $row->{next_dunning_config_id} } @{ $row->{DUNNING_CONFIG } };
    }
    map { $row->{$_} = $form->format_amount(\%myconfig, $row->{$_} * 1, 2) } qw(amount open_amount fee interest);

    if ($row->{'language_id'}) {
      $row->{language} = SL::DB::Manager::Language->find_by_or_create('id' => $row->{'language_id'})->{'description'};
    }
  }

  $form->get_lists('printers'  => 'printers',
                   'languages' => 'languages');

  $form->{type}           = 'dunning';
  $form->{rowcount}       = scalar @{ $form->{DUNNINGS} };
  $form->{callback}     ||= build_std_url("action=show_invoices", qw(customer invnumber ordnumber groupinvoices minamount dunning_level notes));

  $form->{PRINT_OPTIONS}  = print_options('inline'          => 1,
                                          'no_queue'        => 1,
                                          'no_postscript'   => 1,
                                          'no_html'         => 1,
                                          'no_opendocument' => 1,);

  setup_dn_show_invoices_action_bar();
  $form->header();
  print $form->parse_html_template("dunning/show_invoices");

  $main::lxdebug->leave_sub();
}

sub save {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('config');

  for my $i (1 .. $form->{rowcount}) {
    if ($form->{"dunning_description_$i"} ne "") {
      $form->isblank("dunning_level_$i", $locale->text('Dunning Level missing in row '). $i);
      $form->isblank("dunning_description_$i", $locale->text('Dunning Description missing in row '). $i);
      $form->isblank("terms_$i", $locale->text('Terms missing in row '). $i);
      $form->isblank("payment_terms_$i", $locale->text('Payment Terms missing in row '). $i);
    }
  }

  DN->save_config(\%myconfig, \%$form);
  # saving the history
  if(!exists $form->{addition} && $form->{id} ne "") {
    $form->{snumbers} = qq|dunning_id_| . $form->{"dunning_id"};
    $form->{addition} = "SAVED FOR DUNNING";
    $form->save_history;
  }
  # /saving the history
  $form->redirect($locale->text('Dunning Process Config saved!'));

  $main::lxdebug->leave_sub();
}

sub save_dunning {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('dunning_edit');

  my $active=1;
  my @rows = ();
  undef($form->{DUNNING_PDFS});

  my $saved_language_id = $form->{language_id};

  if ($form->{groupinvoices} || $form->{l_include_credit_notes}) {
    my %dunnings_for;

    for my $i (1 .. $form->{rowcount}) {
      next unless ($form->{"active_$i"});

      $dunnings_for{$form->{"customer_id_$i"}} ||= {};
      my $dunning_levels = $dunnings_for{$form->{"customer_id_$i"}};

      $dunning_levels->{$form->{"next_dunning_config_id_$i"}} ||= [];
      my $level = $dunning_levels->{$form->{"next_dunning_config_id_$i"}};

      push @{ $level }, { "row"                    => $i,
                          "invoice_id"             => $form->{"inv_id_$i"},
                          "credit_note"            => $form->{"credit_note_$i"},
                          "customer_id"            => $form->{"customer_id_$i"},
                          "language_id"            => $form->{"language_id_$i"},
                          "next_dunning_config_id" => $form->{"next_dunning_config_id_$i"},
                          "print_invoice"          => $form->{"include_invoice_$i"},
                          "email"                  => $form->{"email_$i"}, };
    }

    foreach my $levels (values %dunnings_for) {
      foreach my $level (values %{ $levels }) {
        next unless scalar @{ $level };
        if (!$form->{force_lang}) {
          $form->{language_id} = @{$level}[0]->{language_id};
        }
        DN->save_dunning(\%myconfig, $form, $level);
      }
    }

  } else {
    for my $i (1 .. $form->{rowcount}) {
      next unless $form->{"active_$i"};

      my $level = [ { "row"                    => $i,
                      "invoice_id"             => $form->{"inv_id_$i"},
                      "customer_id"            => $form->{"customer_id_$i"},
                      "language_id"            => $form->{"language_id_$i"},
                      "next_dunning_config_id" => $form->{"next_dunning_config_id_$i"},
                      "print_invoice"          => $form->{"include_invoice_$i"},
                      "email"                  => $form->{"email_$i"}, } ];
      if (!$form->{force_lang}) {
        $form->{language_id} = @{$level}[0]->{language_id};
      }
      DN->save_dunning(\%myconfig, $form, $level);
    }
  }

  $form->{language_id} = $saved_language_id;

  if (scalar @{ $form->{DUNNING_PDFS} }) {
    $form->{dunning_id} = strftime("%Y%m%d", localtime time) if scalar @{ $form->{DUNNING_PDFS}} > 1;
    DN->melt_pdfs(\%myconfig, $form, $form->{copies});
  }

  # saving the history
  if(!exists $form->{addition} && $form->{id} ne "") {
    $form->{snumbers} = qq|dunning_id_| . $form->{"dunning_id"};
    $form->{addition} = "DUNNING STARTED";
    $form->save_history;
  }
  # /saving the history

  if ($form->{media} eq 'printer') {
    delete $form->{callback};
    $form->redirect($locale->text('Dunning Process started for selected invoices!'));
  }

  $main::lxdebug->leave_sub();
}

sub set_email {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  $main::auth->assert('dunning_edit');

  $form->{"title"} = $locale->text("Set eMail text");
  $form->header(no_layout => 1);
  print($form->parse_html_template("dunning/set_email"));

  $main::lxdebug->leave_sub();
}

sub search {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('dunning_edit');

  $form->get_lists("customers"   => "ALL_CUSTOMERS",
                   "departments" => "ALL_DEPARTMENTS");
  $form->{ALL_EMPLOYEES} = SL::DB::Manager::Employee->get_all_sorted(query => [ deleted => 0 ]);

  DN->get_config(\%myconfig, \%$form);

  $form->{SHOW_DUNNING_LEVELS}   = scalar @{ $form->{DUNNING} };

  $form->{title}    = $locale->text('Dunnings');

  setup_dn_search_action_bar();
  $form->header();

  print $form->parse_html_template("dunning/search");

  $main::lxdebug->leave_sub();

}

sub show_dunning {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;
  my $cgi      = $::request->{cgi};

  $main::auth->assert('dunning_edit');

  my @filter_field_list = qw(customer_id customer dunning_level department_id invnumber ordnumber
                             transdatefrom transdateto dunningfrom dunningto notes showold l_salesman salesman_id);

  report_generator_set_default_sort('customername', 1);

  DN->get_dunning(\%myconfig, \%$form);

  if (!$form->{callback}) {
    $form->{callback} = build_std_url("action=show_dunning", @filter_field_list);
  }

  $form->get_lists('printers'  => 'printers',
                   'languages' => 'languages');

  $form->{type}          = 'dunning';
  $form->{PRINT_OPTIONS} = print_options('inline'          => 1,
                                         'no_queue'        => 1,
                                         'no_postscript'   => 1,
                                         'no_html'         => 1,
                                         'no_opendocument' => 1,);
  $form->{title}         = $locale->text('Dunning overview');

  my $report = SL::ReportGenerator->new(\%myconfig, $form);

  $report->set_options('std_column_visibility' => 1,
                       'title'                 => $form->{title});
  $report->set_export_options('show_dunning', @filter_field_list, qw(sort sortdir));

  my %column_defs         =  (
    'checkbox'            => { 'text' => '', 'visible' => 'HTML' },
    'dunning_description' => { 'text' => $locale->text('Dunning Level') },
    'customername'        => { 'text' => $locale->text('Customername') },
    'departmentname'      => { 'text' => $locale->text('Department') },
    'language'            => { 'text' => $locale->text('Language') },
    'invnumber'           => { 'text' => $locale->text('Invnumber') },
    'transdate'           => { 'text' => $locale->text('Invdate') },
    'duedate'             => { 'text' => $locale->text('Invoice Duedate') },
    'amount'              => { 'text' => $locale->text('Amount') },
    'dunning_date'        => { 'text' => $locale->text('Dunning Date') },
    'dunning_duedate'     => { 'text' => $locale->text('Dunning Duedate') },
    'fee'                 => { 'text' => $locale->text('Total Fees') },
    'interest'            => { 'text' => $locale->text('Interest') },
    'salesman'            => { 'text' => $locale->text('Salesperson'), 'visible' => $form->{l_salesman} ? 1 : 0 },
  );

  $report->set_columns(%column_defs);
  $report->set_column_order(qw(checkbox dunning_description customername language invnumber transdate
                               duedate amount dunning_date dunning_duedate fee interest salesman));
  $report->set_sort_indicator($form->{sort}, $form->{sortdir});

  my $edit_url  = sub { build_std_url('script=' . ($_[0]->{invoice} ? 'is' : 'ar') . '.pl', 'action=edit', 'callback') . '&id=' . $::form->escape($_[0]->{id}) };
  my $print_url = sub { build_std_url('action=print_dunning', 'format=pdf', 'media=screen', 'dunning_id='.$_[0]->{dunning_id}, 'language_id=' . $_[0]->{language_id}) };
  my $sort_url  = build_std_url('action=show_dunning', grep { $form->{$_} } @filter_field_list);

  foreach my $name (qw(dunning_description customername invnumber transdate duedate dunning_date dunning_duedate salesman)) {
    my $sortdir                 = $form->{sort} eq $name ? 1 - $form->{sortdir} : $form->{sortdir};
    $column_defs{$name}->{link} = $sort_url . "&sort=$name&sortdir=$sortdir";
  }

  my %alignment = map { $_ => 'right' } qw(transdate duedate amount dunning_date dunning_duedate fee interest salesman);

  my ($current_dunning_rows, $previous_dunning_id, $first_row_for_dunning);

  $current_dunning_rows  = [];
  $first_row_for_dunning = 1;
  $form->{rowcount}      = scalar @{ $form->{DUNNINGS} };

  my $i = 0;

  foreach my $ref (@{ $form->{DUNNINGS} }) {
    $i++;

    if ($previous_dunning_id != $ref->{dunning_id}) {
      $report->add_data($current_dunning_rows) if (scalar @{ $current_dunning_rows });
      $current_dunning_rows  = [];
      $first_row_for_dunning = 1;
    }

    if ($ref->{'language_id'}) {
      $ref->{language} = SL::DB::Manager::Language->find_by('id' => $ref->{'language_id'})->{'description'};
    }

    my $row = { };
    foreach my $column (keys %{ $ref }) {
      $row->{$column} = {
        'data'  => $first_row_for_dunning || (($column ne 'dunning_description') && ($column ne 'customername')) ? $ref->{$column} : '',

        'align' => $alignment{$column},

        'link'  => (  $column eq 'invnumber'           ? $edit_url->($ref)
                    : $column eq 'dunning_description' ? $print_url->($ref)
                    :                                    ''),
      };
    }

    $row->{checkbox} = !$first_row_for_dunning ? { } : {
      'raw_data' =>   $cgi->hidden('-name' => "dunning_id_$i", '-value' => $ref->{dunning_id})
                    . $cgi->checkbox('-name' => "selected_$i", '-value' => 1, '-label' => ''),
      'valign'   => 'center',
      'align'    => 'center',
    };

    if ($first_row_for_dunning) {
      $row->{language} = {'raw_data' => $cgi->hidden('-name' => "language_id_$i", '-value' => $ref->{language_id})
                                        . " $ref->{language}" };
    } else {
      $row->{language} = { };
    }

    push @{ $current_dunning_rows }, $row;

    $previous_dunning_id   = $ref->{dunning_id};
    $first_row_for_dunning = 0;
  }

  $report->add_data($current_dunning_rows) if (scalar @{ $current_dunning_rows });

  $report->set_options('raw_top_info_text'    => $form->parse_html_template('dunning/show_dunning_top'),
                       'raw_bottom_info_text' => $form->parse_html_template('dunning/show_dunning_bottom'),
                       'output_format'        => 'HTML',
                       'attachment_basename'  => $locale->text('dunning_list') . strftime('_%Y%m%d', localtime time),
    );

  $report->set_options_from_form();

  setup_dn_show_dunning_action_bar();
  $report->generate_with_headers();

  $main::lxdebug->leave_sub();

}

sub print_dunning {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  $main::auth->assert('dunning_edit');

  $form->{rowcount}     = 1;
  $form->{selected_1}   = 1;
  $form->{dunning_id_1} = $form->{dunning_id};
  $form->{language_id_1} = $form->{language_id};

  print_multiple();

  $main::lxdebug->leave_sub();
}

sub delete {
  $main::auth->assert('dunning_edit');

  my @dunning_ids = map { $::form->{"dunning_id_$_"} } grep { $::form->{"selected_$_"} } (1..$::form->{rowcount});

  if (!scalar @dunning_ids) {
    $::form->error($::locale->text('No dunnings have been selected for printing.'));
  }

  my $dunnings = SL::DB::Manager::Dunning->get_all(query => [ dunning_id => \@dunning_ids ]);

  SL::DB::Dunning->new->db->with_transaction(sub {
    for my $dunning (@$dunnings) {
      SL::DB::Manager::Invoice->find_by(id => $dunning->trans_id)->update_attributes(dunning_config_id => undef);
      $dunning->delete;
    }
  });

  flash('info', t8('#1 dunnings have been deleted', scalar @$dunnings));

  search();
}

sub print_multiple {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('dunning_edit');

  $form->{title} = $locale->text('Print dunnings');

  my @dunning_ids = map { $form->{"dunning_id_$_"} } grep { $form->{"selected_$_"} } (1..$form->{rowcount});
  my @language_ids = map { $form->{"language_id_$_"} } grep { $form->{"selected_$_"} } (1..$form->{rowcount});

  if (!scalar @dunning_ids) {
    $form->error($locale->text('No dunnings have been selected for printing.'));
  }

  $form->{DUNNING_PDFS} = [];

  my $saved_language_id = $form->{language_id};
  my $i = 0;
  foreach my $dunning_id (@dunning_ids) {
    if (!$form->{force_lang}) {
      $form->{language_id} = $language_ids[$i];
    }
    $form->{dunning_id} = $dunning_id;
    DN->print_invoice_for_fees(\%myconfig, $form, $dunning_id);
    DN->print_dunning(\%myconfig, $form, $dunning_id);
    $i++;
  }
  $form->{language_id} = $saved_language_id;

  if (scalar @{ $form->{DUNNING_PDFS} }) {
    $form->{dunning_id} = strftime("%Y%m%d", localtime time) if scalar @{ $form->{DUNNING_PDFS}} > 1;
    DN->melt_pdfs(\%myconfig, $form, $form->{copies});

    if ($form->{media} eq 'printer') {
      $form->header();
      $form->info($locale->text('The dunnings have been printed.'));
    }

  } else {
    $form->redirect($locale->text('Could not print dunning.'));
  }

  $main::lxdebug->leave_sub();
}

sub continue {
  call_sub($main::form->{nextsub});
}

sub dispatcher {
  foreach my $action (qw(delete print_multiple)) {
    if ($::form->{"action_${action}"}) {
      call_sub($action);
      return;
    }
  }

  $::form->error($::locale->text('No action defined.'));
}

sub setup_dn_add_action_bar {
  my %params = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Search'),
        submit    => [ '#form', { action => "show_invoices" } ],
        accesskey => 'enter',
      ],
    );
  }
}

sub setup_dn_show_invoices_action_bar {
  my %params = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Create'),
        submit    => [ '#form', { action => "save_dunning" } ],
        checks    => [ [ 'kivi.check_if_entries_selected', '[name^=active_]' ] ],
        accesskey => 'enter',
        only_once => 1,
      ],
    );
  }
}

sub setup_dn_search_action_bar {
  my %params = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Search'),
        submit    => [ '#form', { action => "show_dunning" } ],
        accesskey => 'enter',
      ],
    );
  }
}

sub setup_dn_show_dunning_action_bar {
  my %params = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Print'),
        submit    => [ '#form', { action => "print_multiple" } ],
        checks    => [ [ 'kivi.check_if_entries_selected', '[name^=selected_]' ] ],
        accesskey => 'enter',
      ],

      action => [
        t8('Delete'),
        submit  => [ '#form', { action => "delete" } ],
        checks  => [ [ 'kivi.check_if_entries_selected', '[name^=selected_]' ] ],
        confirm => $::locale->text('This resets the dunning process for the selected invoices. Posted dunning invoices will not be changed!'),
      ],
    );
  }
}

sub setup_dn_edit_config_action_bar {
  my %params = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Save'),
        submit    => [ '#form', { action => "save" } ],
        accesskey => 'enter',
      ],
    );
  }
}

# end of main
