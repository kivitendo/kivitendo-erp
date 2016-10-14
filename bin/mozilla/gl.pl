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
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#======================================================================
#
# Genereal Ledger
#
#======================================================================

use utf8;
use strict;

use POSIX qw(strftime);
use List::Util qw(sum);

use SL::FU;
use SL::GL;
use SL::IS;
use SL::PE;
use SL::ReportGenerator;
use SL::DBUtils qw(selectrow_query selectall_hashref_query);

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

  # departments
  $form->all_departments(\%myconfig);
  if (@{ $form->{all_departments} || [] }) {
    $form->{selectdepartment} = "<option>\n";

    map {
      $form->{selectdepartment} .=
        "<option>$_->{description}--$_->{id}\n"
    } (@{ $form->{all_departments} || [] });
  }

  $form->{show_details} = $myconfig{show_form_details} unless defined $form->{show_details};

  &display_form(1);
  $main::lxdebug->leave_sub();

}

sub prepare_transaction {
  $main::lxdebug->enter_sub();

  $main::auth->assert('gl_transactions');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  GL->transaction(\%myconfig, \%$form);

  $form->{amount} = $form->format_amount(\%myconfig, $form->{amount}, 2);

  # departments
  $form->all_departments(\%myconfig);
  if (@{ $form->{all_departments} || [] }) {
    $form->{selectdepartment} = "<option>\n";

    map {
      $form->{selectdepartment} .=
        "<option>$_->{description}--$_->{id}\n"
    } (@{ $form->{all_departments} || [] });
  }

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
      $form->{"accno_$i"} = "$ref->{accno}--$ref->{tax_id}";
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

  form_header();
  display_rows();
  form_footer();

  $main::lxdebug->leave_sub();
}


