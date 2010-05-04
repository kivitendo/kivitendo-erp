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
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#======================================================================
#
# module for preparing Income Statement and Balance Sheet
#
#======================================================================

use POSIX qw(strftime);

use SL::PE;
use SL::RP;
use SL::Iconv;
use SL::ReportGenerator;
use Data::Dumper;

require "bin/mozilla/arap.pl";
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
# $locale->text('Tax collected')
# $locale->text('Tax paid')
# $locale->text('Receipts')
# $locale->text('Payments')
# $locale->text('Project Transactions')
# $locale->text('Non-taxable Sales')
# $locale->text('Non-taxable Purchases')

# $form->parse_html_template('rp/html_report_susa')

my $rp_access_map = {
  'projects'         => 'report',
  'ar_aging'         => 'general_ledger',
  'ap_aging'         => 'general_ledger',
  'receipts'         => 'cash',
  'payments'         => 'cash',
  'trial_balance'    => 'report',
  'income_statement' => 'report',
  'bwa'              => 'report',
  'balance_sheet'    => 'report',
};

# subs use these pretty freely, so declare them here
our (%column_data, @column_index);
our ($subtotalnetamount, $subtotaltax, $subtotal);

sub check_rp_access {
  my $form     = $main::form;

  my $right   = $rp_access_map->{$form->{report}};
  $right    ||= 'DOES_NOT_EXIST';

  $main::auth->assert($right);
}

