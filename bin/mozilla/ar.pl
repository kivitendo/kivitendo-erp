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

use SL::AR;
use SL::IS;
use SL::PE;
use Data::Dumper;

require "$form->{path}/arap.pl";

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

  $form->{title}    = "Add";
  $form->{callback} =
    "$form->{script}?action=add&path=$form->{path}&login=$form->{login}&password=$form->{password}"
    unless $form->{callback};

  &create_links;
  &display_form;

  $lxdebug->leave_sub();
}

sub edit {
  $lxdebug->enter_sub();

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

  IS->get_customer(\%myconfig, \%$form);

  $form->{duedate}     = $duedate if $duedate;
  $form->{oldcustomer} = "$form->{customer}--$form->{customer_id}";
  $form->{rowcount}    = 1;

  # currencies
  @curr = split /:/, $form->{currencies};
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

  map {
    $tax .=
      qq|<option value=\"$_->{taxkey}--$_->{rate}\">$_->{taxdescription}  |
      . ($_->{rate} * 100) . qq| %|
  } @{ $form->{TAX} };
  $form->{taxchart}       = $tax;
  $form->{selecttaxchart} = $tax;

  # forex
  $form->{forex} = $form->{exchangerate};
  $exchangerate = ($form->{exchangerate}) ? $form->{exchangerate} : 1;
  foreach $key (keys %{ $form->{AR_links} }) {

    foreach $ref (@{ $form->{AR_links}{$key} }) {
      if ($key eq "AR_paid") {
        $form->{"select$key"} .=
          "<option value=\"$ref->{accno}\">$ref->{accno}--$ref->{description}</option>\n";
      } else {
        $form->{"select$key"} .=
          "<option value=\"$ref->{accno}--$ref->{taxkey}\">$ref->{accno}--$ref->{description}</option>\n";
      }
    }

    $form->{$key} = $form->{"select$key"};

    # if there is a value we have an old entry
    my $j = 0;
    my $k = 0;

    for $i (1 .. scalar @{ $form->{acc_trans}{$key} }) {
      if ($key eq "AR_paid") {
        $j++;
        $form->{"AR_paid_$j"} =
          "$form->{acc_trans}{$key}->[$i-1]->{accno}--$form->{acc_trans}{$key}->[$i-1]->{description}";

        # reverse paid
        $form->{"paid_$j"} = $form->{acc_trans}{$key}->[$i - 1]->{amount} * -1;
        $form->{"datepaid_$j"} =
          $form->{acc_trans}{$key}->[$i - 1]->{transdate};
        $form->{"source_$j"} = $form->{acc_trans}{$key}->[$i - 1]->{source};
        $form->{"memo_$j"}   = $form->{acc_trans}{$key}->[$i - 1]->{memo};

        $form->{"forex_$j"} = $form->{"exchangerate_$i"} =
          $form->{acc_trans}{$key}->[$i - 1]->{exchangerate};
        $form->{"AR_paid_$j"} = "$form->{acc_trans}{$key}->[$i-1]->{accno}";
        $form->{paidaccounts}++;
      } else {

        $akey = $key;
        $akey =~ s/AR_//;

        if ($key eq "AR_tax" || $key eq "AP_tax") {
          $form->{"${key}_$form->{acc_trans}{$key}->[$i-1]->{accno}"} =
            "$form->{acc_trans}{$key}->[$i-1]->{accno}--$form->{acc_trans}{$key}->[$i-1]->{description}";
          $form->{"${akey}_$form->{acc_trans}{$key}->[$i-1]->{accno}"} =
            $form->round_amount(
                  $form->{acc_trans}{$key}->[$i - 1]->{amount} / $exchangerate,
                  2);

          if ($form->{"$form->{acc_trans}{$key}->[$i-1]->{accno}_rate"} > 0) {
            $totaltax +=
              $form->{"${akey}_$form->{acc_trans}{$key}->[$i-1]->{accno}"};
            $taxrate +=
              $form->{"$form->{acc_trans}{$key}->[$i-1]->{accno}_rate"};
          } else {
            $totalwithholding +=
              $form->{"${akey}_$form->{acc_trans}{$key}->[$i-1]->{accno}"};
            $withholdingrate +=
              $form->{"$form->{acc_trans}{$key}->[$i-1]->{accno}_rate"};
          }
          $index = $form->{acc_trans}{$key}->[$i - 1]->{index};
          $form->{"tax_$index"} = $form->{acc_trans}{$key}->[$i - 1]->{amount};
          $totaltax += $form->{"tax_$index"};

        } else {
          $k++;
          $form->{"${akey}_$k"} =
            $form->round_amount(
                  $form->{acc_trans}{$key}->[$i - 1]->{amount} / $exchangerate,
                  2);
          if ($akey eq 'amount') {
            $form->{rowcount}++;
            $totalamount += $form->{"${akey}_$i"};

            $form->{"oldprojectnumber_$k"} = $form->{"projectnumber_$k"} =
              "$form->{acc_trans}{$key}->[$i-1]->{projectnumber}";
            $form->{taxrate} = $form->{acc_trans}{$key}->[$i - 1]->{rate};
            $form->{"project_id_$k"} =
              "$form->{acc_trans}{$key}->[$i-1]->{project_id}";
          }
          $form->{"${key}_$k"} =
            "$form->{acc_trans}{$key}->[$i-1]->{accno}--$form->{acc_trans}{$key}->[$i-1]->{description}";
          $form->{"${key}_$i"} =
            "$form->{acc_trans}{$key}->[$i-1]->{accno}--$form->{acc_trans}{$key}->[$i-1]->{description}";
          $form->{"select${key}"} =~
            /<option value=\"($form->{acc_trans}{$key}->[$i-1]->{accno}--[^\"]*)\">$form->{acc_trans}{$key}->[$i-1]->{accno}--$form->{acc_trans}{$key}->[$i-1]->{description}<\/option>\n/;
          $test = $1;
          $form->{"${key}_$k"} = $1;
          if ($akey eq 'amount') {
            $form->{"taxchart_$k"} = $form->{taxchart};
            $form->{"taxchart_$k"} =~
              /<option value=\"($form->{acc_trans}{$key}->[$i-1]->{taxkey}--[^\"]*)/;
            $form->{"taxchart_$k"} = $1;
          }
        }
      }
    }
  }

  $form->{taxincluded}  = $taxincluded if ($form->{id});
  $form->{paidaccounts} = 1            if not defined $form->{paidaccounts};

  if ($form->{taxincluded} && $form->{taxrate} && $totalamount) {

    # add tax to amounts and invtotal
    for $i (1 .. $form->{rowcount}) {
      $taxamount =
        ($totaltax + $totalwithholding) * $form->{"amount_$i"} / $totalamount;
      $tax = $form->round_amount($taxamount, 2);
      $diff                += ($taxamount - $tax);
      $form->{"amount_$i"} += $form->{"tax_$i"};
    }
    $form->{amount_1} += $form->round_amount($diff, 2);
  }

  $taxamount = $form->round_amount($taxamount, 2);
  $form->{tax} = $taxamount;

  $form->{invtotal} = $totalamount + $totaltax;

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
    var reg = /--([0-9])*/;
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
  $selectAR_amount_unquoted = $form->{selectAR_amount};
  $taxchart                 = $form->{taxchart};
  map { $form->{$_} =~ s/\"/&quot;/g }
    qw(AR_amount selectAR_amount AR taxchart);

  # format amounts
  $form->{exchangerate} =
    $form->format_amount(\%myconfig, $form->{exchangerate});

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

  $taxincluded = "";

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
    ? qq|<select name=customer>$form->{selectcustomer}</select>|
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

  $form->{fokus} = "arledger.customer";

  # use JavaScript Calendar or not
  $form->{jsscript} = $jscalendar;
  $jsscript = "";
  if ($form->{jsscript}) {

    # with JavaScript Calendar
    $button1 = qq|
       <td><input name=transdate id=transdate size=11 title="$myconfig{dateformat}" value=$form->{transdate}></td>
       <td><input type=button name=transdate id="trigger1" value=|
      . $locale->text('button') . qq|></td>
       |;
    $button2 = qq|
       <td><input name=duedate id=duedate size=11 title="$myconfig{dateformat}" value=$form->{duedate}></td>
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
      qq|<td><input name=transdate id=transdate size=11 title="$myconfig{dateformat}" value=$form->{transdate}></td>|;
    $button2 =
      qq|<td><input name=duedate id=duedate size=11 title="$myconfig{dateformat}" value=$form->{duedate}></td>|;
  }

  $form->header;

  print qq|
<body onLoad="fokus()">

<form method=post name="arledger" action=$form->{script}>

<input type=hidden name=id value=$form->{id}>
<input type=hidden name=sort value=$form->{sort}>
<input type=hidden name=closedto value=$form->{closedto}>
<input type=hidden name=locked value=$form->{locked}>
<input type=hidden name=title value="$title">

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
		<td colspan=3>$customer</td>
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
  <input type=hidden name=selectAR_amount value="$form->{selectAR_amount}">
  <input type=hidden name=AR_amount value="$form->{AR_amount}">
  <input type=hidden name=taxchart value="$form->{taxchart}">
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
    $selectAR_amount = $selectAR_amount_unquoted;
    $selectAR_amount =~
      s/option value=\"$form->{"AR_amount_$i"}\"/option value=\"$form->{"AR_amount_$i"}\" selected/;
    $tax          = $taxchart;
    $tax_selected = $form->{"taxchart_$i"};
    $tax =~ s/value=\"$tax_selected\"/value=\"$tax_selected\" selected/;
    $tax =
      qq|<td><select id="taxchart_$i" name="taxchart_$i">$tax</select></td>|;

    print qq|
	<tr>
          <td width=50%><select name="AR_amount_$i" onChange="setTaxkey(this, $i)">$selectAR_amount</select></td>
          <td><input name="amount_$i" size=10 value=$form->{"amount_$i"}></td>
          <td><input name="tax_$i" size=10 value=$form->{"tax_$i"}></td>
          <td><input type="checkbox" name="korrektur_$i" value="1"></td>
          $tax
	  <td><input name="projectnumber_$i" size=20 value="$form->{"projectnumber_$i"}">
	      <input type=hidden name="project_id_$i" value=$form->{"project_id_$i"}>
	      <input type=hidden name="oldprojectnumber_$i" value="$form->{"oldprojectnumber_$i"}"></td>
	</tr>
|;
    $amount  = "";
    $project = "";
  }

  $form->{invtotal} = $form->format_amount(\%myconfig, $form->{invtotal}, 2);

  print qq|
        <tr>
          <td colspan=6>
            <hr noshade>
          </td>
        </tr>
        <tr>
	  <td><select name=ARselected>$form->{selectAR}</select></td>
          <input type=hidden name=AR value="$form->{AR}">
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
	  <th colspan=6 class=listheading>|
    . $locale->text('Incoming Payments') . qq|</th>
	</tr>
|;

  if ($form->{currency} eq $form->{defaultcurrency}) {
    @column_index = qw(datepaid source memo paid AR_paid);
  } else {
    @column_index = qw(datepaid source memo paid exchangerate AR_paid);
  }

  $column_data{datepaid}     = "<th>" . $locale->text('Date') . "</th>";
  $column_data{paid}         = "<th>" . $locale->text('Amount') . "</th>";
  $column_data{exchangerate} = "<th>" . $locale->text('Exch') . "</th>";
  $column_data{AR_paid}      = "<th>" . $locale->text('Account') . "</th>";
  $column_data{source}       = "<th>" . $locale->text('Source') . "</th>";
  $column_data{memo}         = "<th>" . $locale->text('Memo') . "</th>";

  print "
        <tr>
";
  map { print "$column_data{$_}\n" } @column_index;
  print "
        </tr>
";

  $form->{paidaccounts}++ if ($form->{"paid_$form->{paidaccounts}"});
  for $i (1 .. $form->{paidaccounts}) {
    print "
        <tr>
";

    $form->{"selectAR_paid_$i"} = $form->{selectAR_paid};
    $form->{"selectAR_paid_$i"} =~
      s/option value=\"$form->{"AR_paid_$i"}\">/option value=\"$form->{"AR_paid_$i"}\" selected>/;

    # format amounts
    $form->{"paid_$i"} =
      $form->format_amount(\%myconfig, $form->{"paid_$i"}, 2);
    $form->{"exchangerate_$i"} =
      $form->format_amount(\%myconfig, $form->{"exchangerate_$i"});

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
      qq|<td align=center><input name="paid_$i" size=11 value=$form->{"paid_$i"}></td>|;
    $column_data{AR_paid} =
      qq|<td align=center><select name="AR_paid_$i">$form->{"selectAR_paid_$i"}</select></td>|;
    $column_data{exchangerate} = qq|<td align=center>$exchangerate</td>|;
    $column_data{datepaid}     =
      qq|<td align=center><input name="datepaid_$i" size=11 value=$form->{"datepaid_$i"}></td>|;
    $column_data{source} =
      qq|<td align=center><input name="source_$i" size=11 value="$form->{"source_$i"}"></td>|;
    $column_data{memo} =
      qq|<td align=center><input name="memo_$i" size=11 value="$form->{"memo_$i"}"></td>|;

    map { print qq|$column_data{$_}\n| } @column_index;

    print "
        </tr>
";
  }
  map { $form->{$_} =~ s/\"/&quot;/g } qw(selectAR_paid);
  print qq|
<input type=hidden name=paidaccounts value=$form->{paidaccounts}>
<input type=hidden name=selectAR_paid value="$form->{selectAR_paid}">

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

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<br>
|;

  $transdate = $form->datetonum($form->{transdate}, \%myconfig);
  $closedto  = $form->datetonum($form->{closedto},  \%myconfig);

  if ($form->{id} && $form->{radier}) {

    print qq|<input class=submit type=submit name=action value="|
      . $locale->text('Update') . qq|">
|;

    if (!$form->{revtrans}) {
      if (!$form->{locked}) {
        print qq|
	<input class=submit type=submit name=action value="|
          . $locale->text('Post') . qq|">
	<input class=submit type=submit name=action value="|
          . $locale->text('Delete') . qq|">
|;
      }
    }

    if ($transdate > $closedto) {
      print qq|
<input class=submit type=submit name=action value="|
        . $locale->text('Post as new') . qq|">
|;
    }

  } else {
    if ($transdate > $closedto) {
      print qq|<input class=submit type=submit name=action value="|
        . $locale->text('Update') . qq|">
      <input class=submit type=submit name=action value="|
        . $locale->text('Post') . qq|">|;
    }
  }

  if ($form->{menubar}) {
    require "$form->{path}/menu.pl";
    &menubar;
  }

  print "
</form>

</body>
</html>
";

  $lxdebug->leave_sub();
}

sub update {
  $lxdebug->enter_sub();

  my $display = shift;

  #   if ($display) {
  #     goto TAXCALC;
  #   }

  $form->{invtotal} = 0;

  #   $form->{selectAR_amount} = $form->{AR_amount};
  #   $form->{selectAR_amount} =~
  #     s/value=\"$form->{AR_amountselected}\"/value=\"$form->{AR_amountselected}\" selected/;

  $form->{selectAR} = $form->{AR};

  $form->{selectAR} =~
    s/value=\"$form->{ARselected}\"/value=\"$form->{ARselected}\" selected/;

  ($AR_amountaccno, $AR_amounttaxkey) =
    split(/--/, $form->{AR_amountselected});
  $form->{selecttaxchart} = $form->{taxchart};
  $form->{selecttaxchart} =~
    s/value=\"$AR_amounttaxkey--([^\"]*)\"/value=\"$AR_amounttaxkey--$1\" selected/;

  $form->{rate} = $1;

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

  &check_project;

  $form->{invtotal} =
    ($form->{taxincluded}) ? $form->{invtotal} : $form->{invtotal} + $totaltax;

  for $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"}) {
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

sub post {
  $lxdebug->enter_sub();

  # check if there is an invoice number, invoice and due date
  $form->isblank("transdate", $locale->text('Invoice Date missing!'));
  $form->isblank("duedate",   $locale->text('Due Date missing!'));
  $form->isblank("customer",  $locale->text('Customer missing!'));

  $closedto  = $form->datetonum($form->{closedto},  \%myconfig);
  $transdate = $form->datetonum($form->{transdate}, \%myconfig);

  $form->error($locale->text('Cannot post transaction for a closed period!'))
    if ($transdate <= $closedto);

  $form->isblank("exchangerate", $locale->text('Exchangerate missing!'))
    if ($form->{currency} ne $form->{defaultcurrency});

  delete($form->{AR});

  for $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"}) {
      $datepaid = $form->datetonum($form->{"datepaid_$i"}, \%myconfig);

      $form->isblank("datepaid_$i", $locale->text('Payment date missing!'));

      $form->error($locale->text('Cannot post payment for a closed period!'))
        if ($datepaid <= $closedto);

      if ($form->{currency} ne $form->{defaultcurrency}) {
        $form->{"exchangerate_$i"} = $form->{exchangerate}
          if ($transdate == $datepaid);
        $form->isblank("exchangerate_$i",
                       $locale->text('Exchangerate for payment missing!'));
      }
    }
  }

  # if oldcustomer ne customer redo form
  ($customer) = split /--/, $form->{customer};
  if ($form->{oldcustomer} ne "$customer--$form->{customer_id}") {
    &update;
    exit;
  }

  ($creditaccno, $credittaxkey) = split /--/, $form->{AR_amountselected};
  ($taxkey,      $NULL)         = split /--/, $form->{taxchartselected};
  ($receivablesaccno, $payablestaxkey) = split /--/, $form->{ARselected};
  $form->{AR}{amount_1}    = $creditaccno;
  $form->{AR}{receivables} = $receivablesaccno;
  $form->{taxkey}          = $taxkey;

  $form->{invnumber} = $form->update_defaults(\%myconfig, "invnumber")
    unless $form->{invnumber};

  $form->{id} = 0 if $form->{postasnew};

  $form->redirect($locale->text('Transaction posted!'))
    if (AR->post_transaction(\%myconfig, \%$form));
  $form->error($locale->text('Cannot post transaction!'));

  $lxdebug->leave_sub();
}