sub search {
  $::lxdebug->enter_sub;
  $::auth->assert('general_ledger | gl_transactions');

  $::form->all_departments(\%::myconfig);
  $::form->get_lists(
    projects  => { key => "ALL_PROJECTS", all => 1 },
  );
  $::form->{ALL_EMPLOYEES} = SL::DB::Manager::Employee->get_all_sorted(query => [ deleted => 0 ]);

  $::form->header;
  print $::form->parse_html_template('gl/search', {
    department_label => sub { ("$_[0]{description}--$_[0]{id}")x2 },
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
    gldate         transdate        id             reference      description
    notes          source           debit          debit_accno
    credit         credit_accno     debit_tax      debit_tax_accno
    credit_tax     credit_tax_accno projectnumbers balance employee
  );

  # add employee here, so that variable is still known and passed in url when choosing a different sort order in resulting table
  my @hidden_variables = qw(accno source reference department description notes project_id datefrom dateto employee_id datesort category l_subtotal);
  push @hidden_variables, map { "l_${_}" } @columns;

  my $employee = $form->{employee_id} ? SL::DB::Employee->new(id => $form->{employee_id})->load->name : '';

  my (@options, @date_options);
  push @options,      $locale->text('Account')     . " : $form->{accno} $form->{account_description}" if ($form->{accno});
  push @options,      $locale->text('Source')      . " : $form->{source}"                             if ($form->{source});
  push @options,      $locale->text('Reference')   . " : $form->{reference}"                          if ($form->{reference});
  push @options,      $locale->text('Description') . " : $form->{description}"                        if ($form->{description});
  push @options,      $locale->text('Notes')       . " : $form->{notes}"                              if ($form->{notes});
  push @options,      $locale->text('Employee')    . " : $employee"                                   if $employee;
  my $datesorttext = $form->{datesort} eq 'transdate' ? $locale->text('Invoice Date') :  $locale->text('Booking Date');
  push @date_options,      "$datesorttext"                              if ($form->{datesort} and ($form->{datefrom} or $form->{dateto}));
  push @date_options, $locale->text('From'), $locale->date(\%myconfig, $form->{datefrom}, 1)          if ($form->{datefrom});
  push @date_options, $locale->text('Bis'),  $locale->date(\%myconfig, $form->{dateto},   1)          if ($form->{dateto});
  push @options,      join(' ', @date_options)                                                        if (scalar @date_options);

  if ($form->{department}) {
    my ($department) = split /--/, $form->{department};
    push @options, $locale->text('Department') . " : $department";
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

  my %column_defs = (
    'id'               => { 'text' => $locale->text('ID'), },
    'transdate'        => { 'text' => $locale->text('Invoice Date'), },
    'gldate'           => { 'text' => $locale->text('Booking Date'), },
    'reference'        => { 'text' => $locale->text('Reference'), },
    'source'           => { 'text' => $locale->text('Source'), },
    'description'      => { 'text' => $locale->text('Description'), },
    'notes'            => { 'text' => $locale->text('Notes'), },
    'debit'            => { 'text' => $locale->text('Debit'), },
    'debit_accno'      => { 'text' => $locale->text('Debit Account'), },
    'credit'           => { 'text' => $locale->text('Credit'), },
    'credit_accno'     => { 'text' => $locale->text('Credit Account'), },
    'debit_tax'        => { 'text' => $locale->text('Debit Tax'), },
    'debit_tax_accno'  => { 'text' => $locale->text('Debit Tax Account'), },
    'credit_tax'       => { 'text' => $locale->text('Credit Tax'), },
    'credit_tax_accno' => { 'text' => $locale->text('Credit Tax Account'), },
    'balance'          => { 'text' => $locale->text('Balance'), },
    'projectnumbers'   => { 'text' => $locale->text('Project Numbers'), },
    'employee'         => { 'text' => $locale->text('Employee'), },
  );

  foreach my $name (qw(id transdate gldate reference description debit_accno credit_accno debit_tax_accno credit_tax_accno)) {
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

  $report->set_export_options('generate_report', @hidden_variables, qw(sort sortdir));

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

    map { $row->{$_}->{data} = $ref->{$_} } qw(id reference description notes gldate employee);

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

  $report->generate_with_headers();

  $main::lxdebug->leave_sub();
}

sub update {
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
    qw(accno debit credit projectnumber fx_transaction source memo tax taxchart);

  for my $i (1 .. $form->{rowcount}) {

    unless (($form->{"debit_$i"} eq "") && ($form->{"credit_$i"} eq "")) {
      for (qw(debit credit tax)) {
        $form->{"${_}_$i"} =
          $form->parse_amount(\%myconfig, $form->{"${_}_$i"});
      }

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
        $form->{"taxchart_$i"} = "$notax_id--0.00";
      }
      if (!$debitcredit && $debittax) {
        $form->{"taxchart_$i"} = "$notax_id--0.00";
      }
      $amount =
        ($form->{"debit_$i"} == 0)
        ? $form->{"credit_$i"}
        : $form->{"debit_$i"};
      my $j = $#a;
      if (($debitcredit && $credittax) || (!$debitcredit && $debittax)) {
        $form->{"taxchart_$i"} = "$notax_id--0.00";
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
  }

  for my $i (1 .. $count) {
    my $j = $i - 1;
    for (@flds) { $form->{"${_}_$i"} = $a[$j]->{$_} }
  }

  for my $i ($count + 1 .. $form->{rowcount}) {
    for (@flds) { delete $form->{"${_}_$i"} }
  }

  $form->{rowcount} = $count + 1;

  &display_form;
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

  $form->{debit_1}     = 0 if !$form->{"debit_1"};
  $form->{totaldebit}  = 0;
  $form->{totalcredit} = 0;

  my %project_labels = ();
  my @project_values = ("");
  foreach my $item (@{ $form->{"ALL_PROJECTS"} }) {
    push(@project_values, $item->{"id"});
    $project_labels{$item->{"id"}} = $item->{"projectnumber"};
  }

  my %chart_labels = ();
  my @chart_values = ();
  my %charts = ();
  my $taxchart_init;
  foreach my $item (@{ $form->{ALL_CHARTS} }) {
    if ($item->{charttype} eq 'H'){ #falls ÃŒberschrift
      next;                         #ÃŒberspringen (Bug 1150)
    }
    my $key = $item->{accno} . "--" . $item->{tax_id};
    $taxchart_init = $item->{tax_id} unless (@chart_values);
    push(@chart_values, $key);
    $chart_labels{$key} = $item->{accno} . "--" . $item->{description};
    $charts{$item->{accno}} = $item;
  }

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

    my $selected_accno_full;
    my ($accno_row) = split(/--/, $form->{"accno_$i"});
    my $item = $charts{$accno_row};
    $selected_accno_full = "$item->{accno}--$item->{tax_id}";

    my $selected_taxchart = $form->{"taxchart_$i"};
    my ($selected_accno, $selected_tax_id) = split(/--/, $selected_accno_full);
    my ($previous_accno, $previous_tax_id) = split(/--/, $form->{"previous_accno_$i"});

    my %taxchart_labels = ();
    my @taxchart_values = ();
    my %taxcharts = ();
    my $filter_accno;
    $filter_accno = $::form->{ALL_CHARTS}[0]->{accno};
    $filter_accno = $selected_accno if (!$init and $i < $form->{rowcount});
    foreach my $item ( GL->get_tax_dropdown($filter_accno) ) {
      my $key = $item->{id} . "--" . $item->{rate};
      $taxchart_init = $key if ($taxchart_init == $item->{id});
      push(@taxchart_values, $key);
      $taxchart_labels{$key} = $item->{taxdescription} . " " . $item->{rate} * 100 . ' %';
      $taxcharts{$item->{id}} = $item;
    }

    if ($previous_accno &&
        ($previous_accno eq $selected_accno) &&
        ($previous_tax_id ne $selected_tax_id)) {
      my $item = $taxcharts{$selected_tax_id};
      $selected_taxchart = "$item->{id}--$item->{rate}";
    }

    $selected_accno      = '' if ($init);
    $selected_taxchart ||= $taxchart_init;

    my $accno = qq|<td>| .
      NTI($cgi->popup_menu('-name' => "accno_$i",
                           '-id' => "accno_$i",
                           '-onChange' => "updateTaxes($i);",
                           '-style' => 'width:200px',
                           '-values' => \@chart_values,
                           '-labels' => \%chart_labels,
                           '-default' => $selected_accno_full))
      . $cgi->hidden('-name' => "previous_accno_$i",
                     '-default' => $selected_accno_full)
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

    my $projectnumber =
      NTI($cgi->popup_menu('-name' => "project_id_$i",
                           '-values' => \@project_values,
                           '-labels' => \%project_labels,
                           '-default' => $form->{"project_id_$i"} ));
    my $projectnumber_hidden = qq|
    <input type="hidden" name="project_id_$i" value="$form->{"project_id_$i"}">|;

    my $copy2credit = $i == 1 ? 'onkeyup="copy_debit_to_credit()"' : '';

    print qq|<tr valign=top>
    $accno
    <td id="chart_balance_$i" align="right">&nbsp;</td>
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

sub form_header {
  $::lxdebug->enter_sub;
  $::auth->assert('gl_transactions');

  my ($init) = @_;

  my @old_project_ids = grep { $_ } map{ $::form->{"project_id_$_"} } 1..$::form->{rowcount};

  $::form->get_lists("projects"  => { "key"       => "ALL_PROJECTS",
                                    "all"       => 0,
                                    "old_id"    => \@old_project_ids },
                   "charts"    => { "key"       => "ALL_CHARTS",
                                    "transdate" => $::form->{transdate} });

  GL->get_chart_balances('charts' => $::form->{ALL_CHARTS});

  my $title      = $::form->{title};
  $::form->{title} = $::locale->text("$title General Ledger Transaction");
  # $locale->text('Add General Ledger Transaction')
  # $locale->text('Edit General Ledger Transaction')

  map { $::form->{$_} =~ s/\"/&quot;/g }
    qw(chart taxchart);

  $::form->{selectdepartment} =~ s/ selected//;
  $::form->{selectdepartment} =~
    s/option>\Q$::form->{department}\E/option selected>$::form->{department}/;

  if ($init) {
    $::request->{layout}->focus("#reference");
    $::form->{taxincluded} = "1";
  } else {
    $::request->{layout}->focus("#accno_$::form->{rowcount}");
  }

  $::form->{previous_id}     ||= "--";
  $::form->{previous_gldate} ||= "--";

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
  my $locale   = $main::locale;

  $form->header;

  print qq|
<form method=post action=gl.pl>
|;

  map { $form->{$_} =~ s/\"/&quot;/g } qw(reference description);

  delete $form->{header};

  foreach my $key (keys %$form) {
    next if (($key eq 'login') || ($key eq 'password') || ('' ne ref $form->{$key}));
    print qq|<input type="hidden" name="$key" value="$form->{$key}">\n|;
  }

  print qq|
<h2 class=confirm>| . $locale->text('Confirm!') . qq|</h2>

<h4>|
    . $locale->text('Are you sure you want to delete Transaction')
    . qq| $form->{reference}</h4>

<input name=action class=submit type=submit value="|
    . $locale->text('Yes') . qq|">
</form>
|;
  $main::lxdebug->leave_sub();

}

sub yes {
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
  $form->isblank("reference",   $locale->text('Reference missing!'));
  $form->isblank("transdate",   $locale->text('Transaction Date missing!'));
  $form->isblank("description", $locale->text('Description missing!'));

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

  my @flds = qw(accno debit credit projectnumber fx_transaction source memo tax taxchart);

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
      $form->{"taxchart_$i"} = "$notax_id--0.00";
    }
    if (!$debitcredit && $debittax) {
      $form->{"taxchart_$i"} = "$notax_id--0.00";
    }
    my $amount = ($form->{"debit_$i"} == 0)
            ? $form->{"credit_$i"}
            : $form->{"debit_$i"};
    my $j = $#a;
    if (($debitcredit && $credittax) || (!$debitcredit && $debittax)) {
      $form->{"taxchart_$i"} = "$notax_id--0.00";
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

  if ((my $errno = GL->post_transaction(\%myconfig, \%$form)) <= -1) {
    $errno *= -1;
    my @err;
    $err[1] = $locale->text('Cannot have a value in both Debit and Credit!');
    $err[2] = $locale->text('Debit and credit out of balance!');
    $err[3] = $locale->text('Cannot post a transaction without a value!');

    $form->error($err[$errno]);
  }
  undef($form->{callback});
  # saving the history
  if(!exists $form->{addition} && $form->{id} ne "") {
    $form->{snumbers} = qq|gltransaction_| . $form->{id};
    $form->{addition} = "POSTED";
    $form->{what_done} = "gl transaction";
    $form->save_history;
  }
  # /saving the history

  $main::lxdebug->leave_sub();
}

sub post {
  $main::lxdebug->enter_sub();

  $main::auth->assert('gl_transactions');

  my $form     = $main::form;
  my $locale   = $main::locale;

  if ($::myconfig{mandatory_departments} && !$form->{department}) {
    $form->{saved_message} = $::locale->text('You have to specify a department.');
    update();
    exit;
  }

  $form->{title}  = $locale->text("$form->{title} General Ledger Transaction");
  $form->{storno} = 0;

  post_transaction();

  $form->{callback} = build_std_url("action=add", "show_details");
  $form->redirect($form->{callback});

  $main::lxdebug->leave_sub();
}

sub post_as_new {
  $main::lxdebug->enter_sub();

  $main::auth->assert('gl_transactions');

  my $form     = $main::form;

  $form->{id} = 0;
  &add;
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

sub continue {
  call_sub($main::form->{nextsub});
}

sub get_tax_dropdown {
  $main::lxdebug->enter_sub();

  my $form = $main::form;
  my @tax_accounts = GL->get_tax_dropdown($form->{accno});

  foreach my $item (@tax_accounts) {
    $item->{taxdescription} = $::locale->{iconv_utf8}->convert($item->{taxdescription});
    $item->{taxdescription} .= ' ' . $form->round_amount($item->{rate} * 100);
  }

  $form->{TAX_ACCOUNTS} = [ @tax_accounts ];

  print $form->ajax_response_header, $form->parse_html_template("gl/update_tax_accounts");

  $main::lxdebug->leave_sub();

}

1;
