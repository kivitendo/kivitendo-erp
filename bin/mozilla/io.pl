#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#############################################################################
# Changelog: Wann - Wer - Was
# Veraendert 2005-01-05 - Marco Welter <mawe@linux-studio.de> - Neue Optik
# 08.11.2008 - information@richardson-bueren.de jb  - Backport von Revision 7339 xplace - E-Mail-Vorlage automatisch auswählen
# 02.02.2009 - information@richardson-bueren.de jb - Backport von Revision 8535 xplace - Erweiterung der Waren bei Lieferantenauftrag um den Eintrag Mindestlagerbestand. Offen: Auswahlliste auf Lieferantenaufträge einschränken -> Erledigt 2.2.09 Prüfung wie das Skript heisst (oe.pl) -> das ist nur die halbe Miete, nochmal mb fragen -> mb gefragt und es gibt die variable is_purchase
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

use Carp;
use CGI;
use List::MoreUtils qw(any uniq);
use List::Util qw(min max first);

use SL::CVar;
use SL::Common;
use SL::CT;
use SL::IC;
use SL::IO;

use SL::DB::Default;
use SL::DB::Language;
use SL::DB::Printer;
use SL::Helper::Flash;

require "bin/mozilla/common.pl";

use strict;

# any custom scripts for this one
if (-f "bin/mozilla/custom_io.pl") {
  eval { require "bin/mozilla/custom_io.pl"; };
}
if (-f "bin/mozilla/$::form->{login}_io.pl") {
  eval { require "bin/mozilla/$::form->{login}_io.pl"; };
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

sub _check_io_auth {
  $main::auth->assert('part_service_assembly_edit   | vendor_invoice_edit       | sales_order_edit    | invoice_edit |' .
                'request_quotation_edit       | sales_quotation_edit      | purchase_order_edit | ' .
                'purchase_delivery_order_edit | sales_delivery_order_edit | part_service_assembly_details');
}

########################################
# Eintrag fuer Version 2.2.0 geaendert #
# neue Optik im Rechnungsformular      #
########################################
sub display_row {
  $main::lxdebug->enter_sub();

  _check_io_auth();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;
  my $cgi      = $::request->{cgi};

  my $numrows = shift;

  my ($stock_in_out, $stock_in_out_title);

  my $defaults = AM->get_defaults();
  $form->{show_weight} = $defaults->{show_weight};
  $form->{weightunit} = $defaults->{weightunit};

  my $is_purchase        = (first { $_ eq $form->{type} } qw(request_quotation purchase_order purchase_delivery_order)) || ($form->{script} eq 'ir.pl');
  my $show_min_order_qty =  first { $_ eq $form->{type} } qw(request_quotation purchase_order);
  my $is_delivery_order  = $form->{type} =~ /_delivery_order$/;
  my $is_s_p_order       = (first { $_ eq $form->{type} } qw(sales_order purchase_order));

  if ($is_delivery_order) {
    if ($form->{type} eq 'sales_delivery_order') {
      $stock_in_out_title = $locale->text('Release From Stock');
      $stock_in_out       = 'out';
    } else {
      $stock_in_out_title = $locale->text('Transfer To Stock');
      $stock_in_out       = 'in';
    }

    retrieve_partunits();
  }

  # column_index
  my @header_sort = qw(runningnumber partnumber description ship qty unit weight sellprice_pg sellprice discount linetotal);
  my @HEADER = (
    {  id => 'runningnumber', width => 5,     value => $locale->text('No.'),                  display => 1, },
    {  id => 'partnumber',    width => 8,     value => $locale->text('Number'),               display => 1, },
    {  id => 'description',   width => 30,    value => $locale->text('Part Description'),     display => 1, },
    {  id => 'ship',          width => 5,     value => $locale->text('Delivered'),            display => $is_s_p_order, },
    {  id => 'qty',           width => 5,     value => $locale->text('Qty'),                  display => 1, },
    {  id => 'price_factor',  width => 5,     value => $locale->text('Price Factor'),         display => !$is_delivery_order, },
    {  id => 'unit',          width => 5,     value => $locale->text('Unit'),                 display => 1, },
    {  id => 'weight',        width => 5,     value => $locale->text('Weight'),               display => $defaults->{show_weight}, },
    {  id => 'serialnr',      width => 10,    value => $locale->text('Serial No.'),           display => 0, },
    {  id => 'projectnr',     width => 10,    value => $locale->text('Project'),              display => 0, },
    {  id => 'sellprice',     width => 15,    value => $locale->text('Price'),                display => !$is_delivery_order, },
    {  id => 'sellprice_pg',  width => 8,     value => $locale->text('Pricegroup'),           display => !$is_delivery_order && !$is_purchase, },
    {  id => 'discount',      width => 5,     value => $locale->text('Discount'),             display => !$is_delivery_order, },
    {  id => 'linetotal',     width => 10,    value => $locale->text('Extended'),             display => !$is_delivery_order, },
    {  id => 'bin',           width => 10,    value => $locale->text('Bin'),                  display => 0, },
    {  id => 'stock_in_out',  width => 10,    value => $stock_in_out_title,                   display => $is_delivery_order, },
  );
  my @column_index = map { $_->{id} } grep { $_->{display} } @HEADER;


  # cache units
  my $all_units       = AM->retrieve_units(\%myconfig, $form);

  my %price_factors   = map { $_->{id} => $_->{factor} } @{ $form->{ALL_PRICE_FACTORS} };

  my $colspan = scalar @column_index;

  $form->{invsubtotal} = 0;
  map { $form->{"${_}_base"} = 0 } (split(/ /, $form->{taxaccounts}));

  # about details
  $myconfig{show_form_details} = 1                            unless (defined($myconfig{show_form_details}));
  $form->{show_details}        = $myconfig{show_form_details} unless (defined($form->{show_details}));
  # /about details

  # translations, unused commented out
#  $runningnumber = $locale->text('No.');
#  my $deliverydate  = $locale->text('Delivery Date');
  my $serialnumber  = $locale->text('Serial No.');
  my $projectnumber = $locale->text('Project');
#  $partsgroup    = $locale->text('Group');
  my $reqdate       = $locale->text('Reqdate');
  my $deliverydate  = $locale->text('Required by');

  # special alignings
  my %align  = map { $_ => 'right' } qw(qty ship right sellprice_pg discount linetotal stock_in_out weight);
  my %nowrap = map { $_ => 1 }       qw(description unit);

  $form->{marge_total}           = 0;
  $form->{sellprice_total}       = 0;
  $form->{lastcost_total}        = 0;
  $form->{totalweight}           = 0;
  my %projectnumber_labels = ();
  my @projectnumber_values = ("");

  foreach my $item (@{ $form->{"ALL_PROJECTS"} }) {
    push(@projectnumber_values, $item->{"id"});
    $projectnumber_labels{$item->{"id"}} = $item->{"projectnumber"};
  }

  _update_part_information();
  _update_ship() if ($is_s_p_order);
  _update_custom_variables();

  my $totalweight = 0;

  # rows

  my @ROWS;
  for my $i (1 .. $numrows) {
    my %column_data = ();

    # undo formatting
    map { $form->{"${_}_$i"} = $form->parse_amount(\%myconfig, $form->{"${_}_$i"}) }
      qw(qty discount sellprice lastcost price_new price_old)
        unless ($form->{simple_save});

# unit begin
    $form->{"unit_old_$i"}      ||= $form->{"unit_$i"};
    $form->{"selected_unit_$i"} ||= $form->{"unit_$i"};

    if (   !$all_units->{$form->{"selected_unit_$i"}}                                            # Die ausgewaehlte Einheit ist fuer diesen Artikel nicht gueltig
        || !AM->convert_unit($form->{"selected_unit_$i"}, $form->{"unit_old_$i"}, $all_units)) { # (z.B. Dimensionseinheit war ausgewaehlt, es handelt sich aber
      $form->{"unit_old_$i"} = $form->{"selected_unit_$i"} = $form->{"unit_$i"};                 # um eine Dienstleistung). Dann keinerlei Umrechnung vornehmen.
    }
    # adjust prices by unit, ignore if pricegroup changed
    if ((!$form->{"prices_$i"}) || ($form->{"new_pricegroup_$i"} == $form->{"old_pricegroup_$i"})) {
        $form->{"sellprice_$i"} *= AM->convert_unit($form->{"selected_unit_$i"}, $form->{"unit_old_$i"}, $all_units) || 1;
        $form->{"lastcost_$i"} *= AM->convert_unit($form->{"selected_unit_$i"}, $form->{"unit_old_$i"}, $all_units) || 1;
        $form->{"unit_old_$i"}   = $form->{"selected_unit_$i"};
    }
    my $this_unit = $form->{"unit_$i"};
    $this_unit    = $form->{"selected_unit_$i"} if AM->convert_unit($this_unit, $form->{"selected_unit_$i"}, $all_units);

    if (0 < scalar @{ $form->{ALL_PRICE_FACTORS} }) {
      my @values = ('', map { $_->{id}                      } @{ $form->{ALL_PRICE_FACTORS} });
      my %labels =      map { $_->{id} => $_->{description} } @{ $form->{ALL_PRICE_FACTORS} };

      $column_data{price_factor} =
        NTI($cgi->popup_menu('-name'    => "price_factor_id_$i",
                             '-default' => $form->{"price_factor_id_$i"},
                             '-values'  => \@values,
                             '-labels'  => \%labels,
                             '-style'   => 'width:90px'));
    } else {
      $column_data{price_factor} = '&nbsp;';
    }
    $form->{"weight_$i"} *= AM->convert_unit($form->{"selected_unit_$i"}, $form->{"partunit_$i"}, $all_units) || 1;

    $column_data{"unit"} = AM->unit_select_html($all_units, "unit_$i", $this_unit, $form->{"id_$i"} ? $form->{"unit_$i"} : undef);
# / unit ending

#count the max of decimalplaces of sellprice and lastcost, so the same number of decimalplaces
#is shown for lastcost and sellprice.
    my $decimalplaces = ($form->{"sellprice_$i"} =~ /\.(\d+)/) ? max 2, length $1 : 2;
    $decimalplaces = ($form->{"lastcost_$i"} =~ /\.(\d+)/) ? max $decimalplaces, length $1 : $decimalplaces;

    my $price_factor   = $price_factors{$form->{"price_factor_id_$i"}} || 1;
    my $discount       = $form->round_amount($form->{"qty_$i"} * $form->{"sellprice_$i"} *        $form->{"discount_$i"}  / 100 / $price_factor, 2);
    my $linetotal      = $form->round_amount($form->{"qty_$i"} * $form->{"sellprice_$i"} * (100 - $form->{"discount_$i"}) / 100 / $price_factor, 2);
    my $rows            = $form->numtextrows($form->{"description_$i"}, 30, 6);

    $column_data{runningnumber} = $cgi->textfield(-name => "runningnumber_$i", -size => 5,  -value => $i);    # HuT
    $column_data{partnumber}    = $cgi->textfield(-name => "partnumber_$i",    -size => 12, -value => $form->{"partnumber_$i"});
    $column_data{description} = (($rows > 1) # if description is too large, use a textbox instead
                                ? $cgi->textarea( -name => "description_$i", -default => $form->{"description_$i"}, -rows => $rows, -columns => 30)
                                : $cgi->textfield(-name => "description_$i",   -size => 30, -value => $form->{"description_$i"}))
                                . $cgi->button(-value => $locale->text('L'), -onClick => "set_longdescription_window('longdescription_$i')");

    my $qty_dec = ($form->{"qty_$i"} =~ /\.(\d+)/) ? length $1 : 2;

    $column_data{qty}  = $cgi->textfield(-name => "qty_$i", -size => 5, -value => $form->format_amount(\%myconfig, $form->{"qty_$i"}, $qty_dec));
    $column_data{qty} .= $cgi->button(-onclick => "calculate_qty_selection_window('qty_$i','alu_$i', 'formel_$i', $i)", -value => $locale->text('*/'))
                       . $cgi->hidden(-name => "formel_$i", -value => $form->{"formel_$i"}) . $cgi->hidden("-name" => "alu_$i", "-value" => $form->{"alu_$i"})
      if $form->{"formel_$i"};

    $column_data{ship} = '';
    if ($form->{"id_$i"}) {
      my $ship_qty        = $form->{"ship_$i"} * 1;
      $ship_qty          *= $all_units->{$form->{"partunit_$i"}}->{factor};
      $ship_qty          /= ( $all_units->{$form->{"unit_$i"}}->{factor} || 1 );

      $column_data{ship}  = $form->format_amount(\%myconfig, $form->round_amount($ship_qty, 2) * 1) . ' ' . $form->{"unit_$i"};
    }

    # build in drop down list for pricesgroups
    # $sellprice_value setzt den Wert etwas unabhängiger von der Darstellung.
    # Hintergrund: Preisgruppen werden hier überprüft und neu berechnet.
    # Vorher wurde der ganze cgi->textfield Block zweimal identisch eingebaut, dass passiert
    # jetzt nach der Abfrage.
    my $sellprice_value;
    if ($form->{"prices_$i"}) {
      $column_data{sellprice_pg} = qq|<select name="sellprice_pg_$i" style="width: 8em">$form->{"prices_$i"}</select>|;
      $sellprice_value           =($form->{"new_pricegroup_$i"} != $form->{"old_pricegroup_$i"})
                                      ? $form->format_amount(\%myconfig, $form->{"price_new_$i"}, $decimalplaces)
                                      : $form->format_amount(\%myconfig, $form->{"sellprice_$i"}, $decimalplaces);
    } else {
      # for last row and report
      # set pricegroup drop down list from report menu
      if ($form->{"sellprice_$i"} != 0) {
        # remember the pricegroup_id in pricegroup_old
        # but don't overwrite it
        $form->{"pricegroup_old_$i"} = $form->{"pricegroup_id_$i"};
        my $default_option           = $form->{"sellprice_$i"}.'--'.$form->{"pricegroup_id_$i"};
        $column_data{sellprice_pg}   = NTI($cgi->popup_menu("sellprice_pg_$i", [ $default_option ], $default_option, { $default_option => $form->{"pricegroup_$i"} || '' }));
      } else {
        $column_data{sellprice_pg} = qq|&nbsp;|;
      }
      $sellprice_value = $form->format_amount(\%myconfig, $form->{"sellprice_$i"}, $decimalplaces);

    }
    # Falls der Benutzer die Preise nicht anpassen sollte, wird das entsprechende
    # Textfield auf readonly gesetzt. Anm. von Sven: Manipulation der Preise ist
    # immer noch möglich, konsequenterweise sollten diese NUR aus der Datenbank
    # geholt werden.
    my $edit_prices = $main::auth->assert('edit_prices', 1);
    $column_data{sellprice} = (!$edit_prices)
                                ? $cgi->textfield(-readonly => "readonly",
                                                  -name => "sellprice_$i", -size => 10, -onBlur => "check_right_number_format(this)", -value => $sellprice_value)
                                : $cgi->textfield(-name => "sellprice_$i", -size => 10, -onBlur => "check_right_number_format(this)", -value => $sellprice_value);
    $column_data{discount}    = (!$edit_prices)
                                  ? $cgi->textfield(-readonly => "readonly",
                                                    -name => "discount_$i", -size => 3, -value => $form->format_amount(\%myconfig, $form->{"discount_$i"}))
                                  : $cgi->textfield(-name => "discount_$i", -size => 3, -value => $form->format_amount(\%myconfig, $form->{"discount_$i"}));
    $column_data{linetotal}   = $form->format_amount(\%myconfig, $linetotal, 2);
    $column_data{bin}         = $form->{"bin_$i"};

    $column_data{weight}      = $form->format_amount(\%myconfig, $form->{"qty_$i"} * $form->{"weight_$i"}, 3) . ' ' . $defaults->{weightunit} if $defaults->{show_weight};

    if ($is_delivery_order) {
      $column_data{stock_in_out} =  calculate_stock_in_out($i);
    }

    my @ROW1 = map { value => $column_data{$_}, align => $align{$_}, nowrap => $nowrap{$_} }, @column_index;

    # second row
    my @ROW2 = ();
    push @ROW2, { value => qq|<b>$serialnumber</b> <input name="serialnumber_$i" size="15" value="$form->{"serialnumber_$i"}">| }
      if $form->{type} !~ /_quotation/;
    push @ROW2, { value => qq|<b>$projectnumber</b> | . NTI($cgi->popup_menu('-name'  => "project_id_$i",        '-values'  => \@projectnumber_values,
                                                                             '-labels' => \%projectnumber_labels, '-default' => $form->{"project_id_$i"})) };
    push @ROW2, { value => qq|<b>$reqdate</b> <input name="reqdate_$i" size="11" onBlur="check_right_date_format(this)" value="$form->{"reqdate_$i"}">| }
      if ($form->{type} =~ /order/ ||  $form->{type} =~ /invoice/);
    push @ROW2, { value => sprintf qq|<b>%s</b>&nbsp;<input type="checkbox" name="subtotal_$i" value="1" %s>|,
                   $locale->text('Subtotal'), $form->{"subtotal_$i"} ? 'checked' : '' };

# begin marge calculations
    $form->{"lastcost_$i"}     *= 1;
    $form->{"marge_percent_$i"} = 0;

    my $marge_color;
    my $real_sellprice;
    if ( $form->{taxincluded} and $form->{"qty_$i"} * 1  and $form->{$form->{"taxaccounts_$i"} . "_rate"} * 1) {
      # if we use taxincluded we need to calculate the marge from the net_value
      # all the marge calculations are based on linetotal which we need to
      # convert to net first

      # there is no direct form value for the tax_rate of the item, but
      # form->{taxaccounts_$i} gives the tax account (e.g. 3806) and 3806_rate
      # gives the tax percentage (e.g. 0.19)
      $real_sellprice = $linetotal / (1 + $form->{$form->{"taxaccounts_$i"} . "_rate"});
    } else {
      $real_sellprice            = $linetotal;
    };
    my $real_lastcost            = $form->round_amount($form->{"lastcost_$i"} * $form->{"qty_$i"} / $price_factor, 2);
    my $marge_percent_warn       = $myconfig{marge_percent_warn} * 1 || 15;
    my $marge_adjust_credit_note = $form->{type} eq 'credit_note' ? -1 : 1;

    if ($real_sellprice * 1 && ($form->{"qty_$i"} * 1)) {
      $form->{"marge_percent_$i"} = ($real_sellprice - $real_lastcost) * 100 / $real_sellprice;
      $marge_color                = 'color="#ff0000"' if $form->{"id_$i"} && $form->{"marge_percent_$i"} < $marge_percent_warn;
    }

    $form->{"marge_absolut_$i"}  = ($real_sellprice - $real_lastcost) * $marge_adjust_credit_note;
    $form->{"marge_total"}      += $form->{"marge_absolut_$i"};
    $form->{"lastcost_total"}   += $real_lastcost;
    $form->{"sellprice_total"}  += $real_sellprice;

    map { $form->{"${_}_$i"} = $form->format_amount(\%myconfig, $form->{"${_}_$i"}, 2) } qw(marge_absolut marge_percent);

    push @ROW2, { value => sprintf qq|
         <font %s><b>%s</b> %s &nbsp;%s%% </font>
        &nbsp;<b>%s</b> %s
        &nbsp;<b>%s</b> <input size="5" name="lastcost_$i" value="%s">|,
                   $marge_color, $locale->text('Ertrag'),$form->{"marge_absolut_$i"}, $form->{"marge_percent_$i"},
                   $locale->text('LP'), $form->format_amount(\%myconfig, $form->{"listprice_$i"}, 2),
                   $locale->text('EK'), $form->format_amount(\%myconfig, $form->{"lastcost_$i"}, $decimalplaces) }
      if $form->{"id_$i"} && ($form->{type} =~ /^sales_/ ||  $form->{type} =~ /invoice/ || $form->{type} =~ /^credit_note$/ ) && !$is_delivery_order;

    $form->{"listprice_$i"} = $form->format_amount(\%myconfig, $form->{"listprice_$i"}, 2)
      if $form->{"id_$i"} && ($form->{type} =~ /^sales_/ ||  $form->{type} =~ /invoice/) ;
# / marge calculations ending

# Calculate total weight
    $totalweight += ($form->{"qty_$i"} * $form->{"weight_$i"});

# calculate onhand
    if ($form->{"id_$i"}) {
      my $part         = IC->get_basic_part_info(id => $form->{"id_$i"});
      my $onhand_color = $part->{onhand} < $part->{rop} ? 'color="#ff0000"' : '';
      push @ROW2, { value => sprintf "<b>%s</b> <font %s>%s %s</font>",
                      $locale->text('On Hand'),
                      $onhand_color,
                      $form->format_amount(\%myconfig, $part->{onhand}, 2),
                      $part->{unit}
      };
    }
# / calculate onhand

    my @hidden_vars;

    if ($is_delivery_order) {
      map { $form->{"${_}_${i}"} = $form->format_amount(\%myconfig, $form->{"${_}_${i}"}) } qw(sellprice discount lastcost);
      push @hidden_vars, qw(sellprice discount not_discountable price_factor_id lastcost pricegroup_id);
      push @hidden_vars, "stock_${stock_in_out}_sum_qty", "stock_${stock_in_out}";
    }

    my @HIDDENS = map { value => $_}, (
          $cgi->hidden("-name" => "unit_old_$i", "-value" => $form->{"selected_unit_$i"}),
          $cgi->hidden("-name" => "price_new_$i", "-value" => $form->format_amount(\%myconfig, $form->{"price_new_$i"})),
          map { ($cgi->hidden("-name" => $_, "-value" => $form->{$_})); } map { $_."_$i" }
            (qw(orderitems_id bo pricegroup_old price_old id inventory_accno bin partsgroup partnotes
                income_accno expense_accno listprice assembly taxaccounts ordnumber transdate cusordnumber
                longdescription basefactor marge_absolut marge_percent marge_price_factor weight), @hidden_vars)
    );

    map { $form->{"${_}_base"} += $linetotal } (split(/ /, $form->{"taxaccounts_$i"}));

    $form->{invsubtotal} += $linetotal;

    # Benutzerdefinierte Variablen für Waren/Dienstleistungen/Erzeugnisse
    _render_custom_variables_inputs(ROW2 => \@ROW2, row => $i, part_id => $form->{"id_$i"});

    push @ROWS, { ROW1 => \@ROW1, ROW2 => \@ROW2, HIDDENS => \@HIDDENS, colspan => $colspan, error => $form->{"row_error_$i"}, };
  }

  $form->{totalweight} = $totalweight;

  print $form->parse_html_template('oe/sales_order', { ROWS   => \@ROWS,
                                                       HEADER => \@HEADER,
                                                     });

  if (0 != ($form->{sellprice_total} * 1)) {
    $form->{marge_percent} = ($form->{sellprice_total} - $form->{lastcost_total}) / $form->{sellprice_total} * 100;
  }

  $main::lxdebug->leave_sub();
}

##################################################
# build html-code for pricegroups in variable $form->{prices_$j}

sub set_pricegroup {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;
  my $cgi      = $::request->{cgi};

  _check_io_auth();

  my $rowcount = shift;
  for my $j (1 .. $rowcount) {
    next unless $form->{PRICES}{$j};
    # build drop down list for pricegroups
    my $option_tmpl = qq|<option value="%s--%s" %s>%s</option>|;
    $form->{"prices_$j"}  = join '', map { sprintf $option_tmpl, @$_{qw(price pricegroup_id selected pricegroup)} }
                                         (+{ pricegroup => $locale->text("none (pricegroup)") }, @{ $form->{PRICES}{$j} });

    foreach my $item (@{ $form->{PRICES}{$j} }) {
      # set new selectedpricegroup_id and prices for "Preis"
      $form->{"pricegroup_old_$j"} = $item->{pricegroup_id}   if $item->{selected} &&  $item->{pricegroup_id};
      $form->{"sellprice_$j"}      = $item->{price}           if $item->{selected} &&  $item->{pricegroup_id};
      $form->{"price_new_$j"}      = $form->{"sellprice_$j"}  if $item->{selected} || !$item->{pricegroup_id};
    }
  }
  $main::lxdebug->leave_sub();
}

sub select_item {
  $main::lxdebug->enter_sub();

  my %params = @_;
  my $mode   = $params{mode} || croak "Missing parameter 'mode'";

  _check_io_auth();

  my $previous_form = $::auth->save_form_in_session(form => $::form);
  $::form->{title}  = $::locale->text('Select from one of the items below');
  $::form->header;

  my @item_list = map {
    $_->{display_sellprice}  = $_->{sellprice} * (1 - $::form->{tradediscount});
    $_->{display_sellprice} /= $_->{price_factor} if ($_->{price_factor});
    $_;
  } @{ $::form->{item_list} };

  # delete action variable
  delete @{$::form}{qw(action item_list)};

  print $::form->parse_html_template('io/select_item', { PREVIOUS_FORM => $previous_form,
                                                         MODE          => $mode,
                                                         ITEM_LIST     => \@item_list,
                                                         IS_PURCHASE   => $mode eq 'IS' });

  $main::lxdebug->leave_sub();
}

sub item_selected {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  _check_io_auth();

  $::auth->restore_form_from_session($form->{select_item_previous_form} || croak('Missing previous form ID'), form => $form);

  my $mode = delete($form->{select_item_mode}) || croak 'Missing item selection mode';
  my $id   = delete($form->{select_item_id})   || croak 'Missing item selection ID';
  my $i    = $form->{ $mode eq 'IC' ? 'assembly_rows' : 'rowcount' };

  $form->{"id_${i}"} = $id;

  if ($mode eq 'IS') {
    IS->retrieve_item(\%myconfig, \%$form);
  } elsif ($mode eq 'IR') {
    IR->retrieve_item(\%myconfig, \%$form);
  } elsif ($mode eq 'IC') {
    IC->assembly_item(\%myconfig, \%$form);
  } else {
    croak "Invalid item selection mode '${mode}'";
  }

  my $new_item = $form->{item_list}->[0] || croak "No item found for mode '${mode}' and ID '${id}'";

  # if there was a price entered, override it
  my $sellprice = $form->parse_amount(\%myconfig, $form->{"sellprice_$i"});

  my @new_fields =
    qw(id partnumber description sellprice listprice inventory_accno
       income_accno expense_accno bin unit weight assembly taxaccounts
       partsgroup formel longdescription not_discountable partnotes lastcost
       price_factor_id price_factor);

  my $ic_cvar_configs = CVar->get_configs(module => 'IC');
  push @new_fields, map { "ic_cvar_$_->{name}" } @{ $ic_cvar_configs };

  map { $form->{"${_}_$i"} = $new_item->{$_} } @new_fields;

  $form->{"marge_price_factor_$i"} = $new_item->{price_factor};

  if ($form->{"part_payment_id_$i"} ne "") {
    $form->{payment_id} = $form->{"part_payment_id_$i"};
  }

  my ($dec) = ($form->{"sellprice_$i"} =~ /\.(\d+)/);
  $dec           = length $dec;
  my $decimalplaces = ($dec > 2) ? $dec : 2;

  if ($sellprice) {
    $form->{"sellprice_$i"} = $sellprice;
  } else {

    # if there is an exchange rate adjust sellprice
    if (($form->{exchangerate} * 1) != 0) {
      $form->{"sellprice_$i"} /= $form->{exchangerate};
      $form->{"sellprice_$i"} =
        $form->round_amount($form->{"sellprice_$i"}, $decimalplaces);
    }

    # tradediscount
    if ($::form->{tradediscount}) {
      $::form->{"sellprice_$i"} *= 1 - $::form->{tradediscount};
    }
  }

  map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) }
    qw(sellprice listprice weight);

  $form->{weight}    += ($form->{"weight_$i"} * $form->{"qty_$i"});

  if ($form->{"not_discountable_$i"}) {
    $form->{"discount_$i"} = 0;
  }

  my $amount =
    $form->{"sellprice_$i"} * (1 - $form->{"discount_$i"} / 100) *
    $form->{"qty_$i"};
  map { $form->{"${_}_base"} += $amount }
    (split / /, $form->{"taxaccounts_$i"});
  map { $amount += ($form->{"${_}_base"} * $form->{"${_}_rate"}) } split / /,
    $form->{"taxaccounts_$i"}
    if !$form->{taxincluded};

  $form->{creditremaining} -= $amount;

  $form->{"runningnumber_$i"} = $i;

  delete $form->{nextsub};

  # format amounts
  map {
    $form->{"${_}_$i"} =
      $form->format_amount(\%myconfig, $form->{"${_}_$i"}, $decimalplaces)
  } qw(sellprice listprice lastcost) if $form->{item} ne 'assembly';

  # get pricegroups for parts
  IS->get_pricegroups_for_parts(\%myconfig, \%$form);

  # build up html code for prices_$i
  set_pricegroup($form->{rowcount});

  &display_form;

  $main::lxdebug->leave_sub();
}