sub report {
  $main::lxdebug->enter_sub();

  check_rp_access();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  my %title = (
            'balance_sheet'        => 'Balance Sheet',
            'income_statement'     => 'Income Statement',
            'trial_balance'        => 'Trial Balance',
            'ar_aging'             => 'AR Aging',
            'ap_aging'             => 'Offene Verbindlichkeiten',
            'tax_collected'        => 'Tax collected',
            'tax_paid'             => 'Tax paid',
            'nontaxable_sales'     => 'Non-taxable Sales',
            'nontaxable_purchases' => 'Non-taxable Purchases',
            'receipts'             => 'Receipts',
            'payments'             => 'Payments',
            'projects'             => 'Project Transactions',
            'bwa'                  => 'Betriebswirtschaftliche Auswertung',
  );

  $form->{title} = $locale->text($title{ $form->{report} });

  my $accrual = ($main::eur) ? ""        : "checked";
  my $cash    = ($main::eur) ? "checked" : "";

  my $year = (localtime)[5] + 1900;

  # get departments
  $form->all_departments(\%myconfig);
  if (@{ $form->{all_departments} || [] }) {
    $form->{selectdepartment} = "<option>\n";
    map { $form->{selectdepartment} .= "<option>$_->{description}--$_->{id}\n" } @{ $form->{all_departments} || [] };
  }

  my $department = qq|
        <tr>
          <th align=right nowrap>| . $locale->text('Department') . qq|</th>
          <td colspan=3><select name=department>$form->{selectdepartment}</select></td>
        </tr>
| if $form->{selectdepartment};

  $form->get_lists("projects" => { "key" => "ALL_PROJECTS",
                                   "all" => 1 });

  my %project_labels = ();
  my @project_values = ("");
  foreach my $item (@{ $form->{"ALL_PROJECTS"} }) {
    push(@project_values, $item->{"id"});
    $project_labels{$item->{"id"}} = $item->{"projectnumber"};
  }

  my $projectnumber =
    NTI($main::cgi->popup_menu('-name' => "project_id",
                               '-values' => \@project_values,
                               '-labels' => \%project_labels));

  # use JavaScript Calendar or not
  $form->{jsscript} = 1;
  my $jsscript = "";
  my ( $name_1, $id_1, $value_1, $trigger_1, $name_2, $id_2, $value_2, $trigger_2, );
  if ($form->{report} eq "balance_sheet") {
    $name_1    = "asofdate";
    $id_1      = "asofdate";
    $value_1   = "$form->{asofdate}";
    $trigger_1 = "trigger1";
    $name_2    = "compareasofdate";
    $id_2      = "compareasofdate";
    $value_2   = "$form->{compareasofdate}";
    $trigger_2 = "trigger2";
  } elsif ($form->{report} =~ /(receipts|payments)$/) {
    $name_1    = "fromdate";
    $id_1      = "fromdate";
    $value_1   = "$form->{fromdate}";
    $trigger_1 = "trigger1";
    $name_2    = "todate";
    $id_2      = "todate";
    $value_2   = "";
    $trigger_2 = "trigger2";
  } elsif (($form->{report} eq "ar_aging") || ($form->{report} eq "ap_aging")) {
    $name_1    = "fromdate";
    $id_1      = "fromdate";
    $value_1   = "$form->{fromdate}";
    $trigger_1 = "trigger1";
    $name_2    = "todate";
    $id_2      = "todate";
    $value_2   = "";
    $trigger_2 = "trigger2";

  } else {
    $name_1    = "fromdate";
    $id_1      = "fromdate";
    $value_1   = "$form->{fromdate}";
    $trigger_1 = "trigger1";
    $name_2    = "todate";
    $id_2      = "todate";
    $value_2   = "";
    $trigger_2 = "trigger2";
  }

  my ($button1, $button1_2, $button2, $button2_2);
  my $checked;

  # with JavaScript Calendar
  if ($form->{jsscript}) {
    if ($name_1 eq "") {
      $button1   = qq| <input name=$name_2 id=$id_2 size=11 title="$myconfig{dateformat}" onBlur=\"check_right_date_format(this)\">|;
      $button1_2 = qq| <input type=button name=$name_2 id="$trigger_2" value=| . $locale->text('button') . qq|>|;

      #write Trigger
      $jsscript = Form->write_trigger(\%myconfig, "1", "$name_2", "BR", "$trigger_2");
    } else {
      $button1   = qq| <input name=$name_1 id=$id_1 size=11 title="$myconfig{dateformat}" value="$value_1" onBlur=\"check_right_date_format(this)\">|;
      $button1_2 = qq| <input type=button name=$name_1 id="$trigger_1" value=| . $locale->text('button') . qq|>|;
      $button2   = qq| <input name=$name_2 id=$id_2 size=11 title="$myconfig{dateformat}" onBlur=\"check_right_date_format(this)\">|;
      $button2_2 = qq| <input type=button name=$name_2 id="$trigger_2" value=| . $locale->text('button') . qq|> |;

      #write Trigger
      $jsscript = Form->write_trigger(\%myconfig, "2", "$name_1", "BR", "$trigger_1", "$name_2", "BL", "$trigger_2");
    }
  } else {

    # without JavaScript Calendar
    if ($name_1 eq "") {
      $button1 = qq|<input name=$name_2 id=$id_2 size=11 title="$myconfig{dateformat}" onBlur=\"check_right_date_format(this)\">|;
    } else {
      $button1 = qq|<input name=$name_1 id=$id_1 size=11 title="$myconfig{dateformat}" value=$value_1 onBlur=\"check_right_date_format(this)\">|;
      $button2 = qq|<input name=$name_2 id=$id_2 size=11 title="$myconfig{dateformat}" onBlur=\"check_right_date_format(this)\">|;
    }
  }
  $form->{javascript} .= qq|<script type="text/javascript" src="js/common.js"></script>|;
  $form->header;
  my $onload = qq|focus()|;
  $onload .= qq|;setupDateFormat('|. $myconfig{dateformat} .qq|', '|. $locale->text("Falsches Datumsformat!") .qq|')|;
  $onload .= qq|;setupPoints('|. $myconfig{numberformat} .qq|', '|. $locale->text("wrongformat") .qq|')|;
  print qq|
<body onLoad="$onload">

<form method=post action=$form->{script}>

<input type=hidden name=title value="$form->{title}">

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
      $department
|;

  if ($form->{report} eq "projects") {
    print qq|
        <tr>
          <th align=right nowrap>| . $locale->text('Project') . qq|</th>
          <td colspan=5><input name=projectnumber size=25</td>
        </tr>
        <input type=hidden name=nextsub value=generate_projects>
        <tr>
          <th align=right>| . $locale->text('From') . qq|</th>
          <td>$button1</td>
          <td>$button1_2</td>
          <th align=right>| . $locale->text('Bis') . qq|</th>
          <td>$button2</td>
          <td>$button2_2</td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td>
      <table>
        <tr>
          <th align=right nowrap>| . $locale->text('Include in Report') . qq|</th>
          <td><input name=l_heading class=checkbox type=checkbox value=Y>&nbsp;| . $locale->text('Heading') . qq|
          <input name=l_subtotal class=checkbox type=checkbox value=Y>&nbsp;| . $locale->text('Subtotal') . qq|</td>
        </tr>

$jsscript
|;
  }

  if ($form->{report} eq "income_statement") {
    print qq|
        <tr>
          <th align=right nowrap>| . $locale->text('Project') . qq|</th>
          <td colspan=3>$projectnumber</td>
        </tr>
        <input type=hidden name=nextsub value=generate_income_statement>
</table>
<table>
        <tr>
          <th align=left><input name=reporttype class=radio type=radio value="custom" checked> | . $locale->text('Customized Report') . qq|</th>
        </tr>
        <tr>
          <th colspan=1>| . $locale->text('Year') . qq|</th>
          <td><input name=year size=11 title="| . $locale->text('YYYY') . qq|" value="$year"></td>
        </tr>
|;

    print qq|
        <tr>
                <td align=right> <b> | . $locale->text('Yearly') . qq|</b> </td>
                <th align=left>| . $locale->text('Quarterly') . qq|</th>
                <th align=left colspan=3>| . $locale->text('Monthly') . qq|</th>
        </tr>
        <tr>
                <td align=right>&nbsp; <input name=duetyp class=radio type=radio value="13" "checked"></td>
                <td><input name=duetyp class=radio type=radio value="A" $checked >&nbsp;1. | . $locale->text('Quarter') . qq|</td>
|;
    $checked = "";
    print qq|
                <td><input name=duetyp class=radio type=radio value="1" $checked >&nbsp;| . $locale->text('January') . qq|</td>
|;
    $checked = "";
    print qq|
                <td><input name=duetyp class=radio type=radio value="5" $checked >&nbsp;| . $locale->text('May') . qq|</td>
                <td><input name=duetyp class=radio type=radio value="9" $checked >&nbsp;| . $locale->text('September') . qq|</td>

        </tr>
        <tr>
                <td align= right>&nbsp;</td>
                <td><input name=duetyp class=radio type=radio value="B" $checked>&nbsp;2. | . $locale->text('Quarter') . qq|</td>
                <td><input name=duetyp class=radio type=radio value="2" $checked >&nbsp;| . $locale->text('February') . qq|</td>
                <td><input name=duetyp class=radio type=radio value="6" $checked >&nbsp;| . $locale->text('June') . qq|</td>
                <td><input name=duetyp class=radio type=radio value="10" $checked >&nbsp;| . $locale->text('October') . qq|</td>
        </tr>
        <tr>
                <td> &nbsp;</td>
                <td><input name=duetyp class=radio type=radio value="C" $checked>&nbsp;3. | . $locale->text('Quarter') . qq|</td>
                <td><input name=duetyp class=radio type=radio value="3" $checked >&nbsp;| . $locale->text('March') . qq|</td>
                <td><input name=duetyp class=radio type=radio value="7" $checked >&nbsp;| . $locale->text('July') . qq|</td>
                <td><input name=duetyp class=radio type=radio value="11" $checked >&nbsp;| . $locale->text('November') . qq|</td>

        </tr>
        <tr>
                <td> &nbsp;</td>
                <td><input name=duetyp class=radio type=radio value="D" $checked>&nbsp;4. | . $locale->text('Quarter') . qq|&nbsp;</td>
                <td><input name=duetyp class=radio type=radio value="4" $checked >&nbsp;| . $locale->text('April') . qq|</td>
                <td><input name=duetyp class=radio type=radio value="8" $checked >&nbsp;| . $locale->text('August') . qq|</td>
                <td><input name=duetyp class=radio type=radio value="12" $checked >&nbsp;| . $locale->text('December') . qq|</td>

        </tr>
        <tr>
                   <td colspan=5><hr size=3 noshade></td>
        </tr>
        <tr>
          <th align=left><input name=reporttype class=radio type=radio value="free" $checked> | . $locale->text('Free report period') . qq|</th>
          <td align=left colspan=4>| . $locale->text('From') . qq|&nbsp;
              $button1
              $button1_2&nbsp;
              | . $locale->text('Bis') . qq|
              $button2
              $button2_2&nbsp;
          </td>
        </tr>
        <tr>
                   <td colspan=5><hr size=3 noshade></td>
        </tr>
        <tr>
          <th align=leftt>| . $locale->text('Method') . qq|</th>
          <td colspan=3><input name=method class=radio type=radio value=accrual $accrual>| . $locale->text('Accrual') . qq|
          &nbsp;<input name=method class=radio type=radio value=cash $cash>| . $locale->text('EUR') . qq|</td>
        </tr>

$jsscript
|;
  }

  if ($form->{report} eq "bwa") {
    print qq|
        <tr>
          <th align=right nowrap>| . $locale->text('Project') . qq|</th>
          <td colspan=3>$projectnumber</td>
        </tr>
        <input type=hidden name=nextsub value=generate_bwa>
</table>
<table>
        <tr>
          <th align=left><input name=reporttype class=radio type=radio value="custom" checked> | . $locale->text('Customized Report') . qq|</th>
        </tr>
        <tr>
          <th colspan=1>| . $locale->text('Year') . qq|</th>
          <td><input name=year size=11 title="| . $locale->text('YYYY') . qq|" value="$year"></td>
        </tr>
|;

    print qq|
        <tr>
                <td align=right> <b> | . $locale->text('Yearly') . qq|</b> </td>
                <th align=left>| . $locale->text('Quarterly') . qq|</th>
                <th align=left colspan=3>| . $locale->text('Monthly') . qq|</th>
        </tr>
        <tr>
                <td align=right>&nbsp; <input name=duetyp class=radio type=radio value="13"
$checked></td>
                <td><input name=duetyp class=radio type=radio value="A" $checked >&nbsp;1. | . $locale->text('Quarter') . qq|</td>
|;
    $checked = "checked";
    print qq|
                <td><input name=duetyp class=radio type=radio value="1" $checked >&nbsp;| . $locale->text('January') . qq|</td>
|;
    $checked = "";
    print qq|
                <td><input name=duetyp class=radio type=radio value="5" $checked >&nbsp;| . $locale->text('May') . qq|</td>
                <td><input name=duetyp class=radio type=radio value="9" $checked >&nbsp;| . $locale->text('September') . qq|</td>

        </tr>
        <tr>
                <td align= right>&nbsp;</td>
                <td><input name=duetyp class=radio type=radio value="B" $checked>&nbsp;2. | . $locale->text('Quarter') . qq|</td>
                <td><input name=duetyp class=radio type=radio value="2" $checked >&nbsp;| . $locale->text('February') . qq|</td>
                <td><input name=duetyp class=radio type=radio value="6" $checked >&nbsp;| . $locale->text('June') . qq|</td>
                <td><input name=duetyp class=radio type=radio value="10" $checked >&nbsp;| . $locale->text('October') . qq|</td>
        </tr>
        <tr>
                <td> &nbsp;</td>
                <td><input name=duetyp class=radio type=radio value="C" $checked>&nbsp;3. | . $locale->text('Quarter') . qq|</td>
                <td><input name=duetyp class=radio type=radio value="3" $checked >&nbsp;| . $locale->text('March') . qq|</td>
                <td><input name=duetyp class=radio type=radio value="7" $checked >&nbsp;| . $locale->text('July') . qq|</td>
                <td><input name=duetyp class=radio type=radio value="11" $checked >&nbsp;| . $locale->text('November') . qq|</td>

        </tr>
        <tr>
                <td> &nbsp;</td>
                <td><input name=duetyp class=radio type=radio value="D" $checked>&nbsp;4. | . $locale->text('Quarter') . qq|&nbsp;</td>
                <td><input name=duetyp class=radio type=radio value="4" $checked >&nbsp;| . $locale->text('April') . qq|</td>
                <td><input name=duetyp class=radio type=radio value="8" $checked >&nbsp;| . $locale->text('August') . qq|</td>
                <td><input name=duetyp class=radio type=radio value="12" $checked >&nbsp;| . $locale->text('December') . qq|</td>

        </tr>
        <tr>
                   <td colspan=5><hr size=3 noshade></td>
        </tr>
        <tr>
          <th align=left><input name=reporttype class=radio type=radio value="free" $checked> | . $locale->text('Free report period') . qq|</th>
          <td align=left colspan=4>| . $locale->text('From') . qq|&nbsp;
              $button1
              $button1_2&nbsp;
              | . $locale->text('Bis') . qq|&nbsp;
              $button2
              $button2_2
          </td>
        </tr>
        <tr>
                   <td colspan=5><hr size=3 noshade></td>
        </tr>
        <tr>
          <th align=leftt>| . $locale->text('Method') . qq|</th>
          <td colspan=3><input name=method class=radio type=radio value=accrual $accrual>| . $locale->text('Accrual') . qq|
          &nbsp;<input name=method class=radio type=radio value=cash $cash>| . $locale->text('EUR') . qq|</td>
        </tr>
        <tr>
         <th align=right colspan=4>| . $locale->text('Decimalplaces') . qq|</th>
             <td><input name=decimalplaces size=3 value="2"></td>
         </tr>

$jsscript
|;
  }

  if ($form->{report} eq "balance_sheet") {
    print qq|
        <input type=hidden name=nextsub value=generate_balance_sheet>
        <tr>
          <th align=right>| . $locale->text('as at') . qq|</th>
          <td>
            $button1
            $button1_2
          </td>
          <th align=right nowrap>| . $locale->text('Compare to') . qq|</th>
          <td>
          $button2
          $button2_2
          </td>
        </tr>
        <tr>
          <th align=right>| . $locale->text('Decimalplaces') . qq|</th>
          <td><input name=decimalplaces size=3 value="2"></td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td>
      <table>
        <tr>
          <th align=right>| . $locale->text('Method') . qq|</th>
          <td colspan=3><input name=method class=radio type=radio value=accrual $accrual>| . $locale->text('Accrual') . qq|
          &nbsp;<input name=method class=radio type=radio value=cash $cash>| . $locale->text('EUR') . qq|</td>
        </tr>

        <tr>
          <th align=right nowrap>| . $locale->text('Include in Report') . qq|</th>
          <td><input name=l_heading class=checkbox type=checkbox value=Y>&nbsp;| . $locale->text('Heading') . qq|
          <input name=l_subtotal class=checkbox type=checkbox value=Y>&nbsp;| . $locale->text('Subtotal') . qq|
          <input name=l_accno class=checkbox type=checkbox value=Y>&nbsp;| . $locale->text('Account Number') . qq|</td>
        </tr>

$jsscript
|;
  }

  if ($form->{report} eq "trial_balance") {
    print qq|
        <tr>
          <th align=right nowrap>| . $locale->text('Project') . qq|</th>
          <td colspan=3>$projectnumber</td>
        </tr>
        <input type=hidden name=nextsub value=generate_trial_balance>
</table>
<table>
        <tr>
          <th align=left><input name=reporttype class=radio type=radio value="custom" checked> | . $locale->text('Customized Report') . qq|</th>
        </tr>
        <tr>
          <th colspan=1>| . $locale->text('Year') . qq|</th>
          <td><input name=year size=11 title="| . $locale->text('YYYY') . qq|" value="$year"></td>
        </tr>
|;

    print qq|
        <tr>
                <td align=right> <b> | . $locale->text('Yearly') . qq|</b> </td>
                <th align=left>| . $locale->text('Quarterly') . qq|</th>
                <th align=left colspan=3>| . $locale->text('Monthly') . qq|</th>
        </tr>
        <tr>
                <td align=right>&nbsp; <input name=duetyp class=radio type=radio value="13" $checked></td>
                <td><input name=duetyp class=radio type=radio value="A" $checked >&nbsp;1. | . $locale->text('Quarter') . qq|</td>
|;
    $checked = "checked";
    print qq|
                <td><input name=duetyp class=radio type=radio value="1" $checked >&nbsp;| . $locale->text('January') . qq|</td>
|;
    $checked = "";
    print qq|
                <td><input name=duetyp class=radio type=radio value="5" $checked >&nbsp;| . $locale->text('May') . qq|</td>
                <td><input name=duetyp class=radio type=radio value="9" $checked >&nbsp;| . $locale->text('September') . qq|</td>

        </tr>
        <tr>
                <td align= right>&nbsp;</td>
                <td><input name=duetyp class=radio type=radio value="B" $checked>&nbsp;2. | . $locale->text('Quarter') . qq|</td>
                <td><input name=duetyp class=radio type=radio value="2" $checked >&nbsp;| . $locale->text('February') . qq|</td>
                <td><input name=duetyp class=radio type=radio value="6" $checked >&nbsp;| . $locale->text('June') . qq|</td>
                <td><input name=duetyp class=radio type=radio value="10" $checked >&nbsp;| . $locale->text('October') . qq|</td>
        </tr>
        <tr>
                <td> &nbsp;</td>
                <td><input name=duetyp class=radio type=radio value="C" $checked>&nbsp;3. | . $locale->text('Quarter') . qq|</td>
                <td><input name=duetyp class=radio type=radio value="3" $checked >&nbsp;| . $locale->text('March') . qq|</td>
                <td><input name=duetyp class=radio type=radio value="7" $checked >&nbsp;| . $locale->text('July') . qq|</td>
                <td><input name=duetyp class=radio type=radio value="11" $checked >&nbsp;| . $locale->text('November') . qq|</td>

        </tr>
        <tr>
                <td> &nbsp;</td>
                <td><input name=duetyp class=radio type=radio value="D" $checked>&nbsp;4. | . $locale->text('Quarter') . qq|&nbsp;</td>
                <td><input name=duetyp class=radio type=radio value="4" $checked >&nbsp;| . $locale->text('April') . qq|</td>
                <td><input name=duetyp class=radio type=radio value="8" $checked >&nbsp;| . $locale->text('August') . qq|</td>
                <td><input name=duetyp class=radio type=radio value="12" $checked >&nbsp;| . $locale->text('December') . qq|</td>

        </tr>
        <tr>
                   <td colspan=5><hr size=3 noshade></td>
        </tr>
        <tr>
          <th align=left><input name=reporttype class=radio type=radio value="free" $checked> | . $locale->text('Free report period') . qq|</th>
          <td align=left colspan=4>| . $locale->text('From') . qq|&nbsp;
              $button1
              $button1_2&nbsp;
              | . $locale->text('Bis') . qq|&nbsp;
              $button2
              $button2_2
          </td>
        </tr>
        <tr>
                   <td colspan=5><hr size=3 noshade></td>
        </tr>
        <tr>
          <th align=leftt>| . $locale->text('Method') . qq|</th>
          <td colspan=3><input name=method class=radio type=radio value=accrual $accrual>| . $locale->text('Accrual') . qq|
          &nbsp;<input name=method class=radio type=radio value=cash $cash>| . $locale->text('EUR') . qq|</td>
        </tr>
       <tr>
         <th align=right colspan=4>| . $locale->text('All Accounts') . qq|</th>
             <td><input name=all_accounts type=checkbox value=1></td>
         </tr>
        <tr>
         <th align=right colspan=4>| . $locale->text('Decimalplaces') . qq|</th>
             <td><input name=decimalplaces size=3 value="2"></td>
         </tr>

$jsscript
|;
  }

  if ($form->{report} =~ /^tax_/) {
    $form->{db} = ($form->{report} =~ /_collected/) ? "ar" : "ap";

    RP->get_taxaccounts(\%myconfig, \%$form);

    print qq|
        <input type=hidden name=nextsub value=generate_tax_report>
        <tr>
          <th align=right>| . $locale->text('From') . qq|</th>
          <td><input name=fromdate size=11 title="$myconfig{dateformat}" value=$form->{fromdate}></td>
          <th align=right>| . $locale->text('Bis') . qq|</th>
          <td><input name=todate size=11 title="$myconfig{dateformat}"></td>
        </tr>
        <tr>
          <th align=right>| . $locale->text('Report for') . qq|</th>
          <td colspan=3>
|;

    $checked = "checked";
    foreach my $ref (@{ $form->{taxaccounts} }) {

      print
        qq|<input name=accno class=radio type=radio value=$ref->{accno} $checked>&nbsp;$ref->{description}

    <input name="$ref->{accno}_description" type=hidden value="$ref->{description}">
    <input name="$ref->{accno}_rate" type=hidden value="$ref->{rate}">|;

      $checked = "";

    }

    print qq|
  <input type=hidden name=db value=$form->{db}>
  <input type=hidden name=sort value=transdate>

          </td>
        </tr>
        <tr>
          <th align=right>| . $locale->text('Method') . qq|</th>
          <td colspan=3><input name=method class=radio type=radio value=accrual $accrual>| . $locale->text('Accrual') . qq|
          &nbsp;<input name=method class=radio type=radio value=cash $cash>| . $locale->text('EUR') . qq|</td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td>
      <table>
        <tr>
          <th align=right>| . $locale->text('Include in Report') . qq|</th>
          <td>
            <table>
              <tr>
                <td><input name="l_id" class=checkbox type=checkbox value=Y></td>
                <td>| . $locale->text('ID') . qq|</td>
                <td><input name="l_invnumber" class=checkbox type=checkbox value=Y checked></td>
                <td>| . $locale->text('Invoice') . qq|</td>
                <td><input name="l_transdate" class=checkbox type=checkbox value=Y checked></td>
                <td>| . $locale->text('Date') . qq|</td>
              </tr>
              <tr>
                <td><input name="l_name" class=checkbox type=checkbox value=Y checked></td>
                <td>|;

    if ($form->{db} eq 'ar') {
      print $locale->text('Customer');
    }
    if ($form->{db} eq 'ap') {
      print $locale->text('Vendor');
    }

    print qq|</td>
                <td><input name="l_netamount" class=checkbox type=checkbox value=Y checked></td>
                <td>| . $locale->text('Amount') . qq|</td>
                <td><input name="l_tax" class=checkbox type=checkbox value=Y checked></td>
                <td>| . $locale->text('Tax') . qq|</td>
                <td><input name="l_amount" class=checkbox type=checkbox value=Y></td>
                <td>| . $locale->text('Total') . qq|</td>
              </tr>
              <tr>
                <td><input name="l_subtotal" class=checkbox type=checkbox value=Y></td>
                <td>| . $locale->text('Subtotal') . qq|</td>
              </tr>
            </table>
          </td>
        </tr>
|;

  }

  if ($form->{report} =~ /^nontaxable_/) {
    $form->{db} = ($form->{report} =~ /_sales/) ? "ar" : "ap";

    print qq|
        <input type=hidden name=nextsub value=generate_tax_report>

        <input type=hidden name=db value=$form->{db}>
        <input type=hidden name=sort value=transdate>
        <input type=hidden name=report value=$form->{report}>

        <tr>
          <th align=right>| . $locale->text('From') . qq|</th>
          <td><input name=fromdate size=11 title="$myconfig{dateformat}" value=$form->{fromdate}></td>
          <th align=right>| . $locale->text('Bis') . qq|</th>
          <td><input name=todate size=11 title="$myconfig{dateformat}"></td>
        </tr>
        <tr>
          <th align=right>| . $locale->text('Method') . qq|</th>
          <td colspan=3><input name=method class=radio type=radio value=accrual $accrual>|
      . $locale->text('Accrual') . qq|
          &nbsp;<input name=method class=radio type=radio value=cash $cash>|
      . $locale->text('EUR') . qq|</td>
        </tr>
        <tr>
          <th align=right>| . $locale->text('Include in Report') . qq|</th>
          <td colspan=3>
            <table>
              <tr>
                <td><input name="l_id" class=checkbox type=checkbox value=Y></td>
                <td>| . $locale->text('ID') . qq|</td>
                <td><input name="l_invnumber" class=checkbox type=checkbox value=Y checked></td>
                <td>| . $locale->text('Invoice') . qq|</td>
                <td><input name="l_transdate" class=checkbox type=checkbox value=Y checked></td>
                <td>| . $locale->text('Date') . qq|</td>
              </tr>
              <tr>
                <td><input name="l_name" class=checkbox type=checkbox value=Y checked></td>
                <td>|;

    if ($form->{db} eq 'ar') {
      print $locale->text('Customer');
    }
    if ($form->{db} eq 'ap') {
      print $locale->text('Vendor');
    }

    print qq|</td>
                <td><input name="l_netamount" class=checkbox type=checkbox value=Y checked></td>
                <td>| . $locale->text('Amount') . qq|</td>
                <td><input name="l_amount" class=checkbox type=checkbox value=Y></td>
                <td>| . $locale->text('Total') . qq|</td>
              </tr>
              <tr>
                <td><input name="l_subtotal" class=checkbox type=checkbox value=Y></td>
                <td>| . $locale->text('Subtotal') . qq|</td>
              </tr>
            </table>
          </td>
        </tr>
|;

  }

  my ($label, $nextsub, $vc);
  if (($form->{report} eq "ar_aging") || ($form->{report} eq "ap_aging")) {
    if ($form->{report} eq 'ar_aging') {
      $label = $locale->text('Customer');
      $form->{vc} = 'customer';
    } else {
      $label = $locale->text('Vendor');
      $form->{vc} = 'vendor';
    }

    $nextsub = "generate_$form->{report}";

    # setup vc selection
    $form->all_vc(\%myconfig, $form->{vc},
                  ($form->{vc} eq 'customer') ? "AR" : "AP");

    map { $vc .= "<option>$_->{name}--$_->{id}\n" }
      @{ $form->{"all_$form->{vc}"} };

    $vc =
      ($vc)
      ? qq|<select name=$form->{vc}><option>\n$vc</select>|
      : qq|<input name=$form->{vc} size=35>|;

    print qq|
        <tr>
          <th align=right>| . $locale->text($label) . qq|</th>
          <td>$vc</td>
        </tr>
        <tr>
          <td align=left colspan=4>| . $locale->text('From') . qq|&nbsp;
              $button1
              $button1_2&nbsp;
              | . $locale->text('Bis') . qq|&nbsp;
              $button2
              $button2_2
          </td>
        </tr>
        <input type=hidden name=type value=statement>
        <input type=hidden name=format value=html>
        <input type=hidden name=media value=screen>

        <input type=hidden name=nextsub value=$nextsub>
        <input type=hidden name=action value=$nextsub>

$jsscript
|;
  }

  # above action can be removed if there is more than one input field

  my ($selection, $paymentaccounts);
  if ($form->{report} =~ /(receipts|payments)$/) {
    $form->{db} = ($form->{report} =~ /payments$/) ? "ap" : "ar";

    RP->paymentaccounts(\%myconfig, \%$form);

    $selection = "<option>\n";
    foreach my $ref (@{ $form->{PR} }) {
      $paymentaccounts .= "$ref->{accno} ";
      $selection       .= "<option>$ref->{accno}--$ref->{description}\n";
    }

    chop $paymentaccounts;

    print qq|
        <input type=hidden name=nextsub value=list_payments>
        <tr>
          <th align=right nowrap>| . $locale->text('Account') . qq|</th>
          <td colspan=3><select name=account>$selection</select>
            <input type=hidden name=paymentaccounts value="$paymentaccounts">
          </td>
        </tr>
        <tr>
          <th align=right>| . $locale->text('Reference') . qq|</th>
          <td colspan=3><input name=reference></td>
        </tr>
        <tr>
          <th align=right nowrap>| . $locale->text('Source') . qq|</th>
          <td colspan=3><input name=source></td>
        </tr>
        <tr>
          <th align=right nowrap>| . $locale->text('Memo') . qq|</th>
          <td colspan=3><input name=memo size=30></td>
        </tr>
        <tr>
          <th align=right>| . $locale->text('From') . qq|</th>
          <td>
            $button1
            $button1_2
          </td>
          <th align=right>| . $locale->text('Bis') . qq|</th>
          <td>
            $button2
            $button2_2
          </td>
        </tr>
        <tr>
          <td align=right><input type=checkbox style=checkbox name=fx_transaction value=1 checked></td>
          <th align=left colspan=3>| . $locale->text('Include Exchangerate Difference') . qq|</td>
        </tr>

$jsscript

          <input type=hidden name=db value=$form->{db}>
          <input type=hidden name=sort value=transdate>
|;

  }

  print qq|

      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<br>
<input type=submit class=submit name=action value="| . $locale->text('Continue') . qq|">

</form>

</body>
</html>
|;

  $main::lxdebug->leave_sub();
}

