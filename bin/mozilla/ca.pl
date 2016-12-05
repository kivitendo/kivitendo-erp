#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 2001
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
# module for Chart of Accounts, Income Statement and Balance Sheet
# search and edit transactions posted by the GL, AR and AP
#
#======================================================================

use POSIX qw(strftime);

use SL::CA;
use SL::DB::Default;
use SL::ReportGenerator;

require "bin/mozilla/reportgenerator.pl";

use strict;

1;

# end of main

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

sub chart_of_accounts {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('report');

  $form->{title} = $locale->text('Chart of Accounts');

  if ( $::instance_conf->get_accounting_method eq 'cash' ) {
    # $form->{method} can probably be made redundant now that we have get_accounting_method
    $form->{method} = "cash";
  }

  CA->all_accounts(\%myconfig, \%$form);

  my @columns     = qw(accno description debit credit);
  my %column_defs = (
    'accno'       => { 'text' => $locale->text('Account'), },
    'description' => { 'text' => $locale->text('Description'), },
    'debit'       => { 'text' => $locale->text('Debit'), },
    'credit'      => { 'text' => $locale->text('Credit'), },
  );

  my $report = SL::ReportGenerator->new(\%myconfig, $form);

  $report->set_options('output_format'         => 'HTML',
                       'title'                 => $form->{title},
                       'attachment_basename'   => $locale->text('chart_of_accounts') . strftime('_%Y%m%d', localtime time),
                       'std_column_visibility' => 1,
    );
  $report->set_options_from_form();
  $locale->set_numberformat_wo_thousands_separator(\%myconfig) if lc($report->{options}->{output_format}) eq 'csv';

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);

  $report->set_export_options('chart_of_accounts');

  $report->set_sort_indicator($form->{sort}, 1);

  my %totals = ('debit' => 0, 'credit' => 0);

  foreach my $ca (@{ $form->{CA} }) {
    next unless defined $ca->{amount};
    my $row = { };

    foreach (qw(debit credit)) {
      $totals{$_} += $ca->{$_} * 1;
      $ca->{$_}    = $form->format_amount(\%myconfig, $ca->{$_}, 2) if ($ca->{$_});
    }

    map { $row->{$_} = { 'data' => $ca->{$_} } } @columns;

    map { $row->{$_}->{align} = 'right'       } qw(debit credit);
    map { $row->{$_}->{class} = 'listheading' } @columns if ($ca->{charttype} eq "H");

    $row->{accno}->{link} = build_std_url('action=list', 'accno=' . E($ca->{accno}), 'description=' . E($ca->{description}));

    $report->add_data($row);
  }

  my $row = { map { $_ => { 'class' => 'listtotal', 'align' => 'right' } } @columns };
  map { $row->{$_}->{data} = $form->format_amount(\%myconfig, $totals{$_}, 2) } qw(debit credit);

  $report->add_separator();
  $report->add_data($row);

  $report->generate_with_headers();

  $main::lxdebug->leave_sub();
}

sub list {
  $::lxdebug->enter_sub;
  $::auth->assert('report');

  $::form->{title} = $::locale->text('List Transactions') . " - " . $::locale->text('Account') . " $::form->{accno}" . " - " . $::form->{description};

  $::form->header;
  print $::form->parse_html_template('ca/list', {
    year => DateTime->today->year,
  });

  $::lxdebug->leave_sub;
}

sub format_debit_credit {
  $main::lxdebug->enter_sub();

  my $dc = shift;

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  my $formatted_dc  = $form->format_amount(\%myconfig, abs($dc), 2) . ' ';
  $formatted_dc    .= ($dc > 0) ? $locale->text('Credit (one letter abbreviation)') : $locale->text('Debit (one letter abbreviation)');

  $main::lxdebug->leave_sub();

  return $formatted_dc;
}


