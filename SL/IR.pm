#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 2001
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
# Inventory received module
#
#======================================================================

package IR;

use SL::AM;
use SL::ARAP;
use SL::Common;
use SL::CVar;
use SL::DATEV qw(:CONSTANTS);
use SL::DBUtils;
use SL::DB::Draft;
use SL::DO;
use SL::GenericTranslations;
use SL::HTML::Restrict;
use SL::IO;
use SL::MoreCommon;
use SL::DB::Default;
use SL::DB::TaxZone;
use SL::DB::MakeModel;
use SL::DB;
use SL::Presenter::Part qw(type_abbreviation classification_abbreviation);
use List::Util qw(min);

use strict;
use constant PCLASS_OK             =>   0;
use constant PCLASS_NOTFORSALE     =>   1;
use constant PCLASS_NOTFORPURCHASE =>   2;

sub post_invoice {
  my ($self, $myconfig, $form, $provided_dbh, %params) = @_;
  $main::lxdebug->enter_sub();

  my $rc = SL::DB->client->with_transaction(\&_post_invoice, $self, $myconfig, $form, $provided_dbh, %params);

  $::lxdebug->leave_sub;
  return $rc;
}

sub _post_invoice {
  my ($self, $myconfig, $form, $provided_dbh, %params) = @_;

  my $payments_only = $params{payments_only};
  my $dbh = $provided_dbh || SL::DB->client->dbh;
  my $restricter = SL::HTML::Restrict->create;

  $form->{defaultcurrency} = $form->get_default_currency($myconfig);
  my $defaultcurrency = $form->{defaultcurrency};

  my $ic_cvar_configs = CVar->get_configs(module => 'IC',
                                          dbh    => $dbh);

  my ($query, $sth, @values, $project_id);
  my ($allocated, $taxrate, $taxamount, $taxdiff, $item);
  my ($amount, $linetotal, $lastinventoryaccno, $lastexpenseaccno);
  my ($netamount, $invoicediff, $expensediff) = (0, 0, 0);
  my $exchangerate = 0;
  my ($basefactor, $baseqty, @taxaccounts, $totaltax);

  my $all_units = AM->retrieve_units($myconfig, $form);

#markierung
  if (!$payments_only) {
    if ($form->{id}) {
      &reverse_invoice($dbh, $form);
    } else {
      ($form->{id}) = selectrow_query($form, $dbh, qq|SELECT nextval('glid')|);
      do_query($form, $dbh, qq|INSERT INTO ap (id, invnumber, currency_id, taxzone_id) VALUES (?, '', (SELECT id FROM currencies WHERE name=?), ?)|, $form->{id}, $form->{currency}, $form->{taxzone_id});
    }
  }

  if ($form->{currency} eq $defaultcurrency) {
    $form->{exchangerate} = 1;
  } else {
    $exchangerate = $form->check_exchangerate($myconfig, $form->{currency}, $form->{invdate}, 'sell');
  }

  $form->{exchangerate} = $exchangerate || $form->parse_amount($myconfig, $form->{exchangerate});
  $form->{exchangerate} = 1 unless ($form->{exchangerate} * 1);

  my %item_units;
  my $q_item_unit = qq|SELECT unit FROM parts WHERE id = ?|;
  my $h_item_unit = prepare_query($form, $dbh, $q_item_unit);

  $form->get_lists('price_factors' => 'ALL_PRICE_FACTORS');
  my %price_factors = map { $_->{id} => $_->{factor} } @{ $form->{ALL_PRICE_FACTORS} };
  my $price_factor;

  my @processed_invoice_ids;
  for my $i (1 .. $form->{rowcount}) {
    next unless $form->{"id_$i"};

    my $position = $i;

    $form->{"qty_$i"}  = $form->parse_amount($myconfig, $form->{"qty_$i"});
    $form->{"qty_$i"} *= -1 if $form->{storno};

    if ( $::instance_conf->get_inventory_system eq 'periodic') {
      # inventory account number is overwritten with expense account number, so
      # never book incoming to inventory account but always to expense account
      $form->{"inventory_accno_$i"} = $form->{"expense_accno_$i"}
    };

    # get item baseunit
    if (!$item_units{$form->{"id_$i"}}) {
      do_statement($form, $h_item_unit, $q_item_unit, $form->{"id_$i"});
      ($item_units{$form->{"id_$i"}}) = $h_item_unit->fetchrow_array();
    }

    my $item_unit = $item_units{$form->{"id_$i"}};

    if (defined($all_units->{$item_unit}->{factor})
            && ($all_units->{$item_unit}->{factor} ne '')
            && ($all_units->{$item_unit}->{factor} * 1 != 0)) {
      $basefactor = $all_units->{$form->{"unit_$i"}}->{factor} / $all_units->{$item_unit}->{factor};
    } else {
      $basefactor = 1;
    }
    $baseqty = $form->{"qty_$i"} * $basefactor;

    @taxaccounts = split / /, $form->{"taxaccounts_$i"};
    $taxdiff     = 0;
    $allocated   = 0;
    $taxrate     = 0;

    $form->{"sellprice_$i"} = $form->parse_amount($myconfig, $form->{"sellprice_$i"});
    (my $fxsellprice = $form->{"sellprice_$i"}) =~ /\.(\d+)/;
    my $dec = length $1;
    my $decimalplaces = ($dec > 2) ? $dec : 2;

    map { $taxrate += $form->{"${_}_rate"} } @taxaccounts;

    $price_factor = $price_factors{ $form->{"price_factor_id_$i"} } || 1;
    # copied from IS.pm, with some changes (no decimalplaces corrections here etc)
    # TODO maybe use PriceTaxCalculation or something like this for backends (IR.pm / IS.pm)

    # undo discount formatting
    $form->{"discount_$i"} = $form->parse_amount($myconfig, $form->{"discount_$i"}) / 100;
    # deduct discount
    $form->{"sellprice_$i"} = $fxsellprice * (1 - $form->{"discount_$i"});

    ######################################################################
    if ($form->{"inventory_accno_$i"}) {

      $linetotal = $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"} / $price_factor, 2);

      if ($form->{taxincluded}) {

        $taxamount              = $linetotal * ($taxrate / (1 + $taxrate));
        $form->{"sellprice_$i"} = $form->{"sellprice_$i"} * (1 / (1 + $taxrate));

      } else {
        $taxamount = $linetotal * $taxrate;
      }

      $netamount += $linetotal;

      if ($form->round_amount($taxrate, 7) == 0) {
        if ($form->{taxincluded}) {
          foreach $item (@taxaccounts) {
            $taxamount =
              $form->round_amount($linetotal * $form->{"${item}_rate"} / (1 + abs($form->{"${item}_rate"})), 2);
            $taxdiff                              += $taxamount;
            $form->{amount}{ $form->{id} }{$item} -= $taxamount;
          }
          $form->{amount}{ $form->{id} }{ $taxaccounts[0] } += $taxdiff;

        } else {
          map { $form->{amount}{ $form->{id} }{$_} -= $linetotal * $form->{"${_}_rate"} } @taxaccounts;
        }

      } else {
        map { $form->{amount}{ $form->{id} }{$_} -= $taxamount * $form->{"${_}_rate"} / $taxrate } @taxaccounts;
      }

      # add purchase to inventory, this one is without the tax!
      $amount    = $form->{"sellprice_$i"} * $form->{"qty_$i"} * $form->{exchangerate} / $price_factor;
      $linetotal = $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"} / $price_factor, 2) * $form->{exchangerate};
      $linetotal = $form->round_amount($linetotal, 2);

      # this is the difference for the inventory
      $invoicediff += ($amount - $linetotal);

      $form->{amount}{ $form->{id} }{ $form->{"inventory_accno_$i"} } -= $linetotal;

      # adjust and round sellprice
      $form->{"sellprice_$i"} = $form->round_amount($form->{"sellprice_$i"} * $form->{exchangerate}, $decimalplaces);

      $lastinventoryaccno = $form->{"inventory_accno_$i"};

      next if $payments_only;

      # update parts table by setting lastcost to current price, don't allow negative values by using abs
      $query = qq|UPDATE parts SET lastcost = ? WHERE id = ?|;
      @values = (abs($fxsellprice * $form->{exchangerate} / $basefactor), conv_i($form->{"id_$i"}));
      do_query($form, $dbh, $query, @values);

      # check if we sold the item already and
      # make an entry for the expense and inventory
      my $taxzone = $form->{taxzone_id} * 1;
      $query =
        qq|SELECT i.id, i.qty, i.allocated, i.trans_id, i.base_qty,
             bg.inventory_accno_id, tc.expense_accno_id AS expense_accno_id, a.transdate
           FROM invoice i, ar a, parts p, buchungsgruppen bg, taxzone_charts tc
           WHERE (i.parts_id = p.id)
             AND (i.parts_id = ?)
             AND ((i.base_qty + i.allocated) > 0)
             AND (i.trans_id = a.id)
             AND (p.buchungsgruppen_id = bg.id)
             AND (tc.buchungsgruppen_id = p.buchungsgruppen_id)
             AND (tc.taxzone_id = ${taxzone})
           ORDER BY transdate|;
           # ORDER BY transdate guarantees FIFO

      # sold two items without having bought them yet, example result of query:
      # id | qty | allocated | trans_id | inventory_accno_id | expense_accno_id | transdate
      # ---+-----+-----------+----------+--------------------+------------------+------------
      #  9 |   2 |         0 |        9 |                 15 |              151 | 2011-01-05

      # base_qty + allocated > 0 if article has already been sold but not bought yet

      # select qty,allocated,base_qty,sellprice from invoice where trans_id = 9;
      #  qty | allocated | base_qty | sellprice
      # -----+-----------+----------+------------
      #    2 |         0 |        2 | 1000.00000

      $sth = prepare_execute_query($form, $dbh, $query, conv_i($form->{"id_$i"}));

      my $totalqty = $baseqty;

      while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
        my $qty    = min $totalqty, ($ref->{base_qty} + $ref->{allocated});
        $linetotal = $form->round_amount(($form->{"sellprice_$i"} * $qty) / $basefactor, 2);

        if  ( $::instance_conf->get_inventory_system eq 'perpetual' ) {
        # Warenbestandsbuchungen nur bei Bestandsmethode

          if ($ref->{allocated} < 0) {

            # we have an entry for it already, adjust amount
            $form->update_balance($dbh, "acc_trans", "amount",
                qq|    (trans_id = $ref->{trans_id})
                AND (chart_id = $ref->{inventory_accno_id})
                AND (transdate = '$ref->{transdate}')|,
                $linetotal);

            $form->update_balance($dbh, "acc_trans", "amount",
                qq|    (trans_id = $ref->{trans_id})
                AND (chart_id = $ref->{expense_accno_id})
                AND (transdate = '$ref->{transdate}')|,
                $linetotal * -1);

          } elsif ($linetotal != 0) {

            # allocated >= 0
            # add entry for inventory, this one is for the sold item
            $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, taxkey, tax_id, chart_link) VALUES (?, ?, ?, ?,
                               (SELECT taxkey_id
                                FROM taxkeys
                                WHERE chart_id= ?
                                AND startdate <= ?
                                ORDER BY startdate DESC LIMIT 1),
                               (SELECT tax_id
                                FROM taxkeys
                                WHERE chart_id= ?
                                AND startdate <= ?
                                ORDER BY startdate DESC LIMIT 1),
                               (SELECT link FROM chart WHERE id = ?))|;
            @values = ($ref->{trans_id},  $ref->{inventory_accno_id}, $linetotal, $ref->{transdate}, $ref->{inventory_accno_id}, $ref->{transdate}, $ref->{inventory_accno_id}, $ref->{transdate},
                       $ref->{inventory_accno_id});
            do_query($form, $dbh, $query, @values);

            # add expense
            $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, taxkey, tax_id, chart_link) VALUES (?, ?, ?, ?,
                                (SELECT taxkey_id
                                 FROM taxkeys
                                 WHERE chart_id= ?
                                 AND startdate <= ?
                                 ORDER BY startdate DESC LIMIT 1),
                                (SELECT tax_id
                                 FROM taxkeys
                                 WHERE chart_id= ?
                                 AND startdate <= ?
                                 ORDER BY startdate DESC LIMIT 1),
                                (SELECT link FROM chart WHERE id = ?))|;
            @values = ($ref->{trans_id},  $ref->{expense_accno_id}, ($linetotal * -1), $ref->{transdate}, $ref->{expense_accno_id}, $ref->{transdate}, $ref->{expense_accno_id}, $ref->{transdate},
                       $ref->{expense_accno_id});
            do_query($form, $dbh, $query, @values);
          }
        };

        # update allocated for sold item
        $form->update_balance($dbh, "invoice", "allocated", qq|id = $ref->{id}|, $qty * -1);

        $allocated += $qty;

        last if ($totalqty -= $qty) <= 0;
      }

      $sth->finish();

    } else {                    # if ($form->{"inventory_accno_id_$i"})
      # part doesn't have an inventory_accno_id
      # lastcost of the part is updated at the end

      $linetotal = $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"} / $price_factor, 2);

      if ($form->{taxincluded}) {
        $taxamount              = $linetotal * ($taxrate / (1 + $taxrate));
        $form->{"sellprice_$i"} = $form->{"sellprice_$i"} * (1 / (1 + $taxrate));

      } else {
        $taxamount = $linetotal * $taxrate;
      }

      $netamount += $linetotal;

      if ($form->round_amount($taxrate, 7) == 0) {
        if ($form->{taxincluded}) {
          foreach $item (@taxaccounts) {
            $taxamount = $linetotal * $form->{"${item}_rate"} / (1 + abs($form->{"${item}_rate"}));
            $totaltax += $taxamount;
            $form->{amount}{ $form->{id} }{$item} -= $taxamount;
          }
        } else {
          map { $form->{amount}{ $form->{id} }{$_} -= $linetotal * $form->{"${_}_rate"} } @taxaccounts;
        }
      } else {
        map { $form->{amount}{ $form->{id} }{$_} -= $taxamount * $form->{"${_}_rate"} / $taxrate } @taxaccounts;
      }

      $amount    = $form->{"sellprice_$i"} * $form->{"qty_$i"} * $form->{exchangerate} / $price_factor;
      $linetotal = $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"} / $price_factor, 2) * $form->{exchangerate};
      $linetotal = $form->round_amount($linetotal, 2);

      # this is the difference for expense
      $expensediff += ($amount - $linetotal);

      # add amount to expense
      $form->{amount}{ $form->{id} }{ $form->{"expense_accno_$i"} } -= $linetotal;

      $lastexpenseaccno = $form->{"expense_accno_$i"};

      # adjust and round sellprice
      $form->{"sellprice_$i"} = $form->round_amount($form->{"sellprice_$i"} * $form->{exchangerate}, $decimalplaces);

      next if $payments_only;

      # update lastcost
      $query = qq|UPDATE parts SET lastcost = ? WHERE id = ?|;
      do_query($form, $dbh, $query, $form->{"sellprice_$i"} / $basefactor, conv_i($form->{"id_$i"}));
    }

    next if $payments_only;

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
        UPDATE invoice SET trans_id = ?, position = ?, parts_id = ?, description = ?, longdescription = ?, qty = ?, base_qty = ?,
                           sellprice = ?, fxsellprice = ?, discount = ?, allocated = ?, unit = ?, deliverydate = ?,
                           project_id = ?, serialnumber = ?, price_factor_id = ?,
                           price_factor = (SELECT factor FROM price_factors WHERE id = ?), marge_price_factor = ?,
                           active_price_source = ?, active_discount_source = ?
        WHERE id = ?