sub post_as_new {
  $lxdebug->enter_sub();

  $form->{postasnew} = 1;
  &post;

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

  $form->redirect($locale->text('Transaction deleted!'))
    if (AR->delete_transaction(\%myconfig, \%$form, $spool));
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

  # use JavaScript Calendar or not
  $form->{jsscript} = $jscalendar;
  $jsscript = "";
  if ($form->{jsscript}) {

    # with JavaScript Calendar
    $button1 = qq|
       <td><input name=transdatefrom id=transdatefrom size=11 title="$myconfig{dateformat}">
       <input type=button name=transdatefrom id="trigger1" value=|
      . $locale->text('button') . qq|></td>
      |;
    $button2 = qq|
       <td><input name=transdateto id=transdateto size=11 title="$myconfig{dateformat}">
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
                              <td><input name=transdatefrom id=transdatefrom size=11 title="$myconfig{dateformat}"></td>|;
    $button2 = qq|
                              <td><input name=transdateto id=transdateto size=11 title="$myconfig{dateformat}"></td>|;
  }

  $form->{fokus} = "search.customer";
  $form->header;

  print qq|
<body onLoad="fokus()">

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
	  <th align=right nowrap>| . $locale->text('Notes') . qq|</th>
	  <td colspan=3><input name=notes size=40></td>
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

<input type=hidden name=path value=$form->{path}>
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

sub ar_transactions {
  $lxdebug->enter_sub();

  $form->{customer} = $form->unescape($form->{customer});
  ($form->{customer}, $form->{customer_id}) = split(/--/, $form->{customer});

  AR->ar_transactions(\%myconfig, \%$form);

  $callback =
    "$form->{script}?action=ar_transactions&path=$form->{path}&login=$form->{login}&password=$form->{password}";
  $href = $callback;

  if ($form->{customer}) {
    $callback .= "&customer=" . $form->escape($form->{customer}, 1);
    $href .= "&customer=" . $form->escape($form->{customer});
    $option = $locale->text('Customer') . " : $form->{customer}";
  }
  if ($form->{department}) {
    $callback .= "&department=" . $form->escape($form->{department}, 1);
    $href .= "&department=" . $form->escape($form->{department});
    ($department) = split /--/, $form->{department};
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('Department') . " : $department";
  }
  if ($form->{invnumber}) {
    $callback .= "&invnumber=" . $form->escape($form->{invnumber}, 1);
    $href .= "&invnumber=" . $form->escape($form->{invnumber});
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('Invoice Number') . " : $form->{invnumber}";
  }
  if ($form->{ordnumber}) {
    $callback .= "&ordnumber=" . $form->escape($form->{ordnumber}, 1);
    $href .= "&ordnumber=" . $form->escape($form->{ordnumber});
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('Order Number') . " : $form->{ordnumber}";
  }
  if ($form->{notes}) {
    $callback .= "&notes=" . $form->escape($form->{notes}, 1);
    $href .= "&notes=" . $form->escape($form->{notes});
    $option .= "\n<br>" if $option;
    $option .= $locale->text('Notes') . " : $form->{notes}";
  }

  if ($form->{transdatefrom}) {
    $callback .= "&transdatefrom=$form->{transdatefrom}";
    $href     .= "&transdatefrom=$form->{transdatefrom}";
    $option   .= "\n<br>" if ($option);
    $option   .=
        $locale->text('From') . "&nbsp;"
      . $locale->date(\%myconfig, $form->{transdatefrom}, 1);
  }
  if ($form->{transdateto}) {
    $callback .= "&transdateto=$form->{transdateto}";
    $href     .= "&transdateto=$form->{transdateto}";
    $option   .= "\n<br>" if ($option);
    $option   .=
        $locale->text('Bis') . "&nbsp;"
      . $locale->date(\%myconfig, $form->{transdateto}, 1);
  }
  if ($form->{open}) {
    $callback .= "&open=$form->{open}";
    $href     .= "&open=$form->{open}";
    $option   .= "\n<br>" if ($option);
    $option   .= $locale->text('Open');
  }
  if ($form->{closed}) {
    $callback .= "&closed=$form->{closed}";
    $href     .= "&closed=$form->{closed}";
    $option   .= "\n<br>" if ($option);
    $option   .= $locale->text('Closed');
  }

  @columns = $form->sort_columns(
    qw(transdate id invnumber ordnumber name netamount tax amount paid datepaid due duedate notes employee shippingpoint shipvia)
  );

  foreach $item (@columns) {
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

  $column_header{id} =
      "<th><a class=listheading href=$href&sort=id>"
    . $locale->text('ID')
    . "</a></th>";
  $column_header{transdate} =
      "<th><a class=listheading href=$href&sort=transdate>"
    . $locale->text('Date')
    . "</a></th>";
  $column_header{duedate} =
      "<th><a class=listheading href=$href&sort=duedate>"
    . $locale->text('Due Date')
    . "</a></th>";
  $column_header{invnumber} =
      "<th><a class=listheading href=$href&sort=invnumber>"
    . $locale->text('Invoice')
    . "</a></th>";
  $column_header{ordnumber} =
      "<th><a class=listheading href=$href&sort=ordnumber>"
    . $locale->text('Order')
    . "</a></th>";
  $column_header{name} =
      "<th><a class=listheading href=$href&sort=name>"
    . $locale->text('Customer')
    . "</a></th>";
  $column_header{netamount} =
    "<th class=listheading>" . $locale->text('Amount') . "</th>";
  $column_header{tax} =
    "<th class=listheading>" . $locale->text('Tax') . "</th>";
  $column_header{amount} =
    "<th class=listheading>" . $locale->text('Total') . "</th>";
  $column_header{paid} =
    "<th class=listheading>" . $locale->text('Paid') . "</th>";
  $column_header{datepaid} =
      "<th><a class=listheading href=$href&sort=datepaid>"
    . $locale->text('Date Paid')
    . "</a></th>";
  $column_header{due} =
    "<th class=listheading>" . $locale->text('Amount Due') . "</th>";
  $column_header{notes} =
    "<th class=listheading>" . $locale->text('Notes') . "</th>";
  $column_header{employee} =
    "<th><a class=listheading href=$href&sort=employee>"
    . $locale->text('Salesperson') . "</th>";

  $column_header{shippingpoint} =
      "<th><a class=listheading href=$href&sort=shippingpoint>"
    . $locale->text('Shipping Point')
    . "</a></th>";
  $column_header{shipvia} =
      "<th><a class=listheading href=$href&sort=shipvia>"
    . $locale->text('Ship via')
    . "</a></th>";

  $form->{title} = $locale->text('AR Transactions');

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

  map { print "\n$column_header{$_}" } @column_index;

  print qq|
	</tr>
|;

  # add sort and escape callback, this one we use for the add sub
  $form->{callback} = $callback .= "&sort=$form->{sort}";

  # escape callback for href
  $callback = $form->escape($callback);

  if (@{ $form->{AR} }) {
    $sameitem = $form->{AR}->[0]->{ $form->{sort} };
  }

  # sums and tax on reports by Antonio Gallardo
  #
  foreach $ar (@{ $form->{AR} }) {

    if ($form->{l_subtotal} eq 'Y') {
      if ($sameitem ne $ar->{ $form->{sort} }) {
        &ar_subtotal;
      }
    }

    $column_data{netamount} =
        "<td align=right>"
      . $form->format_amount(\%myconfig, $ar->{netamount}, 2, "&nbsp;")
      . "</td>";
    $column_data{tax} = "<td align=right>"
      . $form->format_amount(\%myconfig, $ar->{amount} - $ar->{netamount},
                             2, "&nbsp;")
      . "</td>";
    $column_data{amount} =
      "<td align=right>"
      . $form->format_amount(\%myconfig, $ar->{amount}, 2, "&nbsp;") . "</td>";
    $column_data{paid} =
      "<td align=right>"
      . $form->format_amount(\%myconfig, $ar->{paid}, 2, "&nbsp;") . "</td>";
    $column_data{due} = "<td align=right>"
      . $form->format_amount(\%myconfig, $ar->{amount} - $ar->{paid},
                             2, "&nbsp;")
      . "</td>";

    $subtotalnetamount += $ar->{netamount};
    $subtotalamount    += $ar->{amount};
    $subtotalpaid      += $ar->{paid};
    $subtotaldue       += $ar->{amount} - $ar->{paid};

    $totalnetamount += $ar->{netamount};
    $totalamount    += $ar->{amount};
    $totalpaid      += $ar->{paid};
    $totaldue       += ($ar->{amount} - $ar->{paid});

    $column_data{transdate} = "<td>$ar->{transdate}&nbsp;</td>";
    $column_data{id}        = "<td>$ar->{id}</td>";
    $column_data{datepaid}  = "<td>$ar->{datepaid}&nbsp;</td>";
    $column_data{duedate}   = "<td>$ar->{duedate}&nbsp;</td>";

    $module = ($ar->{invoice}) ? "is.pl" : $form->{script};

    $column_data{invnumber} =
      "<td><a href=$module?action=edit&id=$ar->{id}&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback>$ar->{invnumber}</a></td>";
    $column_data{ordnumber} = "<td>$ar->{ordnumber}&nbsp;</td>";
    $column_data{name}      = "<td>$ar->{name}</td>";
    $ar->{notes} =~ s/\r\n/<br>/g;
    $column_data{notes}         = "<td>$ar->{notes}&nbsp;</td>";
    $column_data{shippingpoint} = "<td>$ar->{shippingpoint}&nbsp;</td>";
    $column_data{shipvia}       = "<td>$ar->{shipvia}&nbsp;</td>";
    $column_data{employee}      = "<td>$ar->{employee}&nbsp;</td>";

    $i++;
    $i %= 2;
    print "
        <tr class=listrow$i>
";

    map { print "\n$column_data{$_}" } @column_index;

    print qq|
        </tr>
|;

  }

  if ($form->{l_subtotal} eq 'Y') {
    &ar_subtotal;
  }

  # print totals
  print qq|
        <tr class=listtotal>
|;

  map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;

  $column_data{netamount} =
    "<th class=listtotal align=right>"
    . $form->format_amount(\%myconfig, $totalnetamount, 2, "&nbsp;") . "</th>";
  $column_data{tax} = "<th class=listtotal align=right>"
    . $form->format_amount(\%myconfig, $totalamount - $totalnetamount,
                           2, "&nbsp;")
    . "</th>";
  $column_data{amount} =
    "<th class=listtotal align=right>"
    . $form->format_amount(\%myconfig, $totalamount, 2, "&nbsp;") . "</th>";
  $column_data{paid} =
    "<th class=listtotal align=right>"
    . $form->format_amount(\%myconfig, $totalpaid, 2, "&nbsp;") . "</th>";
  $column_data{due} =
    "<th class=listtotal align=right>"
    . $form->format_amount(\%myconfig, $totaldue, 2, "&nbsp;") . "</th>";

  map { print "\n$column_data{$_}" } @column_index;

  print qq|
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<br>
<form method=post action=$form->{script}>

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input class=submit type=submit name=action value="|
    . $locale->text('AR Transaction') . qq|">
<input class=submit type=submit name=action value="|
    . $locale->text('Sales Invoice') . qq|">|;

  if ($form->{menubar}) {
    require "$form->{path}/menu.pl";
    &menubar;
  }

  print qq|
</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub ar_subtotal {
  $lxdebug->enter_sub();

  map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;

  $column_data{tax} = "<th class=listsubtotal align=right>"
    . $form->format_amount(\%myconfig, $subtotalamount - $subtotalnetamount,
                           2, "&nbsp;")
    . "</th>";
  $column_data{amount} =
    "<th class=listsubtotal align=right>"
    . $form->format_amount(\%myconfig, $subtotalamount, 2, "&nbsp;") . "</th>";
  $column_data{paid} =
    "<th class=listsubtotal align=right>"
    . $form->format_amount(\%myconfig, $subtotalpaid, 2, "&nbsp;") . "</th>";
  $column_data{due} =
    "<th class=listsubtotal align=right>"
    . $form->format_amount(\%myconfig, $subtotaldue, 2, "&nbsp;") . "</th>";

  $subtotalnetamount = 0;
  $subtotalamount    = 0;
  $subtotalpaid      = 0;
  $subtotaldue       = 0;

  $sameitem = $ar->{ $form->{sort} };

  print "<tr class=listsubtotal>";

  map { print "\n$column_data{$_}" } @column_index;

  print "
</tr>
";

  $lxdebug->leave_sub();
}
