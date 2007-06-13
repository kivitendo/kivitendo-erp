#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (c) 2001
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
# Accounts Receivables
#
#======================================================================

use POSIX qw(strftime);

use SL::AR;
use SL::IS;
use SL::PE;
use SL::ReportGenerator;

require "bin/mozilla/arap.pl";
require "bin/mozilla/common.pl";
require "bin/mozilla/drafts.pl";
require "bin/mozilla/report_generator.pl";

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

sub add {
  $lxdebug->enter_sub();

  return $lxdebug->leave_sub() if (load_draft_maybe());

  # saving the history
  if(!exists $form->{addition} && ($form->{id} ne "")) {
    $form->{snumbers} = qq|invnumber_| . $form->{invnumber};
  	$form->{addition} = "ADDED";
  	$form->save_history($form->dbconnect(\%myconfig));
  }
  # /saving the history 
  
  $form->{title}    = "Add";
  $form->{callback} =
    "$form->{script}?action=add&login=$form->{login}&password=$form->{password}"
    unless $form->{callback};

  AR->get_transdate(\%myconfig, $form);
  $form->{initial_transdate} = $form->{transdate};
  &create_links;
  $form->{transdate} = $form->{initial_transdate};
  &display_form;
  $lxdebug->leave_sub();
}

sub edit {
  $lxdebug->enter_sub();
  # show history button
  $form->{javascript} = qq|<script type="text/javascript" src="js/show_history.js"></script>|;
  #/show hhistory button
  $form->{javascript} .= qq|<script type="text/javascript" src="js/common.js"></script>|;
  $form->{title} = "Edit";

  &create_links;
  &display_form;

  $lxdebug->leave_sub();
}

sub display_form {
  $lxdebug->enter_sub();

  &form_header;
  &form_footer;

  $lxdebug->leave_sub();
}

sub create_links {
  $lxdebug->enter_sub();

  $form->create_links("AR", \%myconfig, "customer");
  $duedate = $form->{duedate};

  $taxincluded = $form->{taxincluded};
  my $id = $form->{id};
  IS->get_customer(\%myconfig, \%$form);
  $form->{taxincluded} = $taxincluded;
  $form->{id} = $id;

  $form->{duedate}     = $duedate if $duedate;
  $form->{oldcustomer} = "$form->{customer}--$form->{customer_id}";
  $form->{rowcount}    = 1;

  # notes
  $form->{notes} = $form->{intnotes} unless $form->{notes};

  # currencies
  @curr = split(/:/, $form->{currencies});
  chomp $curr[0];
  $form->{defaultcurrency} = $curr[0];

  map { $form->{selectcurrency} .= "<option>$_\n" } @curr;

  # customers
  if (@{ $form->{all_customer} }) {
    $form->{customer} = "$form->{customer}--$form->{customer_id}";
    map { $form->{selectcustomer} .= "<option>$_->{name}--$_->{id}\n" }
      (@{ $form->{all_customer} });
  }

  # departments
  if (@{ $form->{all_departments} }) {
    $form->{selectdepartment} = "<option>\n";
    $form->{department}       = "$form->{department}--$form->{department_id}";

    map {
      $form->{selectdepartment} .=
        "<option>$_->{description}--$_->{id}\n"
    } (@{ $form->{all_departments} });
  }

  $form->{employee} = "$form->{employee}--$form->{employee_id}";

  # sales staff
  if (@{ $form->{all_employees} }) {
    $form->{selectemployee} = "";
    map { $form->{selectemployee} .= "<option>$_->{name}--$_->{id}\n" }
      (@{ $form->{all_employees} });
  }

  # build the popup menus
  $form->{taxincluded} = ($form->{id}) ? $form->{taxincluded} : "checked";

  AR->setup_form($form);

  $form->{locked} =
    ($form->datetonum($form->{transdate}, \%myconfig) <=
     $form->datetonum($form->{closedto}, \%myconfig));

  $lxdebug->leave_sub();
}