sub new_item {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  _check_io_auth();

  my $price_key = ($form->{type} =~ m/request_quotation|purchase_order/) || ($form->{script} eq 'ir.pl') ? 'lastcost' : 'sellprice';

  # change callback
  $form->{old_callback} = $form->escape($form->{callback}, 1);
  $form->{callback}     = $form->escape("$form->{script}?action=display_form", 1);

  # save all form variables except action in the session and keep the key in the previousform variable
  my $previousform = $::auth->save_form_in_session(skip_keys => [ qw(action) ]);

  my @HIDDENS;
  push @HIDDENS,      { 'name' => 'previousform', 'value' => $previousform };
  push @HIDDENS, map +{ 'name' => $_,             'value' => $form->{$_} },                       qw(rowcount vc);
  push @HIDDENS, map +{ 'name' => $_,             'value' => $form->{"${_}_$form->{rowcount}"} }, qw(partnumber description unit);
  push @HIDDENS,      { 'name' => 'taxaccount2',  'value' => $form->{taxaccounts} };
  push @HIDDENS,      { 'name' => $price_key,     'value' => $form->parse_amount(\%myconfig, $form->{"sellprice_$form->{rowcount}"}) };
  push @HIDDENS,      { 'name' => 'notes',        'value' => $form->{"longdescription_$form->{rowcount}"} };

  $form->header();
  print $form->parse_html_template("generic/new_item", { HIDDENS => [ sort { $a->{name} cmp $b->{name} } @HIDDENS ] } );

  $main::lxdebug->leave_sub();
}

