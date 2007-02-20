#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#############################################################################
# Veraendert 2005-01-05 - Marco Welter <mawe@linux-studio.de> - Neue Optik  #
#############################################################################
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
#
#######################################################################
#
# common routines used in is, ir, oe
#
#######################################################################

use SL::CT;
use SL::IC;
use CGI::Ajax;
use CGI;

require "$form->{path}/common.pl";

# any custom scripts for this one
if (-f "$form->{path}/custom_io.pl") {
  eval { require "$form->{path}/custom_io.pl"; };
}
if (-f "$form->{path}/$form->{login}_io.pl") {
  eval { require "$form->{path}/$form->{login}_io.pl"; };
}

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
use SL::IS;
use SL::PE;
use SL::AM;
use Data::Dumper;
########################################
# Eintrag fuer Version 2.2.0 geaendert #
# neue Optik im Rechnungsformular      #
########################################
sub display_row {
  $lxdebug->enter_sub();
  my $numrows = shift;

  if ($lizenzen && $form->{vc} eq "customer") {
    if ($form->{type} =~ /sales_order/) {
      @column_index = (runningnumber, partnumber, description, ship, qty);
    } elsif ($form->{type} =~ /sales_quotation/) {
      @column_index = (runningnumber, partnumber, description, qty);
    } else {
      @column_index = (runningnumber, partnumber, description, qty);
    }
  } else {
    if (   ($form->{type} =~ /purchase_order/)
        || ($form->{type} =~ /sales_order/)) {
      @column_index = (runningnumber, partnumber, description, ship, qty);
        } else {
      @column_index = (runningnumber, partnumber, description, qty);
    }
  }
############## ENDE Neueintrag ##################

  my $dimension_units = AM->retrieve_units(\%myconfig, $form, "dimension");
  my $service_units = AM->retrieve_units(\%myconfig, $form, "service");
  my $all_units = AM->retrieve_units(\%myconfig, $form);

  push @column_index, qw(unit);

  #for pricegroups column
  if (   $form->{type} =~ (/sales_quotation/)
      or (($form->{level} =~ /Sales/) and ($form->{type} =~ /invoice/))
      or (($form->{level} eq undef) and ($form->{type} =~ /invoice/))
      or ($form->{type} =~ /sales_order/)) {
    push @column_index, qw(sellprice_pg);
  }

  push @column_index, qw(sellprice);

  if ($form->{vc} eq 'customer') {
    push @column_index, qw(discount);
  }

  push @column_index, "linetotal";

  my $colspan = $#column_index + 1;

  $form->{invsubtotal} = 0;
  map { $form->{"${_}_base"} = 0 } (split(/ /, $form->{taxaccounts}));

########################################
  # Eintrag fuer Version 2.2.0 geaendert #
  # neue Optik im Rechnungsformular      #
########################################
  $column_data{runningnumber} =
      qq|<th align=left nowrap width=5 class=listheading>|
    . $locale->text('No.')
    . qq|</th>|;
  $column_data{partnumber} =
      qq|<th align=left nowrap width=12 class=listheading>|
    . $locale->text('Number')
    . qq|</th>|;
  $column_data{description} =
      qq|<th align=left nowrap width=30 class=listheading>|
    . $locale->text('Part Description')
    . qq|</th>|;
  if ($form->{"type"} eq "purchase_order") {
    $column_data{ship} =
      qq|<th align=left nowrap width=5 class=listheading>|
      . $locale->text('Ship rcvd')
      . qq|</th>|;
  } else {
    $column_data{ship} =
      qq|<th align=left nowrap width=5 class=listheading>|
      . $locale->text('Ship')
      . qq|</th>|;
  }
  $column_data{qty} =
      qq|<th align=left nowrap width=5 class=listheading>|
    . $locale->text('Qty')
    . qq|</th>|;
  $column_data{unit} =
      qq|<th align=left nowrap width=5 class=listheading>|
    . $locale->text('Unit')
    . qq|</th>|;
  $column_data{license} =
      qq|<th align=left nowrap width=10 class=listheading>|
    . $locale->text('License')
    . qq|</th>|;
  $column_data{serialnr} =
      qq|<th align=left nowrap width=10 class=listheading>|
    . $locale->text('Serial No.')
    . qq|</th>|;
  $column_data{projectnr} =
      qq|<th align=left nowrap width=10 class=listheading>|
    . $locale->text('Project')
    . qq|</th>|;
  $column_data{sellprice} =
      qq|<th align=left nowrap width=15 class=listheading>|
    . $locale->text('Price')
    . qq|</th>|;
  $column_data{sellprice_pg} =
      qq|<th align=left nowrap width=15 class=listheading>|
    . $locale->text('Pricegroup')
    . qq|</th>|;
  $column_data{discount} =
      qq|<th align=left class=listheading>|
    . $locale->text('Discount')
    . qq|</th>|;
  $column_data{linetotal} =
      qq|<th align=left nowrap width=10 class=listheading>|
    . $locale->text('Extended')
    . qq|</th>|;
  $column_data{bin} =
      qq|<th align=left nowrap width=10 class=listheading>|
    . $locale->text('Bin')
    . qq|</th>|;
############## ENDE Neueintrag ##################

  $myconfig{"show_form_details"} = 1
    unless (defined($myconfig{"show_form_details"}));
  $form->{"show_details"} = $myconfig{"show_form_details"}
    unless (defined($form->{"show_details"}));
  $form->{"show_details"} = $form->{"show_details"} ? 1 : 0;
  my $show_details_new = 1 - $form->{"show_details"};
  my $show_details_checked = $form->{"show_details"} ? "checked" : "";

  print qq|
  <tr>
    <td>
      <input type="hidden" name="show_details" value="$form->{show_details}">
      <input type="checkbox" id="cb_show_details" onclick="show_form_details($show_details_new);" $show_details_checked>
      <label for="cb_show_details">| . $locale->text("Show details") . qq|</label><br>
      <table width=100%>
	<tr class=listheading>|;

  map { print "\n$column_data{$_}" } @column_index;

  print qq|
        </tr>
|;

  $runningnumber = $locale->text('No.');
  $deliverydate  = $locale->text('Delivery Date');
  $serialnumber  = $locale->text('Serial No.');
  $projectnumber = $locale->text('Project');
  $partsgroup    = $locale->text('Group');
  $reqdate       = $locale->text('Reqdate');

  $delvar = 'deliverydate';

  if ($form->{type} =~ /_order$/ || $form->{type} =~ /_quotation$/) {
    $deliverydate = $locale->text('Required by');
    $delvar       = 'reqdate';
  }

  my %projectnumber_labels = ();
  my @projectnumber_values = ("");
  foreach my $item (@{ $form->{"ALL_PROJECTS"} }) {
    push(@projectnumber_values, $item->{"id"});
    $projectnumber_labels{$item->{"id"}} = $item->{"projectnumber"};
  }

  for $i (1 .. $numrows) {

    # undo formatting
    map {
      $form->{"${_}_$i"} =
        $form->parse_amount(\%myconfig, $form->{"${_}_$i"})
    } qw(qty ship discount sellprice price_new price_old) unless ($form->{simple_save});

    if (!$form->{"unit_old_$i"}) {
      # Neue Ware aus der Datenbank. In diesem Fall ist unit_$i die
      # Einheit, wie sie in den Stammdaten hinterlegt wurde.
      # Es sollte also angenommen werden, dass diese ausgewaehlt war.
      $form->{"unit_old_$i"} = $form->{"unit_$i"};
    }



    # Die zuletzt ausgewaehlte mit der aktuell ausgewaehlten Einheit
    # vergleichen und bei Unterschied den Preis entsprechend umrechnen.
    $form->{"selected_unit_$i"} = $form->{"unit_$i"} unless ($form->{"selected_unit_$i"});

    my $check_units = $form->{"inventory_accno_$i"} ? $dimension_units : $service_units;
    if (!$check_units->{$form->{"selected_unit_$i"}} ||
        ($check_units->{$form->{"selected_unit_$i"}}->{"base_unit"} ne
         $all_units->{$form->{"unit_old_$i"}}->{"base_unit"})) {
      # Die ausgewaehlte Einheit ist fuer diesen Artikel nicht gueltig
      # (z.B. Dimensionseinheit war ausgewaehlt, es handelt sich aber
      # um eine Dienstleistung). Dann keinerlei Umrechnung vornehmen.
      $form->{"unit_old_$i"} = $form->{"selected_unit_$i"} = $form->{"unit_$i"};
    }
    if ((!$form->{"prices_$i"}) || ($form->{"new_pricegroup_$i"} == $form->{"old_pricegroup_$i"})) {
      if ($form->{"unit_old_$i"} ne $form->{"selected_unit_$i"}) {
        my $basefactor = 1;
        if (defined($all_units->{$form->{"unit_old_$i"}}->{"factor"}) &&
            $all_units->{$form->{"unit_old_$i"}}->{"factor"}) {
          $basefactor = $all_units->{$form->{"selected_unit_$i"}}->{"factor"} /
            $all_units->{$form->{"unit_old_$i"}}->{"factor"};
        }
        $form->{"sellprice_$i"} *= $basefactor;
        $form->{"unit_old_$i"} = $form->{"selected_unit_$i"};
      }
    }
    ($dec) = ($form->{"sellprice_$i"} =~ /\.(\d+)/);
    $dec           = length $dec;
    $decimalplaces = ($dec > 2) ? $dec : 2;

    $discount =
      $form->round_amount(
                        $form->{"sellprice_$i"} * $form->{"discount_$i"} / 100,
                        $decimalplaces);

    $linetotal =
      $form->round_amount($form->{"sellprice_$i"} - $discount, $decimalplaces);
    $linetotal = $form->round_amount($linetotal * $form->{"qty_$i"}, 2);

    # convert " to &quot;
    map { $form->{"${_}_$i"} =~ s/\"/&quot;/g }
      qw(partnumber description unit unit_old);

########################################
    # Eintrag fuer Version 2.2.0 geaendert #
    # neue Optik im Rechnungsformular      #
########################################
    $column_data{runningnumber} =
      qq|<td><input name="runningnumber_$i" size=5 value=$i></td>|;    # HuT
############## ENDE Neueintrag ##################

    $column_data{partnumber} =
      qq|<td><input name="partnumber_$i" size=12 value="$form->{"partnumber_$i"}"></td>|;

    if (($rows = $form->numtextrows($form->{"description_$i"}, 30, 6)) > 1) {
      $column_data{description} =
        qq|<td><textarea name="description_$i" rows=$rows cols=30 wrap=soft>| . H($form->{"description_$i"}) . qq|</textarea><button type="button" onclick="set_longdescription_window('longdescription_$i')">| . $locale->text('L') . qq|</button></td>|;
    } else {
      $column_data{description} =
        qq|<td><input name="description_$i" size=30 value="| . $form->quote($form->{"description_$i"}) . qq|"><button type="button" onclick="set_longdescription_window('longdescription_$i')">| . $locale->text('L') . qq|</button></td>|;
    }

    (my $qty_dec) = ($form->{"qty_$i"} =~ /\.(\d+)/);
    $qty_dec = length $qty_dec;

    $column_data{qty} =
        qq|<td align=right><input name="qty_$i" size=5 value=|
      . $form->format_amount(\%myconfig, $form->{"qty_$i"}, $qty_dec) .qq|>|;
    if ($form->{"formel_$i"}) {
    $column_data{qty} .= qq|<button type="button" onclick="calculate_qty_selection_window('qty_$i','alu_$i', 'formel_$i', $i)">| . $locale->text('*/') . qq|</button>
          <input type=hidden name="formel_$i" value="$form->{"formel_$i"}"><input type=hidden name="alu_$i" value="$form->{"alu_$i"}"></td>|;
    }
    $column_data{ship} =
        qq|<td align=right><input name="ship_$i" size=5 value=|
      . $form->format_amount(\%myconfig, $form->{"ship_$i"})
      . qq|></td>|;

    my $is_part = $form->{"inventory_accno_$i"};
    my $is_assigned = $form->{"id_$i"};
    my $this_unit = $form->{"unit_$i"};
    if ($form->{"selected_unit_$i"} && $this_unit &&
        $all_units->{$form->{"selected_unit_$i"}} && $all_units->{$this_unit} &&
        ($all_units->{$form->{"selected_unit_$i"}}->{"base_unit"} eq $all_units->{$this_unit}->{"base_unit"})) {
      $this_unit = $form->{"selected_unit_$i"};
    } elsif (!$is_assigned ||
             ($is_part && !$this_unit && ($all_units->{$this_unit} && ($all_units->{$this_unit}->{"base_unit"} eq $all_units->{"kg"}->{"base_unit"})))) {
      $this_unit = "kg";
    }

    $column_data{"unit"} = "<td>" .
      ($qty_readonly ? "&nbsp;" :
       AM->unit_select_html($is_part ? $dimension_units :
                            $is_assigned ? $service_units : $all_units,
                            "unit_$i", $this_unit,
                            $is_assigned ? $form->{"unit_$i"} : undef))
      . "</td>";

    # build in drop down list for pricesgroups
    if ($form->{"prices_$i"}) {
      if  ($form->{"new_pricegroup_$i"} != $form->{"old_pricegroup_$i"}) {
        $price_tmp = $form->format_amount(\%myconfig, $form->{"price_new_$i"}, $decimalplaces);
      } else {
        $price_tmp = $form->format_amount(\%myconfig, $form->{"sellprice_$i"}, $decimalplaces);
      }

      $column_data{sellprice_pg} =
        qq|<td align=right><select name="sellprice_pg_$i">$form->{"prices_$i"}</select></td>|;
      $column_data{sellprice} =
        qq|<td><input name="sellprice_$i" size=10 value=$price_tmp></td>|;
    } else {

      # for last row and report
      # set pricegroup drop down list from report menu
      if ($form->{"sellprice_$i"} != 0) {
        $prices =
          qq|<option value="$form->{"sellprice_$i"}--$form->{"pricegroup_id_$i"}" selected>$form->{"pricegroup_$i"}</option>\n|;

        $form->{"pricegroup_old_$i"} = $form->{"pricegroup_id_$i"};

        $column_data{sellprice_pg} =
          qq|<td align=right><select name="sellprice_pg_$i">$prices</select></td>|;

      } else {

        # for last row
        $column_data{sellprice_pg} = qq|<td align=right>&nbsp;</td>|;
      }

      $column_data{sellprice} =
        qq|<td><input name="sellprice_$i" size=10 value=|
        . $form->format_amount(\%myconfig, $form->{"sellprice_$i"},
                               $decimalplaces)
        . qq|></td>|;
    }
    $column_data{discount} =
        qq|<td align=right><input name="discount_$i" size=3 value=|
      . $form->format_amount(\%myconfig, $form->{"discount_$i"})
      . qq|></td>|;
    $column_data{linetotal} =
        qq|<td align=right>|
      . $form->format_amount(\%myconfig, $linetotal, 2)
      . qq|</td>|;
    $column_data{bin} = qq|<td>$form->{"bin_$i"}</td>|;

########################################
    # Eintrag fuer Version 2.2.0 geaendert #
    # neue Optik im Rechnungsformular      #
########################################
    #     if ($lizenzen &&  $form->{type} eq "invoice" &&  $form->{vc} eq "customer") {
    #     $column_data{license} = qq|<td><select name="licensenumber_$i">$form->{"lizenzen_$i"}></select></td>|;
    #     }
    #
    #     if ($form->{type} !~ /_quotation/) {
    #     $column_data{serialnr} = qq|<td><input name="serialnumber_$i" size=10 value="$form->{"serialnumber_$i"}"></td>|;
    #     }
    #
    #     $column_data{projectnr} = qq|<td><input name="projectnumber_$i" size=10 value="$form->{"projectnumber_$i"}"></td>|;
############## ENDE Neueintrag ##################
    my $j = $i % 2;
    print qq|

        <tr valign=top class=listrow$j>|;

    map { print "\n$column_data{$_}" } @column_index;

    print qq|
        </tr>

<input type=hidden name="orderitems_id_$i" value=$form->{"orderitems_id_$i"}>
<input type=hidden name="bo_$i" value=$form->{"bo_$i"}>

<input type=hidden name="pricegroup_old_$i" value=$form->{"pricegroup_old_$i"}>
<input type=hidden name="price_old_$i" value=$form->{"price_old_$i"}>
<input type=hidden name="unit_old_$i" value="| . $form->quote($form->{"selected_unit_$i"}) . qq|">
<input type=hidden name="price_new_$i" value=|
      . $form->format_amount(\%myconfig, $form->{"price_new_$i"}) . qq|>

<input type=hidden name="id_$i" value=$form->{"id_$i"}>
<input type=hidden name="inventory_accno_$i" value=$form->{"inventory_accno_$i"}>
<input type=hidden name="bin_$i" value="$form->{"bin_$i"}">
<input type=hidden name="partsgroup_$i" value="$form->{"partsgroup_$i"}">
<input type=hidden name="partnotes_$i" value="| . $form->quote($form->{"partnotes_$i"}) . qq|">
<input type=hidden name="income_accno_$i" value=$form->{"income_accno_$i"}>
<input type=hidden name="expense_accno_$i" value=$form->{"expense_accno_$i"}>
<input type=hidden name="listprice_$i" value="$form->{"listprice_$i"}">
<input type=hidden name="assembly_$i" value="$form->{"assembly_$i"}">
<input type=hidden name="taxaccounts_$i" value="$form->{"taxaccounts_$i"}">
<input type=hidden name="ordnumber_$i" value="$form->{"ordnumber_$i"}">
<input type=hidden name="transdate_$i" value="$form->{"transdate_$i"}">
<input type=hidden name="cusordnumber_$i" value="$form->{"cusordnumber_$i"}">
<input type=hidden name="longdescription_$i" value="| . $form->quote($form->{"longdescription_$i"}) . qq|">
<input type=hidden name="basefactor_$i" value="$form->{"basefactor_$i"}">

|;

########################################
    # Eintrag fuer Version 2.2.0 geaendert #
    # neue Optik im Rechnungsformular      #
########################################

    my $row_style_attr =
      'style="display:none;"' if (!$form->{"show_details"});

    # print second row
    print qq|
        <tr  class=listrow$j $row_style_attr>
	  <td colspan=$colspan>
|;
    if ($lizenzen && $form->{type} eq "invoice" && $form->{vc} eq "customer") {
      my $selected = $form->{"licensenumber_$i"};
      my $lizenzen_quoted;
      $form->{"lizenzen_$i"} =~ s/ selected//g;
      $form->{"lizenzen_$i"} =~
        s/value="${selected}"\>/value="${selected}" selected\>/;
      $lizenzen_quoted = $form->{"lizenzen_$i"};
      $lizenzen_quoted =~ s/\"/&quot;/g;
      print qq|
	<b>Lizenz\#</b>&nbsp;<select name="licensenumber_$i" size=1>
	$form->{"lizenzen_$i"}
        </select>
	<input type=hidden name="lizenzen_$i" value="${lizenzen_quoted}">
|;
    }
    if ($form->{type} !~ /_quotation/) {
      print qq|
          <b>$serialnumber</b>&nbsp;<input name="serialnumber_$i" size=15 value="$form->{"serialnumber_$i"}">|;
    }

    print qq|<b>$projectnumber</b>&nbsp;| .
      NTI($cgi->popup_menu('-name' => "project_id_$i",
                           '-values' => \@projectnumber_values,
                           '-labels' => \%projectnumber_labels,
                           '-default' => $form->{"project_id_$i"}));

    if ($form->{type} eq 'invoice' or $form->{type} =~ /order/) {
      my $reqdate_term =
        ($form->{type} eq 'invoice')
        ? 'deliverydate'
        : 'reqdate';    # invoice uses a different term for the same thing.
      print qq|
        <b>${$reqdate_term}</b>&nbsp;<input name="${reqdate_term}_$i" size=11 value="$form->{"${reqdate_term}_$i"}">
|;
    }
    my $subtotalchecked = ($form->{"subtotal_$i"}) ? "checked" : "";
    print qq|
          <b>|.$locale->text('Subtotal').qq|</b>&nbsp;<input type="checkbox" name="subtotal_$i" value="1" "$subtotalchecked">
	  </td>
	</tr>

|;

############## ENDE Neueintrag ##################

    map { $form->{"${_}_base"} += $linetotal }
      (split(/ /, $form->{"taxaccounts_$i"}));

    $form->{invsubtotal} += $linetotal;
  }

  print qq|
      </table>
    </td>
  </tr>
|;

  $lxdebug->leave_sub();
}

##################################################
# build html-code for pricegroups in variable $form->{prices_$j}

sub set_pricegroup {
  $lxdebug->enter_sub();
  my $rowcount = shift;
  for $j (1 .. $rowcount) {
    my $pricegroup_old = $form->{"pricegroup_old_$i"};
    if ($form->{PRICES}{$j}) {
      $len    = 0;
      $prices = '<option value="--">' . $locale->text("none (pricegroup)") . '</option>';
      $price  = 0;
      foreach $item (@{ $form->{PRICES}{$j} }) {

        #$price = $form->round_amount($myconfig,  $item->{price}, 5);
        #$price = $form->format_amount($myconfig, $item->{price}, 2);
        $price         = $item->{price};
        $pricegroup_id = $item->{pricegroup_id};
        $pricegroup    = $item->{pricegroup};

        # build drop down list for pricegroups
        $prices .=
          qq|<option value="$price--$pricegroup_id"$item->{selected}>$pricegroup</option>\n|;

        $len += 1;

        #        map {
        #               $form->{"${_}_$j"} =
        #               $form->format_amount(\%myconfig, $form->{"${_}_$j"})
        #              } qw(sellprice price_new price_old);

        # set new selectedpricegroup_id and prices for "Preis"
        if ($item->{selected} && ($pricegroup_id != 0)) {
          $form->{"pricegroup_old_$j"} = $pricegroup_id;
          $form->{"price_new_$j"}      = $price;
          $form->{"sellprice_$j"}      = $price;
        }
        if ($pricegroup_id == 0) {
          $form->{"price_new_$j"} = $form->{"sellprice_$j"};
        }
      }
      $form->{"prices_$j"} = $prices;
    }
  }
  $lxdebug->leave_sub();
}

sub select_item {
  $lxdebug->enter_sub();
  @column_index = qw(ndx partnumber description onhand unit sellprice);

  $column_data{ndx}        = qq|<th>&nbsp;</th>|;
  $column_data{partnumber} =
    qq|<th class=listheading>| . $locale->text('Number') . qq|</th>|;
  $column_data{description} =
    qq|<th class=listheading>| . $locale->text('Part Description') . qq|</th>|;
  $column_data{sellprice} =
    qq|<th class=listheading>| . $locale->text('Price') . qq|</th>|;
  $column_data{onhand} =
    qq|<th class=listheading>| . $locale->text('Qty') . qq|</th>|;
  $column_data{unit} =
    qq|<th class=listheading>| . $locale->text('Unit') . qq|</th>|;
  # list items with radio button on a form
  $form->header;

  $title   = $locale->text('Select from one of the items below');
  $colspan = $#column_index + 1;

  print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <th class=listtop colspan=$colspan>$title</th>
  </tr>
  <tr height="5"></tr>
  <tr class=listheading>|;

  map { print "\n$column_data{$_}" } @column_index;

  print qq|</tr>|;

  my $i = 0;
  foreach $ref (@{ $form->{item_list} }) {
    $checked = ($i++) ? "" : "checked";

    if ($lizenzen) {
      if ($ref->{inventory_accno} > 0) {
        $ref->{"lizenzen"} = qq|<option></option>|;
        foreach $item (@{ $form->{LIZENZEN}{ $ref->{"id"} } }) {
          $ref->{"lizenzen"} .=
            qq|<option value=\"$item->{"id"}\">$item->{"licensenumber"}</option>|;
        }
        $ref->{"lizenzen"} .= qq|<option value=-1>Neue Lizenz</option>|;
        $ref->{"lizenzen"} =~ s/\"/&quot;/g;
      }
    }

    map { $ref->{$_} =~ s/\"/&quot;/g } qw(partnumber description unit);

    #sk tradediscount
    $ref->{sellprice} =
      $form->round_amount($ref->{sellprice} * (1 - $form->{tradediscount}), 2);
    $column_data{ndx} =
      qq|<td><input name=ndx class=radio type=radio value=$i $checked></td>|;
    $column_data{partnumber} =
      qq|<td><input name="new_partnumber_$i" type=hidden value="$ref->{partnumber}">$ref->{partnumber}</td>|;
    $column_data{description} =
      qq|<td><input name="new_description_$i" type=hidden value="$ref->{description}">$ref->{description}</td>|;
    $column_data{sellprice} =
      qq|<td align=right><input name="new_sellprice_$i" type=hidden value=$ref->{sellprice}>|
      . $form->format_amount(\%myconfig, $ref->{sellprice}, 2, "&nbsp;")
      . qq|</td>|;
    $column_data{onhand} =
      qq|<td align=right><input name="new_onhand_$i" type=hidden value=$ref->{onhand}>|
      . $form->format_amount(\%myconfig, $ref->{onhand}, '', "&nbsp;")
      . qq|</td>|;
    $column_data{unit} =
      qq|<td>$ref->{unit}</td>|;
    $j++;
    $j %= 2;
    print qq|
<tr class=listrow$j>|;

    map { print "\n$column_data{$_}" } @column_index;

    print qq|
</tr>

<input name="new_bin_$i" type=hidden value="$ref->{bin}">
<input name="new_listprice_$i" type=hidden value=$ref->{listprice}>
<input name="new_inventory_accno_$i" type=hidden value=$ref->{inventory_accno}>
<input name="new_income_accno_$i" type=hidden value=$ref->{income_accno}>
<input name="new_expense_accno_$i" type=hidden value=$ref->{expense_accno}>
<input name="new_unit_$i" type=hidden value="$ref->{unit}">
<input name="new_weight_$i" type=hidden value="$ref->{weight}">
<input name="new_assembly_$i" type=hidden value="$ref->{assembly}">
<input name="new_taxaccounts_$i" type=hidden value="$ref->{taxaccounts}">
<input name="new_partsgroup_$i" type=hidden value="$ref->{partsgroup}">
<input name="new_formel_$i" type=hidden value="$ref->{formel}">
<input name="new_longdescription_$i" type=hidden value="| . Q($ref->{longdescription}) . qq|">
<input name="new_not_discountable_$i" type=hidden value="$ref->{not_discountable}">
<input name="new_part_payment_id_$i" type=hidden value="$ref->{part_payment_id}">
<input name="new_partnotes_$i" type="hidden" value="| . Q($ref->{"partnotes"}) . qq|">

<input name="new_id_$i" type=hidden value=$ref->{id}>

|;
    if ($lizenzen) {
      print qq|
<input name="new_lizenzen_$i" type=hidden value="$ref->{lizenzen}">
|;
    }

  }

  print qq|
<tr><td colspan=8><hr size=3 noshade></td></tr>
</table>

<input name=lastndx type=hidden value=$i>

|;

  # delete action variable
  map { delete $form->{$_} } qw(action item_list header);

  # save all other form variables
  foreach $key (keys %${form}) {
    $form->{$key} =~ s/\"/&quot;/g;
    print qq|<input name=$key type=hidden value="$form->{$key}">\n|;
  }

  print qq|
<input type=hidden name=nextsub value=item_selected>

<br>
<input class=submit type=submit name=action value="|
    . $locale->text('Continue') . qq|">
</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub item_selected {
  $lxdebug->enter_sub();

  # replace the last row with the checked row
  $i = $form->{rowcount};
  $i = $form->{assembly_rows} if ($form->{item} eq 'assembly');

  # index for new item
  $j = $form->{ndx};

  #sk
  #($form->{"sellprice_$i"},$form->{"$pricegroup_old_$i"}) = split /--/, $form->{"sellprice_$i"};
  #$form->{"sellprice_$i"} = $form->{"sellprice_$i"};

  # if there was a price entered, override it
  $sellprice = $form->parse_amount(\%myconfig, $form->{"sellprice_$i"});

  map { $form->{"${_}_$i"} = $form->{"new_${_}_$j"} }
    qw(id partnumber description sellprice listprice inventory_accno
       income_accno expense_accno bin unit weight assembly taxaccounts
       partsgroup formel longdescription not_discountable partnotes);
  if ($form->{"part_payment_id_$i"} ne "") {
    $form->{payment_id} = $form->{"part_payment_id_$i"};
  }

  if ($lizenzen) {
    map { $form->{"${_}_$i"} = $form->{"new_${_}_$j"} } qw(lizenzen);
  }

  ($dec) = ($form->{"sellprice_$i"} =~ /\.(\d+)/);
  $dec           = length $dec;
  $decimalplaces = ($dec > 2) ? $dec : 2;

  if ($sellprice) {
    $form->{"sellprice_$i"} = $sellprice;
  } else {

    # if there is an exchange rate adjust sellprice
    if (($form->{exchangerate} * 1) != 0) {
      $form->{"sellprice_$i"} /= $form->{exchangerate};
      $form->{"sellprice_$i"} =
        $form->round_amount($form->{"sellprice_$i"}, $decimalplaces);
    }
  }

  map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) }
    qw(sellprice listprice weight);

  $form->{sellprice} += ($form->{"sellprice_$i"} * $form->{"qty_$i"});
  $form->{weight}    += ($form->{"weight_$i"} * $form->{"qty_$i"});
  
  if ($form->{"not_discountable_$i"}) {
    $form->{"discount_$i"} = 0;
  }

  $amount =
    $form->{"sellprice_$i"} * (1 - $form->{"discount_$i"} / 100) *
    $form->{"qty_$i"};
  map { $form->{"${_}_base"} += $amount }
    (split / /, $form->{"taxaccounts_$i"});
  map { $amount += ($form->{"${_}_base"} * $form->{"${_}_rate"}) } split / /,
    $form->{"taxaccounts_$i"}
    if !$form->{taxincluded};

  $form->{creditremaining} -= $amount;

  $form->{"runningnumber_$i"} = $i;

  # delete all the new_ variables
  for $i (1 .. $form->{lastndx}) {
    map { delete $form->{"new_${_}_$i"} }
      qw(partnumber description sellprice bin listprice inventory_accno income_accno expense_accno unit assembly taxaccounts id);
  }

  map { delete $form->{$_} } qw(ndx lastndx nextsub);

  # format amounts
  map {
    $form->{"${_}_$i"} =
      $form->format_amount(\%myconfig, $form->{"${_}_$i"}, $decimalplaces)
  } qw(sellprice listprice) if $form->{item} ne 'assembly';

  # get pricegroups for parts
  IS->get_pricegroups_for_parts(\%myconfig, \%$form);

  # build up html code for prices_$i
  set_pricegroup($form->{rowcount});

  &display_form;

  $lxdebug->leave_sub();
}

sub new_item {
  $lxdebug->enter_sub();

  # change callback
  $form->{old_callback} = $form->escape($form->{callback}, 1);
  $form->{callback} = $form->escape("$form->{script}?action=display_form", 1);

  # delete action
  delete $form->{action};

  # save all other form variables in a previousform variable
  foreach $key (keys %$form) {

    # escape ampersands
    $form->{$key} =~ s/&/%26/g;
    $previousform .= qq|$key=$form->{$key}&|;
  }
  chop $previousform;
  $previousform = $form->escape($previousform, 1);

  $i = $form->{rowcount};
  map { $form->{"${_}_$i"} =~ s/\"/&quot;/g } qw(partnumber description);

  $form->header;

  print qq|
<body>

<h4 class=error>| . $locale->text('Item not on file!') . qq|

<p>
| . $locale->text('What type of item is this?') . qq|</h4>

<form method=post action=ic.pl>

<p>

  <input class=radio type=radio name=item value=part checked>&nbsp;|
    . $locale->text('Part') . qq|<br>
  <input class=radio type=radio name=item value=service>&nbsp;|
    . $locale->text('Service')

    . qq|
<input type=hidden name=previousform value="$previousform">
<input type=hidden name=partnumber value="$form->{"partnumber_$i"}">
<input type=hidden name=description value="$form->{"description_$i"}">
<input type=hidden name=rowcount value=$form->{rowcount}>
<input type=hidden name=taxaccount2 value=$form->{taxaccounts}>
<input type=hidden name=vc value=$form->{vc}>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input type=hidden name=nextsub value=add>

<p>
<input class=submit type=submit name=action value="|
    . $locale->text('Continue') . qq|">
</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub display_form {
  $lxdebug->enter_sub();

  relink_accounts();

  my $new_rowcount = $form->{"rowcount"} * 1 + 1;
  $form->{"project_id_${new_rowcount}"} = $form->{"globalproject_id"};

  $form->language_payment(\%myconfig);

  # if we have a display_form
  if ($form->{display_form}) {
    &{"$form->{display_form}"};
    exit;
  }

  Common::webdav_folder($form) if ($webdav);

  #   if (   $form->{print_and_post}
  #       && $form->{second_run}
  #       && ($form->{action} eq "display_form")) {
  #     for (keys %$form) { $old_form->{$_} = $form->{$_} }
  #     $old_form->{rowcount}++;
  #
  #     #$form->{rowcount}--;
  #     #$form->{rowcount}--;
  #
  #     $form->{print_and_post} = 0;
  #
  #     &print_form($old_form);
  #     exit;
  #   }
  #
  #   $form->{action}   = "";
  #   $form->{resubmit} = 0;
  #
  #   if ($form->{print_and_post} && !$form->{second_run}) {
  #     $form->{second_run} = 1;
  #     $form->{action}     = "display_form";
  #     $form->{rowcount}--;
  #     my $rowcount = $form->{rowcount};
  #
  #     # get pricegroups for parts
  #     IS->get_pricegroups_for_parts(\%myconfig, \%$form);
  #
  #     # build up html code for prices_$i
  #     set_pricegroup($rowcount);
  #
  #     $form->{resubmit} = 1;
  #
  #   }
  &form_header;

  $numrows    = ++$form->{rowcount};
  $subroutine = "display_row";

  if ($form->{item} eq 'part') {

    #set preisgruppenanzahl
    $numrows    = $form->{price_rows};
    $subroutine = "price_row";

    &{$subroutine}($numrows);

    $numrows    = ++$form->{makemodel_rows};
    $subroutine = "makemodel_row";
  }
  if ($form->{item} eq 'assembly') {
    $numrows    = $form->{price_rows};
    $subroutine = "price_row";

    &{$subroutine}($numrows);

    $numrows    = ++$form->{makemodel_rows};
    $subroutine = "makemodel_row";

    # create makemodel rows
    &{$subroutine}($numrows);

    $numrows    = ++$form->{assembly_rows};
    $subroutine = "assembly_row";
  }
  if ($form->{item} eq 'service') {
    $numrows    = $form->{price_rows};
    $subroutine = "price_row";

    &{$subroutine}($numrows);

    $numrows = 0;
  }

  # create rows
  &{$subroutine}($numrows) if $numrows;

  &form_footer;

  $lxdebug->leave_sub();
}

sub check_form {
  $lxdebug->enter_sub();
  my @a     = ();
  my $count = 0;
  my @flds  = (
    qw(id partnumber description qty ship sellprice unit discount inventory_accno income_accno expense_accno listprice taxaccounts bin assembly weight projectnumber project_id oldprojectnumber runningnumber serialnumber partsgroup payment_id not_discountable shop ve gv buchungsgruppen_id language_values sellprice_pg pricegroup_old price_old price_new unit_old ordnumber transdate longdescription basefactor)
  );


  # remove any makes or model rows
  if ($form->{item} eq 'part') {
    map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) }
      qw(listprice sellprice lastcost weight rop);

    @flds = (make, model);
    for my $i (1 .. ($form->{makemodel_rows})) {
      if (($form->{"make_$i"} ne "") || ($form->{"model_$i"} ne "")) {
        push @a, {};
        my $j = $#a;

        map { $a[$j]->{$_} = $form->{"${_}_$i"} } @flds;
        $count++;
      }
    }

    $form->redo_rows(\@flds, \@a, $count, $form->{makemodel_rows});
    $form->{makemodel_rows} = $count;

  } elsif ($form->{item} eq 'assembly') {

    $form->{sellprice} = 0;
    $form->{weight}    = 0;
    map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) }
      qw(listprice rop stock);

    @flds =
      qw(id qty unit bom partnumber description sellprice weight runningnumber partsgroup);

    for my $i (1 .. ($form->{assembly_rows} - 1)) {
      if ($form->{"qty_$i"}) {
        push @a, {};
        my $j = $#a;

        $form->{"qty_$i"} = $form->parse_amount(\%myconfig, $form->{"qty_$i"});

        map { $a[$j]->{$_} = $form->{"${_}_$i"} } @flds;

        #($form->{"sellprice_$i"},$form->{"$pricegroup_old_$i"}) = split /--/, $form->{"sellprice_$i"};

        $form->{sellprice} += ($form->{"qty_$i"} * $form->{"sellprice_$i"});
        $form->{weight}    += ($form->{"qty_$i"} * $form->{"weight_$i"});
        $count++;
      }
    }

    $form->{sellprice} = $form->round_amount($form->{sellprice}, 2);

    $form->redo_rows(\@flds, \@a, $count, $form->{assembly_rows});
    $form->{assembly_rows} = $count;

    $count = 0;
    @flds  = qw(make model);
    @a     = ();

    for my $i (1 .. ($form->{makemodel_rows})) {
      if (($form->{"make_$i"} ne "") || ($form->{"model_$i"} ne "")) {
        push @a, {};
        my $j = $#a;

        map { $a[$j]->{$_} = $form->{"${_}_$i"} } @flds;
        $count++;
      }
    }

    $form->redo_rows(\@flds, \@a, $count, $form->{makemodel_rows});
    $form->{makemodel_rows} = $count;

  } else {

    # this section applies to invoices and orders
    # remove any empty numbers
    if ($form->{rowcount}) {
      for my $i (1 .. $form->{rowcount} - 1) {
        if ($form->{"partnumber_$i"}) {
          push @a, {};
          my $j = $#a;

          map { $a[$j]->{$_} = $form->{"${_}_$i"} } @flds;
          $count++;
          if ($lizenzen) {
            if ($form->{"licensenumber_$i"} == -1) {
              &new_license($i);
              exit;
            }
          }
        }
      }

      $form->redo_rows(\@flds, \@a, $count, $form->{rowcount});
      $form->{rowcount} = $count;

      $form->{creditremaining} -= &invoicetotal;

    }
  }

  #sk
  # if pricegroups
  if (   $form->{type} =~ (/sales_quotation/)
      or (($form->{level} =~ /Sales/) and ($form->{type} =~ /invoice/))
      or (($form->{level} eq undef) and ($form->{type} =~ /invoice/))
      or ($form->{type} =~ /sales_order/)) {

    # get pricegroups for parts
    IS->get_pricegroups_for_parts(\%myconfig, \%$form);

    # build up html code for prices_$i
    set_pricegroup($form->{rowcount});

  }

  &display_form;

  $lxdebug->leave_sub();
}