sub continue { call_sub($main::form->{"nextsub"}); }

sub get_project {
  $main::lxdebug->enter_sub();

  $main::auth->assert('report');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  my $nextsub = shift;

  $form->{project_id} = $form->{project_id_1};
  if ($form->{projectnumber} && !$form->{project_id}) {
    $form->{rowcount} = 1;

    # call this instead of update
    $form->{update}          = $nextsub;
    $form->{projectnumber_1} = $form->{projectnumber};

    delete $form->{sort};
    check_project('generate_projects');

    # if there is one only, assign id
    $form->{project_id} = $form->{project_id_1};
  }

  $main::lxdebug->leave_sub();
}

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
  }

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

  # setup variables for the form
  my @a = qw(company address businessnumber);
  map { $form->{$_} = $myconfig{$_} } @a;

  $form->{templates} = $myconfig{templates};

  $form->{IN} = "income_statement.html";

  $form->parse_template;

  $main::lxdebug->leave_sub();
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

  $::form->{asofdate} ||= $::form->current_date;
  $::form->{period}     = $::locale->date(\%::myconfig, $::form->current_date, 1);

  ($::form->{department}) = split /--/, $::form->{department};

  # define Current Earnings account
  my $padding = $::form->{l_heading} ? $::form->{padding} : "";
  push @{ $::form->{equity_account} }, $padding . $::locale->text('Current Earnings');

  $::form->{this_period} = $::locale->date(\%::myconfig, $::form->{asofdate}, 0);
  $::form->{last_period} = $::locale->date(\%::myconfig, $::form->{compareasofdate}, 0);

