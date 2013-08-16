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
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#======================================================================
#
# Inventory invoicing module
#
#======================================================================

package IS;

use List::Util qw(max);

use SL::AM;
use SL::ARAP;
use SL::CVar;
use SL::Common;
use SL::DATEV qw(:CONSTANTS);
use SL::DBUtils;
use SL::DO;
use SL::GenericTranslations;
use SL::MoreCommon;
use SL::IC;
use SL::IO;
use SL::TransNumber;
use SL::DB::Default;
use Data::Dumper;

use strict;

sub invoice_details {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $locale) = @_;

  $form->{duedate} ||= $form->{invdate};

  # connect to database
  my $dbh = $form->get_standard_dbh;
  my $sth;

  my $query = qq|SELECT date | . conv_dateq($form->{duedate}) . qq| - date | . conv_dateq($form->{invdate}) . qq| AS terms|;
  ($form->{terms}) = selectrow_query($form, $dbh, $query);

  my (@project_ids, %projectnumbers, %projectdescriptions);
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

  if (@project_ids) {
    $query = "SELECT id, projectnumber, description FROM project WHERE id IN (" .
      join(", ", map({ "?" } @project_ids)) . ")";
    $sth = $dbh->prepare($query);
    $sth->execute(@project_ids) ||
      $form->dberror($query . " (" . join(", ", @project_ids) . ")");
    while (my $ref = $sth->fetchrow_hashref()) {
      $projectnumbers{$ref->{id}} = $ref->{projectnumber};
      $projectdescriptions{$ref->{id}} = $ref->{description};
    }
    $sth->finish();
  }

  $form->{"globalprojectnumber"} =
    $projectnumbers{$form->{"globalproject_id"}};
  $form->{"globalprojectdescription"} =
    $projectdescriptions{$form->{"globalproject_id"}};

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

  IC->prepare_parts_for_printing(myconfig => $myconfig, form => $form);

  my $ic_cvar_configs = CVar->get_configs(module => 'IC');

  my @arrays =
    qw(runningnumber number description longdescription qty ship unit bin
       deliverydate_oe ordnumber_oe transdate_oe validuntil
       partnotes serialnumber reqdate sellprice listprice netprice
       discount p_discount discount_sub nodiscount_sub
       linetotal  nodiscount_linetotal tax_rate projectnumber projectdescription
       price_factor price_factor_name partsgroup weight lineweight);

  push @arrays, map { "ic_cvar_$_->{name}" } @{ $ic_cvar_configs };

  my @tax_arrays = qw(taxbase tax taxdescription taxrate taxnumber);

  my @payment_arrays = qw(payment paymentaccount paymentdate paymentsource paymentmemo);

  map { $form->{TEMPLATE_ARRAYS}->{$_} = [] } (@arrays, @tax_arrays, @payment_arrays);

  my $totalweight = 0;
  foreach $item (sort { $a->[1] cmp $b->[1] } @partsgroup) {
    $i = $item->[0];

    if ($item->[1] ne $sameitem) {
      push(@{ $form->{TEMPLATE_ARRAYS}->{description} }, qq|$item->[1]|);
      $sameitem = $item->[1];

      map({ push(@{ $form->{TEMPLATE_ARRAYS}->{$_} }, "") } grep({ $_ ne "description" } @arrays));
    }

    $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});

    if ($form->{"id_$i"} != 0) {

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
      push @{ $form->{TEMPLATE_ARRAYS}->{ordnumber_oe} },      $form->{"ordnumber_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{transdate_oe} },      $form->{"transdate_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{invnumber} },         $form->{"invnumber"};
      push @{ $form->{TEMPLATE_ARRAYS}->{invdate} },           $form->{"invdate"};
      push @{ $form->{TEMPLATE_ARRAYS}->{price_factor} },      $price_factor->{formatted_factor};
      push @{ $form->{TEMPLATE_ARRAYS}->{price_factor_name} }, $price_factor->{description};
      push @{ $form->{TEMPLATE_ARRAYS}->{partsgroup} },        $form->{"partsgroup_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{reqdate} },           $form->{"reqdate_$i"};
      push(@{ $form->{TEMPLATE_ARRAYS}->{listprice} },         $form->{"listprice_$i"});

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

      $form->{"netprice_$i"}   = $form->round_amount($form->{"qty_$i"} ? ($linetotal / $form->{"qty_$i"}) : 0, 2);

      push @{ $form->{TEMPLATE_ARRAYS}->{netprice} },       ($form->{"netprice_$i"} != 0) ? $form->format_amount($myconfig, $form->{"netprice_$i"}, $decimalplaces) : '';
      push @{ $form->{TEMPLATE_ARRAYS}->{netprice_nofmt} }, ($form->{"netprice_$i"} != 0) ? $form->{"netprice_$i"} : '';

      $linetotal = ($linetotal != 0) ? $linetotal : '';

      push @{ $form->{TEMPLATE_ARRAYS}->{discount} },       ($discount != 0) ? $form->format_amount($myconfig, $discount * -1, 2) : '';
      push @{ $form->{TEMPLATE_ARRAYS}->{discount_nofmt} }, ($discount != 0) ? $discount * -1 : '';
      push @{ $form->{TEMPLATE_ARRAYS}->{p_discount} },     $form->{"discount_$i"};

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

      push(@{ $form->{TEMPLATE_ARRAYS}->{projectnumber} },              $projectnumbers{$form->{"project_id_$i"}});
      push(@{ $form->{TEMPLATE_ARRAYS}->{projectdescription} },         $projectdescriptions{$form->{"project_id_$i"}});

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
      if ($form->{"assembly_$i"}) {
        $sameitem = "";

        # get parts and push them onto the stack
        my $sortorder = "";
        if ($form->{groupitems}) {
          $sortorder =
            qq|ORDER BY pg.partsgroup, a.oid|;
        } else {
          $sortorder = qq|ORDER BY a.oid|;
        }

        $query =
          qq|SELECT p.partnumber, p.description, p.unit, a.qty, pg.partsgroup
             FROM assembly a
             JOIN parts p ON (a.parts_id = p.id)
             LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
             WHERE (a.bom = '1') AND (a.id = ?) $sortorder|;
        $sth = prepare_execute_query($form, $dbh, $query, conv_i($form->{"id_$i"}));

        while (my $ref = $sth->fetchrow_hashref('NAME_lc')) {
          if ($form->{groupitems} && $ref->{partsgroup} ne $sameitem) {
            map({ push(@{ $form->{TEMPLATE_ARRAYS}->{$_} }, "") } grep({ $_ ne "description" } @arrays));
            $sameitem = ($ref->{partsgroup}) ? $ref->{partsgroup} : "--";
            push(@{ $form->{TEMPLATE_ARRAYS}->{description} }, $sameitem);
          }

          map { $form->{"a_$_"} = $ref->{$_} } qw(partnumber description);

          push(@{ $form->{TEMPLATE_ARRAYS}->{description} },
               $form->format_amount($myconfig, $ref->{qty} * $form->{"qty_$i"}
                 )
                 . qq| -- $form->{"a_partnumber"}, $form->{"a_description"}|);
          map({ push(@{ $form->{TEMPLATE_ARRAYS}->{$_} }, "") } grep({ $_ ne "description" } @arrays));

        }
        $sth->finish;
      }

      push @{ $form->{TEMPLATE_ARRAYS}->{"ic_cvar_$_->{name}"} },
        CVar->format_to_template(CVar->parse($form->{"ic_cvar_$_->{name}_$i"}, $_), $_)
          for @{ $ic_cvar_configs };
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
    push(@{ $form->{TEMPLATE_ARRAYS}->{taxdescription} }, $form->{"${item}_description"} . q{ } . 100 * $form->{"${item}_rate"} . q{%});
    push(@{ $form->{TEMPLATE_ARRAYS}->{taxnumber} },      $form->{"${item}_taxnumber"});
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

  $form->{invtotal} = ($form->{taxincluded}) ? $form->{total} : $form->{total} + $tax;
  $form->{total}    = $form->format_amount($myconfig, $form->{invtotal} - $form->{paid}, 2);

  $form->{invtotal} = $form->format_amount($myconfig, $form->{invtotal}, 2);
  $form->{paid}     = $form->format_amount($myconfig, $form->{paid}, 2);

  $form->set_payment_options($myconfig, $form->{invdate});

  $form->{username} = $myconfig->{name};

  $main::lxdebug->leave_sub();
}

sub project_description {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $id) = @_;
  my $form = \%main::form;

  my $query = qq|SELECT description FROM project WHERE id = ?|;
  my ($description) = selectrow_query($form, $dbh, $query, conv_i($id));

  $main::lxdebug->leave_sub();

  return $_;
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

  # remove id and taxincluded before copy back
  delete @$ref{qw(id taxincluded)};

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

  $form->{cp_greeting} = GenericTranslations->get('dbh'              => $dbh,
                                                  'translation_type' => 'greetings::' . ($form->{cp_gender} eq 'f' ? 'female' : 'male'),
                                                  'language_id'      => $language_id,
                                                  'allow_fallback'   => 1);


  $main::lxdebug->leave_sub();
}

