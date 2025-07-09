#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 1998-2002
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
#  Contributors:
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
#======================================================================
#
# Inventory invoicing module
#
#======================================================================

package IS;

use List::Util qw(max sum0);
use List::MoreUtils qw(any);

use Carp;
use Data::Dumper;

use SL::AM;
use SL::ARAP;
use SL::CVar;
use SL::Common;
use SL::DATEV qw(:CONSTANTS);
use SL::Util qw(trim);
use SL::DBUtils;
use SL::DO;
use SL::GenericTranslations;
use SL::HTML::Restrict;
use SL::Locale::String qw(t8);
use SL::MoreCommon;
use SL::IC;
use SL::IO;
use SL::TransNumber;
use SL::DB::Chart;
use SL::DB::Customer;
use SL::DB::Default;
use SL::DB::Draft;
use SL::DB::Tax;
use SL::DB::TaxZone;
use SL::DB::ValidityToken;
use SL::TransNumber;
use SL::DB;
use SL::Presenter::Part qw(type_abbreviation classification_abbreviation);
use SL::Helper::QrBillFunctions qw(get_qrbill_account assemble_ref_number);
use SL::Helper::ISO3166;
use strict;
use constant PCLASS_OK             =>   0;
use constant PCLASS_NOTFORSALE     =>   1;
use constant PCLASS_NOTFORPURCHASE =>   2;

