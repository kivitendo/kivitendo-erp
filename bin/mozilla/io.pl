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

require "bin/mozilla/common.pl";

# any custom scripts for this one
if (-f "bin/mozilla/custom_io.pl") {
  eval { require "bin/mozilla/custom_io.pl"; };
}
if (-f "bin/mozilla/$form->{login}_io.pl") {
  eval { require "bin/mozilla/$form->{login}_io.pl"; };
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
      qq|<th align="left" nowrap width="5" class="listheading">|
    . $locale->text('No.')
    . qq|</th>|;
  $column_data{partnumber} =
      qq|<th align="left" nowrap width="12" class="listheading">|
    . $locale->text('Number')
    . qq|</th>|;
  $column_data{description} =
      qq|<th align="left" nowrap width="30" class="listheading">|
    . $locale->text('Part Description')
    . qq|</th>|;
  if ($form->{"type"} eq "purchase_order") {
    $column_data{ship} =
      qq|<th align="left" nowrap width="5" class="listheading">|
      . $locale->text('Ship rcvd')
      . qq|</th>|;
  } else {
    $column_data{ship} =
      qq|<th align="left" nowrap width="5" class="listheading">|
      . $locale->text('Ship')
      . qq|</th>|;
  }
  $column_data{qty} =
      qq|<th align="left" nowrap width="5" class="listheading">|
    . $locale->text('Qty')
    . qq|</th>|;
  $column_data{unit} =
      qq|<th align="left" nowrap width="5" class="listheading">|
    . $locale->text('Unit')
    . qq|</th>|;
  $column_data{license} =
      qq|<th align="left" nowrap width="10" class="listheading">|
    . $locale->text('License')
    . qq|</th>|;
  $column_data{serialnr} =
      qq|<th align="left" nowrap width="10" class="listheading">|
    . $locale->text('Serial No.')
    . qq|</th>|;
  $column_data{projectnr} =
      qq|<th align="left" nowrap width="10" class="listheading">|
    . $locale->text('Project')
    . qq|</th>|;
  $column_data{sellprice} =
      qq|<th align="left" nowrap width="15" class="listheading">|
    . $locale->text('Price')
    . qq|</th>|;
  $column_data{sellprice_pg} =
      qq|<th align="left" nowrap width="15" class="listheading">|
    . $locale->text('Pricegroup')
    . qq|</th>|;
  $column_data{discount} =
      qq|<th align="left" class="listheading">|
    . $locale->text('Discount')
    . qq|</th>|;
  $column_data{linetotal} =
      qq|<th align="left" nowrap width="10" class="listheading">|
    . $locale->text('Extended')
    . qq|</th>|;
  $column_data{bin} =
      qq|<th align="left" nowrap width="10" class="listheading">|
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
    <td>| . $cgi->hidden("-name" => "show_details", "-value" => $form->{show_details}) . qq|
      <input type="checkbox" id="cb_show_details" onclick="show_form_details($show_details_new);" $show_details_checked>
      <label for="cb_show_details">| . $locale->text("Show details") . qq|</label><br>
      <table width="100%">
	<tr class="listheading">|;

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

  $form->{marge_total} = 0;
  $form->{sellprice_total} = 0;
  $form->{lastcost_total} = 0;
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
    my $real_sellprice = $form->{"sellprice_$i"} - $discount;

    # marge calculations
    my ($marge_font_start, $marge_font_end);

    $form->{"lastcost_$i"} *= 1;

    if ($real_sellprice && ($form->{"qty_$i"} * 1)) {
      $form->{"marge_percent_$i"}     = ($real_sellprice - $form->{"lastcost_$i"}) * 100 / $real_sellprice;
      $myconfig{"marge_percent_warn"} = 15 unless (defined($myconfig{"marge_percent_warn"}));

      if ($form->{"id_$i"} &&
          ($form->{"marge_percent_$i"} < (1 * $myconfig{"marge_percent_warn"}))) {
        $marge_font_start = "<font color=\"#ff0000\">";
        $marge_font_end   = "</font>";
      }

    } else {
      $form->{"marge_percent_$i"} = 0;
    }

    my $marge_adjust_credit_note = $form->{type} eq 'credit_note' ? -1 : 1;
    $form->{"marge_absolut_$i"}  = ($real_sellprice - $form->{"lastcost_$i"}) * $form->{"qty_$i"} * $marge_adjust_credit_note;
    $form->{"marge_total"}      += $form->{"marge_absolut_$i"};
    $form->{"lastcost_total"}   += $form->{"lastcost_$i"} * $form->{"qty_$i"};
    $form->{"sellprice_total"}  += $real_sellprice * $form->{"qty_$i"};

    map { $form->{"${_}_$i"} = $form->format_amount(\%myconfig, $form->{"${_}_$i"}, 2) } qw(marge_absolut marge_percent);

    # convert " to &quot;
    map { $form->{"${_}_$i"} =~ s/\"/&quot;/g }
      qw(partnumber description unit unit_old);

########################################
    # Eintrag fuer Version 2.2.0 geaendert #
    # neue Optik im Rechnungsformular      #
########################################
    $column_data{runningnumber} =
      qq|<td><input name="runningnumber_$i" size="5" value="$i"></td>|;    # HuT
############## ENDE Neueintrag ##################

    $column_data{partnumber} =
      qq|<td><input name="partnumber_$i" size=12 value="$form->{"partnumber_$i"}"></td>|;

    if (($rows = $form->numtextrows($form->{"description_$i"}, 30, 6)) > 1) {
      $column_data{description} =
        qq|<td><textarea name="description_$i" rows="$rows" cols="30" wrap="soft">| . H($form->{"description_$i"}) . qq|</textarea><button type="button" onclick="set_longdescription_window('longdescription_$i')">| . $locale->text('L') . qq|</button></td>|;
    } else {
      $column_data{description} =
        qq|<td><input name="description_$i" size="30" value="| . $form->quote($form->{"description_$i"}) . qq|"><button type="button" onclick="set_longdescription_window('longdescription_$i')">| . $locale->text('L') . qq|</button></td>|;
    }

    (my $qty_dec) = ($form->{"qty_$i"} =~ /\.(\d+)/);
    $qty_dec = length $qty_dec;

    $column_data{qty} =
        qq|<td align="right"><input name="qty_$i" size="5" value="|
      . $form->format_amount(\%myconfig, $form->{"qty_$i"}, $qty_dec) .qq|">|;
    if ($form->{"formel_$i"}) {
    $column_data{qty} .= qq|<button type="button" onclick="calculate_qty_selection_window('qty_$i','alu_$i', 'formel_$i', $i)">| . $locale->text('*/') . qq|</button>| .
          $cgi->hidden("-name" => "formel_$i", "-value" => $form->{"formel_$i"}) . $cgi->hidden("-name" => "alu_$i", "-value" => $form->{"alu_$i"}). qq|</td>|;
    }
    $column_data{ship} =
        qq|<td align="right"><input name="ship_$i" size=5 value="|
      . $form->format_amount(\%myconfig, $form->{"ship_$i"})
      . qq|"></td>|;

    my $is_part     = $form->{"inventory_accno_$i"};
    my $is_assembly = $form->{"assembly_$i"};
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
       AM->unit_select_html($is_part || $is_assembly ? $dimension_units :
                            $is_assigned ? $service_units : $all_units,
                            "unit_$i", $this_unit,
                            $is_assigned ? $form->{"unit_$i"} : undef)
      . "</td>";

    # build in drop down list for pricesgroups
    if ($form->{"prices_$i"}) {
      if  ($form->{"new_pricegroup_$i"} != $form->{"old_pricegroup_$i"}) {
        $price_tmp = $form->format_amount(\%myconfig, $form->{"price_new_$i"}, $decimalplaces);
      } else {
        $price_tmp = $form->format_amount(\%myconfig, $form->{"sellprice_$i"}, $decimalplaces);
      }

      $column_data{sellprice_pg} =
      qq|<td align="right"><select name="sellprice_pg_$i">$form->{"prices_$i"}</select></td>|;
      $column_data{sellprice} =
      qq|<td><input name="sellprice_$i" size="10" value="$price_tmp" onBlur=\"check_right_number_format(this)\"></td>|;
    } else {

      # for last row and report
      # set pricegroup drop down list from report menu
      if ($form->{"sellprice_$i"} != 0) {
        $prices =
          qq|<option value="$form->{"sellprice_$i"}--$form->{"pricegroup_id_$i"}" selected>$form->{"pricegroup_$i"}</option>\n|;

        $form->{"pricegroup_old_$i"} = $form->{"pricegroup_id_$i"};

        $column_data{sellprice_pg} =
          qq|<td align="right"><select name="sellprice_pg_$i">$prices</select></td>|;

      } else {

        # for last row
        $column_data{sellprice_pg} = qq|<td align="right">&nbsp;</td>|;
        }
        
      $column_data{sellprice} =
      qq|<td><input name="sellprice_$i" size="10" onBlur=\"check_right_number_format(this)\" value="|
        . $form->format_amount(\%myconfig, $form->{"sellprice_$i"},
                               $decimalplaces)
        . qq|"></td>|;
    }
    $column_data{discount} =
        qq|<td align="right"><input name="discount_$i" size=3 value="|
      . $form->format_amount(\%myconfig, $form->{"discount_$i"})
      . qq|"></td>|;
    $column_data{linetotal} =
        qq|<td align="right">|
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

        <tr valign="top" class="listrow$j">|;

    map { print "\n$column_data{$_}" } @column_index;

    print("</tr>\n" .
          $cgi->hidden("-name" => "unit_old_$i",
                       "-value" => $form->{"selected_unit_$i"})
          . "\n" .
          $cgi->hidden("-name" => "price_new_$i",
                       "-value" => $form->format_amount(\%myconfig, $form->{"price_new_$i"}))
          . "\n");
    map({ print($cgi->hidden("-name" => $_, "-value" => $form->{$_}) . "\n"); }
        ("orderitems_id_$i", "bo_$i", "pricegroup_old_$i", "price_old_$i",
         "id_$i", "inventory_accno_$i", "bin_$i", "partsgroup_$i", "partnotes_$i",
         "income_accno_$i", "expense_accno_$i", "listprice_$i", "assembly_$i",
         "taxaccounts_$i", "ordnumber_$i", "transdate_$i", "cusordnumber_$i",
         "longdescription_$i", "basefactor_$i", "marge_absolut_$i", "marge_percent_$i", "lastcost_$i"));

########################################
    # Eintrag fuer Version 2.2.0 geaendert #
    # neue Optik im Rechnungsformular      #
########################################

    my $row_style_attr =
      'style="display:none;"' if (!$form->{"show_details"});

    # print second row
    print qq|
        <tr  class="listrow$j" $row_style_attr>
	  <td colspan="$colspan">
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
	<b>Lizenz\#</b>&nbsp;<select name="licensenumber_$i" size="1">
	$form->{"lizenzen_$i"}
        </select>
	<input type="hidden" name="lizenzen_$i" value="${lizenzen_quoted}">
|;
    }
    if ($form->{type} !~ /_quotation/) {
      print qq|
          <b>$serialnumber</b>&nbsp;<input name="serialnumber_$i" size="15" value="$form->{"serialnumber_$i"}">|;
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
        <b>${$reqdate_term}</b>&nbsp;<input name="${reqdate_term}_$i" size="11" onBlur="check_right_date_format(this)" value="$form->{"${reqdate_term}_$i"}">
|;
    }
    my $subtotalchecked = ($form->{"subtotal_$i"}) ? "checked" : "";
    print qq|
          <b>|.$locale->text('Subtotal').qq|</b>&nbsp;<input type="checkbox" name="subtotal_$i" value="1" "$subtotalchecked">
|;

    print qq|
          ${marge_font_start}<b>|.$locale->text('Ertrag').qq|</b>&nbsp;$form->{"marge_absolut_$i"} &nbsp;$form->{"marge_percent_$i"} % ${marge_font_end}
          &nbsp;<b>|.$locale->text('LP').qq|</b>&nbsp;|.$form->format_amount(\%myconfig,$form->{"listprice_$i"},2).qq|
          &nbsp;<b>|.$locale->text('EK').qq|</b>&nbsp;|.$form->format_amount(\%myconfig,$form->{"lastcost_$i"},2).qq|
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

  if (0 != ($form->{sellprice_total} * 1)) {
    $form->{marge_percent} = ($form->{sellprice_total} - $form->{lastcost_total}) / $form->{sellprice_total} * 100;
  }

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
    qq|<th class="listheading">| . $locale->text('Number') . qq|</th>|;
  $column_data{description} =
    qq|<th class="listheading">| . $locale->text('Part Description') . qq|</th>|;
  $column_data{sellprice} =
    qq|<th class="listheading">| . $locale->text('Price') . qq|</th>|;
  $column_data{onhand} =
    qq|<th class="listheading">| . $locale->text('Qty') . qq|</th>|;
  $column_data{unit} =
    qq|<th class="listheading">| . $locale->text('Unit') . qq|</th>|;
  # list items with radio button on a form
  $form->header;

  $title   = $locale->text('Select from one of the items below');
  $colspan = $#column_index + 1;

  print qq|
  <body>

<form method="post" action="$form->{script}">

<table width="100%">
  <tr>
    <th class="listtop" colspan="$colspan">$title</th>
  </tr>
  <tr height="5"></tr>
  <tr class="listheading">|;

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
        $ref->{"lizenzen"} .= qq|<option value="-1">Neue Lizenz</option>|;
        $ref->{"lizenzen"} =~ s/\"/&quot;/g;
      }
    }

    map { $ref->{$_} =~ s/\"/&quot;/g } qw(partnumber description unit);

    #sk tradediscount
    $ref->{sellprice} =
      $form->round_amount($ref->{sellprice} * (1 - $form->{tradediscount}), 2);
    $column_data{ndx} =
      qq|<td><input name="ndx" class="radio" type="radio" value="$i" $checked></td>|;
    $column_data{partnumber} =
      qq|<td><input name="new_partnumber_$i" type="hidden" value="$ref->{partnumber}">$ref->{partnumber}</td>|;
    $column_data{description} =
      qq|<td><input name="new_description_$i" type="hidden" value="$ref->{description}">$ref->{description}</td>|;
    $column_data{sellprice} =
      qq|<td align="right"><input name="new_sellprice_$i" type="hidden" value="$ref->{sellprice}">|
      . $form->format_amount(\%myconfig, $ref->{sellprice}, 2, "&nbsp;")
      . qq|</td>|;
    $column_data{onhand} =
      qq|<td align="right"><input name="new_onhand_$i" type="hidden" value="$ref->{onhand}">|
      . $form->format_amount(\%myconfig, $ref->{onhand}, '', "&nbsp;")
      . qq|</td>|;
    $column_data{unit} =
      qq|<td>$ref->{unit}</td>|;
    $j++;
    $j %= 2;
    print qq|
<tr class=listrow$j>|;

    map { print "\n$column_data{$_}" } @column_index;

    print("</tr>\n");

    my @new_fields =
      qw(bin listprice inventory_accno income_accno expense_accno unit weight
         assembly taxaccounts partsgroup formel longdescription not_discountable
         part_payment_id partnotes id lastcost);
    push(@new_fields, "lizenzen") if ($lizenzen);

    print join "\n", map { $cgi->hidden("-name" => "new_${_}_$i", "-value" => $ref->{$_}) } @new_fields;
    print "\n";
  }

  print qq|