sub post_invoice {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $provided_dbh, $payments_only) = @_;

  # connect to database, turn off autocommit
  my $dbh = $provided_dbh ? $provided_dbh : $form->get_standard_dbh;

  my ($query, $sth, $null, $project_id, @values);
  my $exchangerate = 0;

  my $ic_cvar_configs = CVar->get_configs(module => 'IC',
                                          dbh    => $dbh);

  if (!$form->{employee_id}) {
    $form->get_employee($dbh);
  }

  $form->{defaultcurrency} = $form->get_default_currency($myconfig);
  my $defaultcurrency = $form->{defaultcurrency};

  # Seit neuestem wird die department_id schon übergeben UND $form->department nicht mehr
  # korrekt zusammengebaut. Sehr wahrscheinlich beim Umstieg auf T8 kaputt gegangen
  # Ich lass den Code von 2005 erstmal noch stehen ;-) jb 03-2011
  if (!$form->{department_id}){
    ($null, $form->{department_id}) = split(/--/, $form->{department});
  }

  my $all_units = AM->retrieve_units($myconfig, $form);

  if (!$payments_only) {
    if ($form->{id}) {
      &reverse_invoice($dbh, $form);

    } else {
      my $trans_number   = SL::TransNumber->new(type => $form->{type}, dbh => $dbh, number => $form->{invnumber}, save => 1);
      $form->{invnumber} = $trans_number->create_unique unless $trans_number->is_unique;

      $query = qq|SELECT nextval('glid')|;
      ($form->{"id"}) = selectrow_query($form, $dbh, $query);

      $query = qq|INSERT INTO ar (id, invnumber, currency_id) VALUES (?, ?, (SELECT id FROM currencies WHERE name=?))|;
      do_query($form, $dbh, $query, $form->{"id"}, $form->{"id"}, $form->{currency});

      if (!$form->{invnumber}) {
        $form->{invnumber} =
          $form->update_defaults($myconfig, $form->{type} eq "credit_note" ?
                                 "cnnumber" : "invnumber", $dbh);
      }
    }
  }

  my ($netamount, $invoicediff) = (0, 0);
  my ($amount, $linetotal, $lastincomeaccno);

  if ($form->{currency} eq $defaultcurrency) {
    $form->{exchangerate} = 1;
  } else {
    $exchangerate = $form->check_exchangerate($myconfig, $form->{currency}, $form->{invdate}, 'buy');
  }

  $form->{exchangerate} =
    ($exchangerate)
    ? $exchangerate
    : $form->parse_amount($myconfig, $form->{exchangerate});

  $form->{expense_inventory} = "";

  my %baseunits;

  $form->get_lists('price_factors' => 'ALL_PRICE_FACTORS');
  my %price_factors = map { $_->{id} => $_->{factor} } @{ $form->{ALL_PRICE_FACTORS} };
  my $price_factor;

  $form->{amount}      = {};
  $form->{amount_cogs} = {};

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

      if ($form->{"inventory_accno_$i"} || $form->{"assembly_$i"}) {

        if ($form->{"assembly_$i"}) {
          # record assembly item as allocated
          &process_assembly($dbh, $myconfig, $form, $form->{"id_$i"}, $baseqty);

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

      my ($invoice_id) = selectfirst_array_query($form, $dbh, qq|SELECT nextval('invoiceid')|);

      # save detail record in invoice table
      $query =
        qq|INSERT INTO invoice (id, trans_id, parts_id, description, longdescription, qty,
                                sellprice, fxsellprice, discount, allocated, assemblyitem,
                                unit, deliverydate, project_id, serialnumber, pricegroup_id,
                                ordnumber, transdate, cusordnumber, base_qty, subtotal,
                                marge_percent, marge_total, lastcost,
                                price_factor_id, price_factor, marge_price_factor)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                   (SELECT factor FROM price_factors WHERE id = ?), ?)|;

      @values = ($invoice_id, conv_i($form->{id}), conv_i($form->{"id_$i"}),
                 $form->{"description_$i"}, $form->{"longdescription_$i"}, $form->{"qty_$i"},
                 $form->{"sellprice_$i"}, $fxsellprice,
                 $form->{"discount_$i"}, $allocated, 'f',
                 $form->{"unit_$i"}, conv_date($form->{"reqdate_$i"}), conv_i($form->{"project_id_$i"}),
                 $form->{"serialnumber_$i"}, $pricegroup_id,
                 $form->{"ordnumber_$i"}, conv_date($form->{"transdate_$i"}),
                 $form->{"cusordnumber_$i"}, $baseqty, $form->{"subtotal_$i"} ? 't' : 'f',
                 $form->{"marge_percent_$i"}, $form->{"marge_absolut_$i"},
                 $form->{"lastcost_$i"},
                 conv_i($form->{"price_factor_id_$i"}), conv_i($form->{"price_factor_id_$i"}),
                 conv_i($form->{"marge_price_factor_$i"}));
      do_query($form, $dbh, $query, @values);

      CVar->save_custom_variables(module       => 'IC',
                                  sub_module   => 'invoice',
                                  trans_id     => $invoice_id,
                                  configs      => $ic_cvar_configs,
                                  variables    => $form,
                                  name_prefix  => 'ic_',
                                  name_postfix => "_$i",
                                  dbh          => $dbh);
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

  $form->{amount}{ $form->{id} }{ $form->{AR} } = $netamount + $tax;
  $form->{paid} =
    $form->round_amount($form->{paid} * $form->{exchangerate} + $diff, 2);

  # reverse AR
  $form->{amount}{ $form->{id} }{ $form->{AR} } *= -1;

  # update exchangerate
  if (($form->{currency} ne $defaultcurrency) && !$exchangerate) {
    $form->update_exchangerate($dbh, $form->{currency}, $form->{invdate},
                               $form->{exchangerate}, 0);
  }

  $project_id = conv_i($form->{"globalproject_id"});
  # entsprechend auch beim Bestimmen des Steuerschlüssels in Taxkey.pm berücksichtigen
  my $taxdate = $form->{deliverydate} ? $form->{deliverydate} : $form->{invdate};

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
          qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, tax_id, taxkey, project_id, chart_link)
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
                     (SELECT link FROM chart WHERE accno = ?))|;
        @values = (conv_i($trans_id), $accno, $form->{amount}{$trans_id}{$accno}, conv_date($form->{invdate}), $accno, conv_date($taxdate), $accno, conv_date($taxdate), conv_i($project_id), $accno);
        do_query($form, $dbh, $query, @values);
        $form->{amount}{$trans_id}{$accno} = 0;
      }
    }

    foreach my $accno (keys %{ $form->{amount}{$trans_id} }) {
      $form->{amount}{$trans_id}{$accno} = $form->round_amount($form->{amount}{$trans_id}{$accno}, 2);

      if (!$payments_only && ($form->{amount}{$trans_id}{$accno} != 0)) {
        $query =
          qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, tax_id, taxkey, project_id, chart_link)
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
                     (SELECT link FROM chart WHERE accno = ?))|;
        @values = (conv_i($trans_id), $accno, $form->{amount}{$trans_id}{$accno}, conv_date($form->{invdate}), $accno, conv_date($taxdate), $accno, conv_date($taxdate), conv_i($project_id), $accno);
        do_query($form, $dbh, $query, @values);
      }
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

      if ($form->{amount}{ $form->{id} }{ $form->{AR} } != 0) {
        $query =
        qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, tax_id, taxkey, project_id, chart_link)
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
                   (SELECT link FROM chart WHERE accno = ?))|;
        @values = (conv_i($form->{"id"}), $form->{AR}, $amount, $form->{"datepaid_$i"}, $form->{AR}, conv_date($taxdate), $form->{AR}, conv_date($taxdate), $project_id, $form->{AR});
        do_query($form, $dbh, $query, @values);
      }

      # record payment
      $form->{"paid_$i"} *= -1;
      my $gldate = (conv_date($form->{"gldate_$i"}))? conv_date($form->{"gldate_$i"}) : conv_date($form->current_date($myconfig));

      $query =
      qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, gldate, source, memo, tax_id, taxkey, project_id, chart_link)
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
                 ?,
                 (SELECT link FROM chart WHERE accno = ?))|;
      @values = (conv_i($form->{"id"}), $accno, $form->{"paid_$i"}, $form->{"datepaid_$i"},
                 $gldate, $form->{"source_$i"}, $form->{"memo_$i"}, $accno, conv_date($taxdate), $accno, conv_date($taxdate), $project_id, $accno);
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

      # update exchange rate
      if (($form->{currency} ne $defaultcurrency) && !$exchangerate) {
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

    $dbh->commit if !$provided_dbh;

    $main::lxdebug->leave_sub();
    return;
  }

  $amount = $netamount + $tax;

  # save AR record
  #erweiterung fuer lieferscheinnummer (donumber) 12.02.09 jb

  $query = qq|UPDATE ar set
                invnumber   = ?, ordnumber     = ?, quonumber     = ?, cusordnumber  = ?,
                transdate   = ?, orddate       = ?, quodate       = ?, customer_id   = ?,
                amount      = ?, netamount     = ?, paid          = ?,
                duedate     = ?, deliverydate  = ?, invoice       = ?, shippingpoint = ?,
                shipvia     = ?, terms         = ?, notes         = ?, intnotes      = ?,
                currency_id = (SELECT id FROM currencies WHERE name = ?),
                department_id = ?, payment_id    = ?, taxincluded   = ?,
                type        = ?, language_id   = ?, taxzone_id    = ?, shipto_id     = ?,
                employee_id = ?, salesman_id   = ?, storno_id     = ?, storno        = ?,
                cp_id       = ?, marge_total   = ?, marge_percent = ?,
                globalproject_id               = ?, delivery_customer_id             = ?,
                transaction_description        = ?, delivery_vendor_id               = ?,
                donumber    = ?, invnumber_for_credit_note = ?,        direct_debit  = ?
              WHERE id = ?|;
  @values = (          $form->{"invnumber"},           $form->{"ordnumber"},             $form->{"quonumber"},          $form->{"cusordnumber"},
             conv_date($form->{"invdate"}),  conv_date($form->{"orddate"}),    conv_date($form->{"quodate"}),    conv_i($form->{"customer_id"}),
                       $amount,                        $netamount,                       $form->{"paid"},
             conv_date($form->{"duedate"}),  conv_date($form->{"deliverydate"}),    '1',                                $form->{"shippingpoint"},
                       $form->{"shipvia"},      conv_i($form->{"terms"}),                $form->{"notes"},              $form->{"intnotes"},
                       $form->{"currency"},     conv_i($form->{"department_id"}), conv_i($form->{"payment_id"}),        $form->{"taxincluded"} ? 't' : 'f',
                       $form->{"type"},         conv_i($form->{"language_id"}),   conv_i($form->{"taxzone_id"}), conv_i($form->{"shipto_id"}),
                conv_i($form->{"employee_id"}), conv_i($form->{"salesman_id"}),   conv_i($form->{storno_id}),           $form->{"storno"} ? 't' : 'f',
                conv_i($form->{"cp_id"}),            1 * $form->{marge_total} ,      1 * $form->{marge_percent},
                conv_i($form->{"globalproject_id"}),                              conv_i($form->{"delivery_customer_id"}),
                       $form->{transaction_description},                          conv_i($form->{"delivery_vendor_id"}),
                       $form->{"donumber"}, $form->{"invnumber_for_credit_note"},        $form->{direct_debit} ? 't' : 'f',
                conv_i($form->{"id"}));
  do_query($form, $dbh, $query, @values);


  if ($form->{storno}) {
    $query =
      qq!UPDATE ar SET
           paid = paid + amount,
           storno = 't',
           intnotes = ? || intnotes
         WHERE id = ?!;
    do_query($form, $dbh, $query, "Rechnung storniert am $form->{invdate} ", conv_i($form->{"storno_id"}));
    do_query($form, $dbh, qq|UPDATE ar SET paid = amount WHERE id = ?|, conv_i($form->{"id"}));
  }

  # add shipto
  $form->{name} = $form->{customer};
  $form->{name} =~ s/--\Q$form->{customer_id}\E//;

  if (!$form->{shipto_id}) {
    $form->add_shipto($dbh, $form->{id}, "AR");
  }

  # save printed, emailed and queued
  $form->save_status($dbh);

  Common::webdav_folder($form);

  # Link this record to the records it was created from.
  RecordLinks->create_links('dbh'        => $dbh,
                            'mode'       => 'ids',
                            'from_table' => 'oe',
                            'from_ids'   => $form->{convert_from_oe_ids},
                            'to_table'   => 'ar',
                            'to_id'      => $form->{id},
    );
  delete $form->{convert_from_oe_ids};

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

  # safety check datev export
  if ($::instance_conf->get_datev_check_on_sales_invoice) {
    my $transdate = $::form->{invdate} ? DateTime->from_lxoffice($::form->{invdate}) : undef;
    $transdate  ||= DateTime->today;

    my $datev = SL::DATEV->new(
      exporttype => DATEV_ET_BUCHUNGEN,
      format     => DATEV_FORMAT_KNE,
      dbh        => $dbh,
      from       => $transdate,
      to         => $transdate,
      trans_id   => $form->{id},
    );

    $datev->export;

    if ($datev->errors) {
      $dbh->rollback;
      die join "\n", $::locale->text('DATEV check returned errors:'), $datev->errors;
    }
  }

  my $rc = 1;
  $dbh->commit if !$provided_dbh;

  $main::lxdebug->leave_sub();

  return $rc;
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
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $locale) = @_;

  # connect to database, turn off autocommit
  my $dbh = $form->get_standard_dbh;

  my (%payments, $old_form, $row, $item, $query, %keep_vars);

  $old_form = save_form();

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
  $self->post_invoice($myconfig, $form, $dbh, 1);

  restore_form($old_form);

  my $rc = $dbh->commit();

  $main::lxdebug->leave_sub();

  return $rc;
}