sub check_form {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  _check_io_auth();

  my @a     = ();
  my $count = 0;

  # remove any makes or model rows
  if ($form->{item} eq 'assembly') {

    # fuer assemblies auskommentiert. seiteneffekte? ;-) wird die woanders benoetigt?
    #$form->{sellprice} = 0;
    $form->{weight}    = 0;
    map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) }
      qw(listprice sellprice rop stock);

    my @flds = qw(id qty unit bom partnumber description sellprice weight runningnumber partsgroup lastcost);

    for my $i (1 .. ($form->{assembly_rows} - 1)) {
      if ($form->{"qty_$i"}) {
        push @a, {};
        my $j = $#a;

        $form->{"qty_$i"} = $form->parse_amount(\%myconfig, $form->{"qty_$i"});

        map { $a[$j]->{$_} = $form->{"${_}_$i"} } @flds;

        #($form->{"sellprice_$i"},$form->{"$pricegroup_old_$i"}) = split /--/, $form->{"sellprice_$i"};

        # fuer assemblies auskommentiert. siehe oben
        #    $form->{sellprice} += ($form->{"qty_$i"} * $form->{"sellprice_$i"} / ($form->{"price_factor_$i"} || 1));
        $form->{weight}    += ($form->{"qty_$i"} * $form->{"weight_$i"} / ($form->{"price_factor_$i"} || 1));
        $count++;
      }
    }
    # kann das hier auch weg? s.o. jb
    $form->{sellprice} = $form->round_amount($form->{sellprice}, 2);

    $form->redo_rows(\@flds, \@a, $count, $form->{assembly_rows});
    $form->{assembly_rows} = $count;

  } elsif ($form->{item} !~ m{^(?:part|service)$}) {
    remove_emptied_rows(1);

    $form->{creditremaining} -= &invoicetotal;
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

  $main::lxdebug->leave_sub();
}

