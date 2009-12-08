#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger, Accounting
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
# Inventory received module
#
#======================================================================

use SL::FU;
use SL::IR;
use SL::IS;
use SL::PE;
use List::Util qw(max sum);

require "bin/mozilla/io.pl";
require "bin/mozilla/invoice_io.pl";
require "bin/mozilla/arap.pl";
require "bin/mozilla/common.pl";
require "bin/mozilla/drafts.pl";

use strict;

1;

# end of main

sub add {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  $main::auth->assert('vendor_invoice_edit');

  return $main::lxdebug->leave_sub() if (load_draft_maybe());

  $form->{title} = $locale->text('Add Vendor Invoice');

  &invoice_links;
  &prepare_invoice;
  &display_form;

  $main::lxdebug->leave_sub();
}

sub edit {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  $main::auth->assert('vendor_invoice_edit');

  # show history button
  $form->{javascript} = qq|<script type=text/javascript src=js/show_history.js></script>|;
  #/show hhistory button

  $form->{title} = $locale->text('Edit Vendor Invoice');

  &invoice_links;
  &prepare_invoice;
  &display_form;

  $main::lxdebug->leave_sub();
}

sub invoice_links {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $main::auth->assert('vendor_invoice_edit');

  # create links
  $form->{webdav}   = $main::webdav;
  $form->{jsscript} = 1;

  $form->create_links("AP", \%myconfig, "vendor");

  #quote all_vendor Bug 133
  foreach my $ref (@{ $form->{all_vendor} }) {
    $ref->{name} = $form->quote($ref->{name});
  }

  if ($form->{all_vendor}) {
    unless ($form->{vendor_id}) {
      $form->{vendor_id} = $form->{all_vendor}->[0]->{id};
    }
  }

  my ($payment_id, $language_id, $taxzone_id);
  if ($form->{payment_id}) {
    $payment_id = $form->{payment_id};
  }
  if ($form->{language_id}) {
    $language_id = $form->{language_id};
  }
  if ($form->{taxzone_id}) {
    $taxzone_id = $form->{taxzone_id};
  }

  my $cp_id = $form->{cp_id};
  IR->get_vendor(\%myconfig, \%$form);
  IR->retrieve_invoice(\%myconfig, \%$form);
  $form->{cp_id} = $cp_id;

  if ($payment_id) {
    $form->{payment_id} = $payment_id;
  }
  if ($language_id) {
    $form->{language_id} = $language_id;
  }
  if ($taxzone_id) {
    $form->{taxzone_id} = $taxzone_id;
  }

  my @curr = split(/:/, $form->{currencies}); #seems to be missing
  map { $form->{selectcurrency} .= "<option>$_\n" } @curr;

  $form->{oldvendor} = "$form->{vendor}--$form->{vendor_id}";

  # build vendor/customer drop down comatibility... don't ask
  if (@{ $form->{"all_vendor"} || [] }) {
    $form->{"selectvendor"} = 1;
    $form->{vendor}         = qq|$form->{vendor}--$form->{vendor_id}|;
  }

  # departments
  if ($form->{all_departments}) {
    $form->{selectdepartment} = "<option>\n";
    $form->{department}       = "$form->{department}--$form->{department_id}";

    map {
      $form->{selectdepartment} .=
        "<option>$_->{description}--$_->{id}\n"
    } (@{ $form->{all_departments} || [] });
  }

  # forex
  $form->{forex} = $form->{exchangerate};
  my $exchangerate = ($form->{exchangerate}) ? $form->{exchangerate} : 1;

  foreach my $key (keys %{ $form->{AP_links} }) {

    foreach my $ref (@{ $form->{AP_links}{$key} }) {
      $form->{"select$key"} .= "<option>$ref->{accno}--$ref->{description}\n";
    }

    next unless $form->{acc_trans}{$key};

    if ($key eq "AP_paid") {
      for my $i (1 .. scalar @{ $form->{acc_trans}{$key} }) {
        $form->{"AP_paid_$i"} =
          "$form->{acc_trans}{$key}->[$i-1]->{accno}--$form->{acc_trans}{$key}->[$i-1]->{description}";

        # reverse paid
        $form->{"paid_$i"}     = $form->{acc_trans}{$key}->[$i - 1]->{amount};
        $form->{"datepaid_$i"} =
          $form->{acc_trans}{$key}->[$i - 1]->{transdate};
        $form->{"forex_$i"} = $form->{"exchangerate_$i"} =
          $form->{acc_trans}{$key}->[$i - 1]->{exchangerate};
        $form->{"source_$i"} = $form->{acc_trans}{$key}->[$i - 1]->{source};
        $form->{"memo_$i"}   = $form->{acc_trans}{$key}->[$i - 1]->{memo};

        $form->{paidaccounts} = $i;
      }
    } else {
      $form->{$key} =
        "$form->{acc_trans}{$key}->[0]->{accno}--$form->{acc_trans}{$key}->[0]->{description}";
    }

  }

  $form->{paidaccounts} = 1 unless (exists $form->{paidaccounts});

  $form->{AP} = $form->{AP_1} unless $form->{id};

  $form->{locked} =
    ($form->datetonum($form->{invdate}, \%myconfig) <=
     $form->datetonum($form->{closedto}, \%myconfig));

  $main::lxdebug->leave_sub();
}