#  $::form->{IN} = "balance_sheet.html";

  # setup company variables for the form
  map { $::form->{$_} = $::myconfig{$_} } qw(company address businessnumber nativecurr);

  $::form->{templates} = $::myconfig{templates};

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

  &get_project("generate_projects");
  $form->{projectnumber} = $form->{projectnumber_1};

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

  my @hidden_variables    = qw(fromdate todate year cash);

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


  $form->{template_fromto} = $locale->date(\%myconfig, $form->{fromdate}, 0) . "&nbsp; - &nbsp;" . $locale->date(\%myconfig, $form->{todate}, 0);

  $form->{print_date} = $locale->text('Create Date') . " " . $locale->date(\%myconfig, $form->current_date(\%myconfig), 0);
  push (@options, $form->{print_date});

  $form->{company} = $locale->text('Company') . " " . $myconfig{company};
  push (@options, $form->{company});


  $form->{template_to} = $locale->date(\%myconfig, $form->{todate}, 0);

  $report->set_options('output_format'        => 'HTML',
                       'top_info_text'        => join("\n", @options),
                       'title'                => $form->{title},
                       'attachment_basename'  => $attachment_basename . strftime('_%Y%m%d', localtime time),
                       'html_template'        => 'rp/html_report_susa',
                       'pdf_template'         => 'rp/html_report_susa',
    );
  $report->set_options_from_form();

  # add sort and escape callback, this one we use for the add sub
  $form->{callback} = $href .= "&sort=$form->{sort}";

  # escape callback for href
  my $callback = $form->escape($href);

  my @subtotal_columns = qw(soll_eb haben_eb soll haben soll_kumuliert haben_kumuliert soll_saldo haben_saldo);

  my %totals    = map { $_ => 0 } @subtotal_columns;

  my $edit_url = build_std_url('action=edit', 'type', 'vc');

  my $idx;
  foreach my $accno (@{ $form->{TB} }) {

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

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);

  $report->set_export_options($action, @hidden_variables);

  my @totals_columns = qw(credit debit begbalance endbalance);
  my %subtotals      = map { $_ => 0 } @totals_columns;
  my %totals         = map { $_ => 0 } @totals_columns;
  my $found_heading  = 0;
  my @tb             = sort { $a->{accno} cmp $b->{accno} } @{ $form->{TB} };

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

  $main::auth->assert('general_ledger');

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

  $main::auth->assert('general_ledger');

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
  my $cgi      = $main::cgi;

  my $report = SL::ReportGenerator->new(\%myconfig, $form);

  my @columns = qw(statement ct invnumber transdate duedate amount open);

  my %column_defs = (
    'statement' => { 'text' => '', 'visible' => $form->{ct} eq 'customer' ? 'HTML' : 0, },
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

  my @hidden_variables = qw(todate customer vendor arap title ct);
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

  $report->set_options_from_form();

  $report->generate_with_headers();

  $main::lxdebug->leave_sub();
}

