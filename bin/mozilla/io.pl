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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1335, USA.
#
#######################################################################
#
# common routines used in is, ir, oe
#
#######################################################################

use Carp;
use CGI;
use List::MoreUtils qw(any uniq apply);
use List::Util qw(sum min max first);
use List::UtilsBy qw(sort_by uniq_by);

use SL::ClientJS;
use SL::CVar;
use SL::Common;
use SL::Controller::Base;
use SL::CT;
use SL::Locale::String qw(t8);
use SL::IC;
use SL::IO;
use SL::File;
use SL::PriceSource;
use SL::Presenter::Part;
use SL::Presenter::Chart;
use SL::Presenter::Tag;
use SL::Util qw(trim);

use SL::DB::AuthUser;
use SL::DB::Contact;
use SL::DB::Currency;
use SL::DB::Customer;
use SL::DB::DeliveryOrder::TypeData qw();
use SL::DB::Default;
use SL::DB::Language;
use SL::DB::Printer;
use SL::DB::Vendor;
use SL::Helper::CreatePDF;
use SL::Helper::Flash;
use SL::Helper::PrintOptions;
use SL::Helper::ShippedQty;

require "bin/mozilla/common.pl";

use strict;

# any custom scripts for this one
if (-f "bin/mozilla/custom_io.pl") {
  eval { require "bin/mozilla/custom_io.pl"; };
}
if (-f "bin/mozilla/$::myconfig{login}_io.pl") {
  eval { require "bin/mozilla/$::myconfig{login}_io.pl"; };
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
  my $is_delivery_order  = $form->{type} =~ /_delivery_order$/;
  my $is_quotation       = $form->{type} =~ /_quotation$/;
  my $is_invoice         = $form->{type} =~ /invoice/;
  my $is_credit_note     = $form->{type} =~ /credit_note/;
  my $is_s_p_order       = (first { $_ eq $form->{type} } qw(sales_order purchase_order));
  my $show_ship_missing  = $is_s_p_order && $::instance_conf->get_sales_purchase_order_ship_missing_column;
  my $show_marge         = (!$is_purchase || $is_invoice || $is_credit_note) && !$is_delivery_order;

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
  my @header_sort = qw(
    runningnumber partnumber vendor_partnumber type_and_classific description ship ship_missing qty price_factor
    unit weight price_source sellprice discount linetotal
    bin stock_in_out
  );
  # position of serialnr is used below!
  my @row2_sort   = qw(
    tax_chart tax serialnr projectnr reqdate subtotal recurring_billing_mode marge listprice lastcost onhand
    orderer
  );
  # serialnr is important for delivery_orders
  if ($form->{type} eq 'sales_delivery_order') {
    splice @row2_sort, 0, 3;
    splice @header_sort, 4, 0, "serialnr";
  }

  my %column_def = (
    runningnumber => { width => 5,     value => $locale->text('No.'),                  display => 1, },
    partnumber    => { width => 8,     value => $locale->text('Number'),               display => 1, },
    type_and_classific
                  => { width => 2,     value => $locale->text('Type'),                 display => 1, },
    description   => { width => 30,    value => $locale->text('Part Description'),     display => 1, },
    ship          => { width => 5,     value => $locale->text('Delivered'),            display => $is_s_p_order, },
    ship_missing  => { width => 5,     value => $locale->text('Not delivered'),        display => $show_ship_missing, },
    qty           => { width => 5,     value => $locale->text('Qty'),                  display => 1, },
    price_factor  => { width => 5,     value => $locale->text('Price Factor'),         display => !$is_delivery_order, },
    unit          => { width => 5,     value => $locale->text('Unit'),                 display => 1, },
    weight        => { width => 5,     value => $locale->text('Weight'),               display => $defaults->{show_weight}, },
    serialnr      => { width => 10,    value => $locale->text('Serial No.'),           display => !$is_quotation },
    projectnr     => { width => 10,    value => $locale->text('Project'),              display => 1, },
    price_source  => { width => 5,     value => $locale->text('Price Source'),         display => !$is_delivery_order, },
    sellprice     => { width => 15,    value => $locale->text('Price'),                display => !$is_delivery_order, },
    discount      => { width => 5,     value => $locale->text('Discount'),             display => !$is_delivery_order, },
    linetotal     => { width => 10,    value => $locale->text('Extended'),             display => !$is_delivery_order, },
    bin           => { width => 10,    value => $locale->text('Bin'),                  display => 0, },
    stock_in_out  => { width => 10,    value => $stock_in_out_title,                   display => $is_delivery_order, },
    reqdate       => {                 value => $locale->text('Reqdate'),              display => $is_s_p_order || $is_delivery_order || $is_invoice, },
    subtotal      => {                 value => $locale->text('Subtotal'),             display => 1, },
    recurring_billing_mode => {        value => $locale->text('Recurring billing'),    display => $form->{type} eq 'sales_order', },
    marge         => {                 value => $locale->text('Ertrag'),               display => $show_marge, },
    listprice     => {                 value => $locale->text('LP'),                   display => $show_marge, },
    lastcost      => {                 value => $locale->text('EK'),                   display => $show_marge, },
    onhand        => {                 value => $locale->text('On Hand'),              display => 1, },
    vendor_partnumber => { width => 8, value => $locale->text('Vendor Part Number'),   display => $is_delivery_order && $is_purchase, },
    tax_chart     => {                 value => "",                                    display => $is_purchase && $is_invoice },
    tax           => {                 value => $locale->text('Tax'),                  display => $is_purchase && $is_invoice },
    orderer       => { width => 10,    value => $locale->text('Orderer'),              display => 1, },
  );
  my @HEADER = map { $column_def{$_} } @header_sort;

  # cache units
  my $all_units       = AM->retrieve_units(\%myconfig, $form);

  my %price_factors   = map { $_->{id} => $_->{factor} } @{ $form->{ALL_PRICE_FACTORS} };


  $form->{invsubtotal} = 0;
  map { $form->{"${_}_base"} = 0 } (split(/ /, $form->{taxaccounts}));

  # about details
  $myconfig{show_form_details} = 1                            unless (defined($myconfig{show_form_details}));
  $form->{show_details}        = $myconfig{show_form_details} unless (defined($form->{show_details}));
  # /about details

  # translations, unused commented out
  my $deliverydate  = $locale->text('Required by');

  # special alignings
  my %align  = map { $_ => 'right' } qw(qty ship right discount linetotal stock_in_out weight ship_missing);
  my %nowrap = map { $_ => 1 }       qw(description unit  price_source);

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

  my $record = _make_record();
  # rows

  my @ROWS;
  my $pos_level0 = 0;
  my $pos_level1 = 0;
  my $subtotal_active = 0;
  for my $i (1 .. $numrows) {
    my %column_data = ();

    my $record_item = $record->id && $record->items ? $record->items->[$i-1] : _make_record_item($i);

    # undo formatting
    map { $form->{"${_}_$i"} = $form->parse_amount(\%myconfig, $form->{"${_}_$i"}) }
      qw(qty discount sellprice lastcost price_new price_old)
        unless ($form->{simple_save});

    if ($form->{"prices_$i"} && ($form->{"new_pricegroup_$i"} != $form->{"old_pricegroup_$i"})) {
      $form->{"sellprice_$i"} = $form->{"price_new_$i"};
    }

# unit begin
    $form->{"unit_old_$i"}      ||= $form->{"unit_$i"};
    $form->{"selected_unit_$i"} ||= $form->{"unit_$i"};

    if (   !$all_units->{$form->{"selected_unit_$i"}}                                            # Die ausgewaehlte Einheit ist fuer diesen Artikel nicht gueltig
        || !AM->convert_unit($form->{"selected_unit_$i"}, $form->{"unit_old_$i"}, $all_units)) { # (z.B. Dimensionseinheit war ausgewaehlt, es handelt sich aber
      $form->{"unit_old_$i"} = $form->{"selected_unit_$i"} = $form->{"unit_$i"};                 # um eine Dienstleistung). Dann keinerlei Umrechnung vornehmen.
    }

    $form->{"sellprice_$i"} *= AM->convert_unit($form->{"selected_unit_$i"}, $form->{"unit_old_$i"}, $all_units) || 1;
    $form->{"lastcost_$i"} *= AM->convert_unit($form->{"selected_unit_$i"}, $form->{"unit_old_$i"}, $all_units) || 1;
    $form->{"unit_old_$i"}   = $form->{"selected_unit_$i"};

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

    my $position;
    if (!$subtotal_active) {
      $pos_level0 += 1;
      $pos_level1  = 0;
      $position = "$pos_level0";
    } else {
      $pos_level1 += 1;
      $position = "$pos_level0.$pos_level1";
    }
    $subtotal_active ^= $form->{"subtotal_$i"};

    # quick delete single row
    $column_data{runningnumber}  = q|<a onclick= "$('#partnumber_| . $i . q|').val(''); $('#update_button').click();">| .
                                   q|<img class="icon-delete" alt="| . $locale->text('Remove') . q|"></a> |;
    $column_data{runningnumber} .= $cgi->textfield(-name => "runningnumber_$i", -id => "runningnumber_$i", -size => 5,  -value => $position);    # HuT


    $column_data{partnumber}    = $cgi->textfield(-name => "partnumber_$i",    -id => "partnumber_$i",    -size => 12, -value => $form->{"partnumber_$i"});
    $column_data{vendor_partnumber} = $form->{"vendor_partnumber_$i"};
    $column_data{type_and_classific} = SL::Presenter::Part::type_abbreviation($form->{"part_type_$i"}).
                                       SL::Presenter::Part::classification_abbreviation($form->{"classification_id_$i"}) if $form->{"id_$i"};
    $column_data{description} = (($rows > 1) # if description is too large, use a textbox instead
                                ? $cgi->textarea( -name => "description_$i", -id => "description_$i", -default => $form->{"description_$i"}, -rows => $rows, -columns => 30)
                                : $cgi->textfield(-name => "description_$i", -id => "description_$i",   -value => $form->{"description_$i"}, -size => 30))
                                . $cgi->button(-value => $locale->text('L'), -onClick => "kivi.SalesPurchase.edit_longdescription($i)");

    my $qty_dec = ($form->{"qty_$i"} =~ /\.(\d+)/) ? length $1 : 2;

    $column_data{qty}  = $cgi->textfield(-name => "qty_$i", -size => 5, -class => "numeric", -value => $form->format_amount(\%myconfig, $form->{"qty_$i"}, $qty_dec));
    $column_data{qty} .= $cgi->button(-onclick => "calculate_qty_selection_dialog('qty_$i', '', 'formel_$i', '')", -value => $locale->text('*/'))
                       . $cgi->hidden(-name => "formel_$i", -value => $form->{"formel_$i"})
      if $form->{"formel_$i"};

    $column_data{ship} = '';
    if ($form->{"id_$i"}) {
      my $ship_qty        = $form->{"ship_$i"} * 1;
      $ship_qty          *= $all_units->{$form->{"partunit_$i"}}->{factor};
      $ship_qty          /= ( $all_units->{$form->{"unit_$i"}}->{factor} || 1 );

      $column_data{ship}  = $form->format_amount(\%myconfig, $form->round_amount($ship_qty, 2) * 1) . ' ' . $form->{"unit_$i"}
      . $cgi->hidden(-name => "ship_$i", -value => $form->{"ship_$i"}, $qty_dec);

      my $ship_missing_qty    = $form->{"qty_$i"} - $ship_qty;
      my $ship_missing_amount = $form->round_amount($ship_missing_qty * $form->{"sellprice_$i"} * (100 - $form->{"discount_$i"}) / 100 / $price_factor, 2);

      $column_data{ship_missing} = $form->format_amount(\%myconfig, $ship_missing_qty) . ' ' . $form->{"unit_$i"} . '; ' . $form->format_amount(\%myconfig, $ship_missing_amount, $decimalplaces);
    }

    $column_data{linetotal}   = $form->format_amount(\%myconfig, $linetotal, 2);
    $column_data{bin}         = $form->{"bin_$i"};

    $column_data{weight}      = $form->format_amount(\%myconfig, $form->{"qty_$i"} * $form->{"weight_$i"}, 3) . ' ' . $defaults->{weightunit} if $defaults->{show_weight};

    my $sellprice_value = $form->format_amount(\%myconfig, $form->{"sellprice_$i"}, $decimalplaces);
    my $discount_value  = $form->format_amount(\%myconfig, $form->{"discount_$i"});

    my $price;
    if ($form->{"id_${i}"} && !$is_delivery_order) {
      my $price_source  = SL::PriceSource->new(record_item => $record_item, record => $record);
         $price         = $price_source->price_from_source($::form->{"active_price_source_$i"});
      my $discount      = $price_source->discount_from_source($::form->{"active_discount_source_$i"});
      my $best_price    = $price_source->best_price;
      my $best_discount = $price_source->best_discount;
      $column_data{price_source} .= $cgi->button(-value => $price->source_description, -onClick => "kivi.io.price_chooser($i)");
      if ($price->source) {
        $column_data{price_source} .= ' ' . $cgi->img({src => 'image/flag-red.png', alt => $price->invalid, title => $price->invalid }) if $price->invalid;
        $column_data{price_source} .= ' ' . $cgi->img({src => 'image/flag-red.png', alt => $price->missing, title => $price->missing }) if $price->missing;
        if (!$price->missing && !$price->invalid) {
          $column_data{price_source} .= ' ' . $cgi->img({src => 'image/up.png',   alt => t8('This price has since gone up'),      title => t8('This price has since gone up' )     }) if $price->price - $record_item->sellprice > 0.01;
          $column_data{price_source} .= ' ' . $cgi->img({src => 'image/down.png', alt => t8('This price has since gone down'),    title => t8('This price has since gone down')    }) if $price->price - $record_item->sellprice < -0.01;
          $column_data{price_source} .= ' ' . $cgi->img({src => 'image/ok.png',   alt => t8('There is a better price available'), title => t8('There is a better price available') }) if $best_price && $price->source ne $price_source->best_price->source;
        }
      }
      if ($discount->source) {
        $column_data{discount_source} .= ' ' . $cgi->img({src => 'image/flag-red.png', alt => $discount->invalid, title => $discount->invalid }) if $discount->invalid;
        $column_data{discount_source} .= ' ' . $cgi->img({src => 'image/flag-red.png', alt => $discount->missing, title => $discount->missing }) if $discount->missing;
        if (!$discount->missing && !$discount->invalid) {
          $column_data{price_source} .= ' ' . $cgi->img({src => 'image/up.png',   alt => t8('This discount has since gone up'),      title => t8('This discount has since gone up')      }) if $discount->discount * 100 - $record_item->discount > 0.01;
          $column_data{price_source} .= ' ' . $cgi->img({src => 'image/down.png', alt => t8('This discount has since gone down'),    title => t8('This discount has since gone down')    }) if $discount->discount * 100 - $record_item->discount < -0.01;
          $column_data{price_source} .= ' ' . $cgi->img({src => 'image/ok.png',   alt => t8('There is a better discount available'), title => t8('There is a better discount available') }) if $best_discount && $discount->source ne $price_source->best_discount->source;
        }
      }
    }

    my $right_to_edit_prices  = (!$is_purchase && $main::auth->assert('sales_edit_prices', 1)) || ($is_purchase && $main::auth->assert('purchase_edit_prices', 1));
    my $edit_prices           = $right_to_edit_prices && (!$::form->{"active_price_source_$i"} || !$price || $price->editable);
    my $edit_discounts        = $right_to_edit_prices && !$::form->{"active_discount_source_$i"};
    $column_data{sellprice}   = (!$edit_prices)
                                ? $cgi->hidden(   -name => "sellprice_$i", -id => "sellprice_$i", -value => $sellprice_value) . $sellprice_value
                                : $cgi->textfield(-name => "sellprice_$i", -id => "sellprice_$i", -size => 10, -class => "numeric", -value => $sellprice_value);
    $column_data{discount}    = (!$edit_discounts)
                                  ? $cgi->hidden(   -name => "discount_$i", -id => "discount_$i", -value => $discount_value) . $discount_value . ' %'
                                  : $cgi->textfield(-name => "discount_$i", -id => "discount_$i", -size => 3, -"data-validate" => "number", -class => "numeric", -value => $discount_value);

    if ($is_delivery_order) {
      $column_data{stock_in_out} =  calculate_stock_in_out($i);
    }

    # tax_chart and tax
    if ($is_purchase && $is_invoice) { #only calc if used
      my ($tax_chart_id, $chart_title, $chart_picker);
      if ($record_item && $record_item->part && ($record_item->part->type eq 'part')) {
        my $tax_chart_type = $form->{"tax_chart_type_$i"};
        $tax_chart_type ||=
          $::instance_conf->get_inventory_system eq 'periodic' ? 'expense'
                                                               : 'inventory';
        $tax_chart_id = $form->{"${tax_chart_type}_chart_id_$i"};

        $chart_title = SL::Presenter::Tag::select_tag("tax_chart_type_$i", [
            {value => 'expense',   title => $locale->text('Expense Account')},
            {value => 'inventory', title => $locale->text('Inventory Account')},
          ],
          value_key => 'value', title_key => 'title',
          default  => $tax_chart_type,
          onchange => "kivi.io.update_tax_chart_picker(this.value, $i)",
        );

        $chart_picker =
          SL::Presenter::Tag::html_tag('span',
            SL::Presenter::Chart::chart_picker(
              "expense_chart_id_$i", $form->{"expense_chart_id_$i"},
              type => "AP_amount", style => "width: 150px"),
            id => "expense_chart_span_$i",
            style => $tax_chart_type eq 'expense' ? '' : 'display:none',
          )
          .
          SL::Presenter::Tag::html_tag('span',
            SL::Presenter::Chart::chart_picker(
              "inventory_chart_id_$i", $form->{"inventory_chart_id_$i"},
              type => "IC", style => "width: 150px"),
            id => "inventory_chart_span_$i",
            style => $tax_chart_type eq 'inventory' ? '' : 'display:none',
          );
      } else {
        $tax_chart_id = $form->{"expense_chart_id_$i"};
        $chart_title = $locale->text('Expense Account');
        $chart_picker = SL::Presenter::Chart::chart_picker(
          "expense_chart_id_$i", $form->{"expense_chart_id_$i"},
          type => "AP_amount", style => "width: 150px");
      }
      # change tax dropdown after change
      my $js_set_on_select_item = '<script type="text/javascript">
        <!--
        $(document).ready(function() {
          $("#expense_chart_id_' . $i . '").on("set_item:ChartPicker", function(e, item) {
            kivi.io.update_tax_ids(this);
          });
          $("#inventory_chart_id_' . $i . '").on("set_item:ChartPicker", function(e, item) {
            kivi.io.update_tax_ids(this);
          });
        });
        -->
        </script>
        ';
      $column_data{tax_chart} = SL::Presenter::Tag::html_tag('span',
        $chart_title . $chart_picker . $js_set_on_select_item);

      my $tax_value_title_sub = sub {
        my $item = shift;
        return [
          $item->{id},
          $item->{taxkey} . ' - ' . $item->{taxdescription} .' '. ($item->{rate} * 100) .' %',
        ];
      };

      my @taxes = ();
      if ($form->{"expense_chart_id_$i"}) {
        @taxes = IO->get_active_taxes_for_chart($tax_chart_id,
          $form->{"reqdate_$i"} // $form->{deliverydate} // $form->{transdate});
      }
      # tax_id_ is used in io.js->update_tax_ids
      $column_data{tax} = SL::Presenter::Tag::select_tag(
        "tax_id_$i", \@taxes, default => $form->{"tax_id_$i"},
        value_title_sub => $tax_value_title_sub,
        style => "width: 100px");
    }

    $column_data{serialnr}  = qq|<input name="serialnumber_$i" size="15" value="$form->{"serialnumber_$i"}" data-validate="trimmed_whitespaces">|;
    $column_data{projectnr} = NTI($cgi->popup_menu(
      '-name' => "project_id_$i",
      '-values' => \@projectnumber_values,
      '-labels' => \%projectnumber_labels,
      '-default' => $form->{"project_id_$i"}
    ));
    $column_data{reqdate}   = qq|<input name="reqdate_$i" size="11" data-validate="date" value="$form->{"reqdate_$i"}">|;
    $column_data{subtotal}  = sprintf qq|<input type="checkbox" name="subtotal_$i" value="1" %s>|, $form->{"subtotal_$i"} ? 'checked' : '';
    $column_data{recurring_billing_mode} = SL::Presenter::Tag::select_tag(
      "recurring_billing_mode_$i",
      [[ 'always', $::locale->text('always') ], [ 'once',   $::locale->text('once')   ], [ 'never',  $::locale->text('never')  ]],
      default => $::form->{"recurring_billing_mode_$i"} || 'always',
    );

    # Orderer
    $column_data{orderer}   = qq|: $form->{"orderer_$i"}|;

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
    my $real_lastcost            = $form->round_amount($form->{"lastcost_$i"} * $form->{"qty_$i"}, 2);
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

    $column_data{marge} = sprintf qq|<font %s>%s &nbsp;%s%%</font>|,
      $marge_color, $form->{"marge_absolut_$i"}, $form->{"marge_percent_$i"};
    $column_data{listprice} = $form->format_amount(\%myconfig, $form->{"listprice_$i"}, 2);
    $column_data{lastcost}  = sprintf qq|<input size="5" name="lastcost_$i" value="%s">|, $form->format_amount(\%myconfig, $form->{"lastcost_$i"}, $decimalplaces);
# / marge calculations ending

# Calculate total weight
    $totalweight += ($form->{"qty_$i"} * $form->{"weight_$i"});

# calculate onhand
    if ($form->{"id_$i"}) {
      my $part         = IC->get_basic_part_info(id => $form->{"id_$i"});
      my $onhand_color = $part->{onhand} < $part->{rop} ? 'color="#ff0000"' : '';
      $column_data{onhand} = sprintf "<font %s>%s %s</font>",
                      $onhand_color,
                      $form->format_amount(\%myconfig, $part->{onhand}, 2),
                      $part->{unit};
    }
# / calculate onhand

    my @ROW1 = map { { value => $column_data{$_}, align => $align{$_}, nowrap => $nowrap{$_} } } grep { $column_def{$_}{display} } @header_sort;
    my @ROW2 = map { { value => sprintf "<b>%s</b> %s", $column_def{$_}{value}, $column_data{$_} } } grep { $column_def{$_}{display} } @row2_sort;

    my @hidden_vars;
    # add hidden ids for persistent (item|invoice)_ids and previous (converted_from*) ids
    if ($is_quotation) {
      push @hidden_vars, qw(orderitems_id converted_from_orderitems_id);
    }
    if ($is_s_p_order) {
      push @hidden_vars, qw(orderitems_id converted_from_orderitems_id converted_from_invoice_id);
    }
    if ($is_invoice) {
      push @hidden_vars, qw(invoice_id converted_from_orderitems_id converted_from_delivery_order_items_id converted_from_invoice_id);
    }
    if ($::form->{type} =~ /credit_note/) {
      push @hidden_vars, qw(invoice_id converted_from_invoice_id converted_from_reclamation_items_id);
    }
   if ($is_delivery_order) {
      map { $form->{"${_}_${i}"} = $form->format_amount(\%myconfig, $form->{"${_}_${i}"}) } qw(sellprice discount lastcost);
      push @hidden_vars, grep { defined $form->{"${_}_${i}"} } qw(sellprice discount not_discountable price_factor_id lastcost);
      push @hidden_vars, "stock_${stock_in_out}_sum_qty", "stock_${stock_in_out}";
      push @hidden_vars, qw(delivery_order_items_id converted_from_orderitems_id converted_from_delivery_order_items_id has_sernumber);
    }

    my @HIDDENS = map { value => $_}, (
          $cgi->hidden("-name" => "unit_old_$i", "-value" => $form->{"selected_unit_$i"}),
          $cgi->hidden("-name" => "price_new_$i", "-value" => $form->format_amount(\%myconfig, $form->{"price_new_$i"})),
          map { ($cgi->hidden("-name" => $_, "-id" => $_, "-value" => $form->{$_})); } map { $_."_$i" }
            (qw(bo price_old id inventory_accno bin partsgroup partnotes active_price_source active_discount_source
                orderer_id
                income_accno expense_accno listprice part_type taxaccounts ordnumber donumber transdate cusordnumber
                longdescription basefactor marge_absolut marge_percent marge_price_factor weight), @hidden_vars)
    );

    map { $form->{"${_}_base"} += $linetotal } (split(/ /, $form->{"taxaccounts_$i"}));

    $form->{invsubtotal} += $linetotal;

    # Benutzerdefinierte Variablen für Waren/Dienstleistungen/Erzeugnisse
    _render_custom_variables_inputs(ROW2 => \@ROW2, row => $i, part_id => $form->{"id_$i"});

    my $colspan = scalar @ROW1;
    push @ROWS, { ROW1 => \@ROW1, ROW2 => \@ROW2, HIDDENS => \@HIDDENS, colspan => $colspan, error => $form->{"row_error_$i"}, obj => $record_item };
  }

  $form->{totalweight} = $totalweight;

  print $form->parse_html_template('oe/sales_order', { ROWS   => \@ROWS,
                                                       HEADER => \@HEADER,
                                                     });

  if (abs($form->{sellprice_total} * 1) >= 0.01) {
    $form->{marge_percent} = ($form->{sellprice_total} - $form->{lastcost_total}) / $form->{sellprice_total} * 100;
  }

  $main::lxdebug->leave_sub();
}

sub setup_io_select_item_action_bar {
  my %params = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Continue'),
        submit    => [ '#form' ],
        accesskey => 'enter',
      ],
    );
  }
}