sub invoice_details {
  $main::lxdebug->enter_sub();

  # prepare invoice for printing

  my ($self, $myconfig, $form, $locale) = @_;

  $form->{duedate} ||= $form->{invdate};

  # connect to database
  my $dbh = $form->get_standard_dbh;
  my $sth;

  my (@project_ids);
  $form->{TEMPLATE_ARRAYS} = {};

  push(@project_ids, $form->{"globalproject_id"}) if ($form->{"globalproject_id"});

  $form->get_lists('price_factors' => 'ALL_PRICE_FACTORS');
  my %price_factors;

  foreach my $pfac (@{ $form->{ALL_PRICE_FACTORS} }) {
    $price_factors{$pfac->{id}}  = $pfac;
    $pfac->{factor}             *= 1;
    $pfac->{formatted_factor}    = $form->format_amount($myconfig, $pfac->{factor});
  }

  # sort items by partsgroup
  for my $i (1 .. $form->{rowcount}) {
#    $partsgroup = "";
#    if ($form->{"partsgroup_$i"} && $form->{groupitems}) {
#      $partsgroup = $form->{"partsgroup_$i"};
#    }
#    push @partsgroup, [$i, $partsgroup];
    push(@project_ids, $form->{"project_id_$i"}) if ($form->{"project_id_$i"});
  }

  my $projects = [];
  my %projects_by_id;
  if (@project_ids) {
    $projects = SL::DB::Manager::Project->get_all(query => [ id => \@project_ids ]);
    %projects_by_id = map { $_->id => $_ } @$projects;
  }

  if ($projects_by_id{$form->{"globalproject_id"}}) {
    $form->{globalprojectnumber} = $projects_by_id{$form->{"globalproject_id"}}->projectnumber;
    $form->{globalprojectdescription} = $projects_by_id{$form->{"globalproject_id"}}->description;

    for (@{ $projects_by_id{$form->{"globalproject_id"}}->cvars_by_config }) {
      $form->{"project_cvar_" . $_->config->name} = $_->value_as_text;
    }
  }

  my $tax = 0;
  my $item;
  my $i;
  my @partsgroup = ();
  my $partsgroup;

  # sort items by partsgroup
  for $i (1 .. $form->{rowcount}) {
    $partsgroup = "";
    if ($form->{"partsgroup_$i"} && $form->{groupitems}) {
      $partsgroup = $form->{"partsgroup_$i"};
    }
    push @partsgroup, [$i, $partsgroup];
  }

  my $sameitem = "";
  my @taxaccounts;
  my %taxaccounts;
  my %taxbase;
  my $taxrate;
  my $taxamount;
  my $taxbase;
  my $taxdiff;
  my $nodiscount;
  my $yesdiscount;
  my $nodiscount_subtotal = 0;
  my $discount_subtotal = 0;
  my $position = 0;
  my $subtotal_header = 0;
  my $subposition = 0;

  $form->{discount} = [];

  # get some values of parts from db on store them in extra array,
  # so that they can be sorted in later
  my %prepared_template_arrays = IC->prepare_parts_for_printing(myconfig => $myconfig, form => $form);
  my @prepared_arrays          = keys %prepared_template_arrays;
  my @separate_totals          = qw(non_separate_subtotal);

  my $ic_cvar_configs = CVar->get_configs(module => 'IC');
  my $project_cvar_configs = CVar->get_configs(module => 'Projects');

  my @arrays =
    qw(runningnumber number description longdescription qty qty_nofmt unit bin
       deliverydate_oe ordnumber_oe donumber_do transdate_oe invnumber invdate
       partnotes serialnumber reqdate sellprice sellprice_nofmt listprice listprice_nofmt netprice netprice_nofmt
       discount discount_nofmt p_discount discount_sub discount_sub_nofmt nodiscount_sub nodiscount_sub_nofmt
       linetotal linetotal_nofmt nodiscount_linetotal nodiscount_linetotal_nofmt tax_rate projectnumber projectdescription
       price_factor price_factor_name partsgroup weight weight_nofmt lineweight lineweight_nofmt);

  push @arrays, map { "ic_cvar_$_->{name}" } @{ $ic_cvar_configs };
  push @arrays, map { "project_cvar_$_->{name}" } @{ $project_cvar_configs };

  my @tax_arrays = qw(taxbase tax taxdescription taxrate taxnumber tax_id);

  my @payment_arrays = qw(payment paymentaccount paymentdate paymentsource paymentmemo);

  my @invoices_for_advance_payment_arrays = qw(iap_invnumber iap_transdate
                                               iap_amount iap_amount_nofmt
                                               iap_taxamount iap_taxamount_nofmt
                                               iap_open_amount iap_open_amount_nofmt
                                               iap_netamount);

  map { $form->{TEMPLATE_ARRAYS}->{$_} = [] } (@arrays, @tax_arrays, @payment_arrays, @prepared_arrays, @invoices_for_advance_payment_arrays);

  my $totalweight = 0;
  foreach $item (sort { $a->[1] cmp $b->[1] } @partsgroup) {
    $i = $item->[0];

    if ($item->[1] ne $sameitem) {
      push(@{ $form->{TEMPLATE_ARRAYS}->{entry_type}  }, 'partsgroup');
      push(@{ $form->{TEMPLATE_ARRAYS}->{description} }, qq|$item->[1]|);
      $sameitem = $item->[1];

      map({ push(@{ $form->{TEMPLATE_ARRAYS}->{$_} }, "") } grep({ $_ ne "description" } (@arrays, @prepared_arrays)));
    }

    $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});

    if ($form->{"id_$i"} != 0) {

      # Prepare linked items for printing
      if ( $form->{"invoice_id_$i"} ) {

        require SL::DB::InvoiceItem;
        my $invoice_item = SL::DB::Manager::InvoiceItem->find_by( id => $form->{"invoice_id_$i"} );
        my $linkeditems  = $invoice_item->linked_records( direction => 'from', recursive => 1 );

        # check for (recursively) linked sales quotation items, sales order
        # items and sales delivery order items.

        # The checks for $form->{"ordnumber_$i"} and quo and do are for the old
        # behaviour, where this data was stored in its own database fields in
        # the invoice items, and there were no record links for the items.

        # If this information were to be fetched in retrieve_invoice, e.g. for showing
        # this information in the second row, then these fields will already have
        # been set and won't be calculated again. This shouldn't be done there
        # though, as each invocation creates several database calls per item, and would
        # make the interface very slow for many items. So currently these
        # requests are only made when printing the record.

        # When using the workflow an invoice item can only be (recursively) linked to at
        # most one sales quotation item and at most one delivery order item.  But it may
        # be linked back to several order items, if collective orders were involved. If
        # that is the case we will always choose the very first order item from the
        # original order, i.e. where it first appeared in an order.

        # TODO: credit note items aren't checked for a record link to their
        # invoice item

        unless ( $form->{"ordnumber_$i"} ) {

          # $form->{"ordnumber_$i"} comes from ordnumber in invoice, if an
          # entry exists this must be from before the change from ordnumber to linked items.
          # So we just use that value and don't check for linked items.
          # In that case there won't be any links for quo or do items either

          # sales order items are fetched and sorted by id, the lowest id is first
          # It is assumed that the id always grows, so the item we want (the original) will have the lowest id
          # better solution: filter the order_item that doesn't have any links from other order_items
          #                  or maybe fetch linked_records with param save_path and order by _record_length_depth
          my @linked_orderitems = grep { $_->isa("SL::DB::OrderItem") && $_->record->type eq 'sales_order' } @{$linkeditems};
          if ( scalar @linked_orderitems ) {
            @linked_orderitems = sort { $a->id <=> $b->id } @linked_orderitems;
            my $orderitem = $linked_orderitems[0]; # 0: the original order item, -1: the last collective order item

            $form->{"ordnumber_$i"}       = $orderitem->record->record_number;
            $form->{"transdate_oe_$i"}    = $orderitem->record->transdate->to_kivitendo;
            $form->{"cusordnumber_oe_$i"} = $orderitem->record->cusordnumber;
          };

          my @linked_quoitems = grep { $_->isa("SL::DB::OrderItem") && $_->record->type eq 'sales_quotation' } @{$linkeditems};
          if ( scalar @linked_quoitems ) {
            croak "an invoice item may only be linked back to 1 sales quotation item, something is wrong\n" unless scalar @linked_quoitems == 1;
            $form->{"quonumber_$i"}     = $linked_quoitems[0]->record->record_number;
            $form->{"transdate_quo_$i"} = $linked_quoitems[0]->record->transdate->to_kivitendo;
          };

          my @linked_deliveryorderitems = grep { $_->isa("SL::DB::DeliveryOrderItem") && $_->record->type eq 'sales_delivery_order' } @{$linkeditems};
          if ( scalar @linked_deliveryorderitems ) {
            croak "an invoice item may only be linked back to 1 sales delivery item, something is wrong\n" unless scalar @linked_deliveryorderitems == 1;
            $form->{"donumber_$i"}     = $linked_deliveryorderitems[0]->record->record_number;
            $form->{"transdate_do_$i"} = $linked_deliveryorderitems[0]->record->transdate->to_kivitendo;
          };
        };
      };


      # add number, description and qty to $form->{number},
      if ($form->{"subtotal_$i"} && !$subtotal_header) {
        $subtotal_header = $i;
        $position = int($position);
        $subposition = 0;
        $position++;
      } elsif ($subtotal_header) {
        $subposition += 1;
        $position = int($position);
        $position = $position.".".$subposition;
      } else {
        $position = int($position);
        $position++;
      }

      my $price_factor = $price_factors{$form->{"price_factor_id_$i"}} || { 'factor' => 1 };

      push(@{ $form->{TEMPLATE_ARRAYS}->{$_} },                $prepared_template_arrays{$_}[$i - 1]) for @prepared_arrays;

      push @{ $form->{TEMPLATE_ARRAYS}->{entry_type} },        'normal';
      push @{ $form->{TEMPLATE_ARRAYS}->{runningnumber} },     $position;
      push @{ $form->{TEMPLATE_ARRAYS}->{number} },            $form->{"partnumber_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{serialnumber} },      $form->{"serialnumber_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{bin} },               $form->{"bin_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{partnotes} },         $form->{"partnotes_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{description} },       $form->{"description_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{longdescription} },   $form->{"longdescription_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{qty} },               $form->format_amount($myconfig, $form->{"qty_$i"});
      push @{ $form->{TEMPLATE_ARRAYS}->{qty_nofmt} },         $form->{"qty_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{unit} },              $form->{"unit_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{deliverydate_oe} },   $form->{"reqdate_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{sellprice} },         $form->{"sellprice_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{sellprice_nofmt} },   $form->parse_amount($myconfig, $form->{"sellprice_$i"});
      # linked item print variables
      push @{ $form->{TEMPLATE_ARRAYS}->{quonumber_quo} },     $form->{"quonumber_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{transdate_quo} },     $form->{"transdate_quo_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{ordnumber_oe} },      $form->{"ordnumber_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{transdate_oe} },      $form->{"transdate_oe_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{cusordnumber_oe} },   $form->{"cusordnumber_oe_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{donumber_do} },       $form->{"donumber_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{transdate_do} },      $form->{"transdate_do_$i"};

      push @{ $form->{TEMPLATE_ARRAYS}->{invnumber} },         $form->{"invnumber"};
      push @{ $form->{TEMPLATE_ARRAYS}->{invdate} },           $form->{"invdate"};
      push @{ $form->{TEMPLATE_ARRAYS}->{price_factor} },      $price_factor->{formatted_factor};
      push @{ $form->{TEMPLATE_ARRAYS}->{price_factor_name} }, $price_factor->{description};
      push @{ $form->{TEMPLATE_ARRAYS}->{partsgroup} },        $form->{"partsgroup_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{reqdate} },           $form->{"reqdate_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{listprice} },         $form->format_amount($myconfig, $form->{"listprice_$i"}, 2);
      push(@{ $form->{TEMPLATE_ARRAYS}->{listprice_nofmt} },   $form->{"listprice_$i"});

      my $sellprice     = $form->parse_amount($myconfig, $form->{"sellprice_$i"});
      my ($dec)         = ($sellprice =~ /\.(\d+)/);
      my $decimalplaces = max 2, length($dec);

      my $parsed_discount            = $form->parse_amount($myconfig, $form->{"discount_$i"});

      my $linetotal_exact            = $form->{"qty_$i"} * $sellprice * (100 - $parsed_discount) / 100 / $price_factor->{factor};
      my $linetotal                  = $form->round_amount($linetotal_exact, 2);

      my $nodiscount_exact_linetotal = $form->{"qty_$i"} * $sellprice                                  / $price_factor->{factor};
      my $nodiscount_linetotal       = $form->round_amount($nodiscount_exact_linetotal,2);

      my $discount                   = $nodiscount_linetotal - $linetotal; # is always rounded because $nodiscount_linetotal and $linetotal are rounded

      my $discount_round_error       = $discount + ($linetotal_exact - $nodiscount_exact_linetotal); # not used

      $form->{"netprice_$i"}   = $form->round_amount($form->{"qty_$i"} ? ($linetotal / $form->{"qty_$i"}) : 0, $decimalplaces);

      push @{ $form->{TEMPLATE_ARRAYS}->{netprice} },       ($form->{"netprice_$i"} != 0) ? $form->format_amount($myconfig, $form->{"netprice_$i"}, $decimalplaces) : '';
      push @{ $form->{TEMPLATE_ARRAYS}->{netprice_nofmt} }, ($form->{"netprice_$i"} != 0) ? $form->{"netprice_$i"} : '';

      $linetotal = ($linetotal != 0) ? $linetotal : '';

      push @{ $form->{TEMPLATE_ARRAYS}->{discount} },       ($discount != 0) ? $form->format_amount($myconfig, $discount * -1, 2) : '';
      push @{ $form->{TEMPLATE_ARRAYS}->{discount_nofmt} }, ($discount != 0) ? $discount * -1 : '';
      push @{ $form->{TEMPLATE_ARRAYS}->{p_discount} },     $form->{"discount_$i"};

      if ( $prepared_template_arrays{separate}[$i - 1]  ) {
        my $pabbr = $prepared_template_arrays{separate}[$i - 1];
        if ( ! $form->{"separate_${pabbr}_subtotal"} ) {
            push @separate_totals , "separate_${pabbr}_subtotal";
            $form->{"separate_${pabbr}_subtotal"} = 0;
        }
        $form->{"separate_${pabbr}_subtotal"} += $linetotal;
      } else {
        $form->{non_separate_subtotal} += $linetotal;
      }

      $form->{total}            += $linetotal;
      $form->{nodiscount_total} += $nodiscount_linetotal;
      $form->{discount_total}   += $discount;

      if ($subtotal_header) {
        $discount_subtotal   += $linetotal;
        $nodiscount_subtotal += $nodiscount_linetotal;
      }

      if ($form->{"subtotal_$i"} && $subtotal_header && ($subtotal_header != $i)) {
        push @{ $form->{TEMPLATE_ARRAYS}->{discount_sub} },         $form->format_amount($myconfig, $discount_subtotal,   2);
        push @{ $form->{TEMPLATE_ARRAYS}->{discount_sub_nofmt} },   $discount_subtotal;
        push @{ $form->{TEMPLATE_ARRAYS}->{nodiscount_sub} },       $form->format_amount($myconfig, $nodiscount_subtotal, 2);
        push @{ $form->{TEMPLATE_ARRAYS}->{nodiscount_sub_nofmt} }, $nodiscount_subtotal;

        $discount_subtotal   = 0;
        $nodiscount_subtotal = 0;
        $subtotal_header     = 0;

      } else {
        push @{ $form->{TEMPLATE_ARRAYS}->{$_} }, "" for qw(discount_sub nodiscount_sub discount_sub_nofmt nodiscount_sub_nofmt);
      }

      if (!$form->{"discount_$i"}) {
        $nodiscount += $linetotal;
      }

      push @{ $form->{TEMPLATE_ARRAYS}->{linetotal} },                  $form->format_amount($myconfig, $linetotal, 2);
      push @{ $form->{TEMPLATE_ARRAYS}->{linetotal_nofmt} },            $linetotal_exact;
      push @{ $form->{TEMPLATE_ARRAYS}->{nodiscount_linetotal} },       $form->format_amount($myconfig, $nodiscount_linetotal, 2);
      push @{ $form->{TEMPLATE_ARRAYS}->{nodiscount_linetotal_nofmt} }, $nodiscount_linetotal;

      my $project = $projects_by_id{$form->{"project_id_$i"}} || SL::DB::Project->new;

      push @{ $form->{TEMPLATE_ARRAYS}->{projectnumber} },              $project->projectnumber;
      push @{ $form->{TEMPLATE_ARRAYS}->{projectdescription} },         $project->description;

      my $lineweight = $form->{"qty_$i"} * $form->{"weight_$i"};
      $totalweight += $lineweight;
      push @{ $form->{TEMPLATE_ARRAYS}->{weight} },            $form->format_amount($myconfig, $form->{"weight_$i"}, 3);
      push @{ $form->{TEMPLATE_ARRAYS}->{weight_nofmt} },      $form->{"weight_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{lineweight} },        $form->format_amount($myconfig, $lineweight, 3);
      push @{ $form->{TEMPLATE_ARRAYS}->{lineweight_nofmt} },  $lineweight;

      @taxaccounts = split(/ /, $form->{"taxaccounts_$i"});
      $taxrate     = 0;
      $taxdiff     = 0;

      map { $taxrate += $form->{"${_}_rate"} } @taxaccounts;

      if ($form->{taxincluded}) {

        # calculate tax
        $taxamount = $linetotal * $taxrate / (1 + $taxrate);
        $taxbase = $linetotal - $taxamount;
      } else {
        $taxamount = $linetotal * $taxrate;
        $taxbase   = $linetotal;
      }

      if ($form->round_amount($taxrate, 7) == 0) {
        if ($form->{taxincluded}) {
          foreach my $accno (@taxaccounts) {
            $taxamount            = $form->round_amount($linetotal * $form->{"${accno}_rate"} / (1 + abs($form->{"${accno}_rate"})), 2);

            $taxaccounts{$accno} += $taxamount;
            $taxdiff             += $taxamount;

            $taxbase{$accno}     += $taxbase;
          }
          $taxaccounts{ $taxaccounts[0] } += $taxdiff;
        } else {
          foreach my $accno (@taxaccounts) {
            $taxaccounts{$accno} += $linetotal * $form->{"${accno}_rate"};
            $taxbase{$accno}     += $taxbase;
          }
        }
      } else {
        foreach my $accno (@taxaccounts) {
          $taxaccounts{$accno} += $taxamount * $form->{"${accno}_rate"} / $taxrate;
          $taxbase{$accno}     += $taxbase;
        }
      }
      my $tax_rate = $taxrate * 100;
      push(@{ $form->{TEMPLATE_ARRAYS}->{tax_rate} }, qq|$tax_rate|);
      if ($form->{"part_type_$i"} eq 'assembly') {
        $sameitem = "";

        # get parts and push them onto the stack
        my $sortorder = "";
        if ($form->{groupitems}) {
          $sortorder =
            qq|ORDER BY pg.partsgroup, a.position|;
        } else {
          $sortorder = qq|ORDER BY a.position|;
        }

        my $query =
          qq|SELECT p.partnumber, p.description, p.unit, a.qty, pg.partsgroup
             FROM assembly a
             JOIN parts p ON (a.parts_id = p.id)
             LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
             WHERE (a.bom = '1') AND (a.id = ?) $sortorder|;
        $sth = prepare_execute_query($form, $dbh, $query, conv_i($form->{"id_$i"}));

        while (my $ref = $sth->fetchrow_hashref('NAME_lc')) {
          if ($form->{groupitems} && $ref->{partsgroup} ne $sameitem) {
            map({ push(@{ $form->{TEMPLATE_ARRAYS}->{$_} }, "") } grep({ $_ ne "description" } (@arrays, @prepared_arrays)));
            $sameitem = ($ref->{partsgroup}) ? $ref->{partsgroup} : "--";
            push(@{ $form->{TEMPLATE_ARRAYS}->{entry_type}  }, 'assembly-item-partsgroup');
            push(@{ $form->{TEMPLATE_ARRAYS}->{description} }, $sameitem);
          }

          map { $form->{"a_$_"} = $ref->{$_} } qw(partnumber description);

          push(@{ $form->{TEMPLATE_ARRAYS}->{entry_type}  }, 'assembly-item');
          push(@{ $form->{TEMPLATE_ARRAYS}->{description} },
               $form->format_amount($myconfig, $ref->{qty} * $form->{"qty_$i"}
                 )
                 . qq| -- $form->{"a_partnumber"}, $form->{"a_description"}|);
          map({ push(@{ $form->{TEMPLATE_ARRAYS}->{$_} }, "") } grep({ $_ ne "description" } (@arrays, @prepared_arrays)));

        }
        $sth->finish;
      }

      CVar->get_non_editable_ic_cvars(form               => $form,
                                      dbh                => $dbh,
                                      row                => $i,
                                      sub_module         => 'invoice',
                                      may_converted_from => ['delivery_order_items', 'orderitems', 'invoice']);

      push @{ $form->{TEMPLATE_ARRAYS}->{"ic_cvar_$_->{name}"} },
        CVar->format_to_template(CVar->parse($form->{"ic_cvar_$_->{name}_$i"}, $_), $_)
          for @{ $ic_cvar_configs };

      push @{ $form->{TEMPLATE_ARRAYS}->{"project_cvar_" . $_->config->name} }, $_->value_as_text for @{ $project->cvars_by_config };
    }
  }

  $form->{totalweight}       = $form->format_amount($myconfig, $totalweight, 3);
  $form->{totalweight_nofmt} = $totalweight;
  my $defaults = AM->get_defaults();
  $form->{weightunit}        = $defaults->{weightunit};

  foreach my $item (sort keys %taxaccounts) {
    $tax += $taxamount = $form->round_amount($taxaccounts{$item}, 2);

    push(@{ $form->{TEMPLATE_ARRAYS}->{taxbase} },        $form->format_amount($myconfig, $taxbase{$item}, 2));
    push(@{ $form->{TEMPLATE_ARRAYS}->{taxbase_nofmt} },  $taxbase{$item});
    push(@{ $form->{TEMPLATE_ARRAYS}->{tax} },            $form->format_amount($myconfig, $taxamount,      2));
    push(@{ $form->{TEMPLATE_ARRAYS}->{tax_nofmt} },      $taxamount );
    push(@{ $form->{TEMPLATE_ARRAYS}->{taxrate} },        $form->format_amount($myconfig, $form->{"${item}_rate"} * 100));
    push(@{ $form->{TEMPLATE_ARRAYS}->{taxrate_nofmt} },  $form->{"${item}_rate"} * 100);
    push(@{ $form->{TEMPLATE_ARRAYS}->{taxnumber} },      $form->{"${item}_taxnumber"});
    push(@{ $form->{TEMPLATE_ARRAYS}->{tax_id} },         $form->{"${item}_tax_id"});

    # taxnumber (= accno) is used for grouping the amounts of the various taxes and as a prefix in form

    # This code used to assume that at most one tax entry can point to the same
    # chart_id, even though chart_id does not have a unique constraint!

    # This chart_id was then looked up via its accno, which is the key that is
    # used to group the different taxes by for a record

    # As we now also store the tax_id we can use that to look up the tax
    # instead, this is only done here to get the (translated) taxdescription.

    if ( $form->{"${item}_tax_id"} ) {
      my $tax_obj = SL::DB::Manager::Tax->find_by(id => $form->{"${item}_tax_id"}) or die "Can't find tax with id " . $form->{"${item}_tax_id"};
      my $description = $tax_obj ? $tax_obj->translated_attribute('taxdescription',  $form->{language_id}, 0) : '';
      push(@{ $form->{TEMPLATE_ARRAYS}->{taxdescription} }, $description . q{ } . 100 * $form->{"${item}_rate"} . q{%});
    }

  }

  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"}) {
      my ($accno, $description) = split(/--/, $form->{"AR_paid_$i"});

      push(@{ $form->{TEMPLATE_ARRAYS}->{payment} },        $form->{"paid_$i"});
      push(@{ $form->{TEMPLATE_ARRAYS}->{paymentaccount} }, $description);
      push(@{ $form->{TEMPLATE_ARRAYS}->{paymentdate} },    $form->{"datepaid_$i"});
      push(@{ $form->{TEMPLATE_ARRAYS}->{paymentsource} },  $form->{"source_$i"});
      push(@{ $form->{TEMPLATE_ARRAYS}->{paymentmemo} },    $form->{"memo_$i"});

      $form->{paid} += $form->parse_amount($myconfig, $form->{"paid_$i"});
    }
  }
  if($form->{taxincluded}) {
    $form->{subtotal}       = $form->format_amount($myconfig, $form->{total} - $tax, 2);
    $form->{subtotal_nofmt} = $form->{total} - $tax;
  }
  else {
    $form->{subtotal}       = $form->format_amount($myconfig, $form->{total}, 2);
    $form->{subtotal_nofmt} = $form->{total};
  }

  $form->{nodiscount_subtotal} = $form->format_amount($myconfig, $form->{nodiscount_total}, 2);
  $form->{discount_total}      = $form->format_amount($myconfig, $form->{discount_total}, 2);
  $form->{nodiscount}          = $form->format_amount($myconfig, $nodiscount, 2);
  $form->{yesdiscount}         = $form->format_amount($myconfig, $form->{nodiscount_total} - $nodiscount, 2);

  my $grossamount = ($form->{taxincluded}) ? $form->{total} : $form->{total} + $tax;
  $form->{invtotal} = $form->round_amount($grossamount, 2, 1);
  $form->{rounding} = $form->round_amount(
    $form->{invtotal} - $form->round_amount($grossamount, 2),
    2
  );

  $form->{rounding_nofmt} = $form->{rounding};
  $form->{total_nofmt}    = $form->{total};
  $form->{invtotal_nofmt} = $form->{invtotal};
  $form->{paid_nofmt}     = $form->{paid};

  $form->{rounding} = $form->format_amount($myconfig, $form->{rounding}, 2);
  $form->{total}    = $form->format_amount($myconfig, $form->{invtotal} - $form->{paid}, 2);
  $form->{invtotal} = $form->format_amount($myconfig, $form->{invtotal}, 2);
  $form->{paid}     = $form->format_amount($myconfig, $form->{paid}, 2);

  $form->set_payment_options($myconfig, $form->{invdate}, 'sales_invoice');

  $form->{department}    = SL::DB::Manager::Department->find_by(id => $form->{department_id})->description if $form->{department_id};
  $form->{delivery_term} = SL::DB::Manager::DeliveryTerm->find_by(id => $form->{delivery_term_id} || undef);
  $form->{delivery_term}->description_long($form->{delivery_term}->translated_attribute('description_long', $form->{language_id})) if $form->{delivery_term} && $form->{language_id};

  $form->{username} = $myconfig->{name};
  $form->{$_} = $form->format_amount($myconfig, $form->{$_}, 2) for @separate_totals;

  my $id_for_iap = $form->{convert_from_oe_ids} || $form->{convert_from_ar_ids} || $form->{id};
  my $from_order = !!$form->{convert_from_oe_ids};
  foreach my $invoice_for_advance_payment (@{$self->_get_invoices_for_advance_payment($id_for_iap, $from_order)}) {
    # Collect VAT of invoices for advance payment.
    # Set sellprices to fxsellprices for items, because
    # the PriceTaxCalculator sets fxsellprice from sellprice before calculating.
    $_->sellprice($_->fxsellprice) for @{$invoice_for_advance_payment->items};
    my %pat       = $invoice_for_advance_payment->calculate_prices_and_taxes;
    my $taxamount = sum0 values %{ $pat{taxes_by_tax_id} };

    push(@{ $form->{TEMPLATE_ARRAYS}->{"iap_$_"} },                $invoice_for_advance_payment->$_) for qw(invnumber transdate);
    push(@{ $form->{TEMPLATE_ARRAYS}->{"iap_amount_nofmt"} },      $invoice_for_advance_payment->amount);
    push(@{ $form->{TEMPLATE_ARRAYS}->{"iap_amount"} },            $invoice_for_advance_payment->amount_as_number);
    push(@{ $form->{TEMPLATE_ARRAYS}->{"iap_netamount"} },         $invoice_for_advance_payment->netamount_as_number);
    push(@{ $form->{TEMPLATE_ARRAYS}->{"iap_taxamount_nofmt"} },   $taxamount);
    push(@{ $form->{TEMPLATE_ARRAYS}->{"iap_taxamount"} },         $form->format_amount($myconfig, $taxamount, 2));

    my $open_amount = $form->round_amount($invoice_for_advance_payment->open_amount, 2);
    push(@{ $form->{TEMPLATE_ARRAYS}->{"iap_open_amount_nofmt"} }, $open_amount);
    push(@{ $form->{TEMPLATE_ARRAYS}->{"iap_open_amount"} },       $form->format_amount($myconfig, $open_amount, 2));

    $form->{iap_amount_nofmt}      += $invoice_for_advance_payment->amount;
    $form->{iap_taxamount_nofmt}   += $taxamount;
    $form->{iap_open_amount_nofmt} += $open_amount;
    $form->{iap_existing}           = 1;
  }
  $form->{iap_amount}      = $form->format_amount($myconfig, $form->{iap_amount_nofmt},      2);
  $form->{iap_taxamount}   = $form->format_amount($myconfig, $form->{iap_taxamount_nofmt},   2);
  $form->{iap_open_amount} = $form->format_amount($myconfig, $form->{iap_open_amount_nofmt}, 2);

  $form->{iap_final_amount_nofmt} = $form->{invtotal_nofmt} - $form->{iap_amount_nofmt};
  $form->{iap_final_amount}       = $form->format_amount($myconfig, $form->{iap_final_amount_nofmt}, 2);

  # set variables for swiss QR bill, if feature enabled
  # handling errors gracefully (don't die if undef)
  my $create_qrbill_invoices = $::instance_conf->get_create_qrbill_invoices;
  if ($::instance_conf->get_create_qrbill_invoices && $form->{formname} eq 'invoice') {
    my ($qr_account, $error) = get_qrbill_account();

    # case 1: QR-Reference number and QR-IBAN
    # case 2: without reference number and regular IBAN
    if ($create_qrbill_invoices == 1) {
      $form->{qrbill_iban} = $qr_account->{qr_iban};
    } elsif ($create_qrbill_invoices == 2) {
      $form->{qrbill_iban} = $qr_account->{iban};
    }

    my $biller_country = $::instance_conf->get_address_country() || 'CH';
    my $biller_countrycode = SL::Helper::ISO3166::map_name_to_alpha_2_code($biller_country);
    $form->{qrbill_biller_countrycode} = $biller_countrycode;

    my $customer_country = $form->{billing_address_id} ?
                            $form->{billing_address_country} || 'CH' :
                            $form->{country} || 'CH';
    my $customer_countrycode = SL::Helper::ISO3166::map_name_to_alpha_2_code($customer_country);
    $form->{qrbill_customer_countrycode} = $customer_countrycode;

    $form->{qrbill_amount} = sprintf("%.2f", $form->parse_amount($myconfig, $form->{'total'}));
  }
  $main::lxdebug->leave_sub();
}