sub invoicetotal {
  $lxdebug->enter_sub();

  $form->{oldinvtotal} = 0;

  # add all parts and deduct paid
  map { $form->{"${_}_base"} = 0 } split / /, $form->{taxaccounts};

  my ($amount, $sellprice, $discount, $qty);

  for my $i (1 .. $form->{rowcount}) {
    $sellprice = $form->parse_amount(\%myconfig, $form->{"sellprice_$i"});
    $discount  = $form->parse_amount(\%myconfig, $form->{"discount_$i"});
    $qty       = $form->parse_amount(\%myconfig, $form->{"qty_$i"});

    #($form->{"sellprice_$i"}, $form->{"$pricegroup_old_$i"}) = split /--/, $form->{"sellprice_$i"};

    $amount = $sellprice * (1 - $discount / 100) * $qty;
    map { $form->{"${_}_base"} += $amount }
      (split (/ /, $form->{"taxaccounts_$i"}));
    $form->{oldinvtotal} += $amount;
  }

  map { $form->{oldinvtotal} += ($form->{"${_}_base"} * $form->{"${_}_rate"}) }
    split(/ /, $form->{taxaccounts})
    if !$form->{taxincluded};

  $form->{oldtotalpaid} = 0;
  for $i (1 .. $form->{paidaccounts}) {
    $form->{oldtotalpaid} += $form->{"paid_$i"};
  }

  $lxdebug->leave_sub();

  # return total
  return ($form->{oldinvtotal} - $form->{oldtotalpaid});
}

