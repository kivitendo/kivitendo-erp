#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
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
# Genereal Ledger
#
#======================================================================

use utf8;
use strict;

use POSIX qw(strftime);
use List::Util qw(first sum);

use SL::DB::ApGl;
use SL::DB::RecordTemplate;
use SL::DB::ReconciliationLink;
use SL::DB::BankTransactionAccTrans;
use SL::DB::Tax;
use SL::DB::ValidityToken;
use SL::DB::GLTransaction;
use SL::FU;
use SL::GL;
use SL::Helper::Flash qw(flash flash_later);
use SL::IS;
use SL::ReportGenerator;
use SL::DBUtils qw(selectrow_query selectall_hashref_query);
use SL::Webdav;
use SL::Locale::String qw(t8);
use SL::Helper::GlAttachments qw(count_gl_attachments);
use SL::Presenter::Tag;
use SL::Presenter::Chart;
require "bin/mozilla/common.pl";
require "bin/mozilla/reportgenerator.pl";

# this is for our long dates
# $locale->text('January')
# $locale->text('February')
# $locale->text('March')
# $locale->text('April')
# $locale->text('May ')
# $locale->text('June')
# $locale->text('July')
# $locale->text('August')
# $locale->text('September')
# $locale->text('October')
# $locale->text('November')
# $locale->text('December')

# this is for our short month
# $locale->text('Jan')
# $locale->text('Feb')
# $locale->text('Mar')
# $locale->text('Apr')
# $locale->text('May')
# $locale->text('Jun')
# $locale->text('Jul')
# $locale->text('Aug')
# $locale->text('Sep')
# $locale->text('Oct')
# $locale->text('Nov')
# $locale->text('Dec')

sub load_record_template {
  $::auth->assert('gl_transactions');

  # Load existing template and verify that its one for this module.
  my $template = SL::DB::RecordTemplate
    ->new(id => $::form->{id})
    ->load(
      with_object => [ qw(customer payment currency record_items record_items.chart) ],
    );

  die "invalid template type" unless $template->template_type eq 'gl_transaction';

  $template->substitute_variables;
  my $payment_suggestion =  $::form->{form_defaults}->{amount_1};

  # Clean the current $::form before rebuilding it from the template.
  my $form_defaults = delete $::form->{form_defaults};
  delete @{ $::form }{ grep { !m{^(?:script|login)$}i } keys %{ $::form } };

  my $dummy_form = {};
  GL->transaction(\%::myconfig, $dummy_form);

  # Fill $::form from the template.
  my $today                   = DateTime->today_local;
  $::form->{title}            = "Add";
  $::form->{transdate}        = $today->to_kivitendo;
  $::form->{duedate}          = $today->to_kivitendo;
  $::form->{rowcount}         = @{ $template->items };
  $::form->{paidaccounts}     = 1;
  $::form->{$_}               = $template->$_     for qw(department_id taxincluded ob_transaction cb_transaction reference description show_details transaction_description);
  $::form->{$_}               = $dummy_form->{$_} for qw(closedto revtrans previous_id previous_gldate);

  my $row = 0;
  foreach my $item (@{ $template->items }) {
    $row++;

    my $active_taxkey = $item->chart->get_active_taxkey;
    my $taxes         = SL::DB::Manager::Tax->get_all(
      where   => [ chart_categories => { like => '%' . $item->chart->category . '%' }],
      sort_by => 'taxkey, rate',
    );

    my $tax   = first { $item->tax_id          == $_->id } @{ $taxes };
    $tax    //= first { $active_taxkey->tax_id == $_->id } @{ $taxes };
    $tax    //= $taxes->[0];

    if (!$tax) {
      $row--;
      next;
    }

    $::form->{"accno_id_${row}"}          = $item->chart_id;
    $::form->{"previous_accno_id_${row}"} = $item->chart_id;
    $::form->{"debit_${row}"}             = $::form->format_amount(\%::myconfig, ($payment_suggestion ? $payment_suggestion : $item->amount1), 2) if $item->amount1 * 1;
    $::form->{"credit_${row}"}            = $::form->format_amount(\%::myconfig, ($payment_suggestion ? $payment_suggestion : $item->amount2), 2) if $item->amount2 * 1;
    $::form->{"taxchart_${row}"}          = $item->tax_id . '--' . $tax->rate;
    $::form->{"${_}_${row}"}              = $item->$_ for qw(source memo project_id);
  }

  $::form->{$_} = $form_defaults->{$_} for keys %{ $form_defaults // {} };

  flash('info', $::locale->text("The record template '#1' has been loaded.", $template->template_name));

  $::form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_GL_TRANSACTION_POST())->token;

  update(
    keep_rows_without_amount => 1,
    dont_add_new_row         => 1,
  );
}