SQL

    @values = (conv_i($form->{id}), conv_i($position), conv_i($form->{"id_$i"}),
               $form->{"description_$i"}, $restricter->process($form->{"longdescription_$i"}), $form->{"qty_$i"} * -1,
               $baseqty * -1, $form->{"sellprice_$i"}, $fxsellprice, $form->{"discount_$i"}, $allocated,
               $form->{"unit_$i"}, conv_date($form->{deliverydate}),
               conv_i($form->{"project_id_$i"}), $form->{"serialnumber_$i"},
               conv_i($form->{"price_factor_id_$i"}), conv_i($form->{"price_factor_id_$i"}), conv_i($form->{"marge_price_factor_$i"}),
               $form->{"active_price_source_$i"}, $form->{"active_discount_source_$i"},
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

    # link previous items with invoice items See IS.pm (no credit note -> no invoice item)
    foreach (qw(delivery_order_items orderitems invoice)) {
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

  $h_item_unit->finish();

  $project_id = conv_i($form->{"globalproject_id"});

  $form->{datepaid} = $form->{invdate};

  # all amounts are in natural state, netamount includes the taxes
  # if tax is included, netamount is rounded to 2 decimal places,
  # taxes are not

  # total payments
  for my $i (1 .. $form->{paidaccounts}) {
    $form->{"paid_$i"}  = $form->parse_amount($myconfig, $form->{"paid_$i"});
    $form->{paid}      += $form->{"paid_$i"};
    $form->{datepaid}   = $form->{"datepaid_$i"} if $form->{"datepaid_$i"};
  }

  my ($tax, $paiddiff) = (0, 0);

  $netamount = $form->round_amount($netamount, 2);

  # figure out rounding errors for amount paid and total amount
  if ($form->{taxincluded}) {

    $amount    = $form->round_amount($netamount * $form->{exchangerate}, 2);
    $paiddiff  = $amount - $netamount * $form->{exchangerate};
    $netamount = $amount;

    foreach $item (split / /, $form->{taxaccounts}) {
      $amount                               = $form->{amount}{ $form->{id} }{$item} * $form->{exchangerate};
      $form->{amount}{ $form->{id} }{$item} = $form->round_amount($amount, 2);

      $amount     = $form->{amount}{ $form->{id} }{$item} * -1;
      $tax       += $amount;
      $netamount -= $amount;
    }

    $invoicediff += $paiddiff;
    $expensediff += $paiddiff;

######## this only applies to tax included

    # in the sales invoice case rounding errors only have to be corrected for
    # income accounts, it is enough to add the total rounding error to one of
    # the income accounts, with the one assigned to the last row being used
    # (lastinventoryaccno)

    # in the purchase invoice case rounding errors may be split between
    # inventory accounts and expense accounts. After rounding, an error of 1
    # cent is introduced if the total rounding error exceeds 0.005. The total
    # error is made up of $invoicediff and $expensediff, however, so if both
    # values are below 0.005, but add up to a total >= 0.005, correcting
    # lastinventoryaccno and lastexpenseaccno separately has no effect after
    # rounding. This caused bug 1579. Therefore when the combined total exceeds
    # 0.005, but neither do individually, the account with the larger value
    # shall receive the total rounding error, and the next time it is rounded
    # the 1 cent correction will be introduced.

    $form->{amount}{ $form->{id} }{$lastinventoryaccno} -= $invoicediff if $lastinventoryaccno;
    $form->{amount}{ $form->{id} }{$lastexpenseaccno}   -= $expensediff if $lastexpenseaccno;

    if ( (abs($expensediff)+abs($invoicediff)) >= 0.005 and abs($expensediff) < 0.005 and abs($invoicediff) < 0.005 ) {

      # in total the rounding error adds up to 1 cent effectively, correct the
      # larger of the two numbers

      if ( abs($form->{amount}{ $form->{id} }{$lastinventoryaccno}) > abs($form->{amount}{ $form->{id} }{$lastexpenseaccno}) ) {
        # $invoicediff has already been deducted, now also deduct expensediff
        $form->{amount}{ $form->{id} }{$lastinventoryaccno}   -= $expensediff;
      } else {
        # expensediff has already been deducted, now also deduct invoicediff
        $form->{amount}{ $form->{id} }{$lastexpenseaccno}   -= $invoicediff;
      };
    };

  } else {
    $amount    = $form->round_amount($netamount * $form->{exchangerate}, 2);
    $paiddiff  = $amount - $netamount * $form->{exchangerate};
    $netamount = $amount;

    foreach my $item (split / /, $form->{taxaccounts}) {
      $form->{amount}{ $form->{id} }{$item}  = $form->round_amount($form->{amount}{ $form->{id} }{$item}, 2);
      $amount                                = $form->round_amount( $form->{amount}{ $form->{id} }{$item} * $form->{exchangerate} * -1, 2);
      $paiddiff                             += $amount - $form->{amount}{ $form->{id} }{$item} * $form->{exchangerate} * -1;
      $form->{amount}{ $form->{id} }{$item}  = $form->round_amount($amount * -1, 2);
      $amount                                = $form->{amount}{ $form->{id} }{$item} * -1;
      $tax                                  += $amount;
    }
  }

  $form->{amount}{ $form->{id} }{ $form->{AP} } = $netamount + $tax;


  $form->{paid} = $form->round_amount($form->{paid} * $form->{exchangerate} + $paiddiff, 2) if $form->{paid} != 0;

# update exchangerate

  $form->update_exchangerate($dbh, $form->{currency}, $form->{invdate}, 0, $form->{exchangerate})
    if ($form->{currency} ne $defaultcurrency) && !$exchangerate;

# record acc_trans transactions
  foreach my $trans_id (keys %{ $form->{amount} }) {
    foreach my $accno (keys %{ $form->{amount}{$trans_id} }) {
      $form->{amount}{$trans_id}{$accno} = $form->round_amount($form->{amount}{$trans_id}{$accno}, 2);


      next if $payments_only || !$form->{amount}{$trans_id}{$accno};

      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, taxkey, project_id, tax_id, chart_link)
                  VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?,
                  (SELECT taxkey_id
                   FROM taxkeys
                   WHERE chart_id= (SELECT id
                                    FROM chart
                                    WHERE accno = ?)
                   AND startdate <= ?
                   ORDER BY startdate DESC LIMIT 1),
                  ?,
                  (SELECT tax_id
                   FROM taxkeys
                   WHERE chart_id= (SELECT id
                                    FROM chart
                                    WHERE accno = ?)
                   AND startdate <= ?
                   ORDER BY startdate DESC LIMIT 1),
                  (SELECT link FROM chart WHERE accno = ?))|;
      @values = ($trans_id, $accno, $form->{amount}{$trans_id}{$accno},
                 conv_date($form->{invdate}), $accno, conv_date($form->{invdate}), $project_id, $accno, conv_date($form->{invdate}), $accno);
      do_query($form, $dbh, $query, @values);
    }
  }

  # deduct payment differences from paiddiff
  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"} != 0) {
      $amount    = $form->round_amount($form->{"paid_$i"} * $form->{exchangerate}, 2);
      $paiddiff -= $amount - $form->{"paid_$i"} * $form->{exchangerate};
    }
  }

  # force AP entry if 0

  $form->{amount}{ $form->{id} }{ $form->{AP} } = $form->{paid} if $form->{amount}{$form->{id}}{$form->{AP}} == 0;

  my %already_cleared = %{ $params{already_cleared} // {} };

  # record payments and offsetting AP
  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->{"acc_trans_id_$i"}
        && $payments_only
        && (SL::DB::Default->get->payments_changeable == 0)) {
      next;
    }

    next if $form->{"paid_$i"} == 0;

    my ($accno)            = split /--/, $form->{"AP_paid_$i"};
    $form->{"datepaid_$i"} = $form->{invdate} unless ($form->{"datepaid_$i"});
    $form->{datepaid}      = $form->{"datepaid_$i"};

    $amount = $form->round_amount($form->{"paid_$i"} * $form->{exchangerate} + $paiddiff, 2) * -1;

    my $new_cleared = !$form->{"acc_trans_id_$i"}                                                  ? 'f'
                    : !$already_cleared{$form->{"acc_trans_id_$i"}}                                ? 'f'
                    : $already_cleared{$form->{"acc_trans_id_$i"}}->{amount} != $form->{"paid_$i"} ? 'f'
                    : $already_cleared{$form->{"acc_trans_id_$i"}}->{accno}  != $accno             ? 'f'
                    : $already_cleared{$form->{"acc_trans_id_$i"}}->{cleared}                      ? 't'
                    :                                                                                'f';

    # record AP
    if ($form->{amount}{ $form->{id} }{ $form->{AP} } != 0) {
      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, taxkey, project_id, cleared, tax_id, chart_link)
                  VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?,
                          (SELECT taxkey_id
                           FROM taxkeys
                           WHERE chart_id= (SELECT id
                                            FROM chart
                                            WHERE accno = ?)
                           AND startdate <= ?
                           ORDER BY startdate DESC LIMIT 1),
                          ?, ?,
                          (SELECT tax_id
                           FROM taxkeys
                           WHERE chart_id= (SELECT id
                                            FROM chart
                                            WHERE accno = ?)
                           AND startdate <= ?
                           ORDER BY startdate DESC LIMIT 1),
                          (SELECT link FROM chart WHERE accno = ?))|;
      @values = (conv_i($form->{id}), $form->{AP}, $amount,
                 $form->{"datepaid_$i"}, $form->{AP}, conv_date($form->{"datepaid_$i"}), $project_id, $new_cleared, $form->{AP}, conv_date($form->{"datepaid_$i"}), $form->{AP});
      do_query($form, $dbh, $query, @values);
    }

    # record payment
    my $gldate = (conv_date($form->{"gldate_$i"}))? conv_date($form->{"gldate_$i"}) : conv_date($form->current_date($myconfig));

    $query =
      qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, gldate, source, memo, taxkey, project_id, cleared, tax_id, chart_link)
                VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, ?, ?, ?,
                (SELECT taxkey_id
                 FROM taxkeys
                 WHERE chart_id= (SELECT id
                                  FROM chart WHERE accno = ?)
                 AND startdate <= ?
                 ORDER BY startdate DESC LIMIT 1),
                ?, ?,
                (SELECT tax_id
                 FROM taxkeys
                 WHERE chart_id= (SELECT id
                                  FROM chart WHERE accno = ?)
                 AND startdate <= ?
                 ORDER BY startdate DESC LIMIT 1),
                (SELECT link FROM chart WHERE accno = ?))|;
    @values = (conv_i($form->{id}), $accno, $form->{"paid_$i"}, $form->{"datepaid_$i"},
               $gldate, $form->{"source_$i"}, $form->{"memo_$i"}, $accno, conv_date($form->{"datepaid_$i"}), $project_id, $new_cleared, $accno, conv_date($form->{"datepaid_$i"}), $accno);
    do_query($form, $dbh, $query, @values);

    $exchangerate = 0;

    if ($form->{currency} eq $defaultcurrency) {
      $form->{"exchangerate_$i"} = 1;
    } else {
      $exchangerate              = $form->check_exchangerate($myconfig, $form->{currency}, $form->{"datepaid_$i"}, 'sell');
      $form->{"exchangerate_$i"} = $exchangerate || $form->parse_amount($myconfig, $form->{"exchangerate_$i"});
    }

    # exchangerate difference
    $form->{fx}{$accno}{ $form->{"datepaid_$i"} } += $form->{"paid_$i"} * ($form->{"exchangerate_$i"} - 1) + $paiddiff;

    # gain/loss
    $amount =
      ($form->{"paid_$i"} * $form->{exchangerate}) -
      ($form->{"paid_$i"} * $form->{"exchangerate_$i"});
    if ($amount > 0) {
      $form->{fx}{ $form->{fxgain_accno} }{ $form->{"datepaid_$i"} } += $amount;
    } else {
      $form->{fx}{ $form->{fxloss_accno} }{ $form->{"datepaid_$i"} } += $amount;
    }

    $paiddiff = 0;

    # update exchange rate
    $form->update_exchangerate($dbh, $form->{currency}, $form->{"datepaid_$i"}, 0, $form->{"exchangerate_$i"})
      if ($form->{currency} ne $defaultcurrency) && !$exchangerate;
  }

  # record exchange rate differences and gains/losses
  foreach my $accno (keys %{ $form->{fx} }) {
    foreach my $transdate (keys %{ $form->{fx}{$accno} }) {
      $form->{fx}{$accno}{$transdate} = $form->round_amount($form->{fx}{$accno}{$transdate}, 2);
      next if ($form->{fx}{$accno}{$transdate} == 0);

      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, cleared, fx_transaction, taxkey, project_id, tax_id, chart_link)
                  VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, '0', '1', 0, ?,
                  (SELECT id FROM tax WHERE taxkey=0 LIMIT 1),
                  (SELECT link FROM chart WHERE accno = ?))|;
      @values = (conv_i($form->{id}), $accno, $form->{fx}{$accno}{$transdate}, conv_date($transdate), $project_id, $accno);
      do_query($form, $dbh, $query, @values);
    }
  }

  IO->set_datepaid(table => 'ap', id => $form->{id}, dbh => $dbh);

  if ($payments_only) {
    $query = qq|UPDATE ap SET paid = ? WHERE id = ?|;
    do_query($form, $dbh, $query, $form->{paid}, conv_i($form->{id}));
    $form->new_lastmtime('ap');

    return;
  }

  $amount = $netamount + $tax;

  # set values which could be empty
  my $taxzone_id         = $form->{taxzone_id} * 1;
  $taxzone_id = SL::DB::Manager::TaxZone->get_default->id unless SL::DB::Manager::TaxZone->find_by(id => $taxzone_id);

  $form->{invnumber}     = $form->{id} unless $form->{invnumber};

  # save AP record
  $query = qq|UPDATE ap SET
                invnumber    = ?, ordnumber   = ?, quonumber     = ?, transdate   = ?,
                orddate      = ?, quodate     = ?, vendor_id     = ?, amount      = ?,
                netamount    = ?, paid        = ?, duedate       = ?,
                invoice      = ?, taxzone_id  = ?, notes         = ?, taxincluded = ?,
                intnotes     = ?, storno_id   = ?, storno        = ?,
                cp_id        = ?, employee_id = ?, department_id = ?, delivery_term_id = ?,
                currency_id = (SELECT id FROM currencies WHERE name = ?),
                globalproject_id = ?, direct_debit = ?
              WHERE id = ?|;
  @values = (
                $form->{invnumber},          $form->{ordnumber},           $form->{quonumber},      conv_date($form->{invdate}),
      conv_date($form->{orddate}), conv_date($form->{quodate}),     conv_i($form->{vendor_id}),               $amount,
                $netamount,                  $form->{paid},      conv_date($form->{duedate}),
            '1',                             $taxzone_id, $restricter->process($form->{notes}),               $form->{taxincluded} ? 't' : 'f',
                $form->{intnotes},           conv_i($form->{storno_id}),     $form->{storno}      ? 't' : 'f',
         conv_i($form->{cp_id}),      conv_i($form->{employee_id}), conv_i($form->{department_id}), conv_i($form->{delivery_term_id}),
                $form->{"currency"},
         conv_i($form->{globalproject_id}),
                $form->{direct_debit} ? 't' : 'f',
         conv_i($form->{id})
  );
  do_query($form, $dbh, $query, @values);

  if ($form->{storno}) {
    $query = qq|UPDATE ap SET paid = paid + amount WHERE id = ?|;
    do_query($form, $dbh, $query, conv_i($form->{storno_id}));

    $query = qq|UPDATE ap SET storno = 't' WHERE id = ?|;
    do_query($form, $dbh, $query, conv_i($form->{storno_id}));

    $query = qq!UPDATE ap SET intnotes = ? || intnotes WHERE id = ?!;
    do_query($form, $dbh, $query, "Rechnung storniert am $form->{invdate} ", conv_i($form->{storno_id}));

    $query = qq|UPDATE ap SET paid = amount WHERE id = ?|;
    do_query($form, $dbh, $query, conv_i($form->{id}));
  }

  $form->new_lastmtime('ap');

  $form->{name} = $form->{vendor};
  $form->{name} =~ s/--\Q$form->{vendor_id}\E//;

  # add shipto
  $form->add_shipto($dbh, $form->{id}, "AP");

  # delete zero entries
  do_query($form, $dbh, qq|DELETE FROM acc_trans WHERE amount = 0|);

  Common::webdav_folder($form);

  # Link this record to the records it was created from order or invoice (storno)
  foreach (qw(oe ap)) {
    if ($form->{"convert_from_${_}_ids"}) {
      RecordLinks->create_links('dbh'        => $dbh,
                                'mode'       => 'ids',
                                'from_table' => $_,
                                'from_ids'   => $form->{"convert_from_${_}_ids"},
                                'to_table'   => 'ap',
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
                              'to_table'   => 'ap',
                              'to_id'      => $form->{id},
      );
  }
  delete $form->{convert_from_do_ids};

  ARAP->close_orders_if_billed('dbh'     => $dbh,
                               'arap_id' => $form->{id},
                               'table'   => 'ap',);

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
  if ($::instance_conf->get_datev_check_on_purchase_invoice) {

    my $datev = SL::DATEV->new(
      dbh        => $dbh,
      trans_id   => $form->{id},
    );

    $datev->generate_datev_data;

    if ($datev->errors) {
      die join "\n", $::locale->text('DATEV check returned errors:'), $datev->errors;
    }
  }

  return 1;
}

