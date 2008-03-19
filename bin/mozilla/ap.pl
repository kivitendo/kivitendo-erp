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

use POSIX qw(strftime);
use List::Util qw(sum);

use SL::AP;
use SL::FU;
use SL::IR;
use SL::IS;
use SL::PE;
use SL::ReportGenerator;

require "bin/mozilla/arap.pl";
require "bin/mozilla/common.pl";
require "bin/mozilla/drafts.pl";
require "bin/mozilla/reportgenerator.pl";

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

  $auth->assert('general_ledger');

  return $lxdebug->leave_sub() if (load_draft_maybe());

  $form->{title} = "Add";

  $form->{callback} = "ap.pl?action=add" unless $form->{callback};

  AP->get_transdate(\%myconfig, $form);
  $form->{initial_transdate} = $form->{transdate};
  &create_links;
  $form->{transdate} = $form->{initial_transdate};
  &display_form;

  $lxdebug->leave_sub();
}

sub edit {
  $lxdebug->enter_sub();

  $auth->assert('general_ledger');

  $form->{title} = "Edit";

  &create_links;
  &display_form;

  $lxdebug->leave_sub();
}

sub display_form {
  $lxdebug->enter_sub();

  $auth->assert('general_ledger');

  &form_header;
  &form_footer;

  $lxdebug->leave_sub();
}

sub create_links {
  $lxdebug->enter_sub();

  $auth->assert('general_ledger');

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

  AP->setup_form($form);

  $form->{locked} =
    ($form->datetonum($form->{transdate}, \%myconfig) <=
     $form->datetonum($form->{closedto}, \%myconfig));

  $lxdebug->leave_sub();
}

sub form_header {
  $lxdebug->enter_sub();

  $auth->assert('general_ledger');

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

  $form->{radier} = ($form->current_date(\%myconfig) eq $form->{gldate}) ? 1 : 0;
  $readonly       = ($form->{radier}) ? "" : $readonly;

  $form->{forex}        = $form->check_exchangerate( \%myconfig, $form->{currency}, $form->{transdate}, 'sell');
  $form->{exchangerate} = $form->{forex} if $form->{forex};


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

  my $follow_up_vc         =  $form->{vendor};
  $follow_up_vc            =~ s/--.*?//;
  my $follow_up_trans_info =  "$form->{invnumber} ($follow_up_vc)";

  $form->{javascript} .= qq|<script type="text/javascript" src="js/common.js"></script>|;
  $form->{javascript} .= qq|<script type="text/javascript" src="js/show_vc_details.js"></script>|;
  $form->{javascript} .= qq|<script type="text/javascript" src="js/follow_up.js"></script>|;

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

<input type="hidden" name="follow_up_trans_id_1" value="| . H($form->{id}) . qq|">
<input type="hidden" name="follow_up_trans_type_1" value="ap_transaction">
<input type="hidden" name="follow_up_trans_info_1" value="| . H($follow_up_trans_info) . qq|">
<input type="hidden" name="follow_up_rowcount" value="1">

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

  $form->{invtotal_unformatted} = $form->{invtotal};
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

  my @triggers  = ();
  my $totalpaid = 0;

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

  $auth->assert('general_ledger');

  my $follow_ups_block;
  if ($form->{id}) {
    my $follow_ups = FU->follow_ups('trans_id' => $form->{id});

    if (@{ $follow_ups} ) {
      my $num_due       = sum map { $_->{due} * 1 } @{ $follow_ups };
      $follow_ups_block = qq|<p>| . $locale->text("There are #1 unfinished follow-ups of which #2 are due.", scalar @{ $follow_ups }, $num_due) . qq|</p>|;
    }
  }

  print qq|

$follow_ups_block

<input name=callback type=hidden value="$form->{callback}">
<input name="gldate" type="hidden" value="| . Q($form->{gldate}) . qq|">
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

  print qq|<input class="submit" type="submit" name="action" id="update_button" value="| . $locale->text('Update') . qq|">|;

  if ($form->{id}) {
    if ($form->{radier}) {
      print qq| <input class=submit type=submit name=action value="| . $locale->text('Post') . qq|">
                <input class=submit type=submit name=action value="| . $locale->text('Delete') . qq|">
|;
    }

    # ToDO: - insert a global check for stornos, so that a storno is only possible a limited time after saving it
    print qq| <input class=submit type=submit name=action value="| . $locale->text('Storno') . qq|"> |
      if ($form->{id} && !IS->has_storno(\%myconfig, $form, 'ap') && !IS->is_storno(\%myconfig, $form, 'ap', $form->{id}));

    print qq| <input class=submit type=submit name=action value="| . $locale->text('Post Payment') . qq|">
              <input class=submit type=submit name=action value="| . $locale->text('Use As Template') . qq|">
              <input type="button" class="submit" onclick="follow_up_window()" value="| . $locale->text('Follow-Up') . qq|">
|;
  } elsif (($transdate > $closedto) && !$form->{id}) {
    print qq|
      <input class=submit type=submit name=action value="| . $locale->text('Post') . qq|"> | .
      NTI($cgi->submit('-name' => 'action', '-value' => $locale->text('Save draft'), '-class' => 'submit'));
  }
  # button for saving history
  if($form->{id} ne "") {
    print qq| <input type="button" class="submit" onclick="set_history_window($form->{id});" name="history" id="history" value="| . $locale->text('history') . qq|"> |;
  }
  # /button for saving history
  # mark_as_paid button 
  if($form->{id} ne "") {  
    print qq| <input type="submit" class="submit" name="action" value="| . $locale->text('mark as paid') . qq|"> |;
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

  $auth->assert('general_ledger');

  &mark_as_paid_common(\%myconfig,"ap");  

  $lxdebug->leave_sub();
}

sub update {
  $lxdebug->enter_sub();

  $auth->assert('general_ledger');

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

  $form->{forex}        = $form->check_exchangerate( \%myconfig, $form->{currency}, $form->{transdate}, 'sell');
  $form->{exchangerate} = $form->{forex} if $form->{forex};

  $form->{invdate} = $form->{transdate};
  $save_AP = $form->{AP};
  &check_name("vendor");
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

      $form->{"forex_$i"}        = $form->check_exchangerate( \%myconfig, $form->{currency}, $form->{"datepaid_$i"}, 'sell');
      $form->{"exchangerate_$i"} = $form->{"forex_$i"} if $form->{"forex_$i"};
    }
  }

  $form->{creditremaining} -=
    ($form->{invtotal} - $totalpaid + $form->{oldtotalpaid} -
     $form->{oldinvtotal});
  $form->{oldinvtotal}  = $form->{invtotal};
  $form->{oldtotalpaid} = $totalpaid;

  # notes
  $form->{notes} = $form->{intnotes};

  &display_form;

  $lxdebug->leave_sub();
}