sub validate_items {
  $lxdebug->enter_sub();

  # check if items are valid
  if ($form->{rowcount} == 1) {
    &update;
    exit;
  }

  for $i (1 .. $form->{rowcount} - 1) {
    $form->isblank("partnumber_$i",
                   $locale->text('Number missing in Row') . " $i");
  }

  $lxdebug->leave_sub();
}

sub order {
  $lxdebug->enter_sub();
  if ($form->{second_run}) {
    $form->{print_and_post} = 0;
  }
  $form->{ordnumber} = $form->{invnumber};

  map { delete $form->{$_} } qw(id printed emailed queued);
  if ($form->{script} eq 'ir.pl' || $form->{type} eq 'request_quotation') {
    $form->{title} = $locale->text('Add Purchase Order');
    $form->{vc}    = 'vendor';
    $form->{type}  = 'purchase_order';
    $buysell       = 'sell';
  }
  if ($form->{script} eq 'is.pl' || $form->{type} eq 'sales_quotation') {
    $form->{title} = $locale->text('Add Sales Order');
    $form->{vc}    = 'customer';
    $form->{type}  = 'sales_order';
    $buysell       = 'buy';
  }
  $form->{script} = 'oe.pl';

  $form->{shipto} = 1;

  $form->{rowcount}--;

  $form->{cp_id} *= 1;

  require "$form->{path}/$form->{script}";
  my $script = $form->{"script"};
  $script =~ s|.*/||;
  $script =~ s|.pl$||;
  $locale = new Locale($language, $script);

  map { $form->{"select$_"} = "" } ($form->{vc}, currency);

  $currency = $form->{currency};

  &order_links;

  $form->{currency}     = $currency;
  $form->{exchangerate} = "";
  $form->{forex}        = "";
  $form->{exchangerate} = $exchangerate
    if (
        $form->{forex} = (
                  $exchangerate =
                    $form->check_exchangerate(
                    \%myconfig, $form->{currency}, $form->{transdate}, $buysell
                    )));

  for $i (1 .. $form->{rowcount}) {
    map({ $form->{"${_}_${i}"} = $form->parse_amount(\%myconfig,
                                                     $form->{"${_}_${i}"})
            if ($form->{"${_}_${i}"}) }
        qw(ship qty sellprice listprice basefactor));
  }

  &prepare_order;
  &display_form;

  $lxdebug->leave_sub();
}