sub reverse_invoice {
  $main::lxdebug->enter_sub();

  my ($dbh, $form) = @_;

  # reverse inventory items
  my $query =
    qq|SELECT i.parts_id, p.part_type, i.qty, i.allocated, i.sellprice
       FROM invoice i, parts p
       WHERE (i.parts_id = p.id)
         AND (i.trans_id = ?)|;
  my $sth = prepare_execute_query($form, $dbh, $query, conv_i($form->{id}));

  my $netamount = 0;

  while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
    $netamount += $form->round_amount($ref->{sellprice} * $ref->{qty} * -1, 2);

    next unless $ref->{part_type} eq 'part';

    # if $ref->{allocated} > 0 than we sold that many items
    next if ($ref->{allocated} <= 0);

    # get references for sold items
    $query =
      qq|SELECT i.id, i.trans_id, i.allocated, a.transdate
         FROM invoice i, ar a
         WHERE (i.parts_id = ?)
           AND (i.allocated < 0)
           AND (i.trans_id = a.id)
         ORDER BY transdate DESC|;
      my $sth2 = prepare_execute_query($form, $dbh, $query, $ref->{parts_id});

      while (my $pthref = $sth2->fetchrow_hashref("NAME_lc")) {
        my $qty = $ref->{allocated};
        if (($ref->{allocated} + $pthref->{allocated}) > 0) {
          $qty = $pthref->{allocated} * -1;
        }

        my $amount = $form->round_amount($ref->{sellprice} * $qty, 2);

        #adjust allocated
        $form->update_balance($dbh, "invoice", "allocated", qq|id = $pthref->{id}|, $qty);

        if  ( $::instance_conf->get_inventory_system eq 'perpetual' ) {

          $form->update_balance($dbh, "acc_trans", "amount",
                                qq|    (trans_id = $pthref->{trans_id})
                                   AND (chart_id = $ref->{expense_accno_id})
                                   AND (transdate = '$pthref->{transdate}')|,
                                $amount);

          $form->update_balance($dbh, "acc_trans", "amount",
                                qq|    (trans_id = $pthref->{trans_id})
                                   AND (chart_id = $ref->{inventory_accno_id})
                                   AND (transdate = '$pthref->{transdate}')|,
                                $amount * -1);
        }

        last if (($ref->{allocated} -= $qty) <= 0);
      }
    $sth2->finish();
  }
  $sth->finish();

  my $id = conv_i($form->{id});

  # delete acc_trans
  $query = qq|DELETE FROM acc_trans WHERE trans_id = ?|;
  do_query($form, $dbh, $query, $id);

  $query = qq|DELETE FROM shipto WHERE (trans_id = ?) AND (module = 'AP')|;
  do_query($form, $dbh, $query, $id);

  $main::lxdebug->leave_sub();
}

