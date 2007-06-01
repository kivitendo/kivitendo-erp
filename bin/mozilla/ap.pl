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
# Accounts Payables
#
#======================================================================

use SL::AP;
use SL::IR;
use SL::IS;
use SL::PE;

require "bin/mozilla/arap.pl";
require "bin/mozilla/common.pl";
require "bin/mozilla/drafts.pl";

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

  $form->{title} = "Add";

  $form->{callback} =
    "$form->{script}?action=add&login=$form->{login}&password=$form->{password}"
    unless $form->{callback};

  AP->get_transdate(\%myconfig, $form);
  $form->{initial_transdate} = $form->{transdate};
  &create_links;
  $form->{transdate} = $form->{initial_transdate};
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

  $form->create_links("AP", \%myconfig, "vendor");
  $taxincluded = $form->{taxincluded};
  $duedate     = $form->{duedate};

  IR->get_vendor(\%myconfig, \%$form);
  $form->{taxincluded} = $taxincluded;
  $form->{duedate}   = $duedate if $duedate;
  $form->{oldvendor} = "$form->{vendor}--$form->{vendor_id}";
  $form->{rowcount}  = 1;

  # build the popup menus
  $form->{taxincluded} = ($form->{id}) ? $form->{taxincluded} : "checked";

  # notes
  $form->{notes} = $form->{intnotes} unless $form->{notes};

  # currencies
  @curr = split(/:/, $form->{currencies});
  chomp $curr[0];
  $form->{defaultcurrency} = $curr[0];

  map { $form->{selectcurrency} .= "<option>$_\n" } @curr;

  # vendors
  if (@{ $form->{all_vendor} }) {
    $form->{vendor} = qq|$form->{vendor}--$form->{vendor_id}|;
    map { $form->{selectvendor} .= "<option>$_->{name}--$_->{id}\n" }
      (@{ $form->{all_vendor} });
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

  # forex
  $form->{forex} = $form->{exchangerate};
  $exchangerate = ($form->{exchangerate}) ? $form->{exchangerate} : 1;

  foreach $key (keys %{ $form->{AP_links} }) {
    foreach $ref (@{ $form->{AP_links}{$key} }) {
      if ($key eq "AP_paid") {
        $form->{"select$key"} .=
          "<option value=\"$ref->{accno}\">$ref->{accno}--$ref->{description}</option>\n";
      } else {
        $form->{"select$key"} .=
          "<option value=\"$ref->{accno}--$ref->{tax_id}\">$ref->{accno}--$ref->{description}</option>\n";
      }
    }

    $form->{$key} = $form->{"select$key"};

    # if there is a value we have an old entry
    my $j = 0;
    my $k = 0;

    for $i (1 .. scalar @{ $form->{acc_trans}{$key} }) {

      if ($key eq "AP_paid") {
        $j++;
        $form->{"AP_paid_$j"} =
          "$form->{acc_trans}{$key}->[$i-1]->{accno}--$form->{acc_trans}{$key}->[$i-1]->{description}";
        $form->{"paid_$j"}     = $form->{acc_trans}{$key}->[$i - 1]->{amount};
        $form->{"datepaid_$j"} =
          $form->{acc_trans}{$key}->[$i - 1]->{transdate};
        $form->{"source_$j"} = $form->{acc_trans}{$key}->[$i - 1]->{source};
        $form->{"memo_$j"}   = $form->{acc_trans}{$key}->[$i - 1]->{memo};

        $form->{"forex_$j"} = $form->{"exchangerate_$i"} =
          $form->{acc_trans}{$key}->[$i - 1]->{exchangerate};
        $form->{"AP_paid_$j"} = "$form->{acc_trans}{$key}->[$i-1]->{accno}";
        $form->{"paid_project_id_$j"} = $form->{acc_trans}{$key}->[$i - 1]->{project_id};
        $form->{paidaccounts}++;
      } else {

        $akey = $key;
        $akey =~ s/AP_//;

        if (($key eq "AP_tax") || ($key eq "AR_tax")) {
          $form->{"${key}_$form->{acc_trans}{$key}->[$i-1]->{accno}"} =
            "$form->{acc_trans}{$key}->[$i-1]->{accno}--$form->{acc_trans}{$key}->[$i-1]->{description}";
          $form->{"${akey}_$form->{acc_trans}{$key}->[$i-1]->{accno}"} =
            $form->round_amount(
                  $form->{acc_trans}{$key}->[$i - 1]->{amount} / $exchangerate,
                  2);

          if ($form->{"$form->{acc_trans}{$key}->[$i-1]->{accno}_rate"} > 0) {
            $totaltax +=
              $form->{"${akey}_$form->{acc_trans}{$key}->[$i-1]->{accno}"};
          } else {
            $totalwithholding +=
              $form->{"${akey}_$form->{acc_trans}{$key}->[$i-1]->{accno}"};
            $withholdingrate +=
              $form->{"$form->{acc_trans}{$key}->[$i-1]->{accno}_rate"};
          }
          $index = $form->{acc_trans}{$key}->[$i - 1]->{index};
          $form->{"tax_$index"} =
            $form->{acc_trans}{$key}->[$i - 1]->{amount} * -1;
          $totaltax += $form->{"tax_$index"};

        } else {
          $k++;
          $form->{"${akey}_$k"} =
            $form->round_amount(
                  $form->{acc_trans}{$key}->[$i - 1]->{amount} / $exchangerate,
                  2);
          if ($akey eq 'amount') {
            $form->{rowcount}++;
            $form->{"${akey}_$i"} *= -1;
            $totalamount += $form->{"${akey}_$i"};
            $form->{taxrate} = $form->{acc_trans}{$key}->[$i - 1]->{rate};
            $form->{"oldprojectnumber_$k"} = $form->{"projectnumber_$k"} =
              "$form->{acc_trans}{$key}->[$i-1]->{projectnumber}";
            $form->{"project_id_$k"} =
              "$form->{acc_trans}{$key}->[$i-1]->{project_id}";
          }
          $form->{"${key}_$k"} =
            "$form->{acc_trans}{$key}->[$i-1]->{accno}--$form->{acc_trans}{$key}->[$i-1]->{description}";
          my $q_description = quotemeta($form->{acc_trans}{$key}->[$i-1]->{description});
          $form->{"select${key}"} =~
            /<option value=\"($form->{acc_trans}{$key}->[$i-1]->{accno}--[^\"]*)\">$form->{acc_trans}{$key}->[$i-1]->{accno}--${q_description}<\/option>\n/;
          $form->{"${key}_$k"} = $1;

          if ($akey eq "AP") {
            $form->{APselected} = $form->{acc_trans}{$key}->[$i-1]->{accno};

          } elsif ($akey eq 'amount') {
            $form->{"${key}_$k"} = $form->{acc_trans}{$key}->[$i-1]->{accno} .
              "--" . $form->{acc_trans}{$key}->[$i-1]->{id};
            $form->{"taxchart_$k"} = $form->{acc_trans}{$key}->[$i-1]->{id} .
              "--" . $form->{acc_trans}{$key}->[$i-1]->{rate};
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

  $form->{invtotal} = $totalamount + $totaltax;

  $form->{locked} =
    ($form->datetonum($form->{transdate}, \%myconfig) <=
     $form->datetonum($form->{closedto}, \%myconfig));

  $lxdebug->leave_sub();
}

sub form_header {
  $lxdebug->enter_sub();

  $title = $form->{title};
  $form->{title} = $locale->text("$title Accounts Payables Transaction");

  $form->{taxincluded} = ($form->{taxincluded}) ? "checked" : "";

  # type=submit $locale->text('Add Accounts Payables Transaction')
  # type=submit $locale->text('Edit Accounts Payables Transaction')

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
  # show history button
  $form->{javascript} .= qq|<script type="text/javascript" src="js/show_history.js"></script>|;
  #/show hhistory button

  # set option selected
  foreach $item (qw(vendor currency department)) {
    $form->{"select$item"} =~ s/ selected//;
    $form->{"select$item"} =~
      s/option>\Q$form->{$item}\E/option selected>$form->{$item}/;
  }
  $readonly = ($form->{id}) ? "readonly" : "";

  $form->{radier} =
    ($form->current_date(\%myconfig) eq $form->{gldate}) ? 1 : 0;
  $readonly                 = ($form->{radier}) ? "" : $readonly;

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
            <tr>
	      <th align=right>| . $locale->text('Exchangerate') . qq|</th>
              <td><input type=hidden name=exchangerate value=$form->{exchangerate}>$form->{exchangerate}</td>
           </tr>
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
              <th align=left nowrap>|
    . $locale->text('Tax Included') . qq|</th>
            </tr>
|;

  if (($rows = $form->numtextrows($form->{notes}, 50)) < 2) {
    $rows = 2;
  }
  $notes =
    qq|<textarea name=notes rows=$rows cols=50 wrap=soft $readonly>$form->{notes}</textarea>|;

  $department = qq|
              <tr>
	        <th align="right" nowrap>| . $locale->text('Department') . qq|</th>
		<td colspan=3><select name=department>$form->{selectdepartment}</select>
		<input type=hidden name=selectdepartment value="$form->{selectdepartment}">
		</td>
	      </tr>
| if $form->{selectdepartment};

  $n = ($form->{creditremaining} =~ /-/) ? "0" : "1";

  $vendor =
    ($form->{selectvendor})
    ? qq|<select name="vendor"
onchange="document.getElementById('update_button').click();">$form->{
selectvendor } </select>|
    : qq|<input name=vendor value="$form->{vendor}" size=35>|;

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

  my (%AP_amount_labels, @AP_amount_values);
  my (%AP_labels, @AP_values);
  my (%AP_paid_labels, @AP_paid_values);
  my %charts;
  my $taxchart_init;

  foreach my $item (@{ $form->{ALL_CHARTS} }) {
    if (grep({ $_ eq "AP_amount" } @{ $item->{link_split} })) {
      $taxchart_init = $item->{tax_id} if ($taxchart_init eq "");
      my $key = "$item->{accno}--$item->{tax_id}";
      push(@AP_amount_values, $key);
      $AP_amount_labels{$key} =
        "$item->{accno}--$item->{description}";

    } elsif (grep({ $_ eq "AP" } @{ $item->{link_split} })) {
      push(@AP_values, $item->{accno});
      $AP_labels{$item->{accno}} = "$item->{accno}--$item->{description}";

    } elsif (grep({ $_ eq "AP_paid" } @{ $item->{link_split} })) {
      push(@AP_paid_values, $item->{accno});
      $AP_paid_labels{$item->{accno}} =
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

  # use JavaScript Calendar or not
  $form->{jsscript} = 1;
  $jsscript = "";
  if ($form->{jsscript}) {

    # with JavaScript Calendar
    $button1 = qq|
       <td><input name=transdate id=transdate size=11 title="$myconfig{dateformat}" value="$form->{transdate}" onBlur=\"check_right_date_format(this)\"> $readonly</td>
       <td><input type=button name=transdate id="trigger1" value=|
      . $locale->text('button') . qq|></td>
       |;
    $button2 = qq|
       <td><input name=duedate id=duedate size=11 title="$myconfig{dateformat}" value="$form->{duedate}" onBlur=\"check_right_date_format(this)\"> $readonly</td>
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
      qq|<td><input name=transdate id=transdate size=11 title="$myconfig{dateformat}" value="$form->{transdate}" onBlur=\"check_right_date_format(this)\"> $readonly</td>|;
    $button2 =
      qq|<td><input name=duedate id=duedate size=11 title="$myconfig{dateformat}" value="$form->{duedate}" onBlur=\"check_right_date_format(this)\"> $readonly</td>|;
  }
  $form->{javascript} .= qq|<script type="text/javascript" src="js/common.js"></script>|;
  $form->{javascript} .= qq|<script type="text/javascript" src="js/show_vc_details.js"></script>|;

  $form->header;
  $onload = qq|;setupDateFormat('|. $myconfig{dateformat} .qq|', '|. $locale->text("Falsches Datumsformat!") .qq|')|;
  $onload .= qq|;setupPoints('|. $myconfig{numberformat} .qq|', '|. $locale->text("wrongformat") .qq|')|;
  print qq|
<body onLoad="$onload">

<form method=post action=$form->{script}>

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
		<th align=right nowrap>| . $locale->text('Vendor') . qq|</th>
		<td colspan=3>$vendor <input type="button" value="?" onclick="show_vc_details('vendor')"></td>
		<input type=hidden name=selectvendor value="$form->{selectvendor}">
		<input type=hidden name=oldvendor value="$form->{oldvendor}">
		<input type=hidden name=vendor_id value="$form->{vendor_id}">
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
	      <tr>
		<th align=right nowrap>| . $locale->text('Currency') . qq|</th>
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
	      <tr>
		<th align=right nowrap>| . $locale->text('Invoice Number') . qq|</th>
		<td><input name=invnumber size=11 value="$form->{invnumber}" $readonly></td>
	      </tr>
	      <tr>
		<th align=right nowrap>| . $locale->text('Order Number') . qq|</th>
		<td><input name=ordnumber size=11 value="$form->{ordnumber}" $readonly></td>
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
    my ($accno_row) = split(/--/, $form->{"AP_amount_$i"});
    my $item = $charts{$accno_row};
    $selected_accno_full = "$item->{accno}--$item->{tax_id}";

    my $selected_taxchart = $form->{"taxchart_$i"};
    my ($selected_accno, $selected_tax_id) = split(/--/, $selected_accno_full);
    my ($previous_accno, $previous_tax_id) = split(/--/, $form->{"previous_AP_amount_$i"});

    if ($previous_accno &&
        ($previous_accno eq $selected_accno) &&
        ($previous_tax_id ne $selected_tax_id)) {
      my $item = $taxcharts{$selected_tax_id};
      $selected_taxchart = "$item->{id}--$item->{rate}";
    }

    $selected_taxchart = $taxchart_init unless ($form->{"taxchart_$i"});

    $selectAP_amount =
      NTI($cgi->popup_menu('-name' => "AP_amount_$i",
                           '-id' => "AP_amount_$i",
                           '-style' => 'width:400px',
                           '-onChange' => "setTaxkey(this, $i)",
                           '-values' => \@AP_amount_values,
                           '-labels' => \%AP_amount_labels,
                           '-default' => $selected_accno_full))
      . $cgi->hidden('-name' => "previous_AP_amount_$i",
                     '-default' => $selected_accno_full);

    $tax = qq|<td>| .
      NTI($cgi->popup_menu('-name' => "taxchart_$i",
                           '-id' => "taxchart_$i",
                           '-style' => 'width:200px',
                           '-values' => \@taxchart_values,
                           '-labels' => \%taxchart_labels,
                           '-default' => $selected_taxchart))
      . qq|</td>|;

    my $korrektur = $form->{"korrektur_$i"} ? 'checked' : '';

    my $projectnumber =
      NTI($cgi->popup_menu('-name' => "project_id_$i",
                           '-values' => \@project_values,
                           '-labels' => \%project_labels,
                           '-default' => $form->{"project_id_$i"} ));

    print qq|
	<tr>
          <td>$selectAP_amount</td>
          <td><input name="amount_$i" size=10 value=$form->{"amount_$i"}></td>
          <td><input name="tax_$i" size=10 value=$form->{"tax_$i"}></td>
          <td><input type="checkbox" name="korrektur_$i" value="1" "$korrektur"></td>
          $tax
          <td>$projectnumber</td>
	</tr>
|;
    $amount  = "";
    $project = "";
  }

  $taxlabel =
    ($form->{taxincluded})
    ? $locale->text('Tax Included')
    : $locale->text('Tax');

  $form->{invtotal} = $form->format_amount(\%myconfig, $form->{invtotal}, 2);

  $APselected =
    NTI($cgi->popup_menu('-name' => "APselected", '-id' => "APselected",
                         '-style' => 'width:400px',
                         '-values' => \@AP_values, '-labels' => \%AP_labels,
                         '-default' => $form->{APselected}));
  print qq|
        <tr>
          <td colspan=6>
            <hr noshade>
          </td>
        </tr>
        <tr>
	  <td>${APselected}</td>
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
	  <th class=listheading colspan=7>| . $locale->text('Payments') . qq|</th>
	</tr>
|;

  if ($form->{currency} eq $form->{defaultcurrency}) {
    @column_index = qw(datepaid source memo paid AP_paid paid_project_id);
  } else {
    @column_index = qw(datepaid source memo paid exchangerate AP_paid paid_project_id);
  }

  $column_data{datepaid}     = "<th>" . $locale->text('Date') . "</th>";
  $column_data{paid}         = "<th>" . $locale->text('Amount') . "</th>";
  $column_data{exchangerate} = "<th>" . $locale->text('Exch') . "</th>";
  $column_data{AP_paid}      = "<th>" . $locale->text('Account') . "</th>";
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

  my @triggers = ();
  $form->{paidaccounts}++ if ($form->{"paid_$form->{paidaccounts}"});
  for $i (1 .. $form->{paidaccounts}) {
    print "
        <tr>
";

    $selectAP_paid =
      NTI($cgi->popup_menu('-name' => "AP_paid_$i",
                           '-id' => "AP_paid_$i",
                           '-values' => \@AP_paid_values,
                           '-labels' => \%AP_paid_labels,
                           '-default' => $form->{"AP_paid_$i"}));

    # format amounts
    if ($form->{"paid_$i"}) {
      $form->{"paid_$i"} =
      $form->format_amount(\%myconfig, $form->{"paid_$i"}, 2);
    }
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

    $column_data{"paid_$i"} =
      qq|<td align=center><input name="paid_$i" size=11 value="$form->{"paid_$i"}" onBlur=\"check_right_number_format(this)\"></td>|;
    $column_data{"AP_paid_$i"} =
      qq|<td align=center>${selectAP_paid}</td>|;
    $column_data{"exchangerate_$i"} = qq|<td align=center>$exchangerate</td>|;
    $column_data{"datepaid_$i"}     =
      qq|<td align=center><input name="datepaid_$i" id="datepaid_$i" size=11 title="($myconfig{'dateformat'})" value="$form->{"datepaid_$i"}" onBlur=\"check_right_date_format(this)\">
         <input type="button" name="datepaid_$i" id="trigger_datepaid_$i" value="?"></td>|;
    $column_data{"source_$i"} =
      qq|<td align=center><input name="source_$i" size=11 value="$form->{"source_$i"}"></td>|;
    $column_data{"memo_$i"} =
      qq|<td align=center><input name="memo_$i" size=11 value="$form->{"memo_$i"}"></td>|;
    $column_data{"paid_project_id_$i"} =
      qq|<td>|
      . NTI($cgi->popup_menu('-name' => "paid_project_id_$i",
                             '-values' => \@project_values,
                             '-labels' => \%project_labels,
                             '-default' => $form->{"paid_project_id_$i"} ))
      . qq|</td>|;

    map { print qq|$column_data{"${_}_$i"}\n| } @column_index;

    print "
        </tr>
";
    push(@triggers, "datepaid_$i", "BL", "trigger_datepaid_$i");
  }
  print $form->write_trigger(\%myconfig, scalar(@triggers) / 3, @triggers) .
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

<input name=callback type=hidden value="$form->{callback}">
<input name="gldate" type="hidden" value="| . Q($form->{gldate}) . qq|">

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

  # ToDO: - insert a global check for stornos, so that a storno is only possible a limited time after saving it
  print qq|<input class=submit type=submit name=action value="| . $locale->text('Storno') . qq|">|
    if ($form->{id} && !IS->has_storno(\%myconfig, $form, 'ap') && !IS->is_storno(\%myconfig, $form, 'ap') && !$form->{paid_1});

  print qq|<input class="submit" type="submit" name="action" id="update_button" value="| . $locale->text('Update') . qq|">|;

  if ($form->{id}) {
    if ($form->{radier}) {
      print qq| <input class=submit type=submit name=action value="| . $locale->text('Post') . qq|">
                <input class=submit type=submit name=action value="| . $locale->text('Delete') . qq|">
|;
    }

    print qq| <input class=submit type=submit name=action value="| . $locale->text('Use As Template') . qq|">
              <input class=submit type=submit name=action value="| . $locale->text('Post Payment') . qq|">
|;
  } elsif (($transdate > $closedto) && !$form->{id}) {
    print qq|
      <input class=submit type=submit name=action value="| . $locale->text('Post') . qq|"> | .
      NTI($cgi->submit('-name' => 'action', '-value' => $locale->text('Save draft'), '-class' => 'submit'));
  }
  # button for saving history
  if($form->{id} ne "") {
    print qq| <input type="button" class="submit" onclick="set_history_window($form->{id});" name="history" id="history" value="| . $locale->text('history') . qq|">|;
  }
  # /button for saving history
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

  $form->{invtotal} = 0;

  map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) }
    qw(exchangerate creditlimit creditremaining);

  @flds  = qw(amount AP_amount projectnumber oldprojectnumber project_id);
  $count = 0;
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

  map { $form->{invtotal} += $form->{"amount_$_"} } (1 .. $form->{rowcount});

  $form->{exchangerate} = $exchangerate
    if (
        $form->{forex} = (
                    $exchangerate =
                      $form->check_exchangerate(
                      \%myconfig, $form->{currency}, $form->{transdate}, 'sell'
                      )));

  $form->{invdate} = $form->{transdate};
  $save_AP = $form->{AP};
  &check_name(vendor);
  $form->{AP} = $save_AP;

  $form->{rowcount} = $count + 1;

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
                  \%myconfig, $form->{currency}, $form->{"datepaid_$i"}, 'sell'
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

  ($form->{AP})      = split /--/, $form->{AP};
  ($form->{AP_paid}) = split /--/, $form->{AP_paid};
  $form->redirect($locale->text('Payment posted!'))
      if (AP->post_payment(\%myconfig, \%$form));
    $form->error($locale->text('Cannot post payment!'));


  $lxdebug->leave_sub();
}


sub post {
  $lxdebug->enter_sub();

  # check if there is a vendor, invoice and due date
  $form->isblank("transdate", $locale->text("Invoice Date missing!"));
  $form->isblank("duedate",   $locale->text("Due Date missing!"));
  $form->isblank("vendor",    $locale->text('Vendor missing!'));

  $closedto  = $form->datetonum($form->{closedto},  \%myconfig);
  $transdate = $form->datetonum($form->{transdate}, \%myconfig);
  $form->error($locale->text('Cannot post transaction for a closed period!')) if ($transdate <= $closedto);

  my $zero_amount_posting = 1;
  for $i (1 .. $form->{rowcount}) {
    if ($form->parse_amount(\%myconfig, $form->{"amount_$i"})) {
      $zero_amount_posting = 0;
      last;
    }
  }

  $form->error($locale->text('Zero amount posting!')) if $zero_amount_posting;

  $form->isblank("exchangerate", $locale->text('Exchangerate missing!'))
    if ($form->{currency} ne $form->{defaultcurrency});
  delete($form->{AP});

  for $i (1 .. $form->{paidaccounts}) {
    if ($form->parse_amount(\%myconfig, $form->{"paid_$i"})) {
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

  # if old vendor ne vendor redo form
  ($vendor) = split /--/, $form->{vendor};
  if ($form->{oldvendor} ne "$vendor--$form->{vendor_id}") {
    &update;
    exit;
  }
  ($debitaccno,    $debittaxkey)    = split /--/, $form->{AP_amountselected};
  ($taxkey,        $NULL)           = split /--/, $form->{taxchartselected};
  ($payablesaccno, $payablestaxkey) = split /--/, $form->{APselected};
  $form->{AP}{amount_1} = $debitaccno;
  $form->{AP}{payables} = $payablesaccno;
  $form->{taxkey}       = $taxkey;

  $form->{id} = 0 if $form->{postasnew};

  if (AP->post_transaction(\%myconfig, \%$form)) {
    # saving the history
    if(!exists $form->{addition} && $form->{id} ne "") {
      $form->{snumbers} = qq|invnumber_| . $form->{invnumber};
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
  if (AP->delete_transaction(\%myconfig, \%$form, $spool)) {
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

  # setup vendor selection
  $form->all_vc(\%myconfig, "vendor", "AP");

  if (@{ $form->{all_vendor} }) {
    map { $vendor .= "<option>$_->{name}--$_->{id}\n" }
      @{ $form->{all_vendor} };
    $vendor = qq|<select name=vendor><option>\n$vendor\n</select>|;
  } else {
    $vendor = qq|<input name=vendor size=35>|;
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

  $form->{title} = $locale->text('AP Transactions');

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
  $form->{javascript} .= qq|<script type="text/javascript" src="js/common.js"></script>|;
  $form->header;
  $onload = qq|;setupDateFormat('|. $myconfig{dateformat} .qq|', '|. $locale->text("Falsches Datumsformat!") .qq|')|;
  $onload .= qq|;setupPoints('|. $myconfig{numberformat} .qq|', '|. $locale->text("wrongformat") .qq|')|;
  print qq|
<body onLoad="$onload">

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
	<tr>
	  <th align=right>| . $locale->text('Vendor') . qq|</th>
	  <td colspan=3>$vendor</td>
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
	      </tr>
	      <tr>
		<td align=right><input name="l_name" class=checkbox type=checkbox value=Y checked></td>
		<td nowrap>| . $locale->text('Vendor') . qq|</td>
		<td align=right><input name="l_transdate" class=checkbox type=checkbox value=Y checked></td>
		<td nowrap>| . $locale->text('Invoice Date') . qq|</td>
		<td align=right><input name="l_netamount" class=checkbox type=checkbox value=Y></td>
		<td nowrap>| . $locale->text('Amount') . qq|</td>
	      </tr>
	      <tr>
		<td align=right><input name="l_tax" class=checkbox type=checkbox value=Y></td>
		<td nowrap>| . $locale->text('Tax') . qq|</td>
		<td align=right><input name="l_amount" class=checkbox type=checkbox value=Y checked></td>
		<td nowrap>| . $locale->text('Total') . qq|</td>
		<td align=right><input name="l_datepaid" class=checkbox type=checkbox value=Y></td>
		<td nowrap>| . $locale->text('Date Paid') . qq|</td>
	      </tr>
	      <tr>
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
		<td nowrap>| . $locale->text('Employee') . qq|</td>
	      </tr>
	      <tr>
		<td align=right><input name="l_subtotal" class=checkbox type=checkbox value=Y></td>
		<td nowrap>| . $locale->text('Subtotal') . qq|</td>
		<td align=right><input name="l_globalprojectnumber" class=checkbox type=checkbox value=Y></td>
		<td nowrap>| . $locale->text('Project Number') . qq|</td>
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

$jsscript

<br>
<input type=hidden name=nextsub value=$form->{nextsub}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input class=submit type=submit name=action value="|
    . $locale->text('Continue') . qq|">
</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub ap_transactions {
  $lxdebug->enter_sub();

  $form->{vendor} = $form->unescape($form->{vendor});
  ($form->{vendor}, $form->{vendor_id}) = split(/--/, $form->{vendor});

  AP->ap_transactions(\%myconfig, \%$form);

  $callback =
    "$form->{script}?action=ap_transactions&login=$form->{login}&password=$form->{password}";
  $href = $callback;

  if ($form->{vendor}) {
    $callback .= "&vendor=" . $form->escape($form->{vendor}, 1);
    $href .= "&vendor=" . $form->escape($form->{vendor});
    $option .= $locale->text('Vendor') . " : $form->{vendor}";
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
        $locale->text('From') . " "
      . $locale->date(\%myconfig, $form->{transdatefrom}, 1);
  }
  if ($form->{transdateto}) {
    $callback .= "&transdateto=$form->{transdateto}";
    $href     .= "&transdateto=$form->{transdateto}";
    $option   .= "\n<br>" if ($option);
    $option   .=
        $locale->text('Bis') . " "
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
  if ($form->{globalproject_id}) {
    $callback .= "&globalproject_id=" . E($form->{globalproject_id});
    $href     .= "&globalproject_id=" . E($form->{globalproject_id});
  }

  @columns =
    qw(transdate id type invnumber ordnumber name netamount tax amount paid datepaid
       due duedate notes employee globalprojectnumber);

  $form->{"l_type"} = "Y";

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
      qq|<th><a class=listheading href=$href&sort=id>|
    . $locale->text('ID')
    . qq|</a></th>|;
  $column_header{transdate} =
      qq|<th><a class=listheading href=$href&sort=transdate>|
    . $locale->text('Date')
    . qq|</a></th>|;
  $column_header{type} =
      "<th class=\"listheading\">" . $locale->text('Type') . "</th>";
  $column_header{duedate} =
      qq|<th><a class=listheading href=$href&sort=duedate>|
    . $locale->text('Due Date')
    . qq|</a></th>|;
  $column_header{due} =
    qq|<th class=listheading>| . $locale->text('Amount Due') . qq|</th>|;
  $column_header{invnumber} =
      qq|<th><a class=listheading href=$href&sort=invnumber>|
    . $locale->text('Invoice')
    . qq|</a></th>|;
  $column_header{ordnumber} =
      qq|<th><a class=listheading href=$href&sort=ordnumber>|
    . $locale->text('Order')
    . qq|</a></th>|;
  $column_header{name} =
      qq|<th><a class=listheading href=$href&sort=name>|
    . $locale->text('Vendor')
    . qq|</a></th>|;
  $column_header{netamount} =
    qq|<th class=listheading>| . $locale->text('Amount') . qq|</th>|;
  $column_header{tax} =
    qq|<th class=listheading>| . $locale->text('Tax') . qq|</th>|;
  $column_header{amount} =
    qq|<th class=listheading>| . $locale->text('Total') . qq|</th>|;
  $column_header{paid} =
    qq|<th class=listheading>| . $locale->text('Paid') . qq|</th>|;
  $column_header{datepaid} =
      qq|<th><a class=listheading href=$href&sort=datepaid>|
    . $locale->text('Date Paid')
    . qq|</a></th>|;
  $column_header{notes} =
    qq|<th class=listheading>| . $locale->text('Notes') . qq|</th>|;
  $column_header{employee} =
    "<th><a class=listheading href=$href&sort=employee>"
    . $locale->text('Employee') . "</th>";
  $column_header{globalprojectnumber} =
    qq|<th class="listheading">| . $locale->text('Project Number') . qq|</th>|;

  $form->{title} = $locale->text('AP Transactions');

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

  # add sort and escape callback
  $form->{callback} = "$callback&sort=$form->{sort}";
  $callback = $form->escape($form->{callback});

  if (@{ $form->{AP} }) {
    $sameitem = $form->{AP}->[0]->{ $form->{sort} };
  }

  # sums and tax on reports by Antonio Gallardo
  #
  foreach $ap (@{ $form->{AP} }) {

    if ($form->{l_subtotal} eq 'Y') {
      if ($sameitem ne $ap->{ $form->{sort} }) {
        &ap_subtotal;
        $sameitem = $ap->{ $form->{sort} };
      }
    }

    $column_data{netamount} =
        "<td align=right>"
      . $form->format_amount(\%myconfig, $ap->{netamount}, 2, "&nbsp;")
      . "</td>";
    $column_data{tax} = "<td align=right>"
      . $form->format_amount(\%myconfig, $ap->{amount} - $ap->{netamount},
                             2, "&nbsp;")
      . "</td>";
    $column_data{amount} =
      "<td align=right>"
      . $form->format_amount(\%myconfig, $ap->{amount}, 2, "&nbsp;") . "</td>";
    $column_data{paid} =
      "<td align=right>"
      . $form->format_amount(\%myconfig, $ap->{paid}, 2, "&nbsp;") . "</td>";
    $column_data{due} = "<td align=right>"
      . $form->format_amount(\%myconfig, $ap->{amount} - $ap->{paid},
                             2, "&nbsp;")
      . "</td>";

    $totalnetamount += $ap->{netamount};
    $totalamount    += $ap->{amount};
    $totalpaid      += $ap->{paid};
    $totaldue       += ($ap->{amount} - $ap->{paid});

    $subtotalnetamount += $ap->{netamount};
    $subtotalamount    += $ap->{amount};
    $subtotalpaid      += $ap->{paid};
    $subtotaldue       += ($ap->{amount} - $ap->{paid});

    $column_data{transdate} = "<td>$ap->{transdate}&nbsp;</td>";
    $column_data{type} = "<td>" .
      ($ap->{invoice}    ? $locale->text("Invoice (one letter abbreviation)") :
                           $locale->text("AP Transaction (abbreviation)"))
        . "</td>";
    $column_data{duedate}   = "<td>$ap->{duedate}&nbsp;</td>";
    $column_data{datepaid}  = "<td>$ap->{datepaid}&nbsp;</td>";

    $module = ($ap->{invoice}) ? "ir.pl" : $form->{script};

    $column_data{invnumber} =
      qq|<td><a href="$module?action=edit&id=$ap->{id}&login=$form->{login}&password=$form->{password}&callback=$callback">$ap->{invnumber}</a></td>|;
    $column_data{id}        = "<td>$ap->{id}</td>";
    $column_data{ordnumber} = "<td>$ap->{ordnumber}&nbsp;</td>";
    $column_data{name}      = "<td>$ap->{name}</td>";
    $ap->{notes} =~ s/\r\n/<br>/g;
    $column_data{notes}    = "<td>$ap->{notes}&nbsp;</td>";
    $column_data{employee} = "<td>$ap->{employee}&nbsp;</td>";
    $column_data{globalprojectnumber}  =
      "<td>" . H($ap->{globalprojectnumber}) . "</td>";

    $i++;
    $i %= 2;
    print "
        <tr class=listrow$i >
";

    map { print "\n$column_data{$_}" } @column_index;

    print qq|
	</tr>
|;

  }

  if ($form->{l_subtotal} eq 'Y') {
    &ap_subtotal;
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

<br>
<form method=post action=$form->{script}>

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input class=submit type=submit name=action value="|
    . $locale->text('AP Transaction') . qq|">

<input class=submit type=submit name=action value="|
    . $locale->text('Vendor Invoice') . qq|">

  </form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub ap_subtotal {
  $lxdebug->enter_sub();

  map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;

  $column_data{netamount} =
      "<th class=listsubtotal align=right>"
    . $form->format_amount(\%myconfig, $subtotalnetamount, 2, "&nbsp;")
    . "</th>";
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

  print "<tr class=listsubtotal>";

  map { print "\n$column_data{$_}" } @column_index;

  print qq|
  </tr>
|;

  $lxdebug->leave_sub();
}

sub storno {
  $lxdebug->enter_sub();

  if (IS->has_storno(\%myconfig, $form, 'ap')) {
    $form->{title} = $locale->text("Cancel Accounts Payables Transaction");
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