sub prepare_invoice {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $main::auth->assert('vendor_invoice_edit');

  if ($form->{id}) {

    map { $form->{$_} =~ s/\"/&quot;/g } qw(invnumber ordnumber quonumber);

    my $i = 0;
    foreach my $ref (@{ $form->{invoice_details} }) {
      $i++;
      map { $form->{"${_}_$i"} = $ref->{$_} } keys %{$ref};

      my ($dec) = ($form->{"sellprice_$i"} =~ /\.(\d+)/);
      $dec           = length $dec;
      my $decimalplaces = ($dec > 2) ? $dec : 2;

      $form->{"sellprice_$i"} =
        $form->format_amount(\%myconfig, $form->{"sellprice_$i"},
                             $decimalplaces);

      (my $dec_qty) = ($form->{"qty_$i"} =~ /\.(\d+)/);
      $dec_qty = length $dec_qty;

      $form->{"qty_$i"} =
        $form->format_amount(\%myconfig, ($form->{"qty_$i"} * -1), $dec_qty);

      $form->{rowcount} = $i;
    }
  }

  $main::lxdebug->leave_sub();
}

sub form_header {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;
  my $cgi      = $main::cgi;

  $main::auth->assert('vendor_invoice_edit');

  push @{ $form->{AJAX} }, CGI::Ajax->new('set_duedate_vendor' => "$form->{script}?action=set_duedate_vendor");

  # set option selected
  foreach my $item (qw(AP vendor currency department)) {
    $form->{"select$item"} =~ s/ selected//;
    $form->{"select$item"} =~ s/option>\Q$form->{$item}\E/option selected>$form->{$item}/;
  }

  $form->{employee_id}     = $form->{old_employee_id} if $form->{old_employee_id};
  $form->{salesman_id}     = $form->{old_salesman_id} if $form->{old_salesman_id};
  $form->{defaultcurrency} = $form->get_default_currency(\%myconfig);
  $form->{radier}          = ($form->current_date(\%myconfig) eq $form->{gldate}) ? 1 : 0;
  $form->{exchangerate}    = $form->format_amount(\%myconfig, $form->{exchangerate});
  $form->{creditlimit}     = $form->format_amount(\%myconfig, $form->{creditlimit}, 0, "0");
  $form->{creditremaining} = $form->format_amount(\%myconfig, $form->{creditremaining}, 0, "0");

  my $exchangerate = "";
  if ($form->{currency} ne $form->{defaultcurrency}) {
    if ($form->{forex}) {
      $exchangerate .= qq| <th align=right nowrap>| . $locale->text('Exchangerate') . qq|</th>
                           <td>$form->{exchangerate}<input type=hidden name=exchangerate value=$form->{exchangerate}></td>\n|;
    } else {
      $exchangerate .= qq| <th align=right nowrap>| . $locale->text('Exchangerate') . qq|</th>
                           <td><input name=exchangerate size=10 value=$form->{exchangerate}></td>\n|;
    }
  }
  $exchangerate .= qq| <input type=hidden name=forex value=$form->{forex}>\n|;

  my @old_project_ids = ($form->{"globalproject_id"});
  map { push @old_project_ids, $form->{"project_id_$_"} if $form->{"project_id_$_"}; } 1..$form->{"rowcount"};

  $form->get_lists("contacts"      => "ALL_CONTACTS",
                   "projects"      => { "key"  => "ALL_PROJECTS",
                                      "all"    => 0,
                                      "old_id" => \@old_project_ids },
                   "taxzones"      => "ALL_TAXZONES",
                   "employees"     => "ALL_SALESMEN",
                   "currencies"    => "ALL_CURRENCIES",
                   "vendors"       => "ALL_VENDORS",
                   "price_factors" => "ALL_PRICE_FACTORS");

  my %labels;
  my @values = (undef);
  foreach my $item (@{ $form->{"ALL_CONTACTS"} }) {
    push(@values, $item->{"cp_id"});
    $labels{$item->{"cp_id"}} = $item->{"cp_name"} . ($item->{"cp_abteilung"} ? " ($item->{cp_abteilung})" : "");
  }

  my $contact;
  if (scalar @values > 1) {
    $contact = qq|
    <tr>
      <th align="right">| . $locale->text('Contact Person') . qq|</th>
      <td>| .  NTI($cgi->popup_menu('-name' => 'cp_id', '-values' => \@values, '-style' => 'width: 250px',
                                    '-labels' => \%labels, '-default' => $form->{"cp_id"})) . qq|
      </td>
    </tr>|;
  }

  %labels = ();
  @values = ("");
  foreach my $item (@{ $form->{"ALL_PROJECTS"} }) {
    push(@values, $item->{"id"});
    $labels{$item->{"id"}} = $item->{"projectnumber"};
  }
  my $globalprojectnumber = NTI($cgi->popup_menu('-name' => 'globalproject_id', '-values' => \@values, '-labels' => \%labels,
                                                 '-default' => $form->{"globalproject_id"}));

  %labels = ();
  @values = ();
  my $i = 0;
  foreach my $item (@{ $form->{"ALL_CURRENCIES"} }) {
    push(@values, $item);
    $labels{$item} = $item;
  }

  $form->{currency} = $form->{defaultcurrency} unless $form->{currency};
  my $currencies;
  if (scalar @values) {
    $currencies = qq|
    <tr>
      <th align="right">| . $locale->text('Currency') . qq|</th>
      <td>| .  NTI($cgi->popup_menu('-name' => 'currency', '-default' => $form->{"currency"},
                                    '-values' => \@values, '-labels' => \%labels)) . qq|
      </td>
    </tr>|;
  }

  %labels = ();
  @values = ();
  foreach my $item (@{ $form->{"ALL_SALESMEN"} }) {
    push(@values, $item->{"id"});
    $labels{$item->{"id"}} = $item->{"name"};
  }
  my $employees = qq|
    <tr>
      <th align="right">| . $locale->text('Employee') . qq|</th>
      <td>| .  NTI($cgi->popup_menu('-name' => 'employee_id', '-default' => $form->{"employee_id"},
                                    '-values' => \@values, '-labels' => \%labels)) . qq|
      </td>
    </tr>|;

  %labels = ();
  @values = ();
  foreach my $item (@{ $form->{"ALL_VENDORS"} }) {
    push(@values, $item->{name}.qq|--|.$item->{"id"});
    $labels{$item->{name}.qq|--|.$item->{"id"}} = $item->{"name"};
  }

  $form->{selectvendor} = ($myconfig{vclimit} > scalar(@values));

  my $vendors = qq|
      <th align="right">| . $locale->text('Vendor') . qq|</th>
      <td>| .
        (($myconfig{vclimit} <=  scalar(@values))
              ? qq|<input type="text" value="| . H($form->{vendor}) . qq|" name="vendor">|
              : (NTI($cgi->popup_menu('-name' => 'vendor', '-default' => $form->{oldvendor},
                                      '-onChange' => 'document.getElementById(\'update_button\').click();',
                                      '-values' => \@values, '-labels' => \%labels, '-style' => 'width: 250px')))) . qq|
        <input type="button" value="| . $locale->text('Details (one letter abbreviation)') . qq|" onclick="show_vc_details('vendor')">
      </td>|;

  %labels = ();
  @values = ();
  foreach my $item (@{ $form->{"ALL_TAXZONES"} }) {
    push(@values, $item->{"id"});
    $labels{$item->{"id"}} = $item->{"description"};
  }

  my $taxzone;
  if (!$form->{"id"}) {
    $taxzone = qq|
    <tr>
      <th align="right">| . $locale->text('Steuersatz') . qq|</th>
      <td>| .  NTI($cgi->popup_menu('-name' => 'taxzone_id', '-default' => $form->{"taxzone_id"},
                                    '-values' => \@values, '-labels' => \%labels, '-style' => 'width: 250px')) . qq|
      </td>
    </tr>|;
  } else {
    $taxzone = qq|
    <tr>
      <th align="right">| . $locale->text('Steuersatz') . qq|</th>
      <td>
        <input type="hidden" name="taxzone_id" value="| . H($form->{"taxzone_id"}) . qq|">
        | . H($labels{$form->{"taxzone_id"}}) . qq|
      </td>
    </tr>|;
  }

  my $department = qq|
           <tr>
	      <th align="right" nowrap>| . $locale->text('Department') . qq|</th>
	      <td colspan="3"><select name="department" style="width: 250px">$form->{selectdepartment}</select>
	      <input type="hidden" name="selectdepartment" value="$form->{selectdepartment}">
	      </td>
	    </tr>\n| if $form->{selectdepartment};

  my $n = ($form->{creditremaining} =~ /-/) ? "0" : "1";

  # use JavaScript Calendar or not
  $form->{jsscript} = 1;
  my $jsscript = "";

  my $button1 = qq|
     <td nowrap>
         <input name=invdate id=invdate size=11 title="$myconfig{dateformat}" value="$form->{invdate}" onBlur=\"check_right_date_format(this)\"
                onChange="if (this.value) set_duedate_vendor(['invdate__' + this.value, 'old_duedate__' + document.getElementsByName('duedate')[0].value, 'vendor_id__' + document.getElementsByName('vendor_id')[0].value],['duedate'])">
         <input type=button name=invdate id="trigger1" value="?">
     </td>\n|;

#, 'old_duedate__'' + document.getElementsByName('duedate')[0].value, 'vendor_id__' + document.getElementsByName('vendor_id')[0].value],['duedate'])">
  my $button2 = qq|
     <td width="13" nowrap>
          <input name=duedate id=duedate size=11 title="$myconfig{dateformat}" value="$form->{duedate}"  onBlur=\"check_right_date_format(this)\">
          <input type=button name=duedate id="trigger2" value=| . $locale->text('button') . qq|>
     </td>\n|;

  #write Trigger
  $jsscript =
    Form->write_trigger(\%myconfig, "2",
                        "invdate", "BL", "trigger1",
                        "duedate", "BL", "trigger2");

  my $follow_up_vc         =  $form->{vendor};
  $follow_up_vc            =~ s/--\d*\s*$//;
  my $follow_up_trans_info =  "$form->{invnumber} ($follow_up_vc)";

  $form->{javascript} .= qq|<script type="text/javascript" src="js/show_form_details.js"></script>|;
  $form->{javascript} .= qq|<script type="text/javascript" src="js/common.js"></script>|;
  $form->{javascript} .= qq|<script type="text/javascript" src="js/show_vc_details.js"></script>|;
  $form->{javascript} .= qq|<script type="text/javascript" src="js/follow_up.js"></script>|;

  $jsscript .= $form->write_trigger(\%myconfig, 2, "orddate", "BL", "trigger_orddate", "quodate", "BL", "trigger_quodate");

  $form->header;
  my $onload  = qq|focus()|;
  $onload .= qq|;setupDateFormat('|. $myconfig{dateformat} .qq|', '|. $locale->text("Falsches Datumsformat!") .qq|')|;
  $onload .= qq|;setupPoints('|. $myconfig{numberformat} .qq|', '|. $locale->text("wrongformat") .qq|')|;
  print qq|
<body onLoad="$onload">
<script type="text/javascript" src="js/common.js"></script>
<form method="post" action="ir.pl" name="Form">
|;

  $form->hide_form(qw(id title vc type level creditlimit creditremaining closedto locked shippted storno storno_id
                      max_dunning_level dunning_amount vendor_id oldvendor selectvendor taxaccounts
                      fxgain_accno fxloss_accno taxpart taxservice cursor_fokus
                      convert_from_oe_ids convert_from_do_ids),
                      map { $_.'_rate', $_.'_description' } split / /, $form->{taxaccounts} );

  print qq|<p>$form->{saved_message}</p>| if $form->{saved_message};

  print qq|

<div class="listtop" width="100%">$form->{title}</div>

<table width=100%>
  <tr>
    <td valign="top">
	    <table>
        $vendors
        $contact
        <tr>
          <td align="right">| . $locale->text('Credit Limit') . qq|</td>
          <td>$form->{creditlimit}; | . $locale->text('Remaining') . qq| <span class="plus$n">$form->{creditremaining}</span></td>
        </tr>
	      <tr>
		<th align="right">| . $locale->text('Record in') . qq|</th>
		<td colspan="3"><select name="AP" style="width: 250px">$form->{selectAP}</select></td>
		<input type="hidden" name="selectAP" value="$form->{selectAP}">
	      </tr>
              $taxzone
              $department
	      <tr>
    $currencies
		$exchangerate
	      </tr>
	    </table>
	  </td>
	  <td align=right>
	    <table>
     $employees
	      <tr>
		<th align=right nowrap>| . $locale->text('Invoice Number') . qq|</th>
		<td><input name=invnumber size=11 value="$form->{invnumber}"></td>
	      </tr>
	      <tr>
		<th align=right nowrap>| . $locale->text('Invoice Date') . qq|</th>
                $button1
	      </tr>
	      <tr>
		<th align=right nowrap>| . $locale->text('Due Date') . qq|</th>
                $button2
	      </tr>
	      <tr>
		<th align=right nowrap>| . $locale->text('Order Number') . qq|</th>
		<td><input name=ordnumber size=11 value="$form->{ordnumber}"></td>
<input type=hidden name=quonumber value="$form->{quonumber}">
	      </tr>
        <tr>
          <th align="right" nowrap>| . $locale->text('Order Date') . qq|</th>
          <td><input name="orddate" id="orddate" size="11" title="$myconfig{dateformat}" value="| . Q($form->{orddate}) . qq|" onBlur=\"check_right_date_format(this)\">
           <input type="button" name="b_orddate" id="trigger_orddate" value="?"></td>
        </tr>
        <tr>
          <th align="right" nowrap>| . $locale->text('Quotation Date') . qq|</th>
          <td><input name="quodate" id="quodate" size="11" title="$myconfig{dateformat}" value="| . Q($form->{quodate}) . qq|" onBlur=\"check_right_date_format(this)\">
           <input type="button" name="b_quodate" id="trigger_quodate" value="?"></td>
        </tr>
	      <tr>
          <th align="right" nowrap>| . $locale->text('Project Number') . qq|</th>
          <td>$globalprojectnumber</td>
	      </tr>
     </table>
	  </td>
	</tr>
      </table>
    </td>
  </tr>

$jsscript

<input type=hidden name=webdav value=$main::webdav>
|;

  foreach my $item (split / /, $form->{taxaccounts}) {
    print qq|
<input type=hidden name="${item}_rate" value=$form->{"${item}_rate"}>
<input type=hidden name="${item}_description" value="$form->{"${item}_description"}">
|;
  }

  $main::lxdebug->leave_sub();
}

sub form_footer {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;
  my $cgi      = $main::cgi;

  $main::auth->assert('vendor_invoice_edit');

  $form->{invtotal} = $form->{invsubtotal};

  my ($rows, $introws);
  if (($rows = $form->numtextrows($form->{notes}, 25, 8)) < 2) {
    $rows = 2;
  }
  if (($introws = $form->numtextrows($form->{intnotes}, 35, 8)) < 2) {
    $introws = 2;
  }
  $rows = ($rows > $introws) ? $rows : $introws;
  my $notes =
    qq|<textarea name=notes rows=$rows cols=25 wrap=soft>$form->{notes}</textarea>|;
  my $intnotes =
    qq|<textarea name=intnotes rows=$rows cols=35 wrap=soft>$form->{intnotes}</textarea>|;

  $form->{taxincluded} = ($form->{taxincluded}) ? "checked" : "";

  my $taxincluded = "";
  if ($form->{taxaccounts}) {
    $taxincluded = qq|
		<input name=taxincluded class=checkbox type=checkbox value=1 $form->{taxincluded}> <b>|
      . $locale->text('Tax Included') . qq|</b>
|;
  }

  my ($tax, $subtotal);
  if (!$form->{taxincluded}) {

    foreach my $item (split / /, $form->{taxaccounts}) {
      if ($form->{"${item}_base"}) {
        $form->{invtotal} += $form->{"${item}_total"} =
          $form->round_amount(
                             $form->{"${item}_base"} * $form->{"${item}_rate"},
                             2);
        $form->{"${item}_total"} =
          $form->format_amount(\%myconfig, $form->{"${item}_total"}, 2);

        $tax .= qq|
		<tr>
		  <th align=right>$form->{"${item}_description"}&nbsp;|
                    . $form->{"${item}_rate"} * 100 .qq|%</th>
		  <td align=right>$form->{"${item}_total"}</td>
		</tr>
|;
      }
    }

    $form->{invsubtotal} =
      $form->format_amount(\%myconfig, $form->{invsubtotal}, 2, 0);

    $subtotal = qq|
	      <tr>
		<th align=right>| . $locale->text('Subtotal') . qq|</th>
		<td align=right>$form->{invsubtotal}</td>
	      </tr>
|;

  }

  if ($form->{taxincluded}) {
    foreach my $item (split / /, $form->{taxaccounts}) {
      if ($form->{"${item}_base"}) {
        $form->{"${item}_total"} =
          $form->round_amount(
                           ($form->{"${item}_base"} * $form->{"${item}_rate"} /
                              (1 + $form->{"${item}_rate"})
                           ),
                           2);
        $form->{"${item}_base"} =
          $form->round_amount($form->{"${item}_base"}, 2);
        $form->{"${item}_netto"} =
          $form->round_amount(
                          ($form->{"${item}_base"} - $form->{"${item}_total"}),
                          2);
        $form->{"${item}_netto"} =
          $form->format_amount(\%myconfig, $form->{"${item}_netto"}, 2);
        $form->{"${item}_total"} =
          $form->format_amount(\%myconfig, $form->{"${item}_total"}, 2);

        $tax .= qq|
	      <tr>
		<th align=right>Enthaltene $form->{"${item}_description"}&nbsp;|
		                    . $form->{"${item}_rate"} * 100 .qq|%</th>
		<td align=right>$form->{"${item}_total"}</td>
	      </tr>
	      <tr>
	        <th align=right>Nettobetrag</th>
		<td align=right>$form->{"${item}_netto"}</td>
	      </tr>
|;
      }
    }

  }

  $form->{oldinvtotal} = $form->{invtotal};
  $form->{invtotal}    =
    $form->format_amount(\%myconfig, $form->{invtotal}, 2, 0);

  my $follow_ups_block;
  if ($form->{id}) {
    my $follow_ups = FU->follow_ups('trans_id' => $form->{id});

    if (@{ $follow_ups} ) {
      my $num_due       = sum map { $_->{due} * 1 } @{ $follow_ups };
      $follow_ups_block = qq|
      <tr>
        <td colspan="2">| . $locale->text("There are #1 unfinished follow-ups of which #2 are due.", scalar @{ $follow_ups }, $num_due) . qq|</td>
      </tr>
|;
    }
  }

  our $colspan;
  print qq|
  <tr>
    <td colspan=$colspan>
      <table cellspacing="0">
	<tr valign=bottom>
	  <td>
	    <table>
	      <tr>
		<th align=left>| . $locale->text('Notes') . qq|</th>
		<th align=left>| . $locale->text('Internal Notes') . qq|</th>
	      </tr>
	      <tr valign=top>
		<td>$notes</td>
		<td>$intnotes</td>
	      </tr>
        $follow_ups_block
	    </table>
	  </td>
	  <td colspan=2 align=right width=100%>
	    $taxincluded
	    <br>
	    <table width=100%>
	      $subtotal
	      $tax
	      <tr>
		<th align=right>| . $locale->text('Total') . qq|</th>
		<td align=right>$form->{invtotal}</td>
	      </tr>
	    </table>
	  </td>
	</tr>
      </table>
    </td>
  </tr>
|;
  my $webdav_list;
  if ($main::webdav) {
    $webdav_list = qq|
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
  <tr>
    <th class=listtop align=left>Dokumente im Webdav-Repository</th>
  </tr>
    <table width=100%>
      <td align=left width=30%><b>Dateiname</b></td>
      <td align=left width=70%><b>Webdavlink</b></td>
|;
    foreach my $file (@{ $form->{WEBDAV} }) {
      $webdav_list .= qq|
      <tr>
        <td align="left">$file->{name}</td>
        <td align="left"><a href="$file->{link}">$file->{type}</a></td>
      </tr>
|;
    }
    $webdav_list .= qq|
    </table>
  </tr>
|;

    print $webdav_list;
  }
  print qq|
  <tr>
    <td colspan=$colspan>
      <table width=100%>
        <tr>
	  <th colspan=6 class=listheading>| . $locale->text('Payments') . qq|</th>
	</tr>
|;

  my @column_index;
  if ($form->{currency} eq $form->{defaultcurrency}) {
    @column_index = qw(datepaid source memo paid AP_paid);
  } else {
    @column_index = qw(datepaid source memo paid exchangerate AP_paid);
  }

  my %column_data;
  $column_data{datepaid}     = "<th>" . $locale->text('Date') . "</th>";
  $column_data{paid}         = "<th>" . $locale->text('Amount') . "</th>";
  $column_data{exchangerate} = "<th>" . $locale->text('Exch') . "</th>";
  $column_data{AP_paid}      = "<th>" . $locale->text('Account') . "</th>";
  $column_data{source}       = "<th>" . $locale->text('Source') . "</th>";
  $column_data{memo}         = "<th>" . $locale->text('Memo') . "</th>";

  print qq|
	<tr>
|;
  map { print "$column_data{$_}\n" } @column_index;
  print qq|
	</tr>
|;

  my @triggers  = ();
  my $totalpaid = 0;

  $form->{paidaccounts}++ if ($form->{"paid_$form->{paidaccounts}"});
  for my $i (1 .. $form->{paidaccounts}) {

    print qq|
	<tr>
|;

    $form->{"selectAP_paid_$i"} = $form->{selectAP_paid};
    $form->{"selectAP_paid_$i"} =~
      s/option>\Q$form->{"AP_paid_$i"}\E/option selected>$form->{"AP_paid_$i"}/;

    $totalpaid += $form->{"paid_$i"};

    # format amounts
    if ($form->{"paid_$i"}) {
      $form->{"paid_$i"} =
        $form->format_amount(\%myconfig, $form->{"paid_$i"}, 2);
    }
    $form->{"exchangerate_$i"} =
      $form->format_amount(\%myconfig, $form->{"exchangerate_$i"});

    my $exchangerate = qq|&nbsp;|;
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
    $column_data{"exchangerate_$i"} = qq|<td align=center>$exchangerate</td>|;
    $column_data{"AP_paid_$i"}      =
      qq|<td align=center><select name="AP_paid_$i">$form->{"selectAP_paid_$i"}</select></td>|;
    $column_data{"datepaid_$i"} =
      qq|<td align=center><input name="datepaid_$i" id="datepaid_$i" size=11 title="$myconfig{dateformat}" value="$form->{"datepaid_$i"}" onBlur=\"check_right_date_format(this)\">
         <input type="button" name="datepaid_$i" id="trigger_datepaid_$i" value="?"></td>|;
    $column_data{"source_$i"} =
      qq|<td align=center><input name="source_$i" size=11 value="$form->{"source_$i"}"></td>|;
    $column_data{"memo_$i"} =
      qq|<td align=center><input name="memo_$i" size=11 value="$form->{"memo_$i"}"></td>|;

    map { print qq|$column_data{"${_}_$i"}\n| } @column_index;

    print qq|
	</tr>
|;
    push(@triggers, "datepaid_$i", "BL", "trigger_datepaid_$i");
  }

  my $paid_missing = $form->{oldinvtotal} - $totalpaid;

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

	    <input type=hidden name=oldinvtotal value=$form->{oldinvtotal}>
	    <input type=hidden name=paidaccounts value=$form->{paidaccounts}>
      	    <input type=hidden name=selectAP_paid value="$form->{selectAP_paid}">
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>
<br>
|;

  my $invdate  = $form->datetonum($form->{invdate},  \%myconfig);
  my $closedto = $form->datetonum($form->{closedto}, \%myconfig);

  print qq|<input class=submit type=submit name=action id=update_button value="|
    . $locale->text('Update') . qq|">
|;

  if ($form->{id}) {
    my $show_storno = !$form->{storno} && !IS->has_storno(\%myconfig, $form, "ap") && (($totalpaid == 0) || ($totalpaid eq ""));

    print qq|<input class=submit type=submit name=action value="|
      . $locale->text('Post Payment') . qq|">
|;
    print qq|<input class=submit type=submit name=action value="|
      . $locale->text('Storno') . qq|">
| if ($show_storno);
    if ($form->{radier}) {
    print qq|
    <input class=submit type=submit name=action value="|
      . $locale->text('Delete') . qq|">
|;
  }
    print qq|<input class=submit type=submit name=action value="|
      . $locale->text('Use As Template') . qq|">
        <input type="button" class="submit" onclick="follow_up_window()" value="|
      . $locale->text('Follow-Up')
      . qq|">
|;

  }

  if (!$form->{id} && ($invdate > $closedto)) {
    print qq| <input class=submit type=submit name=action value="|
      . $locale->text('Post') . qq|"> | .
      NTI($cgi->submit('-name' => 'action', '-value' => $locale->text('Save draft'),
                       '-class' => 'submit'));
  }

  print $form->write_trigger(\%myconfig, scalar(@triggers) / 3, @triggers);
  $form->hide_form(qw(rowcount callback draft_id draft_description vendor_discount));

  # button for saving history
  if($form->{id} ne "") {
    print qq|
  	  <input type="button" class="submit" onclick="set_history_window(|
  	  . Q($form->{id})
  	  . qq|);" name="history" id="history" value="|
  	  . $locale->text('history')
  	  . qq|">|;
  }
  # /button for saving history
  # mark_as_paid button
  if($form->{id} ne "") {
    print qq| <input type="submit" class="submit" name="action" value="|
          . $locale->text('mark as paid') . qq|">|;
  }
  # /mark_as_paid button
print qq|</form>
</body>
</html>
|;

  $main::lxdebug->leave_sub();
}