sub select_item {
  $main::lxdebug->enter_sub();

  my %params = @_;
  my $mode            = $params{mode}            || croak "Missing parameter 'mode'";
  my $pre_entered_qty = $params{pre_entered_qty} || 1;
  _check_io_auth();

  setup_io_select_item_action_bar();

  my $previous_form = $::auth->save_form_in_session(form => $::form);
  $::form->{title}  = $::myconfig{item_multiselect} ?
      $::locale->text('Set count for one or more of the items to select them'):
      $::locale->text('Select from one of the items below');
  $::form->header;

  my @item_list = map {
    # maybe there is a better backend function or way to calc
    $_->{display_sellprice} = ($_->{price_factor}) ? $_->{sellprice} / $_->{price_factor} : $_->{sellprice};
    $_;
  } @{ $::form->{item_list} };

  # delete action variable
  delete @{$::form}{qw(action item_list)};

  print $::form->parse_html_template('io/select_item', { PREVIOUS_FORM   => $previous_form,
                                                         MODE            => $mode,
                                                         ITEM_LIST       => \@item_list,
                                                         IS_ASSEMBLY     => $mode eq 'IC',
                                                         IS_PURCHASE     => $mode eq 'IS',
                                                         PRE_ENTERED_QTY => $pre_entered_qty, });

  $main::lxdebug->leave_sub();
}