sub process_assembly {
  $main::lxdebug->enter_sub();

  my ($dbh, $myconfig, $form, $id, $totalqty) = @_;

  my $query =
    qq|SELECT a.parts_id, a.qty, p.assembly, p.partnumber, p.description, p.unit,
         p.inventory_accno_id, p.income_accno_id, p.expense_accno_id
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
      &process_assembly($dbh, $myconfig, $form, $ref->{parts_id}, $ref->{qty});
      next;
    } else {
      if ($ref->{inventory_accno_id}) {
        $allocated = &cogs($dbh, $myconfig, $form, $ref->{parts_id}, $ref->{qty});
      }
    }

    # save detail record for individual assembly item in invoice table
    $query =
      qq|INSERT INTO invoice (trans_id, description, parts_id, qty, sellprice, fxsellprice, allocated, assemblyitem, unit)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)|;
    my @values = (conv_i($form->{id}), $ref->{description}, conv_i($ref->{parts_id}), $ref->{qty}, 0, 0, $allocated, 't', $ref->{unit});
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
       LEFT JOIN chart c2 ON ((SELECT income_accno_id_${taxzone_id} FROM buchungsgruppen WHERE id = p.buchungsgruppen_id) = c2.id)
       LEFT JOIN chart c3 ON ((select expense_accno_id_${taxzone_id} FROM buchungsgruppen WHERE id = p.buchungsgruppen_id) = c3.id)
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
    qq|SELECT i.id, i.parts_id, i.qty, i.assemblyitem, p.assembly, p.inventory_accno_id
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
  do_query($form, $dbh, qq|DELETE FROM invoice WHERE trans_id = ?|, @values);
  do_query($form, $dbh, qq|DELETE FROM shipto WHERE (trans_id = ?) AND (module = 'AR')|, @values);

  $main::lxdebug->leave_sub();
}