sub form_header {
  $lxdebug->enter_sub();

  $title = $form->{title};
  $form->{title} = $locale->text("$title Accounts Receivables Transaction");

  $form->{taxincluded} = ($form->{taxincluded}) ? "checked" : "";

  # $locale->text('Add Accounts Receivables Transaction')
  # $locale->text('Edit Accounts Receivables Transaction')
  $form->{javascript} = qq|<script type="text/javascript">
  <!--
  function setTaxkey(accno, row) {
    var taxkey = accno.options[accno.selectedIndex].value;
    var reg = /--([0-9]*)/;
    var found = reg.exec(taxkey);
    var index = found[1];
    index = parseInt(index);
    var tax = 'taxchart_' + row;
    for (var i = 0; i < document.getElementById(tax).options.length; ++i) {
      var reg2 = new RegExp("^"+ index, "");
      if (reg2.exec(document.getElementById(tax).options[i].value)) {
        document.getElementById(tax).options[i].selected = true;
        break;
      }
    }
  };
  //-->
  </script>|;
  # show history button js
  $form->{javascript} .= qq|<script type="text/javascript" src="js/show_history.js"></script>|;
  #/show history button js
  $form->{javascript} .= qq|<script type="text/javascript" src="js/common.js"></script>|;
  $readonly = ($form->{id}) ? "readonly" : "";

  $form->{radier} =
    ($form->current_date(\%myconfig) eq $form->{gldate}) ? 1 : 0;
  $readonly = ($form->{radier}) ? "" : $readonly;

  # set option selected
  foreach $item (qw(customer currency department employee)) {
    $form->{"select$item"} =~ s/ selected//;
    $form->{"select$item"} =~
      s/option>\Q$form->{$item}\E/option selected>$form->{$item}/;
  }

  $form->{exchangerate} = $exchangerate
    if (
        $form->{forex} = (
                     $exchangerate =
                       $form->check_exchangerate(
                       \%myconfig, $form->{currency}, $form->{transdate}, 'buy'
                       )));

  # format amounts
  $form->{exchangerate} =
    $form->format_amount(\%myconfig, $form->{exchangerate});

  if ($form->{exchangerate} == 0) {
    $form->{exchangerate} = "";
  }

  $form->{creditlimit} =
    $form->format_amount(\%myconfig, $form->{creditlimit}, 0, "0");
  $form->{creditremaining} =
    $form->format_amount(\%myconfig, $form->{creditremaining}, 0, "0");

  $exchangerate = qq|
<input type=hidden name=forex value=$form->{forex}>
|;
  if ($form->{currency} ne $form->{defaultcurrency}) {
    if ($form->{forex}) {
      $exchangerate .= qq|
	<th align=right>| . $locale->text('Exchangerate') . qq|</th>
	<td><input type=hidden name=exchangerate value=$form->{exchangerate}>$form->{exchangerate}</td>
|;
    } else {
      $exchangerate .= qq|
        <th align=right>| . $locale->text('Exchangerate') . qq|</th>
        <td><input name=exchangerate size=10 value=$form->{exchangerate}></td>
|;
    }
  }

  $taxincluded = qq|
	      <tr>
		<td align=right><input name=taxincluded class=checkbox type=checkbox value=1 $form->{taxincluded}></td>
		<th align=left nowrap>| . $locale->text('Tax Included') . qq|</th>
	      </tr>
|;

  if (($rows = $form->numtextrows($form->{notes}, 50)) < 2) {
    $rows = 2;
  }
  $notes =
    qq|<textarea name=notes rows=$rows cols=50 wrap=soft>$form->{notes}</textarea>|;

  $department = qq|
	      <tr>
		<th align="right" nowrap>| . $locale->text('Department') . qq|</th>
		<td colspan=3><select name=department>$form->{selectdepartment}</select>
		<input type=hidden name=selectdepartment value="$form->{selectdepartment}">
		</td>
	      </tr>
| if $form->{selectdepartment};

  $n = ($form->{creditremaining} =~ /-/) ? "0" : "1";

  $customer =
    ($form->{selectcustomer})
    ? qq|<select name="customer"
onchange="document.getElementById('update_button').click();">$form->{
selectcustomer}</select>|
    : qq|<input name=customer value="$form->{customer}" size=35>|;

  $employee = qq|
                <input type=hidden name=employee value="$form->{employee}">
|;

  if ($form->{selectemployee}) {
    $employee = qq|
	      <tr>
		<th align=right nowrap>| . $locale->text('Salesperson') . qq|</th>
		<td  colspan=2><select name=employee>$form->{selectemployee}</select></td>
		<input type=hidden name=selectemployee value="$form->{selectemployee}">
	      </tr>
|;
  }

  my @old_project_ids = ();
  map({ push(@old_project_ids, $form->{"project_id_$_"})
          if ($form->{"project_id_$_"}); } (1..$form->{"rowcount"}));

  $form->get_lists("projects" => { "key" => "ALL_PROJECTS",
                                   "all" => 0,
                                   "old_id" => \@old_project_ids },
                   "charts" => { "key" => "ALL_CHARTS",
                                 "transdate" => $form->{transdate} },
                   "taxcharts" => "ALL_TAXCHARTS");

  map({ $_->{link_split} = [ split(/:/, $_->{link}) ]; }
      @{ $form->{ALL_CHARTS} });

  my %project_labels = ();
  my @project_values = ("");
  foreach my $item (@{ $form->{"ALL_PROJECTS"} }) {
    push(@project_values, $item->{"id"});
    $project_labels{$item->{"id"}} = $item->{"projectnumber"};
  }

  my (%AR_amount_labels, @AR_amount_values);
  my (%AR_labels, @AR_values);
  my (%AR_paid_labels, @AR_paid_values);
  my %charts;
  my $taxchart_init;

  foreach my $item (@{ $form->{ALL_CHARTS} }) {
    if (grep({ $_ eq "AR_amount" } @{ $item->{link_split} })) {
      $taxchart_init = $item->{tax_id} if ($taxchart_init eq "");
      my $key = "$item->{accno}--$item->{tax_id}";
      push(@AR_amount_values, $key);
      $AR_amount_labels{$key} =
        "$item->{accno}--$item->{description}";

    } elsif (grep({ $_ eq "AR" } @{ $item->{link_split} })) {
      push(@AR_values, $item->{accno});
      $AR_labels{$item->{accno}} = "$item->{accno}--$item->{description}";

    } elsif (grep({ $_ eq "AR_paid" } @{ $item->{link_split} })) {
      push(@AR_paid_values, $item->{accno});
      $AR_paid_labels{$item->{accno}} =
        "$item->{accno}--$item->{description}";
    }

    $charts{$item->{accno}} = $item;
  }

  my %taxchart_labels = ();
  my @taxchart_values = ();
  my %taxcharts = ();
  foreach my $item (@{ $form->{ALL_TAXCHARTS} }) {
    my $key = "$item->{id}--$item->{rate}";
    $taxchart_init = $key if ($taxchart_init eq $item->{id});
    push(@taxchart_values, $key);
    $taxchart_labels{$key} =
      "$item->{taxdescription} " . ($item->{rate} * 100) . ' %';
    $taxcharts{$item->{id}} = $item;
  }

  $form->{fokus} = "arledger.customer";

  # use JavaScript Calendar or not
  $form->{jsscript} = 1;
  $jsscript = "";
  if ($form->{jsscript}) {

    # with JavaScript Calendar
    $button1 = qq|
       <td><input name=transdate id=transdate size=11 title="$myconfig{dateformat}" value="$form->{transdate}" onBlur=\"check_right_date_format(this)\"></td>
       <td><input type=button name=transdate id="trigger1" value=|
      . $locale->text('button') . qq|></td>
       |;
    $button2 = qq|
       <td><input name=duedate id=duedate size=11 title="$myconfig{dateformat}" value="$form->{duedate}" onBlur=\"check_right_date_format(this)\"></td>
       <td><input type=button name=duedate id="trigger2" value=|
      . $locale->text('button') . qq|></td></td>
     |;

    #write Trigger
    $jsscript =
      Form->write_trigger(\%myconfig, "2", "transdate", "BL", "trigger1",
                          "duedate", "BL", "trigger2");
  } else {

    # without JavaScript Calendar
    $button1 =
      qq|<td><input name=transdate id=transdate size=11 title="$myconfig{dateformat}" value="$form->{transdate}" onBlur=\"check_right_date_format(this)\"></td>|;
    $button2 =
      qq|<td><input name=duedate id=duedate size=11 title="$myconfig{dateformat}" value="$form->{duedate}" onBlur=\"check_right_date_format(this)\"></td>|;
  }

  $form->{javascript} .=
    qq|<script type="text/javascript" src="js/common.js"></script>| .
    qq|<script type="text/javascript" src="js/show_vc_details.js"></script>|;

  $form->header;
  $onload = qq|focus()|;
  $onload .= qq|;setupDateFormat('|. $myconfig{dateformat} .qq|', '|. $locale->text("Falsches Datumsformat!") .qq|')|;
  $onload .= qq|;setupPoints('|. $myconfig{numberformat} .qq|', '|. $locale->text("wrongformat") .qq|')|;
  print qq|
<body onLoad="$onload">

<form method=post name="arledger" action=$form->{script}>

<input type=hidden name=id value=$form->{id}>
<input type=hidden name=sort value=$form->{sort}>
<input type=hidden name=closedto value=$form->{closedto}>
<input type=hidden name=locked value=$form->{locked}>
<input type=hidden name=title value="$title">

| . ($form->{saved_message} ? qq|<p>$form->{saved_message}</p>| : "") . qq|

<table width=100%>
  <tr class=listtop>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr valign=top>
    <td>
      <table width=100%>
        <tr valign=top>
	  <td>
	    <table>
	      <tr>
		<th align="right" nowrap>| . $locale->text('Customer') . qq|</th>
		<td colspan=3>$customer <input type="button" value="?" onclick="show_vc_details('customer')"></td>
		<input type=hidden name=selectcustomer value="$form->{selectcustomer}">
		<input type=hidden name=oldcustomer value="$form->{oldcustomer}">
		<input type=hidden name=customer_id value="$form->{customer_id}">
		<input type=hidden name=terms value=$form->{terms}>
	      </tr>
	      <tr>
		<td></td>
		<td colspan=3>
		  <table width=100%>
		    <tr>
		      <th align=left nowrap>| . $locale->text('Credit Limit') . qq|</th>
		      <td>$form->{creditlimit}</td>
		      <th align=left nowrap>| . $locale->text('Remaining') . qq|</th>
		      <td class="plus$n">$form->{creditremaining}</td>
		      <input type=hidden name=creditlimit value=$form->{creditlimit}>
		      <input type=hidden name=creditremaining value=$form->{creditremaining}>
		    </tr>
		  </table>
		</td>
	      </tr>
	      <tr>
		<th align=right>| . $locale->text('Currency') . qq|</th>
		<td><select name=currency>$form->{selectcurrency}</select></td>
		<input type=hidden name=selectcurrency value="$form->{selectcurrency}">
		<input type=hidden name=defaultcurrency value=$form->{defaultcurrency}>
		<input type=hidden name=fxgain_accno value=$form->{fxgain_accno}>
		<input type=hidden name=fxloss_accno value=$form->{fxloss_accno}>
		$exchangerate
	      </tr>
	      $department
	      $taxincluded
	    </table>
	  </td>
	  <td align=right>
	    <table>
	      $employee
	      <tr>
		<th align=right nowrap>| . $locale->text('Invoice Number') . qq|</th>
		<td><input name=invnumber size=11 value="$form->{invnumber}"></td>
	      </tr>
	      <tr>
		<th align=right nowrap>| . $locale->text('Order Number') . qq|</th>
		<td><input name=ordnumber size=11 value="$form->{ordnumber}"></td>
	      </tr>
	      <tr>
		<th align=right nowrap>| . $locale->text('Invoice Date') . qq|</th>
                $button1
	      </tr>
	      <tr>
		<th align=right nowrap>| . $locale->text('Due Date') . qq|</th>
                $button2
	      </tr>
     </table>
	  </td>
	</tr>
      </table>
    </td>
  </tr>

$jsscript
  <input type=hidden name=rowcount value=$form->{rowcount}>
  <tr>
      <td>
          <table width=100%>
	   <tr class=listheading>
	  <th class=listheading style="width:15%">|
    . $locale->text('Account') . qq|</th>
	  <th class=listheading style="width:10%">|
    . $locale->text('Amount') . qq|</th>
          <th class=listheading style="width:10%">|
    . $locale->text('Tax') . qq|</th>
          <th class=listheading style="width:5%">|
    . $locale->text('Korrektur') . qq|</th>
          <th class=listheading style="width:10%">|
    . $locale->text('Taxkey') . qq|</th>
          <th class=listheading style="width:10%">|
    . $locale->text('Project') . qq|</th>
	</tr>
|;

  $amount  = $locale->text('Amount');
  $project = $locale->text('Project');

  for $i (1 .. $form->{rowcount}) {

    # format amounts
    $form->{"amount_$i"} =
      $form->format_amount(\%myconfig, $form->{"amount_$i"}, 2);
    $form->{"tax_$i"} = $form->format_amount(\%myconfig, $form->{"tax_$i"}, 2);

    my $selected_accno_full;
    my ($accno_row) = split(/--/, $form->{"AR_amount_$i"});
    my $item = $charts{$accno_row};
    $selected_accno_full = "$item->{accno}--$item->{tax_id}";

    my $selected_taxchart = $form->{"taxchart_$i"};
    my ($selected_accno, $selected_tax_id) = split(/--/, $selected_accno_full);
    my ($previous_accno, $previous_tax_id) = split(/--/, $form->{"previous_AR_amount_$i"});

    if ($previous_accno &&
        ($previous_accno eq $selected_accno) &&
        ($previous_tax_id ne $selected_tax_id)) {
      my $item = $taxcharts{$selected_tax_id};
      $selected_taxchart = "$item->{id}--$item->{rate}";
    }

    $selected_taxchart = $taxchart_init unless ($form->{"taxchart_$i"});

    $selectAR_amount =
      NTI($cgi->popup_menu('-name' => "AR_amount_$i",
                           '-id' => "AR_amount_$i",
                           '-style' => 'width:400px',
                           '-onChange' => "setTaxkey(this, $i)",
                           '-values' => \@AR_amount_values,
                           '-labels' => \%AR_amount_labels,
                           '-default' => $selected_accno_full))
      . $cgi->hidden('-name' => "previous_AR_amount_$i",
                     '-default' => $selected_accno_full);

    $tax = qq|<td>| .
      NTI($cgi->popup_menu('-name' => "taxchart_$i",
                           '-id' => "taxchart_$i",
                           '-style' => 'width:200px',
                           '-values' => \@taxchart_values,
                           '-labels' => \%taxchart_labels,
                           '-default' => $selected_taxchart))
      . qq|</td>|;

    $korrektur_checked = ($form->{"korrektur_$i"} ? 'checked' : '');

    my $projectnumber =
      NTI($cgi->popup_menu('-name' => "project_id_$i",
                           '-values' => \@project_values,
                           '-labels' => \%project_labels,
                           '-default' => $form->{"project_id_$i"} ));

    print qq|
	<tr>
          <td>$selectAR_amount</td>
          <td><input name="amount_$i" size=10 value=$form->{"amount_$i"}></td>
          <td><input name="tax_$i" size=10 value=$form->{"tax_$i"}></td>
          <td><input type="checkbox" name="korrektur_$i" value="1" $korrektur_checked></td>
          $tax
          <td>$projectnumber</td>
	</tr>
|;
    $amount  = "";
    $project = "";
  }

  $form->{invtotal_unformatted} = $form->{invtotal};
  $form->{invtotal} = $form->format_amount(\%myconfig, $form->{invtotal}, 2);

  $ARselected =
    NTI($cgi->popup_menu('-name' => "ARselected", '-id' => "ARselected",
                         '-style' => 'width:400px',
                         '-values' => \@AR_values, '-labels' => \%AR_labels,
                         '-default' => $form->{ARselected}));

  print qq|
        <tr>
          <td colspan=6>
            <hr noshade>
          </td>
        </tr>
        <tr>
	  <td>${ARselected}</td>
	  <th align=left>$form->{invtotal}</th>

	  <input type=hidden name=oldinvtotal value=$form->{oldinvtotal}>
	  <input type=hidden name=oldtotalpaid value=$form->{oldtotalpaid}>

	  <input type=hidden name=taxaccounts value="$form->{taxaccounts}">

	  <td colspan=4></td>


        </tr>
        </table>
        </td>
    </tr>
    <tr>
      <td>
        <table width=100%>
        <tr>
	  <th align=left width=1%>| . $locale->text('Notes') . qq|</th>
	  <td align=left>$notes</td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td>
      <table width=100%>
	<tr class=listheading>
	  <th colspan=7 class=listheading>|
    . $locale->text('Incoming Payments') . qq|</th>
	</tr>
|;

  if ($form->{currency} eq $form->{defaultcurrency}) {
    @column_index = qw(datepaid source memo paid AR_paid paid_project_id);
  } else {
    @column_index = qw(datepaid source memo paid exchangerate AR_paid paid_project_id);
  }

  $column_data{datepaid}     = "<th>" . $locale->text('Date') . "</th>";
  $column_data{paid}         = "<th>" . $locale->text('Amount') . "</th>";
  $column_data{exchangerate} = "<th>" . $locale->text('Exch') . "</th>";
  $column_data{AR_paid}      = "<th>" . $locale->text('Account') . "</th>";
  $column_data{source}       = "<th>" . $locale->text('Source') . "</th>";
  $column_data{memo}         = "<th>" . $locale->text('Memo') . "</th>"; 
  $column_data{paid_project_id} = "<th>" . $locale->text('Project Number') . "</th>"; 

  print "
        <tr>
";
  map { print "$column_data{$_}\n" } @column_index;
  print "
        </tr>
";

  my @triggers  = ();
  my $totalpaid = 0;

  $form->{paidaccounts}++ if ($form->{"paid_$form->{paidaccounts}"});
  for $i (1 .. $form->{paidaccounts}) {
    print "
        <tr>
";

    $selectAR_paid =
      NTI($cgi->popup_menu('-name' => "AR_paid_$i",
                           '-id' => "AR_paid_$i",
                           '-values' => \@AR_paid_values,
                           '-labels' => \%AR_paid_labels,
                           '-default' => $form->{"AR_paid_$i"}));

    $totalpaid += $form->{"paid_$i"};

    # format amounts
    if ($form->{"paid_$i"}) {
      $form->{"paid_$i"} =
        $form->format_amount(\%myconfig, $form->{"paid_$i"}, 2);
    }
    $form->{"exchangerate_$i"} =
      $form->format_amount(\%myconfig, $form->{"exchangerate_$i"});

    if ($form->{"exchangerate_$i"} == 0) {
      $form->{"exchangerate_$i"} = "";
    }

    $exchangerate = qq|&nbsp;|;
    if ($form->{currency} ne $form->{defaultcurrency}) {
      if ($form->{"forex_$i"}) {
        $exchangerate =
          qq|<input type=hidden name="exchangerate_$i" value=$form->{"exchangerate_$i"}>$form->{"exchangerate_$i"}|;
      } else {
        $exchangerate =
          qq|<input name="exchangerate_$i" size=10 value=$form->{"exchangerate_$i"}>|;
      }
    }

    $exchangerate .= qq|
<input type=hidden name="forex_$i" value=$form->{"forex_$i"}>
|;

    $column_data{paid} =
      qq|<td align=center><input name="paid_$i" size=11 value="$form->{"paid_$i"}" onBlur=\"check_right_number_format(this)\"></td>|;
    $column_data{AR_paid} =
      qq|<td align=center>${selectAR_paid}</td>|;
    $column_data{exchangerate} = qq|<td align=center>$exchangerate</td>|;
    $column_data{datepaid}     =
      qq|<td align=center><input name="datepaid_$i" id="datepaid_$i" size=11 value="$form->{"datepaid_$i"}" onBlur=\"check_right_date_format(this)\">
         <input type="button" name="datepaid_$i" id="trigger_datepaid_$i" value="?"></td>|;
    $column_data{source} =
      qq|<td align=center><input name="source_$i" size=11 value="$form->{"source_$i"}"></td>|;
    $column_data{memo} =
      qq|<td align=center><input name="memo_$i" size=11 value="$form->{"memo_$i"}"></td>|;

    $column_data{paid_project_id} =
      qq|<td>|
      . NTI($cgi->popup_menu('-name' => "paid_project_id_$i",
                             '-values' => \@project_values,
                             '-labels' => \%project_labels,
                             '-default' => $form->{"paid_project_id_$i"} ))
      . qq|</td>|;

    map { print qq|$column_data{$_}\n| } @column_index;

    print "
        </tr>
";
    push(@triggers, "datepaid_$i", "BL", "trigger_datepaid_$i");
  }

  my $paid_missing = $form->{invtotal_unformatted} - $totalpaid;

  print qq|
        <tr>
          <td></td>
          <td></td>
          <td align="center">| . $locale->text('Total') . qq|</td>
          <td align="center">| . H($form->format_amount(\%myconfig, $totalpaid, 2)) . qq|</td>
        </tr>
        <tr>
          <td></td>
          <td></td>
          <td align="center">| . $locale->text('Missing amount') . qq|</td>
          <td align="center">| . H($form->format_amount(\%myconfig, $paid_missing, 2)) . qq|</td>
        </tr>
| . $form->write_trigger(\%myconfig, scalar(@triggers) / 3, @triggers) .
    qq|
<input type=hidden name=paidaccounts value=$form->{paidaccounts}>

      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>
|;

  $lxdebug->leave_sub();
}