sub delete_invoice {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;
  my $query;
  # connect to database
  my $dbh = SL::DB->client->dbh;

  SL::DB->client->with_transaction(sub{

    &reverse_invoice($dbh, $form);

    my @values = (conv_i($form->{id}));

    # delete zero entries
    # wtf? use case for this?
    $query = qq|DELETE FROM acc_trans WHERE amount = 0|;
    do_query($form, $dbh, $query);


    my @queries = (
      qq|DELETE FROM invoice WHERE trans_id = ?|,
      qq|DELETE FROM ap WHERE id = ?|,
    );

    map { do_query($form, $dbh, $_, @values) } @queries;
    1;
  }) or do { die SL::DB->client->error };

  return 1;
}

sub retrieve_invoice {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = SL::DB->client->dbh;

  my ($query, $sth, $ref, $q_invdate);

  if (!$form->{id}) {
    $q_invdate = qq|, COALESCE((SELECT transdate FROM ar WHERE id = (SELECT MAX(id) FROM ar)), current_date) AS invdate|;
    if ($form->{vendor_id}) {
      my $vendor_id = $dbh->quote($form->{vendor_id} * 1);
      $q_invdate .=
        qq|, COALESCE((SELECT transdate FROM ar WHERE id = (SELECT MAX(id) FROM ar)), current_date) +
             COALESCE((SELECT pt.terms_netto
                       FROM vendor v
                       LEFT JOIN payment_terms pt ON (v.payment_id = pt.id)
                       WHERE v.id = $vendor_id),
                      0) AS duedate|;
    }
  }

  # get default accounts and last invoice number

  $query = qq|SELECT
               (SELECT c.accno FROM chart c WHERE d.inventory_accno_id = c.id) AS inventory_accno,
               (SELECT c.accno FROM chart c WHERE d.income_accno_id = c.id)    AS income_accno,
               (SELECT c.accno FROM chart c WHERE d.expense_accno_id = c.id)   AS expense_accno,
               (SELECT c.accno FROM chart c WHERE d.fxgain_accno_id = c.id)    AS fxgain_accno,
               (SELECT c.accno FROM chart c WHERE d.fxloss_accno_id = c.id)    AS fxloss_accno
               $q_invdate
               FROM defaults d|;
  $ref = selectfirst_hashref_query($form, $dbh, $query);
  map { $form->{$_} = $ref->{$_} } keys %$ref;

  if (!$form->{id}) {
    $main::lxdebug->leave_sub();

    return;
  }

  # retrieve invoice
  $query = qq|SELECT cp_id, invnumber, transdate AS invdate, duedate,
                orddate, quodate, globalproject_id,
                ordnumber, quonumber, paid, taxincluded, notes, taxzone_id, storno, gldate,
                mtime, itime,
                intnotes, (SELECT cu.name FROM currencies cu WHERE cu.id=ap.currency_id) AS currency, direct_debit,
                delivery_term_id
              FROM ap
              WHERE id = ?|;
  $ref = selectfirst_hashref_query($form, $dbh, $query, conv_i($form->{id}));
  map { $form->{$_} = $ref->{$_} } keys %$ref;
  $form->{mtime} = $form->{itime} if !$form->{mtime};
  $form->{lastmtime} = $form->{mtime};

  $form->{exchangerate}  = $form->get_exchangerate($dbh, $form->{currency}, $form->{invdate}, "sell");

  # get shipto
  $query = qq|SELECT * FROM shipto WHERE (trans_id = ?) AND (module = 'AP')|;
  $ref = selectfirst_hashref_query($form, $dbh, $query, conv_i($form->{id}));
  delete $ref->{id};
  map { $form->{$_} = $ref->{$_} } keys %$ref;

  my $transdate  = $form->{invdate} ? $dbh->quote($form->{invdate}) : "current_date";

  my $taxzone_id = $form->{taxzone_id} * 1;
  $taxzone_id = SL::DB::Manager::TaxZone->get_default->id unless SL::DB::Manager::TaxZone->find_by(id => $taxzone_id);

  # retrieve individual items
  $query =
    qq|SELECT
        c1.accno AS inventory_accno, c1.new_chart_id AS inventory_new_chart, date($transdate) - c1.valid_from AS inventory_valid,
        c2.accno AS income_accno,    c2.new_chart_id AS income_new_chart,    date($transdate) - c2.valid_from AS income_valid,
        c3.accno AS expense_accno,   c3.new_chart_id AS expense_new_chart,   date($transdate) - c3.valid_from AS expense_valid,

        i.id AS invoice_id,
        i.description, i.longdescription, i.qty, i.fxsellprice AS sellprice, i.parts_id AS id, i.unit, i.deliverydate, i.project_id, i.serialnumber,
        i.price_factor_id, i.price_factor, i.marge_price_factor, i.discount, i.active_price_source, i.active_discount_source,
        p.partnumber, p.part_type, pr.projectnumber, pg.partsgroup
        ,p.classification_id

        FROM invoice i
        JOIN parts p ON (i.parts_id = p.id)
        LEFT JOIN chart c1 ON ((SELECT inventory_accno_id             FROM buchungsgruppen WHERE id = p.buchungsgruppen_id) = c1.id)
        LEFT JOIN chart c2 ON ((SELECT tc.income_accno_id FROM taxzone_charts tc where tc.taxzone_id = '$taxzone_id' and tc.buchungsgruppen_id = p.buchungsgruppen_id) = c2.id)
        LEFT JOIN chart c3 ON ((SELECT tc.expense_accno_id FROM taxzone_charts tc where tc.taxzone_id = '$taxzone_id' and tc.buchungsgruppen_id = p.buchungsgruppen_id) = c3.id)
        LEFT JOIN project pr    ON (i.project_id = pr.id)
        LEFT JOIN partsgroup pg ON (pg.id = p.partsgroup_id)

        WHERE i.trans_id = ?

        ORDER BY i.position|;
  $sth = prepare_execute_query($form, $dbh, $query, conv_i($form->{id}));

  while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
    # Retrieve custom variables.
    my $cvars = CVar->get_custom_variables(dbh        => $dbh,
                                           module     => 'IC',
                                           sub_module => 'invoice',
                                           trans_id   => $ref->{invoice_id},
                                          );
    map { $ref->{"ic_cvar_$_->{name}"} = $_->{value} } @{ $cvars };

    map({ delete($ref->{$_}); } qw(inventory_accno inventory_new_chart inventory_valid)) if !$ref->{"part_type"} eq 'part';

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
         WHERE t.id in
           (SELECT tk.tax_id FROM taxkeys tk
            WHERE tk.chart_id = (SELECT id FROM chart WHERE accno = ?)
              AND (startdate <= $transdate)
            ORDER BY startdate DESC
            LIMIT 1)
         ORDER BY c.accno|;
    my $stw = prepare_execute_query($form, $dbh, $query, $accno_id);
    $ref->{taxaccounts} = "";

    my $i = 0;
    while (my $ptr = $stw->fetchrow_hashref("NAME_lc")) {
      if (($ptr->{accno} eq "") && ($ptr->{rate} == 0)) {
        $i++;
        $ptr->{accno} = $i;
      }

      $ref->{taxaccounts} .= "$ptr->{accno} ";

      if (!($form->{taxaccounts} =~ /\Q$ptr->{accno}\E/)) {
        $form->{"$ptr->{accno}_rate"}         = $ptr->{rate};
        $form->{"$ptr->{accno}_description"}  = $ptr->{taxdescription};
        $form->{"$ptr->{accno}_taxnumber"}    = $ptr->{taxnumber};
        $form->{taxaccounts}                 .= "$ptr->{accno} ";
      }

    }

    chop $ref->{taxaccounts};
    push @{ $form->{invoice_details} }, $ref;
    $stw->finish();
  }
  $sth->finish();

  Common::webdav_folder($form);

  $main::lxdebug->leave_sub();
}