sub save_record_template {
  $::auth->assert('gl_transactions');

  my $template = $::form->{record_template_id} ? SL::DB::RecordTemplate->new(id => $::form->{record_template_id})->load : SL::DB::RecordTemplate->new;
  my $js       = SL::ClientJS->new(controller => SL::Controller::Base->new);
  my $new_name = $template->template_name_to_use($::form->{record_template_new_template_name});
  $js->dialog->close('#record_template_dialog');


  # bank transactions need amounts for assignment
  my $can_save = 0;
  $can_save    = 1 if ($::form->{credit_1} > 0 && $::form->{debit_2} > 0 && $::form->{credit_2} == 0 && $::form->{debit_1} == 0);
  $can_save    = 1 if ($::form->{credit_2} > 0 && $::form->{debit_1} > 0 && $::form->{credit_1} == 0 && $::form->{debit_2} == 0);
  return $js->flash('error', t8('Can only save template if amounts,i.e. 1 for debit and credit are set.'))->render unless $can_save;

  my @items = grep {
    $_->{chart_id} && (($_->{tax_id} // '') ne '')
  } map {
    +{ chart_id   => $::form->{"accno_id_${_}"},
       amount1    => $::form->parse_amount(\%::myconfig, $::form->{"debit_${_}"}),
       amount2    => $::form->parse_amount(\%::myconfig, $::form->{"credit_${_}"}),
       tax_id     => (split m{--}, $::form->{"taxchart_${_}"})[0],
       project_id => $::form->{"project_id_${_}"} || undef,
       source     => $::form->{"source_${_}"},
       memo       => $::form->{"memo_${_}"},
     }
  } (1..($::form->{rowcount} || 1));

  $template->assign_attributes(
    template_type  => 'gl_transaction',
    template_name  => $new_name,

    currency_id             => $::instance_conf->get_currency_id,
    department_id           => $::form->{department_id}    || undef,
    project_id              => $::form->{globalproject_id} || undef,
    taxincluded             => $::form->{taxincluded}     ? 1 : 0,
    ob_transaction          => $::form->{ob_transaction}  ? 1 : 0,
    cb_transaction          => $::form->{cb_transaction}  ? 1 : 0,
    reference               => $::form->{reference},
    description             => $::form->{description},
    show_details            => $::form->{show_details},
    transaction_description => $::form->{transaction_description},

    items          => \@items,
  );

  eval {
    $template->save;
    1;
  } or do {
    return $js
      ->flash('error', $::locale->text("Saving the record template '#1' failed.", $new_name))
      ->render;
  };

  return $js
    ->flash('info', $::locale->text("The record template '#1' has been saved.", $new_name))
    ->render;
}

sub add {
  $main::lxdebug->enter_sub();

  $main::auth->assert('gl_transactions');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $form->{title} = "Add";

  $form->{callback} = "gl.pl?action=add" unless $form->{callback};

  # we use this only to set a default date
  # yep. aber er holt hier auch schon ALL_CHARTS. Aufwand / Nutzen? jb
  GL->transaction(\%myconfig, \%$form);

  $form->{rowcount}  = 2;

  $form->{debit}  = 0;
  $form->{credit} = 0;
  $form->{tax}    = 0;

  $::form->{ALL_DEPARTMENTS} = SL::DB::Manager::Department->get_all_sorted;

  $form->{show_details} = $myconfig{show_form_details} unless defined $form->{show_details};

  if (!$form->{form_validity_token}) {
    $form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_GL_TRANSACTION_POST())->token;
  }

  &display_form(1);
  $main::lxdebug->leave_sub();

}

sub add_from_email_journal {
  die "No 'email_journal_id' was given." unless ($::form->{email_journal_id});
  &add;
}

sub load_record_template_from_email_journal {
  die "No 'email_journal_id' was given." unless ($::form->{email_journal_id});
  &load_record_template;
}

sub edit_with_email_journal_workflow {
  my ($self) = @_;
  die "No 'email_journal_id' was given." unless ($::form->{email_journal_id});
  $::form->{workflow_email_journal_id}    = delete $::form->{email_journal_id};
  $::form->{workflow_email_attachment_id} = delete $::form->{email_attachment_id};
  $::form->{workflow_email_callback}      = delete $::form->{callback};

  &edit;
}

sub prepare_transaction {
  $main::lxdebug->enter_sub();

  $main::auth->assert('gl_transactions');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  GL->transaction(\%myconfig, \%$form);

  $form->{amount} = $form->format_amount(\%myconfig, $form->{amount}, 2);

  $::form->{ALL_DEPARTMENTS} = SL::DB::Manager::Department->get_all_sorted;

  my $i        = 1;
  my $tax      = 0;
  my $taxaccno = "";
  foreach my $ref (@{ $form->{GL} }) {
    my $j = $i - 1;
    if ($tax && ($ref->{accno} eq $taxaccno)) {
      $form->{"tax_$j"}      = abs($ref->{amount});
      $form->{"taxchart_$j"} = $ref->{id} . "--" . $ref->{taxrate};
      if ($form->{taxincluded}) {
        if ($ref->{amount} < 0) {
          $form->{"debit_$j"} += $form->{"tax_$j"};
        } else {
          $form->{"credit_$j"} += $form->{"tax_$j"};
        }
      }
      $form->{"project_id_$j"} = $ref->{project_id};

    } else {
      $form->{"accno_id_$i"} = $ref->{chart_id};
      for (qw(fx_transaction source memo)) { $form->{"${_}_$i"} = $ref->{$_} }
      if ($ref->{amount} < 0) {
        $form->{totaldebit} -= $ref->{amount};
        $form->{"debit_$i"} = $ref->{amount} * -1;
      } else {
        $form->{totalcredit} += $ref->{amount};
        $form->{"credit_$i"} = $ref->{amount};
      }
      $form->{"taxchart_$i"} = $ref->{id}."--0.00000";
      $form->{"project_id_$i"} = $ref->{project_id};
      $i++;
    }
    if ($ref->{taxaccno} && !$tax) {
      $taxaccno = $ref->{taxaccno};
      $tax      = 1;
    } else {
      $taxaccno = "";
      $tax      = 0;
    }
  }

  $form->{rowcount} = $i;
  $form->{locked}   =
    ($form->datetonum($form->{transdate}, \%myconfig) <=
     $form->datetonum($form->{closedto}, \%myconfig));

  $main::lxdebug->leave_sub();
}

sub edit {
  $main::lxdebug->enter_sub();

  $main::auth->assert('gl_transactions');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  prepare_transaction();

  $form->{title} = "Edit";

  $form->{show_details} = $myconfig{show_form_details} unless defined $form->{show_details};

  if ($form->{id} && $::instance_conf->get_webdav) {
    my $webdav = SL::Webdav->new(
      type     => 'general_ledger',
      number   => $form->{id},
    );
    my @all_objects = $webdav->get_all_objects;
    @{ $form->{WEBDAV} } = map { { name => $_->filename,
                                   type => t8('File'),
                                   link => File::Spec->catfile($_->full_filedescriptor),
                               } } @all_objects;
  }
  form_header();
  display_rows();
  form_footer();

  $main::lxdebug->leave_sub();
}


sub search {
  $::lxdebug->enter_sub;
  $::auth->assert('general_ledger | gl_transactions');

  $::form->get_lists(
    projects  => { key => "ALL_PROJECTS", all => 1 },
  );
  $::form->{ALL_EMPLOYEES} = SL::DB::Manager::Employee->get_all_sorted(query => [ deleted => 0 ]);
  $::form->{ALL_DEPARTMENTS} = SL::DB::Manager::Department->get_all_sorted;

  setup_gl_search_action_bar();

  $::form->{title} = t8('Journal');
  $::form->header;
  print $::form->parse_html_template('gl/search', {
    employee_label => sub { "$_[0]{id}--$_[0]{name}" },
  });

  $::lxdebug->leave_sub;
}

sub create_subtotal_row {
  $main::lxdebug->enter_sub();

  my ($totals, $columns, $column_alignment, $subtotal_columns, $class) = @_;

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  my $row = { map { $_ => { 'data' => '', 'class' => $class, 'align' => $column_alignment->{$_}, } } @{ $columns } };

  map { $row->{$_}->{data} = $form->format_amount(\%myconfig, $totals->{$_}, 2) } @{ $subtotal_columns };

  map { $totals->{$_} = 0 } @{ $subtotal_columns };

  $main::lxdebug->leave_sub();

  return $row;
}

sub generate_report {
  $main::lxdebug->enter_sub();

  $main::auth->assert('general_ledger | gl_transactions');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  # generate_report wird beim ersten Aufruf per Weiter-Knopf und POST mit der hidden Variablen sort mit Wert "datesort" (früher "transdate" als Defaultsortiervariable) übertragen

  # <form method=post action=gl.pl>
  # <input type=hidden name=sort value=datesort>    # form->{sort} setzen
  # <input type=hidden name=nextsub value=generate_report>

  # anhand von neuer Variable datesort wird jetzt $form->{sort} auf transdate oder gldate gesetzt
  # damit ist die Hidden Variable "sort" wahrscheinlich sogar überflüssig

  # ändert man die Sortierreihenfolge per Klick auf eine der Überschriften wird die Variable "sort" per GET übergeben, z.B. id,transdate, gldate, ...
  # gl.pl?action=generate_report&employee=18383--Jan%20B%c3%bcren&datesort=transdate&category=X&l_transdate=Y&l_gldate=Y&l_id=Y&l_reference=Y&l_description=Y&l_source=Y&l_debit=Y&l_credit=Y&sort=gldate&sortdir=0

  if ( $form->{sort} eq 'datesort' ) {   # sollte bei einem Post (Aufruf aus Suchmaske) immer wahr sein
      # je nachdem ob in Suchmaske "transdate" oder "gldate" ausgesucht wurde erstes Suchergebnis entsprechend sortieren
      $form->{sort} = $form->{datesort};
  };

  # was passiert hier?
  report_generator_set_default_sort("$form->{datesort}", 1);
#  report_generator_set_default_sort('transdate', 1);

  GL->all_transactions(\%myconfig, \%$form);

  my %acctype = ('A' => $locale->text('Asset'),
                 'C' => $locale->text('Contra'),
                 'L' => $locale->text('Liability'),
                 'Q' => $locale->text('Equity'),
                 'I' => $locale->text('Revenue'),
                 'E' => $locale->text('Expense'),);

  $form->{title} = $locale->text('Journal');
  if ($form->{category} ne 'X') {
    $form->{title} .= " : " . $locale->text($acctype{ $form->{category} });
  }

  $form->{landscape} = 1;

  my $ml = ($form->{ml} =~ /(A|E|Q)/) ? -1 : 1;

  my @columns = qw(
    transdate     gldate              id                         reference
    description   notes               transaction_description    source
    doccnt        debit               debit_accno
    credit        credit_accno        debit_tax                  debit_tax_accno
    credit_tax    credit_tax_accno    balance                    projectnumbers
    department    employee
  );

  # add employee here, so that variable is still known and passed in url when choosing a different sort order in resulting table
  my @hidden_variables = qw(accno source reference description notes project_id datefrom dateto employee_id datesort category l_subtotal department_id transaction_description);
  push @hidden_variables, map { "l_${_}" } @columns;

  my $employee = $form->{employee_id} ? SL::DB::Employee->new(id => $form->{employee_id})->load->name : '';

  my (@options, @date_options);
  push @options,      $locale->text('Account')                 . " : $form->{accno} $form->{account_description}" if ($form->{accno});
  push @options,      $locale->text('Source')                  . " : $form->{source}"                             if ($form->{source});
  push @options,      $locale->text('Reference')               . " : $form->{reference}"                          if ($form->{reference});
  push @options,      $locale->text('Description')             . " : $form->{description}"                        if ($form->{description});
  push @options,      $locale->text('Notes')                   . " : $form->{notes}"                              if ($form->{notes});
  push @options,      $locale->text('Transaction description') . " : $form->{transaction_description}"            if $form->{transaction_description};
  push @options,      $locale->text('Employee')                . " : $employee"                                   if $employee;
  my $datesorttext = $form->{datesort} eq 'transdate' ? $locale->text('Transdate') :  $locale->text('Gldate');
  push @date_options,      "$datesorttext"                              if ($form->{datesort} and ($form->{datefrom} or $form->{dateto}));
  push @date_options, $locale->text('From'), $locale->date(\%myconfig, $form->{datefrom}, 1)          if ($form->{datefrom});
  push @date_options, $locale->text('Bis'),  $locale->date(\%myconfig, $form->{dateto},   1)          if ($form->{dateto});
  push @options,      join(' ', @date_options)                                                        if (scalar @date_options);

  if ($form->{department_id}) {
    my $department = SL::DB::Manager::Department->find_by( id => $form->{department_id} );
    push @options, $locale->text('Department') . " : " . $department->description;
  }

  my $callback = build_std_url('action=generate_report', grep { $form->{$_} } @hidden_variables);

  $form->{l_credit_accno}     = 'Y';
  $form->{l_debit_accno}      = 'Y';
  $form->{l_credit_tax}       = 'Y';
  $form->{l_debit_tax}        = 'Y';
#  $form->{l_gldate}           = 'Y';  # Spalte mit gldate immer anzeigen
  $form->{l_credit_tax_accno} = 'Y';
  $form->{l_datesort} = 'Y';
  $form->{l_debit_tax_accno}  = 'Y';
  $form->{l_balance}          = $form->{accno} ? 'Y' : '';
  $form->{l_doccnt}           = $form->{l_source} ? 'Y' : '';

  my %column_defs = (
    'id'                      => { 'text' => $locale->text('ID'), },
    'transdate'               => { 'text' => $locale->text('Transdate'), },
    'gldate'                  => { 'text' => $locale->text('Gldate'), },
    'reference'               => { 'text' => $locale->text('Reference'), },
    'source'                  => { 'text' => $locale->text('Source'), },
    'doccnt'                  => { 'text' => $locale->text('Document Count'), },
    'description'             => { 'text' => $locale->text('Description'), },
    'notes'                   => { 'text' => $locale->text('Notes'), },
    'debit'                   => { 'text' => $locale->text('Debit'), },
    'debit_accno'             => { 'text' => $locale->text('Debit Account'), },
    'credit'                  => { 'text' => $locale->text('Credit'), },
    'credit_accno'            => { 'text' => $locale->text('Credit Account'), },
    'debit_tax'               => { 'text' => $locale->text('Debit Tax'), },
    'debit_tax_accno'         => { 'text' => $locale->text('Debit Tax Account'), },
    'credit_tax'              => { 'text' => $locale->text('Credit Tax'), },
    'credit_tax_accno'        => { 'text' => $locale->text('Credit Tax Account'), },
    'balance'                 => { 'text' => $locale->text('Balance'), },
    'projectnumbers'          => { 'text' => $locale->text('Project Numbers'), },
    'department'              => { 'text' => $locale->text('Department'), },
    'employee'                => { 'text' => $locale->text('Employee'), },
    'transaction_description' => { 'text' => $locale->text('Transaction description'), },
  );

  foreach my $name (qw(id transdate gldate reference description debit_accno credit_accno debit_tax_accno credit_tax_accno department transaction_description)) {
    my $sortname                = $name =~ m/accno/ ? 'accno' : $name;
    my $sortdir                 = $sortname eq $form->{sort} ? 1 - $form->{sortdir} : $form->{sortdir};
    $column_defs{$name}->{link} = $callback . "&sort=$sortname&sortdir=$sortdir";
  }

  map { $column_defs{$_}->{visible} = $form->{"l_${_}"} ? 1 : 0 } @columns;
  map { $column_defs{$_}->{visible} = 0 } qw(debit_accno credit_accno debit_tax_accno credit_tax_accno) if $form->{accno};

  my %column_alignment;
  map { $column_alignment{$_}     = 'right'  } qw(balance id debit credit debit_tax credit_tax balance);
  map { $column_alignment{$_}     = 'center' } qw(transdate gldate reference debit_accno credit_accno debit_tax_accno credit_tax_accno);
  map { $column_alignment{$_}     = 'left' } qw(description source notes);
  map { $column_defs{$_}->{align} = $column_alignment{$_} } keys %column_alignment;

  my $report = SL::ReportGenerator->new(\%myconfig, $form);

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);

  $form->{l_attachments} = 'Y';
  $report->set_export_options('generate_report', @hidden_variables, qw(sort sortdir l_attachments));

  $report->set_sort_indicator($form->{sort} eq 'accno' ? 'debit_accno' : $form->{sort}, $form->{sortdir});

  $report->set_options('top_info_text'        => join("\n", @options),
                       'output_format'        => 'HTML',
                       'title'                => $form->{title},
                       'attachment_basename'  => $locale->text('general_ledger_list') . strftime('_%Y%m%d', localtime time),
    );
  $report->set_options_from_form();
  $locale->set_numberformat_wo_thousands_separator(\%myconfig) if lc($report->{options}->{output_format}) eq 'csv';

  # add sort to callback
  $form->{callback} = "$callback&sort=" . E($form->{sort}) . "&sortdir=" . E($form->{sortdir});


  my @totals_columns = qw(debit credit debit_tax credit_tax);
  my %subtotals      = map { $_ => 0 } @totals_columns;
  my %totals         = map { $_ => 0 } @totals_columns;
  my $idx            = 0;

  foreach my $ref (@{ $form->{GL} }) {

    my %rows;

    foreach my $key (qw(debit credit debit_tax credit_tax)) {
      $rows{$key} = [];
      foreach my $idx (sort keys(%{ $ref->{$key} })) {
        my $value         = $ref->{$key}->{$idx};
        $subtotals{$key} += $value;
        $totals{$key}    += $value;
        if ($key =~ /debit.*/) {
          $ml = -1;
        } else {
          $ml = 1;
        }
        $form->{balance}  = $form->{balance} + $value * $ml;
        push @{ $rows{$key} }, $form->format_amount(\%myconfig, $value, 2);
      }
    }

    foreach my $key (qw(debit_accno credit_accno debit_tax_accno credit_tax_accno ac_transdate source)) {
      my $col = $key eq 'ac_transdate' ? 'transdate' : $key;
      $rows{$col} = [ map { $ref->{$key}->{$_} } sort keys(%{ $ref->{$key} }) ];
    }

    my $row = { };
    map { $row->{$_} = { 'data' => '', 'align' => $column_alignment{$_} } } @columns;

    if ( $form->{l_doccnt} ) {
      $row->{doccnt}->{data} = SL::Helper::GlAttachments->count_gl_pdf_attachments($ref->{id},$ref->{type});
    }

    my $sh = "";
    if ($form->{balance} < 0) {
      $sh = " S";
      $ml = -1;
    } elsif ($form->{balance} > 0) {
      $sh = " H";
      $ml = 1;
    }
    my $data = $form->format_amount(\%myconfig, ($form->{balance} * $ml), 2);
    $data .= $sh;

    $row->{balance}->{data}        = $data;
    $row->{projectnumbers}->{data} = join ", ", sort { lc($a) cmp lc($b) } keys %{ $ref->{projectnumbers} };

    map { $row->{$_}->{data} = $ref->{$_} } qw(id reference description notes gldate employee department transaction_description);

    map { $row->{$_}->{data} = \@{ $rows{$_} }; } qw(transdate debit credit debit_accno credit_accno debit_tax_accno credit_tax_accno source);

    foreach my $col (qw(debit_accno credit_accno debit_tax_accno credit_tax_accno)) {
      $row->{$col}->{link} = [ map { "${callback}&accno=" . E($_) } @{ $rows{$col} } ];
    }

    map { $row->{$_}->{data} = \@{ $rows{$_} } if ($ref->{"${_}_accno"} ne "") } qw(debit_tax credit_tax);

    $row->{reference}->{link} = build_std_url("script=$ref->{module}.pl", 'action=edit', 'id=' . E($ref->{id}), 'callback');

    my $row_set = [ $row ];

    if ( ($form->{l_subtotal} eq 'Y' && !$form->{report_generator_csv_options_for_import} )
        && (($idx == (scalar @{ $form->{GL} } - 1))
            || ($ref->{ $form->{sort} } ne $form->{GL}->[$idx + 1]->{ $form->{sort} }))) {
      push @{ $row_set }, create_subtotal_row(\%subtotals, \@columns, \%column_alignment, [ qw(debit credit) ], 'listsubtotal');
    }

    $report->add_data($row_set);

    $idx++;
  }

  # = 0 for balanced ledger
  my $balanced_ledger = $totals{debit} + $totals{debit_tax} - $totals{credit} - $totals{credit_tax};

  my $row = create_subtotal_row(\%totals, \@columns, \%column_alignment, [ qw(debit credit debit_tax credit_tax) ], 'listtotal');

  my $sh = "";
  if ($form->{balance} < 0) {
    $sh = " S";
    $ml = -1;
  } elsif ($form->{balance} > 0) {
    $sh = " H";
    $ml = 1;
  }
  my $data = $form->format_amount(\%myconfig, ($form->{balance} * $ml), 2);
  $data .= $sh;

  $row->{balance}->{data}        = $data;

  if ( !$form->{report_generator_csv_options_for_import} ) {
    $report->add_separator();
    $report->add_data($row);
  }

  my $raw_bottom_info_text;

  if (!$form->{accno} && (abs($balanced_ledger) >  0.001)) {
    $raw_bottom_info_text .=
        '<p><span class="unbalanced_ledger">'
      . $locale->text('Unbalanced Ledger')
      . ': '
      . $form->format_amount(\%myconfig, $balanced_ledger, 3)
      . '</span></p> ';
  }

  $raw_bottom_info_text .= $form->parse_html_template('gl/generate_report_bottom');

  $report->set_options('raw_bottom_info_text' => $raw_bottom_info_text);

  setup_gl_transactions_action_bar();

  $report->generate_with_headers();

  $main::lxdebug->leave_sub();
}