sub remove_emptied_rows {
  my $dont_add_empty = shift;
  my $form           = $::form;

  return unless $form->{rowcount};

  my @flds = qw(id partnumber description qty ship sellprice unit
                discount inventory_accno income_accno expense_accno listprice
                taxaccounts bin assembly weight projectnumber project_id
                oldprojectnumber runningnumber serialnumber partsgroup payment_id
                not_discountable shop ve gv buchungsgruppen_id language_values
                sellprice_pg pricegroup_old price_old price_new unit_old ordnumber
                transdate longdescription basefactor marge_total marge_percent
                marge_price_factor lastcost price_factor_id partnotes
                stock_out stock_in has_sernumber reqdate);

  my $ic_cvar_configs = CVar->get_configs(module => 'IC');
  push @flds, map { "ic_cvar_$_->{name}" } @{ $ic_cvar_configs };

  my @new_rows;
  for my $i (1 .. $form->{rowcount} - 1) {
    next unless $form->{"partnumber_$i"};

    push @new_rows, { map { $_ => $form->{"${_}_$i" } } @flds };
  }

  my $new_rowcount = scalar @new_rows;
  $form->redo_rows(\@flds, \@new_rows, $new_rowcount, $form->{rowcount});
  $form->{rowcount} = $new_rowcount + ($dont_add_empty ? 0 : 1);
}

