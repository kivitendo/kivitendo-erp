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
#  Contributors: Antonio Gallardo <agssa@ibw.com.ni>
#                Benjamin Lee <benjaminlee@consultant.com>
#                Philip Reetz <p.reetz@linet-services.de>
#                Udo Spallek
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
# module for preparing Income Statement and Balance Sheet
#
#======================================================================

use POSIX qw(strftime);

use SL::DB::Default;
use SL::DB::Project;
use SL::DB::Customer;
use SL::RP;
use SL::Iconv;
use SL::Locale::String qw(t8);
use SL::Presenter::Tag;
use SL::ReportGenerator;
use Data::Dumper;
use List::MoreUtils qw(any);

require "bin/mozilla/common.pl";
require "bin/mozilla/reportgenerator.pl";

# note: this file was particularly hard to strictify.
# alot of the vars are passed carelessly between invocations
# should there be any missing vars, declare them globally
use strict;

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

# $locale->text('Balance Sheet')
# $locale->text('Income Statement')
# $locale->text('Trial Balance')
# $locale->text('AR Aging')
# $locale->text('AP Aging')
# $locale->text('Search AR Aging')
# $locale->text('Search AP Aging')
# $locale->text('Tax collected')
# $locale->text('Tax paid')
# $locale->text('Receipts')
# $locale->text('Payments')
# $locale->text('Project Transactions')
# $locale->text('Business evaluation')

# $form->parse_html_template('rp/html_report_susa')

my $rp_access_map = {
  'projects'           => 'report',
  'ar_aging'           => 'general_ledger',
  'ap_aging'           => 'general_ledger',
  'receipts'           => 'cash',
  'payments'           => 'cash',
  'trial_balance'      => 'report',
  'income_statement'   => 'report',
  'erfolgsrechnung'    => 'report',
  'bwa'                => 'report',
  'balance_sheet'      => 'report',
};

sub check_rp_access {
  my $form     = $main::form;

  my $right   = $rp_access_map->{$form->{report}};
  $right    ||= 'DOES_NOT_EXIST';

  $main::auth->assert($right);
}

sub report {
  $::lxdebug->enter_sub;

  check_rp_access();

  my %title = (
    balance_sheet        => $::locale->text('Balance Sheet'),
    income_statement     => $::locale->text('Income Statement'),
    erfolgsrechnung      => $::locale->text('Erfolgsrechnung'),
    trial_balance        => $::locale->text('Trial Balance'),
    ar_aging             => $::locale->text('Search AR Aging'),
    ap_aging             => $::locale->text('Search AP Aging'),
    tax_collected        => $::locale->text('Tax collected'),
    tax_paid             => $::locale->text('Tax paid'),
    receipts             => $::locale->text('Receipts'),
    payments             => $::locale->text('Payments'),
    projects             => $::locale->text('Project Transactions'),
    bwa                  => $::locale->text('Business evaluation'),
  );

  $::form->{title} = $title{$::form->{report}};
  $::request->{layout}->add_javascripts('kivi.CustomerVendor.js');
  $::request->{layout}->add_javascripts('autocomplete_project.js');
  $::form->{fromdate} = DateTime->today->truncate(to => 'year')->to_kivitendo;
  $::form->{todate} = DateTime->today->truncate(to => 'year')->add(years => 1)->add(days => -1)->to_kivitendo;

  # get departments
  $::form->all_departments(\%::myconfig);
  if (@{ $::form->{all_departments} || [] }) {
    $::form->{selectdepartment} = "<option>\n";
    map { $::form->{selectdepartment} .= "<option>$_->{description}--$_->{id}\n" } @{ $::form->{all_departments} || [] };
  }

  $::form->get_lists("projects" => { "key" => "ALL_PROJECTS", "all" => 1 });

  my $is_projects            = $::form->{report} eq "projects";
  my $is_income_statement    = $::form->{report} eq "income_statement";
  my $is_erfolgsrechnung     = $::form->{report} eq "erfolgsrechnung";
  my $is_bwa                 = $::form->{report} eq "bwa";
  my $is_balance_sheet       = $::form->{report} eq "balance_sheet";
  my $is_trial_balance       = $::form->{report} eq "trial_balance";
  my $is_aging               = $::form->{report} =~ /^a[rp]_aging$/;
  my $is_payments            = $::form->{report} =~ /(receipts|payments)$/;
  my $format                 = 'html';

  my ($label, $nextsub, $vc);
  if ($is_aging) {
    my $is_sales  = $::form->{report} eq 'ar_aging';
    $label        = $is_sales ? $::locale->text('Customer') : $::locale->text('Vendor');
    $::form->{vc} = $is_sales ? 'customer' : 'vendor';

    $nextsub = "generate_$::form->{report}";

    $vc = qq|<input name=$::form->{vc} size=35 class="initial_focus">|;

    $format = 'pdf';
  }

  my ($selection, $paymentaccounts);
  if ($is_payments) {
    $::form->{db} = $::form->{report} =~ /payments$/ ? "ap" : "ar";

    RP->paymentaccounts(\%::myconfig, $::form);

    $selection = "<option>\n";
    for my $ref (@{ $::form->{PR} }) {
      $paymentaccounts .= "$ref->{accno} ";
      $selection       .= "<option>$ref->{accno}--$ref->{description}\n";
    }
  }

  setup_rp_report_action_bar();

  $::form->header;
  print $::form->parse_html_template('rp/report', {
    paymentaccounts        => $paymentaccounts,
    selection              => $selection,
    is_aging               => $is_aging,
    vc                     => $vc,
    label                  => $label,
    year                   => DateTime->today->year,
    today                  => DateTime->today,
    nextsub                => $nextsub,
    is_payments            => $is_payments,
    is_trial_balance       => $is_trial_balance,
    is_balance_sheet       => $is_balance_sheet,
    is_bwa                 => $is_bwa,
    is_income_statement    => $is_income_statement,
    is_erfolgsrechnung     => $is_erfolgsrechnung,
    is_projects            => $is_projects,
    format                 => $format,
  });

  $::lxdebug->leave_sub;
}

sub continue { call_sub($main::form->{"nextsub"}); }