<tr><td colspan="8"><hr size="3" noshade></td></tr>
</table>

<input name="lastndx" type="hidden" value="$i">

|;

  # delete action variable
  map { delete $form->{$_} } qw(action item_list header);

  # save all other form variables
  foreach $key (keys %${form}) {
    $form->{$key} =~ s/\"/&quot;/g;
    print qq|<input name="$key" type="hidden" value="$form->{$key}">\n|;
  }

  print qq|
<input type="hidden" name="nextsub" value="item_selected">

<br>
<input class="submit" type="submit" name="action" value="|
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
       partsgroup formel longdescription not_discountable partnotes lastcost);
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

<h4 class="error">| . $locale->text('Item not on file!') . qq|

<p>
| . $locale->text('What type of item is this?') . qq|</h4>

<form method="post" action="ic.pl">

<p>

  <input class="radio" type="radio" name="item" value="part" checked>&nbsp;|
    . $locale->text('Part') . qq|<br>
  <input class="radio" type="radio" name="item" value="service">&nbsp;|
    . $locale->text('Service');
print $cgi->hidden("-name" => "previousform", "-value" => $previousform);
map({ print($cgi->hidden("-name" => $_, "-value" => $form->{$_})); } 
     qw(rowcount vc login password));
     map({ print($cgi->hidden("-name" => $_, "-value" => $form->{"$__$i"})); }
     ("partnumber", "description"));