sub customer_details {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, @wanted_vars) = @_;

  # connect to database
  my $dbh = $form->get_standard_dbh;

  my $language_id = $form->{language_id};

  # get contact id, set it if nessessary
  $form->{cp_id} *= 1;

  my @values =  (conv_i($form->{customer_id}));

  my $where = "";
  if ($form->{cp_id}) {
    $where = qq| AND (cp.cp_id = ?) |;
    push(@values, conv_i($form->{cp_id}));
  }

  # get rest for the customer
  my $query =
    qq|SELECT ct.*, cp.*, ct.notes as customernotes,
         ct.phone AS customerphone, ct.fax AS customerfax, ct.email AS customeremail,
         cu.name AS currency
       FROM customer ct
       LEFT JOIN contacts cp on ct.id = cp.cp_cv_id
       LEFT JOIN currencies cu ON (ct.currency_id = cu.id)
       WHERE (ct.id = ?) $where
       ORDER BY cp.cp_id
       LIMIT 1|;
  my $ref = selectfirst_hashref_query($form, $dbh, $query, @values);
  # we have no values, probably a invalid contact person. hotfix and first idea for issue #10
  if (!$ref) {
    my $customer = SL::DB::Manager::Customer->find_by(id => $::form->{customer_id});
    if ($customer) {
      $ref->{name} = $customer->name;
      $ref->{street} = $customer->street;
      $ref->{zipcode} = $customer->zipcode;
      $ref->{country} = $customer->country;
      $ref->{gln} = $customer->gln;
    }
    my $contact = SL::DB::Manager::Contact->find_by(cp_id => $::form->{cp_id});
    if ($contact) {
      $ref->{cp_name} = $contact->cp_name;
      $ref->{cp_givenname} = $contact->cp_givenname;
      $ref->{cp_gender} = $contact->cp_gender;
    }
  }
  # remove id,notes (double of customernotes) and taxincluded before copy back
  delete @$ref{qw(id taxincluded notes)};

  @wanted_vars = grep({ $_ } @wanted_vars);
  if (scalar(@wanted_vars) > 0) {
    my %h_wanted_vars;
    map({ $h_wanted_vars{$_} = 1; } @wanted_vars);
    map({ delete($ref->{$_}) unless ($h_wanted_vars{$_}); } keys(%{$ref}));
  }

  map { $form->{$_} = $ref->{$_} } keys %$ref;

  if ($form->{delivery_customer_id}) {
    $query =
      qq|SELECT *, notes as customernotes
         FROM customer
         WHERE id = ?
         LIMIT 1|;
    $ref = selectfirst_hashref_query($form, $dbh, $query, conv_i($form->{delivery_customer_id}));

    map { $form->{"dc_$_"} = $ref->{$_} } keys %$ref;
  }

  if ($form->{delivery_vendor_id}) {
    $query =
      qq|SELECT *, notes as customernotes
         FROM customer
         WHERE id = ?
         LIMIT 1|;
    $ref = selectfirst_hashref_query($form, $dbh, $query, conv_i($form->{delivery_vendor_id}));

    map { $form->{"dv_$_"} = $ref->{$_} } keys %$ref;
  }

  my $custom_variables = CVar->get_custom_variables('dbh'      => $dbh,
                                                    'module'   => 'CT',
                                                    'trans_id' => $form->{customer_id});
  map { $form->{"vc_cvar_$_->{name}"} = $_->{value} } @{ $custom_variables };

  if ($form->{cp_id}) {
    $custom_variables = CVar->get_custom_variables(dbh      => $dbh,
                                                   module   => 'Contacts',
                                                   trans_id => $form->{cp_id});
    $form->{"cp_cvar_$_->{name}"} = $_->{value} for @{ $custom_variables };
  }

  $form->{cp_greeting} = GenericTranslations->get('dbh'              => $dbh,
                                                  'translation_type' => 'greetings::' . ($form->{cp_gender} eq 'f' ? 'female' : 'male'),
                                                  'language_id'      => $language_id,
                                                  'allow_fallback'   => 1);


  $main::lxdebug->leave_sub();
}

sub post_invoice {
  my ($self, $myconfig, $form, $provided_dbh, %params) = @_;
  $main::lxdebug->enter_sub();

  my $rc = SL::DB->client->with_transaction(\&_post_invoice, $self, $myconfig, $form, $provided_dbh, %params);

  $::lxdebug->leave_sub;
  return $rc;
}