sub generate_income_statement {
  $main::lxdebug->enter_sub();

  $main::auth->assert('report');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $form->{padding} = "&nbsp;&nbsp;";
  $form->{bold}    = "<b>";
  $form->{endbold} = "</b>";
  $form->{br}      = "<br>";

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
    hotfix_reformat_date();
  } # Ende Bericht für vorgewählten Zeitraum (warum auch immer die Prüfung (custom eq true) ist ...

  RP->income_statement(\%myconfig, \%$form);

  ($form->{department}) = split /--/, $form->{department};

  $form->{period} =
    $locale->date(\%myconfig, $form->current_date(\%myconfig), 1);
  $form->{todate} = $form->current_date(\%myconfig) unless $form->{todate};

  # if there are any dates construct a where
  if ($form->{fromdate} || $form->{todate}) {

    unless ($form->{todate}) {
      $form->{todate} = $form->current_date(\%myconfig);
    }

    my $longtodate  = $locale->date(\%myconfig, $form->{todate}, 1);
    my $shorttodate = $locale->date(\%myconfig, $form->{todate}, 0);

    my $longfromdate  = $locale->date(\%myconfig, $form->{fromdate}, 1);
    my $shortfromdate = $locale->date(\%myconfig, $form->{fromdate}, 0);

    $form->{this_period} = "$shortfromdate\n$shorttodate";
    $form->{period}      =
        $locale->text('for Period')
      . qq|\n$longfromdate |
      . $locale->text('Bis')
      . qq| $longtodate|;
  }

  if ($form->{comparefromdate} || $form->{comparetodate}) {
    my $longcomparefromdate = $locale->date(\%myconfig, $form->{comparefromdate}, 1);
    my $shortcomparefromdate = $locale->date(\%myconfig, $form->{comparefromdate}, 0);

    my $longcomparetodate  = $locale->date(\%myconfig, $form->{comparetodate}, 1);
    my $shortcomparetodate = $locale->date(\%myconfig, $form->{comparetodate}, 0);

    $form->{last_period} = "$shortcomparefromdate\n$shortcomparetodate";
    $form->{period} .=
        "\n$longcomparefromdate "
      . $locale->text('Bis')
      . qq| $longcomparetodate|;
  }

  if ( $::instance_conf->get_profit_determination eq 'balance' ) {
    $form->{title} = $locale->text('Income Statement');
  } elsif ( $::instance_conf->get_profit_determination eq 'income' ) {
    $form->{title} = $locale->text('Net Income Statement');
  } else {
    $form->{title} = "";
  };

  if ( $form->{method} eq 'cash' ) {
    $form->{accounting_method} = $locale->text('Cash accounting');
  } elsif ( $form->{method} eq 'accrual' ) {
    $form->{accounting_method} = $locale->text('Accrual accounting');
  } else {
    $form->{accounting_method} = "";
  };

  $form->{report_date} = $locale->text('Report date') . ": " . $form->current_date;

  $form->header;
  print $form->parse_html_template('rp/income_statement');

  $main::lxdebug->leave_sub();
}

sub generate_erfolgsrechnung {
  $::lxdebug->enter_sub;
  $::auth->assert('report');

  $::form->{decimalplaces} = $::form->{decimalplaces} * 1 || 2;
  $::form->{padding}       = "&emsp;";
  $::form->{bold}          = "<b>";
  $::form->{endbold}       = "</b>";
  $::form->{br}            = "<br>";

  my $data = RP->erfolgsrechnung(\%::myconfig, $::form);

  $::form->header();
  print $::form->parse_html_template('rp/erfolgsrechnung', $data);

  $::lxdebug->leave_sub;
}


sub generate_balance_sheet {
  $::lxdebug->enter_sub;
  $::auth->assert('report');

  $::form->{decimalplaces} = $::form->{decimalplaces} * 1 || 2;
  $::form->{padding}       = "&nbsp;&nbsp;";
  $::form->{bold}          = "<b>";
  $::form->{endbold}       = "</b>";
  $::form->{br}            = "<br>";

  my $data = RP->balance_sheet(\%::myconfig, $::form);

  $::form->{asofdate}    ||= $::form->current_date;
  $::form->{report_title}  = $::locale->text('Balance Sheet');
  $::form->{report_date} ||= $::form->current_date;

  ($::form->{department}) = split /--/, $::form->{department};

  # define Current Earnings account
  my $padding = $::form->{l_heading} ? $::form->{padding} : "";
  push @{ $::form->{equity_account} }, $padding . $::locale->text('Current Earnings');

  $::form->{this_period} = $::locale->date(\%::myconfig, $::form->{asofdate}, 0);
  $::form->{last_period} = $::locale->date(\%::myconfig, $::form->{compareasofdate}, 0);

#  balance sheet isn't read from print templates anymore,
#  instead use template in rp
#  $::form->{IN} = "balance_sheet.html";

  $::form->header;
  print $::form->parse_html_template('rp/balance_sheet', $data);

  $::lxdebug->leave_sub;
}

sub generate_projects {
  $main::lxdebug->enter_sub();

  $main::auth->assert('report');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  my $project            = $form->{project_id} ? SL::DB::Project->new(id => $form->{project_id})->load : undef;
  $form->{projectnumber} = $project ? $project->projectnumber : '';

  # make sure todate and fromdate always have a value, even if the date fields
  # were left empty or the inputs weren't valid dates/couldn't be parsed

  $project = SL::DB::Project->new() unless $project;  # dummy object for dbh
  unless ($::locale->parse_date_to_object($::form->{fromdate})) {
    ($form->{fromdate}) = $project->db->dbh->selectrow_array('select min(transdate) from acc_trans');
  };

  unless ($::locale->parse_date_to_object($::form->{todate})) {
    ($form->{todate})   = $project->db->dbh->selectrow_array('select max(transdate) from acc_trans');
  };

  $form->{nextsub} = "generate_projects";
  $form->{title}   = $locale->text('Project Transactions');
  RP->trial_balance(\%myconfig, \%$form);

  list_accounts('generate_projects');

  $main::lxdebug->leave_sub();
}