sub select_all {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  RP->aging(\%myconfig, \%$form);

  map { $_->{checked} = "checked" } @{ $form->{AG} };

  &aging;

  $main::lxdebug->leave_sub();
}

sub e_mail {
  $main::lxdebug->enter_sub();

  $main::auth->assert('general_ledger');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  # get name and email addresses
  my $selected = 0;
  for my $i (1 .. $form->{rowcount}) {
    if ($form->{"statement_$i"}) {
      $form->{"$form->{ct}_id"} = $form->{"$form->{ct}_id_$i"};
      RP->get_customer(\%myconfig, \%$form);
      $selected = 1;
      last;
    }
  }

  $form->error($locale->text('Nothing selected!')) unless $selected;

  my $bcc = '';
  if ($myconfig{role} eq 'admin') {
    $bcc = qq|
          <th align=right nowrap=true>| . $locale->text('Bcc') . qq|</th>
          <td><input name=bcc size=30 value="$form->{bcc}"></td>
|;
  }

  my $title = $locale->text('E-mail Statement to') . " $form->{$form->{ct}}";

  $form->{media} = "email";

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr class=listtop>
    <th>$title</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr>
          <th align=right nowrap>| . $locale->text('E-mail') . qq|</th>
          <td><input name=email size=30 value="$form->{email}"></td>
          <th align=right nowrap>| . $locale->text('Cc') . qq|</th>
          <td><input name=cc size=30 value="$form->{cc}"></td>
        </tr>
        <tr>
          <th align=right nowrap>| . $locale->text('Subject') . qq|</th>
          <td><input name=subject size=30 value="$form->{subject}"></td>
          $bcc
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td>
      <table width=100%>
        <tr>
          <th align=left nowrap>| . $locale->text('Message') . qq|</th>
        </tr>
        <tr>
          <td><textarea name=message rows=15 cols=60 wrap=soft>$form->{message}</textarea></td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td>
|;

  &print_options;

  map { delete $form->{$_} }
    qw(action email cc bcc subject message type sendmode format header);

  # save all other variables
  foreach my $key (keys %$form) {
    next if (($key eq 'login') || ($key eq 'password') || ('' ne ref $form->{$key}));
    $form->{$key} =~ s/\"/&quot;/g;
    print qq|<input type=hidden name=$key value="$form->{$key}">\n|;
  }

  print qq|
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<input type=hidden name=nextsub value=send_email>

<br>
<input name=action class=submit type=submit value="|
    . $locale->text('Continue') . qq|">
</form>

</body>
</html>
|;

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

  $form->{statementdate} = $locale->date(\%myconfig, $form->{todate}, 1);

  $form->{templates} = "$myconfig{templates}";

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

        map { $form->{$_} = () } qw(invnumber invdate duedate);
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

        $form->parse_template(\%myconfig, $main::userspath);

      }
    }
  }
  # saving the history
  if(!exists $form->{addition} && $form->{id} ne "") {
    $form->{snumbers} = qq|ordnumber_| . $form->{ordnumber};
    $form->{addition} = "PRINTED";
    $form->{what_done} = $form->{type};
    $form->save_history($form->dbconnect(\%myconfig));
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

  foreach my $item (qw(c0 c30 c60 c90)) {
    if ($ref->{exchangerate} * 1) {
      $ref->{$item} =
        $form->round_amount($ref->{$item} / $ref->{exchangerate}, 2);
    }
    $form->{"${item}total"} += $ref->{$item};
    $form->{total}          += $ref->{$item};
    push @{ $form->{$item} },
      $form->format_amount(\%myconfig, $ref->{$item}, 2);
  }

  $main::lxdebug->leave_sub();
}