sub get_vendor {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $params) = @_;

  $params = $form unless defined $params && ref $params eq "HASH";

  # connect to database
  my $dbh = SL::DB->client->dbh;

  my $dateformat = $myconfig->{dateformat};
  $dateformat .= "yy" if $myconfig->{dateformat} !~ /^y/;

  my $vid = conv_i($params->{vendor_id});
  my $vnr = conv_i($params->{vendornumber});

  my $duedate =
    ($params->{invdate})
    ? "to_date(" . $dbh->quote($params->{invdate}) . ", '$dateformat')"
    : "current_date";

  # get vendor
  my @values = ();
  my $where = '';
  if ($vid) {
    $where .= 'AND v.id = ?';
    push @values, $vid;
  }
  if ($vnr) {
    $where .= 'AND v.vendornumber = ?';
    push @values, $vnr;
  }
  my $query =
    qq|SELECT
         v.id AS vendor_id, v.name AS vendor, v.discount as vendor_discount,
         v.creditlimit, v.notes AS intnotes,
         v.email, v.cc, v.bcc, v.language_id, v.payment_id, v.delivery_term_id,
         v.street, v.zipcode, v.city, v.country, v.taxzone_id, cu.name AS curr, v.direct_debit,
         $duedate + COALESCE(pt.terms_netto, 0) AS duedate,
         b.discount AS tradediscount, b.description AS business
       FROM vendor v
       LEFT JOIN business b       ON (b.id = v.business_id)
       LEFT JOIN payment_terms pt ON (v.payment_id = pt.id)
       LEFT JOIN currencies cu    ON (v.currency_id = cu.id)
       WHERE 1=1 $where|;
  my $ref = selectfirst_hashref_query($form, $dbh, $query, @values);
  map { $params->{$_} = $ref->{$_} } keys %$ref;

  # use vendor currency
  $form->{currency} = $form->{curr};

  $params->{creditremaining} = $params->{creditlimit};

  $query = qq|SELECT SUM(amount - paid) FROM ap WHERE vendor_id = ?|;
  my ($unpaid_invoices) = selectfirst_array_query($form, $dbh, $query, $vid);
  $params->{creditremaining} -= $unpaid_invoices;

  $query = qq|SELECT o.amount,
                (SELECT e.sell
                 FROM exchangerate e
                 WHERE (e.currency_id = o.currency_id)
                   AND (e.transdate = o.transdate)) AS exch
              FROM oe o
              WHERE (o.vendor_id = ?) AND (o.quotation = '0') AND (o.closed = '0')|;
  my $sth = prepare_execute_query($form, $dbh, $query, $vid);
  while (my ($amount, $exch) = $sth->fetchrow_array()) {
    $exch = 1 unless $exch;
    $params->{creditremaining} -= $amount * $exch;
  }
  $sth->finish();

  $main::lxdebug->leave_sub();
}