sub form_footer {
  $lxdebug->enter_sub();

  print qq|

<input name=gldate type=hidden value="| . Q($form->{gldate}) . qq|">

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>
|
. $cgi->hidden('-name' => 'draft_id', '-default' => [$form->{draft_id}])
. $cgi->hidden('-name' => 'draft_description', '-default' => [$form->{draft_description}])
. qq|

<br>
|;

  if (!$form->{id} && $form->{draft_id}) {
    print(NTI($cgi->checkbox('-name' => 'remove_draft', '-id' => 'remove_draft',
                             '-value' => 1, '-checked' => $form->{remove_draft},
                             '-label' => '')) .
          qq|&nbsp;<label for="remove_draft">| .
          $locale->text("Remove draft when posting") .
          qq|</label><br>|);
  }

  $transdate = $form->datetonum($form->{transdate}, \%myconfig);
  $closedto  = $form->datetonum($form->{closedto},  \%myconfig);

  print qq|<input class="submit" type="submit" name="action" id="update_button" value="| . $locale->text('Update') . qq|">\n|;

  # ToDO: - insert a global check for stornos, so that a storno is only possible a limited time after saving it
  print qq|<input class=submit type=submit name=action value="| . $locale->text('Storno') . qq|">|
    if ($form->{id} && !IS->has_storno(\%myconfig, $form, 'ar') && !IS->is_storno(\%myconfig, $form, 'ar') && !$form->{paid_1});

  if ($form->{id}) {
    if ($form->{radier}) {
      print qq|
        <input class=submit type=submit name=action value="| . $locale->text('Post') .            qq|">
        <input class=submit type=submit name=action value="| . $locale->text('Delete') .          qq|"> |;
    }
    if ($transdate > $closedto) {
      print qq|
        <input class=submit type=submit name=action value="| . $locale->text('Use As Template') . qq|"> |;
    }
    print qq|
        <input class=submit type=submit name=action value="| . $locale->text('Post Payment') .    qq|"> |;

  } else {
    if ($transdate > $closedto) {
      print qq|<input class=submit type=submit name=action value="| . $locale->text('Post') .     qq|"> | .
        NTI($cgi->submit('-name' => 'action', '-value' => $locale->text('Save draft'), '-class' => 'submit'));
    }
  }

  if ($form->{menubar}) {
    require "bin/mozilla/menu.pl";
    &menubar;
  }
  # button for saving history
  if($form->{id} ne "") {
    print qq|<input type=button class=submit onclick=set_history_window($form->{id}); name=history id=history value=| . $locale->text('history') . qq|>|;
  }
  # /button for saving history
  # mark_as_paid button 
  if($form->{id} ne "") {  
    print qq|<input type="submit" class="submit" name="action" value="| 
          . $locale->text('mark as paid') . qq|">|;
  }
  # /mark_as_paid button

  print "
</form>

</body>
</html>
";

  $lxdebug->leave_sub();
}

