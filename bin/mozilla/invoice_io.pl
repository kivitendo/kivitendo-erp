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
# common routines used in is, ir but not in oe
#
#######################################################################

use CGI;
use CGI::Ajax;
use List::Util qw(max);

use SL::Common;
use SL::CT;
use SL::IC;

require "bin/mozilla/common.pl";

# any custom scripts for this one
if (-f "bin/mozilla/custom_invoice_io.pl") {
  eval { require "bin/mozilla/custom_ivvoice_io.pl"; };
}
if (-f "bin/mozilla/$form->{login}_invoice_io.pl") {
  eval { require "bin/mozilla/$form->{login}_invoice_io.pl"; };
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
#sub display_row {
#  $lxdebug->enter_sub();
#  my $numrows = shift;
#
#  my $is_sales =
#    (substr($form->{type}, 0, 6) eq "sales_")
#    || (($form->{type} eq "invoice") && ($form->{script} eq "is.pl"))
#    || ($form->{type} eq 'credit_note');
#
#  if ($lizenzen && $form->{vc} eq "customer") {
#    if ($form->{type} =~ /sales_order/) {
#      @column_index = (runningnumber, partnumber, description, ship, qty);
#    } elsif ($form->{type} =~ /sales_quotation/) {
#      @column_index = (runningnumber, partnumber, description, qty);
#    } else {
#      @column_index = (runningnumber, partnumber, description, qty);
#    }
#  } else {
#    if (   ($form->{type} =~ /purchase_order/)
#        || ($form->{type} =~ /sales_order/)) {
#      @column_index = (runningnumber, partnumber, description, ship, qty);
#        } else {
#      @column_index = (runningnumber, partnumber, description, qty);
#    }
#  }
############### ENDE Neueintrag ##################
#
#  my $dimension_units = AM->retrieve_units(\%myconfig, $form, "dimension");
#  my $service_units = AM->retrieve_units(\%myconfig, $form, "service");
#  my $all_units = AM->retrieve_units(\%myconfig, $form);
#
#  my %price_factors = map { $_->{id} => $_->{factor} } @{ $form->{ALL_PRICE_FACTORS} };
#
#  push @column_index, qw(unit);
#
#  #for pricegroups column
#  if (   $form->{type} =~ (/sales_quotation/)
#      or (($form->{level} =~ /Sales/) and ($form->{type} =~ /invoice/))
#      or (($form->{level} eq undef) and ($form->{type} =~ /invoice/))
#      or ($form->{type} =~ /sales_order/)) {
#    push @column_index, qw(sellprice_pg);
#  }
#
#  push @column_index, qw(sellprice);
#
#  if ($form->{vc} eq 'customer') {
#    push @column_index, qw(discount);
#  }
#
#  push @column_index, "linetotal";
#
#  my $colspan = $#column_index + 1;
#
#  $form->{invsubtotal} = 0;
#  map { $form->{"${_}_base"} = 0 } (split(/ /, $form->{taxaccounts}));
#
#########################################
#  # Eintrag fuer Version 2.2.0 geaendert #
#  # neue Optik im Rechnungsformular      #
#########################################
#  $column_data{runningnumber} = qq|<th align="left" nowrap width="5%"  class="listheading">| . $locale->text('No.') .         qq|</th>|;
#  $column_data{partnumber}    = qq|<th align="left" nowrap width="12%" class="listheading">| . $locale->text('Number') .      qq|</th>|;
#  $column_data{description}   = qq|<th align="left" nowrap width="30%" class="listheading">| . $locale->text('Part Description') . qq|</th>|;
#  if ($form->{"type"} eq "purchase_order") {
#    $column_data{ship}        = qq|<th align="left" nowrap width="5%"  class="listheading">| . $locale->text('Ship rcvd') .   qq|</th>|;
#  } else {
#    $column_data{ship}        = qq|<th align="left" nowrap width="5%"  class="listheading">| . $locale->text('Ship') .        qq|</th>|;
#  }
#  $column_data{qty}           = qq|<th align="left" nowrap width="5%"  class="listheading">| . $locale->text('Qty') .         qq|</th>|;
#  $column_data{unit}          = qq|<th align="left" nowrap width="20%" class="listheading">| . $locale->text('Unit') .        qq|</th>|;
#  $column_data{license}       = qq|<th align="left" nowrap width="10%" class="listheading">| . $locale->text('License') .     qq|</th>|;
#  $column_data{serialnr}      = qq|<th align="left" nowrap width="10%" class="listheading">| . $locale->text('Serial No.') .  qq|</th>|;
#  $column_data{projectnr}     = qq|<th align="left" nowrap width="10%" class="listheading">| . $locale->text('Project') .     qq|</th>|;
#  $column_data{sellprice}     = qq|<th align="left" nowrap width="15%" class="listheading">| . $locale->text('Price') .       qq|</th>|;
#  $column_data{sellprice_pg}  = qq|<th align="left" nowrap width="15%" class="listheading">| . $locale->text('Pricegroup') .  qq|</th>|;
#  $column_data{discount}      = qq|<th align="left" nowrap width="5%"  class="listheading">| . $locale->text('Discount') .    qq|</th>|;
#  $column_data{linetotal}     = qq|<th align="left" nowrap width="10%" class="listheading">| . $locale->text('Extended') .    qq|</th>|;
#  $column_data{bin}           = qq|<th align="left" nowrap width="10%" class="listheading">| . $locale->text('Bin') .         qq|</th>|;
############### ENDE Neueintrag ##################
#
#  $myconfig{"show_form_details"} = 1
#    unless (defined($myconfig{"show_form_details"}));
#  $form->{"show_details"} = $myconfig{"show_form_details"}
#    unless (defined($form->{"show_details"}));
#  $form->{"show_details"} = $form->{"show_details"} ? 1 : 0;
#  my $show_details_new = 1 - $form->{"show_details"};
#  my $show_details_checked = $form->{"show_details"} ? "checked" : "";
#
#  print qq|
#  <tr>
#    <td>| . $cgi->hidden("-name" => "show_details", "-value" => $form->{show_details}) . qq|
#      <input type="checkbox" id="cb_show_details" onclick="show_form_details($show_details_new);" $show_details_checked>
#      <label for="cb_show_details">| . $locale->text("Show details") . qq|</label><br>
#      <table width="100%">
#	<tr class="listheading">|;
#
#  map { print "\n$column_data{$_}" } @column_index;
#
#  print qq|
#        </tr>
#|;
#
#  $runningnumber = $locale->text('No.');
#  $deliverydate  = $locale->text('Delivery Date');
#  $serialnumber  = $locale->text('Serial No.');
#  $projectnumber = $locale->text('Project');
#  $partsgroup    = $locale->text('Group');
#  $reqdate       = $locale->text('Reqdate');
#
#  $delvar = 'deliverydate';
#
#  if ($form->{type} =~ /_order$/ || $form->{type} =~ /_quotation$/) {
#    $deliverydate = $locale->text('Required by');
#    $delvar       = 'reqdate';
#  }
#
#  $form->{marge_total} = 0;
#  $form->{sellprice_total} = 0;
#  $form->{lastcost_total} = 0;
#  my %projectnumber_labels = ();
#  my @projectnumber_values = ("");
#  foreach my $item (@{ $form->{"ALL_PROJECTS"} }) {
#    push(@projectnumber_values, $item->{"id"});
#    $projectnumber_labels{$item->{"id"}} = $item->{"projectnumber"};
#  }
#
#  for $i (1 .. $numrows) {
#
#    # undo formatting
#    map {
#      $form->{"${_}_$i"} =
#        $form->parse_amount(\%myconfig, $form->{"${_}_$i"})
#    } qw(qty ship discount sellprice price_new price_old) unless ($form->{simple_save});
#
#    if (!$form->{"unit_old_$i"}) {
#      # Neue Ware aus der Datenbank. In diesem Fall ist unit_$i die
#      # Einheit, wie sie in den Stammdaten hinterlegt wurde.
#      # Es sollte also angenommen werden, dass diese ausgewaehlt war.
#      $form->{"unit_old_$i"} = $form->{"unit_$i"};
#    }
#
#    # Die zuletzt ausgewaehlte mit der aktuell ausgewaehlten Einheit
#    # vergleichen und bei Unterschied den Preis entsprechend umrechnen.
#    $form->{"selected_unit_$i"} = $form->{"unit_$i"} unless ($form->{"selected_unit_$i"});
#
#    my $check_units = $form->{"inventory_accno_$i"} ? $dimension_units : $service_units;
#    if (!$check_units->{$form->{"selected_unit_$i"}} ||
#        ($check_units->{$form->{"selected_unit_$i"}}->{"base_unit"} ne
#         $all_units->{$form->{"unit_old_$i"}}->{"base_unit"})) {
#      # Die ausgewaehlte Einheit ist fuer diesen Artikel nicht gueltig
#      # (z.B. Dimensionseinheit war ausgewaehlt, es handelt sich aber
#      # um eine Dienstleistung). Dann keinerlei Umrechnung vornehmen.
#      $form->{"unit_old_$i"} = $form->{"selected_unit_$i"} = $form->{"unit_$i"};
#    }
#    if ((!$form->{"prices_$i"}) || ($form->{"new_pricegroup_$i"} == $form->{"old_pricegroup_$i"})) {
#      if ($form->{"unit_old_$i"} ne $form->{"selected_unit_$i"}) {
#        my $basefactor = 1;
#        if (defined($all_units->{$form->{"unit_old_$i"}}->{"factor"}) &&
#            $all_units->{$form->{"unit_old_$i"}}->{"factor"}) {
#          $basefactor = $all_units->{$form->{"selected_unit_$i"}}->{"factor"} /
#            $all_units->{$form->{"unit_old_$i"}}->{"factor"};
#        }
#        $form->{"sellprice_$i"} *= $basefactor;
#        $form->{"unit_old_$i"} = $form->{"selected_unit_$i"};
#      }
#    }
#
#    ($dec) = ($form->{"sellprice_$i"} =~ /\.(\d+)/);
#    $decimalplaces = max length($dec), 2;
#
#    $price_factor = $price_factors{$form->{"price_factor_id_$i"}} || 1;
#    $discount     = (100 - $form->{"discount_$i"} * 1) / 100;
#
#    $linetotal    = $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"} * $discount / $price_factor, $decimalplaces);
#
#    my $real_sellprice = $form->{"sellprice_$i"} * $discount / $price_factor;
#
#    # marge calculations
#    my ($marge_font_start, $marge_font_end);
#
#    $form->{"lastcost_$i"} *= 1;
#
#    $marge_price_factor = $form->{"marge_price_factor_$i"} * 1 || 1;
#
#    if ($real_sellprice && ($form->{"qty_$i"} * 1)) {
#      $form->{"marge_percent_$i"}     = ($real_sellprice - $form->{"lastcost_$i"} / $marge_price_factor) * 100 / $real_sellprice;
#      $myconfig{"marge_percent_warn"} = 15 unless (defined($myconfig{"marge_percent_warn"}));
#
#      if ($form->{"id_$i"} &&
#          ($form->{"marge_percent_$i"} < (1 * $myconfig{"marge_percent_warn"}))) {
#        $marge_font_start = "<font color=\"#ff0000\">";
#        $marge_font_end   = "</font>";
#      }
#
#    } else {
#      $form->{"marge_percent_$i"} = 0;
#    }
#
#    my $marge_adjust_credit_note = $form->{type} eq 'credit_note' ? -1 : 1;
#    $form->{"marge_total_$i"}  = ($real_sellprice - $form->{"lastcost_$i"} / $marge_price_factor) * $form->{"qty_$i"} * $marge_adjust_credit_note;
#    $form->{"marge_total"}      += $form->{"marge_total_$i"};
#    $form->{"lastcost_total"}   += $form->{"lastcost_$i"} * $form->{"qty_$i"} / $marge_price_factor;
#    $form->{"sellprice_total"}  += $real_sellprice * $form->{"qty_$i"};
#
#    map { $form->{"${_}_$i"} = $form->format_amount(\%myconfig, $form->{"${_}_$i"}, 2) } qw(marge_total marge_percent);
#
#    # convert " to &quot;
#    map { $form->{"${_}_$i"} =~ s/\"/&quot;/g }
#      qw(partnumber description unit unit_old);
#
#########################################
#    # Eintrag fuer Version 2.2.0 geaendert #
#    # neue Optik im Rechnungsformular      #
#########################################
#    $column_data{runningnumber} =
#      qq|<td><input name="runningnumber_$i" size="5" value="$i"></td>|;    # HuT
############### ENDE Neueintrag ##################
#
#    $column_data{partnumber} =
#      qq|<td><input name="partnumber_$i" size=12 value="$form->{"partnumber_$i"}"></td>|;
#
#    if (($rows = $form->numtextrows($form->{"description_$i"}, 30, 6)) > 1) {
#      $column_data{description} =
#        qq|<td><textarea name="description_$i" rows="$rows" cols="30" wrap="soft">| . H($form->{"description_$i"}) . qq|</textarea><button type="button" onclick="set_longdescription_window('longdescription_$i')">| . $locale->text('L') . qq|</button></td>|;
#    } else {
#      $column_data{description} =
#        qq|<td><input name="description_$i" size="30" value="| . $form->quote($form->{"description_$i"}) . qq|"><button type="button" onclick="set_longdescription_window('longdescription_$i')">| . $locale->text('L') . qq|</button></td>|;
#    }
#
#    (my $qty_dec) = ($form->{"qty_$i"} =~ /\.(\d+)/);
#    $qty_dec = length $qty_dec;
#
#    $column_data{qty} =
#        qq|<td align="right"><input name="qty_$i" size="5" value="|
#      . $form->format_amount(\%myconfig, $form->{"qty_$i"}, $qty_dec) .qq|">|;
#    if ($form->{"formel_$i"}) {
#      $column_data{qty} .= qq|<button type="button" onclick="calculate_qty_selection_window('qty_$i','alu_$i', 'formel_$i', $i)">| . $locale->text('*/') . qq|</button>|
#        . $cgi->hidden("-name" => "formel_$i", "-value" => $form->{"formel_$i"}) . $cgi->hidden("-name" => "alu_$i", "-value" => $form->{"alu_$i"});
#    }
#    $column_data{qty} .= qq|</td>|;
#    $column_data{ship} =
#        qq|<td align="right"><input name="ship_$i" size=5 value="|
#      . $form->format_amount(\%myconfig, $form->{"ship_$i"})
#      . qq|"></td>|;
#
#    my $is_part     = $form->{"inventory_accno_$i"};
#    my $is_assembly = $form->{"assembly_$i"};
#    my $is_assigned = $form->{"id_$i"};
#    my $this_unit = $form->{"unit_$i"};
#    if ($form->{"selected_unit_$i"} && $this_unit &&
#        $all_units->{$form->{"selected_unit_$i"}} && $all_units->{$this_unit} &&
#        ($all_units->{$form->{"selected_unit_$i"}}->{"base_unit"} eq $all_units->{$this_unit}->{"base_unit"})) {
#      $this_unit = $form->{"selected_unit_$i"};
#    } elsif (!$is_assigned ||
#             ($is_part && !$this_unit && ($all_units->{$this_unit} && ($all_units->{$this_unit}->{"base_unit"} eq $all_units->{"kg"}->{"base_unit"})))) {
#      $this_unit = "kg";
#    }
#
#    my $price_factor_select;
#    if (0 < scalar @{ $form->{ALL_PRICE_FACTORS} }) {
#      my @values = ('', map { $_->{id}                      } @{ $form->{ALL_PRICE_FACTORS} });
#      my %labels =      map { $_->{id} => $_->{description} } @{ $form->{ALL_PRICE_FACTORS} };
#
#      $price_factor_select =
#        NTI($cgi->popup_menu('-name'    => "price_factor_id_$i",
#                             '-default' => $form->{"price_factor_id_$i"},
#                             '-values'  => \@values,
#                             '-labels'  => \%labels,
#                             '-style'   => 'width:90px'))
#        . ' ';
#    }
#
#    $column_data{"unit"} = "<td>" .
#      $price_factor_select .
#       AM->unit_select_html($is_part || $is_assembly ? $dimension_units :
#                            $is_assigned ? $service_units : $all_units,
#                            "unit_$i", $this_unit,
#                            $is_assigned ? $form->{"unit_$i"} : undef)
#      . "</td>";
#
#    # build in drop down list for pricesgroups
#    if ($form->{"prices_$i"}) {
#      if  ($form->{"new_pricegroup_$i"} != $form->{"old_pricegroup_$i"}) {
#        $price_tmp = $form->format_amount(\%myconfig, $form->{"price_new_$i"}, $decimalplaces);
#      } else {
#        $price_tmp = $form->format_amount(\%myconfig, $form->{"sellprice_$i"}, $decimalplaces);
#      }
#
#      $column_data{sellprice_pg} =
#      qq|<td align="right"><select name="sellprice_pg_$i">$form->{"prices_$i"}</select></td>|;
#      $column_data{sellprice} =
#      qq|<td><input name="sellprice_$i" size="10" value="$price_tmp" onBlur=\"check_right_number_format(this)\"></td>|;
#    } else {
#
#      # for last row and report
#      # set pricegroup drop down list from report menu
#      if ($form->{"sellprice_$i"} != 0) {
#        $prices =
#          qq|<option value="$form->{"sellprice_$i"}--$form->{"pricegroup_id_$i"}" selected>$form->{"pricegroup_$i"}</option>\n|;
#
#        $form->{"pricegroup_old_$i"} = $form->{"pricegroup_id_$i"};
#
#        $column_data{sellprice_pg} =
#          qq|<td align="right"><select name="sellprice_pg_$i">$prices</select></td>|;
#
#      } else {
#
#        # for last row
#        $column_data{sellprice_pg} = qq|<td align="right">&nbsp;</td>|;
#        }
#        
#      $column_data{sellprice} =
#      qq|<td><input name="sellprice_$i" size="10" onBlur=\"check_right_number_format(this)\" value="|
#        . $form->format_amount(\%myconfig, $form->{"sellprice_$i"},
#                               $decimalplaces)
#        . qq|"></td>|;
#    }
#    $column_data{discount} =
#        qq|<td align="right"><input name="discount_$i" size=3 value="|
#      . $form->format_amount(\%myconfig, $form->{"discount_$i"})
#      . qq|"></td>|;
#    $column_data{linetotal} =
#        qq|<td align="right">|
#      . $form->format_amount(\%myconfig, $linetotal, 2)
#      . qq|</td>|;
#    $column_data{bin} = qq|<td>$form->{"bin_$i"}</td>|;
#
#########################################
#    # Eintrag fuer Version 2.2.0 geaendert #
#    # neue Optik im Rechnungsformular      #
#########################################
#    #     if ($lizenzen &&  $form->{type} eq "invoice" &&  $form->{vc} eq "customer") {
#    #     $column_data{license} = qq|<td><select name="licensenumber_$i">$form->{"lizenzen_$i"}></select></td>|;
#    #     }
#    #
#    #     if ($form->{type} !~ /_quotation/) {
#    #     $column_data{serialnr} = qq|<td><input name="serialnumber_$i" size=10 value="$form->{"serialnumber_$i"}"></td>|;
#    #     }
#    #
#    #     $column_data{projectnr} = qq|<td><input name="projectnumber_$i" size=10 value="$form->{"projectnumber_$i"}"></td>|;
############### ENDE Neueintrag ##################
#    my $j = $i % 2;
#    print qq|
#
#        <tr valign="top" class="listrow$j">|;
#
#    map { print "\n$column_data{$_}" } @column_index;
#
#    print("</tr>\n" .
#          $cgi->hidden("-name" => "unit_old_$i",
#                       "-value" => $form->{"selected_unit_$i"})
#          . "\n" .
#          $cgi->hidden("-name" => "price_new_$i",
#                       "-value" => $form->format_amount(\%myconfig, $form->{"price_new_$i"}))
#          . "\n");
#    map({ print($cgi->hidden("-name" => $_, "-value" => $form->{$_}) . "\n"); }
#        ("orderitems_id_$i", "bo_$i", "pricegroup_old_$i", "price_old_$i",
#         "id_$i", "inventory_accno_$i", "bin_$i", "partsgroup_$i", "partnotes_$i",
#         "income_accno_$i", "expense_accno_$i", "listprice_$i", "assembly_$i",
#         "taxaccounts_$i", "ordnumber_$i", "transdate_$i", "cusordnumber_$i",
#         "longdescription_$i", "basefactor_$i", "marge_total_$i", "marge_percent_$i", "lastcost_$i",
#         "marge_price_factor_$i"));
#
#########################################
#    # Eintrag fuer Version 2.2.0 geaendert #
#    # neue Optik im Rechnungsformular      #
#########################################
#
#    my $row_style_attr =
#      'style="display:none;"' if (!$form->{"show_details"});
#
#    # print second row
#    print qq|
#        <tr  class="listrow$j" $row_style_attr>
#	  <td colspan="$colspan">
#|;
#    if ($lizenzen && $form->{type} eq "invoice" && $form->{vc} eq "customer") {
#      my $selected = $form->{"licensenumber_$i"};
#      my $lizenzen_quoted;
#      $form->{"lizenzen_$i"} =~ s/ selected//g;
#      $form->{"lizenzen_$i"} =~
#        s/value="${selected}"\>/value="${selected}" selected\>/;
#      $lizenzen_quoted = $form->{"lizenzen_$i"};
#      $lizenzen_quoted =~ s/\"/&quot;/g;
#      print qq|
#	<b>Lizenz\#</b>&nbsp;<select name="licensenumber_$i" size="1">
#	$form->{"lizenzen_$i"}
#        </select>
#	<input type="hidden" name="lizenzen_$i" value="${lizenzen_quoted}">
#|;
#    }
#    if ($form->{type} !~ /_quotation/) {
#      print qq|
#          <b>$serialnumber</b>&nbsp;<input name="serialnumber_$i" size="15" value="$form->{"serialnumber_$i"}">|;
#    }
#
#    print qq|<b>$projectnumber</b>&nbsp;| .
#      NTI($cgi->popup_menu('-name' => "project_id_$i",
#                           '-values' => \@projectnumber_values,
#                           '-labels' => \%projectnumber_labels,
#                           '-default' => $form->{"project_id_$i"}));
#
#    if ($form->{type} eq 'invoice' or $form->{type} =~ /order/) {
#      my $reqdate_term =
#        ($form->{type} eq 'invoice')
#        ? 'deliverydate'
#        : 'reqdate';    # invoice uses a different term for the same thing.
#      print qq|
#        <b>${$reqdate_term}</b>&nbsp;<input name="${reqdate_term}_$i" size="11" onBlur="check_right_date_format(this)" value="$form->{"${reqdate_term}_$i"}">
#|;
#    }
#    my $subtotalchecked = ($form->{"subtotal_$i"}) ? "checked" : "";
#    print qq|
#          <b>|.$locale->text('Subtotal').qq|</b>&nbsp;<input type="checkbox" name="subtotal_$i" value="1" $subtotalchecked>
#|;
#
#    if ($form->{"id_$i"} && $is_sales) {
#      my $marge_price_factor;
#
#      $form->{"marge_price_factor_$i"} *= 1;
#
#      if ($form->{"marge_price_factor_$i"} && (1 != $form->{"marge_price_factor_$i"})) {
#        $marge_price_factor = '/' . $form->format_amount(\%myconfig, $form->{"marge_price_factor_$i"});
#      }
#
#      print qq|
#          ${marge_font_start}<b>| . $locale->text('Ertrag') . qq|</b>&nbsp;$form->{"marge_total_$i"}&nbsp;$form->{"marge_percent_$i"} % ${marge_font_end}|;
#   }
#   print qq|
#          &nbsp;<b>| . $locale->text('LP') . qq|</b>&nbsp;| . $form->format_amount(\%myconfig, $form->{"listprice_$i"}, 2) . qq|
#          &nbsp;<b>| . $locale->text('EK') . qq|</b>&nbsp;| . $form->format_amount(\%myconfig, $form->{"lastcost_$i"}, 2) . $marge_price_factor;
#
#
#    print qq|
#	  </td>
#	</tr>
#|;
#
############### ENDE Neueintrag ##################
#
#    map { $form->{"${_}_base"} += $linetotal }
#      (split(/ /, $form->{"taxaccounts_$i"}));
#
#    $form->{invsubtotal} += $linetotal;
#  }
#
#  print qq|
#      </table>
#    </td>
#  </tr>
#|;
#
#  if (0 != ($form->{sellprice_total} * 1)) {
#    $form->{marge_percent} = ($form->{sellprice_total} - $form->{lastcost_total}) / $form->{sellprice_total} * 100;
#  }
#
#  $lxdebug->leave_sub();
#}

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