sub delete_invoice {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->get_standard_dbh;

  &reverse_invoice($dbh, $form);

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

  # delete spool files
  my @spoolfiles = selectall_array_query($form, $dbh, qq|SELECT spoolfile FROM status WHERE trans_id = ?|, @values);

  my @queries = (
    qq|DELETE FROM status WHERE trans_id = ?|,
    qq|DELETE FROM periodic_invoices WHERE ar_id = ?|,
    qq|DELETE FROM ar WHERE id = ?|,
  );

  map { do_query($form, $dbh, $_, @values) } @queries;

  my $rc = $dbh->commit;

  if ($rc) {
    my $spool = $::lx_office_conf{paths}->{spool};
    map { unlink "$spool/$_" if -f "$spool/$_"; } @spoolfiles;
  }

  $main::lxdebug->leave_sub();

  return $rc;
}

sub retrieve_invoice {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->get_standard_dbh;

  my ($sth, $ref, $query);

  my $query_transdate = !$form->{id} ? ", current_date AS invdate" : '';

  $query =
    qq|SELECT
         (SELECT c.accno FROM chart c WHERE d.inventory_accno_id = c.id) AS inventory_accno,
         (SELECT c.accno FROM chart c WHERE d.income_accno_id = c.id)    AS income_accno,
         (SELECT c.accno FROM chart c WHERE d.expense_accno_id = c.id)   AS expense_accno,
         (SELECT c.accno FROM chart c WHERE d.fxgain_accno_id = c.id)    AS fxgain_accno,
         (SELECT c.accno FROM chart c WHERE d.fxloss_accno_id = c.id)    AS fxloss_accno
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
           a.transdate AS invdate, a.deliverydate, a.paid, a.storno, a.gldate,
           a.shippingpoint, a.shipvia, a.terms, a.notes, a.intnotes, a.taxzone_id,
           a.duedate, a.taxincluded, (SELECT cu.name FROM currencies cu WHERE cu.id=a.currency_id) AS currency, a.shipto_id, a.cp_id,
           a.employee_id, a.salesman_id, a.payment_id,
           a.language_id, a.delivery_customer_id, a.delivery_vendor_id, a.type,
           a.transaction_description, a.donumber, a.invnumber_for_credit_note,
           a.marge_total, a.marge_percent, a.direct_debit,
           e.name AS employee
         FROM ar a
         LEFT JOIN employee e ON (e.id = a.employee_id)
         WHERE a.id = ?|;
    $ref = selectfirst_hashref_query($form, $dbh, $query, $id);
    map { $form->{$_} = $ref->{$_} } keys %{ $ref };

    $form->{exchangerate} = $form->get_exchangerate($dbh, $form->{currency}, $form->{invdate}, "buy");

    # get shipto
    $query = qq|SELECT * FROM shipto WHERE (trans_id = ?) AND (module = 'AR')|;
    $ref = selectfirst_hashref_query($form, $dbh, $query, $id);
    delete $ref->{id};
    map { $form->{$_} = $ref->{$_} } keys %{ $ref };

    foreach my $vc (qw(customer vendor)) {
      next if !$form->{"delivery_${vc}_id"};
      ($form->{"delivery_${vc}_string"}) = selectrow_query($form, $dbh, qq|SELECT name FROM customer WHERE id = ?|, $id);
    }

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

    my $transdate = $form->{deliverydate} ? $dbh->quote($form->{deliverydate})
                  : $form->{invdate}      ? $dbh->quote($form->{invdate})
                  :                         "current_date";


    my $taxzone_id = $form->{taxzone_id} *= 1;
    $taxzone_id = 0 if (0 > $taxzone_id) || (3 < $taxzone_id);

    # retrieve individual items
    $query =
      qq|SELECT
           c1.accno AS inventory_accno, c1.new_chart_id AS inventory_new_chart, date($transdate) - c1.valid_from AS inventory_valid,
           c2.accno AS income_accno,    c2.new_chart_id AS income_new_chart,    date($transdate) - c2.valid_from as income_valid,
           c3.accno AS expense_accno,   c3.new_chart_id AS expense_new_chart,   date($transdate) - c3.valid_from AS expense_valid,

           i.id AS invoice_id,
           i.description, i.longdescription, i.qty, i.fxsellprice AS sellprice, i.discount, i.parts_id AS id, i.unit, i.deliverydate AS reqdate,
           i.project_id, i.serialnumber, i.id AS invoice_pos, i.pricegroup_id, i.ordnumber, i.transdate, i.cusordnumber, i.subtotal, i.lastcost,
           i.price_factor_id, i.price_factor, i.marge_price_factor,
           p.partnumber, p.assembly, p.notes AS partnotes, p.inventory_accno_id AS part_inventory_accno_id, p.formel, p.listprice,
           pr.projectnumber, pg.partsgroup, prg.pricegroup

         FROM invoice i
         LEFT JOIN parts p ON (i.parts_id = p.id)
         LEFT JOIN project pr ON (i.project_id = pr.id)
         LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
         LEFT JOIN pricegroup prg ON (i.pricegroup_id = prg.id)

         LEFT JOIN chart c1 ON ((SELECT inventory_accno_id             FROM buchungsgruppen WHERE id = p.buchungsgruppen_id) = c1.id)
         LEFT JOIN chart c2 ON ((SELECT income_accno_id_${taxzone_id}  FROM buchungsgruppen WHERE id = p.buchungsgruppen_id) = c2.id)
         LEFT JOIN chart c3 ON ((SELECT expense_accno_id_${taxzone_id} FROM buchungsgruppen WHERE id = p.buchungsgruppen_id) = c3.id)

         WHERE (i.trans_id = ?) AND NOT (i.assemblyitem = '1') ORDER BY i.id|;

    $sth = prepare_execute_query($form, $dbh, $query, $id);

    while (my $ref = $sth->fetchrow_hashref('NAME_lc')) {
      # Retrieve custom variables.
      my $cvars = CVar->get_custom_variables(dbh        => $dbh,
                                             module     => 'IC',
                                             sub_module => 'invoice',
                                             trans_id   => $ref->{invoice_id},
                                            );
      map { $ref->{"ic_cvar_$_->{name}"} = $_->{value} } @{ $cvars };
      delete $ref->{invoice_id};

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
        qq|SELECT c.accno, t.taxdescription, t.rate, t.taxnumber FROM tax t
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
          $form->{"$ptr->{accno}_taxnumber"}   = $ptr->{taxnumber};
          $form->{taxaccounts} .= "$ptr->{accno} ";
        }

      }

      $ref->{qty} *= -1 if $form->{type} eq "credit_note";

      chop $ref->{taxaccounts};
      push @{ $form->{invoice_details} }, $ref;
      $stw->finish;
    }
    $sth->finish;

    Common::webdav_folder($form);
  }

  my $rc = $dbh->commit;

  $main::lxdebug->leave_sub();

  return $rc;
}