sub quotation {
  $lxdebug->enter_sub();
  if ($form->{second_run}) {
    $form->{print_and_post} = 0;
  }
  map { delete $form->{$_} } qw(id printed emailed queued);

  if ($form->{script} eq 'ir.pl' || $form->{type} eq 'purchase_order') {
    $form->{title} = $locale->text('Add Request for Quotation');
    $form->{vc}    = 'vendor';
    $form->{type}  = 'request_quotation';
    $buysell       = 'sell';
  }
  if ($form->{script} eq 'is.pl' || $form->{type} eq 'sales_order') {
    $form->{title} = $locale->text('Add Quotation');
    $form->{vc}    = 'customer';
    $form->{type}  = 'sales_quotation';
    $buysell       = 'buy';
  }

  $form->{cp_id} *= 1;

  $form->{script} = 'oe.pl';

  $form->{shipto} = 1;

  $form->{rowcount}--;

  require "$form->{path}/$form->{script}";

  map { $form->{"select$_"} = "" } ($form->{vc}, currency);

  $currency = $form->{currency};

  &order_links;

  $form->{currency}     = $currency;
  $form->{exchangerate} = "";
  $form->{forex}        = "";
  $form->{exchangerate} = $exchangerate
    if (
        $form->{forex} = (
                  $exchangerate =
                    $form->check_exchangerate(
                    \%myconfig, $form->{currency}, $form->{transdate}, $buysell
                    )));

  for $i (1 .. $form->{rowcount}) {
    map({ $form->{"${_}_${i}"} = $form->parse_amount(\%myconfig,
                                                     $form->{"${_}_${i}"})
            if ($form->{"${_}_${i}"}) }
        qw(ship qty sellprice listprice basefactor));
  }

  &prepare_order;
  &display_form;

  $lxdebug->leave_sub();
}