sub invoicetotal {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  _check_io_auth();

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
  for my $i (1 .. $form->{paidaccounts}) {
    $form->{oldtotalpaid} += $form->{"paid_$i"};
  }

  $main::lxdebug->leave_sub();

  # return total
  return ($form->{oldinvtotal} - $form->{oldtotalpaid});
}

sub validate_items {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  _check_io_auth();

  # check if items are valid
  if ($form->{rowcount} == 1) {
    flash('warning', $::locale->text('The action you\'ve chosen has not been executed because the document does not contain any item yet.'));
    &update;
    ::end_of_request();
  }

  for my $i (1 .. $form->{rowcount} - 1) {
    $form->isblank("partnumber_$i",
                   $locale->text('Number missing in Row') . " $i");
  }

  $main::lxdebug->leave_sub();
}

sub order {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  _check_io_auth();

  if ($form->{second_run}) {
    $form->{print_and_post} = 0;
  }
  $form->{ordnumber} = $form->{invnumber};

  $form->{old_employee_id} = $form->{employee_id};
  $form->{old_salesman_id} = $form->{salesman_id};

  map { delete $form->{$_} } qw(id printed emailed queued);
  my $buysell;
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
  $locale = new Locale($::lx_office_conf{system}->{language}, $script);

  map { $form->{"select$_"} = "" } ($form->{vc}, "currency");

  my $currency = $form->{currency};

  &order_links;

  $form->{currency}     = $currency;
  $form->{forex}        = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{transdate}, $buysell);
  $form->{exchangerate} = $form->{forex} || '';

  for my $i (1 .. $form->{rowcount}) {
    map({ $form->{"${_}_${i}"} = $form->parse_amount(\%myconfig, $form->{"${_}_${i}"})
            if ($form->{"${_}_${i}"}) }
        qw(ship qty sellprice listprice basefactor discount));
  }

  &prepare_order;
  &display_form;

  $main::lxdebug->leave_sub();
}

sub quotation {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  _check_io_auth();

  if ($form->{second_run}) {
    $form->{print_and_post} = 0;
  }
  map { delete $form->{$_} } qw(id printed emailed queued);

  my $buysell;
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

  map { $form->{"select$_"} = "" } ($form->{vc}, "currency");

  my $currency = $form->{currency};

  &order_links;

  $form->{currency}     = $currency;
  $form->{forex}        = $form->check_exchangerate( \%myconfig, $form->{currency}, $form->{transdate}, $buysell);
  $form->{exchangerate} = $form->{forex} || '';

  for my $i (1 .. $form->{rowcount}) {
    map({ $form->{"${_}_${i}"} = $form->parse_amount(\%myconfig,
                                                     $form->{"${_}_${i}"})
            if ($form->{"${_}_${i}"}) }
        qw(ship qty sellprice listprice basefactor discount));
  }

  &prepare_order;
  &display_form;

  $main::lxdebug->leave_sub();
}

sub request_for_quotation {
  quotation();
}

sub edit_e_mail {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  _check_io_auth();

  if ($form->{second_run}) {
    $form->{print_and_post} = 0;
    $form->{resubmit}       = 0;
  }

  $form->{email} = $form->{shiptoemail} if $form->{shiptoemail} && $form->{formname} =~ /(pick|packing|bin)_list/;

  if ($form->{"cp_id"}) {
    CT->get_contact(\%myconfig, $form);
    $form->{"email"} = $form->{"cp_email"} if $form->{"cp_email"};
  }

  $form->{language} = $form->get_template_language(\%myconfig);
  $form->{language} = "_" . $form->{language} if $form->{language};

  my $title = $locale->text('E-mail') . " " . $form->get_formname_translation();

  $form->{oldmedia} = $form->{media};
  $form->{media}    = "email";

  my $attachment_filename = $form->generate_attachment_filename();
  my $subject             = $form->{subject} || $form->generate_email_subject();

  $form->header;

  my (@dont_hide_key_list, %dont_hide_key, @hidden_keys);
  @dont_hide_key_list = qw(action email cc bcc subject message sendmode format header override login password);
  @dont_hide_key{@dont_hide_key_list} = (1) x @dont_hide_key_list;
  @hidden_keys = sort grep { !$dont_hide_key{$_} } grep { !ref $form->{$_} } keys %$form;

  print $form->parse_html_template('generic/edit_email',
                                   { title         => $title,
                                     a_filename    => $attachment_filename,
                                     subject       => $subject,
                                     print_options => print_options('inline' => 1),
                                     HIDDEN        => [ map +{ name => $_, value => $form->{$_} }, @hidden_keys ],
                                     SHOW_BCC      => $::auth->assert('email_bcc', 'may fail') });

  $main::lxdebug->leave_sub();
}