# Antonio Gallardo
#
# D.S. Feb 16, 2001
# included links to display transactions for period entered
# added headers and subtotals
#
sub generate_trial_balance {
  $main::lxdebug->enter_sub();

  $main::auth->assert('report');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;
  my $defaults = SL::DB::Default->get;

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
    hotfix_reformat_date();
  }


  # get for each account initial balance, debits and credits
  RP->trial_balance(\%myconfig, \%$form, 'beginning_balances' => 1);


  $form->{rowcount} = scalar @{ $form->{TB} || [] };
  $form->{title} = sprintf($locale->text('Trial balance between %s and %s'), $form->{fromdate}, $form->{todate});

  my @columns = (
    "accno",               "description",
    "last_transaction",    "soll_eb",
    "haben_eb",
    "soll",                "haben",
    "soll_kumuliert",      "haben_kumuliert",
    "soll_saldo",          "haben_saldo"
  );


  my $attachment_basename = $locale->text('trial_balance');
  my $report              = SL::ReportGenerator->new(\%myconfig, $form);

  my @hidden_variables    = qw(fromdate todate year method department_id);

  my $href                = build_std_url('action=generate_trial_balance', grep { $form->{$_} } @hidden_variables);

  my %column_defs         = (
    'accno'               => { 'text' => $locale->text('Account'), },
    'description'         => { 'text' => $locale->text('Description'), },
    'last_transaction'    => { 'text' => $locale->text('Last Transaction'), },
    'soll_eb'             => { 'text' => $locale->text('Debit Starting Balance'), },
    'haben_eb'            => { 'text' => $locale->text('Credit Starting Balance'), },
    'soll'                => { 'text' => $locale->text('Debit'), },
    'haben'               => { 'text' => $locale->text('Credit'), },
    'soll_kumuliert'      => { 'text' => $locale->text('Sum Debit'), },
    'haben_kumuliert'     => { 'text' => $locale->text('Sum Credit'), },
    'soll_saldo'          => { 'text' => $locale->text('Saldo Debit'), },
    'haben_saldo'         => { 'text' => $locale->text('Saldo Credit'), }
  );



  my %column_alignment = map { $_ => 'right' } qw(soll_eb haben_eb soll haben soll_kumuliert haben_kumuliert soll_saldo haben_saldo);

  map { $column_defs{$_}->{visible} =  1 } @columns;

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);

  $report->set_export_options('generate_trial_balance', @hidden_variables);

  my @options;


  $form->{template_fromto} = $locale->date(\%myconfig, $form->{fromdate}, 0) . " - " . $locale->date(\%myconfig, $form->{todate}, 0);

  $form->{print_date} = $locale->text('Create Date') . " " . $locale->date(\%myconfig, $form->current_date(\%myconfig), 0);
  push (@options, $form->{print_date});

  $form->{company} = $locale->text('Company') . " " . $defaults->company;
  push (@options, $form->{company});

  if ($::form->{customer_id}) {
    my $customer = SL::DB::Manager::Customer->find_by(id => $::form->{customer_id});
    push @options, $::locale->text('Customer') . ' ' . $customer->displayable_name;
  }


  $form->{template_to} = $locale->date(\%myconfig, $form->{todate}, 0);

  my @custom_headers = ([
    { text => $::locale->text('Account'),          rowspan => 2, },
    { text => $::locale->text('Description'),      rowspan => 2, },
    { text => $::locale->text('Last Transaction'), rowspan => 2, },
    { text => $::locale->text('Starting Balance'), colspan => 2, },
    { text => $::locale->text('Sum for')   . " $form->{template_fromto}", colspan => 2, },
    { text => $::locale->text('Sum per')   . " $form->{template_to}",     colspan => 2, },
    { text => $::locale->text('Saldo per') . " $form->{template_to}",     colspan => 2, },
  ], [
    { text => '', },
    { text => '', },
    { text => '', },
    { text => $::locale->text('Assets'), },
    { text => $::locale->text('Equity'), },
    { text => $::locale->text('Debit'),  },
    { text => $::locale->text('Credit'), },
    { text => $::locale->text('Debit'),  },
    { text => $::locale->text('Credit'), },
    { text => $::locale->text('Debit'),  },
    { text => $::locale->text('Credit'), },
  ]);

  $report->set_options('output_format'        => 'HTML',
                       'top_info_text'        => join("\n", @options),
                       'title'                => $form->{title},
                       'attachment_basename'  => $attachment_basename . strftime('_%Y%m%d', localtime time),
                       'html_template'        => 'rp/html_report_susa',
                       'pdf_template'         => 'rp/html_report_susa',
    );
  $report->set_custom_headers(@custom_headers);
  $report->set_options_from_form();
  $locale->set_numberformat_wo_thousands_separator(\%myconfig) if lc($report->{options}->{output_format}) eq 'csv';

  # add sort and escape callback, this one we use for the add sub
  $form->{callback} = $href .= "&sort=$form->{sort}";

  # escape callback for href
  my $callback = $form->escape($href);

  my @subtotal_columns = qw(soll_eb haben_eb soll haben soll_kumuliert haben_kumuliert soll_saldo haben_saldo);

  my %totals    = map { $_ => 0 } @subtotal_columns;

  my $edit_url = build_std_url('action=edit', 'type', 'vc');

  my $idx;
  foreach my $accno (@{ $form->{TB} || [] }) {

    $accno->{soll} = $accno->{debit};
    $accno->{haben} = $accno->{credit};
    map { $totals{$_}    += $accno->{$_} } @subtotal_columns;

    map { $accno->{$_} = $accno->{$_} == 0 ? '' : $form->format_amount(\%myconfig, $accno->{$_}, 2) }
      qw(soll_eb haben_eb soll haben soll_kumuliert haben_kumuliert soll_saldo haben_saldo);

    my $row = { };

    foreach my $column (@columns) {
      $row->{$column} = {
        'data'  => $accno->{$column},
        'align' => $column_alignment{$column},
      };
    }

    $row->{accno}->{link} = build_std_url('script=ca.pl', 'action=list_transactions', 'accno=' . E($accno->{accno}), 'description=' . E($accno->{description}), 'fromdate=' . E($form->{fromdate}), 'todate=' . E($form->{todate}), 'method=' . E($form->{method}));

    my $row_set = [ $row ];


    $report->add_data($row_set);

    $idx++;
  }

  $report->add_separator();

  $report->add_data(create_subtotal_row(\%totals, \@columns, \%column_alignment, \@subtotal_columns, 'listtotal'));

  $report->generate_with_headers();

  $main::lxdebug->leave_sub();

}

sub create_subtotal_row {
  $main::lxdebug->enter_sub();

  my ($totals, $columns, $column_alignment, $subtotal_columns, $class) = @_;

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  my $row = { map { $_ => { 'data' => '', 'class' => $class, 'align' => $column_alignment->{$_}, } } @{ $columns } };

  map { $row->{$_}->{data} = $form->format_amount(\%myconfig, $totals->{$_}, 2) } @{ $subtotal_columns };

  $row->{tax}->{data} = $form->format_amount(\%myconfig, $totals->{amount} - $totals->{netamount}, 2);

  map { $totals->{$_} = 0 } @{ $subtotal_columns };

  $main::lxdebug->leave_sub();

  return $row;
}

sub create_list_accounts_subtotal_row {
  $main::lxdebug->enter_sub();

  my ($subtotals, $columns, $fields, $class) = @_;

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  my $row = { map { $_ => { 'data' => '', 'class' => $class, 'align' => 'right' } } @{ $columns } };

  map { $row->{$_}->{data} = $form->format_amount(\%myconfig, $subtotals->{$_}, 2) } @{ $fields };

  $main::lxdebug->leave_sub();

  return $row;
}