sub show_draft {
  $::form->{transdate} = DateTime->today_local->to_kivitendo if !$::form->{transdate};
  $::form->{gldate}    = $::form->{transdate} if !$::form->{gldate};
  $::form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_GL_TRANSACTION_POST())->token;
  update();
}

sub update {
  my %params = @_;

  $main::lxdebug->enter_sub();

  $main::auth->assert('gl_transactions');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $form->{oldtransdate} = $form->{transdate};

  my @a           = ();
  my $count       = 0;
  my $debittax    = 0;
  my $credittax   = 0;
  my $debitcount  = 0;
  my $creditcount = 0;
  my ($debitcredit, $amount);

  my $dbh = SL::DB->client->dbh;
  my ($notax_id) = selectrow_query($form, $dbh, "SELECT id FROM tax WHERE taxkey = 0 LIMIT 1", );
  my $zerotaxes  = selectall_hashref_query($form, $dbh, "SELECT id FROM tax WHERE rate = 0", );

  my @flds =
    qw(accno_id debit credit projectnumber fx_transaction source memo tax taxchart);

  for my $i (1 .. $form->{rowcount}) {
    $form->{"${_}_$i"} = $form->parse_amount(\%myconfig, $form->{"${_}_$i"}) for qw(debit credit tax);

    next if !$form->{"debit_$i"} && !$form->{"credit_$i"} && !$params{keep_rows_without_amount};

    push @a, {};
    $debitcredit = ($form->{"debit_$i"} == 0) ? "0" : "1";
    if ($debitcredit) {
      $debitcount++;
    } else {
      $creditcount++;
    }

    if (($debitcount >= 2) && ($creditcount == 2)) {
      $form->{"credit_$i"} = 0;
      $form->{"tax_$i"}    = 0;
      $creditcount--;
      $form->{creditlock} = 1;
    }
    if (($creditcount >= 2) && ($debitcount == 2)) {
      $form->{"debit_$i"} = 0;
      $form->{"tax_$i"}   = 0;
      $debitcount--;
      $form->{debitlock} = 1;
    }
    if (($creditcount == 1) && ($debitcount == 2)) {
      $form->{creditlock} = 1;
    }
    if (($creditcount == 2) && ($debitcount == 1)) {
      $form->{debitlock} = 1;
    }
    if ($debitcredit && $credittax) {
      $form->{"taxchart_$i"} = "$notax_id--0.00000";
    }
    if (!$debitcredit && $debittax) {
      $form->{"taxchart_$i"} = "$notax_id--0.00000";
    }
    $amount =
      ($form->{"debit_$i"} == 0)
      ? $form->{"credit_$i"}
      : $form->{"debit_$i"};
    my $j = $#a;
    if (($debitcredit && $credittax) || (!$debitcredit && $debittax)) {
      $form->{"taxchart_$i"} = "$notax_id--0.00000";
      $form->{"tax_$i"}      = 0;
    }
    my ($taxkey, $rate) = split(/--/, $form->{"taxchart_$i"});
    my $iswithouttax = grep { $_->{id} == $taxkey } @{ $zerotaxes };
    if (!$iswithouttax) {
      if ($debitcredit) {
        $debittax = 1;
      } else {
        $credittax = 1;
      }
    };
    my ($tmpnetamount,$tmpdiff);
    ($tmpnetamount,$form->{"tax_$i"},$tmpdiff) = $form->calculate_tax($amount,$rate,$form->{taxincluded} *= 1,2);

    for (@flds) { $a[$j]->{$_} = $form->{"${_}_$i"} }
    $count++;
  }

  for my $i (1 .. $count) {
    my $j = $i - 1;
    for (@flds) { $form->{"${_}_$i"} = $a[$j]->{$_} }
  }

  for my $i ($count + 1 .. $form->{rowcount}) {
    for (@flds) { delete $form->{"${_}_$i"} }
  }

  $form->{rowcount} = $count + ($params{dont_add_new_row} ? 0 : 1);

  display_form();
  $main::lxdebug->leave_sub();

}