sub item_selected {

  # this function is used for adding parts to records (mode = IR/IS)
  # and to assemblies (mode = IC)

  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  _check_io_auth();

  $::auth->restore_form_from_session($form->{select_item_previous_form} || croak('Missing previous form ID'), form => $form);

  my $mode     = delete($form->{select_item_mode}) || croak 'Missing item selection mode';
  my $row_key  = $mode eq 'IC' ? 'assembly_rows' : 'rowcount';
  my $curr_row = $form->{ $row_key };

  my $row = $curr_row;

  if ($myconfig{item_multiselect}) {
    my %multi_items;
    for (keys %$form) {
      next unless $form->{$_};
      next unless /^select_qty_(\d+)/;
      $multi_items{"id_${row}"}  = $1;
      $multi_items{"qty_${row}"} = $form->{$_};
      $row++;
    }
    $form->{$_} = $multi_items{$_} for keys %multi_items;
  } else {
    $form->{"id_${row}"} = delete($form->{select_item_id}) || croak 'Missing item selection ID';
    $row++;
  }

  map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) }
    qw(sellprice weight);

  if ( $mode eq 'IC' ) {
    # assembly mode:
    # the qty variables of the existing assembly items are all still formatted, so we parse them here
    # including the qty of the just added part
    $form->{"qty_$_"} = $form->parse_amount(\%myconfig, $form->{"qty_$_"}) for (1 .. $row - 1);
  } else {
    if ($myconfig{item_multiselect}) {
      # other modes and multiselection:
      # parse all newly entered qtys
      $form->{"qty_$_"} = $form->parse_amount(\%myconfig, $form->{"qty_$_"}) for ($curr_row .. $row - 1);
    }
  }

  for my $i ($curr_row .. $row - 1) {
    $form->{ $row_key } = $i;

    my $id = $form->{"id_${i}"};

    delete $form->{item_list};

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
    my $sellprice;
    unless ( $mode eq 'IC' ) {
      $sellprice = $form->parse_amount(\%myconfig, $form->{"sellprice_$i"});
    };

    my @new_fields =
        qw(id partnumber description sellprice listprice inventory_accno
           income_accno expense_accno bin unit weight part_type taxaccounts
           partsgroup formel longdescription not_discountable partnotes lastcost
           price_factor_id price_factor);

    my $ic_cvar_configs = CVar->get_configs(module => 'IC');
    push @new_fields, map { "ic_cvar_$_->{name}" } @{ $ic_cvar_configs };

    map { $form->{"${_}_$i"} = $new_item->{$_} } @new_fields;

    if (my $record = _make_record()) {
      my $price_source = SL::PriceSource->new(record_item => $record->items->[$i-1], record => $record);
      my $best_price   = $price_source->best_price;

      if ($best_price) {
        $::form->{"sellprice_$i"}           = $best_price->price;
        $::form->{"active_price_source_$i"} = $best_price->source;
      }

      my $best_discount = $price_source->best_discount;

      if ($best_discount) {
        $::form->{"discount_$i"}               = $best_discount->discount;
        $::form->{"active_discount_source_$i"} = $best_discount->source;
      }
    }

    $form->{"marge_price_factor_$i"} = $new_item->{price_factor};

    if ($form->{"part_payment_id_$i"} ne "") {
      $form->{payment_id} = $form->{"part_payment_id_$i"};
    }

    my ($dec)         = ($form->{"sellprice_$i"} =~ /\.(\d+)/);
    $dec              = length $dec;
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
    }

    # at this stage qty of newly added part needs to be have been parsed
    $form->{weight}    += ($form->{"weight_$i"} * $form->{"qty_$i"});

    if ($form->{"not_discountable_$i"}) {
      $form->{"discount_$i"} = 0;
    }

    my $amount =
        $form->{"sellprice_$i"} * (1 - $form->{"discount_$i"}) * $form->{"qty_$i"};
    map { $form->{"${_}_base"} += $amount }                         (split / /, $form->{"taxaccounts_$i"});
    map { $amount += ($form->{"${_}_base"} * $form->{"${_}_rate"}) } split / /, $form->{"taxaccounts_$i"} if !$form->{taxincluded};

    $form->{creditremaining} -= $amount;
    $form->{"runningnumber_$i"} = $i;

    # format amounts
    map {
      $form->{"${_}_$i"} =
          $form->format_amount(\%myconfig, $form->{"${_}_$i"}, $decimalplaces)
    } qw(sellprice lastcost qty) if $form->{part_type} ne 'assembly';
    $form->{"discount_$i"} = $form->format_amount(\%myconfig, $form->{"discount_$i"} * 100.0) if $form->{part_type} ne 'assembly';

    delete $form->{nextsub};

  }

  &display_form;

  $main::lxdebug->leave_sub();
}