sub list_accounts {
  $main::lxdebug->enter_sub();

  my ($action) = @_;

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  my @options;
  if ($form->{department}) {
    my ($department) = split /--/, $form->{department};
    push @options, $locale->text('Department') . " : $department";
  }
  if ($form->{projectnumber}) {
    push @options, $locale->text('Project Number') . " : $form->{projectnumber}";
  }

  # if there are any dates
  if ($form->{fromdate} || $form->{todate}) {
    my ($fromdate, $todate);

    if ($form->{fromdate}) {
      $fromdate = $locale->date(\%myconfig, $form->{fromdate}, 1);
    }
    if ($form->{todate}) {
      $todate = $locale->date(\%myconfig, $form->{todate}, 1);
    }

    push @options, "$fromdate - $todate";

  } else {
    push @options, $locale->date(\%myconfig, $form->current_date(\%myconfig), 1);
  }

  my @columns     = qw(accno description begbalance debit credit endbalance);
  my %column_defs = (
    'accno'       => { 'text' => $locale->text('Account'), },
    'description' => { 'text' => $locale->text('Description'), },
    'debit'       => { 'text' => $locale->text('Debit'), },
    'credit'      => { 'text' => $locale->text('Credit'), },
    'begbalance'  => { 'text' => $locale->text('Balance'), },
    'endbalance'  => { 'text' => $locale->text('Balance'), },
  );
  my %column_alignment = map { $_ => 'right' } qw(debit credit begbalance endbalance);

  my @hidden_variables = qw(fromdate todate department l_heading l_subtotal all_accounts sort accounttype eur projectnumber project_id title nextsub);

  $form->{callback} = build_std_url("action=$action", grep { $form->{$_} } @hidden_variables);

  my $report = SL::ReportGenerator->new(\%myconfig, $form);

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

  $report->set_export_options($action, @hidden_variables);

  my @totals_columns = qw(credit debit begbalance endbalance);
  my %subtotals      = map { $_ => 0 } @totals_columns;
  my %totals         = map { $_ => 0 } @totals_columns;
  my $found_heading  = 0;
  my @tb             = sort { $a->{accno} cmp $b->{accno} } @{ $form->{TB} || [] };

  # sort the whole thing by account numbers and display
  foreach my $idx (0 .. scalar(@tb) - 1) {
    my $ref  = $tb[$idx];
    my $href = build_std_url('script=ca.pl', 'action=list_transactions', 'accno=' . E($ref->{accno}), 'description=' . E($ref->{description}), @hidden_variables);

    my $ml   = ($ref->{category} =~ /(A|C|E)/) ? -1 : 1;

    my $row  = { map { $_ => { 'align' => $column_alignment{$_} } } @columns };

    if ($ref->{charttype} eq 'H') {
      next unless ($form->{l_heading});

      %subtotals                   = map { $_ => 0 } @totals_columns;
      $found_heading               = 1;
      $row->{description}->{class} = 'listheading';
      $row->{description}->{data}  = $ref->{description};

      $report->add_data($row);

      next;
    }

    foreach (qw(debit credit)) {
      $subtotals{$_} += $ref->{$_};
      $totals{$_}    += $ref->{$_};
    }

    $subtotals{begbalance} += $ref->{balance} * $ml;
    $subtotals{endbalance} += ($ref->{balance} + $ref->{amount}) * $ml;

    map { $row->{$_}->{data} = $ref->{$_} } qw(accno description);
    map { $row->{$_}->{data} = $form->format_amount(\%myconfig, $ref->{$_}, 2) if ($ref->{$_} != 0) } qw(credit debit);

    $row->{begbalance}->{data} = $form->format_amount(\%myconfig, $ref->{balance} * $ml, 2);
    $row->{endbalance}->{data} = $form->format_amount(\%myconfig, ($ref->{balance} + $ref->{amount}) * $ml, 2);

    $report->add_data($row);

    if ($form->{l_heading} && $found_heading &&
        (($idx == scalar(@tb) - 1) || ('H' eq $tb[$idx + 1]->{charttype}))) {
      $report->add_data(create_list_accounts_subtotal_row(\%subtotals, \@columns, \@totals_columns, 'listsubtotal'));
    }
  }

  $report->add_separator();

  $report->add_data(create_list_accounts_subtotal_row(\%totals, \@columns, [ qw(debit credit) ], 'listtotal'));

  $report->generate_with_headers();

  $main::lxdebug->leave_sub();
}

sub generate_ar_aging {
  $main::lxdebug->enter_sub();

  $main::auth->assert('general_ledger | ar_transactions');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  # split customer
  ($form->{customer}) = split(/--/, $form->{customer});

  $form->{ct}   = "customer";
  $form->{arap} = "ar";

  $form->{callback} = build_std_url('action=generate_ar_aging', qw(todate customer title));

  RP->aging(\%myconfig, \%$form);
  aging();

  $main::lxdebug->leave_sub();
}

sub generate_ap_aging {
  $main::lxdebug->enter_sub();

  $main::auth->assert('general_ledger | ap_transactions');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  # split vendor
  ($form->{vendor}) = split(/--/, $form->{vendor});

  $form->{ct}   = "vendor";
  $form->{arap} = "ap";

  $form->{callback} = build_std_url('action=generate_ap_aging', qw(todate vendor title));

  RP->aging(\%myconfig, \%$form);
  aging();

  $main::lxdebug->leave_sub();
}

sub create_aging_subtotal_row {
  $main::lxdebug->enter_sub();

  my ($subtotals, $columns, $periods, $class) = @_;

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  my $row = { map { $_ => { 'data' => '', 'class' => $class, 'align' => 'right' } } @{ $columns } };

  foreach (@{ $periods }) {
    $row->{"$_"}->{data} = $subtotals->{$_} != 0 ? $form->format_amount(\%myconfig, $subtotals->{$_}, 2) : '';
    $subtotals->{$_}      = 0;
  }

  $main::lxdebug->leave_sub();

  return $row;
}

sub aging {
  $main::lxdebug->enter_sub();

  $main::auth->assert('general_ledger');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;
  my $cgi      = $::request->{cgi};

  my $report = SL::ReportGenerator->new(\%myconfig, $form);

  my @columns = qw(statement ct invnumber transdate duedate amount open);

  my %column_defs = (
    'statement' => { raw_header_data => SL::Presenter::Tag::checkbox_tag("checkall", checkall => '[name^=statement_]'), 'visible' => $form->{ct} eq 'customer' ? 'HTML' : 0, align => "center" },
    'ct'        => { 'text' => $form->{ct} eq 'customer' ? $locale->text('Customer') : $locale->text('Vendor'), },
    'invnumber' => { 'text' => $locale->text('Invoice'), },
    'transdate' => { 'text' => $locale->text('Date'), },
    'duedate'   => { 'text' => $locale->text('Due'), },
    'amount'    => { 'text' => $locale->text('Amount'), },
    'open'      => { 'text' => $locale->text('Open'), },
  );

  my %column_alignment = ('statement' => 'center',
                          map { $_ => 'right' } qw(open amount));

  $report->set_options('std_column_visibility' => 1);
  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  my @hidden_variables = qw(todate customer vendor arap title ct fordate reporttype department fromdate);
  $report->set_export_options('generate_' . ($form->{arap} eq 'ar' ? 'ar' : 'ap') . '_aging', @hidden_variables);

  my @options;
  my $attachment_basename;

  if ($form->{department}) {
    my ($department) = split /--/, $form->{department};
    push @options, $locale->text('Department') . " : $department";
    $form->{callback} .= "&department=" . E($department);
  }

  if (($form->{arap} eq 'ar') && $form->{customer}) {
    push @options, $form->{customer};
    $attachment_basename = $locale->text('ar_aging_list');
    $form->{title} = sprintf($locale->text('Ar aging on %s'), $form->{todate});
  }

  if (($form->{arap} eq 'ap') && $form->{vendor}) {
    push @options, $form->{vendor};
    $attachment_basename = $locale->text('ap_aging_list');
    $form->{title} = sprintf($locale->text('Ap aging on %s'), $form->{todate});
  }

  if ($form->{fromdate}) {
    push @options, $locale->text('for Period') . " " . $locale->text('From') . " " .$locale->date(\%myconfig, $form->{fromdate}, 1) . " " . $locale->text('Bis') . " " . $locale->date(\%myconfig, $form->{todate}, 1);
  } else {
    push @options, $locale->text('for Period') . " " . $locale->text('Bis') . " " . $locale->date(\%myconfig, $form->{todate}, 1);
  }

  $attachment_basename = $form->{ct} eq 'customer' ? $locale->text('ar_aging_list') : $locale->text('ap_aging_list');

  $report->set_options('top_info_text'        => join("\n", @options),
                       'output_format'        => 'HTML',
                       'title'                => $form->{title},
                       'attachment_basename'  => $attachment_basename . strftime('_%Y%m%d', localtime time),
    );
  $report->set_options_from_form();
  $locale->set_numberformat_wo_thousands_separator(\%myconfig) if lc($report->{options}->{output_format}) eq 'csv';

  my $previous_ctid = 0;
  my $row_idx       = 0;
  my @periods       = qw(open amount);
  my %subtotals     = map { $_ => 0 } @periods;
  my %totals        = map { $_ => 0 } @periods;

  foreach my $ref (@{ $form->{AG} }) {
    if ($row_idx && ($previous_ctid != $ref->{ctid})) {
      $report->add_data(create_aging_subtotal_row(\%subtotals, \@columns, \@periods, 'listsubtotal'));
    }

    foreach my $key (@periods) {
      $subtotals{$key}  += $ref->{"$key"};
      $totals{$key}     += $ref->{"$key"};
      $ref->{"$key"}  = $ref->{"$key"} != 0 ? $form->format_amount(\%myconfig, $ref->{"$key"}, 2) : '';
    }

    my $row = { };

    foreach my $column (@columns) {
      $row->{$column} = {
        'data'   => (($column eq 'ct') || ($column eq 'statement')) ? '' : $ref->{$column},
        'align'  => $column_alignment{$column},
        'valign' => $column eq 'statement' ? 'center' : '',
      };
    }

    $row->{invnumber}->{link} =  build_std_url("script=$ref->{module}.pl", 'action=edit', 'callback', 'id=' . E($ref->{id}));

    if ($previous_ctid != $ref->{ctid}) {
      $row->{statement}->{raw_data} =
          $cgi->hidden('-name' => "customer_id_" . ($row_idx + 1), '-value' => $ref->{ctid})
        . $cgi->checkbox('-name' => "statement_" . ($row_idx + 1), '-value' => 1, '-label' => '', 'checked' => $ref->{checked});
      $row->{ct}->{data} = $ref->{name};

      $row_idx++;
    }

    $previous_ctid = $ref->{ctid};

    $report->add_data($row);
  }

  $report->add_data(create_aging_subtotal_row(\%subtotals, \@columns, \@periods, 'listsubtotal')) if ($row_idx);

  $report->add_data(create_aging_subtotal_row(\%totals, \@columns, \@periods, 'listtotal'));

  if ($form->{arap} eq 'ar') {
    my $raw_top_info_text    = $form->parse_html_template('rp/aging_ar_top');
    my $raw_bottom_info_text = $form->parse_html_template('rp/aging_ar_bottom', { 'row_idx' => $row_idx,
                                                                               'PRINT_OPTIONS' => print_options(inline => 1), });
    $report->set_options('raw_top_info_text'    => $raw_top_info_text,
                         'raw_bottom_info_text' => $raw_bottom_info_text);
  }

  setup_rp_aging_action_bar(arap => $form->{arap});
  $report->generate_with_headers();

  $main::lxdebug->leave_sub();
}