print $cgi->hidden("-name" => "taxaccount2", "-value" => $form->{taxaccounts});

print qq|
<input type="hidden" name="nextsub" value="add">

<p>
<input class="submit" type="submit" name="action" value="|
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
    call_sub($form->{"display_form"});
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
    qw(id partnumber description qty ship sellprice unit discount inventory_accno income_accno expense_accno listprice taxaccounts bin assembly weight projectnumber project_id oldprojectnumber runningnumber serialnumber partsgroup payment_id not_discountable shop ve gv buchungsgruppen_id language_values sellprice_pg pricegroup_old price_old price_new unit_old ordnumber transdate longdescription basefactor marge_absolut marge_percent lastcost )
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

  $form->{old_employee_id} = $form->{employee_id};
  $form->{old_salesman_id} = $form->{salesman_id};

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

  require "bin/mozilla/$form->{script}";
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

  require "bin/mozilla/$form->{script}";

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

sub edit_e_mail {
  $lxdebug->enter_sub();
  if ($form->{second_run}) {
    $form->{print_and_post} = 0;
    $form->{resubmit}       = 0;
  }

  $form->{email} = $form->{shiptoemail} if $form->{shiptoemail} && $form->{formname} =~ /(pick|packing|bin)_list/;

  if ($form->{"cp_id"} && !$form->{"email"}) {
    CT->get_contact(\%myconfig, $form);
    $form->{"email"} = $form->{"cp_email"};
  }

  $form->{ $form->{vc} } =~ /--/;
  $title = $locale->text('E-mail') . " $`";

  $form->{oldmedia} = $form->{media};
  $form->{media}    = "email";

  my $attachment_filename = $form->generate_attachment_filename();

  $form->{"fokus"} = $form->{"email"} ? "Form.subject" : "Form.email";
  $form->header;

  my (@dont_hide_key_list, %dont_hide_key, @hidden_keys);
  @dont_hide_key_list = qw(action email cc bcc subject message formname sendmode format header override);
  @dont_hide_key{@dont_hide_key_list} = (1) x @dont_hide_key_list;
  @hidden_keys = grep { !$dont_hide_key{$_} } grep { !ref $form->{$_} } keys %$form;

  print $form->parse_html_template('generic/edit_email', 
                                  { title           => $title,
                                    a_filename      => $attachment_filename,
                                    _print_options_ => print_options({ 'inline' => 1 }),
                                    HIDDEN          => [ map +{ name => $_, value => $form->{$_} }, @hidden_keys ],
                                    SHOW_BCC        => $myconfig{role} eq 'admin' });

  $lxdebug->leave_sub();
}