sub generate_tax_report {
  $main::lxdebug->enter_sub();

  $main::auth->assert('report');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  RP->tax_report(\%myconfig, \%$form);

  my $descvar     = "$form->{accno}_description";
  my $description = $form->escape($form->{$descvar});
  my $ratevar     = "$form->{accno}_rate";
  our $taxrate; # most likely error

  my $department = $form->escape($form->{department});

  # construct href
  my $href =
    "$form->{script}?&action=generate_tax_report&fromdate=$form->{fromdate}&todate=$form->{todate}&db=$form->{db}&method=$form->{method}&accno=$form->{accno}&$descvar=$description&department=$department&$ratevar=$taxrate&report=$form->{report}";

  # construct callback
  $description = $form->escape($form->{$descvar},   1);
  $department  = $form->escape($form->{department}, 1);
  my $callback    =
    "$form->{script}?&action=generate_tax_report&fromdate=$form->{fromdate}&todate=$form->{todate}&db=$form->{db}&method=$form->{method}&accno=$form->{accno}&$descvar=$description&department=$department&$ratevar=$taxrate&report=$form->{report}";

  my $title = $form->escape($form->{title});
  $href .= "&title=$title";
  $title = $form->escape($form->{title}, 1);
  $callback .= "&title=$title";

  $form->{title} = qq|$form->{title} $form->{"$form->{accno}_description"} |;

  my @columns =
    $form->sort_columns(qw(id transdate invnumber name netamount tax amount));

  foreach my $item (@columns) {
    if ($form->{"l_$item"} eq "Y") {
      push @column_index, $item;

      # add column to href and callback
      $callback .= "&l_$item=Y";
      $href     .= "&l_$item=Y";
    }
  }

  if ($form->{l_subtotal} eq 'Y') {
    $callback .= "&l_subtotal=Y";
    $href     .= "&l_subtotal=Y";
  }

  my $option;
  if ($form->{department}) {
    ($department) = split /--/, $form->{department};
    $option = $locale->text('Department') . " : $department";
  }

  my ($fromdate, $todate);
  # if there are any dates
  if ($form->{fromdate} || $form->{todate}) {
    if ($form->{fromdate}) {
      $fromdate = $locale->date(\%myconfig, $form->{fromdate}, 1);
    }
    if ($form->{todate}) {
      $todate = $locale->date(\%myconfig, $form->{todate}, 1);
    }

    $form->{period} = "$fromdate - $todate";
  } else {
    $form->{period} =
      $locale->date(\%myconfig, $form->current_date(\%myconfig), 1);
  }

  my ($name, $invoice, $arap);
  if ($form->{db} eq 'ar') {
    $name    = $locale->text('Customer');
    $invoice = 'is.pl';
    $arap    = 'ar.pl';
  }
  if ($form->{db} eq 'ap') {
    $name    = $locale->text('Vendor');
    $invoice = 'ir.pl';
    $arap    = 'ap.pl';
  }

  $option .= "<br>" if $option;
  $option .= "$form->{period}";

  my %column_header;
  $column_header{id}        = qq|<th><a class=listheading href=$href&sort=id>| . $locale->text('ID') . qq|</th>|;
  $column_header{invnumber} = qq|<th><a class=listheading href=$href&sort=invnumber>| . $locale->text('Invoice') . qq|</th>|;
  $column_header{transdate} = qq|<th><a class=listheading href=$href&sort=transdate>| . $locale->text('Date') . qq|</th>|;
  $column_header{netamount} = qq|<th class=listheading>| . $locale->text('Amount') . qq|</th>|;
  $column_header{tax}       = qq|<th class=listheading>| . $locale->text('Tax') . qq|</th>|;
  $column_header{amount}    = qq|<th class=listheading>| . $locale->text('Total') . qq|</th>|;

  $column_header{name}      = qq|<th><a class=listheading href=$href&sort=name>$name</th>|;

  $form->header;

  print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>$option</td>
  </tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>
|;

  map { print "$column_header{$_}\n" } @column_index;

  print qq|
        </tr>
|;

  # add sort and escape callback
  $callback = $form->escape($callback . "&sort=$form->{sort}");

  my $sameitem;
  if (@{ $form->{TR} }) {
    $sameitem = $form->{TR}->[0]->{ $form->{sort} };
  }

  my ($totalnetamount, $totaltax);
  my ($i);
  foreach my $ref (@{ $form->{TR} }) {

    my $module = ($ref->{invoice}) ? $invoice : $arap;

    if ($form->{l_subtotal} eq 'Y') {
      if ($sameitem ne $ref->{ $form->{sort} }) {
        &tax_subtotal;
        $sameitem = $ref->{ $form->{sort} };
      }
    }

    $totalnetamount += $ref->{netamount};
    $totaltax       += $ref->{tax};
    $ref->{amount} = $ref->{netamount} + $ref->{tax};

    $subtotalnetamount += $ref->{netamount};
    $subtotaltax       += $ref->{tax};

    map {
      $ref->{$_} = $form->format_amount(\%myconfig, $ref->{$_}, 2, "&nbsp;");
    } qw(netamount tax amount);

    $column_data{id}        = qq|<td>$ref->{id}</td>|;
    $column_data{invnumber} =
      qq|<td><a href=$module?action=edit&id=$ref->{id}&callback=$callback>$ref->{invnumber}</a></td>|;
    $column_data{transdate} = qq|<td>$ref->{transdate}</td>|;
    $column_data{name}      = qq|<td>$ref->{name}&nbsp;</td>|;

    map { $column_data{$_} = qq|<td align=right>$ref->{$_}</td>| }
      qw(netamount tax amount);

    $i++;
    $i %= 2;
    print qq|
        <tr class=listrow$i>
|;

    map { print "$column_data{$_}\n" } @column_index;

    print qq|
        </tr>
|;

  }

  if ($form->{l_subtotal} eq 'Y') {
    &tax_subtotal;
  }

  map { $column_data{$_} = qq|<th>&nbsp;</th>| } @column_index;

  print qq|
        </tr>
        <tr class=listtotal>
|;

  my $total          = $form->format_amount(\%myconfig, $totalnetamount + $totaltax, 2, "&nbsp;");
  $totalnetamount = $form->format_amount(\%myconfig, $totalnetamount, 2, "&nbsp;");
  $totaltax       = $form->format_amount(\%myconfig, $totaltax, 2, "&nbsp;");

  $column_data{netamount} = qq|<th class=listtotal align=right>$totalnetamount</th>|;
  $column_data{tax}    = qq|<th class=listtotal align=right>$totaltax</th>|;
  $column_data{amount} = qq|<th class=listtotal align=right>$total</th>|;

  map { print "$column_data{$_}\n" } @column_index;

  print qq|
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

</body>
</html>
|;

  $main::lxdebug->leave_sub();
}