sub mark_as_paid {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $main::auth->assert('vendor_invoice_edit');

  &mark_as_paid_common(\%myconfig,"ap");

  $main::lxdebug->leave_sub();
}

sub update {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $main::auth->assert('vendor_invoice_edit');

  map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) } qw(exchangerate creditlimit creditremaining);

  &check_name('vendor');

  $form->{forex}        = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{invdate}, 'sell');
  $form->{exchangerate} = $form->{forex} if $form->{forex};

  for my $i (1 .. $form->{paidaccounts}) {
    next unless $form->{"paid_$i"};
    map { $form->{"${_}_$i"} = $form->parse_amount(\%myconfig, $form->{"${_}_$i"}) } qw(paid exchangerate);
    $form->{"forex_$i"}        = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{"datepaid_$i"}, 'sell');
    $form->{"exchangerate_$i"} = $form->{"forex_$i"} if $form->{"forex_$i"};
  }

  my $i            = $form->{rowcount};
  my $exchangerate = ($form->{exchangerate} * 1) || 1;

  if (   ($form->{"partnumber_$i"} eq "")
      && ($form->{"description_$i"} eq "")
      && ($form->{"partsgroup_$i"} eq "")) {
    $form->{creditremaining} += ($form->{oldinvtotal} - $form->{oldtotalpaid});
    &check_form;

  } else {

    IR->retrieve_item(\%myconfig, \%$form);

    my $rows = scalar @{ $form->{item_list} };

    if ($rows) {
      $form->{"qty_$i"} = 1 unless ($form->{"qty_$i"});

      if ($rows > 1) {

        &select_item;
        exit;

      } else {

        # override sellprice if there is one entered
        my $sellprice = $form->parse_amount(\%myconfig, $form->{"sellprice_$i"});

	# ergaenzung fuer bug 736 Lieferanten-Rabatt auch in Einkaufsrechnungen vorbelegen jb
        $form->{"discount_$i"} = $form->format_amount(\%myconfig,
						      $form->{vendor_discount} * 100 );
        map { $form->{item_list}[$i]{$_} =~ s/\"/&quot;/g } qw(partnumber description unit);
        map { $form->{"${_}_$i"} = $form->{item_list}[0]{$_} } keys %{ $form->{item_list}[0] };

        $form->{"marge_price_factor_$i"} = $form->{item_list}->[0]->{price_factor};

        ($sellprice || $form->{"sellprice_$i"}) =~ /\.(\d+)/;
        my $dec_qty       = length $1;
        my $decimalplaces = max 2, $dec_qty;

        if ($sellprice) {
          $form->{"sellprice_$i"} = $sellprice;
        } else {
          # if there is an exchange rate adjust sellprice
          $form->{"sellprice_$i"} /= $exchangerate;
        }

        my $amount                   = $form->{"sellprice_$i"} * $form->{"qty_$i"} * (1 - $form->{"discount_$i"} / 100);
        $form->{creditremaining} -= $amount;
        $form->{"sellprice_$i"}   = $form->format_amount(\%myconfig, $form->{"sellprice_$i"}, $decimalplaces);
        $form->{"qty_$i"}         = $form->format_amount(\%myconfig, $form->{"qty_$i"},       $dec_qty);
      }

      &display_form;

    } else {

      # ok, so this is a new part
      # ask if it is a part or service item

      if (   $form->{"partsgroup_$i"}
          && ($form->{"partsnumber_$i"} eq "")
          && ($form->{"description_$i"} eq "")) {
        $form->{rowcount}--;
        $form->{"discount_$i"} = "";
        display_form();

      } else {
        $form->{"id_$i"}   = 0;
        new_item();
      }
    }
  }
  $main::lxdebug->leave_sub();
}