sub get_customer {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->get_standard_dbh;

  my $dateformat = $myconfig->{dateformat};
  $dateformat .= "yy" if $myconfig->{dateformat} !~ /^y/;

  my (@values, $duedate, $ref, $query);

  if ($form->{invdate}) {
    $duedate = "to_date(?, '$dateformat')";
    push @values, $form->{invdate};
  } else {
    $duedate = "current_date";
  }

  my $cid = conv_i($form->{customer_id});
  my $payment_id;

  if ($form->{payment_id}) {
    $payment_id = "(pt.id = ?) OR";
    push @values, conv_i($form->{payment_id});
  }

  # get customer
  $query =
    qq|SELECT
         c.id AS customer_id, c.name AS customer, c.discount as customer_discount, c.creditlimit, c.terms,
         c.email, c.cc, c.bcc, c.language_id, c.payment_id,
         c.street, c.zipcode, c.city, c.country,
         c.notes AS intnotes, c.klass as customer_klass, c.taxzone_id, c.salesman_id, cu.name AS curr,
         c.taxincluded_checked, c.direct_debit,
         $duedate + COALESCE(pt.terms_netto, 0) AS duedate,
         b.discount AS tradediscount, b.description AS business
       FROM customer c
       LEFT JOIN business b ON (b.id = c.business_id)
       LEFT JOIN payment_terms pt ON ($payment_id (c.payment_id = pt.id))
       LEFT JOIN currencies cu ON (c.currency_id=cu.id)
       WHERE c.id = ?|;
  push @values, $cid;
  $ref = selectfirst_hashref_query($form, $dbh, $query, @values);

  delete $ref->{salesman_id} if !$ref->{salesman_id};

  map { $form->{$_} = $ref->{$_} } keys %$ref;

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
         AND o.quotation = '0'
         AND o.closed = '0'|;
  my $sth = prepare_execute_query($form, $dbh, $query, $cid);

  while (my ($amount, $exch) = $sth->fetchrow_array) {
    $exch = 1 unless $exch;
    $form->{creditremaining} -= $amount * $exch;
  }
  $sth->finish;

  # get shipto if we did not converted an order or invoice
  if (!$form->{shipto}) {
    map { delete $form->{$_} }
      qw(shiptoname shiptodepartment_1 shiptodepartment_2
         shiptostreet shiptozipcode shiptocity shiptocountry
         shiptocontact shiptophone shiptofax shiptoemail);

    $query = qq|SELECT * FROM shipto WHERE trans_id = ? AND module = 'CT'|;
    $ref = selectfirst_hashref_query($form, $dbh, $query, $cid);
    delete $ref->{id};
    map { $form->{$_} = $ref->{$_} } keys %$ref;
  }

  # setup last accounts used for this customer
  if (!$form->{id} && $form->{type} !~ /_(order|quotation)/) {
    $query =
      qq|SELECT c.id, c.accno, c.description, c.link, c.category
         FROM chart c
         JOIN acc_trans ac ON (ac.chart_id = c.id)
         JOIN ar a ON (a.id = ac.trans_id)
         WHERE a.customer_id = ?
           AND NOT (c.link LIKE '%_tax%' OR c.link LIKE '%_paid%')
           AND a.id IN (SELECT max(a2.id) FROM ar a2 WHERE a2.customer_id = ?)|;
    $sth = prepare_execute_query($form, $dbh, $query, $cid, $cid);

    my $i = 0;
    while ($ref = $sth->fetchrow_hashref('NAME_lc')) {
      if ($ref->{category} eq 'I') {
        $i++;
        $form->{"AR_amount_$i"} = "$ref->{accno}--$ref->{description}";

        if ($form->{initial_transdate}) {
          my $tax_query =
            qq|SELECT tk.tax_id, t.rate
               FROM taxkeys tk
               LEFT JOIN tax t ON tk.tax_id = t.id
               WHERE (tk.chart_id = ?) AND (startdate <= date(?))
               ORDER BY tk.startdate DESC
               LIMIT 1|;
          my ($tax_id, $rate) =
            selectrow_query($form, $dbh, $tax_query, $ref->{id},
                            $form->{initial_transdate});
          $form->{"taxchart_$i"} = "${tax_id}--${rate}";
        }
      }
      if ($ref->{category} eq 'A') {
        $form->{ARselected} = $form->{AR_1} = $ref->{accno};
      }
    }
    $sth->finish;
    $form->{rowcount} = $i if ($i && !$form->{type});
  }

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
    push @values, '%' . $form->{"${field}_${i}"} . '%';
  }

  #Es soll auch nach EAN gesucht werden, ohne Einschränkung durch Beschreibung
  if ($form->{"partnumber_$i"} && !$form->{"description_$i"}) {
    $where .= qq| OR (NOT p.obsolete = '1' AND p.ean = ? )|;
    push @values, $form->{"partnumber_$i"};
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
         p.listprice, p.inventory_accno_id, p.lastcost,

         c1.accno AS inventory_accno,
         c1.new_chart_id AS inventory_new_chart,
         date($transdate) - c1.valid_from AS inventory_valid,

         c2.accno AS income_accno,
         c2.new_chart_id AS income_new_chart,
         date($transdate)  - c2.valid_from AS income_valid,

         c3.accno AS expense_accno,
         c3.new_chart_id AS expense_new_chart,
         date($transdate) - c3.valid_from AS expense_valid,

         p.unit, p.assembly, p.onhand,
         p.notes AS partnotes, p.notes AS longdescription,
         p.not_discountable, p.formel, p.payment_id AS part_payment_id,
         p.price_factor_id, p.weight,

         pfac.factor AS price_factor,

         pg.partsgroup

       FROM parts p
       LEFT JOIN chart c1 ON
         ((SELECT inventory_accno_id
           FROM buchungsgruppen
           WHERE id = p.buchungsgruppen_id) = c1.id)
       LEFT JOIN chart c2 ON
         ((SELECT income_accno_id_${taxzone_id}
           FROM buchungsgruppen
           WHERE id = p.buchungsgruppen_id) = c2.id)
       LEFT JOIN chart c3 ON
         ((SELECT expense_accno_id_${taxzone_id}
           FROM buchungsgruppen
           WHERE id = p.buchungsgruppen_id) = c3.id)
       LEFT JOIN partsgroup pg ON (pg.id = p.partsgroup_id)
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

  while (my $ref = $sth->fetchrow_hashref('NAME_lc')) {

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
      qq|SELECT c.accno, t.taxdescription, t.rate, t.taxnumber
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

  foreach my $item (@{ $form->{item_list} }) {
    my $custom_variables = CVar->get_custom_variables(module   => 'IC',
                                                      trans_id => $item->{id},
                                                      dbh      => $dbh,
                                                     );

    map { $item->{"ic_cvar_" . $_->{name} } = $_->{value} } @{ $custom_variables };
  }

  $main::lxdebug->leave_sub();
}

##########################
# get pricegroups from database
# build up selected pricegroup
# if an exchange rate - change price
# for each part
#
sub get_pricegroups_for_parts {

  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->get_standard_dbh;

  $form->{"PRICES"} = {};

  my $i  = 1;
  my $id = 0;
  my $all_units = AM->retrieve_units($myconfig, $form);
  while (($form->{"id_$i"}) or ($form->{"new_id_$i"})) {
    $form->{"PRICES"}{$i} = [];

    $id = $form->{"id_$i"};

    if (!($form->{"id_$i"}) and $form->{"new_id_$i"}) {
      $id = $form->{"new_id_$i"};
    }

    my ($price, $selectedpricegroup_id) = split(/--/, $form->{"sellprice_pg_$i"});

    my $pricegroup_old = $form->{"pricegroup_old_$i"};

    # sellprice has format 13,0000 or 0,00000,  can't check for 0 numerically
    my $sellprice = $form->{"sellprice_$i"};
    my $pricegroup_id = $form->{"pricegroup_id_$i"};
    $form->{"new_pricegroup_$i"} = $selectedpricegroup_id;
    $form->{"old_pricegroup_$i"} = $pricegroup_old;

    my $price_new = $form->{"price_new_$i"};
    my $price_old = $form->{"price_old_$i"};

    if (!$form->{"unit_old_$i"}) {
      # Neue Ware aus der Datenbank. In diesem Fall ist unit_$i die
      # Einheit, wie sie in den Stammdaten hinterlegt wurde.
      # Es sollte also angenommen werden, dass diese ausgewaehlt war.
      $form->{"unit_old_$i"} = $form->{"unit_$i"};
    }

    # Die zuletzt ausgewaehlte mit der aktuell ausgewaehlten Einheit
    # vergleichen und bei Unterschied den Preis entsprechend umrechnen.
    $form->{"selected_unit_$i"} = $form->{"unit_$i"} unless ($form->{"selected_unit_$i"});

    if (!$all_units->{$form->{"selected_unit_$i"}} ||
        ($all_units->{$form->{"selected_unit_$i"}}->{"base_unit"} ne
         $all_units->{$form->{"unit_old_$i"}}->{"base_unit"})) {
      # Die ausgewaehlte Einheit ist fuer diesen Artikel nicht gueltig
      # (z.B. Dimensionseinheit war ausgewaehlt, es handelt sich aber
      # um eine Dienstleistung). Dann keinerlei Umrechnung vornehmen.
      $form->{"unit_old_$i"} = $form->{"selected_unit_$i"} = $form->{"unit_$i"};
    }

    my $basefactor = 1;

    if ($form->{"unit_old_$i"} ne $form->{"selected_unit_$i"}) {
      if (defined($all_units->{$form->{"unit_old_$i"}}->{"factor"}) &&
          $all_units->{$form->{"unit_old_$i"}}->{"factor"}) {
        $basefactor = $all_units->{$form->{"selected_unit_$i"}}->{"factor"} /
          $all_units->{$form->{"unit_old_$i"}}->{"factor"};
      }
    }

    if (!$form->{"basefactor_$i"}) {
      $form->{"basefactor_$i"} = 1;
    }

    my $query =
       qq|SELECT
            0 as pricegroup_id,
            sellprice AS default_sellprice,
            '' AS pricegroup,
            sellprice AS price,
            'selected' AS selected
          FROM parts
          WHERE id = ?
          UNION ALL
          SELECT
           pricegroup_id,
           parts.sellprice AS default_sellprice,
           pricegroup.pricegroup,
           price,
           '' AS selected
          FROM prices
          LEFT JOIN parts ON parts.id = parts_id
          LEFT JOIN pricegroup ON pricegroup.id = pricegroup_id
          WHERE parts_id = ?
          ORDER BY pricegroup|;
    my @values = (conv_i($id), conv_i($id));
    my $pkq = prepare_execute_query($form, $dbh, $query, @values);

    while (my $pkr = $pkq->fetchrow_hashref('NAME_lc')) {
      $pkr->{id}       = $id;
      $pkr->{selected} = '';

      # if there is an exchange rate change price
      if (($form->{exchangerate} * 1) != 0) {
        $pkr->{price} /= $form->{exchangerate};
      }

      $pkr->{price} *= $form->{"basefactor_$i"};
      $pkr->{price} *= $basefactor;
      $pkr->{price_ufmt} = $pkr->{price};
      $pkr->{price} = $form->format_amount($myconfig, $pkr->{price}, 5);

      if (!defined $selectedpricegroup_id) {
        # new entries in article list, either old invoice was loaded (edit) or a new article was added
        # Case A: open old invoice, no pricegroup selected
        # Case B: add new article to invoice, no pricegroup selected

        # to distinguish case A and B the variable pricegroup_id_$i is used
        # for new articles this variable isn't defined, for loaded articles it is
        # sellprice can't be used, as it already has 0,00 set

        if ($pkr->{pricegroup_id} eq $form->{"pricegroup_id_$i"} and defined $form->{"pricegroup_id_$i"}) {
          # Case A
          $pkr->{selected}  = ' selected';
        } elsif ($pkr->{pricegroup_id} eq $form->{customer_klass}
                 and not defined $form->{"pricegroup_id_$i"}
                 and $pkr->{price_ufmt} != 0    # only use customer pricegroup price if it has a value, else use default_sellprice
                                                # for the case where pricegroup prices haven't been set
                ) {
          # Case B: use default pricegroup of customer

          $pkr->{selected}  = ' selected'; # unless $form->{selected};
          # no customer pricesgroup set
          if ($pkr->{price_ufmt} == $pkr->{default_sellprice}) {

            $pkr->{price} = $form->{"sellprice_$i"};

          } else {

# this sub should not set anything and only return. --sschoeling, 20090506
# is this correct? put in again... -- grichardson 20110119
            $form->{"sellprice_$i"} = $pkr->{price};
          }

        } elsif ($pkr->{price_ufmt} == $pkr->{default_sellprice} and $pkr->{default_sellprice} != 0) {
          $pkr->{price}    = $form->{"sellprice_$i"};
          $pkr->{selected} = ' selected';
        }
      }

      # existing article: pricegroup or price changed
      if ($selectedpricegroup_id or $selectedpricegroup_id == 0) {
        if ($selectedpricegroup_id ne $pricegroup_old) {
          # pricegroup has changed
          if ($pkr->{pricegroup_id} eq $selectedpricegroup_id) {
            $pkr->{selected}  = ' selected';
          }
        } elsif ( ($form->parse_amount($myconfig, $price_new)
                 != $form->parse_amount($myconfig, $form->{"sellprice_$i"}))
                  and ($price_new ne 0) and defined $price_new) {
          # sellprice has changed
          # when loading existing invoices $price_new is NULL
          if ($pkr->{pricegroup_id} == 0) {
            $pkr->{price}     = $form->{"sellprice_$i"};
            $pkr->{selected}  = ' selected';
          }
        } elsif ($pkr->{pricegroup_id} eq $selectedpricegroup_id) {
          # neither sellprice nor pricegroup changed
          $pkr->{selected}  = ' selected';
          if (    ($pkr->{pricegroup_id} == 0) and ($pkr->{price} == $form->{"sellprice_$i"})) {
            # $pkr->{price}                         = $form->{"sellprice_$i"};
          } else {
            $pkr->{price} = $form->{"sellprice_$i"};
          }
        }
      }
      push @{ $form->{PRICES}{$i} }, $pkr;

    }
    $form->{"basefactor_$i"} *= $basefactor;

    $i++;

    $pkq->finish;
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