sub _post_invoice {
  my ($self, $myconfig, $form, $provided_dbh, %params) = @_;

  my $validity_token;
  if (!$form->{id}) {
    $validity_token = SL::DB::Manager::ValidityToken->fetch_valid_token(
      scope => SL::DB::ValidityToken::SCOPE_SALES_INVOICE_POST(),
      token => $form->{form_validity_token},
    );

    die $::locale->text('The form is not valid anymore.') if !$validity_token;
  }

  my $payments_only = $params{payments_only};
  my $dbh = $provided_dbh || SL::DB->client->dbh;
  my $restricter = SL::HTML::Restrict->create;

  my ($query, $sth, $null, $project_id, @values);
  my $exchangerate = 0;

  my $ic_cvar_configs = CVar->get_configs(module => 'IC',
                                          dbh    => $dbh);

  if (!$form->{employee_id}) {
    $form->get_employee($dbh);
  }

  $form->{defaultcurrency} = $form->get_default_currency($myconfig);
  my $defaultcurrency = $form->{defaultcurrency};

  my $all_units = AM->retrieve_units($myconfig, $form);

  my $already_booked = !!$form->{id};

  if (!$payments_only) {
    if ($form->{storno}) {
      _delete_transfers($dbh, $form, $form->{storno_id});
    }
    if ($form->{id}) {
      &reverse_invoice($dbh, $form);
      _delete_transfers($dbh, $form, $form->{id});

    } else {
      my $trans_number   = SL::TransNumber->new(type => $form->{type}, dbh => $dbh, number => $form->{invnumber}, save => 1);
      $form->{invnumber} = $trans_number->create_unique unless $trans_number->is_unique;

      $query = qq|SELECT nextval('glid')|;
      ($form->{"id"}) = selectrow_query($form, $dbh, $query);

      $query = qq|INSERT INTO ar (id, invnumber, currency_id, taxzone_id) VALUES (?, ?, (SELECT id FROM currencies WHERE name=?), ?)|;
      do_query($form, $dbh, $query, $form->{"id"}, $form->{"id"}, $form->{currency}, $form->{taxzone_id});

      if (!$form->{invnumber}) {
        my $trans_number   = SL::TransNumber->new(type => $form->{type}, dbh => $dbh, number => $form->{invnumber}, id => $form->{id});
        $form->{invnumber} = $trans_number->create_unique;
      }
    }
  }

  my ($netamount, $invoicediff) = (0, 0);
  my ($amount, $linetotal, $lastincomeaccno);

  if ($form->{currency} eq $defaultcurrency) {
    $form->{exchangerate} = 1;
  } else {
    $exchangerate         = $form->check_exchangerate($myconfig, $form->{currency}, $form->{invdate}, 'buy');
    $form->{exchangerate} = $form->parse_amount($myconfig, $form->{exchangerate}, 5);

    # if default exchangerate is not defined, define one
    unless ($exchangerate) {
      $form->update_exchangerate($dbh, $form->{currency}, $form->{invdate}, $form->{exchangerate}, 0);
      # delete records exchangerate -> if user sets new invdate for record
      $query = qq|UPDATE ar set exchangerate = NULL where id = ?|;
      do_query($form, $dbh, $query, $form->{"id"});
    }
    # update record exchangerate, if the default is set and differs from current
    if ($exchangerate && ($form->{exchangerate} != $exchangerate)) {
      $form->update_exchangerate($dbh, $form->{currency}, $form->{invdate},
                                 $form->{exchangerate}, 0, $form->{id}, 'ar');
    }
  }

  $form->{expense_inventory} = "";

  my %baseunits;

  $form->get_lists('price_factors' => 'ALL_PRICE_FACTORS');
  my %price_factors = map { $_->{id} => $_->{factor} } @{ $form->{ALL_PRICE_FACTORS} };
  my $price_factor;

  $form->{amount}      = {};
  $form->{amount_cogs} = {};

  my @processed_invoice_ids;

  foreach my $i (1 .. $form->{rowcount}) {
    if ($form->{type} eq "credit_note") {
      $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"}) * -1;
      $form->{shipped} = 1;
    } else {
      $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});
    }
    my $basefactor;
    my $baseqty;

    $form->{"marge_percent_$i"} = $form->parse_amount($myconfig, $form->{"marge_percent_$i"}) * 1;
    $form->{"marge_absolut_$i"} = $form->parse_amount($myconfig, $form->{"marge_absolut_$i"}) * 1;
    $form->{"lastcost_$i"} = $form->parse_amount($myconfig, $form->{"lastcost_$i"}) * 1;

    if ($form->{storno}) {
      $form->{"qty_$i"} *= -1;
    }

    if ($form->{"id_$i"}) {
      my $item_unit;
      my $position = $i;

      if (defined($baseunits{$form->{"id_$i"}})) {
        $item_unit = $baseunits{$form->{"id_$i"}};
      } else {
        # get item baseunit
        $query = qq|SELECT unit FROM parts WHERE id = ?|;
        ($item_unit) = selectrow_query($form, $dbh, $query, conv_i($form->{"id_$i"}));
        $baseunits{$form->{"id_$i"}} = $item_unit;
      }

      if (defined($all_units->{$item_unit}->{factor})
          && ($all_units->{$item_unit}->{factor} ne '')
          && ($all_units->{$item_unit}->{factor} != 0)) {
        $basefactor = $all_units->{$form->{"unit_$i"}}->{factor} / $all_units->{$item_unit}->{factor};
      } else {
        $basefactor = 1;
      }
      $baseqty = $form->{"qty_$i"} * $basefactor;

      my ($allocated, $taxrate) = (0, 0);
      my $taxamount;

      # add tax rates
      map { $taxrate += $form->{"${_}_rate"} } split(/ /, $form->{"taxaccounts_$i"});

      # keep entered selling price
      my $fxsellprice =
        $form->parse_amount($myconfig, $form->{"sellprice_$i"});

      my ($dec) = ($fxsellprice =~ /\.(\d+)/);
      $dec = length $dec;
      my $decimalplaces = ($dec > 2) ? $dec : 2;

      # undo discount formatting
      $form->{"discount_$i"} = $form->parse_amount($myconfig, $form->{"discount_$i"}) / 100;

      # deduct discount
      $form->{"sellprice_$i"} = $fxsellprice * (1 - $form->{"discount_$i"});

      # round linetotal to 2 decimal places
      $price_factor = $price_factors{ $form->{"price_factor_id_$i"} } || 1;
      $linetotal    = $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"} / $price_factor, 2);

      if ($form->{taxincluded}) {
        $taxamount = $linetotal * ($taxrate / (1 + $taxrate));
        $form->{"sellprice_$i"} =
          $form->{"sellprice_$i"} * (1 / (1 + $taxrate));
      } else {
        $taxamount = $linetotal * $taxrate;
      }

      $netamount += $linetotal;

      if ($taxamount != 0) {
        map {
          $form->{amount}{ $form->{id} }{$_} +=
            $taxamount * $form->{"${_}_rate"} / $taxrate
        } split(/ /, $form->{"taxaccounts_$i"});
      }

      # add amount to income, $form->{amount}{trans_id}{accno}
      $amount = $form->{"sellprice_$i"} * $form->{"qty_$i"} * $form->{exchangerate} / $price_factor;

      $linetotal = $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"} / $price_factor, 2) * $form->{exchangerate};
      $linetotal = $form->round_amount($linetotal, 2);

      # this is the difference from the inventory
      $invoicediff += ($amount - $linetotal);

      $form->{amount}{ $form->{id} }{ $form->{"income_accno_$i"} } +=
        $linetotal;

      $lastincomeaccno = $form->{"income_accno_$i"};

      # adjust and round sellprice
      $form->{"sellprice_$i"} =
        $form->round_amount($form->{"sellprice_$i"} * $form->{exchangerate},
                            $decimalplaces);

      next if $payments_only;



      # do cogs only if inventory_sytem perpetual is active
      if  ($::instance_conf->get_inventory_system eq 'perpetual'
        && $form->{"inventory_accno_$i"} || $form->{"part_type_$i"} eq 'assembly') {

        if ($form->{"part_type_$i"} eq 'assembly') {
          # record assembly item as allocated
          &process_assembly($dbh, $myconfig, $form, $position, $form->{"id_$i"}, $baseqty);

        } else {
          $allocated = &cogs($dbh, $myconfig, $form, $form->{"id_$i"}, $baseqty, $basefactor, $i);
        }
      }

      # Get pricegroup_id and save it. Unfortunately the interface
      # also uses ID "0" for signalling that none is selected, but "0"
      # must not be stored in the database. Therefore we cannot simply
      # use conv_i().
      ($null, my $pricegroup_id) = split(/--/, $form->{"sellprice_pg_$i"});
      $pricegroup_id *= 1;
      $pricegroup_id  = undef if !$pricegroup_id;

      CVar->get_non_editable_ic_cvars(form               => $form,
                                      dbh                => $dbh,
                                      row                => $i,
                                      sub_module         => 'invoice',
                                      may_converted_from => ['delivery_order_items', 'orderitems', 'invoice']);

      if (!$form->{"invoice_id_$i"}) {
        # there is no persistent id, therefore create one with all necessary constraints
        my $q_invoice_id = qq|SELECT nextval('invoiceid')|;
        my $h_invoice_id = prepare_query($form, $dbh, $q_invoice_id);
        do_statement($form, $h_invoice_id, $q_invoice_id);
        $form->{"invoice_id_$i"}  = $h_invoice_id->fetchrow_array();
        my $q_create_invoice_id = qq|INSERT INTO invoice (id, trans_id, position, parts_id) values (?, ?, ?, ?)|;
        do_query($form, $dbh, $q_create_invoice_id, conv_i($form->{"invoice_id_$i"}),
                 conv_i($form->{id}), conv_i($position), conv_i($form->{"id_$i"}));
        $h_invoice_id->finish();
      }

      # save detail record in invoice table
      $query = <<SQL;
        UPDATE invoice SET trans_id = ?, position = ?, parts_id = ?, description = ?, longdescription = ?, qty = ?,
                           sellprice = ?, fxsellprice = ?, discount = ?, allocated = ?, assemblyitem = ?,
                           unit = ?, deliverydate = ?, project_id = ?, serialnumber = ?, pricegroup_id = ?,
                           base_qty = ?, subtotal = ?,
                           marge_percent = ?, marge_total = ?, lastcost = ?, active_price_source = ?, active_discount_source = ?,
                           price_factor_id = ?, price_factor = (SELECT factor FROM price_factors WHERE id = ?), marge_price_factor = ?
        WHERE id = ?
SQL

      @values = (conv_i($form->{id}), conv_i($position), conv_i($form->{"id_$i"}),
                 $form->{"description_$i"}, $restricter->process($form->{"longdescription_$i"}), $form->{"qty_$i"},
                 $form->{"sellprice_$i"}, $fxsellprice,
                 $form->{"discount_$i"}, $allocated, 'f',
                 $form->{"unit_$i"}, conv_date($form->{"reqdate_$i"}), conv_i($form->{"project_id_$i"}),
                 trim($form->{"serialnumber_$i"}), $pricegroup_id,
                 $baseqty, $form->{"subtotal_$i"} ? 't' : 'f',
                 $form->{"marge_percent_$i"}, $form->{"marge_absolut_$i"},
                 $form->{"lastcost_$i"},
                 $form->{"active_price_source_$i"}, $form->{"active_discount_source_$i"},
                 conv_i($form->{"price_factor_id_$i"}), conv_i($form->{"price_factor_id_$i"}),
                 conv_i($form->{"marge_price_factor_$i"}),
                 conv_i($form->{"invoice_id_$i"}));
      do_query($form, $dbh, $query, @values);
      push @processed_invoice_ids, $form->{"invoice_id_$i"};

      CVar->save_custom_variables(module       => 'IC',
                                  sub_module   => 'invoice',
                                  trans_id     => $form->{"invoice_id_$i"},
                                  configs      => $ic_cvar_configs,
                                  variables    => $form,
                                  name_prefix  => 'ic_',
                                  name_postfix => "_$i",
                                  dbh          => $dbh);
    }
    # link previous items with invoice items
    foreach (qw(delivery_order_items orderitems invoice reclamation_items)) {
      if (!$form->{useasnew} && $form->{"converted_from_${_}_id_$i"}) {
        RecordLinks->create_links('dbh'        => $dbh,
                                  'mode'       => 'ids',
                                  'from_table' => $_,
                                  'from_ids'   => $form->{"converted_from_${_}_id_$i"},
                                  'to_table'   => 'invoice',
                                  'to_id'      => $form->{"invoice_id_$i"},
        );
      }
      delete $form->{"converted_from_${_}_id_$i"};
    }
  }

  # total payments, don't move we need it here
  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->{type} eq "credit_note") {
      $form->{"paid_$i"} = $form->parse_amount($myconfig, $form->{"paid_$i"}) * -1;
    } else {
      $form->{"paid_$i"} = $form->parse_amount($myconfig, $form->{"paid_$i"});
    }
    $form->{paid} += $form->{"paid_$i"};
    $form->{datepaid} = $form->{"datepaid_$i"} if ($form->{"datepaid_$i"});
  }

  my ($tax, $diff) = (0, 0);

  $netamount = $form->round_amount($netamount, 2);

  # figure out rounding errors for total amount vs netamount + taxes
  if ($form->{taxincluded}) {

    $amount = $form->round_amount($netamount * $form->{exchangerate}, 2);
    $diff += $amount - $netamount * $form->{exchangerate};
    $netamount = $amount;

    foreach my $item (split(/ /, $form->{taxaccounts})) {
      $amount = $form->{amount}{ $form->{id} }{$item} * $form->{exchangerate};
      $form->{amount}{ $form->{id} }{$item} = $form->round_amount($amount, 2);
      $tax += $form->{amount}{ $form->{id} }{$item};
      $netamount -= $form->{amount}{ $form->{id} }{$item};
    }

    $invoicediff += $diff;
    ######## this only applies to tax included
    if ($lastincomeaccno) {
      $form->{amount}{ $form->{id} }{$lastincomeaccno} += $invoicediff;
    }

  } else {
    $amount    = $form->round_amount($netamount * $form->{exchangerate}, 2);
    $diff      = $amount - $netamount * $form->{exchangerate};
    $netamount = $amount;
    foreach my $item (split(/ /, $form->{taxaccounts})) {
      $form->{amount}{ $form->{id} }{$item} =
        $form->round_amount($form->{amount}{ $form->{id} }{$item}, 2);
      $amount =
        $form->round_amount(
                 $form->{amount}{ $form->{id} }{$item} * $form->{exchangerate},
                 2);
      $diff +=
        $amount - $form->{amount}{ $form->{id} }{$item} *
        $form->{exchangerate};
      $form->{amount}{ $form->{id} }{$item} = $form->round_amount($amount, 2);
      $tax += $form->{amount}{ $form->{id} }{$item};
    }
  }

  # Invoice Summary includes Rounding
  my $grossamount = $netamount + $tax;
  my $rounding = $form->round_amount(
    $form->round_amount($grossamount, 2, 1) - $form->round_amount($grossamount, 2),
    2
  );
  my $rnd_accno = $rounding == 0 ? 0
                : $rounding > 0  ? $form->{rndgain_accno}
                :                  $form->{rndloss_accno}
  ;
  $form->{amount}{ $form->{id} }{ $form->{AR} } = $form->round_amount($grossamount, 2, 1);
  $form->{paid} = $form->round_amount(
    $form->{paid} * $form->{exchangerate} + $diff,
    2
  );

  # reverse AR
  $form->{amount}{ $form->{id} }{ $form->{AR} } *= -1;

  $project_id = conv_i($form->{"globalproject_id"});
  # entsprechend auch beim Bestimmen des Steuerschlüssels in Taxkey.pm berücksichtigen
  my $taxdate = $form->{tax_point} ||$form->{deliverydate} || $form->{invdate};

  # Sanity checks for invoices for advance payment and final invoices
  my $advance_payment_clearing_chart;
  if (any { $_ eq $form->{type} } qw(invoice_for_advance_payment final_invoice)) {
    $advance_payment_clearing_chart = SL::DB::Chart->new(id => $::instance_conf->get_advance_payment_clearing_chart_id)->load;
    die "No Clearing Chart for Advance Payment" unless ref $advance_payment_clearing_chart eq 'SL::DB::Chart';

    my @current_taxaccounts = (split(/ /, $form->{taxaccounts}));
    die 'Wrong call: Cannot post invoice for advance payment or final invoice with more than one tax' if (scalar @current_taxaccounts > 1);

    my @trans_ids = keys %{ $form->{amount} };
    if (scalar @trans_ids > 1) {
      require Data::Dumper;
      die "Invalid state for advance payment more than one trans_id " . Dumper($form->{amount});
    }
  }

  my $iap_amounts;
  if ($form->{type} eq 'final_invoice') {
    my $id_for_iap = $form->{convert_from_oe_ids} || $form->{convert_from_ar_ids} || $form->{id};
    my $from_order = !!$form->{convert_from_oe_ids};
    my $invoices_for_advance_payment = $self->_get_invoices_for_advance_payment($id_for_iap, $from_order);
    if (scalar @$invoices_for_advance_payment > 0) {
      # reverse booking for invoices for advance payment
      foreach my $invoice_for_advance_payment (@$invoices_for_advance_payment) {
        # delete ?
        # --> is implemented below (bookings are marked in memo field)
        #
        # TODO: helper table acc_trans_advance_payment
        # trans_id for final invoice connects to acc_trans_id here
        # my $booking = SL::DB::AccTrans->new( ...)
        # --> helper table not nessessary because of mark in memo field
        #
        # TODO: If final_invoice change (delete storno) delete all connectin acc_trans entries, if
        # period is not closed
        # --> no problem because gldate of reverse booking is date of final invoice
        #     if deletion of final invoice is allowed, reverting bookings in invoices
        #     for advance payment are allowed, too.
        # $booking->id, $self->id in helper table
        if (!$already_booked) {
          # move all netamount to correct transfer chart (19% or 7%)
          my %inv_calc = $invoice_for_advance_payment->calculate_prices_and_taxes();
          my @trans_ids = keys %{ $inv_calc{amounts} };
          die "Invalid state for advance payment invoice,more than one trans_id" if (scalar @trans_ids > 1);
          my $entry = delete $inv_calc{amounts}{$trans_ids[0]};
          my $tax;
          if ($entry->{tax_id}) {
            $tax = SL::DB::Manager::Tax->find_by(id => $entry->{tax_id}); # || die "Can't find tax with id " . $entry->{tax_id};
          }
          # no tax, no prob
          if ($tax and $tax->rate != 0) {
            die "Need a valid chart id for table defaults column advance_payment_taxable_7"  if $tax->taxkey == 2 && ! $::instance_conf->get_advance_payment_taxable_7_id;
            die "Need a valid chart id for table defaults column advance_payment_taxable_19" if $tax->taxkey == 3 && ! $::instance_conf->get_advance_payment_taxable_19_id;
            my $transfer_chart = $tax->taxkey == 2 ? SL::DB::Chart->new(id => $::instance_conf->get_advance_payment_taxable_7_id)->load
                              :  $tax->taxkey == 3 ? SL::DB::Chart->new(id => $::instance_conf->get_advance_payment_taxable_19_id)->load
                              :  undef;
            die "No Transfer Chart for Advance Payment" unless ref $transfer_chart eq 'SL::DB::Chart';
            $form->{amount}->{$invoice_for_advance_payment->id}->{$transfer_chart->accno} = -1 * $invoice_for_advance_payment->netamount;
            $form->{memo}  ->{$invoice_for_advance_payment->id}->{$transfer_chart->accno} = 'reverse booking by final invoice';
            # AR
            $form->{amount}->{$invoice_for_advance_payment->id}->{$form->{AR}} = $invoice_for_advance_payment->netamount;
            $form->{memo}  ->{$invoice_for_advance_payment->id}->{$form->{AR}} = 'reverse booking by final invoice';
          }
        }

        # VAT for invoices for advance payment is booked on payment of these. So do not book this VAT for final invoice.
        # And book the amount of the invoices for advance payment with taxkey 0 (see below).
        # Collect amounts and VAT of invoices for advance payment.

        # Set sellprices to fxsellprices for items, because
        # the PriceTaxCalculator sets fxsellprice from sellprice before calculating.
        $_->sellprice($_->fxsellprice) for @{$invoice_for_advance_payment->items};
        my %pat = $invoice_for_advance_payment->calculate_prices_and_taxes;

        foreach my $tax_chart_id (keys %{ $pat{taxes_by_chart_id} }) {
          my $tax_accno = SL::DB::Chart->load_cached($tax_chart_id)->accno;
          $form->{amount}{ $form->{id} }{$tax_accno}  -= $pat{taxes_by_chart_id}->{$tax_chart_id};
          $form->{amount}{ $form->{id} }{$form->{AR}} += $pat{taxes_by_chart_id}->{$tax_chart_id};
        }

        foreach my $amount_chart_id (keys %{ $pat{amounts} }) {
          my $amount_accno = SL::DB::Chart->load_cached($amount_chart_id)->accno;
          $iap_amounts->{$amount_accno}                 += $pat{amounts}->{$amount_chart_id}->{amount};
          $form->{amount}{ $form->{id} }{$amount_accno} -= $pat{amounts}->{$amount_chart_id}->{amount};
        }
      }
    }
  }

  if ($form->{type} eq 'invoice_for_advance_payment') {
    # get gross and move to clearing chart - delete everything else
    # 1. gross
    my $gross = $form->{amount}{ $form->{id} }{$form->{AR}};
    # 2. destroy
    undef $form->{amount}{ $form->{id} };
    # 3. rebuild
    $form->{amount}{ $form->{id} }{$form->{AR}}            = $gross;
    $form->{amount}{ $form->{id} }{$advance_payment_clearing_chart->accno} = $gross * -1;
    # 4. no cogs, hopefully not commonly used at all
    undef $form->{amount_cogs};
  }

  foreach my $trans_id (keys %{ $form->{amount_cogs} }) {
    foreach my $accno (keys %{ $form->{amount_cogs}{$trans_id} }) {
      next unless ($form->{expense_inventory} =~ /\Q$accno\E/);

      $form->{amount_cogs}{$trans_id}{$accno} = $form->round_amount($form->{amount_cogs}{$trans_id}{$accno}, 2);

      if (!$payments_only && ($form->{amount_cogs}{$trans_id}{$accno} != 0)) {
        $query =
          qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, tax_id, taxkey, project_id, chart_link)
               VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, (SELECT id FROM tax WHERE taxkey=0), 0, ?, (SELECT link FROM chart WHERE accno = ?))|;
        @values = (conv_i($trans_id), $accno, $form->{amount_cogs}{$trans_id}{$accno}, conv_date($form->{invdate}), conv_i($project_id), $accno);
        do_query($form, $dbh, $query, @values);
        $form->{amount_cogs}{$trans_id}{$accno} = 0;
      }
    }

    foreach my $accno (keys %{ $form->{amount_cogs}{$trans_id} }) {
      $form->{amount_cogs}{$trans_id}{$accno} = $form->round_amount($form->{amount_cogs}{$trans_id}{$accno}, 2);

      if (!$payments_only && ($form->{amount_cogs}{$trans_id}{$accno} != 0)) {
        $query =
          qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, tax_id, taxkey, project_id, chart_link)
               VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, (SELECT id FROM tax WHERE taxkey=0), 0, ?, (SELECT link FROM chart WHERE accno = ?))|;
        @values = (conv_i($trans_id), $accno, $form->{amount_cogs}{$trans_id}{$accno}, conv_date($form->{invdate}), conv_i($project_id), $accno);
        do_query($form, $dbh, $query, @values);
      }
    }
  }

  foreach my $trans_id (keys %{ $form->{amount} }) {
    foreach my $accno (keys %{ $form->{amount}{$trans_id} }) {
      next unless ($form->{expense_inventory} =~ /\Q$accno\E/);

      $form->{amount}{$trans_id}{$accno} = $form->round_amount($form->{amount}{$trans_id}{$accno}, 2);

      if (!$payments_only && ($form->{amount}{$trans_id}{$accno} != 0)) {
        $query =
          qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, tax_id, taxkey, project_id, chart_link, memo)
             VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?,
                     (SELECT tax_id
                      FROM taxkeys
                      WHERE chart_id= (SELECT id
                                       FROM chart
                                       WHERE accno = ?)
                      AND startdate <= ?
                      ORDER BY startdate DESC LIMIT 1),
                     (SELECT taxkey_id
                      FROM taxkeys
                      WHERE chart_id= (SELECT id
                                       FROM chart
                                       WHERE accno = ?)
                      AND startdate <= ?
                      ORDER BY startdate DESC LIMIT 1),
                     ?,
                     (SELECT link FROM chart WHERE accno = ?),
                     ?)|;
        @values = (conv_i($trans_id), $accno, $form->{amount}{$trans_id}{$accno}, conv_date($form->{invdate}), $accno, conv_date($taxdate), $accno, conv_date($taxdate), conv_i($project_id), $accno, $form->{memo}{$trans_id}{$accno});
        do_query($form, $dbh, $query, @values);
        $form->{amount}{$trans_id}{$accno} = 0;
      }
    }

    foreach my $accno (keys %{ $form->{amount}{$trans_id} }) {
      $form->{amount}{$trans_id}{$accno} = $form->round_amount($form->{amount}{$trans_id}{$accno}, 2);

      if (!$payments_only && ($form->{amount}{$trans_id}{$accno} != 0)) {
        $query =
          qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, tax_id, taxkey, project_id, chart_link, memo)
             VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?,
                     (SELECT tax_id
                      FROM taxkeys
                      WHERE chart_id= (SELECT id
                                       FROM chart
                                       WHERE accno = ?)
                      AND startdate <= ?
                      ORDER BY startdate DESC LIMIT 1),
                     (SELECT taxkey_id
                      FROM taxkeys
                      WHERE chart_id= (SELECT id
                                       FROM chart
                                       WHERE accno = ?)
                      AND startdate <= ?
                      ORDER BY startdate DESC LIMIT 1),
                     ?,
                     (SELECT link FROM chart WHERE accno = ?),
                     ?)|;
        @values = (conv_i($trans_id), $accno, $form->{amount}{$trans_id}{$accno}, conv_date($form->{invdate}), $accno, conv_date($taxdate), $accno, conv_date($taxdate), conv_i($project_id), $accno,$form->{memo}{$trans_id}{$accno});
        do_query($form, $dbh, $query, @values);
      }
    }
    if (!$payments_only && ($rnd_accno != 0)) {
      $query =
        qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, tax_id, taxkey, project_id, chart_link)
             VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, (SELECT id FROM tax WHERE taxkey=0), 0, ?, (SELECT link FROM chart WHERE accno = ?))|;
      @values = (conv_i($trans_id), $rnd_accno, $rounding, conv_date($form->{invdate}), conv_i($project_id), $rnd_accno);
      do_query($form, $dbh, $query, @values);
      $rnd_accno = 0;
    }
  }

  # Book the amount of the invoices for advance payment with taxkey 0 (see below).
  if ($form->{type} eq 'final_invoice' && $iap_amounts) {
    foreach my $accno (keys %$iap_amounts) {
      $query =
        qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, tax_id, taxkey, project_id, chart_link)
        VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, (SELECT id FROM tax WHERE taxkey=0), 0, ?, (SELECT link FROM chart WHERE accno = ?))|;
      @values = (conv_i($form->{id}), $accno, $iap_amounts->{$accno}, conv_date($form->{invdate}), conv_i($project_id), $accno);
      do_query($form, $dbh, $query, @values);
    }
  }

  # deduct payment differences from diff
  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"} != 0) {
      $amount =
        $form->round_amount($form->{"paid_$i"} * $form->{exchangerate}, 2);
      $diff -= $amount - $form->{"paid_$i"} * $form->{exchangerate};
    }
  }

  my %already_cleared = %{ $params{already_cleared} // {} };

  # record payments and offsetting AR
  if (!$form->{storno}) {
    for my $i (1 .. $form->{paidaccounts}) {

      if ($form->{"acc_trans_id_$i"}
          && $payments_only
          && (SL::DB::Default->get->payments_changeable == 0)) {
        next;
      }

      next if ($form->{"paid_$i"} == 0);

      my ($accno) = split(/--/, $form->{"AR_paid_$i"});
      $form->{"datepaid_$i"} = $form->{invdate}
      unless ($form->{"datepaid_$i"});
      $form->{datepaid} = $form->{"datepaid_$i"};

      $exchangerate = 0;

      if ($form->{currency} eq $defaultcurrency) {
        $form->{"exchangerate_$i"} = 1;
      } else {
        $exchangerate              = $form->check_exchangerate($myconfig, $form->{currency}, $form->{"datepaid_$i"}, 'buy');
        $form->{"exchangerate_$i"} = $exchangerate || $form->parse_amount($myconfig, $form->{"exchangerate_$i"});
      }

      # record AR
      $amount = $form->round_amount($form->{"paid_$i"} * $form->{exchangerate} + $diff, 2);

      my $new_cleared = !$form->{"acc_trans_id_$i"}                                                       ? 'f'
                      : !$already_cleared{$form->{"acc_trans_id_$i"}}                                     ? 'f'
                      : $already_cleared{$form->{"acc_trans_id_$i"}}->{amount} != $form->{"paid_$i"} * -1 ? 'f'
                      : $already_cleared{$form->{"acc_trans_id_$i"}}->{accno}  != $accno                  ? 'f'
                      : $already_cleared{$form->{"acc_trans_id_$i"}}->{cleared}                           ? 't'
                      :                                                                                     'f';

      if ($form->{amount}{ $form->{id} }{ $form->{AR} } != 0) {
        $query =
        qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, tax_id, taxkey, project_id, cleared, chart_link)
           VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?,
                   (SELECT tax_id
                    FROM taxkeys
                    WHERE chart_id= (SELECT id
                                     FROM chart
                                     WHERE accno = ?)
                    AND startdate <= ?
                    ORDER BY startdate DESC LIMIT 1),
                   (SELECT taxkey_id
                    FROM taxkeys
                    WHERE chart_id= (SELECT id
                                     FROM chart
                                     WHERE accno = ?)
                    AND startdate <= ?
                    ORDER BY startdate DESC LIMIT 1),
                   ?, ?,
                   (SELECT link FROM chart WHERE accno = ?))|;
        @values = (conv_i($form->{"id"}), $form->{AR}, $amount, $form->{"datepaid_$i"}, $form->{AR}, conv_date($taxdate), $form->{AR}, conv_date($taxdate), $project_id, $new_cleared, $form->{AR});
        do_query($form, $dbh, $query, @values);
      }

      # record payment
      $form->{"paid_$i"} *= -1;
      my $gldate = (conv_date($form->{"gldate_$i"}))? conv_date($form->{"gldate_$i"}) : conv_date($form->current_date($myconfig));

      $query =
      qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, gldate, source, memo, tax_id, taxkey, project_id, cleared, chart_link)
         VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, ?, ?, ?,
                 (SELECT tax_id
                  FROM taxkeys
                  WHERE chart_id= (SELECT id
                                   FROM chart
                                   WHERE accno = ?)
                  AND startdate <= ?
                  ORDER BY startdate DESC LIMIT 1),
                 (SELECT taxkey_id
                  FROM taxkeys
                  WHERE chart_id= (SELECT id
                                   FROM chart
                                   WHERE accno = ?)
                  AND startdate <= ?
                  ORDER BY startdate DESC LIMIT 1),
                 ?, ?,
                 (SELECT link FROM chart WHERE accno = ?))|;
      @values = (conv_i($form->{"id"}), $accno, $form->{"paid_$i"}, $form->{"datepaid_$i"},
                 $gldate, $form->{"source_$i"}, $form->{"memo_$i"}, $accno, conv_date($taxdate), $accno, conv_date($taxdate), $project_id, $new_cleared, $accno);
      do_query($form, $dbh, $query, @values);

      # exchangerate difference
      $form->{fx}{$accno}{ $form->{"datepaid_$i"} } +=
        $form->{"paid_$i"} * ($form->{"exchangerate_$i"} - 1) + $diff;

      # gain/loss
      $amount =
        $form->{"paid_$i"} * $form->{exchangerate} - $form->{"paid_$i"} *
        $form->{"exchangerate_$i"};
      if ($amount > 0) {
        $form->{fx}{ $form->{fxgain_accno} }{ $form->{"datepaid_$i"} } += $amount;
      } else {
        $form->{fx}{ $form->{fxloss_accno} }{ $form->{"datepaid_$i"} } += $amount;
      }

      $diff = 0;

      # update exchange rate for PAYMENTS
      # exchangerate contains a new exchangerate of the payment date
      if (($form->{currency} ne $defaultcurrency) && !$exchangerate) {
        $form->{script} = 'is.pl';
        $form->update_exchangerate($dbh, $form->{currency},
                                   $form->{"datepaid_$i"},
                                   $form->{"exchangerate_$i"}, 0);
      }
    }

  } else {                      # if (!$form->{storno})
    $form->{marge_total} *= -1;
  }

  IO->set_datepaid(table => 'ar', id => $form->{id}, dbh => $dbh);

  # record exchange rate differences and gains/losses
  foreach my $accno (keys %{ $form->{fx} }) {
    foreach my $transdate (keys %{ $form->{fx}{$accno} }) {
      $form->{fx}{$accno}{$transdate} = $form->round_amount($form->{fx}{$accno}{$transdate}, 2);
      if ( $form->{fx}{$accno}{$transdate} != 0 ) {

        $query =
          qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, cleared, fx_transaction, tax_id, taxkey, project_id, chart_link)
             VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, '0', '1',
                 (SELECT tax_id
                  FROM taxkeys
                  WHERE chart_id= (SELECT id
                                   FROM chart
                                   WHERE accno = ?)
                  AND startdate <= ?
                  ORDER BY startdate DESC LIMIT 1),
                 (SELECT taxkey_id
                  FROM taxkeys
                  WHERE chart_id= (SELECT id
                                   FROM chart
                                   WHERE accno = ?)
                  AND startdate <= ?
                  ORDER BY startdate DESC LIMIT 1),
                 ?,
                 (SELECT link FROM chart WHERE accno = ?))|;
        @values = (conv_i($form->{"id"}), $accno, $form->{fx}{$accno}{$transdate}, conv_date($transdate), $accno, conv_date($taxdate), $accno, conv_date($taxdate), conv_i($project_id), $accno);
        do_query($form, $dbh, $query, @values);
      }
    }
  }

  if ($payments_only) {
    $query = qq|UPDATE ar SET paid = ? WHERE id = ?|;
    do_query($form, $dbh, $query,  $form->{paid}, conv_i($form->{id}));

    $form->new_lastmtime('ar');

    return;
  }

  $amount = $form->round_amount( $netamount + $tax, 2, 1);

  # qr reference
  my $qr_reference;
  if ($form->{has_qr_reference}) {
    # (re-)generate reference number

    # get qr-account data
    my ($qr_account, $error) = get_qrbill_account();
    die $error if !$qr_account;

    # get customer object
    my $customer_obj = SL::DB::Customer->load_cached(conv_i($form->{customer_id}));

    # assemble reference number with check digit
    ($qr_reference, $error) = assemble_ref_number($qr_account->{bank_account_id},
                                                  $customer_obj->{customernumber},
                                                  $form->{invnumber});
    die $error if !$qr_reference;
  } else {
    # if the reference number has been previously defined keep it
    if (defined $form->{qr_reference}) {
      $qr_reference = $form->{qr_reference};
    } else {
      $qr_reference = undef;
    }
  }

  # add invoice number to unstructured message if feature enabled in client config
  my $qr_unstructured_message = $form->{"qr_unstructured_message"};
  if ($::instance_conf->get_qrbill_copy_invnumber && $form->{formname} eq 'invoice') {
    my $invnumber = $form->{"invnumber"};
    if ($qr_unstructured_message eq '') {
      $qr_unstructured_message = $invnumber;
    } elsif (rindex($qr_unstructured_message, $invnumber) == -1) {
      $qr_unstructured_message .= '; ' . $invnumber;
    }
  }

  # save AR record
  #erweiterung fuer lieferscheinnummer (donumber) 12.02.09 jb

  $query = qq|UPDATE ar set
                invnumber   = ?, ordnumber     = ?, quonumber     = ?, cusordnumber  = ?,
                transdate   = ?, orddate       = ?, quodate       = ?, tax_point     = ?, customer_id   = ?,
                amount      = ?, netamount     = ?, paid          = ?,
                duedate     = ?, deliverydate  = ?, invoice       = ?, shippingpoint = ?,
                shipvia     = ?,                    notes         = ?, intnotes      = ?,
                currency_id = (SELECT id FROM currencies WHERE name = ?),
                department_id = ?, payment_id    = ?, taxincluded   = ?,
                type        = ?, language_id   = ?, taxzone_id    = ?, shipto_id     = ?, billing_address_id = ?,
                employee_id = ?, salesman_id   = ?, storno_id     = ?, storno        = ?,
                cp_id       = ?, marge_total   = ?, marge_percent = ?,
                globalproject_id               = ?, delivery_customer_id             = ?,
                transaction_description        = ?, delivery_vendor_id               = ?,
                donumber    = ?, invnumber_for_credit_note = ?,        direct_debit  = ?, qrbill_without_amount = ?,
                qr_reference = ?, qr_unstructured_message = ?, delivery_term_id = ?
              WHERE id = ?|;
  @values = (          $form->{"invnumber"},           $form->{"ordnumber"},             $form->{"quonumber"},          $form->{"cusordnumber"},
             conv_date($form->{"invdate"}),  conv_date($form->{"orddate"}),    conv_date($form->{"quodate"}), conv_date($form->{tax_point}), conv_i($form->{"customer_id"}),
                       $amount,                        $netamount,                       $form->{"paid"},
             conv_date($form->{"duedate"}),  conv_date($form->{"deliverydate"}),    '1',                                $form->{"shippingpoint"},
                       $form->{"shipvia"},                                $restricter->process($form->{"notes"}),       $form->{"intnotes"},
                       $form->{"currency"},     conv_i($form->{"department_id"}), conv_i($form->{"payment_id"}),        $form->{"taxincluded"} ? 't' : 'f',
                       $form->{"type"},         conv_i($form->{"language_id"}),   conv_i($form->{"taxzone_id"}), conv_i($form->{"shipto_id"}), conv_i($form->{billing_address_id}),
                conv_i($form->{"employee_id"}), conv_i($form->{"salesman_id"}),   conv_i($form->{storno_id}),           $form->{"storno"} ? 't' : 'f',
                conv_i($form->{"cp_id"}),            1 * $form->{marge_total} ,      1 * $form->{marge_percent},
                conv_i($form->{"globalproject_id"}),                              conv_i($form->{"delivery_customer_id"}),
                       $form->{transaction_description},                          conv_i($form->{"delivery_vendor_id"}),
                       $form->{"donumber"}, $form->{"invnumber_for_credit_note"},        $form->{direct_debit} ? 't' : 'f', $form->{qrbill_without_amount} ? 't' : 'f',
                $qr_reference, $qr_unstructured_message, conv_i($form->{delivery_term_id}),
                conv_i($form->{"id"}));
  do_query($form, $dbh, $query, @values);


  if ($form->{storno}) {
    $query =
      qq!UPDATE ar SET
           paid = amount,
           storno = 't',
           intnotes = ? || intnotes
         WHERE id = ?!;
    do_query($form, $dbh, $query, "Rechnung storniert am $form->{invdate} ", conv_i($form->{"storno_id"}));
    do_query($form, $dbh, qq|UPDATE ar SET paid = amount WHERE id = ?|, conv_i($form->{"id"}));

    $query = <<SQL;
      UPDATE orderitems
      SET recurring_billing_invoice_id = NULL
      WHERE recurring_billing_invoice_id = ?
SQL

    do_query($form, $dbh, $query, conv_i($form->{"storno_id"}));
  }

  # maybe we are in a larger transaction and the current
  # object is not yet persistent in the db, therefore we
  # need the current dbh to get the not yet committed mtime
  $form->new_lastmtime('ar', $provided_dbh);

  # add shipto
  if (!$form->{shipto_id}) {
    $form->add_shipto($dbh, $form->{id}, "AR");
  }

  # save printed, emailed and queued
  $form->save_status($dbh);

  Common::webdav_folder($form);

  # Link this record to the records it was created from.
  foreach (qw(oe ar reclamations)) {
    if ($form->{"convert_from_${_}_ids"}) {
      RecordLinks->create_links('dbh'        => $dbh,
                                'mode'       => 'ids',
                                'from_table' => $_,
                                'from_ids'   => $form->{"convert_from_${_}_ids"},
                                'to_table'   => 'ar',
                                'to_id'      => $form->{id},
      );
      delete $form->{"convert_from_${_}_ids"};
    }
  }

  my @convert_from_do_ids = map { $_ * 1 } grep { $_ } split m/\s+/, $form->{convert_from_do_ids};

  if (scalar @convert_from_do_ids) {
    DO->close_orders('dbh' => $dbh,
                     'ids' => \@convert_from_do_ids);

    RecordLinks->create_links('dbh'        => $dbh,
                              'mode'       => 'ids',
                              'from_table' => 'delivery_orders',
                              'from_ids'   => \@convert_from_do_ids,
                              'to_table'   => 'ar',
                              'to_id'      => $form->{id},
      );
  }
  delete $form->{convert_from_do_ids};

  ARAP->close_orders_if_billed('dbh'     => $dbh,
                               'arap_id' => $form->{id},
                               'table'   => 'ar',);

  # search for orphaned invoice items
  $query  = sprintf 'SELECT id FROM invoice WHERE trans_id = ? AND NOT id IN (%s)', join ', ', ("?") x scalar @processed_invoice_ids;
  @values = (conv_i($form->{id}), map { conv_i($_) } @processed_invoice_ids);
  my @orphaned_ids = map { $_->{id} } selectall_hashref_query($form, $dbh, $query, @values);
  if (scalar @orphaned_ids) {
    # clean up invoice items
    $query  = sprintf 'DELETE FROM invoice WHERE id IN (%s)', join ', ', ("?") x scalar @orphaned_ids;
    do_query($form, $dbh, $query, @orphaned_ids);
  }

  if ($form->{draft_id}) {
    SL::DB::Manager::Draft->delete_all(where => [ id => delete($form->{draft_id}) ]);
  }

  # safety check datev export
  if ($::instance_conf->get_datev_check_on_sales_invoice) {

    my $datev = SL::DATEV->new(
      dbh        => $dbh,
      trans_id   => $form->{id},
    );

    $datev->generate_datev_data;

    if ($datev->errors) {
      die join "\n", $::locale->text('DATEV check returned errors:'), $datev->errors;
    }
  }

  # update shop status
  my $invoice = SL::DB::Invoice->new( id => $form->{id} )->load;
  my @linked_shop_orders = $invoice->linked_records(
    from      => 'ShopOrder',
    via       => ['DeliveryOrder','Order',],
  );
    #do update
    my $shop_order = $linked_shop_orders[0][0];
  if ( $shop_order ) {
    require SL::Shop;
    my $shop_config = SL::DB::Manager::Shop->get_first( query => [ id => $shop_order->shop_id ] );
    my $shop = SL::Shop->new( config => $shop_config );
    $shop->connector->set_orderstatus($shop_order->shop_trans_id, "completed");
  }

  $validity_token->delete if $validity_token;
  delete $form->{form_validity_token};

  return 1;
}