sub display_form {
  my ($init) = @_;
  $main::lxdebug->enter_sub();

  $main::auth->assert('gl_transactions');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  &form_header($init);

  #   for $i (1 .. $form->{rowcount}) {
  #     $form->{totaldebit} += $form->parse_amount(\%myconfig, $form->{"debit_$i"});
  #     $form->{totalcredit} += $form->parse_amount(\%myconfig, $form->{"credit_$i"});
  #
  #     &form_row($i);
  #   }
  &display_rows($init);
  &form_footer;
  $main::lxdebug->leave_sub();

}

sub display_rows {
  my ($init) = @_;
  $main::lxdebug->enter_sub();

  $main::auth->assert('gl_transactions');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $cgi      = $::request->{cgi};

  my %balances = GL->get_chart_balances(map { $_->{id} } @{ $form->{ALL_CHARTS} });

  $form->{debit_1}     = 0 if !$form->{"debit_1"};
  $form->{totaldebit}  = 0;
  $form->{totalcredit} = 0;

  my %charts_by_id  = map { ($_->{id} => $_) } @{ $::form->{ALL_CHARTS} };
  my $default_chart = $::form->{ALL_CHARTS}[0];
  my $transdate     = $::form->{transdate} ? DateTime->from_kivitendo($::form->{transdate}) : DateTime->today_local;
  my $deliverydate  = $::form->{deliverydate} ? DateTime->from_kivitendo($::form->{deliverydate}) : undef;

  my ($source, $memo, $source_hidden, $memo_hidden);
  for my $i (1 .. $form->{rowcount}) {
    if ($form->{show_details}) {
      $source = qq|
      <td><input name="source_$i" value="$form->{"source_$i"}" size="16"></td>|;
      $memo = qq|
      <td><input name="memo_$i" value="$form->{"memo_$i"}" size="16"></td>|;
    } else {
      $source_hidden = qq|
      <input type="hidden" name="source_$i" value="$form->{"source_$i"}" size="16">|;
      $memo_hidden = qq|
      <input type="hidden" name="memo_$i" value="$form->{"memo_$i"}" size="16">|;
    }

    my %taxchart_labels = ();
    my @taxchart_values = ();

    my $accno_id = $::form->{"accno_id_$i"};
    my $chart    = $charts_by_id{$accno_id} // $default_chart;
    $accno_id    = $chart->{id};
    my ($first_taxchart, $default_taxchart, $taxchart_to_use);

    my $used_tax_id;
    if ( $form->{"taxchart_$i"} ) {
      ($used_tax_id) = split(/--/, $form->{"taxchart_$i"});
    }

    my $taxdate = $deliverydate ? $deliverydate : $transdate;
    foreach my $item ( GL->get_active_taxes_for_chart($accno_id, $taxdate, $used_tax_id) ) {
      my $key             = $item->id . "--" . $item->rate;
      $first_taxchart   //= $item;
      $default_taxchart   = $item if $item->{is_default};
      $taxchart_to_use    = $item if $key eq $form->{"taxchart_$i"};

      push(@taxchart_values, $key);
      $taxchart_labels{$key} = $item->taxkey . " - " . $item->taxdescription . " " . $item->rate * 100 . ' %';
    }

    $taxchart_to_use    //= $default_taxchart // $first_taxchart;
    my $selected_taxchart = $taxchart_to_use->id . '--' . $taxchart_to_use->rate;

    my $accno = qq|<td>| .
      SL::Presenter::Chart::picker("accno_id_$i", $accno_id, style => "width: 300px") .
      SL::Presenter::Tag::hidden_tag("previous_accno_id_$i", $accno_id)
      . qq|</td>|;
    my $tax_ddbox = qq|<td>| .
      NTI($cgi->popup_menu('-name' => "taxchart_$i",
            '-id' => "taxchart_$i",
            '-style' => 'width:200px',
            '-values' => \@taxchart_values,
            '-labels' => \%taxchart_labels,
            '-default' => $selected_taxchart))
      . qq|</td>|;

    my ($fx_transaction, $checked);
    if ($init) {
      if ($form->{transfer}) {
        $fx_transaction = qq|
        <td><input name="fx_transaction_$i" class=checkbox type=checkbox value=1></td>
    |;
      }

    } else {
      if ($form->{"debit_$i"} != 0) {
        $form->{totaldebit} += $form->{"debit_$i"};
        if (!$form->{taxincluded}) {
          $form->{totaldebit} += $form->{"tax_$i"};
        }
      } else {
        $form->{totalcredit} += $form->{"credit_$i"};
        if (!$form->{taxincluded}) {
          $form->{totalcredit} += $form->{"tax_$i"};
        }
      }

      for (qw(debit credit tax)) {
        $form->{"${_}_$i"} =
          ($form->{"${_}_$i"})
          ? $form->format_amount(\%myconfig, $form->{"${_}_$i"}, 2)
          : "";
      }

      if ($i < $form->{rowcount}) {
        if ($form->{transfer}) {
          $checked = ($form->{"fx_transaction_$i"}) ? "1" : "";
          my $x = ($checked) ? "x" : "";
          $fx_transaction = qq|
      <td><input type=hidden name="fx_transaction_$i" value="$checked">$x</td>
    |;
        }
        $form->hide_form("accno_$i");

      } else {
        if ($form->{transfer}) {
          $fx_transaction = qq|
      <td><input name="fx_transaction_$i" class=checkbox type=checkbox value=1></td>
    |;
        }
      }
    }
    my $debitreadonly  = "";
    my $creditreadonly = "";
    if ($i == $form->{rowcount}) {
      if ($form->{debitlock}) {
        $debitreadonly = "readonly";
      } elsif ($form->{creditlock}) {
        $creditreadonly = "readonly";
      }
    }

    my $projectnumber = SL::Presenter::Project::picker("project_id_$i", $form->{"project_id_$i"});
    my $projectnumber_hidden = SL::Presenter::Tag::hidden_tag("project_id_$i", $form->{"project_id_$i"});

    my $copy2credit = $i == 1 ? 'onkeyup="copy_debit_to_credit()"' : '';
    my $balance     = $form->format_amount(\%::myconfig, $balances{$accno_id} // 0, 2, 'DRCR');

    # if we have a bt_chart_id we disallow changing the amount of the bank account
    if ($form->{bt_chart_id}) {
      $debitreadonly = $creditreadonly = "readonly" if ($form->{"accno_id_$i"} eq $form->{bt_chart_id});
      $copy2credit   = '' if $i == 1;   # and disallow copy2credit
    }

    print qq|<tr valign=top>
    $accno
    <td id="chart_balance_$i" align="right">${balance}</td>
    $fx_transaction
    <td><input name="debit_$i" size="8" value="$form->{"debit_$i"}" accesskey=$i $copy2credit $debitreadonly></td>
    <td><input name="credit_$i" size=8 value="$form->{"credit_$i"}" $creditreadonly></td>
    <td><input type="hidden" name="tax_$i" value="$form->{"tax_$i"}">$form->{"tax_$i"}</td>
    $tax_ddbox|;

    if ($form->{show_details}) {
      print qq|
    $source
    $memo
    <td>$projectnumber</td>
|;
    } else {
    print qq|
    $source_hidden
    $memo_hidden
    $projectnumber_hidden
    |;
    }
    print qq|
  </tr>
|;
  }

  $form->hide_form(qw(rowcount selectaccno));

  $main::lxdebug->leave_sub();

}

sub _get_radieren {
  return ($::instance_conf->get_gl_changeable == 2) ? ($::form->current_date(\%::myconfig) eq $::form->{gldate}) : ($::instance_conf->get_gl_changeable == 1);
}

sub setup_gl_action_bar {
  my %params = @_;
  my $form   = $::form;
  my $change_never            = $::instance_conf->get_gl_changeable == 0;
  my $change_on_same_day_only = $::instance_conf->get_gl_changeable == 2 && ($form->current_date(\%::myconfig) ne $form->{gldate});
  my ($is_linked_bank_transaction, $is_linked_ap_transaction, $is_reconciled_bank_transaction);

  if ($form->{id} && SL::DB::Manager::BankTransactionAccTrans->find_by(gl_id => $form->{id})) {
    $is_linked_bank_transaction = 1;
  }
  if ($form->{id} && SL::DB::Manager::ApGl->find_by(gl_id => $form->{id})) {
    $is_linked_ap_transaction = 1;
  }
  # dont edit reconcilated bookings!
  if ($form->{id}) {
    my @acc_trans = map { $_->acc_trans_id } @{ SL::DB::Manager::AccTransaction->get_all( where => [ trans_id => $form->{id} ] ) };
    if (scalar @acc_trans && scalar @{ SL::DB::Manager::ReconciliationLink->get_all(where => [ acc_trans_id  => [ @acc_trans ] ]) }) {
      $is_reconciled_bank_transaction = 1;
    }
  }
  my $create_post_action = sub {
    # $_[0]: description
    # $_[1]: after_action
    action => [
      $_[0],
      submit   => [ '#form', { action => 'post', after_action => $_[1] } ],
      disabled => $form->{locked}                           ? t8('The billing period has already been locked.')
                : $form->{storno}                           ? t8('A canceled general ledger transaction cannot be posted.')
                : ($form->{id} && $change_never)            ? t8('Changing general ledger transaction has been disabled in the configuration.')
                : ($form->{id} && $change_on_same_day_only) ? t8('General ledger transactions can only be changed on the day they are posted.')
                : $is_linked_bank_transaction               ? t8('This transaction is linked with a bank transaction. Please undo and redo the bank transaction booking if needed.')
                : $is_linked_ap_transaction                 ? t8('This transaction is linked with a AP transaction. Please undo and redo the AP transaction booking if needed.')
                : $is_reconciled_bank_transaction           ? t8('This transaction is reconciled with a bank transaction. Please undo the reconciliation if needed.')
                : undef,
    ],
  };

  my %post_entry;
  if ($::instance_conf->get_gl_add_doc && $::instance_conf->get_doc_storage) {
    %post_entry = (combobox => [ $create_post_action->(t8('Post'), 'doc-tab'),
                                 $create_post_action->(t8('Post and new booking')) ]);
  } elsif ($::instance_conf->get_doc_storage) {
    %post_entry = (combobox => [ $create_post_action->(t8('Post')),
                                 $create_post_action->(t8('Post and upload document'), 'doc-tab') ]);
  } else {
    %post_entry = $create_post_action->(t8('Post'));
  }
  push @{$post_entry{combobox}}, $create_post_action->(t8('Post and Close'), 'callback');

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Update'),
        submit    => [ '#form', { action => 'update' } ],
        id        => 'update_button',
        accesskey => 'enter',
      ],
      %post_entry,
      combobox => [
        action => [ t8('Storno'),
          submit   => [ '#form', { action => 'storno' } ],
          confirm  => t8('Do you really want to cancel this general ledger transaction?'),
          disabled => !$form->{id}                ? t8('This general ledger transaction has not been posted yet.')
                    : $form->{storno}             ? t8('A canceled general ledger transaction cannot be canceled again.')
                    : $is_linked_bank_transaction ? t8('This transaction is linked with a bank transaction. Please undo and redo the bank transaction booking if needed.')
                    : $is_linked_ap_transaction   ? t8('This transaction is linked with a AP transaction. Please undo and redo the AP transaction booking if needed.')
                    : $is_reconciled_bank_transaction ? t8('This transaction is reconciled with a bank transaction. Please undo the reconciliation if needed.')
                    : undef,
        ],
        action => [ t8('Delete'),
          submit   => [ '#form', { action => 'delete' } ],
          confirm  => t8('Do you really want to delete this object?'),
          disabled => !$form->{id}             ? t8('This invoice has not been posted yet.')
                    : $form->{locked}          ? t8('The billing period has already been locked.')
                    : $change_never            ? t8('Changing invoices has been disabled in the configuration.')
                    : $change_on_same_day_only ? t8('Invoices can only be changed on the day they are posted.')
                    : $is_linked_bank_transaction ? t8('This transaction is linked with a bank transaction. Please undo and redo the bank transaction booking if needed.')
                    : $is_linked_ap_transaction   ? t8('This transaction is linked with a AP transaction. Please undo and redo the AP transaction booking if needed.')
                    : $is_reconciled_bank_transaction ? t8('This transaction is reconciled with a bank transaction. Please undo the reconciliation if needed.')
                    : $form->{storno}             ? t8('A canceled general ledger transaction cannot be deleted.')
                    : undef,
        ],
      ], # end of combobox "Storno"

      combobox => [
        action => [ t8('Workflow') ],
        action => [
          t8('Use As New'),
          submit   => [ '#form', { action => "use_as_new" } ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$form->{id} ? t8('This general ledger transaction has not been posted yet.')
                    : undef,
        ],
      ], # end of combobox "Workflow"

      combobox => [
        action => [ t8('more') ],
        action => [
          t8('History'),
          call     => [ 'set_history_window', $form->{id} * 1, 'glid' ],
          disabled => !$form->{id} ? t8('This invoice has not been posted yet.') : undef,
        ],
        action => [
          t8('Follow-Up'),
          call     => [ 'follow_up_window' ],
          disabled => !$form->{id} ? t8('This invoice has not been posted yet.') : undef,
        ],
        action => [
          t8('Record templates'),
          call => [ 'kivi.RecordTemplate.popup', 'gl_transaction' ],
        ],
        action => [
          t8('Drafts'),
          call     => [ 'kivi.Draft.popup', 'gl', 'unknown', $form->{draft_id}, $form->{draft_description} ],
          disabled => $form->{id}     ? t8('This invoice has already been posted.')
                    : $form->{locked} ? t8('The billing period has already been locked.')
                    : undef,
        ],
      ], # end of combobox "more"
    );
  }
}