sub request_for_quotation {
  quotation();
}

sub e_mail {
  $lxdebug->enter_sub();
  if ($form->{second_run}) {
    $form->{print_and_post} = 0;
    $form->{resubmit}       = 0;
  }
  if ($myconfig{role} eq 'admin') {
    $bcc = qq|
    <tr>
      <th align="right" nowrap="true">| . $locale->text('Bcc') . qq|</th>
      <td><input name="bcc" size="30" value="| . Q($form->{bcc}) . qq|"></td>
    </tr>
|;
  }

  if ($form->{formname} =~ /(pick|packing|bin)_list/) {
    $form->{email} = $form->{shiptoemail} if $form->{shiptoemail};
  }

  if ($form->{"cp_id"} && !$form->{"email"}) {
    CT->get_contact(\%myconfig, $form);
    $form->{"email"} = $form->{"cp_email"};
  }

  $name = $form->{ $form->{vc} };
  $name =~ s/--.*//g;
  $title = $locale->text('E-mail') . " $name";

  $form->{oldmedia} = $form->{media};
  $form->{media}    = "email";

  my %formname_translations =
    (
     "bin_list" => $locale->text('Bin List'),
     "credit_note" => $locale->text('Credit Note'),
     "invoice" => $locale->text('Invoice'),
     "packing_list" => $locale->text('Packing List'),
     "pick_list" => $locale->text('Pick List'),
     "proforma" => $locale->text('Proforma Invoice'),
     "purchase_order" => $locale->text('Purchase Order'),
     "request_quotation" => $locale->text('RFQ'),
     "sales_order" => $locale->text('Confirmation'),
     "sales_quotation" => $locale->text('Quotation'),
     "storno_invoice" => $locale->text('Storno Invoice'),
     "storno_packing_list" => $locale->text('Storno Packing List'),
    );

  my $attachment_filename = $formname_translations{$form->{"formname"}};
  my $prefix;

  if (grep({ $form->{"type"} eq $_ } qw(invoice credit_note))) {
    $prefix = "inv";
  } elsif ($form->{"type"} =~ /_quotation$/) {
    $prefix = "quo";
  } else {
    $prefix = "ord";
  }

  if ($attachment_filename && $form->{"${prefix}number"}) {
    $attachment_filename .= "_" . $form->{"${prefix}number"} .
      ($form->{"format"} =~ /pdf/i ? ".pdf" :
       $form->{"format"} =~ /postscript/i ? ".ps" :
       $form->{"format"} =~ /opendocument/i ? ".odt" :
       $form->{"format"} =~ /html/i ? ".html" : "");
    $attachment_filename =~ s/ /_/g;
    my %umlaute =
      (
       "