sub _get_invoices_for_advance_payment {
  my ($self, $id, $id_is_from_order) = @_;

  return [] if !$id;

  # Search all related invoices for advance payment.
  # Case 1:
  # (order) -> invoice for adv. payment 1 -> invoice for adv. payment 2 -> invoice for adv. payment 3 -> final invoice
  #
  # Case 2:
  # order -> invoice for adv. payment 1
  #   | |`-> invoice for adv. payment 2
  #   | `--> invoice for adv. payment 3
  #   `----> final invoice
  #
  # The id is currently that from the last invoice for adv. payment (3 in this example),
  # that from the final invoice or that from the order.

  my $invoice_obj;
  my $order_obj;
  my $links;

  if (!$id_is_from_order) {
    $invoice_obj = SL::DB::Invoice->load_cached($id*1);
    $links       = $invoice_obj->linked_records(direction => 'from', from => ['Order']);
    $order_obj   = $links->[0];
  } else {
    $order_obj   = SL::DB::Order->load_cached($id*1);
  }

  if ($order_obj) {
    $links        = $order_obj  ->linked_records(direction => 'to',   to => ['Invoice']);
  } else {
    $links        = $invoice_obj->linked_records(direction => 'from', from => ['Invoice'], recursive => 1);
  }

  my @related_invoices = grep {'SL::DB::Invoice' eq ref $_ && "invoice_for_advance_payment" eq $_->type} @$links;

  push @related_invoices, $invoice_obj if !$order_obj && "invoice_for_advance_payment" eq $invoice_obj->type;

  return \@related_invoices;
}