sub send_email {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  _check_io_auth();

  my $callback = $form->{script} . "?action=edit";
  map({ $callback .= "\&${_}=" . E($form->{$_}); } qw(type id));

  print_form("return");

  Common->save_email_status(\%myconfig, $form);

  $form->{callback} = $callback;
  $form->redirect();

  $main::lxdebug->leave_sub();
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
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  _check_io_auth();

  my %options = @_;

  # names 3 parameters and returns a hashref, for use in templates
  sub opthash { +{ value => shift, selected => shift, oname => shift } }
  my (@FORMNAME, @LANGUAGE_ID, @FORMAT, @SENDMODE, @MEDIA, @PRINTER_ID, @SELECTS) = ();

  # note: "||"-selection is only correct for values where "0" is _not_ a correct entry
  $form->{sendmode}   = "attachment";
  $form->{format}     = $form->{format} || $myconfig{template_format} || "pdf";
  $form->{copies}     = $form->{copies} || $myconfig{copies}          || 3;
  $form->{media}      = $form->{media}  || $myconfig{default_media}   || "screen";
  $form->{printer_id} = defined $form->{printer_id}           ? $form->{printer_id} :
                        defined $myconfig{default_printer_id} ? $myconfig{default_printer_id} : "";

  $form->{PD}{ $form->{formname} } = "selected";
  $form->{DF}{ $form->{format} }   = "selected";
  $form->{OP}{ $form->{media} }    = "selected";
  $form->{SM}{ $form->{formname} } = "selected";

  push @FORMNAME, grep $_,
    ($form->{type} eq 'purchase_order') ? (
      opthash("purchase_order",      $form->{PD}{purchase_order},      $locale->text('Purchase Order')),
      opthash("bin_list",            $form->{PD}{bin_list},            $locale->text('Bin List'))
    ) : undef,
    ($form->{type} eq 'credit_note') ?
      opthash("credit_note",         $form->{PD}{credit_note},         $locale->text('Credit Note')) : undef,
    ($form->{type} eq 'sales_order') ? (
      opthash("sales_order",         $form->{PD}{sales_order},         $locale->text('Confirmation')),
      opthash("proforma",            $form->{PD}{proforma},            $locale->text('Proforma Invoice')),
    ) : undef,
    ($form->{type} =~ /sales_quotation$/) ?
      opthash('sales_quotation',     $form->{PD}{sales_quotation},     $locale->text('Quotation')) : undef,
    ($form->{type} =~ /request_quotation$/) ?
      opthash('request_quotation',   $form->{PD}{request_quotation},   $locale->text('Request for Quotation')) : undef,
    ($form->{type} eq 'invoice') ? (
      opthash("invoice",             $form->{PD}{invoice},             $locale->text('Invoice')),
      opthash("proforma",            $form->{PD}{proforma},            $locale->text('Proforma Invoice')),
    ) : undef,
    ($form->{type} eq 'invoice' && $form->{storno}) ? (
      opthash("storno_invoice",      $form->{PD}{storno_invoice},      $locale->text('Storno Invoice')),
    ) : undef,
    ($form->{type} =~ /_delivery_order$/) ? (
      opthash($form->{type},         $form->{PD}{$form->{type}},       $locale->text('Delivery Order')),
      opthash('pick_list',           $form->{PD}{pick_list},           $locale->text('Pick List')),
    ) : undef;

  push @SENDMODE,
    opthash("attachment",            $form->{SM}{attachment},          $locale->text('Attachment')),
    opthash("inline",                $form->{SM}{inline},              $locale->text('In-line'))
      if ($form->{media} eq 'email');

  my $printable_templates = any { $::lx_office_conf{print_templates}->{$_} } qw(latex opendocument);
  push @MEDIA, grep $_,
      opthash("screen",              $form->{OP}{screen},              $locale->text('Screen')),
    ($printable_templates && $form->{printers} && scalar @{ $form->{printers} }) ?
      opthash("printer",             $form->{OP}{printer},             $locale->text('Printer')) : undef,
    ($printable_templates && !$options{no_queue}) ?
      opthash("queue",               $form->{OP}{queue},               $locale->text('Queue')) : undef
        if ($form->{media} ne 'email');

  push @FORMAT, grep $_,
    ($::lx_office_conf{print_templates}->{opendocument} &&     $::lx_office_conf{applications}->{openofficeorg_writer}  &&     $::lx_office_conf{applications}->{xvfb}
                                                        && (-x $::lx_office_conf{applications}->{openofficeorg_writer}) && (-x $::lx_office_conf{applications}->{xvfb})
     && !$options{no_opendocument_pdf}) ?
      opthash("opendocument_pdf",    $form->{DF}{"opendocument_pdf"},  $locale->text("PDF (OpenDocument/OASIS)")) : undef,
    ($::lx_office_conf{print_templates}->{latex}) ?
      opthash("pdf",                 $form->{DF}{pdf},                 $locale->text('PDF')) : undef,
    ($::lx_office_conf{print_templates}->{latex} && !$options{no_postscript}) ?
      opthash("postscript",          $form->{DF}{postscript},          $locale->text('Postscript')) : undef,
    (!$options{no_html}) ?
      opthash("html", $form->{DF}{html}, "HTML") : undef,
    ($::lx_office_conf{print_templates}->{opendocument} && !$options{no_opendocument}) ?
      opthash("opendocument",        $form->{DF}{opendocument},        $locale->text("OpenDocument/OASIS")) : undef,
    ($::lx_office_conf{print_templates}->{excel} && !$options{no_excel}) ?
      opthash("excel",               $form->{DF}{excel},               $locale->text("Excel")) : undef;

  push @LANGUAGE_ID,
    map { opthash($_->{id}, ($_->{id} eq $form->{language_id} ? 'selected' : ''), $_->{description}) } +{}, @{ $form->{languages} }
      if (ref $form->{languages} eq 'ARRAY');

  push @PRINTER_ID,
    map { opthash($_->{id}, ($_->{id} eq $form->{printer_id} ? 'selected' : ''), $_->{printer_description}) } +{}, @{ $form->{printers} }
      if ((ref $form->{printers} eq 'ARRAY') && scalar @{ $form->{printers } });

  @SELECTS = map {
    sname => $_->[1],
    DATA  => $_->[0],
    show  => !$options{"hide_" . $_->[1]} && scalar @{ $_->[0] }
  },
  [ \@FORMNAME,    'formname',    ],
  [ \@LANGUAGE_ID, 'language_id', ],
  [ \@FORMAT,      'format',      ],
  [ \@SENDMODE,    'sendmode',    ],
  [ \@MEDIA,       'media',       ],
  [ \@PRINTER_ID,  'printer_id',  ];

  my %dont_display_groupitems = (
    'dunning' => 1,
    );

  my %template_vars = (
    display_copies       => scalar @{ $form->{printers} || [] } && $::lx_office_conf{print_templates}->{latex} && $form->{media} ne 'email',
    display_remove_draft => (!$form->{id} && $form->{draft_id}),
    display_groupitems   => !$dont_display_groupitems{$form->{type}},
    groupitems_checked   => $form->{groupitems} ? "checked" : '',
    remove_draft_checked => $form->{remove_draft} ? "checked" : ''
  );

  my $print_options = $form->parse_html_template("generic/print_options", { SELECTS  => \@SELECTS, %template_vars } );

  if ($options{inline}) {
    $main::lxdebug->leave_sub();
    return $print_options;
  }

  print $print_options;

  $main::lxdebug->leave_sub();
}

sub print {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  _check_io_auth();

  if ($form->{print_nextsub}) {
    call_sub($form->{print_nextsub});
    $main::lxdebug->leave_sub();
    return;
  }

  # if this goes to the printer pass through
  my $old_form;
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
    $::lxdebug->leave_sub();
    ::end_of_request();
  }

  &print_form($old_form);

  $main::lxdebug->leave_sub();
}