sub list_transactions {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;
  my $defaults = SL::DB::Default->get;

  $main::auth->assert('report');

  $form->{title} = $locale->text('Account') . " $form->{accno} - $form->{description}";

  if ($form->{reporttype} eq "custom") {

    #forgotten the year --> thisyear
    if ($form->{year} !~ m/^\d\d\d\d$/) {
      $locale->date(\%myconfig, $form->current_date(\%myconfig), 0) =~
        /(\d\d\d\d)/;
      $form->{year} = $1;
    }

    #yearly report
    if ($form->{duetyp} eq "13") {
      $form->{fromdate} = "1.1.$form->{year}";
      $form->{todate}   = "31.12.$form->{year}";
    }

    #Quater reports
    if ($form->{duetyp} eq "A") {
      $form->{fromdate} = "1.1.$form->{year}";
      $form->{todate}   = "31.3.$form->{year}";
    }
    if ($form->{duetyp} eq "B") {
      $form->{fromdate} = "1.4.$form->{year}";
      $form->{todate}   = "30.6.$form->{year}";
    }
    if ($form->{duetyp} eq "C") {
      $form->{fromdate} = "1.7.$form->{year}";
      $form->{todate}   = "30.9.$form->{year}";
    }
    if ($form->{duetyp} eq "D") {
      $form->{fromdate} = "1.10.$form->{year}";
      $form->{todate}   = "31.12.$form->{year}";
    }

    #Monthly reports
  SWITCH: {
      $form->{duetyp} eq "1" && do {
        $form->{fromdate} = "1.1.$form->{year}";
        $form->{todate}   = "31.1.$form->{year}";
        last SWITCH;
      };
      $form->{duetyp} eq "2" && do {
        $form->{fromdate} = "1.2.$form->{year}";

        #this works from 1901 to 2099, 1900 and 2100 fail.
        my $leap = ($form->{year} % 4 == 0) ? "29" : "28";
        $form->{todate} = "$leap.2.$form->{year}";
        last SWITCH;
      };
      $form->{duetyp} eq "3" && do {
        $form->{fromdate} = "1.3.$form->{year}";
        $form->{todate}   = "31.3.$form->{year}";
        last SWITCH;
      };
      $form->{duetyp} eq "4" && do {
        $form->{fromdate} = "1.4.$form->{year}";
        $form->{todate}   = "30.4.$form->{year}";
        last SWITCH;
      };
      $form->{duetyp} eq "5" && do {
        $form->{fromdate} = "1.5.$form->{year}";
        $form->{todate}   = "31.5.$form->{year}";
        last SWITCH;
      };
      $form->{duetyp} eq "6" && do {
        $form->{fromdate} = "1.6.$form->{year}";
        $form->{todate}   = "30.6.$form->{year}";
        last SWITCH;
      };
      $form->{duetyp} eq "7" && do {
        $form->{fromdate} = "1.7.$form->{year}";
        $form->{todate}   = "31.7.$form->{year}";
        last SWITCH;
      };
      $form->{duetyp} eq "8" && do {
        $form->{fromdate} = "1.8.$form->{year}";
        $form->{todate}   = "31.8.$form->{year}";
        last SWITCH;
      };
      $form->{duetyp} eq "9" && do {
        $form->{fromdate} = "1.9.$form->{year}";
        $form->{todate}   = "30.9.$form->{year}";
        last SWITCH;
      };
      $form->{duetyp} eq "10" && do {
        $form->{fromdate} = "1.10.$form->{year}";
        $form->{todate}   = "31.10.$form->{year}";
        last SWITCH;
      };
      $form->{duetyp} eq "11" && do {
        $form->{fromdate} = "1.11.$form->{year}";
        $form->{todate}   = "30.11.$form->{year}";
        last SWITCH;
      };
      $form->{duetyp} eq "12" && do {
        $form->{fromdate} = "1.12.$form->{year}";
        $form->{todate}   = "31.12.$form->{year}";
        last SWITCH;
      };
    }
  }

  CA->all_transactions(\%myconfig, \%$form);

  $form->{saldo_old} += $form->{beginning_balance};
  $form->{saldo_new} += $form->{beginning_balance};
  my $saldo_old = format_debit_credit($form->{saldo_old});
  my $eb_string = format_debit_credit($form->{beginning_balance});
  $form->{balance} = $form->{saldo_old};

  my @options;
  if ($form->{department}) {
    my ($department) = split /--/, $form->{department};
    push @options, $locale->text('Department') . " : $department";
  }
  if ($form->{projectnumber}) {
    push @options, $locale->text('Project Number') . " : $form->{projectnumber}<br>";
  }

  my $period;
  if ($form->{fromdate} || $form->{todate}) {
    my ($fromdate, $todate);

    if ($form->{fromdate}) {
      $fromdate = $locale->date(\%myconfig, $form->{fromdate}, 1);
    }
    if ($form->{todate}) {
      $todate = $locale->date(\%myconfig, $form->{todate}, 1);
    }

    $period = "$fromdate - $todate";

  } else {
    $period = $locale->date(\%myconfig, $form->current_date(\%myconfig), 1);
  }

  push @options, $period;

  $form->{print_date} = $locale->text('Create Date') . " " . $locale->date(\%myconfig, $form->current_date(\%myconfig), 0);
  push (@options, $form->{print_date});

  $form->{company} = $locale->text('Company') . " " . $defaults->company;
  push (@options, $form->{company});

  my @columns     = qw(transdate reference description gegenkonto debit credit ustkonto ustrate balance);
  my %column_defs = (
    'transdate'   => { 'text' => $locale->text('Date'), },
    'reference'   => { 'text' => $locale->text('Reference'), },
    'description' => { 'text' => $locale->text('Description'), },
    'debit'       => { 'text' => $locale->text('Debit'), },
    'credit'      => { 'text' => $locale->text('Credit'), },
    'gegenkonto'  => { 'text' => $locale->text('Gegenkonto'), },
    'ustkonto'    => { 'text' => $locale->text('USt-Konto'), },
    'balance'     => { 'text' => $locale->text('Balance'), },
    'ustrate'     => { 'text' => $locale->text('Satz %'), },
 );

  my @hidden_variables = qw(accno fromdate todate description accounttype l_heading subtotal department projectnumber project_id sort method);

  my $link = build_std_url('action=list_transactions', grep { $form->{$_} } @hidden_variables);

  $form->{callback} = $link . '&sort=' . E($form->{sort});

  my %column_alignment = map { $_ => 'right' } qw(debit credit balance);

  my @custom_headers = ();
 # Zeile 1:
 push @custom_headers, [
   { 'text' => 'Letzte Buchung', },
   { 'text' => 'EB-Wert', },
   { 'text' => 'Saldo alt', 'colspan' => 2, },
   { 'text' => 'Jahresverkehrszahlen alt', 'colspan' => 2, },
   { 'text' => '', 'colspan' => 2, },
 ];
 push @custom_headers, [
   { 'text' => $form->{last_transaction}, },
   { 'text' => $eb_string, },
   { 'text' => $saldo_old, 'colspan' => 2, },
   { 'text' => $form->format_amount(\%myconfig, abs($form->{old_balance_debit}), 2) . " S", },
   { 'text' => $form->format_amount(\%myconfig, $form->{old_balance_credit}, 2) . " H", },
   { 'text' => '', 'colspan' => 2, },
 ];
 # Zeile 2:
 push @custom_headers, [
   { 'text' => $locale->text('Date'), 'link' => $link . "&sort=transdate", },
   { 'text' => $locale->text('Reference'), 'link' => $link . "&sort=reference",  },
   { 'text' => $locale->text('Description'), 'link' => $link . "&sort=description",  },
   { 'text' => $locale->text('Gegenkonto'), },
   { 'text' => $locale->text('Debit'), },
   { 'text' => $locale->text('Credit'), },
   { 'text' => $locale->text('USt-Konto'), },
   { 'text' => $locale->text('Satz %'), },
   { 'text' => $locale->text('Balance'), },
 ];





  my $report = SL::ReportGenerator->new(\%myconfig, $form);
  $report->set_custom_headers(@custom_headers);

  $report->set_options('top_info_text'         => join("\n", @options),
                       'output_format'         => 'HTML',
                       'title'                 => $form->{title},
                       'attachment_basename'   => $locale->text('list_of_transactions') . strftime('_%Y%m%d', localtime time),
                       'std_column_visibility' => 1,
    );
  $report->set_options_from_form();
  $locale->set_numberformat_wo_thousands_separator(\%myconfig) if lc($report->{options}->{output_format}) eq 'csv';

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);

  $report->set_export_options('list_transactions', @hidden_variables);

  $report->set_sort_indicator($form->{sort}, 1);

  $column_defs{balance}->{visible} = 1;

  my $ml = ($form->{category} =~ /(A|E)/) ? -1 : 1;


  my $idx       = 0;
  my %totals    = ( 'debit' => 0, 'credit' => 0 );
  my %subtotals = ( 'debit' => 0, 'credit' => 0 );
  my ($previous_index, $row_set);

  foreach my $ca (@{ $form->{CA} }) {

    foreach (qw(debit credit)) {
      $subtotals{$_} += $ca->{$_};
      $totals{$_}    += $ca->{$_};
      if ($_ =~ /debit.*/) {
        $ml = -1;
      } else {
        $ml = 1;
      }
      $form->{balance}= $form->{balance} + $ca->{$_} * $ml;
      $ca->{$_}       = $form->format_amount(\%myconfig, $ca->{$_}, 2) if ($ca->{$_} != 0);
    }

    my $do_subtotal = 0;
    if (($form->{subtotal})
        && (($idx == scalar @{ $form->{CA} } - 1)
            || ($ca->{$form->{sort}} ne $form->{CA}->[$idx + 1]->{$form->{sort}}))) {
      $do_subtotal = 1;
    }

    my $row = { };

    $ca->{ustrate} = $form->format_amount(\%myconfig, $ca->{ustrate} * 100, 2) if ($ca->{ustrate} != 0);

    if ($ca->{memo} ne "") {
      $ca->{description} .= " \n " . $ca->{memo};
    }



    foreach my $gegenkonto (@{ $ca->{GEGENKONTO} }) {
      if ($ca->{gegenkonto} eq "") {
        $ca->{gegenkonto} = $gegenkonto->{accno};
      } else {
        $ca->{gegenkonto} .= ", " . $gegenkonto->{accno};
      }
    }

    foreach (@columns) {
      $row->{$_} = {
        'data'  => $ca->{$_},
        'align' => $column_alignment{$_},
      };
    }

    $row->{balance}->{data}        = $form->format_amount(\%myconfig, $form->{balance}, 2, 'DRCR');

    if ($ca->{index} ne $previous_index) {
#       $report->add_data($row_set) if ($row_set);

#       $row_set         = [ ];
      $previous_index  = $ca->{index};

      $row->{reference}->{link} = build_std_url("script=$ca->{module}.pl", 'action=edit', 'id=' . E($ca->{id}), 'callback');

    } elsif ($ca->{index} eq $previous_index) {
      map { $row->{$_}->{data} = '' } qw(reference description);
      $row->{transdate}->{data} = '' if ($form->{sort} eq 'transdate');
    }

    my $row_set = [];

    push @{ $row_set }, $row;

    push @{ $row_set }, create_subtotal_row(\%subtotals, \@columns, \%column_alignment, 'listsubtotal') if ($do_subtotal);


    $idx++;
    $report->add_data($row_set);

  }

  $report->add_data($row_set) if ($row_set);

  $report->add_separator();

  my $row = create_subtotal_row(\%totals, \@columns, \%column_alignment, 'listtotal');


  $row->{balance}->{data}        = $form->format_amount(\%myconfig, $form->{balance}, 2, 'DRCR');

  $report->add_data($row);


  $report->add_separator();
  $row = {
     'transdate' => {
       'data'    => "",
       'class' => 'listtotal',
     },
     'reference' => {
       'data'    => $locale->text('EB-Wert'),
       'class' => 'listtotal',
     },
     'description'      => {
       'data'    => $locale->text('Saldo neu'),
       'colspan' => 2,
       'class' => 'listtotal',
     },
     'debit'      => {
       'data'    => $locale->text('Jahresverkehrszahlen neu'),
       'colspan' => 2,
       'align' => 'left',
       'class' => 'listtotal',
    },
     'ustkonto'      => {
       'data'    => '',
       'colspan' => 2,
       'align' => 'left',
       'class' => 'listtotal',
    },
  };

  $report->add_data($row);
  my $saldo_new = format_debit_credit($form->{saldo_new});
  $row = {
     'transdate' => {
       'data'    => "",
       'class' => 'listtotal',
     },
     'reference' => {
       'data'    => $eb_string,
       'class' => 'listtotal',
     },
     'description'      => {
       'data'    => $saldo_new,
       'colspan' => 2,
       'class' => 'listtotal',
     },
     'debit'      => {
       'data'    => $form->format_amount(\%myconfig, abs($form->{current_balance_debit}) , 2) . " S",
       'class' => 'listtotal',
     },
      'credit'      => {
       'data'    => $form->format_amount(\%myconfig, $form->{current_balance_credit}, 2) . " H",
       'class' => 'listtotal',
     },
      'ustkonto'      => {
       'data'    => "",
       'colspan' => 2,
       'class' => 'listtotal',
     },
  };

  $report->add_data($row);

  $report->generate_with_headers();

  $main::lxdebug->leave_sub();
}

sub create_subtotal_row {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  my ($totals, $columns, $column_alignment, $class) = @_;

  my $row = { map { $_ => { 'data' => '', 'class' => $class, 'align' => $column_alignment->{$_}, } } @{ $columns } };

  map { $row->{$_}->{data} = $form->format_amount(\%myconfig, $totals->{$_}, 2) } qw(credit debit);

  map { $totals->{$_} = 0 } qw(debit credit);

  $main::lxdebug->leave_sub();

  return $row;
}