sub transfer_out {
  $::lxdebug->enter_sub;

  my ($self, $form, $dbh) = @_;

  my (@errors, @transfers);

  # do nothing, if transfer default is not requested at all
  if (!$::instance_conf->get_transfer_default) {
    $::lxdebug->leave_sub;
    return \@errors;
  }

  require SL::WH;

  foreach my $i (1 .. $form->{rowcount}) {
    next if !$form->{"id_$i"};

    my ($err, $qty, $wh_id, $bin_id, $chargenumber);

    if ($::instance_conf->get_sales_serial_eq_charge && $form->{"serialnumber_$i"}) {
      my @serials = split(" ", trim($form->{"serialnumber_$i"}));
      if (scalar @serials != $form->{"qty_$i"}) {
        push @errors, $::locale->text("Cannot transfer #1 qty with #2 serial number(s)", $form->{"qty_$i"}, scalar @serials);
        last;
      }
      foreach my $serial (@serials) {
        ($qty, $wh_id, $bin_id, $chargenumber) = WH->get_wh_and_bin_for_charge(chargenumber => $serial);
        if (!$qty) {
          push @errors, $::locale->text("Not enough in stock for the serial number #1", $serial);
          last;
        }
        push @transfers, {
            'parts_id'         => $form->{"id_$i"},
            'qty'              => 1,
            'unit'             => $form->{"unit_$i"},
            'transfer_type'    => 'shipped',
            'src_warehouse_id' => $wh_id,
            'src_bin_id'       => $bin_id,
            'chargenumber'     => $chargenumber,
            'project_id'       => $form->{"project_id_$i"},
            'invoice_id'       => $form->{"invoice_id_$i"},
            'comment'          => $::locale->text("Default transfer invoice with charge number"),
        };
      }
      $err = []; # error handling uses @errors direct
    } else {
      ($err, $wh_id, $bin_id)    = _determine_wh_and_bin($dbh, $::instance_conf,
                                                         $form->{"id_$i"},
                                                         $form->{"qty_$i"},
                                                         $form->{"unit_$i"});
      if (!@{ $err } && $wh_id && $bin_id) {
        push @transfers, {
          'parts_id'         => $form->{"id_$i"},
          'qty'              => $form->{"qty_$i"},
          'unit'             => $form->{"unit_$i"},
          'transfer_type'    => 'shipped',
          'src_warehouse_id' => $wh_id,
          'src_bin_id'       => $bin_id,
          'project_id'       => $form->{"project_id_$i"},
          'invoice_id'       => $form->{"invoice_id_$i"},
          'comment'          => $::locale->text("Default transfer invoice"),
        };
      }
    }
    push @errors, @{ $err };
  } # end form rowcount

  if (!@errors) {
    WH->transfer(@transfers);
  }

  $::lxdebug->leave_sub;
  return \@errors;
}

sub _determine_wh_and_bin {
  $::lxdebug->enter_sub(2);

  my ($dbh, $conf, $part_id, $qty, $unit) = @_;
  my @errors;

  my $part = SL::DB::Part->new(id => $part_id)->load;

  # ignore service if they are not configured to be transfered
  if ($part->is_service && !$conf->get_transfer_default_services) {
    $::lxdebug->leave_sub(2);
    return (\@errors);
  }

  # test negative qty
  if ($qty < 0) {
    push @errors, $::locale->text("Cannot transfer negative quantities.");
    return (\@errors);
  }

  # get/test default bin
  my ($default_wh_id, $default_bin_id);
  if ($conf->get_transfer_default_use_master_default_bin) {
    $default_wh_id  = $conf->get_warehouse_id if $conf->get_warehouse_id;
    $default_bin_id = $conf->get_bin_id       if $conf->get_bin_id;
  }
  my $wh_id  = $part->warehouse_id || $default_wh_id;
  my $bin_id = $part->bin_id       || $default_bin_id;

  # check qty and bin
  if ($bin_id) {
    my ($max_qty, $error) = WH->get_max_qty_parts_bin(dbh      => $dbh,
                                                      parts_id => $part->id,
                                                      bin_id   => $bin_id);
    if ($error == 1) {
      push @errors, $::locale->text('Part "#1" has chargenumber or best before date set. So it cannot be transfered automatically.',
                                    $part->description);
    }
    my $form_unit_obj = SL::DB::Unit->new(name => $unit)->load;
    my $part_unit_qty = $form_unit_obj->convert_to($qty, $part->unit_obj);
    my $diff_qty      = $max_qty - $part_unit_qty;
    if (!@errors && $diff_qty < 0) {
      push @errors, $::locale->text('For part "#1" there are missing #2 #3 in the default warehouse/bin "#4/#5".',
                                    $part->description,
                                    $::form->format_amount(\%::myconfig, -1*$diff_qty),
                                    $part->unit_obj->name,
                                    SL::DB::Warehouse->new(id => $wh_id)->load->description,
                                    SL::DB::Bin->new(      id => $bin_id)->load->description);
    }
  } else {
    push @errors, $::locale->text('For part "#1" there is no default warehouse and bin defined.',
                                  $part->description);
  }

  # transfer to special "ignore onhand" bin if requested and default bin does not work
  if (@errors && $conf->get_transfer_default_ignore_onhand && $conf->get_bin_id_ignore_onhand) {
    $wh_id  = $conf->get_warehouse_id_ignore_onhand;
    $bin_id = $conf->get_bin_id_ignore_onhand;
    if ($wh_id && $bin_id) {
      @errors = ();
    } else {
      push @errors, $::locale->text('For part "#1" there is no default warehouse and bin for ignoring onhand defined.',
                                    $part->description);
    }
  }

  $::lxdebug->leave_sub(2);
  return (\@errors, $wh_id, $bin_id);
}

sub _delete_transfers {
  $::lxdebug->enter_sub;

  my ($dbh, $form, $id) = @_;

  my $query = qq|DELETE FROM inventory WHERE invoice_id
                  IN (SELECT id FROM invoice WHERE trans_id = ?)|;

  do_query($form, $dbh, $query, $id);

  $::lxdebug->leave_sub;
}

sub _delete_payments {
  $main::lxdebug->enter_sub();

  my ($self, $form, $dbh) = @_;

  my @delete_acc_trans_ids;

  # Delete old payment entries from acc_trans.
  my $query =
    qq|SELECT acc_trans_id
       FROM acc_trans
       WHERE (trans_id = ?) AND fx_transaction

       UNION

       SELECT at.acc_trans_id
       FROM acc_trans at
       LEFT JOIN chart c ON (at.chart_id = c.id)
       WHERE (trans_id = ?) AND (c.link LIKE '%AR_paid%')|;
  push @delete_acc_trans_ids, selectall_array_query($form, $dbh, $query, conv_i($form->{id}), conv_i($form->{id}));

  $query =
    qq|SELECT at.acc_trans_id
       FROM acc_trans at
       LEFT JOIN chart c ON (at.chart_id = c.id)
       WHERE (trans_id = ?)
         AND ((c.link = 'AR') OR (c.link LIKE '%:AR') OR (c.link LIKE 'AR:%'))
       ORDER BY at.acc_trans_id
       OFFSET 1|;
  push @delete_acc_trans_ids, selectall_array_query($form, $dbh, $query, conv_i($form->{id}));

  if (@delete_acc_trans_ids) {
    $query = qq|DELETE FROM acc_trans WHERE acc_trans_id IN (| . join(", ", @delete_acc_trans_ids) . qq|)|;
    do_query($form, $dbh, $query);
  }

  $main::lxdebug->leave_sub();
}

sub post_payment {
  my ($self, $myconfig, $form, $locale) = @_;
  $main::lxdebug->enter_sub();

  my $rc = SL::DB->client->with_transaction(\&_post_payment, $self, $myconfig, $form, $locale);

  $::lxdebug->leave_sub;
  return $rc;
}

sub _post_payment {
  my ($self, $myconfig, $form, $locale) = @_;

  my $dbh = SL::DB->client->dbh;

  my (%payments, $old_form, $row, $item, $query, %keep_vars);

  $old_form = save_form();

  $query = <<SQL;
    SELECT at.acc_trans_id, at.amount, at.cleared, c.accno
    FROM acc_trans at
    LEFT JOIN chart c ON (at.chart_id = c.id)
    WHERE (at.trans_id = ?)
SQL

  my %already_cleared = selectall_as_map($form, $dbh, $query, 'acc_trans_id', [ qw(amount cleared accno) ], $form->{id});

  # Delete all entries in acc_trans from prior payments.
  if (SL::DB::Default->get->payments_changeable != 0) {
    $self->_delete_payments($form, $dbh);
  }

  # Save the new payments the user made before cleaning up $form.
  map { $payments{$_} = $form->{$_} } grep m/^datepaid_\d+$|^gldate_\d+$|^acc_trans_id_\d+$|^memo_\d+$|^source_\d+$|^exchangerate_\d+$|^paid_\d+$|^AR_paid_\d+$|^paidaccounts$/, keys %{ $form };

  # Clean up $form so that old content won't tamper the results.
  %keep_vars = map { $_, 1 } qw(login password id);
  map { delete $form->{$_} unless $keep_vars{$_} } keys %{ $form };

  # Retrieve the invoice from the database.
  $self->retrieve_invoice($myconfig, $form);

  # Set up the content of $form in the way that IS::post_invoice() expects.
  $form->{exchangerate} = $form->format_amount($myconfig, $form->{exchangerate});

  for $row (1 .. scalar @{ $form->{invoice_details} }) {
    $item = $form->{invoice_details}->[$row - 1];

    map { $item->{$_} = $form->format_amount($myconfig, $item->{$_}) } qw(qty sellprice discount);

    map { $form->{"${_}_${row}"} = $item->{$_} } keys %{ $item };
  }

  $form->{rowcount} = scalar @{ $form->{invoice_details} };

  delete @{$form}{qw(invoice_details paidaccounts storno paid)};

  # Restore the payment options from the user input.
  map { $form->{$_} = $payments{$_} } keys %payments;

  # Get the AR accno (which is normally done by Form::create_links()).
  $query =
    qq|SELECT c.accno
       FROM acc_trans at
       LEFT JOIN chart c ON (at.chart_id = c.id)
       WHERE (trans_id = ?)
         AND ((c.link = 'AR') OR (c.link LIKE '%:AR') OR (c.link LIKE 'AR:%'))
       ORDER BY at.acc_trans_id
       LIMIT 1|;

  ($form->{AR}) = selectfirst_array_query($form, $dbh, $query, conv_i($form->{id}));

  # Post the new payments.
  $self->post_invoice($myconfig, $form, $dbh, payments_only => 1, already_cleared => \%already_cleared);

  restore_form($old_form);

  return 1;
}

sub process_assembly {
  $main::lxdebug->enter_sub();

  my ($dbh, $myconfig, $form, $position, $id, $totalqty) = @_;

  my $query =
    qq|SELECT a.parts_id, a.qty, p.part_type, p.partnumber, p.description, p.unit
       FROM assembly a
       JOIN parts p ON (a.parts_id = p.id)
       WHERE (a.id = ?)|;
  my $sth = prepare_execute_query($form, $dbh, $query, conv_i($id));

  while (my $ref = $sth->fetchrow_hashref('NAME_lc')) {

    my $allocated = 0;

    $ref->{inventory_accno_id} *= 1;
    $ref->{expense_accno_id}   *= 1;

    # multiply by number of assemblies
    $ref->{qty} *= $totalqty;

    if ($ref->{assembly}) {
      &process_assembly($dbh, $myconfig, $form, $position, $ref->{parts_id}, $ref->{qty});
      next;
    } else {
      if ($ref->{inventory_accno_id}) {
        $allocated = &cogs($dbh, $myconfig, $form, $ref->{parts_id}, $ref->{qty});
      }
    }

    # save detail record for individual assembly item in invoice table
    $query =
      qq|INSERT INTO invoice (trans_id, position, description, parts_id, qty, sellprice, fxsellprice, allocated, assemblyitem, unit)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)|;
    my @values = (conv_i($form->{id}), conv_i($position), $ref->{description},
                  conv_i($ref->{parts_id}), $ref->{qty}, 0, 0, $allocated, 't', $ref->{unit});
    do_query($form, $dbh, $query, @values);

  }

  $sth->finish;

  $main::lxdebug->leave_sub();
}

sub cogs {
  $main::lxdebug->enter_sub();

  # adjust allocated in table invoice according to FIFO princicple
  # for a certain part with part_id $id

  my ($dbh, $myconfig, $form, $id, $totalqty, $basefactor, $row) = @_;

  $basefactor ||= 1;

  $form->{taxzone_id} *=1;
  my $transdate  = $form->{invdate} ? $dbh->quote($form->{invdate}) : "current_date";
  my $taxzone_id = $form->{"taxzone_id"} * 1;
  my $query =
    qq|SELECT i.id, i.trans_id, i.base_qty, i.allocated, i.sellprice, i.price_factor,
         c1.accno AS inventory_accno, c1.new_chart_id AS inventory_new_chart, date($transdate) - c1.valid_from AS inventory_valid,
         c2.accno AS    income_accno, c2.new_chart_id AS    income_new_chart, date($transdate) - c2.valid_from AS    income_valid,
         c3.accno AS   expense_accno, c3.new_chart_id AS   expense_new_chart, date($transdate) - c3.valid_from AS   expense_valid
       FROM invoice i, parts p
       LEFT JOIN chart c1 ON ((SELECT inventory_accno_id FROM buchungsgruppen WHERE id = p.buchungsgruppen_id) = c1.id)
       LEFT JOIN chart c2 ON ((SELECT tc.income_accno_id FROM taxzone_charts tc WHERE tc.taxzone_id = '$taxzone_id' and tc.buchungsgruppen_id = p.buchungsgruppen_id) = c2.id)
       LEFT JOIN chart c3 ON ((SELECT tc.expense_accno_id FROM taxzone_charts tc WHERE tc.taxzone_id = '$taxzone_id' and tc.buchungsgruppen_id = p.buchungsgruppen_id) = c3.id)
       WHERE (i.parts_id = p.id)
         AND (i.parts_id = ?)
         AND ((i.base_qty + i.allocated) < 0)
       ORDER BY trans_id|;
  my $sth = prepare_execute_query($form, $dbh, $query, conv_i($id));

  my $allocated = 0;
  my $qty;

# all invoice entries of an example part:

# id | trans_id | base_qty | allocated | sellprice | inventory_accno | income_accno | expense_accno
# ---+----------+----------+-----------+-----------+-----------------+--------------+---------------
#  4 |        4 |       -5 |         5 |  20.00000 | 1140            | 4400         | 5400     bought 5 for 20
#  5 |        5 |        4 |        -4 |  50.00000 | 1140            | 4400         | 5400     sold   4 for 50
#  6 |        6 |        1 |        -1 |  50.00000 | 1140            | 4400         | 5400     sold   1 for 50
#  7 |        7 |       -5 |         1 |  20.00000 | 1140            | 4400         | 5400     bought 5 for 20
#  8 |        8 |        1 |        -1 |  50.00000 | 1140            | 4400         | 5400     sold   1 for 50

# AND ((i.base_qty + i.allocated) < 0) filters out all but line with id=7, elsewhere i.base_qty + i.allocated has already reached 0
# and all parts have been allocated

# so transaction 8 only sees transaction 7 with unallocated parts and adjusts allocated for that transaction, before allocated was 0
#  7 |        7 |       -5 |         1 |  20.00000 | 1140            | 4400         | 5400     bought 5 for 20

# in this example there are still 4 unsold articles


  # search all invoice entries for the part in question, adjusting "allocated"
  # until the total number of sold parts has been reached

  # ORDER BY trans_id ensures FIFO


  while (my $ref = $sth->fetchrow_hashref('NAME_lc')) {
    if (($qty = (($ref->{base_qty} * -1) - $ref->{allocated})) > $totalqty) {
      $qty = $totalqty;
    }

    # update allocated in invoice
    $form->update_balance($dbh, "invoice", "allocated", qq|id = $ref->{id}|, $qty);

    # total expenses and inventory
    # sellprice is the cost of the item
    my $linetotal = $form->round_amount(($ref->{sellprice} * $qty) / ( ($ref->{price_factor} || 1) * ( $basefactor || 1 )), 2);

    if ( $::instance_conf->get_inventory_system eq 'perpetual' ) {
      # Bestandsmethode: when selling parts, deduct their purchase value from the inventory account
      $ref->{expense_accno} = ($form->{"expense_accno_$row"}) ? $form->{"expense_accno_$row"} : $ref->{expense_accno};
      # add to expense
      $form->{amount_cogs}{ $form->{id} }{ $ref->{expense_accno} } += -$linetotal;
      $form->{expense_inventory} .= " " . $ref->{expense_accno};
      $ref->{inventory_accno} = ($form->{"inventory_accno_$row"}) ? $form->{"inventory_accno_$row"} : $ref->{inventory_accno};
      # deduct inventory
      $form->{amount_cogs}{ $form->{id} }{ $ref->{inventory_accno} } -= -$linetotal;
      $form->{expense_inventory} .= " " . $ref->{inventory_accno};
    }

    # add allocated
    $allocated -= $qty;

    last if (($totalqty -= $qty) <= 0);
  }

  $sth->finish;

  $main::lxdebug->leave_sub();

  return $allocated;
}