sub new_item {
  _check_io_auth();

  my $price = $::form->{vc} eq 'customer' ? 'sellprice_as_number' : 'lastcost_as_number';
  my $previousform = $::auth->save_form_in_session;
  my $callback     = build_std_url("action=return_from_new_item", "previousform=$previousform");
  my $i            = $::form->{rowcount};

  my $parts_classification_type = $::form->{vc} eq 'customer' ? 'sales' : 'purchases';

  my @HIDDENS;
  push @HIDDENS,      { 'name' => 'callback',     'value' => $callback };
  push @HIDDENS, map +{ 'name' => $_,             'value' => $::form->{$_} },        qw(rowcount vc);
  push @HIDDENS, map +{ 'name' => "part.$_",      'value' => $::form->{"${_}_$i"} }, qw(partnumber description unit price_factor_id);
  push @HIDDENS,      { 'name' => "part.$price",  'value' => $::form->{"sellprice_$i"} };
  push @HIDDENS,      { 'name' => "part.notes",   'value' => $::form->{"longdescription_$i"} };

  push @HIDDENS,      { 'name' => "parts_classification_type", 'value' => $parts_classification_type };

  $::form->header;
  print $::form->parse_html_template("generic/new_item", { HIDDENS => [ sort { $a->{name} cmp $b->{name} } @HIDDENS ] } );
}

sub return_from_new_item {
  _check_io_auth();

  my $part = SL::DB::Manager::Part->find_by(id => delete $::form->{new_parts_id}) or die 'can not find part that was just saved!';

  $::auth->restore_form_from_session(delete $::form->{previousform}, form => $::form);

  $::form->{"id_$::form->{rowcount}"} = $part->id;

  my $url = build_std_url("script=$::form->{script}", "RESTORE_FORM_FROM_SESSION_ID=" . $::auth->save_form_in_session);
  print $::request->{cgi}->redirect($url);
}