sub post_payment {
  $lxdebug->enter_sub();

  $auth->assert('general_ledger');

  $form->{defaultcurrency} = $form->get_default_currency(\%myconfig);

  for $i (1 .. $form->{paidaccounts}) {
    if ($form->parse_amount(\%myconfig, $form->{"paid_$i"})) {
      $datepaid = $form->datetonum($form->{"datepaid_$i"}, \%myconfig);

      $form->isblank("datepaid_$i", $locale->text('Payment date missing!'));

      $form->error($locale->text('Cannot post payment for a closed period!'))
        if ($form->date_closed($form->{"datepaid_$i"}, \%myconfig));

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

  $auth->assert('general_ledger');

  # check if there is a vendor, invoice and due date
  $form->isblank("transdate", $locale->text("Invoice Date missing!"));
  $form->isblank("duedate",   $locale->text("Due Date missing!"));
  $form->isblank("vendor",    $locale->text('Vendor missing!'));

  $closedto  = $form->datetonum($form->{closedto},  \%myconfig);
  $transdate = $form->datetonum($form->{transdate}, \%myconfig);
  $form->error($locale->text('Cannot post transaction for a closed period!')) if ($form->date_closed($form->{"transdate"}, \%myconfig));

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
        if ($form->date_closed($form->{"datepaid_$i"}, \%myconfig));

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
  $form->{storno}       = 0;

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

  $auth->assert('general_ledger');

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

  $auth->assert('general_ledger');

  map { delete $form->{$_} } qw(printed emailed queued invnumber invdate deliverydate id datepaid_1 source_1 memo_1 paid_1 exchangerate_1 AP_paid_1 storno);
  $form->{paidaccounts} = 1;
  $form->{rowcount}--;
  $form->{invdate} = $form->current_date(\%myconfig);
  &update;

  $lxdebug->leave_sub();
}

sub delete {
  $lxdebug->enter_sub();

  $auth->assert('general_ledger');

  $form->{title} = $locale->text('Confirm!');

  $form->header;

  delete $form->{header};

  print qq|
<body>

<form method=post action=$form->{script}>
|;

  foreach $key (keys %$form) {
    next if (($key eq 'login') || ($key eq 'password') || ('' ne ref $form->{$key}));
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

  $auth->assert('general_ledger');

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

  $auth->assert('general_ledger | vendor_invoice_edit');

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

<input class=submit type=submit name=action value="|
    . $locale->text('Continue') . qq|">
</form>

</body>
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

sub ap_transactions {
  $lxdebug->enter_sub();

  $auth->assert('general_ledger | vendor_invoice_edit');

  ($form->{vendor}, $form->{vendor_id}) = split(/--/, $form->{vendor});

  $form->{sort} ||= 'transdate';

  AP->ap_transactions(\%myconfig, \%$form);

  $form->{title} = $locale->text('AP Transactions');

  my $report = SL::ReportGenerator->new(\%myconfig, $form);

  my @columns =
    qw(transdate id type invnumber ordnumber name netamount tax amount paid datepaid
       due duedate transaction_description notes employee globalprojectnumber);

  my @hidden_variables = map { "l_${_}" } @columns;
  push @hidden_variables, "l_subtotal", qw(open closed vendor invnumber ordnumber transaction_description notes project_id transdatefrom transdateto);

  my $href = build_std_url('action=ap_transactions', grep { $form->{$_} } @hidden_variables);

  my %column_defs = (
    'transdate'               => { 'text' => $locale->text('Date'), },
    'id'                      => { 'text' => $locale->text('ID'), },
    'type'                    => { 'text' => $locale->text('Type'), },
    'invnumber'               => { 'text' => $locale->text('Invoice'), },
    'ordnumber'               => { 'text' => $locale->text('Order'), },
    'name'                    => { 'text' => $locale->text('Vendor'), },
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

  $report->set_export_options('ap_transactions', @hidden_variables);

  $report->set_sort_indicator($form->{sort}, 1);

  my @options;
  if ($form->{vendor}) {
    push @options, $locale->text('Vendor') . " : $form->{vendor}";
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
                       'raw_bottom_info_text' => $form->parse_html_template('ap/ap_transactions_bottom'),
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

  foreach $ap (@{ $form->{AP} }) {
    $ap->{tax} = $ap->{amount} - $ap->{netamount};
    $ap->{due} = $ap->{amount} - $ap->{paid};

    map { $subtotals{$_} += $ap->{$_};
          $totals{$_}    += $ap->{$_} } @subtotal_columns;

    map { $ap->{$_} = $form->format_amount(\%myconfig, $ap->{$_}, 2) } qw(netamount tax amount paid due);

    $ap->{type} =
      $ap->{invoice} ? $locale->text("Invoice (one letter abbreviation)") :
                       $locale->text("AP Transaction (abbreviation)");

    my $row = { };

    foreach my $column (@columns) {
      $row->{$column} = {
        'data'  => $ap->{$column},
        'align' => $column_alignment{$column},
      };
    }

    $row->{invnumber}->{link} = build_std_url("script=" . ($ap->{invoice} ? 'ir.pl' : 'ap.pl'), 'action=edit')
      . "&id=" . E($ap->{id}) . "&callback=${callback}";

    my $row_set = [ $row ];

    if (($form->{l_subtotal} eq 'Y')
        && (($idx == (scalar @{ $form->{AP} } - 1))
            || ($ap->{ $form->{sort} } ne $form->{AP}->[$idx + 1]->{ $form->{sort} }))) {
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

  $auth->assert('general_ledger');

  if (IS->has_storno(\%myconfig, $form, 'ap')) {
    $form->{title} = $locale->text("Cancel Accounts Payables Transaction");
    $form->error($locale->text("Transaction has already been cancelled!"));
  }

  AP->storno($form, \%myconfig, $form->{id});

  # saving the history
  if(!exists $form->{addition} && $form->{id} ne "") {
    $form->{snumbers} = "ordnumber_$form->{ordnumber}";
    $form->{addition} = "STORNO";
    $form->save_history($form->dbconnect(\%myconfig));
  }
  # /saving the history 

  $form->redirect(sprintf $locale->text("Transaction %d cancelled."), $form->{storno_id}); 

  $lxdebug->leave_sub();
}