sub send_email {
  $lxdebug->enter_sub();

  my $callback = $form->{script} . "?action=edit";
  map({ $callback .= "\&${_}=" . E($form->{$_}); }
      qw(login password type id));

  print_form("return");

  $form->{callback} = $callback;
  $form->redirect();

  $lxdebug->leave_sub();
}

# generate the printing options displayed at the bottom of oe and is forms.
# this function will attempt to guess what type of form is displayed, and will generate according options
#
# about the coding: 
# this version builds the arrays of options pretty directly. if you have trouble understanding how,
# the opthash function builds hashrefs which are then pieced together for the template arrays.
# unneeded options are "undef"ed out, and then grepped out. 
#
# the inline options is untested, but intended to be used later in metatemplating
sub print_options {
  $lxdebug->enter_sub();

  my ($options) = @_;

  $options ||= { };

  # names 3 parameters and returns a hashref, for use in templates
  sub opthash { +{ value => shift, selected => shift, oname => shift } }
  (@FORMNAME, @FORMNAME, @LANGUAGE_ID, @FORMAT, @SENDMODE, @MEDIA, @PRINTER_ID, @SELECTS) = ();

  # note: "||"-selection is only correct for values where "0" is _not_ a correct entry
  $form->{sendmode}   = "attachment";
  $form->{format}     = $form->{format} || $myconfig{template_format} || "pdf";
  $form->{copies}     = $form->{copies} || $myconfig{copies} || 3;
  $form->{media}      = $form->{media} || $myconfig{default_media} || "screen";
  $form->{printer_id} = defined $form->{printer_id}           ? $form->{printer_id} :
                        defined $myconfig{default_printer_id} ? $myconfig{default_printer_id} : "";

  $form->{PD}{ $form->{formname} } = "selected";
  $form->{DF}{ $form->{format} }   = "selected";
  $form->{OP}{ $form->{media} }    = "selected";
  $form->{SM}{ $form->{formname} } = "selected";

  push @FORMNAME, grep $_,
    ($form->{type} eq 'purchase_order') ? (
      opthash("purchase_order", $form->{PD}{purchase_order}, $locale->text('Purchase Order')),
      opthash("bin_list", $form->{PD}{bin_list}, $locale->text('Bin List')) 
    ) : undef,
    ($form->{type} eq 'credit_note') ?
      opthash("credit_note", $form->{PD}{credit_note}, $locale->text('Credit Note')) : undef,
    ($form->{type} eq 'sales_order') ? (
      opthash("sales_order", $form->{PD}{sales_order}, $locale->text('Confirmation')),
      opthash("proforma", $form->{PD}{proforma}, $locale->text('Proforma Invoice')),
      opthash("pick_list", $form->{PD}{pick_list}, $locale->text('Pick List')),
      opthash("packing_list", $form->{PD}{packing_list}, $locale->text('Packing List')) 
    ) : undef,
    ($form->{type} =~ /_quotation$/) ?
      opthash("$`_quotation", $form->{PD}{"$`_quotation"}, $locale->text('Quotation')) : undef,
    ($form->{type} eq 'invoice') ? (
      opthash("invoice", $form->{PD}{invoice}, $locale->text('Invoice')),
      opthash("proforma", $form->{PD}{proforma}, $locale->text('Proforma Invoice')),
      opthash("packing_list", $form->{PD}{packing_list}, $locale->text('Packing List'))
    ) : undef,
    ($form->{type} eq 'invoice' && $form->{storno}) ? (
      opthash("storno_invoice", $form->{PD}{storno_invoice}, $locale->text('Storno Invoice')),
      opthash("storno_packing_list", $form->{PD}{storno_packing_list}, $locale->text('Storno Packing List')) 
    ) : undef,
    ($form->{type} eq 'credit_note') ?
      opthash("credit_note", $form->{PD}{credit_note}, $locale->text('Credit Note')) : undef;

  push @SENDMODE, 
    opthash("attachment", $form->{SM}{attachment}, $locale->text('Attachment')),
    opthash("inline", $form->{SM}{inline}, $locale->text('In-line'))
      if ($form->{media} eq 'email');

  push @MEDIA, grep $_,
      opthash("screen", $form->{OP}{screen}, $locale->text('Screen')),
    (scalar @{ $form->{printers} } && $latex_templates) ?
      opthash("printer", $form->{OP}{printer}, $locale->text('Printer')) : undef,
    ($latex_templates && !$options->{no_queue}) ?
      opthash("queue", $form->{OP}{queue}, $locale->text('Queue')) : undef
        if ($form->{media} ne 'email');

  push @FORMAT, grep $_,
    ($opendocument_templates && $openofficeorg_writer_bin && $xvfb_bin && (-x $openofficeorg_writer_bin) && (-x $xvfb_bin)
     && !$options->{no_opendocument_pdf}) ?
      opthash("opendocument_pdf", $form->{DF}{"opendocument_pdf"}, $locale->text("PDF (OpenDocument/OASIS)")) : undef,
    ($latex_templates) ?
      opthash("pdf", $form->{DF}{pdf}, $locale->text('PDF')) : undef,
    ($latex_templates && !$options->{no_postscript}) ?
      opthash("postscript", $form->{DF}{postscript}, $locale->text('Postscript')) : undef,
    (!$options->{no_html}) ?
      opthash("html", $form->{DF}{html}, "HTML") : undef,
    ($opendocument_templates && !$options->{no_opendocument}) ?
      opthash("opendocument", $form->{DF}{opendocument}, $locale->text("OpenDocument/OASIS")) : undef;

  push @LANGUAGE_ID, 
    map { opthash($_->{id}, ($_->{id} eq $form->{language} ? 'selected' : ''), $_->{description}) } +{}, @{ $form->{languages} }
      if (ref $form->{languages} eq 'ARRAY');

  push @PRINTER_ID, 
    map { opthash($_->{id}, ($_->{id} eq $form->{printer_id} ? 'selected' : ''), $_->{printer_description}) } +{}, @{ $form->{printers} }
      if ((ref $form->{printers} eq 'ARRAY') && scalar @{ $form->{printers } });

  @SELECTS = map { sname => lc $_, DATA => \@$_, show => scalar @$_ }, qw(FORMNAME LANGUAGE_ID FORMAT SENDMODE MEDIA PRINTER_ID);

  my %dont_display_groupitems = (
    'dunning' => 1,
    );

  %template_vars = (
    display_copies       => scalar @{ $form->{printers} } && $latex_templates && $form->{media} ne 'email',
    display_remove_draft => (!$form->{id} && $form->{draft_id}),
    display_groupitems   => !$dont_display_groupitems{$form->{type}},
    groupitems_checked   => $form->{groupitems} ? "checked" : '',
    remove_draft_checked => $form->{remove_draft} ? "checked" : ''
  );

  my $print_options = $form->parse_html_template("generic/print_options", { SELECTS  => \@SELECTS, %template_vars } );

  if ($options->{inline}) {
    $lxdebug->leave_sub() and return $print_options;
  } else {
    print $print_options; $lxdebug->leave_sub();
  }
}