sub reverse_invoice {
  $main::lxdebug->enter_sub();

  my ($dbh, $form) = @_;

  # reverse inventory items
  my $query =
    qq|SELECT i.id, i.parts_id, i.qty, i.assemblyitem, p.part_type
       FROM invoice i
       JOIN parts p ON (i.parts_id = p.id)
       WHERE i.trans_id = ?|;
  my $sth = prepare_execute_query($form, $dbh, $query, conv_i($form->{"id"}));

  while (my $ref = $sth->fetchrow_hashref('NAME_lc')) {

    if ($ref->{inventory_accno_id}) {
      # de-allocated purchases
      $query =
        qq|SELECT i.id, i.trans_id, i.allocated
           FROM invoice i
           WHERE (i.parts_id = ?) AND (i.allocated > 0)
           ORDER BY i.trans_id DESC|;
      my $sth2 = prepare_execute_query($form, $dbh, $query, conv_i($ref->{"parts_id"}));

      while (my $inhref = $sth2->fetchrow_hashref('NAME_lc')) {
        my $qty = $ref->{qty};
        if (($ref->{qty} - $inhref->{allocated}) > 0) {
          $qty = $inhref->{allocated};
        }

        # update invoice
        $form->update_balance($dbh, "invoice", "allocated", qq|id = $inhref->{id}|, $qty * -1);

        last if (($ref->{qty} -= $qty) <= 0);
      }
      $sth2->finish;
    }
  }

  $sth->finish;

  # delete acc_trans
  my @values = (conv_i($form->{id}));
  do_query($form, $dbh, qq|DELETE FROM acc_trans WHERE trans_id = ?|, @values);

  $query = qq|DELETE FROM custom_variables
              WHERE (config_id IN (SELECT id        FROM custom_variable_configs WHERE (module = 'ShipTo')))
                AND (trans_id  IN (SELECT shipto_id FROM shipto                  WHERE (module = 'AR') AND (trans_id = ?)))|;
  do_query($form, $dbh, $query, @values);
  do_query($form, $dbh, qq|DELETE FROM shipto WHERE (trans_id = ?) AND (module = 'AR')|, @values);

  $main::lxdebug->leave_sub();
}

sub delete_invoice {
  my ($self, $myconfig, $form) = @_;
  $main::lxdebug->enter_sub();

  my $rc = SL::DB->client->with_transaction(\&_delete_invoice, $self, $myconfig, $form);

  $::lxdebug->leave_sub;
  return $rc;
}

sub _delete_invoice {
  my ($self, $myconfig, $form) = @_;

  my $dbh = SL::DB->client->dbh;

  &reverse_invoice($dbh, $form);
  _delete_transfers($dbh, $form, $form->{id});

  my @values = (conv_i($form->{id}));

  # Falls wir ein Storno haben, müssen zwei Felder in der stornierten Rechnung wieder
  # zurückgesetzt werden. Vgl:
  #  id | storno | storno_id |  paid   |  amount
  #----+--------+-----------+---------+-----------
  # 18 | f      |           | 0.00000 | 119.00000
  # ZU:
  # 18 | t      |           |  119.00000 |  119.00000
  #
  if($form->{storno}){
    # storno_id auslesen und korrigieren
    my ($invoice_id) = selectfirst_array_query($form, $dbh, qq|SELECT storno_id FROM ar WHERE id = ?|,@values);
    do_query($form, $dbh, qq|UPDATE ar SET storno = 'f', paid = 0 WHERE id = ?|, $invoice_id);
  }

  # if we delete a final invoice, the reverse bookings for the clearing account in the invoice for advance payment
  # must be deleted as well
  my $invoices_for_advance_payment = $self->_get_invoices_for_advance_payment($form->{id});

  # Todo: allow only if invoice for advance payment is not paid.
  # die if any { $_->paid } for @$invoices_for_advance_payment;
  my @trans_ids_to_consider        = map { $_->id } @$invoices_for_advance_payment;
  if (scalar @trans_ids_to_consider) {
    my $query = sprintf 'DELETE FROM acc_trans WHERE memo LIKE ? AND trans_id IN (%s)', join ', ', ("?") x scalar @trans_ids_to_consider;
    do_query($form, $dbh, $query, 'reverse booking by final invoice', @trans_ids_to_consider);
  }

  # delete spool files
  my @spoolfiles = selectall_array_query($form, $dbh, qq|SELECT spoolfile FROM status WHERE trans_id = ?|, @values);

  my @queries = (
    qq|DELETE FROM status WHERE trans_id = ?|,
    qq|DELETE FROM periodic_invoices WHERE ar_id = ?|,
    qq|DELETE FROM invoice WHERE trans_id = ?|,
    qq|DELETE FROM ar WHERE id = ?|,
  );

  map { do_query($form, $dbh, $_, @values) } @queries;

  my $spool = $::lx_office_conf{paths}->{spool};
  map { unlink "$spool/$_" if -f "$spool/$_"; } @spoolfiles;

  return 1;
}

sub retrieve_invoice {
  my ($self, $myconfig, $form) = @_;
  $main::lxdebug->enter_sub();

  my $rc = SL::DB->client->with_transaction(\&_retrieve_invoice, $self, $myconfig, $form);

  $::lxdebug->leave_sub;
  return $rc;
}