sub check_form {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  _check_io_auth();

  my @a     = ();
  my $count = 0;

  # remove any makes or model rows
  if ($form->{part_type} eq 'assembly') {

    # fuer assemblies auskommentiert. seiteneffekte? ;-) wird die woanders benoetigt?
    #$form->{sellprice} = 0;
    $form->{weight}    = 0;
    map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) }
      qw(sellprice rop stock);

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

  } elsif ($form->{part_type} !~ m{^(?:part|service)$}) {
    remove_emptied_rows(1);

    $form->{creditremaining} -= &invoicetotal;
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
                price_old price_new unit_old ordnumber donumber
                transdate longdescription basefactor marge_total marge_percent
                marge_price_factor lastcost price_factor_id partnotes
                stock_out stock_in has_sernumber reqdate orderitems_id
                active_price_source active_discount_source delivery_order_items_id
                invoice_id converted_from_orderitems_id
                converted_from_delivery_order_items_id converted_from_invoice_id
                converted_from_reclamation_items_id recurring_billing_mode
                expense_chart_id inventory_chart_id tax_id tax_chart_type subtotal
              );

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
    $::dispatcher->end_request;
  }

  for my $i (1 .. $form->{rowcount} - 1) {
    $form->isblank("partnumber_$i",
                   $locale->text('Number missing in Row') . " $i");
  }

  $main::lxdebug->leave_sub();
}

sub order {
  $main::lxdebug->enter_sub();

  $::form->{email_journal_id}    = delete $::form->{workflow_email_journal_id};
  $::form->{email_attachment_id} = delete $::form->{workflow_email_attachment_id};
  $::form->{callback}            = delete $::form->{workflow_email_callback};

  _order();

  # At this point, the record is saved and the exchangerate contains
  # an unformatted value. _make_record uses RDBO attributes (i.e. _as_number)
  # to assign values and thus expects an formatted value.
  $::form->{exchangerate} = $::form->format_amount(\%::myconfig, $::form->{exchangerate});

  my $order = _make_record();

  $order->currency(SL::DB::Currency->new(name => $::form->{currency})->load) if $::form->{currency};
  $order->globalproject_id(undef)                                            if !$order->globalproject_id;
  $order->payment_id(undef)                                                  if !$order->payment_id;

  my $row = 1;
  foreach my $item (@{$order->items_sorted}) {
    $item->custom_variables([]);

    $item->price_factor_id(undef) if !$item->price_factor_id;
    $item->project_id(undef)      if !$item->project_id;

    # autovivify all cvars that are not in the form (cvars_by_config can do it).
    # workaround to pre-parse number-cvars (parse_custom_variable_values does not parse number values).
     foreach my $var (@{ $item->cvars_by_config }) {
      my $key = 'ic_cvar_' . $var->config->name . '_' . $row;
      $var->unparsed_value($::form->{$key});
      $var->unparsed_value($::form->parse_amount(\%::myconfig, $var->{__unparsed_value})) if ($var->config->type eq 'number' && exists($var->{__unparsed_value}));
    }
    $item->parse_custom_variable_values;

    $row++;
  }

  require SL::Controller::Order;
  my $c = SL::Controller::Order->new(order => $order);
  $c->reinit_after_new_order();
  $c->action_add();

  $main::lxdebug->leave_sub();
  $::dispatcher->end_request;
}

sub _order {
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

  delete $form->{$_} foreach (qw(id printed emailed queued));

  # When creating a new sales order from a saved sales invoice, reset id,
  # ordnumber, transdate and deliverydate as we are creating a new order. This
  # workflow is probably mainly used as a template mechanism for creating new
  # orders from existing invoices, so we probably don't want to link the items.
  # Is this order function called anywhere else?
  # The worksflows in oe already call sales_order and purchase_order in oe, not
  # this general function which now only seems to be called from saved sales
  # invoices
  # Why is ordnumber set to invnumber above, does this ever make sense?

  if ( $form->{script} eq 'is.pl' && $form->{type} eq 'invoice' ) {
    delete $form->{$_} foreach (qw(ordnumber id transdate deliverydate));
  };

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

  $form->{rowcount}--;

  $form->{cp_id} *= 1;

  require "bin/mozilla/$form->{script}";
  my $script = $form->{"script"};
  $script =~ s|.*/||;
  $script =~ s|.pl$||;
  $locale = Locale->new($::lx_office_conf{system}->{language}, $script);

  map { $form->{"select$_"} = "" } ($form->{vc}, "currency");

  my $currency = $form->{currency};

  &order_links;

  $form->{currency}     = $currency;
  $form->{forex}        = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{transdate}, $buysell);
  $form->{exchangerate} = $form->{forex} || '';

  for my $i (1 .. $form->{rowcount}) {
    map({ $form->{"${_}_${i}"} = $form->parse_amount(\%myconfig, $form->{"${_}_${i}"})
            if ($form->{"${_}_${i}"}) }
        qw(ship qty sellprice basefactor discount));
    $form->{"converted_from_invoice_id_$i"} = delete $form->{"invoice_id_$i"};
  }

  &prepare_order;
}

sub quotation {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  _check_io_auth();

  # we are coming from *_order and convert to quotation
  # it seems that quotation is only called if we have a existing order
  if ($form->{type} =~  /(sales|purchase)_order/) {
    $form->{"converted_from_orderitems_id_$_"} = delete $form->{"orderitems_id_$_"} for 1 .. $form->{"rowcount"};
  }
  if ($form->{second_run}) {
    $form->{print_and_post} = 0;
  }
  delete $form->{$_} foreach (qw(id printed emailed queued quonumber transaction_description));

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
        qw(ship qty sellprice basefactor discount lastcost));
  }

  &prepare_order;
  &display_form;

  $main::lxdebug->leave_sub();
}

sub request_for_quotation {
  quotation();
}

sub sales_reclamation {
  my $id = $::form->{id};
  my $type = $::form->{type};

  require SL::Controller::Reclamation;
  my $c = SL::Controller::Reclamation->new();
  $c->redirect_to(
    controller => 'Reclamation',
    action     => 'add_from_record',
    type       => 'sales_reclamation',
    email_journal_id    => $::form->{workflow_email_journal_id},
    email_attachment_id => $::form->{workflow_email_attachment_id},
    callback            => $::form->{workflow_email_callback},
    from_id    => $id,
    from_type  => $type,
  );
}

sub purchase_reclamation {
  my $id = $::form->{id};
  my $type = $::form->{type};

  require SL::Controller::Reclamation;
  my $c = SL::Controller::Reclamation->new();
  $c->redirect_to(
    controller => 'Reclamation',
    action     => 'add_from_record',
    type       => 'purchase_reclamation',
    email_journal_id    => $::form->{workflow_email_journal_id},
    email_attachment_id => $::form->{workflow_email_attachment_id},
    callback            => $::form->{workflow_email_callback},
    from_id    => $id,
    from_type  => $type,
  );
}