sub print {
  $lxdebug->enter_sub();

  if ($form->{print_nextsub}) {
    call_sub($form->{print_nextsub});
    $lxdebug->leave_sub();
    return;
  }

  # if this goes to the printer pass through
  if ($form->{media} eq 'printer' || $form->{media} eq 'queue') {
    $form->error($locale->text('Select postscript or PDF!'))
      if ($form->{format} !~ /(postscript|pdf)/);

    $old_form = new Form;
    map { $old_form->{$_} = $form->{$_} } keys %$form;
  }

  if (!$form->{id} || (($form->{formname} eq "proforma") && !$form->{proforma} && (($form->{type} =~ /_order$/) || ($form->{type} =~ /_quotation$/)))) {
    if ($form->{formname} eq "proforma") {
      $form->{proforma} = 1;
    }
    $form->{print_and_save} = 1;
    my $formname = $form->{formname};
    &save();
    $form->{formname} = $formname;
    &edit();
    exit;
  }

  &print_form($old_form);

  $lxdebug->leave_sub();
}

sub print_form {
  $lxdebug->enter_sub();
  my ($old_form) = @_;

  $inv       = "inv";
  $due       = "due";
  $numberfld = "invnumber";

  $display_form =
    ($form->{display_form}) ? $form->{display_form} : "display_form";

  # $form->{"notes"} will be overridden by the customer's/vendor's "notes" field. So save it here.
  $form->{ $form->{"formname"} . "notes" } = $form->{"notes"};

  if ($form->{formname} eq "invoice") {
    $form->{label} = $locale->text('Invoice');
  }
  if ($form->{formname} eq "packing_list") {

    # this is from an invoice
    $form->{label} = $locale->text('Packing List');
  }
  if ($form->{formname} eq 'sales_order') {
    $inv                  = "ord";
    $due                  = "req";
    $form->{"${inv}date"} = $form->{transdate};
    $form->{label}        = $locale->text('Sales Order');
    $numberfld            = "sonumber";
    $order                = 1;
  }

  if (($form->{type} eq 'invoice') && ($form->{formname} eq 'proforma') ) {
    $inv                  = "inv";
    $due                  = "due";
    $form->{"${inv}date"} = $form->{invdate};
    $form->{label}        = $locale->text('Proforma Invoice');
    $numberfld            = "sonumber";
    $order                = 0;
  }

  if (($form->{type} eq 'sales_order') && ($form->{formname} eq 'proforma') ) {
    $inv                  = "inv";
    $due                  = "due";
    $form->{"${inv}date"} = $form->{transdate};
    $form->{"invdate"}    = $form->{transdate};
    $form->{invnumber}    = $form->{ordnumber};
    $form->{label}        = $locale->text('Proforma Invoice');
    $numberfld            = "sonumber";
    $order                = 1;
  }

  if ($form->{formname} eq 'packing_list' && $form->{type} ne 'invoice') {

    # we use the same packing list as from an invoice
    $inv = "ord";
    $due = "req";
    $form->{invdate} = $form->{"${inv}date"} = $form->{transdate};
    $form->{label} = $locale->text('Packing List');
    $order = 1;
    # set invnumber for template packing_list 
    $form->{invnumber}   = $form->{ordnumber};
  }
  if ($form->{formname} eq 'pick_list') {
    $inv                  = "ord";
    $due                  = "req";
    $form->{"${inv}date"} =
      ($form->{transdate}) ? $form->{transdate} : $form->{invdate};
    $form->{label} = $locale->text('Pick List');
    $order = 1 unless $form->{type} eq 'invoice';
  }
  if ($form->{formname} eq 'purchase_order') {
    $inv                  = "ord";
    $due                  = "req";
    $form->{"${inv}date"} = $form->{transdate};
    $form->{label}        = $locale->text('Purchase Order');
    $numberfld            = "ponumber";
    $order                = 1;
  }
  if ($form->{formname} eq 'bin_list') {
    $inv                  = "ord";
    $due                  = "req";
    $form->{"${inv}date"} = $form->{transdate};
    $form->{label}        = $locale->text('Bin List');
    $order                = 1;
  }
  if ($form->{formname} eq 'sales_quotation') {
    $inv                  = "quo";
    $due                  = "req";
    $form->{"${inv}date"} = $form->{transdate};
    $form->{label}        = $locale->text('Quotation');
    $numberfld            = "sqnumber";
    $order                = 1;
  }

  if (($form->{type} eq 'sales_quotation') && ($form->{formname} eq 'proforma') ) {
    $inv                  = "quo";
    $due                  = "req";
    $form->{"${inv}date"} = $form->{transdate};
    $form->{"invdate"}    = $form->{transdate};
    $form->{label}        = $locale->text('Proforma Invoice');
    $numberfld            = "sqnumber";
    $order                = 1;
  }

  if ($form->{formname} eq 'request_quotation') {
    $inv                  = "quo";
    $due                  = "req";
    $form->{"${inv}date"} = $form->{transdate};
    $form->{label}        = $locale->text('Quotation');
    $numberfld            = "rfqnumber";
    $order                = 1;
  }

  $form->isblank("email", $locale->text('E-mail address missing!'))
    if ($form->{media} eq 'email');
  $form->isblank("${inv}date",
           $locale->text($form->{label}) 
           . ": "
           . $locale->text(' Date missing!'));

  # $locale->text('Invoice Number missing!')
  # $locale->text('Invoice Date missing!')
  # $locale->text('Packing List Number missing!')
  # $locale->text('Packing List Date missing!')
  # $locale->text('Order Number missing!')
  # $locale->text('Order Date missing!')
  # $locale->text('Quotation Number missing!')
  # $locale->text('Quotation Date missing!')

  # assign number
  $form->{what_done} = $form->{formname};
  if (!$form->{"${inv}number"} && !$form->{preview} && !$form->{id}) {
    $form->{"${inv}number"} = $form->update_defaults(\%myconfig, $numberfld);
    if ($form->{media} ne 'email') {

      # get pricegroups for parts
      IS->get_pricegroups_for_parts(\%myconfig, \%$form);

      # build up html code for prices_$i
      set_pricegroup($form->{rowcount});

      $form->{rowcount}--;

      call_sub($display_form);
      # saving the history
  	  if(!exists $form->{addition}) {
        $form->{snumbers} = qq|ordnumber_| . $form->{ordnumber}; 
  	    $form->{addition} = "PRINTED";
  	    $form->save_history($form->dbconnect(\%myconfig));
      }
      # /saving the history
      exit;
    }
  }

  &validate_items;

  # Save the email address given in the form because it should override the setting saved for the customer/vendor.
  my ($saved_email, $saved_cc, $saved_bcc) =
    ($form->{"email"}, $form->{"cc"}, $form->{"bcc"});

  $language_saved = $form->{language_id};
  $payment_id_saved = $form->{payment_id};
  $salesman_id_saved = $form->{salesman_id};
  $cp_id_saved = $form->{cp_id};

  call_sub("$form->{vc}_details");

  $form->{language_id} = $language_saved;
  $form->{payment_id} = $payment_id_saved;

  $form->{"email"} = $saved_email if ($saved_email);
  $form->{"cc"}    = $saved_cc    if ($saved_cc);
  $form->{"bcc"}   = $saved_bcc   if ($saved_bcc);

  if (!$cp_id_saved) {
    # No contact was selected. Delete all contact variables because
    # IS->customer_details() and IR->vendor_details() get the default
    # contact anyway.
    map({ delete($form->{$_}); } grep(/^cp_/, keys(%{ $form })));
  }

  my ($language_tc, $output_numberformat, $output_dateformat, $output_longdates);
  if ($form->{"language_id"}) {
    ($language_tc, $output_numberformat, $output_dateformat, $output_longdates) =
      AM->get_language_details(\%myconfig, $form, $form->{language_id});
  } else {
    $output_dateformat = $myconfig{"dateformat"};
    $output_numberformat = $myconfig{"numberformat"};
    $output_longdates = 1;
  }

  ($form->{employee}) = split /--/, $form->{employee};

  # create the form variables
  if ($order) {
    OE->order_details(\%myconfig, \%$form);
  } else {
    IS->invoice_details(\%myconfig, \%$form, $locale);
  }

  $form->get_salesman(\%myconfig, $salesman_id_saved);

  if ($form->{shipto_id}) {
    $form->get_shipto(\%myconfig);
  }

  @a = qw(name street zipcode city country);

  $shipto = 1;

  # if there is no shipto fill it in from billto
  foreach $item (@a) {
    if ($form->{"shipto$item"}) {
      $shipto = 0;
      last;
    }
  }

  if ($shipto) {
    if (   $form->{formname} eq 'purchase_order'
        || $form->{formname} eq 'request_quotation') {
      $form->{shiptoname}   = $myconfig{company};
      $form->{shiptostreet} = $myconfig{address};
    } else {
      map { $form->{"shipto$_"} = $form->{$_} } @a;
    }
  }

  $form->{notes} =~ s/^\s+//g;

  $form->{templates} = "$myconfig{templates}";

  delete $form->{printer_command};

  $form->{language} = $form->get_template_language(\%myconfig);

  my $printer_code;
  if ($form->{media} ne 'email') {
    $printer_code = $form->get_printer_code(\%myconfig);
    if ($printer_code ne "") {
      $printer_code = "_" . $printer_code;
    }
  }

  if ($form->{language} ne "") {
    map({ $form->{"unit"}->[$_] =
            AM->translate_units($form, $form->{"language"},
                                $form->{"unit"}->[$_], $form->{"qty"}->[$_]); }
        (0..scalar(@{$form->{"unit"}}) - 1));
    $form->{language} = "_" . $form->{language};
  }

  # Format dates.
  format_dates($output_dateformat, $output_longdates,
               qw(invdate orddate quodate pldate duedate reqdate transdate
                  shippingdate deliverydate validitydate paymentdate
                  datepaid transdate_oe deliverydate_oe
                  employee_startdate employee_enddate
                  ),
               grep({ /^datepaid_\d+$/ ||
                        /^transdate_oe_\d+$/ ||
                        /^deliverydate_oe_\d+$/ ||
                        /^reqdate_\d+$/ ||
                        /^deliverydate_\d+$/ ||
                        /^transdate_\d+$/
                    } keys(%{$form})));

  reformat_numbers($output_numberformat, 2,
                   qw(invtotal ordtotal quototal subtotal linetotal
                      listprice sellprice netprice discount
                      tax taxbase total paid),
                   grep({ /^linetotal_\d+$/ ||
                            /^listprice_\d+$/ ||
                            /^sellprice_\d+$/ ||
                            /^netprice_\d+$/ ||
                            /^taxbase_\d+$/ ||
                            /^discount_\d+$/ ||
                            /^paid_\d+$/ ||
                            /^subtotal_\d+$/ ||
                            /^total_\d+$/ ||
                            /^tax_\d+$/
                        } keys(%{$form})));

  reformat_numbers($output_numberformat, undef,
                   qw(qty),
                   grep({ /^qty_\d+$/
                        } keys(%{$form})));

  $form->{IN} = "$form->{formname}$form->{language}${printer_code}.html";
  if ($form->{format} eq 'postscript') {
    $form->{postscript} = 1;
    $form->{IN} =~ s/html$/tex/;
  } elsif ($form->{"format"} =~ /pdf/) {
    $form->{pdf} = 1;
    if ($form->{"format"} =~ /opendocument/) {
      $form->{IN} =~ s/html$/odt/;
    } else {
      $form->{IN} =~ s/html$/tex/;
    }
  } elsif ($form->{"format"} =~ /opendocument/) {
    $form->{"opendocument"} = 1;
    $form->{"IN"} =~ s/html$/odt/;
  }

  delete $form->{OUT};

  if ($form->{media} eq 'printer') {
    $form->{OUT} = "| $form->{printer_command} &>/dev/null";
    $form->{printed} .= " $form->{formname}";
    $form->{printed} =~ s/^ //;
  }
  $printed = $form->{printed};

  if ($form->{media} eq 'email') {
    $form->{subject} = qq|$form->{label} $form->{"${inv}number"}|
      unless $form->{subject};

    $form->{emailed} .= " $form->{formname}";
    $form->{emailed} =~ s/^ //;
  }
  $emailed = $form->{emailed};

  if ($form->{media} eq 'queue') {
    %queued = map { s|.*/|| } split / /, $form->{queued};

    if ($filename = $queued{ $form->{formname} }) {
      $form->{queued} =~ s/$form->{formname} $filename//;
      unlink "$spool/$filename";
      $filename =~ s/\..*$//g;
    } else {
      $filename = time;
      $filename .= $$;
    }

    $filename .= ($form->{postscript}) ? '.ps' : '.pdf';
    $form->{OUT} = ">$spool/$filename";

    # add type
    $form->{queued} .= " $form->{formname} $filename";

    $form->{queued} =~ s/^ //;
  }
  $queued = $form->{queued};

# saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers} = qq|ordnumber_| . $form->{ordnumber};
    if($form->{media} =~ /printer/) {
    	$form->{addition} = "PRINTED";
    }
    elsif($form->{media} =~ /email/) {
    	$form->{addition} = "MAILED";
    }
    elsif($form->{media} =~ /queue/) {
    	$form->{addition} = "QUEUED";
    }
    elsif($form->{media} =~ /screen/) {
    	$form->{addition} = "SCREENED";
    }
    $form->save_history($form->dbconnect(\%myconfig));
  }
  # /saving the history

  $form->parse_template(\%myconfig, $userspath);

  $form->{callback} = "";

  if ($form->{media} eq 'email') {
    $form->{message} = $locale->text('sent') unless $form->{message};
  }
  $message = $form->{message};

  # if we got back here restore the previous form
  if ($form->{media} =~ /(printer|email|queue)/) {

    $form->update_status(\%myconfig)
      if ($form->{media} eq 'queue' && $form->{id});

    return $lxdebug->leave_sub() if ($old_form eq "return");

    if ($old_form) {

      $old_form->{"${inv}number"} = $form->{"${inv}number"};

      # restore and display form
      map { $form->{$_} = $old_form->{$_} } keys %$old_form;

      $form->{queued}  = $queued;
      $form->{printed} = $printed;
      $form->{emailed} = $emailed;
      $form->{message} = $message;

      $form->{rowcount}--;
      map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) }
        qw(exchangerate creditlimit creditremaining);

      for $i (1 .. $form->{paidaccounts}) {
        map {
          $form->{"${_}_$i"} =
            $form->parse_amount(\%myconfig, $form->{"${_}_$i"})
        } qw(paid exchangerate);
      }

      call_sub($display_form);
      exit;
    }

    $msg =
      ($form->{media} eq 'printer')
      ? $locale->text('sent to printer')
      : $locale->text('emailed to') . " $form->{email}";
    $form->redirect(qq|$form->{label} $form->{"${inv}number"} $msg|);
  }
  if ($form->{printing}) {
   call_sub($display_form);
   exit; 
  }

  $lxdebug->leave_sub();
}