sub print_form {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  _check_io_auth();

  my $defaults = SL::DB::Default->get;
  $form->error($::locale->text('No print templates have been created for this client yet. Please do so in the client configuration.')) if !$defaults->templates;
  $form->{templates} = $defaults->templates;

  my ($old_form) = @_;

  my $inv       = "inv";
  my $due       = "due";
  my $numberfld = "invnumber";
  my $order;

  my $display_form =
    ($form->{display_form}) ? $form->{display_form} : "display_form";

  # $form->{"notes"} will be overridden by the customer's/vendor's "notes" field. So save it here.
  $form->{ $form->{"formname"} . "notes" } = $form->{"notes"};

  if ($form->{formname} eq "invoice") {
    $form->{label} = $locale->text('Invoice');
  }
  if ($form->{formname} eq 'sales_order') {
    $inv                  = "ord";
    $due                  = "req";
    $form->{"${inv}date"} = $form->{transdate};
    $form->{label}        = $locale->text('Confirmation');
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
    $form->{label}        = $locale->text('RFQ');
    $numberfld            = "rfqnumber";
    $order                = 1;
  }

  if ($form->{type} =~ /_delivery_order$/) {
    undef $due;
    $inv                  = "do";
    $form->{"${inv}date"} = $form->{transdate};
    $numberfld            = $form->{type} =~ /^sales/ ? 'sdonumber' : 'pdonumber';
    $form->{label}        = $form->{formname} eq 'pick_list' ? $locale->text('Pick List') : $locale->text('Delivery Order');
  }

  $form->isblank("email", $locale->text('E-mail address missing!'))
    if ($form->{media} eq 'email');
  $form->isblank("${inv}date",
           $locale->text($form->{label})
           . ": "
           . $locale->text(' Date missing!'));

  # $locale->text('Invoice Number missing!')
  # $locale->text('Invoice Date missing!')
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
        $form->{snumbers} = "${inv}number" . "_" . $form->{"${inv}number"};
        $form->{addition} = "PRINTED";
        $form->save_history;
      }
      # /saving the history
      ::end_of_request();
    }
  }

  &validate_items;

  # Save the email address given in the form because it should override the setting saved for the customer/vendor.
  my ($saved_email, $saved_cc, $saved_bcc) =
    ($form->{"email"}, $form->{"cc"}, $form->{"bcc"});

  my $language_saved = $form->{language_id};
  my $payment_id_saved = $form->{payment_id};
  my $salesman_id_saved = $form->{salesman_id};
  my $cp_id_saved = $form->{cp_id};
  my $taxzone_id_saved = $form->{taxzone_id};
  my $currency_saved = $form->{currency};

  call_sub("$form->{vc}_details") if ($form->{vc});

  $form->{language_id} = $language_saved;
  $form->{payment_id} = $payment_id_saved;
  $form->{taxzone_id} = $taxzone_id_saved;
  $form->{currency} = $currency_saved;

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

  # Store the output number format so that the template modules know
  # how to parse the amounts back if requested.
  $myconfig{output_numberformat} = $output_numberformat || $myconfig{numberformat};

  ($form->{employee}) = split /--/, $form->{employee};

  # create the form variables
  if ($form->{type} =~ /_delivery_order$/) {
    DO->order_details(\%myconfig, \%$form);
  } elsif ($order) {
    OE->order_details(\%myconfig, \%$form);
  } else {
    IS->invoice_details(\%myconfig, \%$form, $locale);
  }

  $form->get_employee_data('prefix' => 'employee', 'id' => $form->{employee_id});
  $form->get_employee_data('prefix' => 'salesman', 'id' => $salesman_id_saved);

  if ($form->{shipto_id}) {
    $form->get_shipto(\%myconfig);
  }

  my @a = qw(name department_1 department_2 street zipcode city country contact phone fax email);

  my $shipto = 1;

  # if there is no shipto fill it in from billto
  foreach my $item (@a) {
    if ($form->{"shipto$item"}) {
      $shipto = 0;
      last;
    }
  }

  if ($shipto) {
    if (   $form->{formname} eq 'purchase_order'
        || $form->{formname} eq 'request_quotation') {
      $form->{shiptoname}   = $defaults->company;
      $form->{shiptostreet} = $defaults->address;
    } else {
      map { $form->{"shipto$_"} = $form->{$_} } @a;
    }
  }

  $form->{notes} =~ s/^\s+//g;

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
    my $template_arrays = $form->{TEMPLATE_ARRAYS} || $form;
    map { $template_arrays->{unit}->[$_] = AM->translate_units($form, $form->{language}, $template_arrays->{unit}->[$_], $template_arrays->{qty}->[$_]); } (0..scalar(@{ $template_arrays->{unit} }) - 1);

    $form->{language} = "_" . $form->{language};
  }

  # Format dates.
  format_dates($output_dateformat, $output_longdates,
               qw(invdate orddate quodate pldate duedate reqdate transdate
                  shippingdate deliverydate validitydate paymentdate
                  datepaid transdate_oe deliverydate_oe dodate
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
                      tax taxbase total paid payment),
                   grep({ /^(?:linetotal|nodiscount_linetotal|listprice|sellprice|netprice|taxbase|discount|p_discount|discount_sub|nodiscount_sub|paid|subtotal|total|tax)_\d+$/ } keys(%{$form})));

  reformat_numbers($output_numberformat, undef,
                   qw(qty price_factor),
                   grep({ /^qty_\d+$/
                        } keys(%{$form})));

  my ($cvar_date_fields, $cvar_number_fields) = CVar->get_field_format_list('module' => 'CT', 'prefix' => 'vc_');

  if (scalar @{ $cvar_date_fields }) {
    format_dates($output_dateformat, $output_longdates, @{ $cvar_date_fields });
  }

  while (my ($precision, $field_list) = each %{ $cvar_number_fields }) {
    reformat_numbers($output_numberformat, $precision, @{ $field_list });
  }

  my $extension = 'html';
  if ($form->{format} eq 'postscript') {
    $form->{postscript}   = 1;
    $extension            = 'tex';

  } elsif ($form->{"format"} =~ /pdf/) {
    $form->{pdf}          = 1;
    $extension            = $form->{'format'} =~ m/opendocument/i ? 'odt' : 'tex';

  } elsif ($form->{"format"} =~ /opendocument/) {
    $form->{opendocument} = 1;
    $extension            = 'odt';
  } elsif ($form->{"format"} =~ /excel/) {
    $form->{excel} = 1;
    $extension            = 'xls';
  }

  # search for the template
  my @template_files;
  push @template_files, "$form->{formname}_email$form->{language}$printer_code.$extension" if $form->{media} eq 'email';
  push @template_files, "$form->{formname}$form->{language}$printer_code.$extension";
  push @template_files, "$form->{formname}.$extension";
  push @template_files, "default.$extension";
  @template_files = uniq @template_files;
  $form->{IN}     = first { -f ($defaults->templates . "/$_") } @template_files;

  if (!defined $form->{IN}) {
    $::form->error($::locale->text('Cannot find matching template for this print request. Please contact your template maintainer. I tried these: #1.', join ', ', map { "'$_'"} @template_files));
  }

  delete $form->{OUT};

  if ($form->{media} eq 'printer') {
    $form->{OUT}      = $form->{printer_command};
    $form->{OUT_MODE} = '|-';
    $form->{printed} .= " $form->{formname}";
    $form->{printed}  =~ s/^ //;
  }
  my $printed = $form->{printed};

  if ($form->{media} eq 'email') {
    $form->{subject} = qq|$form->{label} $form->{"${inv}number"}|
      unless $form->{subject};

    $form->{emailed} .= " $form->{formname}";
    $form->{emailed} =~ s/^ //;
  }
  my $emailed = $form->{emailed};

  if ($form->{media} eq 'queue') {
    my %queued = map { s|.*[/\\]||; $_ } split / /, $form->{queued};

    my $filename;
    my $suffix = ($form->{postscript}) ? '.ps' : '.pdf';
    if ($filename = $queued{ $form->{formname} }) {
      unlink $::lx_office_conf{paths}->{spool} . "/$filename";
      delete $queued{ $form->{formname} };

      $form->{queued}    =  join ' ', %queued;
      $filename          =~ s/\..*$//g;
      $filename         .=  $suffix;
      $form->{OUT}       =  $::lx_office_conf{paths}->{spool} . "/$filename";
      $form->{OUT_MODE}  =  '>';

    } else {
      my $temp_fh;
      ($temp_fh, $filename) = File::Temp::tempfile(
        'kivitendo-spoolXXXXXX',
        SUFFIX => "$suffix",
        DIR    => $::lx_office_conf{paths}->{spool},
        UNLINK => 0,
      );
      close $temp_fh;
      $form->{OUT} = "$filename";
      # use >> for OUT_MODE because file is already created by File::Temp
      $form->{OUT_MODE} = '>>';
      # strip directory so that only filename is stored in table status
      ($filename) = $filename =~ /^$::lx_office_conf{paths}->{spool}\/(.*)/;
    }

    # add type
    $form->{queued} .= " $form->{formname} $filename";
    $form->{queued} =~ s/^ //;
  }
  my $queued = $form->{queued};

# saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers} = "${inv}number" . "_" . $form->{"${inv}number"};
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
    $form->save_history;
  }
  # /saving the history

  # prepare meta information for template introspection
  $form->{template_meta} = {
    formname  => $form->{formname},
    language  => SL::DB::Manager::Language->find_by_or_create(id => $form->{language_id} || undef),
    format    => $form->{format},
    media     => $form->{media},
    extension => $extension,
    printer   => SL::DB::Manager::Printer->find_by_or_create(id => $form->{printer_id} || undef),
    today     => DateTime->today,
  };

  $form->parse_template(\%myconfig);

  $form->{callback} = "";

  if ($form->{media} eq 'email') {
    $form->{message} = $locale->text('sent') unless $form->{message};
  }
  my $message = $form->{message};

  # if we got back here restore the previous form
  if ($form->{media} =~ /(printer|email|queue)/) {

    $form->update_status(\%myconfig)
      if ($form->{media} eq 'queue' && $form->{id});

    return $main::lxdebug->leave_sub() if ($old_form eq "return");

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

      for my $i (1 .. $form->{paidaccounts}) {
        map {
          $form->{"${_}_$i"} =
            $form->parse_amount(\%myconfig, $form->{"${_}_$i"})
        } qw(paid exchangerate);
      }

      call_sub($display_form);
      ::end_of_request();
    }

    my $msg =
      ($form->{media} eq 'printer')
      ? $locale->text('sent to printer')
      : $locale->text('emailed to') . " $form->{email}";
    $form->redirect(qq|$form->{label} $form->{"${inv}number"} $msg|);
  }
  if ($form->{printing}) {
   call_sub($display_form);
   ::end_of_request();
  }

  $main::lxdebug->leave_sub();
}