sub mark_as_paid {
  $lxdebug->enter_sub();
  &mark_as_paid_common(\%myconfig,"ar");  
  $lxdebug->leave_sub();
}

sub update {
  $lxdebug->enter_sub();

  my $display = shift;

  $form->{invtotal} = 0;

  map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) }
    qw(exchangerate creditlimit creditremaining);

  @flds  = qw(amount AR_amount projectnumber oldprojectnumber project_id);
  $count = 0;
  @a     = ();

  for $i (1 .. $form->{rowcount}) {
    $form->{"amount_$i"} =
      $form->parse_amount(\%myconfig, $form->{"amount_$i"});
    $form->{"tax_$i"} = $form->parse_amount(\%myconfig, $form->{"tax_$i"});
    if ($form->{"amount_$i"}) {
      push @a, {};
      $j = $#a;
      if (!$form->{"korrektur_$i"}) {
        ($taxkey, $rate) = split(/--/, $form->{"taxchart_$i"});
        if ($taxkey > 1) {
          if ($form->{taxincluded}) {
            $form->{"tax_$i"} = $form->{"amount_$i"} / ($rate + 1) * $rate;
          } else {
            $form->{"tax_$i"} = $form->{"amount_$i"} * $rate;
          }
        } else {
          $form->{"tax_$i"} = 0;
        }
      }
      $form->{"tax_$i"} = $form->round_amount($form->{"tax_$i"}, 2);

      $totaltax += $form->{"tax_$i"};
      map { $a[$j]->{$_} = $form->{"${_}_$i"} } @flds;
      $count++;
    }
  }

  $form->redo_rows(\@flds, \@a, $count, $form->{rowcount});
  $form->{rowcount} = $count + 1;
  map { $form->{invtotal} += $form->{"amount_$_"} } (1 .. $form->{rowcount});

  $form->{exchangerate} = $exchangerate
    if (
        $form->{forex} = (
                     $exchangerate =
                       $form->check_exchangerate(
                       \%myconfig, $form->{currency}, $form->{transdate}, 'buy'
                       )));

  $form->{invdate} = $form->{transdate};
  $save_AR = $form->{AR};
  &check_name(customer);
  $form->{AR} = $save_AR;

  $form->{invtotal} =
    ($form->{taxincluded}) ? $form->{invtotal} : $form->{invtotal} + $totaltax;

  for $i (1 .. $form->{paidaccounts}) {
    if ($form->parse_amount(\%myconfig, $form->{"paid_$i"})) {
      map {
        $form->{"${_}_$i"} =
          $form->parse_amount(\%myconfig, $form->{"${_}_$i"})
      } qw(paid exchangerate);

      $totalpaid += $form->{"paid_$i"};

      $form->{"exchangerate_$i"} = $exchangerate
        if (
            $form->{"forex_$i"} = (
                 $exchangerate =
                   $form->check_exchangerate(
                   \%myconfig, $form->{currency}, $form->{"datepaid_$i"}, 'buy'
                   )));
    }
  }

  $form->{creditremaining} -=
    ($form->{invtotal} - $totalpaid + $form->{oldtotalpaid} -
     $form->{oldinvtotal});
  $form->{oldinvtotal}  = $form->{invtotal};
  $form->{oldtotalpaid} = $totalpaid;

  &display_form;

  $lxdebug->leave_sub();
}