sub customer_details {
  $lxdebug->enter_sub();
  IS->customer_details(\%myconfig, \%$form, @_);
  $lxdebug->leave_sub();
}

sub vendor_details {
  $lxdebug->enter_sub();

  IR->vendor_details(\%myconfig, \%$form, @_);

  $lxdebug->leave_sub();
}

sub post_as_new {
  $lxdebug->enter_sub();

  $form->{postasnew} = 1;
  map { delete $form->{$_} } qw(printed emailed queued);

  &post;

  $lxdebug->leave_sub();
}

sub ship_to {
  $lxdebug->enter_sub();
  if ($form->{second_run}) {
    $form->{print_and_post} = 0;
  }

  $title = $form->{title};
  $form->{title} = $locale->text('Ship to');

  map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) }
    qw(exchangerate creditlimit creditremaining);

  my @shipto_vars =
    qw(shiptoname shiptostreet shiptozipcode shiptocity shiptocountry
       shiptocontact shiptophone shiptofax shiptoemail
       shiptodepartment_1 shiptodepartment_2);

  my @addr_vars =
    (qw(name department_1 department_2 street zipcode city country
        contact email phone fax));

  # get details for name
  call_sub("$form->{vc}_details", @addr_vars);

  $number =
    ($form->{vc} eq 'customer')
    ? $locale->text('Customer Number')
    : $locale->text('Vendor Number');

  # get pricegroups for parts
  IS->get_pricegroups_for_parts(\%myconfig, \%$form);

  # build up html code for prices_$i
  set_pricegroup($form->{rowcount});

  $nextsub = ($form->{display_form}) ? $form->{display_form} : "display_form";

  $form->{rowcount}--;

  $form->header;

  print qq|