sub retrieve_item {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh = SL::DB->client->dbh;

  my $i = $form->{rowcount};

  # don't include assemblies or obsolete parts
  my $where = "NOT p.part_type = 'assembly' AND NOT p.obsolete = '1'";
  my @values;

  foreach my $table_column (qw(p.partnumber p.description pg.partsgroup)) {
    my $field = (split m{\.}, $table_column)[1];
    next unless $form->{"${field}_${i}"};
    $where .= " AND lower(${table_column}) LIKE lower(?)";
    push @values, like($form->{"${field}_${i}"});
  }

  my (%mm_by_id);
  if ($form->{"partnumber_$i"} && !$form->{"description_$i"}) {
    $where .= qq| OR (NOT p.obsolete = '1' AND p.ean = ? )|;
    push @values, $form->{"partnumber_$i"};

    # also search hits in makemodels, but only cache the results by id and merge later
    my $mm_query = qq|
      SELECT parts_id, model FROM makemodel
      LEFT JOIN parts ON parts.id = parts_id
      WHERE NOT parts.obsolete AND model ILIKE ? AND (make IS NULL OR make = ?);
    |;
    my $mm_results = selectall_hashref_query($::form, $dbh, $mm_query, like($form->{"partnumber_$i"}), $::form->{vendor_id});
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
    $where .= " ORDER BY p.description";
  } else {
    $where .= " ORDER BY p.partnumber";
  }

  my $transdate = "";
  if ($form->{type} eq "invoice") {
    $transdate = $form->{deliverydate} ? $dbh->quote($form->{deliverydate})
               : $form->{invdate} ? $dbh->quote($form->{invdate})
               : "current_date";
  } else {
    $transdate = $form->{transdate} ? $dbh->quote($form->{transdate}) : "current_date";
  }

  my $taxzone_id = $form->{taxzone_id} * 1;
  $taxzone_id = SL::DB::Manager::TaxZone->get_default->id unless SL::DB::Manager::TaxZone->find_by(id => $taxzone_id);

  my $query =
    qq|SELECT
         p.id, p.partnumber, p.description, p.lastcost AS sellprice, p.listprice,
         p.unit, p.part_type, p.onhand, p.formel,
         p.notes AS partnotes, p.notes AS longdescription, p.not_discountable,
         p.price_factor_id,
         p.ean,
         p.classification_id,

         pfac.factor AS price_factor,

         c1.accno                         AS inventory_accno,
         c1.new_chart_id                  AS inventory_new_chart,
         date($transdate) - c1.valid_from AS inventory_valid,

         c2.accno                         AS income_accno,
         c2.new_chart_id                  AS income_new_chart,
         date($transdate) - c2.valid_from AS income_valid,

         c3.accno                         AS expense_accno,
         c3.new_chart_id                  AS expense_new_chart,
         date($transdate) - c3.valid_from AS expense_valid,

         pt.used_for_purchase AS used_for_purchase,
         pg.partsgroup

       FROM parts p
       LEFT JOIN chart c1 ON
         ((SELECT inventory_accno_id
           FROM buchungsgruppen
           WHERE id = p.buchungsgruppen_id) = c1.id)
       LEFT JOIN chart c2 ON
         ((SELECT tc.income_accno_id
           FROM taxzone_charts tc
           WHERE tc.taxzone_id = '$taxzone_id' and tc.buchungsgruppen_id = p.buchungsgruppen_id) = c2.id)
       LEFT JOIN chart c3 ON
         ((SELECT tc.expense_accno_id
           FROM taxzone_charts tc
           WHERE tc.taxzone_id = '$taxzone_id' and tc.buchungsgruppen_id = p.buchungsgruppen_id) = c3.id)
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

  $form->{item_list} = [];
  my $has_wrong_pclass = PCLASS_OK;
  while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {

    if ($mm_by_id{$ref->{id}}) {
      $ref->{makemodels} = $mm_by_id{$ref->{id}};
      push @{ $ref->{matches} ||= [] }, $::locale->text('Model') . ': ' . join ', ', map { $_->{model} } @{ $mm_by_id{$ref->{id}} };
    }

    if (($::form->{"partnumber_$i"} ne '') && ($ref->{ean} eq $::form->{"partnumber_$i"})) {
      push @{ $ref->{matches} ||= [] }, $::locale->text('EAN') . ': ' . $ref->{ean};
    }
    $ref->{type_and_classific} = type_abbreviation($ref->{part_type}) .
                                 classification_abbreviation($ref->{classification_id});

    if (! $ref->{used_for_purchase} ) {
       $has_wrong_pclass = PCLASS_NOTFORPURCHASE;
       next;
    }
    # In der Buchungsgruppe ist immer ein Bestandskonto verknuepft, auch wenn
    # es sich um eine Dienstleistung handelt. Bei Dienstleistungen muss das
    # Buchungskonto also aus dem Ergebnis rausgenommen werden.
    if (!$ref->{inventory_accno_id}) {
      map({ delete($ref->{"inventory_${_}"}); } qw(accno new_chart valid));
    }
    delete($ref->{inventory_accno_id});

    # get tax rates and description
    my $accno_id = ($form->{vc} eq "customer") ? $ref->{income_accno} : $ref->{expense_accno};
    $query =
      qq|SELECT c.accno, t.taxdescription, t.rate, t.taxnumber
         FROM tax t
         LEFT JOIN chart c on (c.id = t.chart_id)
         WHERE t.id IN
           (SELECT tk.tax_id
            FROM taxkeys tk
            WHERE tk.chart_id =
              (SELECT id
               FROM chart
               WHERE accno = ?)
              AND (startdate <= $transdate)
            ORDER BY startdate DESC
            LIMIT 1)
         ORDER BY c.accno|;
    my $stw = prepare_execute_query($form, $dbh, $query, $accno_id);

    $ref->{taxaccounts} = "";
    my $i = 0;
    while (my $ptr = $stw->fetchrow_hashref("NAME_lc")) {

      if (($ptr->{accno} eq "") && ($ptr->{rate} == 0)) {
        $i++;
        $ptr->{accno} = $i;
      }

      $ref->{taxaccounts} .= "$ptr->{accno} ";

      if (!($form->{taxaccounts} =~ /\Q$ptr->{accno}\E/)) {
        $form->{"$ptr->{accno}_rate"}         = $ptr->{rate};
        $form->{"$ptr->{accno}_description"}  = $ptr->{taxdescription};
        $form->{"$ptr->{accno}_taxnumber"}    = $ptr->{taxnumber};
        $form->{taxaccounts}                 .= "$ptr->{accno} ";
      }

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
    }

    $stw->finish();
    chop $ref->{taxaccounts};

    $ref->{onhand} *= 1;
    push @{ $form->{item_list} }, $ref;

  }

  $sth->finish();
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

sub vendor_details {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, @wanted_vars) = @_;

  my $dbh = SL::DB->client->dbh;

  my @values;

  # get contact id, set it if nessessary
  $form->{cp_id} *= 1;
  my $contact = "";
  if ($form->{cp_id}) {
    $contact = "AND cp.cp_id = ?";
    push @values, $form->{cp_id};
  }

  # get rest for the vendor
  # fax and phone and email as vendor*
  my $query =
    qq|SELECT ct.*, cp.*, ct.notes as vendornotes, phone as vendorphone, fax as vendorfax, email as vendoremail,
         cu.name AS currency
       FROM vendor ct
       LEFT JOIN contacts cp ON (ct.id = cp.cp_cv_id)
       LEFT JOIN currencies cu ON (ct.currency_id = cu.id)
       WHERE (ct.id = ?) $contact
       ORDER BY cp.cp_id
       LIMIT 1|;
  my $ref = selectfirst_hashref_query($form, $dbh, $query, $form->{vendor_id}, @values);

  # remove id,notes (double of vendornotes) and taxincluded before copy back
  delete @$ref{qw(id taxincluded notes)};

  @wanted_vars = grep({ $_ } @wanted_vars);
  if (scalar(@wanted_vars) > 0) {
    my %h_wanted_vars;
    map({ $h_wanted_vars{$_} = 1; } @wanted_vars);
    map({ delete($ref->{$_}) unless ($h_wanted_vars{$_}); } keys(%{$ref}));
  }

  map { $form->{$_} = $ref->{$_} } keys %$ref;

  my $custom_variables = CVar->get_custom_variables('dbh'      => $dbh,
                                                    'module'   => 'CT',
                                                    'trans_id' => $form->{vendor_id});
  map { $form->{"vc_cvar_$_->{name}"} = $_->{value} } @{ $custom_variables };

  if ($form->{cp_id}) {
    $custom_variables = CVar->get_custom_variables(dbh      => $dbh,
                                                   module   => 'Contacts',
                                                   trans_id => $form->{cp_id});
    $form->{"cp_cvar_$_->{name}"} = $_->{value} for @{ $custom_variables };
  }

  $form->{cp_greeting} = GenericTranslations->get('dbh'              => $dbh,
                                                  'translation_type' => 'greetings::' . ($form->{cp_gender} eq 'f' ? 'female' : 'male'),
                                                  'allow_fallback'   => 1);

  $main::lxdebug->leave_sub();
}