sub send_email {
  $main::lxdebug->enter_sub();

  $main::auth->assert('general_ledger');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $form->{subject} = $locale->text('Statement') . qq| - $form->{todate}|
    unless $form->{subject};

  RP->aging(\%myconfig, \%$form);

  $form->{"statement_1"} = 1;

  my $email_form  = delete $form->{email_form};
  my %field_names = (to => 'email');

  $form->{ $field_names{$_} // $_ } = $email_form->{$_} for keys %{ $email_form };

  $form->{media} = 'email';
  print_form();

  $form->redirect($locale->text('Statement sent to') . " $form->{$form->{ct}}");

  $main::lxdebug->leave_sub();
}

sub print {
  $main::lxdebug->enter_sub();

  $main::auth->assert('general_ledger');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  if ($form->{media} eq 'printer') {
    $form->error($locale->text('Select postscript or PDF!'))
      if ($form->{format} !~ /(postscript|pdf)/);
  }

  my $selected = 0;
  for my $i (1 .. $form->{rowcount}) {
    if ($form->{"statement_$i"}) {
      $form->{"$form->{ct}_id"} = $form->{"$form->{ct}_id_$i"};
      $selected = 1;
      last;
    }
  }

  $form->error($locale->text('Nothing selected!')) unless $selected;

  if ($form->{media} eq 'printer') {
    $form->{"$form->{ct}_id"} = "";
  } else {
    $form->{"statement_1"} = 1;
  }

  RP->aging(\%myconfig, \%$form);

  print_form();

  $form->redirect($locale->text('Statements sent to printer!'))
    if ($form->{media} eq 'printer');

  $main::lxdebug->leave_sub();
}

sub print_form {
  $main::lxdebug->enter_sub();

  $main::auth->assert('general_ledger');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  my $defaults = SL::DB::Default->get;
  $form->error($::locale->text('No print templates have been created for this client yet. Please do so in the client configuration.')) if !$defaults->templates;
  $form->{templates} = $defaults->templates;

  $form->{statementdate} = $locale->date(\%myconfig, $form->{todate}, 1);

  my $suffix = "html";
  my $attachment_suffix = "html";
  if ($form->{format} eq 'postscript') {
    $form->{postscript} = 1;
    $suffix = "tex";
    $attachment_suffix = "ps";
  } elsif ($form->{format} eq 'pdf') {
    $form->{pdf} = 1;
    $suffix = "tex";
    $attachment_suffix = "pdf";
  }

  $form->{IN}  = "$form->{type}.$suffix";
  $form->{OUT} = $form->{media} eq 'printer' ? "| $myconfig{printer}" : "";

  # Save $form->{email} because it will be overwritten.
  $form->{EMAIL_RECIPIENT} = $form->{email};

  my $i = 0;
  my $ctid;
  while (@{ $form->{AG} }) {

    my $ref = shift @{ $form->{AG} };

    if ($ctid != $ref->{ctid}) {

      $ctid = $ref->{ctid};
      $i++;

      if ($form->{"statement_$i"}) {

        my @a =
          ("name", "street", "zipcode", "city", "country", "contact", "email",
           "$form->{ct}phone", "$form->{ct}fax");
        map { $form->{$_} = $ref->{$_} } @a;

        $form->{ $form->{ct} } = $form->{name};
        $form->{"$form->{ct}_id"} = $ref->{ctid};

        map { $form->{$_} = () } qw(invnumber invdate duedate amount open);
        $form->{total} = 0;
        foreach my $item (qw(c0 c30 c60 c90)) {
          $form->{$item} = ();
          $form->{"${item}total"} = 0;
        }

        &statement_details($ref);

        while ($ref) {

          if (scalar(@{ $form->{AG} }) > 0) {

            # one or more left to go
            if ($ctid == $form->{AG}->[0]->{ctid}) {
              $ref = shift @{ $form->{AG} };
              &statement_details($ref);

              # any more?
              $ref = scalar(@{ $form->{AG} });
            } else {
              $ref = 0;
            }
          } else {

            # set initial ref to 0
            $ref = 0;
          }

        }

        map {
          $form->{"${_}total"} =
            $form->format_amount(\%myconfig, $form->{"${_}total"}, 2)
        } ('c0', 'c30', 'c60', 'c90', "");

        $form->{attachment_filename} =  $locale->quote_special_chars('filenames', $locale->text("Statement") . "_$form->{todate}.$attachment_suffix");
        $form->{attachment_filename} =~ s/\s+/_/g;

        $form->parse_template(\%myconfig);

      }
    }
  }
  # saving the history
  if(!exists $form->{addition} && $form->{id} ne "") {
    $form->{snumbers} = qq|ordnumber_| . $form->{ordnumber};
    $form->{addition} = "PRINTED";
    $form->{what_done} = $form->{type};
    $form->save_history;
  }
  # /saving the history
  $main::lxdebug->leave_sub();
}

sub statement_details {
  $main::lxdebug->enter_sub();

  $main::auth->assert('general_ledger');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  my ($ref) = @_;

  push @{ $form->{invnumber} }, $ref->{invnumber};
  push @{ $form->{invdate} },   $ref->{transdate};
  push @{ $form->{duedate} },   $ref->{duedate};
  push @{ $form->{amount} },    $form->format_amount(\%myconfig, $ref->{amount} / $ref->{exchangerate}, 2);
  push @{ $form->{open} },      $form->format_amount(\%myconfig, $ref->{open} / $ref->{exchangerate}, 2);

  foreach my $item (qw(c0 c30 c60 c90)) {
    if ($ref->{exchangerate} * 1) {
      # add only the open amount of the invoice to the aging, not the total amount
      $ref->{"${item}"} = $form->round_amount($ref->{open} / $ref->{exchangerate}, 2) if $ref->{overduedays} < 30 and $item eq 'c0';
      $ref->{"${item}"} = $form->round_amount($ref->{open} / $ref->{exchangerate}, 2) if $ref->{overduedays} >= 30 and $ref->{overduedays} < 60 and $item eq 'c30';
      $ref->{"${item}"} = $form->round_amount($ref->{open} / $ref->{exchangerate}, 2) if $ref->{overduedays} >= 60 and $ref->{overduedays} < 90 and $item eq 'c60';
      $ref->{"${item}"} = $form->round_amount($ref->{open} / $ref->{exchangerate}, 2) if $ref->{overduedays} >= 90 and $item eq 'c90';
    }
    $form->{"${item}total"} += $ref->{$item};
    $form->{total}          += $ref->{$item};
    push @{ $form->{$item} },
      $form->format_amount(\%myconfig, $ref->{$item}, 2);
  }

  $main::lxdebug->leave_sub();
}

sub generate_tax_report {
  $::lxdebug->enter_sub;
  $::auth->assert('report');

  RP->tax_report(\%::myconfig, $::form);

  my $descvar     = "$::form->{accno}_description";
  my ($subtotalnetamount, $subtotaltax, $subtotal) = (0, 0, 0);

  # construct href
  my $href     =
  my $callback = build_std_url('action=generate_tax_report', $descvar,
    qw(fromdate todate db method accno department report title));

  my @columns = $::form->sort_columns(qw(id transdate invnumber name netamount tax amount));
  my @column_index;

  for my $item (@columns, 'subtotal') {
    if ($::form->{"l_$item"} eq "Y") {
      $callback .= "&l_$item=Y";
      $href     .= "&l_$item=Y";
    }
  }

  for my $item (@columns) {
    if ($::form->{"l_$item"} eq "Y") {
      push @column_index, $item;
    }
  }

  my @options;
  if ($::form->{department}) {
    my ($department) = split /--/, $::form->{department};
    push @options, $::locale->text('Department') . " : $department";
  }

  # if there are any dates
  if ($::form->{fromdate} || $::form->{todate}) {
    my $fromdate = $::form->{fromdate} ? $::locale->date(\%::myconfig, $::form->{fromdate}, 1) : '';
    my $todate   = $::form->{todate}   ? $::locale->date(\%::myconfig, $::form->{todate}, 1)   : '';
    push @options, "$fromdate - $todate";
  } else {
    push @options, $::locale->date(\%::myconfig, $::form->current_date, 1);
  }

  my ($name, $invoice, $arap);
  if ($::form->{db} eq 'ar') {
    $name    = $::locale->text('Customer');
    $invoice = 'is.pl';
    $arap    = 'ar.pl';
  }
  if ($::form->{db} eq 'ap') {
    $name    = $::locale->text('Vendor');
    $invoice = 'ir.pl';
    $arap    = 'ap.pl';
  }

  my %column_header = (
    id        => $::locale->text('ID'),
    invnumber => $::locale->text('Invoice'),
    transdate => $::locale->text('Date'),
    netamount => $::locale->text('Amount'),
    tax       => $::locale->text('Tax'),
    amount    => $::locale->text('Total'),
    name      => $name,
  );

  my %column_sorted = map { $_ => 1 } qw(id invnumber transdate);

  $callback .= "&sort=$::form->{sort}";

  my $sameitem;
  if (@{ $::form->{TR} }) {
    $sameitem = $::form->{TR}->[0]->{ $::form->{sort} };
  }

  my ($totalnetamount, $totaltax, @data);
  for my $ref (@{ $::form->{TR} }) {

    my $module = ($ref->{invoice}) ? $invoice : $arap;

    if ($::form->{l_subtotal} eq 'Y') {
      if ($sameitem ne $ref->{ $::form->{sort} }) {
        push @data, {
          subtotal  => 1,
          netamount => $subtotalnetamount,
          tax       => $subtotaltax,
          amount    => $subtotal,
        };
        $subtotalnetamount = 0;
        $subtotaltax       = 0;
        $sameitem          = $ref->{ $::form->{sort} };
      }
    }

    $subtotalnetamount += $ref->{netamount};
    $subtotaltax       += $ref->{tax};
    $totalnetamount    += $ref->{netamount};
    $totaltax          += $ref->{tax};
    $ref->{amount}      = $ref->{netamount} + $ref->{tax};

    push @data, { map { $_ => { data => $ref->{$_} } } keys %$ref };
    $data[-1]{invnumber}{link} = "$module?action=edit&id=$ref->{id}&callback=$callback";
    $data[-1]{$_}{numeric}     = 1 for qw(netamount tax amount);
  }

  if ($::form->{l_subtotal} eq 'Y') {
    push @data, {
      subtotal  => 1,
      netamount => $subtotalnetamount,
      tax       => $subtotaltax,
      amount    => $subtotal,
    };
  }

  push @data, {
    total     => 1,
    netamount => $totalnetamount,
    tax       => $totaltax,
    amount    => $totalnetamount + $totaltax,
  };

  $::form->header;
  print $::form->parse_html_template('rp/tax_report', {
    column_index  => \@column_index,
    column_header => \%column_header,
    column_sorted => \%column_sorted,
    sort_base     => $href,
    DATA          => \@data,
    options       => \@options,
  });

  $::lxdebug->leave_sub;
}

sub list_payments {
  $main::lxdebug->enter_sub();

  $main::auth->assert('cash');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  if ($form->{account}) {
    ($form->{paymentaccounts}) = split /--/, $form->{account};
  }

  my $option;
  if ($form->{department}) {
    (my $department, $form->{department_id}) = split /--/, $form->{department};
    $option = $locale->text('Department') . " : $department";
  }

  report_generator_set_default_sort('transdate', 1);

  RP->payments(\%myconfig, \%$form);

  my @hidden_variables = qw(account title department reference source memo fromdate todate
                            fx_transaction db prepayment paymentaccounts sort);

  my $href = build_std_url('action=list_payments', grep { $form->{$_} } @hidden_variables);
  $form->{callback} = $href;

  my @columns     = qw(transdate invnumber name paid source memo);
  my %column_defs = (
    'name'      => { 'text' => $locale->text('Description'), },
    'invnumber' => { 'text' => $locale->text('Reference'), },
    'transdate' => { 'text' => $locale->text('Date'), },
    'paid'      => { 'text' => $locale->text('Amount'), },
    'source'    => { 'text' => $locale->text('Source'), },
    'memo'      => { 'text' => $locale->text('Memo'), },
  );
  my %column_alignment = ('paid' => 'right');

  foreach my $name (grep { $_ ne 'paid' } @columns) {
    my $sortdir                 = $form->{sort} eq $name ? 1 - $form->{sortdir} : $form->{sortdir};
    $column_defs{$name}->{link} = $href . "&sort=${name}&sortdir=$sortdir";
  }

  my @options;
  if ($form->{fromdate}) {
    push @options, $locale->text('From') . " " . $locale->date(\%myconfig, $form->{fromdate}, 1);
  }
  if ($form->{todate}) {
    push @options, $locale->text('bis') . " " . $locale->date(\%myconfig, $form->{todate}, 1);
  }

  my $report = SL::ReportGenerator->new(\%myconfig, $form);

  my $attachment_basename = $form->{db} eq 'ar' ? $locale->text('list_of_receipts') : $locale->text('list_of_payments');

  $report->set_options('top_info_text'         => join("\n", @options),
                       'output_format'         => 'HTML',
                       'title'                 => $form->{title},
                       'attachment_basename'   => $attachment_basename . strftime('_%Y%m%d', localtime time),
                       'std_column_visibility' => 1,
    );
  $report->set_options_from_form();

  $locale->set_numberformat_wo_thousands_separator(\%myconfig) if lc($report->{options}->{output_format}) eq 'csv';

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);

  $report->set_export_options('list_payments', @hidden_variables, qw(sort sortdir));

  $report->set_sort_indicator($form->{sort}, $form->{sortdir});

  my $total_paid    = 0;

  foreach my $ref (sort { $a->{accno} cmp $b->{accno} } @{ $form->{PR} }) {
    next unless @{ $form->{ $ref->{id} } };

    $report->add_control({ 'type' => 'colspan_data', 'data' => "$ref->{accno}--$ref->{description}" });

    my $subtotal_paid = 0;

    foreach my $payment (@{ $form->{ $ref->{id} } }) {
      my $module = $payment->{module};
      $module = 'is' if ($payment->{invoice} && $payment->{module} eq 'ar');
      $module = 'ir' if ($payment->{invoice} && $payment->{module} eq 'ap');

      $subtotal_paid += $payment->{paid};
      $total_paid    += $payment->{paid};

      $payment->{paid} = $form->format_amount(\%myconfig, $payment->{paid}, 2);

      my $row = { };

      foreach my $column (@columns) {
        $row->{$column} = {
          'data'  => $payment->{$column},
          'align' => $column_alignment{$column},
        };
      }

      $row->{invnumber}->{link} = build_std_url("script=${module}.pl", 'action=edit', 'id=' . E($payment->{id}), 'callback');

      $report->add_data($row);
    }

    my $row = { map { $_ => { 'class' => 'listsubtotal' } } @columns };
    $row->{paid} = {
      'data'  => $form->format_amount(\%myconfig, $subtotal_paid, 2),
      'align' => 'right',
      'class' => 'listsubtotal',
    };

    $report->add_data($row);
  }

  $report->add_separator();

  my $row = { map { $_ => { 'class' => 'listtotal' } } @columns };
  $row->{paid} = {
    'data'  => $form->format_amount(\%myconfig, $total_paid, 2),
    'align' => 'right',
    'class' => 'listtotal',
  };

  $report->add_data($row);

  $report->generate_with_headers();

  $main::lxdebug->leave_sub();
}