<body>

<form method="post" action="$form->{script}">

<table width="100%">
  <tr>
    <td>
      <table>
	<tr class="listheading">
	  <th class="listheading" colspan="2" width="50%">|
    . $locale->text('Billing Address') . qq|</th>
	  <th class="listheading" width="50%">|
    . $locale->text('Shipping Address') . qq|</th>
	</tr>
	<tr height="5"></tr>
	<tr>
	  <th align="right" nowrap>$number</th>
	  <td>$form->{"$form->{vc}number"}</td>
	</tr>
	<tr>
	  <th align="right" nowrap>| . $locale->text('Company Name') . qq|</th>
	  <td>$form->{name}</td>
	  <td><input name="shiptoname" size="35" value="$form->{shiptoname}"></td>
	</tr>
	<tr>
	  <th align="right" nowrap>| . $locale->text('Department') . qq|</th>
	  <td>$form->{department_1}</td>
	  <td><input name="shiptodepartment_1" size="35" value="$form->{shiptodepartment_1}"></td>
	</tr>
	<tr>
	  <th align="right" nowrap>&nbsp;</th>
	  <td>$form->{department_2}</td>
	  <td><input name="shiptodepartment_2" size="35" value="$form->{shiptodepartment_2}"></td>
	</tr>
	<tr>
	  <th align="right" nowrap>| . $locale->text('Street') . qq|</th>
	  <td>$form->{street}</td>
	  <td><input name="shiptostreet" size="35" value="$form->{shiptostreet}"></td>
	</tr>
	<tr>
	  <th align="right" nowrap>| . $locale->text('Zipcode') . qq|</th>
	  <td>$form->{zipcode}</td>
	  <td><input name="shiptozipcode" size="35" value="$form->{shiptozipcode}"></td>
	</tr>
	<tr>
	  <th align="right" nowrap>| . $locale->text('City') . qq|</th>
	  <td>$form->{city}</td>
	  <td><input name="shiptocity" size="35" value="$form->{shiptocity}"></td>
	</tr>
	<tr>
	  <th align="right" nowrap>| . $locale->text('Country') . qq|</th>
	  <td>$form->{country}</td>
	  <td><input name="shiptocountry" size="35" value="$form->{shiptocountry}"></td>
	</tr>
	<tr>
	  <th align="right" nowrap>| . $locale->text('Contact') . qq|</th>
	  <td>$form->{contact}</td>
	  <td><input name="shiptocontact" size="35" value="$form->{shiptocontact}"></td>
	</tr>
	<tr>
	  <th align="right" nowrap>| . $locale->text('Phone') . qq|</th>
	  <td>$form->{phone}</td>
	  <td><input name="shiptophone" size="20" value="$form->{shiptophone}"></td>
	</tr>
	<tr>
	  <th align="right" nowrap>| . $locale->text('Fax') . qq|</th>
	  <td>$form->{fax}</td>
	  <td><input name="shiptofax" size="20" value="$form->{shiptofax}"></td>
	</tr>
	<tr>
	  <th align="right" nowrap>| . $locale->text('E-mail') . qq|</th>
	  <td>$form->{email}</td>
	  <td><input name="shiptoemail" size="35" value="$form->{shiptoemail}"></td>
	</tr>
      </table>
    </td>
  </tr>