sub post_payment {
  $lxdebug->enter_sub();

  $form->{defaultcurrency} = $form->get_default_currency(\%myconfig);

  for $i (1 .. $form->{paidaccounts}) {
    if ($form->parse_amount(\%myconfig, $form->{"paid_$i"})) {
      $datepaid = $form->datetonum($form->{"datepaid_$i"}, \%myconfig);

      $form->isblank("datepaid_$i", $locale->text('Payment date missing!'));

      $form->error($locale->text('Cannot post payment for a closed period!'))
        if ($datepaid <= $closedto);

      if ($form->{currency} ne $form->{defaultcurrency}) {
        $form->{"exchangerate_$i"} = $form->{exchangerate}
          if ($invdate == $datepaid);
        $form->isblank("exchangerate_$i",
                       $locale->text('Exchangerate for payment missing!'));
      }
    }
  }

  ($form->{AR})      = split /--/, $form->{AR};
  ($form->{AR_paid}) = split /--/, $form->{AR_paid};
  $form->redirect($locale->text('Payment posted!'))
      if (AR->post_payment(\%myconfig, \%$form));
    $form->error($locale->text('Cannot post payment!'));


  $lxdebug->leave_sub();
}

sub post {
  $lxdebug->enter_sub();

  # check if there is an invoice number, invoice and due date
  $form->isblank("transdate", $locale->text('Invoice Date missing!'));
  $form->isblank("duedate",   $locale->text('Due Date missing!'));
  $form->isblank("customer",  $locale->text('Customer missing!'));

  $closedto  = $form->datetonum($form->{closedto},  \%myconfig);
  $transdate = $form->datetonum($form->{transdate}, \%myconfig);
  $form->error($locale->text('Cannot post transaction for a closed period!')) if ($transdate <= $closedto);

  $form->error($locale->text('Zero amount posting!')) 
    unless grep $_*1, map $form->parse_amount(\%myconfig, $form->{"amount_$_"}), 1..$form->{rowcount};

  $form->isblank("exchangerate", $locale->text('Exchangerate missing!'))
    if ($form->{currency} ne $form->{defaultcurrency});

  delete($form->{AR});

  for $i (1 .. $form->{paidaccounts}) {
    if ($form->parse_amount(\%myconfig, $form->{"paid_$i"})) {
      $datepaid = $form->datetonum($form->{"datepaid_$i"}, \%myconfig);

      $form->isblank("datepaid_$i", $locale->text('Payment date missing!'));

      $form->error($locale->text('Cannot post payment for a closed period!'))
        if ($datepaid <= $closedto);

      if ($form->{currency} ne $form->{defaultcurrency}) {
        $form->{"exchangerate_$i"} = $form->{exchangerate} if ($transdate == $datepaid);
        $form->isblank("exchangerate_$i", $locale->text('Exchangerate for payment missing!'));
      }
    }
  }

  # if oldcustomer ne customer redo form
  ($customer) = split /--/, $form->{customer};
  if ($form->{oldcustomer} ne "$customer--$form->{customer_id}") {
    &update;
    exit;
  }

  $form->{AR}{receivables} = $form->{ARselected};
  $form->{storno}          = 0;

  $form->{id} = 0 if $form->{postasnew};


  if (AR->post_transaction(\%myconfig, \%$form)) {
    # saving the history
    if(!exists $form->{addition} && $form->{id} ne "") {
      $form->{snumbers} = "invnumber_$form->{invnumber}";
      $form->{addition} = "POSTED";
      $form->save_history($form->dbconnect(\%myconfig));
    }
    # /saving the history 
    remove_draft() if $form->{remove_draft};
    $form->redirect($locale->text('Transaction posted!'));
  }
  $form->error($locale->text('Cannot post transaction!'));

  $lxdebug->leave_sub();
}