sub print_options {
  $::lxdebug->enter_sub;

  my ($dont_print) = @_;

  $::form->{sendmode} = "attachment";
  $::form->{format} ||= $::myconfig{template_format} || "pdf";
  $::form->{copies} ||= $::myconfig{copies}          || 2;

  $::form->{PD}{ $::form->{type} }     = "selected";
  $::form->{DF}{ $::form->{format} }   = "selected";
  $::form->{OP}{ $::form->{media} }    = "selected";
  $::form->{SM}{ $::form->{sendmode} } = "selected";

  my $output = $::form->parse_html_template('rp/print_options', {
    is_email    => $::form->{media} eq 'email',
  });

  print $output unless $dont_print;

  $::lxdebug->leave_sub;

  return $output;
}

sub generate_bwa {
  $main::lxdebug->enter_sub();

  $main::auth->assert('report');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $form->{padding} = "&nbsp;&nbsp;";
  $form->{bold}    = "<b>";
  $form->{endbold} = "</b>";
  $form->{br}      = "<br>";

  if ($form->{reporttype} eq "custom") {

    #forgotten the year --> thisyear
    if ($form->{year} !~ m/^\d\d\d\d$/) {
      $locale->date(\%myconfig, $form->current_date(\%myconfig), 0) =~
        /(\d\d\d\d)/;
      $form->{year} = $1;
    }

    #yearly report
    if ($form->{duetyp} eq "13") {
      $form->{fromdate}        = "1.1.$form->{year}";
      $form->{todate}          = "31.12.$form->{year}";
      $form->{comparefromdate} = "1.01.$form->{year}";
      $form->{comparetodate}   = "31.12.$form->{year}";
    }

    #Quater reports
    if ($form->{duetyp} eq "A") {
      $form->{fromdate}        = "1.1.$form->{year}";
      $form->{todate}          = "31.3.$form->{year}";
      $form->{comparefromdate} = "1.01.$form->{year}";
      $form->{comparetodate}   = "31.03.$form->{year}";
    }
    if ($form->{duetyp} eq "B") {
      $form->{fromdate}        = "1.4.$form->{year}";
      $form->{todate}          = "30.6.$form->{year}";
      $form->{comparefromdate} = "1.01.$form->{year}";
      $form->{comparetodate}   = "30.06.$form->{year}";
    }
    if ($form->{duetyp} eq "C") {
      $form->{fromdate}        = "1.7.$form->{year}";
      $form->{todate}          = "30.9.$form->{year}";
      $form->{comparefromdate} = "1.01.$form->{year}";
      $form->{comparetodate}   = "30.09.$form->{year}";
    }
    if ($form->{duetyp} eq "D") {
      $form->{fromdate}        = "1.10.$form->{year}";
      $form->{todate}          = "31.12.$form->{year}";
      $form->{comparefromdate} = "1.01.$form->{year}";
      $form->{comparetodate}   = "31.12.$form->{year}";
    }

    #Monthly reports
  SWITCH: {
      $form->{duetyp} eq "1" && do {
        $form->{fromdate}        = "1.1.$form->{year}";
        $form->{todate}          = "31.1.$form->{year}";
        $form->{comparefromdate} = "1.01.$form->{year}";
        $form->{comparetodate}   = "31.01.$form->{year}";
        last SWITCH;
      };
      $form->{duetyp} eq "2" && do {
        $form->{fromdate} = "1.2.$form->{year}";

        #this works from 1901 to 2099, 1900 and 2100 fail.
        my $leap = ($form->{year} % 4 == 0) ? "29" : "28";
        $form->{todate}          = "$leap.2.$form->{year}";
        $form->{comparefromdate} = "1.01.$form->{year}";
        $form->{comparetodate}   = "$leap.02.$form->{year}";
        last SWITCH;
      };
      $form->{duetyp} eq "3" && do {
        $form->{fromdate}        = "1.3.$form->{year}";
        $form->{todate}          = "31.3.$form->{year}";
        $form->{comparefromdate} = "1.01.$form->{year}";
        $form->{comparetodate}   = "31.03.$form->{year}";
        last SWITCH;
      };
      $form->{duetyp} eq "4" && do {
        $form->{fromdate}        = "1.4.$form->{year}";
        $form->{todate}          = "30.4.$form->{year}";
        $form->{comparefromdate} = "1.01.$form->{year}";
        $form->{comparetodate}   = "30.04.$form->{year}";
        last SWITCH;
      };
      $form->{duetyp} eq "5" && do {
        $form->{fromdate}        = "1.5.$form->{year}";
        $form->{todate}          = "31.5.$form->{year}";
        $form->{comparefromdate} = "1.01.$form->{year}";
        $form->{comparetodate}   = "31.05.$form->{year}";
        last SWITCH;
      };
      $form->{duetyp} eq "6" && do {
        $form->{fromdate}        = "1.6.$form->{year}";
        $form->{todate}          = "30.6.$form->{year}";
        $form->{comparefromdate} = "1.01.$form->{year}";
        $form->{comparetodate}   = "30.06.$form->{year}";
        last SWITCH;
      };
      $form->{duetyp} eq "7" && do {
        $form->{fromdate}        = "1.7.$form->{year}";
        $form->{todate}          = "31.7.$form->{year}";
        $form->{comparefromdate} = "1.01.$form->{year}";
        $form->{comparetodate}   = "31.07.$form->{year}";
        last SWITCH;
      };
      $form->{duetyp} eq "8" && do {
        $form->{fromdate}        = "1.8.$form->{year}";
        $form->{todate}          = "31.8.$form->{year}";
        $form->{comparefromdate} = "1.01.$form->{year}";
        $form->{comparetodate}   = "31.08.$form->{year}";
        last SWITCH;
      };
      $form->{duetyp} eq "9" && do {
        $form->{fromdate}        = "1.9.$form->{year}";
        $form->{todate}          = "30.9.$form->{year}";
        $form->{comparefromdate} = "1.01.$form->{year}";
        $form->{comparetodate}   = "30.09.$form->{year}";
        last SWITCH;
      };
      $form->{duetyp} eq "10" && do {
        $form->{fromdate}        = "1.10.$form->{year}";
        $form->{todate}          = "31.10.$form->{year}";
        $form->{comparefromdate} = "1.01.$form->{year}";
        $form->{comparetodate}   = "31.10.$form->{year}";
        last SWITCH;
      };
      $form->{duetyp} eq "11" && do {
        $form->{fromdate}        = "1.11.$form->{year}";
        $form->{todate}          = "30.11.$form->{year}";
        $form->{comparefromdate} = "1.01.$form->{year}";
        $form->{comparetodate}   = "30.11.$form->{year}";
        last SWITCH;
      };
      $form->{duetyp} eq "12" && do {
        $form->{fromdate}        = "1.12.$form->{year}";
        $form->{todate}          = "31.12.$form->{year}";
        $form->{comparefromdate} = "1.01.$form->{year}";
        $form->{comparetodate}   = "31.12.$form->{year}";
        last SWITCH;
      };
    }
    hotfix_reformat_date();
  } else {
    # die konvertierungen nur dann durchführen, wenn auch daten gesetzt sind.
    # ansonsten ist die prüfung in RP.pm
    # if (defined ($form->{fromdate|todate}=='..'))
    # immer wahr
    if ($form->{fromdate}){
      my $datetime = $locale->parse_date_to_object($form->{fromdate});
      $datetime->set( month      => 1,
                      day        => 1);
      $form->{comparefromdate} = $locale->format_date(\%::myconfig, $datetime);
    }
    if ($form->{todate}){
      $form->{comparetodate}   = $form->{todate};
    }
  }

  RP->bwa(\%myconfig, \%$form);

  ($form->{department}) = split /--/, $form->{department};

  $form->{period} =
    $locale->date(\%myconfig, $form->current_date(\%myconfig), 1);
  $form->{todate} = $form->current_date(\%myconfig) unless $form->{todate};

  # if there are any dates construct a where
  if ($form->{fromdate} || $form->{todate}) {

    unless ($form->{todate}) {
      $form->{todate} = $form->current_date(\%myconfig);
    }

    my %germandate = ("dateformat" => "dd.mm.yyyy");

    my $longtodate  = $locale->date(\%germandate, $form->{todate}, 1);
    my $shorttodate = $locale->date(\%germandate, $form->{todate}, 0);

    my $longfromdate  = $locale->date(\%germandate, $form->{fromdate}, 1);
    my $shortfromdate = $locale->date(\%germandate, $form->{fromdate}, 0);

    $form->{this_period} = "$shortfromdate\n$shorttodate";
    $form->{period}      =
        $locale->text('for Period')
      . qq|\n$longfromdate |
      . $locale->text('bis')
      . qq| $longtodate|;
  }

  $form->{report_date} = $locale->text('Report date') . ": " . $form->current_date;

  if ( $form->{method} eq 'cash' ) {
    $form->{accounting_method} = $locale->text('Cash accounting');
  } elsif ( $form->{method} eq 'accrual' ) {
    $form->{accounting_method} = $locale->text('Accrual accounting');
  } else {
    $form->{accounting_method} = "";
  };

  $form->{title} = $locale->text('BWA');

  $::request->layout->add_stylesheets('bwa.css');
  $form->header;
  print $form->parse_html_template('rp/bwa');

  $main::lxdebug->leave_sub();
}
###
# Hotfix, um das Datumsformat, die unten hart auf deutsches Datumsformat eingestellt
# sind, entsprechend mit anderem Formaten (z.B. iso-kodiert) zum Laufen zu bringen (S.a.: Bug 1388)
sub hotfix_reformat_date {

  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  if ($myconfig{dateformat} ne 'dd.mm.yyyy'){
    my $current_dateformat = $myconfig{dateformat};
    $myconfig{dateformat} = 'dd.mm.yyyy';
    $form->{fromdate} = $main::locale->reformat_date(\%myconfig, $form->{fromdate}, $current_dateformat);
    $form->{todate} = $main::locale->reformat_date(\%myconfig, $form->{todate}, $current_dateformat);
    $form->{comparefromdate} = $main::locale->reformat_date(\%myconfig, $form->{comparefromdate}, $current_dateformat)
      unless (!defined ($form->{comparefromdate}));
    $form->{comparetodate} = $main::locale->reformat_date(\%myconfig, $form->{comparetodate}, $current_dateformat)
      unless (!defined ($form->{comparetodate}));

    # Und wieder zurücksetzen
    $myconfig{dateformat} =  $current_dateformat; #'dd.mm.yyyy';
  } # Ende Hotifx Bug 1388

  $main::lxdebug->leave_sub();

}

sub setup_rp_aging_action_bar {
  my %params = @_;

  return unless $params{arap} eq 'ar';

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      combobox => [
        action => [
          t8('Print'),
          call   => [ 'kivi.SalesPurchase.show_print_dialog' ],
          checks => [ [ 'kivi.check_if_entries_selected', '[name^=statement_]' ] ],
        ],
        action => [
          t8('E Mail'),
          call   => [ 'kivi.SalesPurchase.show_email_dialog', 'send_email' ],
          checks => [ [ 'kivi.check_if_entries_selected', '[name^=statement_]' ] ],
        ],
      ],
    );
  }
}

sub setup_rp_report_action_bar {
  my %params = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Continue'),
        submit    => [ '#form', { action => 'continue' } ],
        accesskey => 'enter',
      ],
    );
  }
}

1;