sub _retrieve_invoice {
  my ($self, $myconfig, $form) = @_;

  my $dbh = SL::DB->client->dbh;

  my ($sth, $ref, $query);

  my $query_transdate = !$form->{id} ? ", current_date AS invdate" : '';

  $query =
    qq|SELECT
         (SELECT c.accno FROM chart c WHERE d.inventory_accno_id = c.id) AS inventory_accno,
         (SELECT c.accno FROM chart c WHERE d.income_accno_id = c.id)    AS income_accno,
         (SELECT c.accno FROM chart c WHERE d.expense_accno_id = c.id)   AS expense_accno,
         (SELECT c.accno FROM chart c WHERE d.fxgain_accno_id = c.id)    AS fxgain_accno,
         (SELECT c.accno FROM chart c WHERE d.fxloss_accno_id = c.id)    AS fxloss_accno,
         (SELECT c.accno FROM chart c WHERE d.rndgain_accno_id = c.id)   AS rndgain_accno,
         (SELECT c.accno FROM chart c WHERE d.rndloss_accno_id = c.id)   AS rndloss_accno
         ${query_transdate}
       FROM defaults d|;

  $ref = selectfirst_hashref_query($form, $dbh, $query);
  map { $form->{$_} = $ref->{$_} } keys %{ $ref };

  if ($form->{id}) {
    my $id = conv_i($form->{id});

    # retrieve invoice
    #erweiterung um das entsprechende feld lieferscheinnummer (a.donumber) in der html-maske anzuzeigen 12.02.2009 jb

    $query =
      qq|SELECT
           a.invnumber, a.ordnumber, a.quonumber, a.cusordnumber,
           a.orddate, a.quodate, a.globalproject_id,
           a.transdate AS invdate, a.deliverydate, a.tax_point, a.paid, a.storno, a.storno_id, a.gldate,
           a.shippingpoint, a.shipvia, a.notes, a.intnotes, a.taxzone_id,
           a.duedate, a.taxincluded, (SELECT cu.name FROM currencies cu WHERE cu.id=a.currency_id) AS currency, a.shipto_id, a.cp_id,
           a.billing_address_id,
           a.employee_id, a.salesman_id, a.payment_id,
           a.mtime, a.itime,
           a.language_id, a.delivery_customer_id, a.delivery_vendor_id, a.type,
           a.transaction_description, a.donumber, a.invnumber_for_credit_note,
           a.marge_total, a.marge_percent, a.direct_debit, a.qrbill_without_amount, a.qr_reference, a.qr_unstructured_message, a.delivery_term_id,
           dc.dunning_description,
           e.name AS employee
         FROM ar a
         LEFT JOIN employee e ON (e.id = a.employee_id)
         LEFT JOIN dunning_config dc ON (a.dunning_config_id = dc.id)
         WHERE a.id = ?|;
    $ref = selectfirst_hashref_query($form, $dbh, $query, $id);
    map { $form->{$_} = $ref->{$_} } keys %{ $ref };
    $form->{mtime} = $form->{itime} if !$form->{mtime};
    $form->{lastmtime} = $form->{mtime};

    ($form->{exchangerate}, $form->{record_forex}) = $form->check_exchangerate($myconfig, $form->{currency}, $form->{invdate}, "buy", $id, 'ar');

    foreach my $vc (qw(customer vendor)) {
      next if !$form->{"delivery_${vc}_id"};
      ($form->{"delivery_${vc}_string"}) = selectrow_query($form, $dbh, qq|SELECT name FROM customer WHERE id = ?|,
                                                           $form->{"delivery_${vc}_id"});
    }

    # get shipto
    $query = qq|SELECT * FROM shipto WHERE (trans_id = ?) AND (module = 'AR')|;
    $ref = selectfirst_hashref_query($form, $dbh, $query, $id);
    $form->{$_} = $ref->{$_} for grep { m{^shipto(?!_id$)} } keys %$ref;

    # get printed, emailed
    $query = qq|SELECT printed, emailed, spoolfile, formname FROM status WHERE trans_id = ?|;
    $sth = prepare_execute_query($form, $dbh, $query, $id);

    while ($ref = $sth->fetchrow_hashref('NAME_lc')) {
      $form->{printed} .= "$ref->{formname} " if $ref->{printed};
      $form->{emailed} .= "$ref->{formname} " if $ref->{emailed};
      $form->{queued} .= "$ref->{formname} $ref->{spoolfile} " if $ref->{spoolfile};
    }
    $sth->finish;
    map { $form->{$_} =~ s/ +$//g } qw(printed emailed queued);

    my $transdate = $form->{tax_point}    ? $dbh->quote($form->{tax_point})
                  : $form->{deliverydate} ? $dbh->quote($form->{deliverydate})
                  : $form->{invdate}      ? $dbh->quote($form->{invdate})
                  :                         "current_date";


    my $taxzone_id = $form->{taxzone_id} *= 1;
    $taxzone_id = SL::DB::Manager::TaxZone->get_default->id unless SL::DB::Manager::TaxZone->find_by(id => $taxzone_id);

    # retrieve individual items
    $query =
      qq|SELECT
           c1.accno AS inventory_accno, c1.new_chart_id AS inventory_new_chart, date($transdate) - c1.valid_from AS inventory_valid,
           c2.accno AS income_accno,    c2.new_chart_id AS income_new_chart,    date($transdate) - c2.valid_from as income_valid,
           c3.accno AS expense_accno,   c3.new_chart_id AS expense_new_chart,   date($transdate) - c3.valid_from AS expense_valid,

           i.id AS invoice_id,
           i.description, i.longdescription, i.qty, i.fxsellprice AS sellprice, i.discount, i.parts_id AS id, i.unit, i.deliverydate AS reqdate,
           i.project_id, i.serialnumber, i.pricegroup_id, i.ordnumber, i.donumber, i.transdate, i.cusordnumber, i.subtotal, i.lastcost,
           i.price_factor_id, i.price_factor, i.marge_price_factor, i.active_price_source, i.active_discount_source,
           p.partnumber, p.part_type, p.notes AS partnotes, p.formel, p.listprice,
           p.classification_id,
           pr.projectnumber, pg.partsgroup, prg.pricegroup

         FROM invoice i
         LEFT JOIN parts p ON (i.parts_id = p.id)
         LEFT JOIN project pr ON (i.project_id = pr.id)
         LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
         LEFT JOIN pricegroup prg ON (i.pricegroup_id = prg.id)

         LEFT JOIN chart c1 ON ((SELECT inventory_accno_id             FROM buchungsgruppen WHERE id = p.buchungsgruppen_id) = c1.id)
         LEFT JOIN chart c2 ON ((SELECT tc.income_accno_id FROM taxzone_charts tc WHERE tc.taxzone_id = '$taxzone_id' and tc.buchungsgruppen_id = p.buchungsgruppen_id) = c2.id)
         LEFT JOIN chart c3 ON ((SELECT tc.expense_accno_id FROM taxzone_charts tc WHERE tc.taxzone_id = '$taxzone_id' and tc.buchungsgruppen_id = p.buchungsgruppen_id) = c3.id)

         WHERE (i.trans_id = ?) AND NOT (i.assemblyitem = '1') ORDER BY i.position|;

    $sth = prepare_execute_query($form, $dbh, $query, $id);

    while (my $ref = $sth->fetchrow_hashref('NAME_lc')) {
      # Retrieve custom variables.
      my $cvars = CVar->get_custom_variables(dbh        => $dbh,
                                             module     => 'IC',
                                             sub_module => 'invoice',
                                             trans_id   => $ref->{invoice_id},
                                            );
      map { $ref->{"ic_cvar_$_->{name}"} = $_->{value} } @{ $cvars };

      map({ delete($ref->{$_}); } qw(inventory_accno inventory_new_chart inventory_valid)) if !$ref->{"part_inventory_accno_id"};
      delete($ref->{"part_inventory_accno_id"});

      foreach my $type (qw(inventory income expense)) {
        while ($ref->{"${type}_new_chart"} && ($ref->{"${type}_valid"} >=0)) {
          my $query = qq|SELECT accno, new_chart_id, date($transdate) - valid_from FROM chart WHERE id = ?|;
          @$ref{ map $type.$_, qw(_accno _new_chart _valid) } = selectrow_query($form, $dbh, $query, $ref->{"${type}_new_chart"});
        }
      }

      # get tax rates and description
      my $accno_id = ($form->{vc} eq "customer") ? $ref->{income_accno} : $ref->{expense_accno};
      $query =
        qq|SELECT c.accno, t.taxdescription, t.rate, t.id as tax_id, c.accno as taxnumber
           FROM tax t
           LEFT JOIN chart c ON (c.id = t.chart_id)
           WHERE t.id IN
             (SELECT tk.tax_id FROM taxkeys tk
              WHERE tk.chart_id = (SELECT id FROM chart WHERE accno = ?)
                AND startdate <= date($transdate)
              ORDER BY startdate DESC LIMIT 1)
           ORDER BY c.accno|;
      my $stw = prepare_execute_query($form, $dbh, $query, $accno_id);
      $ref->{taxaccounts} = "";
      my $i=0;
      while (my $ptr = $stw->fetchrow_hashref('NAME_lc')) {

        if (($ptr->{accno} eq "") && ($ptr->{rate} == 0)) {
          $i++;
          $ptr->{accno} = $i;
        }
        $ref->{taxaccounts} .= "$ptr->{accno} ";

        if (!($form->{taxaccounts} =~ /\Q$ptr->{accno}\E/)) {
          $form->{"$ptr->{accno}_rate"}        = $ptr->{rate};
          $form->{"$ptr->{accno}_description"} = $ptr->{taxdescription};
          $form->{"$ptr->{accno}_taxnumber"}   = $ptr->{taxnumber}; # don't use this anymore
          $form->{"$ptr->{accno}_tax_id"}      = $ptr->{tax_id};
          $form->{taxaccounts} .= "$ptr->{accno} ";
        }

      }

      $ref->{qty} *= -1 if $form->{type} eq "credit_note";

      chop $ref->{taxaccounts};
      push @{ $form->{invoice_details} }, $ref;
      $stw->finish;
    }
    $sth->finish;

    # Fetch shipping address.
    $query = qq|SELECT s.* FROM shipto s WHERE s.trans_id = ? AND s.module = 'AR'|;
    $ref   = selectfirst_hashref_query($form, $dbh, $query, $form->{id});

    $form->{$_} = $ref->{$_} for grep { $_ ne 'id' } keys %$ref;

    if ($form->{shipto_id}) {
      my $cvars = CVar->get_custom_variables(
        dbh      => $dbh,
        module   => 'ShipTo',
        trans_id => $form->{shipto_id},
      );
      $form->{"shiptocvar_$_->{name}"} = $_->{value} for @{ $cvars };
    }

    Common::webdav_folder($form);
  }

  return 1;
}

sub get_customer {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->get_standard_dbh;

  my $dateformat = $myconfig->{dateformat};
  $dateformat .= "yy" if $myconfig->{dateformat} !~ /^y/;

  my (@values, $ref, $query);

  my $cid = conv_i($form->{customer_id});
  my $payment_id;

  # get customer
  my $where = '';
  if ($cid) {
    $where .= 'AND c.id = ?';
    push @values, $cid;
  }
  $query =
    qq|SELECT
         c.id AS customer_id, c.name AS customer, c.discount as customer_discount, c.creditlimit,
         c.email, c.cc, c.bcc, c.language_id, c.payment_id, c.delivery_term_id,
         c.street, c.zipcode, c.city, c.country,
         c.notes AS intnotes, c.pricegroup_id as customer_pricegroup_id, c.taxzone_id, c.salesman_id, cu.name AS curr,
         c.taxincluded_checked, c.direct_debit,
         (SELECT aba.id
          FROM additional_billing_addresses aba
          WHERE aba.default_address
          LIMIT 1) AS default_billing_address_id,
         b.discount AS tradediscount, b.description AS business
       FROM customer c
       LEFT JOIN business b ON (b.id = c.business_id)
       LEFT JOIN currencies cu ON (c.currency_id=cu.id)
       WHERE 1 = 1 $where|;
  $ref = selectfirst_hashref_query($form, $dbh, $query, @values);
  die t8("Cannot find a single customer. Maybe there is no customer yet?") unless $ref;
  delete $ref->{salesman_id} if !$ref->{salesman_id};
  delete $ref->{payment_id}  if !$ref->{payment_id};

  map { $form->{$_} = $ref->{$_} } keys %$ref;

  if ($form->{payment_id}) {
    my $reference_date = $form->{invdate} ? DateTime->from_kivitendo($form->{invdate}) : undef;
    $form->{duedate}   = SL::DB::PaymentTerm->new(id => $form->{payment_id})->load->calc_date(reference_date => $reference_date)->to_kivitendo;
  } else {
    $form->{duedate}   = DateTime->today_local->to_kivitendo;
  }

  # use customer currency
  $form->{currency} = $form->{curr};

  $query =
    qq|SELECT sum(amount - paid) AS dunning_amount
       FROM ar
       WHERE (paid < amount)
         AND (customer_id = ?)
         AND (dunning_config_id IS NOT NULL)|;
  $ref = selectfirst_hashref_query($form, $dbh, $query, $cid);
  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $query =
    qq|SELECT dnn.dunning_description AS max_dunning_level
       FROM dunning_config dnn
       WHERE id IN (SELECT dunning_config_id
                    FROM ar
                    WHERE (paid < amount) AND (customer_id = ?) AND (dunning_config_id IS NOT NULL))
       ORDER BY dunning_level DESC LIMIT 1|;
  $ref = selectfirst_hashref_query($form, $dbh, $query, $cid);
  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $form->{creditremaining} = $form->{creditlimit};
  $query = qq|SELECT SUM(amount - paid) FROM ar WHERE customer_id = ?|;
  my ($value) = selectrow_query($form, $dbh, $query, $cid);
  $form->{creditremaining} -= $value;

  $query =
    qq|SELECT o.amount,
         (SELECT e.buy FROM exchangerate e
          WHERE e.currency_id = o.currency_id
            AND e.transdate = o.transdate)
       FROM oe o
       WHERE o.customer_id = ?
         AND o.record_type = 'sales_order'
         AND o.closed = '0'|;
  my $sth = prepare_execute_query($form, $dbh, $query, $cid);

  while (my ($amount, $exch) = $sth->fetchrow_array) {
    $exch = 1 unless $exch;
    $form->{creditremaining} -= $amount * $exch;
  }
  $sth->finish;

  $main::lxdebug->leave_sub();
}

sub retrieve_item {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->get_standard_dbh;

  my $i = $form->{rowcount};

  my $where = qq|NOT p.obsolete = '1'|;
  my @values;

  foreach my $column (qw(p.partnumber p.description pgpartsgroup )) {
    my ($table, $field) = split m/\./, $column;
    next if !$form->{"${field}_${i}"};
    $where .= qq| AND lower(${column}) ILIKE ?|;
    push @values, like($form->{"${field}_${i}"});
  }

  my (%mm_by_id);
  if ($form->{"partnumber_$i"} && !$form->{"description_$i"}) {
    $where .= qq| OR (NOT p.obsolete = '1' AND p.ean = ? )|;
    push @values, $form->{"partnumber_$i"};

    # also search hits in makemodels, but only cache the results by id and merge later
    my $mm_query = qq|
      SELECT parts_id, model FROM makemodel LEFT JOIN parts ON parts.id = parts_id WHERE NOT parts.obsolete AND model ILIKE ?;
    |;
    my $mm_results = selectall_hashref_query($::form, $dbh, $mm_query, like($form->{"partnumber_$i"}));
    my @mm_ids     = map { $_->{parts_id} } @$mm_results;
    push @{$mm_by_id{ $_->{parts_id} } ||= []}, $_ for @$mm_results;

    if (@mm_ids) {
      $where .= qq| OR p.id IN (| . join(',', ('?') x @mm_ids) . qq|)|;
      push @values, @mm_ids;
    }
  }

  # Search for part ID overrides all other criteria.
  if ($form->{"id_${i}"}) {
    $where  = qq|p.id = ?|;
    @values = ($form->{"id_${i}"});
  }

  if ($form->{"description_$i"}) {
    $where .= qq| ORDER BY p.description|;
  } else {
    $where .= qq| ORDER BY p.partnumber|;
  }

  my $transdate;
  if ($form->{type} eq "invoice") {
    $transdate =
      $form->{deliverydate} ? $dbh->quote($form->{deliverydate}) :
      $form->{invdate}      ? $dbh->quote($form->{invdate}) :
                              "current_date";
  } else {
    $transdate =
      $form->{transdate}    ? $dbh->quote($form->{transdate}) :
                              "current_date";
  }

  my $taxzone_id = $form->{taxzone_id} * 1;
  $taxzone_id = 0 if (0 > $taxzone_id) || (3 < $taxzone_id);

  my $query =
    qq|SELECT
         p.id, p.partnumber, p.description, p.sellprice,
         p.listprice, p.part_type, p.lastcost,
         p.ean, p.notes,
         p.classification_id,

         c1.accno AS inventory_accno,
         c1.new_chart_id AS inventory_new_chart,
         date($transdate) - c1.valid_from AS inventory_valid,

         c2.accno AS income_accno,
         c2.new_chart_id AS income_new_chart,
         date($transdate)  - c2.valid_from AS income_valid,

         c3.accno AS expense_accno,
         c3.new_chart_id AS expense_new_chart,
         date($transdate) - c3.valid_from AS expense_valid,

         p.unit, p.part_type, p.onhand,
         p.notes AS partnotes, p.notes AS longdescription,
         p.not_discountable, p.formel, p.payment_id AS part_payment_id,
         p.price_factor_id, p.weight,

         pfac.factor AS price_factor,
         pt.used_for_sale AS used_for_sale,
         pg.partsgroup

       FROM parts p
       LEFT JOIN chart c1 ON
         ((SELECT inventory_accno_id
           FROM buchungsgruppen
           WHERE id = p.buchungsgruppen_id) = c1.id)
       LEFT JOIN chart c2 ON
         ((SELECT tc.income_accno_id
           FROM taxzone_charts tc
           WHERE tc.buchungsgruppen_id = p.buchungsgruppen_id and tc.taxzone_id = ${taxzone_id}) = c2.id)
       LEFT JOIN chart c3 ON
         ((SELECT tc.expense_accno_id
           FROM taxzone_charts tc
           WHERE tc.buchungsgruppen_id = p.buchungsgruppen_id and tc.taxzone_id = ${taxzone_id}) = c3.id)
       LEFT JOIN partsgroup pg ON (pg.id = p.partsgroup_id)
       LEFT JOIN part_classifications pt ON (pt.id = p.classification_id)
       LEFT JOIN price_factors pfac ON (pfac.id = p.price_factor_id)
       WHERE $where|;
  my $sth = prepare_execute_query($form, $dbh, $query, @values);

  my @translation_queries = ( [ qq|SELECT tr.translation, tr.longdescription
                                   FROM translation tr
                                   WHERE tr.language_id = ? AND tr.parts_id = ?| ],
                              [ qq|SELECT tr.translation, tr.longdescription
                                   FROM translation tr
                                   WHERE tr.language_id IN
                                     (SELECT id
                                      FROM language
                                      WHERE article_code = (SELECT article_code FROM language WHERE id = ?))
                                     AND tr.parts_id = ?
                                   LIMIT 1| ] );
  map { push @{ $_ }, prepare_query($form, $dbh, $_->[0]) } @translation_queries;

  my $has_wrong_pclass = PCLASS_OK;
  while (my $ref = $sth->fetchrow_hashref('NAME_lc')) {

    if ($mm_by_id{$ref->{id}}) {
      $ref->{makemodels} = $mm_by_id{$ref->{id}};
      push @{ $ref->{matches} ||= [] }, $::locale->text('Model') . ': ' . join ', ', map { $_->{model} } @{ $mm_by_id{$ref->{id}} };
    }

    if (($::form->{"partnumber_$i"} ne '') && ($ref->{ean} eq $::form->{"partnumber_$i"})) {
      push @{ $ref->{matches} ||= [] }, $::locale->text('EAN') . ': ' . $ref->{ean};
    }

    $ref->{type_and_classific} = type_abbreviation($ref->{part_type}) .
                                 classification_abbreviation($ref->{classification_id});
    if (! $ref->{used_for_sale} ) {
      $has_wrong_pclass = PCLASS_NOTFORSALE ;
      next;
    }
    # In der Buchungsgruppe ist immer ein Bestandskonto verknuepft, auch wenn
    # es sich um eine Dienstleistung handelt. Bei Dienstleistungen muss das
    # Buchungskonto also aus dem Ergebnis rausgenommen werden.
    if (!$ref->{inventory_accno_id}) {
      map({ delete($ref->{"inventory_${_}"}); } qw(accno new_chart valid));
    }
    delete($ref->{inventory_accno_id});

    foreach my $type (qw(inventory income expense)) {
      while ($ref->{"${type}_new_chart"} && ($ref->{"${type}_valid"} >=0)) {
        my $query =
          qq|SELECT accno, new_chart_id, date($transdate) - valid_from
             FROM chart
             WHERE id = ?|;
        ($ref->{"${type}_accno"},
         $ref->{"${type}_new_chart"},
         $ref->{"${type}_valid"})
          = selectrow_query($form, $dbh, $query, $ref->{"${type}_new_chart"});
      }
    }

    if ($form->{payment_id} eq "") {
      $form->{payment_id} = $form->{part_payment_id};
    }

    # get tax rates and description
    my $accno_id = ($form->{vc} eq "customer") ? $ref->{income_accno} : $ref->{expense_accno};
    $query =
      qq|SELECT c.accno, t.taxdescription, t.id as tax_id, t.rate, c.accno as taxnumber
         FROM tax t
         LEFT JOIN chart c ON (c.id = t.chart_id)
         WHERE t.id in
           (SELECT tk.tax_id
            FROM taxkeys tk
            WHERE tk.chart_id = (SELECT id from chart WHERE accno = ?)
              AND startdate <= ?
            ORDER BY startdate DESC
            LIMIT 1)
         ORDER BY c.accno|;
    @values = ($accno_id, $transdate eq "current_date" ? "now" : $transdate);
    my $stw = $dbh->prepare($query);
    $stw->execute(@values) || $form->dberror($query);

    $ref->{taxaccounts} = "";
    my $i = 0;
    while (my $ptr = $stw->fetchrow_hashref('NAME_lc')) {

      if (($ptr->{accno} eq "") && ($ptr->{rate} == 0)) {
        $i++;
        $ptr->{accno} = $i;
      }
      $ref->{taxaccounts} .= "$ptr->{accno} ";

      if (!($form->{taxaccounts} =~ /\Q$ptr->{accno}\E/)) {
        $form->{"$ptr->{accno}_rate"}        = $ptr->{rate};
        $form->{"$ptr->{accno}_description"} = $ptr->{taxdescription};
        $form->{"$ptr->{accno}_taxnumber"}   = $ptr->{taxnumber};
        $form->{"$ptr->{accno}_tax_id"}      = $ptr->{tax_id};
        $form->{taxaccounts} .= "$ptr->{accno} ";
      }

    }

    $stw->finish;
    chop $ref->{taxaccounts};

    if ($form->{language_id}) {
      for my $spec (@translation_queries) {
        do_statement($form, $spec->[1], $spec->[0], conv_i($form->{language_id}), conv_i($ref->{id}));
        my ($translation, $longdescription) = $spec->[1]->fetchrow_array;
        next unless $translation;
        $ref->{description} = $translation;
        $ref->{longdescription} = $longdescription;
        last;
      }
    }

    $ref->{onhand} *= 1;
    push @{ $form->{item_list} }, $ref;
  }
  $sth->finish;
  $_->[1]->finish for @translation_queries;

  $form->{is_wrong_pclass} = $has_wrong_pclass;
  $form->{NOTFORSALE}      = PCLASS_NOTFORSALE;
  $form->{NOTFORPURCHASE}  = PCLASS_NOTFORPURCHASE;
  foreach my $item (@{ $form->{item_list} }) {
    my $custom_variables = CVar->get_custom_variables(module   => 'IC',
                                                      trans_id => $item->{id},
                                                      dbh      => $dbh,
                                                     );
    $form->{is_wrong_pclass} = PCLASS_OK; # one correct type
    map { $item->{"ic_cvar_" . $_->{name} } = $_->{value} } @{ $custom_variables };
  }
  $main::lxdebug->leave_sub();
}

sub has_storno {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $table) = @_;

  $main::lxdebug->leave_sub() and return 0 unless ($form->{id});

  # make sure there's no funny stuff in $table
  # ToDO: die when this happens and throw an error
  $main::lxdebug->leave_sub() and return 0 if ($table =~ /\W/);

  my $dbh = $form->get_standard_dbh;

  my $query = qq|SELECT storno FROM $table WHERE storno_id = ?|;
  my ($result) = selectrow_query($form, $dbh, $query, $form->{id});

  $main::lxdebug->leave_sub();

  return $result;
}

sub is_storno {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $table, $id) = @_;

  $main::lxdebug->leave_sub() and return 0 unless ($id);

  # make sure there's no funny stuff in $table
  # ToDO: die when this happens and throw an error
  $main::lxdebug->leave_sub() and return 0 if ($table =~ /\W/);

  my $dbh = $form->get_standard_dbh;

  my $query = qq|SELECT storno FROM $table WHERE id = ?|;
  my ($result) = selectrow_query($form, $dbh, $query, $id);

  $main::lxdebug->leave_sub();

  return $result;
}

sub get_standard_accno_current_assets {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->get_standard_dbh;

  my $query = qq| SELECT accno FROM chart WHERE id = (SELECT ar_paid_accno_id FROM defaults)|;
  my ($result) = selectrow_query($form, $dbh, $query);

  $main::lxdebug->leave_sub();

  return $result;
}

1;