sub print_options {
  $::lxdebug->enter_sub();

  my (%options) = @_;

  _check_io_auth();

  my $inline = delete $options{inline};

  require SL::Helper::PrintOptions;
  my $print_options = SL::Helper::PrintOptions->get_print_options(
    form     => $::form,
    myconfig => \%::myconfig,
    locale   => $::locale,
    options  => \%options);

  if ($inline) {
    $::lxdebug->leave_sub();
    return $print_options;
  }

  print $print_options;
  $::lxdebug->leave_sub();
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

    $old_form = Form->new;
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
    $::dispatcher->end_request;
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

  my ($old_form, %params) = @_;

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

  if ($form->{formname} eq "invoice_for_advance_payment") {
    $form->{label} = $locale->text('Invoice for Advance Payment');
  }

  if ($form->{formname} eq "final_invoice") {
    $form->{label} = $locale->text('Final Invoice');
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

  if (($form->{type} eq 'sales_order') && ($form->{formname} eq 'ic_supply') ) {
    $inv                  = "inv";
    $due                  = "due";
    $form->{"${inv}date"} = $form->{transdate};
    $form->{"invdate"}    = $form->{transdate};
    $form->{invnumber}    = $form->{ordnumber};
    $form->{label}        = $locale->text('Intra-Community supply');
    $numberfld            = "sonumber";
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
  if ($form->{type} =~ /letter/) {
    undef $due;
    undef $inv;
    $form->{label}        = $locale->text('Letter');
  }

  $form->{TEMPLATE_DRIVER_OPTIONS} = { };
  if (any { $form->{type} eq $_ } qw(sales_quotation sales_order sales_delivery_order invoice invoice_for_advance_payment final_invoice request_quotation purchase_order purchase_delivery_order credit_note)) {
    $form->{TEMPLATE_DRIVER_OPTIONS}->{variable_content_types} = $form->get_variable_content_types();
  }

  if ($form->{format} =~ m{pdf} && !$form->{preview}) {
    _maybe_attach_zugferd_data($form);
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

  $form->{what_done} = $form->{formname};

  &validate_items;

  # Save the email address given in the form because it should override the setting saved for the customer/vendor.
  my ($saved_email, $saved_cc, $saved_bcc) =
    ($form->{"email"}, $form->{"cc"}, $form->{"bcc"});

  my $language_saved = $form->{language_id};
  my $payment_id_saved = $form->{payment_id};
  my $delivery_term_id_saved = $form->{delivery_term_id};
  my $salesman_id_saved = $form->{salesman_id};
  my $cp_id_saved = $form->{cp_id};
  my $taxzone_id_saved = $form->{taxzone_id};
  my $currency_saved = $form->{currency};

  call_sub("$form->{vc}_details") if ($form->{vc});

  $form->{language_id} = $language_saved;
  $form->{payment_id} = $payment_id_saved;
  $form->{delivery_term_id} = $delivery_term_id_saved;
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
  } elsif ($form->{type} eq 'letter') {
    # right now, no details are needed
    # but i do not want to break the bad default (invoice)
  } else {
    IS->invoice_details(\%myconfig, \%$form, $locale);
  }

  $form->get_employee_data('prefix' => 'employee', 'id' => $form->{employee_id});
  $form->get_employee_data('prefix' => 'salesman', 'id' => $salesman_id_saved);

  if ($form->{shipto_id}) {
    $form->get_shipto(\%myconfig);
  }

  $form->set_addition_billing_address_print_variables;

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
               qw(invdate orddate quodate pldate duedate reqdate transdate tax_point
                  shippingdate deliverydate validitydate paymentdate
                  datepaid transdate_oe transdate_do transdate_quo deliverydate_oe dodate
                  employee_startdate employee_enddate
                  ),
               grep({ /^datepaid_\d+$/ ||
                        /^transdate_oe_\d+$/ ||
                        /^transdate_do_\d+$/ ||
                        /^transdate_quo_\d+$/ ||
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
  my ($template_file, @template_files) = SL::Helper::CreatePDF->find_template(
    name        => $form->{formname},
    email       => $form->{media} eq 'email',
    language_id => $form->{language_id},
    printer_id  => $form->{printer_id},
    extension   => $extension,
  );

  if (!defined $template_file) {
    $::form->error($::locale->text('Cannot find matching template for this print request. Please contact your template maintainer. I tried these: #1.', join ', ', map { "'$_'"} @template_files));
  }

  $form->{IN} = $template_file;

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
    $form->{addition} = "MAILED";
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

  if ($defaults->print_interpolate_variables_in_positions) {
    $form->substitute_placeholders_in_template_arrays({ field => 'description', type => 'text' }, { field => 'longdescription', type => 'html' });
  }

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
      $::dispatcher->end_request;
    }

    my $msg =
      ($form->{media} eq 'printer')
      ? $locale->text('sent to printer')
      : $locale->text('emailed to') . " $form->{email}";

    if (!$params{no_redirect}) {
      $form->redirect(qq|$form->{label} $form->{"${inv}number"} $msg|);
    }
  }
  if ($form->{printing}) {
   call_sub($display_form);
   $::dispatcher->end_request;
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

sub relink_accounts {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $form->{"taxaccounts"} =~ s/\s*$//;
  $form->{"taxaccounts"} =~ s/^\s*//;
  foreach my $accno (split(/\s*/, $form->{"taxaccounts"})) {
    map({ delete($form->{"${accno}_${_}"}); } qw(rate description taxnumber tax_id)); # add tax_id ?
  }
  $form->{"taxaccounts"} = "";

  IC->retrieve_accounts(\%myconfig, $form, map { $_ => $form->{"id_$_"} } 1 .. $form->{rowcount});

  $main::lxdebug->leave_sub();
}

sub get_payment_terms_for_invoice {
  my $terms = $::form->{payment_id}  ? SL::DB::PaymentTerm->new(id => $::form->{payment_id}) ->load
            : $::form->{customer_id} ? SL::DB::Customer   ->new(id => $::form->{customer_id})->load->payment
            : $::form->{vendor_id}   ? SL::DB::Vendor     ->new(id => $::form->{vendor_id})  ->load->payment
            :                          undef;

  return $terms;
}

sub set_duedate {
  _check_io_auth();

  my $js      = SL::ClientJS->new(controller => SL::Controller::Base->new);
  my $terms   = get_payment_terms_for_invoice();
  my $invdate = $::form->{invdate} eq 'undefined' ? DateTime->today_local : DateTime->from_kivitendo($::form->{invdate});
  my $duedate = $terms ? $terms->calc_date(reference_date => $invdate, due_date => $::form->{duedate})->to_kivitendo : ($::form->{duedate} || $invdate->to_kivitendo);

  if ($terms && $terms->auto_calculation) {
    $js->hide('#duedate_container')
       ->show('#duedate_fixed')
       ->html('#duedate_fixed', $duedate);

  } else {
    $js->show('#duedate_container')
       ->hide('#duedate_fixed');
  }

  $js->val('#duedate', $duedate)
     ->render;
}

sub _update_part_information {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  my %part_information = IC->get_basic_part_info('id' => [ grep { $_ } map { $form->{"id_${_}"} } (1..$form->{rowcount}) ]);

  $form->{PART_INFORMATION} = \%part_information;

  foreach my $i (1..$form->{rowcount}) {
    next unless ($form->{"id_${i}"});

    my $info                        = $form->{PART_INFORMATION}->{$form->{"id_${i}"}} || { };
    $form->{"partunit_${i}"}        = $info->{unit};
    $form->{"weight_$i"}            = $info->{weight};
    $form->{"part_type_$i"}         = $info->{part_type};
    $form->{"classification_id_$i"} = $info->{classification_id};
    $form->{"has_sernumber_$i"}     = $info->{has_sernumber};
  }

  $main::lxdebug->leave_sub();
}

sub _update_ship {
  return unless $::form->{id};
  my $helper = SL::Helper::ShippedQty->new->calculate($::form->{id});

  for my $i (1..$::form->{rowcount}) {
    if (my $oid = $::form->{"orderitems_id_$i"}) {
      $::form->{"ship_$i"} = $helper->shipped_qty->{$oid};
    }
  }
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

  # get partsgroup_id from part
  my $partsgroup_id;
  if ($params{part_id}) {
    $partsgroup_id = SL::DB::Part->new(id => $params{part_id})->load->partsgroup_id;
  }

  my $num_visible_cvars = 0;
  foreach my $cvar (@{ $form->{CVAR_CONFIGS}->{IC} }) {
    $cvar->{valid} = $params{part_id} && $valid->($cvar->{id});

    # set partsgroup filter
    my $partsgroup_filtered = 0;
    if ($cvar->{flag_partsgroup_filter}) {
      if (!$partsgroup_id || (!grep {$partsgroup_id == $_} @{ $cvar->{partsgroups} })) {
        $partsgroup_filtered = 1;
      }
    }

    my $hide_non_editable = 1;

    my $show = 0;
    my $description = '';
    if (( ($cvar->{flag_editable} || !$hide_non_editable) && $cvar->{valid}) && !$partsgroup_filtered) {
      $num_visible_cvars++;
      $description = $cvar->{description} . ' ';
      $show = 1;
    }

    my $form_key = "ic_cvar_" . $cvar->{name} . "_$params{row}";

    push @{ $params{ROW2} }, {
      line_break     => $show && !(($num_visible_cvars - 1) % ($::myconfig{form_cvars_nr_cols}*1 || 3)),
      description    => $description,
      cvar           => 1,
      render_options => {
         hide_non_editable => $hide_non_editable,
         var               => $cvar,
         name_prefix       => 'ic_',
         name_postfix      => "_$params{row}",
         valid             => $cvar->{valid},
         value             => CVar->parse($::form->{$form_key}, $cvar),
         partsgroup_filtered => $partsgroup_filtered,
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

  my $make_key = sub {
    my ($row) = @_;
    return $::form->{"id_${row}"} unless $::form->{"serialnumber_${row}"};
    my $key = $::form->{"id_${row}"} . ':' . $::form->{"serialnumber_${row}"};
    return exists $params{quantities}->{$key} ? $key : $::form->{"id_${row}"};
  };

  my $removed_rows = 0;
  my $row          = 0;
  while ($row < $::form->{rowcount}) {
    $row++;
    next unless $::form->{"id_$row"};

    my $parts_id                      = $::form->{"id_$row"};
    my $base_qty                      = $::form->parse_amount(\%::myconfig, $::form->{"qty_$row"}) * SL::DB::Manager::Unit->find_by(name => $::form->{"unit_$row"})->base_factor;

    my $key                           = $make_key->($row);
    my $sub_qty                       = min($base_qty, $params{quantities}->{$key});
    $params{quantities}->{$key}      -= $sub_qty;

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

# TODO: both of these are makeshift so that price sources can operate on rdbo objects. if
# this ever gets rewritten in controller style, throw this out
sub _make_record_item {
  my ($row, %params) = @_;

  my $class = {
    sales_order             => 'OrderItem',
    purchase_order          => 'OrderItem',
    sales_quotation         => 'OrderItem',
    request_quotation       => 'OrderItem',
    invoice                 => 'InvoiceItem',
    invoice_for_advance_payment => 'InvoiceItem',
    final_invoice           => 'InvoiceItem',
    credit_note             => 'InvoiceItem',
    purchase_invoice        => 'InvoiceItem',
    purchase_delivery_order => 'DeliveryOrderItem',
    sales_delivery_order    => 'DeliveryOrderItem',
  }->{$::form->{type}};

  return unless $class;

  $class = 'SL::DB::' . $class;

  my %translated_methods = (
    'SL::DB::OrderItem' => {
      id                      => 'parts_id',
      orderitems_id           => 'id',
    },
    'SL::DB::DeliveryOrderItem' => {
      id                      => 'parts_id',
      delivery_order_items_id => 'id',
    },
    'SL::DB::InvoiceItem' => {
      id                      => 'parts_id',
      invoice_id => 'id',
    },
  );

  eval "require $class";

  my $obj = $::form->{"orderitems_id_$row"}
          ? $class->meta->convention_manager->auto_manager_class_name->find_by(id => $::form->{"orderitems_id_$row"})
          : $class->new;

  for my $key (grep { /_$row$/ } keys %$::form) {
    my $method = $key;
    $method =~ s/_$row$//;
    $method = $translated_methods{$class}{$method} // $method;
    my $value = $::form->{$key};
    if ($obj->meta->column($method)) {
      if ($obj->meta->column($method)->isa('Rose::DB::Object::Metadata::Column::Date')) {
        $obj->${\"$method\_as_date"}($value);
      } elsif ((ref $obj->meta->column($method)) =~ /^Rose::DB::Object::Metadata::Column::(?:Numeric|Float|DoublePrecsion)$/) {
        $obj->${\"$method\_as_number"}(($value // '') eq '' ? undef : $value);
      } elsif ((ref $obj->meta->column($method)) =~ /^Rose::DB::Object::Metadata::Column::Boolean$/) {
        $obj->$method(!!$value);
      } elsif ((ref $obj->meta->column($method)) =~ /^Rose::DB::Object::Metadata::Column::(?:Big)?(?:Int(?:eger)?|Serial)$/) {
        $obj->$method(($value // '') eq '' ? undef : $value * 1);
      } else {
        $obj->$method($value);
      }

      if ($method eq 'discount') {
        $obj->discount($obj->discount / 100.0);
      }

    } else {
      $obj->{__additional_form_attributes}{$method} = $value;
    }
  }

  if ($::form->{"id_$row"}) {
    $obj->part(SL::DB::Part->load_cached($::form->{"id_$row"}));
  }

  if ($obj->can('qty')) {
    $obj->qty(     $obj->qty      * $params{factor});
    $obj->base_qty($obj->base_qty * $params{factor});
  }

  return $obj;
}

sub _make_record {
  my $class = {
    sales_order             => 'Order',
    purchase_order          => 'Order',
    sales_quotation         => 'Order',
    request_quotation       => 'Order',
    purchase_delivery_order => 'DeliveryOrder',
    sales_delivery_order    => 'DeliveryOrder',
  }->{$::form->{type}};

  if ($::form->{type} =~ /invoice|credit_note/) {
    $class = $::form->{vc} eq 'customer' ? 'Invoice'
           : $::form->{vc} eq 'vendor'   ? 'PurchaseInvoice'
           : do { die 'unknown invoice type' };
  }

  my $factor = $::form->{type} =~ m{credit_note} ? -1 : 1;

  return unless $class;

  $class = 'SL::DB::' . $class;

  eval "require $class";

  my $obj = $::form->{id}
          ? $class->meta->convention_manager->auto_manager_class_name->find_by(id => $::form->{id})
          : $class->new;

  for my $method (keys %$::form) {
    next unless $obj->can($method);
    next unless $obj->meta->column($method);

    if ($obj->meta->column($method)->isa('Rose::DB::Object::Metadata::Column::Date')) {
      $obj->${\"$method\_as_date"}($::form->{$method});
    } elsif ((ref $obj->meta->column($method)) =~ /^Rose::DB::Object::Metadata::Column::(?:Numeric|Float|DoublePrecsion)$/) {
      $obj->${\"$method\_as_number"}(($::form->{$method} // '') eq '' ? undef : $::form->{$method});
    } elsif ((ref $obj->meta->column($method)) =~ /^Rose::DB::Object::Metadata::Column::Boolean$/) {
      $obj->$method(!!$::form->{$method});
    } elsif ((ref $obj->meta->column($method)) =~ /^Rose::DB::Object::Metadata::Column::(?:Big)?(?:Int(?:eger)?|Serial)$/) {
      $obj->$method(($::form->{$method} // '') eq '' ? undef : $::form->{$method} * 1);
    } else {
      $obj->$method($::form->{$method});
    }
  }

  my @items;
  for my $i (1 .. $::form->{rowcount}) {
    next unless $::form->{"id_$i"};
    push @items, _make_record_item($i, factor => $factor);
  }

  $obj->items(@items) if @items;

  if ($class eq 'SL::DB::DeliveryOrder' && !$obj->record_type) {
    $obj->record_type(SL::DB::DeliveryOrder::TypeData::validate_type($::form->{type}));
  }

  if ($class eq 'SL::DB::Order' && !$obj->record_type) {
    $obj->record_type(SL::DB::Order::TypeData::validate_type($::form->{type}));
  }

  if ($class eq 'SL::DB::Invoice') {
    my $paid = $factor *
      sum
      map  { $::form->parse_amount(\%::myconfig, $::form->{$_}) }
      grep { m{^paid_\d+$} }
      keys %{ $::form };
    $obj->paid($paid);
  }

  return $obj;
}

sub setup_sales_purchase_print_options {
  my $print_form = Form->new('');
  $print_form->{printers}  = SL::DB::Manager::Printer->get_all_sorted;

  $print_form->{$_} = $::form->{$_} for qw(type media printer_id storno storno_id formname groupitems);

  return SL::Helper::PrintOptions->get_print_options(
    form    => $print_form,
    options => {
      show_headers => 1,
    },
  );
}

sub _get_files_for_email_dialog {
  my %files = map { ($_ => []) } qw(versions files vc_files part_files project_files);

  return %files if !$::instance_conf->get_doc_storage;

  if ($::form->{id}) {
    $files{versions} = [ SL::File->get_all_versions(object_id => $::form->{id},    object_type => $::form->{type}, file_type => 'document') ];
    $files{files}    = [ SL::File->get_all(         object_id => $::form->{id},    object_type => $::form->{type}, file_type => 'attachment') ];
    $files{vc_files} = [ SL::File->get_all(         object_id => $::form->{vc_id}, object_type => $::form->{vc},   file_type => 'attachment') ]
      if $::form->{vc} && $::form->{"vc_id"};
    $files{project_files} = [ SL::File->get_all(object_id => $::form->{project_id}, object_type => 'project',file_type => 'attachment') ]
      if $::form->{project_id};
  }

  my @parts =
    uniq_by { $_->{id} }
    grep    { $_->{id} }
    map     {
      +{ id         => $::form->{"id_$_"},
         partnumber => $::form->{"partnumber_$_"},
       }
    } (1 .. $::form->{rowcount});

  foreach my $part (@parts) {
    my @pfiles = SL::File->get_all(object_id => $part->{id}, object_type => 'part');
    push @{ $files{part_files} }, map { +{ %{ $_ }, partnumber => $part->{partnumber} } } @pfiles;
  }

  foreach my $key (keys %files) {
    $files{$key} = [ sort_by { lc $_->{db_file}->{file_name} } @{ $files{$key} } ];
  }

  return %files;
}

sub show_sales_purchase_email_dialog {
  my $email = '';
  my $email_cc = '';
  my $record_email;

  my $is_invoice_mail = $::form->{type} =~ m{final_invoice|credit_note|invoice_for_advance_payment|invoice};

  if ($::form->{cp_id}) {
    $email = SL::DB::Contact->load_cached($::form->{cp_id})->cp_email;
  }
  # write a dispatch table if a third type enters
  # check record mail for sales_invoice
  if ($is_invoice_mail && (!$email || $::instance_conf->get_invoice_mail_settings ne 'cp')) {
    # check for invoice_mail if defined (vc.invoice_email)
    $record_email = SL::DB::Customer->load_cached($::form->{vc_id})->invoice_mail;
    if ($record_email) {
      # check if cc for contact is also wanted
      $email_cc = $email if ($::instance_conf->get_invoice_mail_settings eq 'invoice_mail_cc_cp');
      $email    = $record_email;
    }
  }
  # check record mail for sales_delivery_order
  if ($::form->{type} eq 'sales_delivery_order') {
    # check for deliver_order_mail if defined (vc.delivery_order_mail)
    $record_email = SL::DB::Customer->load_cached($::form->{vc_id})->delivery_order_mail;
    if ($record_email) {
      # check if cc for contact is also wanted
      $email_cc = $email; # always cc to cp
      $email    = $record_email;
    }
  }
  # still no email? use general mail (vc.email)
  if (!$email && $::form->{vc} && $::form->{vc_id}) {
    $email = SL::DB::Customer->load_cached($::form->{vc_id})->email if 'customer' eq $::form->{vc};
    $email = SL::DB::Vendor  ->load_cached($::form->{vc_id})->email if 'vendor'   eq $::form->{vc};
  }

  $email = '' if $::form->{type} eq 'purchase_delivery_order';

  $::form->{language} = $::form->get_template_language(\%::myconfig);
  $::form->{language} = "_" . $::form->{language};

  my %body_params = (record_email => $record_email);
  if (($::form->{type} eq 'invoice') && $::form->{direct_debit}) {
    $body_params{translation_type}          = "preset_text_invoice_direct_debit";
    $body_params{fallback_translation_type} = "preset_text_invoice";
  }

  my @employees_with_email = grep {
    my $user = SL::DB::Manager::AuthUser->find_by(login => $_->login);
    $user && !!trim($user->get_config_value('email'));
  } @{ SL::DB::Manager::Employee->get_all_sorted(query => [ deleted => 0 ]) };

  my $email_form = {
    to                  => $email,
    cc                  => $email_cc,
    subject             => $::form->generate_email_subject,
    message             => $::form->generate_email_body(%body_params),
    attachment_filename => $::form->generate_attachment_filename,
    js_send_function    => 'kivi.SalesPurchase.send_email()',
  };

  my %files = _get_files_for_email_dialog();

  my $all_partner_email_addresses;
  $all_partner_email_addresses = SL::DB::Customer->load_cached($::form->{vc_id})->get_all_email_addresses() if 'customer' eq $::form->{vc};
  $all_partner_email_addresses = SL::DB::Vendor  ->load_cached($::form->{vc_id})->get_all_email_addresses() if 'vendor'   eq $::form->{vc};

  my $html  = $::form->parse_html_template("common/_send_email_dialog", {
    email_form      => $email_form,
    show_bcc        => $::auth->assert('email_bcc', 'may fail'),
    FILES           => \%files,
    is_customer     => $::form->{vc} eq 'customer',
    is_invoice_mail => ($record_email && $is_invoice_mail),
    ALL_EMPLOYEES   => \@employees_with_email,
    ALL_PARTNER_EMAIL_ADDRESSES => $all_partner_email_addresses,
  });

  print $::form->ajax_response_header, $html;
}

sub send_sales_purchase_email {
  my $type        = $::form->{type};
  my $id          = $::form->{id};
  my $script      = $type =~ m{sales_order|purchase_order|quotation} ? 'oe.pl'
                  : $type =~ m{delivery_}                            ? 'do.pl'
                  :                                                    'is.pl';

  my $email_form  = delete $::form->{email_form};

  if ($email_form->{additional_to}) {
    $email_form->{to} = join ', ', grep { $_ } $email_form->{to}, @{$email_form->{additional_to}};
    delete $email_form->{additional_to};
  }

  my %field_names = (to => 'email');

  $::form->{ $field_names{$_} // $_ } = $email_form->{$_} for keys %{ $email_form };

  $::form->{media} = 'email';

  $::form->{attachment_policy} //= '';

  # Is an old file version available?
  my $attfile;
  if ($::form->{attachment_policy} eq 'old_file') {
    $attfile = SL::File->get_all(object_id     => $id,
                                 object_type   => $type,
                                 file_type     => 'document',
                                 print_variant => $::form->{formname},);
  }

  if ($::form->{attachment_policy} eq 'no_file' || ($::form->{attachment_policy} eq 'old_file' && $attfile)) {
    $::form->send_email(\%::myconfig, 'pdf');

  } else {
    print_form("return");
    Common->save_email_status(\%::myconfig, $::form) unless ($::instance_conf->get_email_journal);
  }

  flash_later('info', $::locale->text('The email has been sent.'));

  print $::form->redirect_header($script . '?action=edit&id=' . $::form->escape($id) . '&type=' . $::form->escape($type));
}

sub _maybe_attach_zugferd_data {
  my ($form) = @_;

  my $record = _make_record();

  return if !$record
    || !$record->can('customer')
    || !$record->customer
    || !$record->can('create_pdf_a_print_options')
    || !$record->can('create_zugferd_data')
    || !$record->customer->create_zugferd_invoices_for_this_customer;

  eval {
    my $xmlfile = File::Temp->new;
    $xmlfile->print($record->create_zugferd_data);
    $xmlfile->close;

    $form->{TEMPLATE_DRIVER_OPTIONS}->{pdf_a}           = $record->create_pdf_a_print_options(zugferd_xmp_data => $record->create_zugferd_xmp_data);
    $form->{TEMPLATE_DRIVER_OPTIONS}->{pdf_attachments} = [
      { source       => $xmlfile,
        name         => 'factur-x.xml',
        description  => $::locale->text('Factur-X/ZUGFeRD invoice'),
        relationship => '/Alternative',
        mime_type    => 'text/xml',
      }
    ];
  };

  if (my $e = SL::X::ZUGFeRDValidation->caught) {
    $::form->error($e->message);
  }
}

sub download_factur_x_xml {
  my ($form) = @_;

  my $record = _make_record();

  die if !$record
      || !$record->can('customer')
      || !$record->customer
      || !$record->can('create_pdf_a_print_options')
      || !$record->can('create_zugferd_data')
      || !$record->customer->create_zugferd_invoices_for_this_customer;

  my $xml_content = eval { $record->create_zugferd_data };

  if (my $e = SL::X::ZUGFeRDValidation->caught) {
    $::form->error($e->message);
  }

  my $attachment_filename = "factur-x_" . $::form->generate_attachment_filename;
  $attachment_filename    =~ s{\.[^.]+$}{.xml};
  my %headers             = (
    '-type'           => 'application/xml',
    '-connection'     => 'close',
    '-attachment'     => $attachment_filename,
    '-content-length' => length($xml_content),
  );

  print $::request->cgi->header(%headers);

  $::locale->with_raw_io(\*STDOUT, sub { print $xml_content });
}

sub get_taxes_dropdown {
  my $transdate         = $::form->{transdate}    ? DateTime->from_kivitendo($::form->{transdate}) : DateTime->today_local;
  my $deliverydate      = $::form->{deliverydate} ? DateTime->from_kivitendo($::form->{deliverydate}) : undef;
  my $item_deliverydate = $::form->{item_deliverydate} ? DateTime->from_kivitendo($::form->{item_deliverydate}) : undef;

  my @taxes = IO->get_active_taxes_for_chart($::form->{chart_id},
    $item_deliverydate // $deliverydate // $transdate);
  my $html  = $::form->parse_html_template("ir/update_taxes", { TAXES => \@taxes });

  print $::form->ajax_response_header, $html;
}

1;