sub item_links {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh = SL::DB->client->dbh;

  my $query =
    qq|SELECT accno, description, link
       FROM chart
       WHERE link LIKE '%IC%'
       ORDER BY accno|;
  my $sth = prepare_execute_query($query, $dbh, $query);

  while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
    foreach my $key (split(/:/, $ref->{link})) {
      if ($key =~ /IC/) {
        push @{ $form->{IC_links}{$key} },
          { accno       => $ref->{accno},
            description => $ref->{description} };
      }
    }
  }

  $sth->finish();
  $main::lxdebug->leave_sub();
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
       WHERE (trans_id = ?) AND (c.link LIKE '%AP_paid%')|;
  push @delete_acc_trans_ids, selectall_array_query($form, $dbh, $query, conv_i($form->{id}), conv_i($form->{id}));

  $query =
    qq|SELECT at.acc_trans_id
       FROM acc_trans at
       LEFT JOIN chart c ON (at.chart_id = c.id)
       WHERE (trans_id = ?)
         AND ((c.link = 'AP') OR (c.link LIKE '%:AP') OR (c.link LIKE 'AP:%'))
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
  map { $payments{$_} = $form->{$_} } grep m/^datepaid_\d+$|^gldate_\d+$|^acc_trans_id_\d+$|^memo_\d+$|^source_\d+$|^exchangerate_\d+$|^paid_\d+$|^AP_paid_\d+$|^paidaccounts$/, keys %{ $form };

  # Clean up $form so that old content won't tamper the results.
  %keep_vars = map { $_, 1 } qw(login password id);
  map { delete $form->{$_} unless $keep_vars{$_} } keys %{ $form };

  # Retrieve the invoice from the database.
  $self->retrieve_invoice($myconfig, $form);

  # Set up the content of $form in the way that IR::post_invoice() expects.
  $form->{exchangerate} = $form->format_amount($myconfig, $form->{exchangerate});

  for $row (1 .. scalar @{ $form->{invoice_details} }) {
    $item = $form->{invoice_details}->[$row - 1];

    map { $item->{$_} = $form->format_amount($myconfig, $item->{$_}) } qw(qty sellprice);

    map { $form->{"${_}_${row}"} = $item->{$_} } keys %{ $item };
  }

  $form->{rowcount} = scalar @{ $form->{invoice_details} };

  delete @{$form}{qw(invoice_details paidaccounts storno paid)};

  # Restore the payment options from the user input.
  map { $form->{$_} = $payments{$_} } keys %payments;

  # Get the AP accno (which is normally done by Form::create_links()).
  $query =
    qq|SELECT c.accno
       FROM acc_trans at
       LEFT JOIN chart c ON (at.chart_id = c.id)
       WHERE (trans_id = ?)
         AND ((c.link = 'AP') OR (c.link LIKE '%:AP') OR (c.link LIKE 'AP:%'))
       ORDER BY at.acc_trans_id
       LIMIT 1|;

  ($form->{AP}) = selectfirst_array_query($form, $dbh, $query, conv_i($form->{id}));

  # Post the new payments.
  $self->post_invoice($myconfig, $form, $dbh, payments_only => 1, already_cleared => \%already_cleared);

  restore_form($old_form);

  return 1;
}

sub get_duedate {
  $::lxdebug->enter_sub;

  my ($self, %params) = @_;

  if (!$params{vendor_id} || !$params{invdate}) {
    $::lxdebug->leave_sub;
    return $params{default};
  }

  my $dbh      = $::form->get_standard_dbh;
  my $query    = qq|SELECT ?::date + pt.terms_netto
                    FROM vendor v
                    LEFT JOIN payment_terms pt ON (pt.id = v.payment_id)
                    WHERE v.id = ?|;

  my ($duedate) = selectfirst_array_query($::form, $dbh, $query, $params{invdate}, $params{vendor_id});

  $duedate ||= $params{default};

  $::lxdebug->leave_sub;

  return $duedate;
}

1;