sub storno {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('vendor_invoice_edit');

  if ($form->{storno}) {
    $form->error($locale->text('Cannot storno storno invoice!'));
  }

  if (IS->has_storno(\%myconfig, $form, "ap")) {
    $form->error($locale->text("Invoice has already been storno'd!"));
  }

  my $employee_id = $form->{employee_id};
  invoice_links();
  prepare_invoice();
  relink_accounts();

  # Payments must not be recorded for the new storno invoice.
  $form->{paidaccounts} = 0;
  map { my $key = $_; delete $form->{$key} if grep { $key =~ /^$_/ } qw(datepaid_ source_ memo_ paid_ exchangerate_ AR_paid_) } keys %{ $form };

  # saving the history
  if(!exists $form->{addition} && $form->{id} ne "") {
    $form->{snumbers} = qq|invnumber_| . $form->{invnumber};
    $form->{addition} = "CANCELED";
    $form->save_history($form->dbconnect(\%myconfig));
  }
  # /saving the history

  $form->{storno_id} = $form->{id};
  $form->{storno} = 1;
  $form->{id} = "";
  $form->{invnumber} = "Storno zu " . $form->{invnumber};
  $form->{rowcount}++;
  $form->{employee_id} = $employee_id;
  post();
  $main::lxdebug->leave_sub();

}