sub customer_details {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  IS->customer_details(\%myconfig, \%$form, @_);

  $main::lxdebug->leave_sub();
}

sub vendor_details {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  IR->vendor_details(\%myconfig, \%$form, @_);

  $main::lxdebug->leave_sub();
}

sub post_as_new {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  _check_io_auth();

  $form->{postasnew} = 1;
  map { delete $form->{$_} } qw(printed emailed queued);

  &post;

  $main::lxdebug->leave_sub();
}

sub ship_to {
  $main::lxdebug->enter_sub();

  _check_io_auth();

  $::form->{print_and_post} = 0 if $::form->{second_run};

  map { $::form->{$_} = $::form->parse_amount(\%::myconfig, $::form->{$_}) } qw(exchangerate creditlimit creditremaining);

  # get details for customer/vendor
  call_sub($::form->{vc} . "_details", qw(name department_1 department_2 street zipcode city country contact email phone fax), $::form->{vc} . "number");

  # get pricegroups for parts
  IS->get_pricegroups_for_parts(\%::myconfig, \%$::form);

  # build up html code for prices_$i
  set_pricegroup($::form->{rowcount});

  $::form->{rowcount}--;

  my @shipto_vars   = qw(shiptoname shiptostreet shiptozipcode shiptocity shiptocountry
                         shiptocontact shiptocp_gender shiptophone shiptofax shiptoemail
                         shiptodepartment_1 shiptodepartment_2);
  my $previous_form = $::auth->save_form_in_session(skip_keys => [ @shipto_vars, qw(header shipto_id) ]);
  $::form->{title}  = $::locale->text('Ship to');
  $::form->header;

  print $::form->parse_html_template('io/ship_to', { previousform => $previous_form,
                                                     nextsub      => $::form->{display_form} || 'display_form',
                                                   });

  $main::lxdebug->leave_sub();
}

sub ship_to_entered {
  $::auth->restore_form_from_session(delete $::form->{previousform});
  call_sub($::form->{nextsub});
}

sub relink_accounts {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  _check_io_auth();

  $form->{"taxaccounts"} =~ s/\s*$//;
  $form->{"taxaccounts"} =~ s/^\s*//;
  foreach my $accno (split(/\s*/, $form->{"taxaccounts"})) {
    map({ delete($form->{"${accno}_${_}"}); } qw(rate description taxnumber));
  }
  $form->{"taxaccounts"} = "";

  IC->retrieve_accounts(\%myconfig, $form, map { $_ => $form->{"id_$_"} } 1 .. $form->{rowcount});

  $main::lxdebug->leave_sub();
}

sub set_duedate {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  _check_io_auth();

  my $invdate = $form->{invdate} eq 'undefined' ? undef : $form->{invdate};
  my $duedate = $form->get_duedate(\%myconfig, $invdate);

  print $form->ajax_response_header() . ($duedate || $invdate);

  $main::lxdebug->leave_sub();
}

sub _update_part_information {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  my %part_information = IC->get_basic_part_info('id'        => [ grep { $_ } map { $form->{"id_${_}"} } (1..$form->{rowcount}) ],
                                                 'vendor_id' => $form->{vendor_id});

  $form->{PART_INFORMATION} = \%part_information;

  foreach my $i (1..$form->{rowcount}) {
    next unless ($form->{"id_${i}"});

    my $info                 = $form->{PART_INFORMATION}->{$form->{"id_${i}"}} || { };
    $form->{"partunit_${i}"} = $info->{unit};
    $form->{"weight_$i"}     = $info->{weight};
  }

  $main::lxdebug->leave_sub();
}

sub _update_ship {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  if (!$form->{ordnumber} || !$form->{id}) {
    map { $form->{"ship_$_"} = 0 } (1..$form->{rowcount});
    $main::lxdebug->leave_sub();
    return;
  }

  my $all_units = AM->retrieve_all_units();

  my %ship = DO->get_shipped_qty('type'  => ($form->{type} eq 'purchase_order') ? 'purchase' : 'sales',
                                 'oe_id' => $form->{id},);

  foreach my $i (1..$form->{rowcount}) {
    next unless ($form->{"id_${i}"});

    $form->{"ship_$i"} = 0;

    my $ship_entry = $ship{$form->{"id_$i"}};

    next if (!$ship_entry || ($ship_entry->{qty} <= 0));

    my $rowqty =
      ($form->{simple_save} ? $form->{"qty_$i"} : $form->parse_amount(\%myconfig, $form->{"qty_$i"}))
      * $all_units->{$form->{"unit_$i"}}->{factor}
      / $all_units->{$form->{"partunit_$i"}}->{factor};

    $form->{"ship_$i"}  = min($rowqty, $ship_entry->{qty});
    $ship_entry->{qty} -= $form->{"ship_$i"};
  }

  foreach my $i (1..$form->{rowcount}) {
    next unless ($form->{"id_${i}"});

    my $ship_entry = $ship{$form->{"id_$i"}};

    next if (!$ship_entry || ($ship_entry->{qty} <= 0.01));

    $form->{"ship_$i"} += $ship_entry->{qty};
    $ship_entry->{qty}  = 0;
  }

  $main::lxdebug->leave_sub();
}

sub _update_custom_variables {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  $form->{CVAR_CONFIGS}         = { } unless ref $form->{CVAR_CONFIGS} eq 'HASH';
  $form->{CVAR_CONFIGS}->{IC} ||= CVar->get_configs(module => 'IC');

  $main::lxdebug->leave_sub();
}

sub _render_custom_variables_inputs {
  $main::lxdebug->enter_sub(2);

  my $form     = $main::form;

  my %params = @_;

  if (!$form->{CVAR_CONFIGS}->{IC}) {
    $main::lxdebug->leave_sub();
    return;
  }

  my $valid = CVar->custom_variables_validity_by_trans_id(trans_id => $params{part_id});

  my $num_visible_cvars = 0;
  foreach my $cvar (@{ $form->{CVAR_CONFIGS}->{IC} }) {
    $cvar->{valid} = $params{part_id} && $valid->($cvar->{id});

    my $description = '';
    if ($cvar->{flag_editable} && $cvar->{valid}) {
      $num_visible_cvars++;
      $description = $cvar->{description} . ' ';
    }

    my $form_key = "ic_cvar_" . $cvar->{name} . "_$params{row}";

    push @{ $params{ROW2} }, {
      line_break     => $num_visible_cvars == 1,
      description    => $description,
      cvar           => 1,
      render_options => {
         hide_non_editable => 1,
         var               => $cvar,
         name_prefix       => 'ic_',
         name_postfix      => "_$params{row}",
         valid             => $cvar->{valid},
         value             => CVar->parse($::form->{$form_key}, $cvar),
      }
    };
  }

  $main::lxdebug->leave_sub(2);
}

sub _remove_billed_or_delivered_rows {
  my (%params) = @_;

  croak "Missing parameter 'quantities'" if !$params{quantities};

  my @fields = map { s/_1$//; $_ } grep { m/_1$/ } keys %{ $::form };
  my @new_rows;

  my $removed_rows = 0;
  my $row          = 0;
  while ($row < $::form->{rowcount}) {
    $row++;
    next unless $::form->{"id_$row"};

    my $parts_id                      = $::form->{"id_$row"};
    my $base_qty                      = $::form->parse_amount(\%::myconfig, $::form->{"qty_$row"}) * SL::DB::Manager::Unit->find_by(name => $::form->{"unit_$row"})->base_factor;

    my $sub_qty                       = min($base_qty, $params{quantities}->{$parts_id});
    $params{quantities}->{$parts_id} -= $sub_qty;

    if (!$sub_qty || ($sub_qty != $base_qty)) {
      $::form->{"qty_${row}"} = $::form->format_amount(\%::myconfig, ($base_qty - $sub_qty) / SL::DB::Manager::Unit->find_by(name => $::form->{"unit_$row"})->base_factor);
      push @new_rows, { map { $_ => $::form->{"${_}_${row}"} } @fields };

    } else {
      $removed_rows++;
    }
  }

  $::form->redo_rows(\@fields, \@new_rows, scalar(@new_rows), $::form->{rowcount});
  $::form->{rowcount} -= $removed_rows;
}