sub post_as_new {
  $lxdebug->enter_sub();

  $form->{postasnew} = 1;
  # saving the history
  if(!exists $form->{addition} && $form->{id} ne "") {
    $form->{snumbers} = qq|invnumber_| . $form->{invnumber};
  	$form->{addition} = "POSTED AS NEW";
  	$form->save_history($form->dbconnect(\%myconfig));
  }
  # /saving the history 
  &post;

  $lxdebug->leave_sub();
}

sub use_as_template {
  $lxdebug->enter_sub();

  map { delete $form->{$_} } qw(printed emailed queued invnumber invdate deliverydate id datepaid_1 source_1 memo_1 paid_1 exchangerate_1 AP_paid_1 storno);
  $form->{paidaccounts} = 1;
  $form->{rowcount}--;
  $form->{invdate} = $form->current_date(\%myconfig);
  &update;

  $lxdebug->leave_sub();
}

sub delete {
  $lxdebug->enter_sub();

  $form->{title} = $locale->text('Confirm!');

  $form->header;

  delete $form->{header};

  print qq|
<body>

<form method=post action=$form->{script}>
|;

  foreach $key (keys %$form) {
    $form->{$key} =~ s/\"/&quot;/g;
    print qq|<input type=hidden name=$key value="$form->{$key}">\n|;
  }

  print qq|
<h2 class=confirm>$form->{title}</h2>

<h4>|
    . $locale->text('Are you sure you want to delete Transaction')
    . qq| $form->{invnumber}</h4>

<input name=action class=submit type=submit value="|
    . $locale->text('Yes') . qq|">
</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub yes {
  $lxdebug->enter_sub();
  if (AR->delete_transaction(\%myconfig, \%$form, $spool)) {
    # saving the history
    if(!exists $form->{addition}) {
      $form->{snumbers} = qq|invnumber_| . $form->{invnumber};
  	  $form->{addition} = "DELETED";
  	  $form->save_history($form->dbconnect(\%myconfig));
    }
    # /saving the history 
    $form->redirect($locale->text('Transaction deleted!'));
  }
  $form->error($locale->text('Cannot delete transaction!'));

  $lxdebug->leave_sub();
}

sub search {
  $lxdebug->enter_sub();

  # setup customer selection
  $form->all_vc(\%myconfig, "customer", "AR");

  if (@{ $form->{all_customer} }) {
    map { $customer .= "<option>$_->{name}--$_->{id}\n" }
      @{ $form->{all_customer} };
    $customer = qq|<select name=customer><option>\n$customer</select>|;
  } else {
    $customer = qq|<input name=customer size=35>|;
  }

  # departments
  if (@{ $form->{all_departments} }) {
    $form->{selectdepartment} = "<option>\n";

    map {
      $form->{selectdepartment} .=
        "<option>$_->{description}--$_->{id}\n"
    } (@{ $form->{all_departments} });
  }

  $department = qq|
        <tr>
	  <th align=right nowrap>| . $locale->text('Department') . qq|</th>
	  <td colspan=3><select name=department>$form->{selectdepartment}</select></td>
	</tr>
| if $form->{selectdepartment};

  $form->{title} = $locale->text('AR Transactions');
  
  $form->{javascript} .= qq|<script type="text/javascript" src="js/common.js"></script>|;
  
  # use JavaScript Calendar or not
  $form->{jsscript} = 1;
  $jsscript = "";
  if ($form->{jsscript}) {

    # with JavaScript Calendar
    $button1 = qq|
       <td><input name=transdatefrom id=transdatefrom size=11 title="$myconfig{dateformat}" onBlur=\"check_right_date_format(this)\">
       <input type=button name=transdatefrom id="trigger1" value=|
      . $locale->text('button') . qq|></td>
      |;
    $button2 = qq|
       <td><input name=transdateto id=transdateto size=11 title="$myconfig{dateformat}" onBlur=\"check_right_date_format(this)\">
       <input type=button name=transdateto name=transdateto id="trigger2" value=|
      . $locale->text('button') . qq|></td>
     |;

    #write Trigger
    $jsscript =
      Form->write_trigger(\%myconfig, "2", "transdatefrom", "BR", "trigger1",
                          "transdateto", "BL", "trigger2");
  } else {

    # without JavaScript Calendar
    $button1 = qq|
                              <td><input name=transdatefrom id=transdatefrom size=11 title="$myconfig{dateformat}" onBlur=\"check_right_date_format(this)\"></td>|;
    $button2 = qq|
                              <td><input name=transdateto id=transdateto size=11 title="$myconfig{dateformat}" onBlur=\"check_right_date_format(this)\"></td>|;
  }

  $form->get_lists("projects" => { "key" => "ALL_PROJECTS",
                                   "all" => 1 });

  my %labels = ();
  my @values = ("");
  foreach my $item (@{ $form->{"ALL_PROJECTS"} }) {
    push(@values, $item->{"id"});
    $labels{$item->{"id"}} = $item->{"projectnumber"};
  }
  my $projectnumber =
    NTI($cgi->popup_menu('-name' => 'project_id', '-values' => \@values,
                         '-labels' => \%labels));

  $form->{fokus} = "search.customer";
  $form->header;
  $onload = qq|focus()|;
  $onload .= qq|;setupDateFormat('|. $myconfig{dateformat} .qq|', '|. $locale->text("Falsches Datumsformat!") .qq|')|;
  $onload .= qq|;setupPoints('|. $myconfig{numberformat} .qq|', '|. $locale->text("wrongformat") .qq|')|;
  print qq|
<body onLoad="$onload">

<form method=post name="search" action=$form->{script}>

<table width=100%>
  <tr><th class=listtop>$form->{title}</th></tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
	<tr>
	  <th align=right>| . $locale->text('Customer') . qq|</th>
	  <td colspan=3>$customer</td>
	</tr>
	$department
	<tr>
	  <th align=right nowrap>| . $locale->text('Invoice Number') . qq|</th>
	  <td colspan=3><input name=invnumber size=20></td>
	</tr>
	<tr>
	  <th align=right nowrap>| . $locale->text('Order Number') . qq|</th>
	  <td colspan=3><input name=ordnumber size=20></td>
	</tr>
       <tr>
         <th align=right nowrap>| . $locale->text('Transaction description') . qq|</th>
         <td colspan=3><input name=transaction_description size=40></td>
       </tr>
	<tr>
	  <th align=right nowrap>| . $locale->text('Notes') . qq|</th>
	  <td colspan=3><input name=notes size=40></td>
	</tr>
        <tr>
          <th align="right">| . $locale->text("Project Number") . qq|</th>
          <td colspan="3">$projectnumber</td>
        </tr>
	<tr>
	  <th align=right nowrap>| . $locale->text('From') . qq|</th>
          $button1
	  <th align=right>| . $locale->text('Bis') . qq|</th>
          $button2
	</tr>
	<input type=hidden name=sort value=transdate>
      </table>
    </td>
  </tr>
  <tr>
    <td>
      <table>
	<tr>
	  <th align=right nowrap>| . $locale->text('Include in Report') . qq|</th>
	  <td>
	    <table width=100%>
	      <tr>
		<td align=right><input name=open class=checkbox type=checkbox value=Y checked></td>
		<td nowrap>| . $locale->text('Open') . qq|</td>
		<td align=right><input name=closed class=checkbox type=checkbox value=Y></td>
		<td nowrap>| . $locale->text('Closed') . qq|</td>
	      </tr>
	      <tr>
		<td align=right><input name="l_id" class=checkbox type=checkbox value=Y></td>
		<td nowrap>| . $locale->text('ID') . qq|</td>
		<td align=right><input name="l_invnumber" class=checkbox type=checkbox value=Y checked></td>
		<td nowrap>| . $locale->text('Invoice Number') . qq|</td>
		<td align=right><input name="l_ordnumber" class=checkbox type=checkbox value=Y></td>
		<td nowrap>| . $locale->text('Order Number') . qq|</td>
		<td align=right><input name="l_transdate" class=checkbox type=checkbox value=Y checked></td>
		<td nowrap>| . $locale->text('Invoice Date') . qq|</td>
	      </tr>
	      <tr>
		<td align=right><input name="l_name" class=checkbox type=checkbox value=Y checked></td>
		<td nowrap>| . $locale->text('Customer') . qq|</td>
		<td align=right><input name="l_netamount" class=checkbox type=checkbox value=Y></td>
		<td nowrap>| . $locale->text('Amount') . qq|</td>
		<td align=right><input name="l_tax" class=checkbox type=checkbox value=Y></td>
		<td nowrap>| . $locale->text('Tax') . qq|</td>
		<td align=right><input name="l_amount" class=checkbox type=checkbox value=Y checked></td>
		<td nowrap>| . $locale->text('Total') . qq|</td>
	      </tr>
	      <tr>
		<td align=right><input name="l_datepaid" class=checkbox type=checkbox value=Y></td>
		<td nowrap>| . $locale->text('Date Paid') . qq|</td>
		<td align=right><input name="l_paid" class=checkbox type=checkbox value=Y checked></td>
		<td nowrap>| . $locale->text('Paid') . qq|</td>
		<td align=right><input name="l_duedate" class=checkbox type=checkbox value=Y></td>
		<td nowrap>| . $locale->text('Due Date') . qq|</td>
		<td align=right><input name="l_due" class=checkbox type=checkbox value=Y></td>
		<td nowrap>| . $locale->text('Amount Due') . qq|</td>
	      </tr>
	      <tr>
		<td align=right><input name="l_notes" class=checkbox type=checkbox value=Y></td>
		<td nowrap>| . $locale->text('Notes') . qq|</td>
		<td align=right><input name="l_employee" class=checkbox type=checkbox value=Y></td>
		<td nowrap>| . $locale->text('Salesperson') . qq|</td>
		<td align=right><input name="l_shippingpoint" class=checkbox type=checkbox value=Y></td>
		<td nowrap>| . $locale->text('Shipping Point') . qq|</td>
		<td align=right><input name="l_shipvia" class=checkbox type=checkbox value=Y></td>
		<td nowrap>| . $locale->text('Ship via') . qq|</td>
	      </tr>
	      <tr>
		<td align=right><input name="l_subtotal" class=checkbox type=checkbox value=Y></td>
		<td nowrap>| . $locale->text('Subtotal') . qq|</td>
		<td align=right><input name="l_globalprojectnumber" class=checkbox type=checkbox value=Y></td>
		<td nowrap>| . $locale->text('Project Number') . qq|</td>
		<td align=right><input name="l_transaction_description" class=checkbox type=checkbox value=Y></td>
		<td nowrap>| . $locale->text('Transaction description') . qq|</td>
	      </tr>
	    </table>
	  </td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<input type=hidden name=nextsub value=$form->{nextsub}>

<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<br>
<input class=submit type=submit name=action value="|
    . $locale->text('Continue') . qq|">

</form>

</body>

$jsscript

</html>
|;

  $lxdebug->leave_sub();
}

sub create_subtotal_row {
  $lxdebug->enter_sub();

  my ($totals, $columns, $column_alignment, $subtotal_columns, $class) = @_;

  my $row = { map { $_ => { 'data' => '', 'class' => $class, 'align' => $column_alignment->{$_}, } } @{ $columns } };

  map { $row->{$_}->{data} = $form->format_amount(\%myconfig, $totals->{$_}, 2) } @{ $subtotal_columns };

  $row->{tax}->{data} = $form->format_amount(\%myconfig, $totals->{amount} - $totals->{netamount}, 2);

  map { $totals->{$_} = 0 } @{ $subtotal_columns };

  $lxdebug->leave_sub();

  return $row;
}

sub ar_transactions {
  $lxdebug->enter_sub();

  ($form->{customer}, $form->{customer_id}) = split(/--/, $form->{customer});

  $form->{sort} ||= 'transdate';

  AR->ar_transactions(\%myconfig, \%$form);

  $form->{title} = $locale->text('AR Transactions');

  my $report = SL::ReportGenerator->new(\%myconfig, $form);

  my @columns =
    qw(transdate id type invnumber ordnumber name netamount tax amount paid
       datepaid due duedate transaction_description notes employee shippingpoint shipvia
       globalprojectnumber);

  my @hidden_variables = map { "l_${_}" } @columns;
  push @hidden_variables, "l_subtotal", qw(open closed customer invnumber ordnumber transaction_description notes project_id transdatefrom transdateto);

  my $href = build_std_url('action=ar_transactions', grep { $form->{$_} } @hidden_variables);

  my %column_defs = (
    'transdate'               => { 'text' => $locale->text('Date'), },
    'id'                      => { 'text' => $locale->text('ID'), },
    'type'                    => { 'text' => $locale->text('Type'), },
    'invnumber'               => { 'text' => $locale->text('Invoice'), },
    'ordnumber'               => { 'text' => $locale->text('Order'), },
    'name'                    => { 'text' => $locale->text('Customer'), },
    'netamount'               => { 'text' => $locale->text('Amount'), },
    'tax'                     => { 'text' => $locale->text('Tax'), },
    'amount'                  => { 'text' => $locale->text('Total'), },
    'paid'                    => { 'text' => $locale->text('Paid'), },
    'datepaid'                => { 'text' => $locale->text('Date Paid'), },
    'due'                     => { 'text' => $locale->text('Amount Due'), },
    'duedate'                 => { 'text' => $locale->text('Due Date'), },
    'transaction_description' => { 'text' => $locale->text('Transaction description'), },
    'notes'                   => { 'text' => $locale->text('Notes'), },
    'employee'                => { 'text' => $locale->text('Salesperson'), },
    'shippingpoint'           => { 'text' => $locale->text('Shipping Point'), },
    'shipvia'                 => { 'text' => $locale->text('Ship via'), },
    'globalprojectnumber'     => { 'text' => $locale->text('Project Number'), },
  );

  foreach my $name (qw(id transdate duedate invnumber ordnumber name datepaid
                       employee shippingpoint shipvia)) {
    $column_defs{$name}->{link} = $href . "&sort=$name";
  }

  my %column_alignment = map { $_ => 'right' } qw(netamount tax amount paid due);

  $form->{"l_type"} = "Y";
  map { $column_defs{$_}->{visible} = $form->{"l_${_}"} ? 1 : 0 } @columns;

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);

  $report->set_export_options('ar_transactions', @hidden_variables);

  my @options;
  if ($form->{customer}) {
    push @options, $locale->text('Customer') . " : $form->{customer}";
  }
  if ($form->{department}) {
    ($department) = split /--/, $form->{department};
    push @options, $locale->text('Department') . " : $department";
  }
  if ($form->{invnumber}) {
    push @options, $locale->text('Invoice Number') . " : $form->{invnumber}";
  }
  if ($form->{ordnumber}) {
    push @options, $locale->text('Order Number') . " : $form->{ordnumber}";
  }
  if ($form->{notes}) {
    push @options, $locale->text('Notes') . " : $form->{notes}";
  }
  if ($form->{transaction_description}) {
    push @options, $locale->text('Transaction description') . " : $form->{transaction_description}";
  }
  if ($form->{transdatefrom}) {
    push @options, $locale->text('From') . "&nbsp;" . $locale->date(\%myconfig, $form->{transdatefrom}, 1);
  }
  if ($form->{transdateto}) {
    push @options, $locale->text('Bis') . "&nbsp;" . $locale->date(\%myconfig, $form->{transdateto}, 1);
  }
  if ($form->{open}) {
    push @options, $locale->text('Open');
  }
  if ($form->{closed}) {
    push @options, $locale->text('Closed');
  }

  $report->set_options('top_info_text'        => join("\n", @options),
                       'raw_bottom_info_text' => $form->parse_html_template('ar/ar_transactions_bottom'),
                       'output_format'        => 'HTML',
                       'title'                => $form->{title},
                       'attachment_basename'  => $locale->text('invoice_list') . strftime('_%Y%m%d', localtime time),
    );
  $report->set_options_from_form();

  # add sort and escape callback, this one we use for the add sub
  $form->{callback} = $href .= "&sort=$form->{sort}";

  # escape callback for href
  $callback = $form->escape($href);

  my @subtotal_columns = qw(netamount amount paid due);

  my %totals    = map { $_ => 0 } @subtotal_columns;
  my %subtotals = map { $_ => 0 } @subtotal_columns;

  my $idx = 0;

  foreach $ar (@{ $form->{AR} }) {
    $ar->{tax} = $ar->{amount} - $ar->{netamount};
    $ar->{due} = $ar->{amount} - $ar->{paid};

    map { $subtotals{$_} += $ar->{$_};
          $totals{$_}    += $ar->{$_} } @subtotal_columns;

    map { $ar->{$_} = $form->format_amount(\%myconfig, $ar->{$_}, 2) } qw(netamount tax amount paid due);

    my $is_storno  = $ar->{storno} && IS->is_storno(\%myconfig, $form, 'ar');
    my $has_storno = $ar->{storno} && !$is_storno;

    $ar->{type} =
      $has_storno       ? $locale->text("Invoice with Storno (abbreviation)") :
      $is_storno        ? $locale->text("Storno (one letter abbreviation)") :
      $ar->{amount} < 0 ? $locale->text("Credit note (one letter abbreviation)") :
      $ar->{invoice}    ? $locale->text("Invoice (one letter abbreviation)") :
                          $locale->text("AR Transaction (abbreviation)");

    my $row = { };

    foreach my $column (@columns) {
      $row->{$column} = {
        'data'  => $ar->{$column},
        'align' => $column_alignment{$column},
      };
    }

    $row->{invnumber}->{link} = build_std_url("script=" . ($ar->{invoice} ? 'is.pl' : 'ar.pl'), 'action=edit')
      . "&id=" . E($ar->{id}) . "&callback=${callback}";

    my $row_set = [ $row ];

    if (($form->{l_subtotal} eq 'Y')
        && (($idx == (scalar @{ $form->{AR} } - 1))
            || ($ar->{ $form->{sort} } ne $form->{AR}->[$idx + 1]->{ $form->{sort} }))) {
      push @{ $row_set }, create_subtotal_row(\%subtotals, \@columns, \%column_alignment, \@subtotal_columns, 'listsubtotal');
    }

    $report->add_data($row_set);

    $idx++;
  }

  $report->add_separator();
  $report->add_data(create_subtotal_row(\%totals, \@columns, \%column_alignment, \@subtotal_columns, 'listtotal'));

  $report->generate_with_headers();

  $lxdebug->leave_sub();
}

sub storno {
  $lxdebug->enter_sub();

  if (IS->has_storno(\%myconfig, $form, 'ar')) {
    $form->{title} = $locale->text("Cancel Accounts Receivables Transaction");
    $form->error($locale->text("Transaction has already been cancelled!"));
  }

  # negate amount/taxes
  for my $i (1 .. $form->{rowcount}) {
    $form->{"amount_$i"} *= -1;
    $form->{"tax_$i"}    *= -1; 
  }

  # format things
  for my $i (1 .. $form->{rowcount}) {
    for (qw(amount tax)) {
      $form->{"${_}_$i"} = $form->format_amount(\%myconfig, $form->{"${_}_$i"}, 2) if $form->{"${_}_$i"};
    }
  }

  $form->{storno}      = 1;
  $form->{storno_id}   = $form->{id};
  $form->{id}          = 0;

  $form->{invnumber}   = "Storno-" . $form->{invnumber};

  post();

  # saving the history
  if(!exists $form->{addition} && $form->{id} ne "") {
    $form->{snumbers} = "ordnumber_$form->{ordnumber}";
    $form->{addition} = "STORNO";
    $form->save_history($form->dbconnect(\%myconfig));
  }
  # /saving the history 

  $lxdebug->leave_sub();
}