sub use_as_template {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $main::auth->assert('vendor_invoice_edit');

  map { delete $form->{$_} } qw(printed emailed queued invnumber invdate deliverydate id datepaid_1 source_1 memo_1 paid_1 exchangerate_1 AP_paid_1 storno);
  $form->{paidaccounts} = 1;
  $form->{rowcount}--;
  $form->{invdate} = $form->current_date(\%myconfig);
  &display_form;

  $main::lxdebug->leave_sub();
}

sub post_payment {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('vendor_invoice_edit');

  $form->{defaultcurrency} = $form->get_default_currency(\%myconfig);
  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"}) {
      my $datepaid = $form->datetonum($form->{"datepaid_$i"}, \%myconfig);

      $form->isblank("datepaid_$i", $locale->text('Payment date missing!'));

      $form->error($locale->text('Cannot post payment for a closed period!'))
        if ($form->date_closed($form->{"datepaid_$i"}, \%myconfig));

      if ($form->{currency} ne $form->{defaultcurrency}) {
#        $form->{"exchangerate_$i"} = $form->{exchangerate} if ($invdate == $datepaid); # invdate isn't set here
        $form->isblank("exchangerate_$i", $locale->text('Exchangerate for payment missing!'));
      }
    }
  }

  ($form->{AP})      = split /--/, $form->{AP};
  ($form->{AP_paid}) = split /--/, $form->{AP_paid};
  if (IR->post_payment(\%myconfig, \%$form)){
  	if (!exists $form->{addition} && $form->{id} ne "") {
  		# saving the history
      $form->{snumbers} = qq|invnumber_| . $form->{invnumber};
  		$form->{addition} = "PAYMENT POSTED";
      $form->{what_done} = $form->{currency} . qq| | . $form->{paid} . qq| | . $locale->text("POSTED");
  		$form->save_history($form->dbconnect(\%myconfig));
  		# /saving the history
  	}

    $form->redirect($locale->text('Payment posted!'));
  }

  $form->error($locale->text('Cannot post payment!'));

  $main::lxdebug->leave_sub();
}