</table>
| . $cgi->hidden("-name" => "nextsub", "-value" => $nextsub);
;



  # delete shipto
  map({ delete $form->{$_} } (@shipto_vars, qw(header)));
  $form->{title} = $title;

  foreach $key (keys %$form) {
    $form->{$key} =~ s/\"/&quot;/g;
    print qq|<input type="hidden" name="$key" value="$form->{$key}">\n|;
  }

  print qq|

<hr size="3" noshade>

<br>
<input class="submit" type="submit" name="action" value="|
    . $locale->text('Continue') . qq|">
</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub new_license {
  $lxdebug->enter_sub();

  my $row = shift;

  # change callback
  $form->{old_callback} = $form->escape($form->{callback}, 1);
  $form->{callback} = $form->escape("$form->{script}?action=display_form", 1);
  $form->{old_callback} = $form->escape($form->{old_callback}, 1);

  # delete action
  delete $form->{action};
  $customer = $form->{customer};
  map { $form->{"old_$_"} = $form->{"${_}_$row"} } qw(partnumber description);

  # save all other form variables in a previousform variable
  $form->{row} = $row;
  foreach $key (keys %$form) {

    # escape ampersands
    $form->{$key} =~ s/&/%26/g;
    $previousform .= qq|$key=$form->{$key}&|;
  }
  chop $previousform;
  $previousform = $form->escape($previousform, 1);

  $form->{script} = "licenses.pl";

  map { $form->{$_} = $form->{"old_$_"} } qw(partnumber description);
  map { $form->{$_} = $form->escape($form->{$_}, 1) }
    qw(partnumber description);
  $form->{callback} =
    qq|$form->{script}?login=$form->{login}&password=$form->{password}&action=add&vc=$form->{db}&$form->{db}_id=$form->{id}&$form->{db}=$name&type=$form->{type}&customer=$customer&partnumber=$form->{partnumber}&description=$form->{description}&previousform="$previousform"&initial=1|;
  $form->redirect;

  $lxdebug->leave_sub();
}

sub relink_accounts {
  $lxdebug->enter_sub();

  $form->{"taxaccounts"} =~ s/\s*$//;
  $form->{"taxaccounts"} =~ s/^\s*//;
  foreach my $accno (split(/\s*/, $form->{"taxaccounts"})) {
    map({ delete($form->{"${accno}_${_}"}); } qw(rate description taxnumber));
  }
  $form->{"taxaccounts"} = "";

  for (my $i = 1; $i <= $form->{"rowcount"}; $i++) {
    if ($form->{"id_$i"}) {
      IC->retrieve_accounts(\%myconfig, $form, $form->{"id_$i"}, $i, 1);
    }
  }

  $lxdebug->leave_sub();
}

sub set_duedate {
  $lxdebug->enter_sub();

  $form->get_duedate(\%myconfig);

  my $q = new CGI;
  $result = "$form->{duedate}";
  print $q->header();
  print $result;
  $lxdebug->leave_sub();

}