sub tax_subtotal {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;

  $subtotalnetamount = $form->format_amount(\%myconfig, $subtotalnetamount, 2, "&nbsp;");
  $subtotaltax       = $form->format_amount(\%myconfig, $subtotaltax, 2, "&nbsp;");
  $subtotal          = $form->format_amount(\%myconfig, $subtotalnetamount + $subtotaltax, 2, "&nbsp;");

  $column_data{netamount} = "<th class=listsubtotal align=right>$subtotalnetamount</th>";
  $column_data{tax}       = "<th class=listsubtotal align=right>$subtotaltax</th>";
  $column_data{amount}    = "<th class=listsubtotal align=right>$subtotal</th>";

  $subtotalnetamount = 0;
  $subtotaltax       = 0;

  print qq|
        <tr class=listsubtotal>
|;
  map { print "\n$column_data{$_}" } @column_index;

  print qq|
        </tr>
|;

  $main::lxdebug->leave_sub();
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
  $main::lxdebug->enter_sub();

  my ($dont_print) = @_;

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $form->{sendmode} = "attachment";

  $form->{"format"} =
    $form->{"format"} ? $form->{"format"} :
    $myconfig{"template_format"} ? $myconfig{"template_format"} :
    "pdf";

  $form->{"copies"} =
    $form->{"copies"} ? $form->{"copies"} :
    $myconfig{"copies"} ? $myconfig{"copies"} :
    2;

  $form->{PD}{ $form->{type} }     = "selected";
  $form->{DF}{ $form->{format} }   = "selected";
  $form->{OP}{ $form->{media} }    = "selected";
  $form->{SM}{ $form->{sendmode} } = "selected";

  my ($media);
  my $type = qq|
            <option value=statement $form->{PD}{statement}>| . $locale->text('Statement');

  if ($form->{media} eq 'email') {
    $media = qq|
            <option value=attachment $form->{SM}{attachment}>| . $locale->text('Attachment') . qq|
            <option value=inline $form->{SM}{inline}>| . $locale->text('In-line');
  } else {
    $media = qq|
            <option value=screen $form->{OP}{screen}>| . $locale->text('Screen');
    if ($myconfig{printer} && $main::latex_templates) {
      $media .= qq|
            <option value=printer $form->{OP}{printer}>| . $locale->text('Printer');
    }
  }

  my $format;
  if ($main::latex_templates) {
    $format .= qq|
            <option value=html $form->{DF}{html}>| . $locale->text('HTML')
      . qq| <option value=pdf $form->{DF}{pdf}>| . $locale->text('PDF')
      . qq| <option value=postscript $form->{DF}{postscript}>| . $locale->text('Postscript');
  }

  my $output = qq|
<table>
  <tr>
    <td><select name=type>$type</select></td>
    <td><select name=format>$format</select></td>
    <td><select name=media>$media</select></td>
|;

  if ($myconfig{printer} && $main::latex_templates && $form->{media} ne 'email') {
    $output .= qq|
      <td>| . $locale->text('Copies') . qq|
      <input name=copies size=2 value=$form->{copies}></td>
|;
  }

  $output .= qq|
  </tr>
</table>
|;

  print $output unless $dont_print;

  $main::lxdebug->leave_sub();

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
  } else {
    # die konvertierungen nur dann durchführen, wenn auch daten gesetzt sind.
    # ansonsten ist die prüfung in RP.pm
    # if (defined ($form->{fromdate|todate}=='..'))
    # immer wahr
    if ($form->{fromdate}){
      my ($yy, $mm, $dd) = $locale->parse_date(\%myconfig, $form->{fromdate});
      $form->{fromdate} = "${dd}.${mm}.${yy}";
      $form->{comparefromdate} = "01.01.$yy";
    }
    if ($form->{todate}){
      my ($yy, $mm, $dd) = $locale->parse_date(\%myconfig, $form->{todate});
      $form->{todate}          = "${dd}.${mm}.${yy}";
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

  # setup variables for the form
  my @a = qw(company address businessnumber);
  map { $form->{$_} = $myconfig{$_} } @a;
  $form->{templates} = $myconfig{templates};

  $form->{IN} = "bwa.html";

  $form->parse_template;

  $main::lxdebug->leave_sub();
}

1;