sub setup_gl_search_action_bar {
  my %params = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Search'),
        submit    => [ '#form', { action => 'continue', nextsub => 'generate_report' } ],
        accesskey => 'enter',
      ],
    );
  }
}

sub setup_gl_transactions_action_bar {
  my %params = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      combobox => [
        action => [ $::locale->text('Create new') ],
        action => [
          $::locale->text('GL Transaction'),
          submit => [ '#create_new_form', { action => 'gl_transaction' } ],
        ],
        action => [
          $::locale->text('AR Transaction'),
          submit => [ '#create_new_form', { action => 'ar_transaction' } ],
        ],
        action => [
          $::locale->text('AP Transaction'),
          submit => [ '#create_new_form', { action => 'ap_transaction' } ],
        ],
        action => [
          $::locale->text('Sales Invoice'),
          submit => [ '#create_new_form', { action => 'sales_invoice'  } ],
        ],
        action => [
          $::locale->text('Vendor Invoice'),
          submit => [ '#create_new_form', { action => 'vendor_invoice' } ],
        ],
      ], # end of combobox "Create new"
    );
  }
}

sub form_header {
  $::lxdebug->enter_sub;
  $::auth->assert('gl_transactions');

  my ($init) = @_;

  $::request->layout->add_javascripts("autocomplete_chart.js", "autocomplete_project.js", "kivi.File.js", "kivi.GL.js", "kivi.RecordTemplate.js", "kivi.Validator.js", "show_history.js");

  my @old_project_ids     = grep { $_ } map{ $::form->{"project_id_$_"} } 1..$::form->{rowcount};
  my @conditions          = @old_project_ids ? (id => \@old_project_ids) : ();
  $::form->{ALL_PROJECTS} = SL::DB::Manager::Project->get_all_sorted(query => [ or => [ active => 1, @conditions ]]);

  $::form->get_lists(
    "charts"    => { "key" => "ALL_CHARTS", "transdate" => $::form->{transdate} },
  );

  # we cannot book on charttype header
  @{ $::form->{ALL_CHARTS} } = grep { $_->{charttype} ne 'H' }  @{ $::form->{ALL_CHARTS} };
  $::form->{ALL_DEPARTMENTS} = SL::DB::Manager::Department->get_all_sorted;

  my $title      = $::form->{title};
  $::form->{title} = $::locale->text("$title General Ledger Transaction");
  # $locale->text('Add General Ledger Transaction')
  # $locale->text('Edit General Ledger Transaction')

  map { $::form->{$_} =~ s/\"/&quot;/g }
    qw(chart taxchart);

  if ($init) {
    $::request->{layout}->focus("#reference");
    $::form->{taxincluded} = "1";
  } else {
    $::request->{layout}->focus("#accno_id_$::form->{rowcount}_name");
  }

  $::form->{previous_id}     ||= "--";
  $::form->{previous_gldate} ||= "--";

  setup_gl_action_bar();

  $::form->header;
  print $::form->parse_html_template('gl/form_header', {
    hide_title => $title,
    readonly   => $::form->{id} && ($::form->{locked} || !_get_radieren()),
  });

  $::lxdebug->leave_sub;

}

sub form_footer {
  $::lxdebug->enter_sub;
  $::auth->assert('gl_transactions');

  my ($follow_ups, $follow_ups_due);

  if ($::form->{id}) {
    $follow_ups     = FU->follow_ups('trans_id' => $::form->{id}, 'not_done' => 1);
    $follow_ups_due = sum map { $_->{due} * 1 } @{ $follow_ups || [] };
  }

  print $::form->parse_html_template('gl/form_footer', {
    radieren       => _get_radieren(),
    follow_ups     => $follow_ups,
    follow_ups_due => $follow_ups_due,
  });

  $::lxdebug->leave_sub;
}

sub delete {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  if (GL->delete_transaction(\%myconfig, \%$form)){
    # saving the history
      if(!exists $form->{addition} && $form->{id} ne "") {
        $form->{snumbers} = qq|gltransaction_| . $form->{id};
        $form->{addition} = "DELETED";
        $form->{what_done} = "gl_transaction";
        $form->save_history;
      }
    # /saving the history
    $form->redirect($locale->text('Transaction deleted!'))
  }
  $form->error($locale->text('Cannot delete transaction!'));
  $main::lxdebug->leave_sub();

}

sub post_transaction {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  # check if there is something in reference and date
  $form->isblank("reference",               $locale->text('Reference missing!'));
  $form->isblank("transdate",               $locale->text('Transaction Date missing!'));
  $form->isblank("description",             $locale->text('Description missing!'));
  $form->isblank("transaction_description", $locale->text('A transaction description is required.')) if $::instance_conf->get_require_transaction_description_ps;

  my $transdate = $form->datetonum($form->{transdate}, \%myconfig);
  my $closedto  = $form->datetonum($form->{closedto},  \%myconfig);

  my @a           = ();
  my $count       = 0;
  my $debittax    = 0;
  my $credittax   = 0;
  my $debitcount  = 0;
  my $creditcount = 0;
  my $debitcredit;
  my %split_safety = ();

  my $dbh = SL::DB->client->dbh;
  my ($notax_id) = selectrow_query($form, $dbh, "SELECT id FROM tax WHERE taxkey = 0 LIMIT 1", );
  my $zerotaxes  = selectall_hashref_query($form, $dbh, "SELECT id FROM tax WHERE rate = 0", );

  my @flds = qw(accno_id debit credit projectnumber fx_transaction source memo tax taxchart);

  for my $i (1 .. $form->{rowcount}) {
    next if $form->{"debit_$i"} eq "" && $form->{"credit_$i"} eq "";

    for (qw(debit credit tax)) {
      $form->{"${_}_$i"} = $form->parse_amount(\%myconfig, $form->{"${_}_$i"});
    }

    push @a, {};
    $debitcredit = ($form->{"debit_$i"} == 0) ? "0" : "1";

    $split_safety{   $form->{"debit_$i"}  <=> 0 }++;
    $split_safety{ - $form->{"credit_$i"} <=> 0 }++;

    if ($debitcredit) {
      $debitcount++;
    } else {
      $creditcount++;
    }

    if (($debitcount >= 2) && ($creditcount == 2)) {
      $form->{"credit_$i"} = 0;
      $form->{"tax_$i"}    = 0;
      $creditcount--;
      $form->{creditlock} = 1;
    }
    if (($creditcount >= 2) && ($debitcount == 2)) {
      $form->{"debit_$i"} = 0;
      $form->{"tax_$i"}   = 0;
      $debitcount--;
      $form->{debitlock} = 1;
    }
    if (($creditcount == 1) && ($debitcount == 2)) {
      $form->{creditlock} = 1;
    }
    if (($creditcount == 2) && ($debitcount == 1)) {
      $form->{debitlock} = 1;
    }
    if ($debitcredit && $credittax) {
      $form->{"taxchart_$i"} = "$notax_id--0.00000";
    }
    if (!$debitcredit && $debittax) {
      $form->{"taxchart_$i"} = "$notax_id--0.00000";
    }
    my $amount = ($form->{"debit_$i"} == 0)
            ? $form->{"credit_$i"}
            : $form->{"debit_$i"};
    my $j = $#a;
    if (($debitcredit && $credittax) || (!$debitcredit && $debittax)) {
      $form->{"taxchart_$i"} = "$notax_id--0.00000";
      $form->{"tax_$i"}      = 0;
    }
    my ($taxkey, $rate) = split(/--/, $form->{"taxchart_$i"});
    my $iswithouttax = grep { $_->{id} == $taxkey } @{ $zerotaxes };
    if (!$iswithouttax) {
      if ($debitcredit) {
        $debittax = 1;
      } else {
        $credittax = 1;
      }

      my ($tmpnetamount,$tmpdiff);
      ($tmpnetamount,$form->{"tax_$i"},$tmpdiff) = $form->calculate_tax($amount,$rate,$form->{taxincluded} *= 1,2);
      if ($debitcredit) {
        $form->{"debit_$i"} = $tmpnetamount;
      } else {
        $form->{"credit_$i"} = $tmpnetamount;
      }

    } else {
      $form->{"tax_$i"} = 0;
    }

    for (@flds) { $a[$j]->{$_} = $form->{"${_}_$i"} }
    $count++;
  }

  if ($split_safety{-1} > 1 && $split_safety{1} > 1) {
    $::form->error($::locale->text("Split entry detected. The values you have entered will result in an entry with more than one position on both debit and credit. " .
                                   "Due to known problems involving accounting software kivitendo does not allow these."));
  }

  for my $i (1 .. $count) {
    my $j = $i - 1;
    for (@flds) { $form->{"${_}_$i"} = $a[$j]->{$_} }
  }

  for my $i ($count + 1 .. $form->{rowcount}) {
    for (@flds) { delete $form->{"${_}_$i"} }
  }

  my ($debit, $credit, $taxtotal);
  for my $i (1 .. $form->{rowcount}) {
    my $dr  = $form->{"debit_$i"};
    my $cr  = $form->{"credit_$i"};
    my $tax = $form->{"tax_$i"};
    if ($dr && $cr) {
      $form->error($locale->text('Cannot post transaction with a debit and credit entry for the same account!'));
    }
    $debit    += $dr + $tax if $dr;
    $credit   += $cr + $tax if $cr;
    $taxtotal += $tax if $form->{taxincluded}
  }

  $form->{taxincluded} = 0 if !$taxtotal;

  # this is just for the wise guys

  $form->error($locale->text('Cannot post transaction above the maximum future booking date!'))
    if ($form->date_max_future($form->{"transdate"}, \%myconfig));
  $form->error($locale->text('Cannot post transaction for a closed period!'))
    if ($form->date_closed($form->{"transdate"}, \%myconfig));
  if ($form->round_amount($debit, 2) != $form->round_amount($credit, 2)) {
    $form->error($locale->text('Out of balance transaction!'));
  }

  if ($form->round_amount($debit, 2) + $form->round_amount($credit, 2) == 0) {
    $form->error($locale->text('Empty transaction!'));
  }


  # start transaction (post + history + (optional) banktrans)
  SL::DB->client->with_transaction(sub {

    if ((my $errno = GL->post_transaction(\%myconfig, \%$form)) <= -1) {
      $errno *= -1;
      my @err;
      $err[1] = $locale->text('Cannot have a value in both Debit and Credit!');
      $err[2] = $locale->text('Debit and credit out of balance!');
      $err[3] = $locale->text('Cannot post a transaction without a value!');

      die $err[$errno];
    }
    # saving the history
    if(!exists $form->{addition} && $form->{id} ne "") {
      $form->{snumbers} = qq|gltransaction_| . $form->{id};
      $form->{addition} = "POSTED";
      $form->{what_done} = "gl transaction";
      $form->save_history;
    }

    # Case BankTransaction: update RecordLink and BankTransaction
    if ($form->{callback} =~ /BankTransaction/ && $form->{bt_id}) {
      # set invoice_amount - we only rely on bt_id in form, do all other stuff ui independent
      # die if we have a unlogic or NYI case and abort the whole transaction
      my ($bt, $chart_id, $payment);
      require SL::DB::Manager::BankTransaction;

      $bt = SL::DB::Manager::BankTransaction->find_by(id => $::form->{bt_id});
      die "No bank transaction found" unless $bt;

      $chart_id = SL::DB::Manager::BankAccount->find_by(id => $bt->local_bank_account_id)->chart_id;
      die "no chart id" unless $chart_id;

      $payment = SL::DB::Manager::AccTransaction->get_all(where => [ trans_id => $::form->{id},
                                                                     chart_link => { like => '%_paid%' },
                                                                     chart_id => $chart_id                  ]);
      die "guru meditation error: Can only assign amount to one bank account booking" if scalar @{ $payment } > 1;

      # credit/debit * -1 matches the sign for bt.amount and bt.invoice_amount

      die "Can only assign the full (partial) bank amount to a single general ledger booking: " . $bt->not_assigned_amount . " " .  ($payment->[0]->amount * -1)
        unless (abs($bt->not_assigned_amount - ($payment->[0]->amount * -1)) < 0.001);

      $bt->update_attributes(invoice_amount => $bt->invoice_amount + ($payment->[0]->amount * -1));

      # create record_link
      my %props = (
        from_table => 'bank_transactions',
        from_id    => $::form->{bt_id},
        to_table   => 'gl',
        to_id      => $::form->{id},
      );
      SL::DB::RecordLink->new(%props)->save;
      # and tighten holy acc_trans_id for this bank_transaction
      my  %props_acc = (
        acc_trans_id        => $payment->[0]->acc_trans_id,
        bank_transaction_id => $bt->id,
        gl_id               => $payment->[0]->trans_id,
      );
      my $bta = SL::DB::BankTransactionAccTrans->new(%props_acc);
      $bta->save;

    }
    1;
  }) or do { die SL::DB->client->error };

  $main::lxdebug->leave_sub();
}

sub post {
  $main::lxdebug->enter_sub();

  $main::auth->assert('gl_transactions');

  my $form     = $main::form;
  my $locale   = $main::locale;

  if ($::myconfig{mandatory_departments} && !$form->{department_id}) {
    $form->error($locale->text('You have to specify a department.'));
  }

  $form->{title}  = $locale->text("$form->{title} General Ledger Transaction");
  $form->{storno} = 0;

  post_transaction();

  if ($::instance_conf->get_webdav) {
    SL::Webdav->new(type     => 'general_ledger',
                    number   => $form->{id},
                   )->webdav_path;
  }

  if ($form->{email_journal_id} && $form->{id} ne "") {
    my $ar_transaction = SL::DB::GLTransaction->new(id => $form->{id})->load;
    my $email_journal = SL::DB::EmailJournal->new(
      id => delete $form->{email_journal_id}
    )->load;
    $email_journal->link_to_record_with_attachment($ar_transaction, delete $::form->{email_attachment_id});
  }

  my $msg = $::locale->text("General ledger transaction '#1' posted (ID: #2)", $form->{reference}, $form->{id});
  if ($form->{callback} =~ /BankTransaction/ && $form->{bt_id}) {
    SL::Helper::Flash::flash_later('info', $msg) if $msg;
    print $::form->redirect_header($form->{callback});
  } elsif ('doc-tab' eq $form->{after_action}) {
    # Redirect with callback containing a fragment does not work (by now)
    # because the callback info is stored in the session an parsing the
    # callback parameters does not support fragments (see SL::Form::redirect).
    # So use flash_later for the message and redirect_headers for redirecting.
    my $add_doc_url = build_std_url("script=gl.pl", 'action=edit', 'id=' . E($form->{id}), 'fragment=ui-tabs-docs');
    SL::Helper::Flash::flash_later('info', $msg);
    print $form->redirect_header($add_doc_url);
    $::dispatcher->end_request;
  } elsif ('callback' eq $form->{after_action}) {
    my $callback = $form->{callback}
      || "controller.pl?action=LoginScreen/user_login";
    SL::Helper::Flash::flash_later('info', $msg);
    print $form->redirect_header($callback);
    $::dispatcher->end_request;
  } else {
    $form->{callback} = build_std_url("action=add", "show_details");
    $form->redirect($msg);
  }

  $main::lxdebug->leave_sub();
}

sub storno {
  $main::lxdebug->enter_sub();

  $main::auth->assert('gl_transactions');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  # don't cancel cancelled transactions
  if (IS->has_storno(\%myconfig, $form, 'gl')) {
    $form->{title} = $locale->text("Cancel Accounts Receivables Transaction");
    $form->error($locale->text("Transaction has already been cancelled!"));
  }

  GL->storno($form, \%myconfig, $form->{id});

  # saving the history
  if(!exists $form->{addition} && $form->{id} ne "") {
    $form->{snumbers} = qq|gltransaction_| . $form->{id};
    $form->{addition} = "STORNO";
    $form->{what_done} = "gl_transaction";
    $form->save_history;
  }
  # /saving the history

  $form->redirect(sprintf $locale->text("Transaction %d cancelled."), $form->{storno_id});

  $main::lxdebug->leave_sub();
}

sub use_as_new {
  $::auth->assert('gl_transactions');

  $::form->{email_journal_id}    = delete $::form->{workflow_email_journal_id};
  $::form->{email_attachment_id} = delete $::form->{workflow_email_attachment_id};
  $::form->{callback}            = delete $::form->{workflow_email_callback};

  delete $::form->{$_} for qw(id gldate tax_point deliverydate storno);

  $::form->{title}     = "Add";
  $::form->{transdate} = DateTime->today_local->to_kivitendo;

  $::form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_GL_TRANSACTION_POST())->token;

  update();
}

sub continue {
  call_sub($main::form->{nextsub});
}

sub get_tax_dropdown {
  my $transdate    = $::form->{transdate}    ? DateTime->from_kivitendo($::form->{transdate}) : DateTime->today_local;
  my $deliverydate = $::form->{deliverydate} ? DateTime->from_kivitendo($::form->{deliverydate}) : undef;
  my @tax_accounts = GL->get_active_taxes_for_chart($::form->{accno_id}, $deliverydate // $transdate);
  my $html         = $::form->parse_html_template("gl/update_tax_accounts", { TAX_ACCOUNTS => \@tax_accounts });

  print $::form->ajax_response_header, $html;
}

sub get_chart_balance {
  my %balances = GL->get_chart_balances($::form->{accno_id});
  my $balance  = $::form->format_amount(\%::myconfig, $balances{ $::form->{accno_id} }, 2, 'DRCR');

  print $::form->ajax_response_header, $balance;
}

1;