sub _max_datepaid {
  my $form  =  $main::form;

  my @dates = sort { $b->[1] cmp $a->[1] }
              map  { [ $_, $main::locale->reformat_date(\%main::myconfig, $_, 'yyyy-mm-dd') ] }
              grep { $_ }
              map  { $form->{"datepaid_${_}"} }
              (1..$form->{rowcount});

  return @dates ? $dates[0]->[0] : undef;
}


sub post {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('vendor_invoice_edit');

  $form->{defaultcurrency} = $form->get_default_currency(\%myconfig);

  $form->isblank("invdate",   $locale->text('Invoice Date missing!'));
  $form->isblank("vendor",    $locale->text('Vendor missing!'));
  $form->isblank("invnumber", $locale->text('Invnumber missing!'));

  $form->{invnumber} =~ s/^\s*//g;
  $form->{invnumber} =~ s/\s*$//g;

  # if the vendor changed get new values
  if (&check_name('vendor')) {
    &update;
    exit;
  }

  &validate_items;

  my $closedto     = $form->datetonum($form->{closedto}, \%myconfig);
  my $invdate      = $form->datetonum($form->{invdate},  \%myconfig);
  my $max_datepaid = _max_datepaid();

  $form->error($locale->text('Cannot post invoice for a closed period!')) if $max_datepaid && $form->date_closed($max_datepaid, \%myconfig);

  $form->isblank("exchangerate", $locale->text('Exchangerate missing!'))
    if ($form->{currency} ne $form->{defaultcurrency});

  my $i;
  for $i (1 .. $form->{paidaccounts}) {
    if ($form->parse_amount(\%myconfig, $form->{"paid_$i"})) {
      my $datepaid = $form->datetonum($form->{"datepaid_$i"}, \%myconfig);

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
  $form->{storno}  ||= 0;

  $form->{id} = 0 if $form->{postasnew};


  relink_accounts();
  if (IR->post_invoice(\%myconfig, \%$form)){
  	# saving the history
  	if(!exists $form->{addition} && $form->{id} ne "") {
      $form->{snumbers} = qq|invnumber_| . $form->{invnumber};
      $form->{addition} = "POSTED";
  		#$form->{what_done} = $locale->text("Rechnungsnummer") . qq| | . $form->{invnumber};
  		$form->save_history($form->dbconnect(\%myconfig));
  	}
	# /saving the history
    remove_draft() if $form->{remove_draft};
  	$form->redirect(  $locale->text('Invoice')
                  . " $form->{invnumber} "
                  . $locale->text('posted!'));
  }
  $form->error($locale->text('Cannot post invoice!'));

  $main::lxdebug->leave_sub();
}

sub delete {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  $main::auth->assert('vendor_invoice_edit');

  $form->header;
  print qq|
<body>

<form method=post action=$form->{script}>
|;

  # delete action variable
  map { delete $form->{$_} } qw(action header);

  foreach my $key (keys %$form) {
    next if (($key eq 'login') || ($key eq 'password') || ('' ne ref $form->{$key}));
    $form->{$key} =~ s/\"/&quot;/g;
    print qq|<input type=hidden name=$key value="$form->{$key}">\n|;
  }

  print qq|
<h2 class=confirm>| . $locale->text('Confirm!') . qq|</h2>

<h4>|
    . $locale->text('Are you sure you want to delete Invoice Number')
    . qq| $form->{invnumber}</h4>
<p>
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

  $main::auth->assert('vendor_invoice_edit');

  if (IR->delete_invoice(\%myconfig, \%$form)) {
    # saving the history
    if(!exists $form->{addition}) {
      $form->{snumbers} = qq|invnumber_| . $form->{invnumber};
  	  $form->{addition} = "DELETED";
  	  $form->save_history($form->dbconnect(\%myconfig));
    }
    # /saving the history
    $form->redirect($locale->text('Invoice deleted!'));
  }
  $form->error($locale->text('Cannot delete invoice!'));

  $main::lxdebug->leave_sub();
}

sub set_duedate_vendor {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  print $form->ajax_response_header(), IR->get_duedate('vendor_id' => $form->{vendor_id},
                                                       'invdate'   => $form->{invdate},
                                                       'default'   => $form->{old_duedate});

  $main::lxdebug->leave_sub();
}
