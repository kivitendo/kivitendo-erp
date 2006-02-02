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
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#======================================================================
#
# Inventory received module
#
#======================================================================

package IR;

sub post_invoice {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database, turn off autocommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  my ($query, $sth, $null, $project_id);
  my $exchangerate = 0;
  my $allocated;
  my $taxrate;
  my $taxamount;
  my $taxdiff;
  my $item;

  if ($form->{id}) {

    &reverse_invoice($dbh, $form);

  } else {
    my $uid = rand() . time;

    $uid .= $form->{login};

    $uid = substr($uid, 2, 75);

    $query = qq|INSERT INTO ap (invnumber, employee_id)
                VALUES ('$uid', (SELECT e.id FROM employee e
		                 WHERE e.login = '$form->{login}'))|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|SELECT a.id FROM ap a
                WHERE a.invnumber = '$uid'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{id}) = $sth->fetchrow_array;
    $sth->finish;
  }

  ($null, $form->{contact_id}) = split /--/, $form->{contact};
  $form->{contact_id} *= 1;

  map { $form->{$_} =~ s/\'/\'\'/g } qw(invnumber ordnumber quonumber);

  my ($amount, $linetotal, $lastinventoryaccno, $lastexpenseaccno);
  my ($netamount, $invoicediff, $expensediff) = (0, 0, 0);

  if ($form->{currency} eq $form->{defaultcurrency}) {
    $form->{exchangerate} = 1;
  } else {
    $exchangerate =
      $form->check_exchangerate($myconfig, $form->{currency},
                                $form->{transdate}, 'sell');
  }

  $form->{exchangerate} =
    ($exchangerate)
    ? $exchangerate
    : $form->parse_amount($myconfig, $form->{exchangerate});

  for my $i (1 .. $form->{rowcount}) {
    $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});

    if ($form->{"qty_$i"} != 0) {

      map { $form->{"${_}_$i"} =~ s/\'/\'\'/g }
        qw(partnumber description unit);

      @taxaccounts = split / /, $form->{"taxaccounts_$i"};
      $taxdiff     = 0;
      $allocated   = 0;
      $taxrate     = 0;

      $form->{"sellprice_$i"} =
        $form->parse_amount($myconfig, $form->{"sellprice_$i"});
      my $fxsellprice = $form->{"sellprice_$i"};

      my ($dec) = ($fxsellprice =~ /\.(\d+)/);
      $dec = length $dec;
      my $decimalplaces = ($dec > 2) ? $dec : 2;

      map { $taxrate += $form->{"${_}_rate"} } @taxaccounts;

      if ($form->{"inventory_accno_$i"}) {

        $linetotal =
          $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"}, 2);

        if ($form->{taxincluded}) {
          $taxamount = $linetotal * ($taxrate / (1 + $taxrate));
          $form->{"sellprice_$i"} =
            $form->{"sellprice_$i"} * (1 / (1 + $taxrate));
        } else {
          $taxamount = $linetotal * $taxrate;
        }

        $netamount += $linetotal;

        if ($form->round_amount($taxrate, 7) == 0) {
          if ($form->{taxincluded}) {
            foreach $item (@taxaccounts) {
              $taxamount =
                $form->round_amount($linetotal * $form->{"${item}_rate"} /
                                      (1 + abs($form->{"${item}_rate"})),
                                    2);
              $taxdiff += $taxamount;
              $form->{amount}{ $form->{id} }{$item} -= $taxamount;
            }
            $form->{amount}{ $form->{id} }{ $taxaccounts[0] } += $taxdiff;
          } else {
            map {
              $form->{amount}{ $form->{id} }{$_} -=
                $linetotal * $form->{"${_}_rate"}
            } @taxaccounts;
          }
        } else {
          map {
            $form->{amount}{ $form->{id} }{$_} -=
              $taxamount * $form->{"${_}_rate"} / $taxrate
          } @taxaccounts;
        }

        # add purchase to inventory, this one is without the tax!
        $amount =
          $form->{"sellprice_$i"} * $form->{"qty_$i"} * $form->{exchangerate};
        $linetotal =
          $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"}, 2) *
          $form->{exchangerate};
        $linetotal = $form->round_amount($linetotal, 2);

        # this is the difference for the inventory
        $invoicediff += ($amount - $linetotal);

        $form->{amount}{ $form->{id} }{ $form->{"inventory_accno_$i"} } -=
          $linetotal;

        # adjust and round sellprice
        $form->{"sellprice_$i"} =
          $form->round_amount($form->{"sellprice_$i"} * $form->{exchangerate},
                              $decimalplaces);

        # update parts table
        $query = qq|UPDATE parts SET
		    lastcost = $form->{"sellprice_$i"}
	            WHERE id = $form->{"id_$i"}|;

        $dbh->do($query) || $form->dberror($query);

        $form->update_balance($dbh, "parts", "onhand",
                              qq|id = $form->{"id_$i"}|,
                              $form->{"qty_$i"})
          unless $form->{shipped};

        # check if we sold the item already and
        # make an entry for the expense and inventory
        $query = qq|SELECT i.id, i.qty, i.allocated, i.trans_id,
		    p.inventory_accno_id, p.expense_accno_id, a.transdate
		    FROM invoice i, ar a, parts p
		    WHERE i.parts_id = p.id
	            AND i.parts_id = $form->{"id_$i"}
		    AND (i.qty + i.allocated) > 0
		    AND i.trans_id = a.id
		    ORDER BY transdate|;
        $sth = $dbh->prepare($query);
        $sth->execute || $form->dberror($query);

        my $totalqty = $form->{"qty_$i"};

        while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {

          my $qty = $ref->{qty} + $ref->{allocated};

          if (($qty - $totalqty) > 0) {
            $qty = $totalqty;
          }

          $linetotal = $form->round_amount($form->{"sellprice_$i"} * $qty, 2);

          if ($ref->{allocated} < 0) {

            # we have an entry for it already, adjust amount
            $form->update_balance(
              $dbh,
              "acc_trans",
              "amount",
              qq|trans_id = $ref->{trans_id} AND chart_id = $ref->{inventory_accno_id} AND transdate = '$ref->{transdate}'|,
              $linetotal);

            $form->update_balance(
              $dbh,
              "acc_trans",
              "amount",
              qq|trans_id = $ref->{trans_id} AND chart_id = $ref->{expense_accno_id} AND transdate = '$ref->{transdate}'|,
              $linetotal * -1);

          } else {

            # add entry for inventory, this one is for the sold item
            if ($linetotal != 0) {
              $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
			  transdate)
			  VALUES ($ref->{trans_id}, $ref->{inventory_accno_id},
			  $linetotal, '$ref->{transdate}')|;
              $dbh->do($query) || $form->dberror($query);

              # add expense
              $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
			  transdate, taxkey)
			  VALUES ($ref->{trans_id}, $ref->{expense_accno_id},
			  | . ($linetotal * -1) . qq|, '$ref->{transdate}',
                          (SELECT taxkey from tax WHERE chart_id = $ref->{expense_accno_id}))|;
              $dbh->do($query) || $form->dberror($query);
            }
          }

          # update allocated for sold item
          $form->update_balance($dbh, "invoice", "allocated",
                                qq|id = $ref->{id}|,
                                $qty * -1);

          $allocated += $qty;

          last if (($totalqty -= $qty) <= 0);
        }

        $sth->finish;

        $lastinventoryaccno = $form->{"inventory_accno_$i"};

      } else {

        $linetotal =
          $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"}, 2);

        if ($form->{taxincluded}) {
          $taxamount = $linetotal * ($taxrate / (1 + $taxrate));

          $form->{"sellprice_$i"} =
            $form->{"sellprice_$i"} * (1 / (1 + $taxrate));
        } else {
          $taxamount = $linetotal * $taxrate;
        }

        $netamount += $linetotal;

        if ($form->round_amount($taxrate, 7) == 0) {
          if ($form->{taxincluded}) {
            foreach $item (@taxaccounts) {
              $taxamount =
                $linetotal * $form->{"${item}_rate"} /
                (1 + abs($form->{"${item}_rate"}));
              $totaltax += $taxamount;
              $form->{amount}{ $form->{id} }{$item} -= $taxamount;
            }
          } else {
            map {
              $form->{amount}{ $form->{id} }{$_} -=
                $linetotal * $form->{"${_}_rate"}
            } @taxaccounts;
          }
        } else {
          map {
            $form->{amount}{ $form->{id} }{$_} -=
              $taxamount * $form->{"${_}_rate"} / $taxrate
          } @taxaccounts;
        }

        $amount =
          $form->{"sellprice_$i"} * $form->{"qty_$i"} * $form->{exchangerate};
        $linetotal =
          $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"}, 2) *
          $form->{exchangerate};
        $linetotal = $form->round_amount($linetotal, 2);

        # this is the difference for expense
        $expensediff += ($amount - $linetotal);

        # add amount to expense
        $form->{amount}{ $form->{id} }{ $form->{"expense_accno_$i"} } -=
          $linetotal;

        $lastexpenseaccno = $form->{"expense_accno_$i"};

        # adjust and round sellprice
        $form->{"sellprice_$i"} =
          $form->round_amount($form->{"sellprice_$i"} * $form->{exchangerate},
                              $decimalplaces);

        # update lastcost
        $query = qq|UPDATE parts SET
		    lastcost = $form->{"sellprice_$i"}
	            WHERE id = $form->{"id_$i"}|;

        $dbh->do($query) || $form->dberror($query);

      }

      $project_id = 'NULL';
      if ($form->{"projectnumber_$i"}) {
        $project_id = $form->{"projectnumber_$i"};
      }
      $deliverydate =
        ($form->{"deliverydate_$i"})
        ? qq|'$form->{"deliverydate_$i"}'|
        : "NULL";

      # save detail record in invoice table
      $query = qq|INSERT INTO invoice (trans_id, parts_id, description, qty,
                  sellprice, fxsellprice, allocated, unit, deliverydate,
		  project_id, serialnumber)
		  VALUES ($form->{id}, $form->{"id_$i"},
		  '$form->{"description_$i"}', | . ($form->{"qty_$i"} * -1) . qq|,
		  $form->{"sellprice_$i"}, $fxsellprice, $allocated,
		  '$form->{"unit_$i"}', $deliverydate, (SELECT id FROM project WHERE projectnumber = '$project_id'),
		  '$form->{"serialnumber_$i"}')|;
      $dbh->do($query) || $form->dberror($query);
    }
  }

  $form->{datepaid} = $form->{invdate};

  # all amounts are in natural state, netamount includes the taxes
  # if tax is included, netamount is rounded to 2 decimal places,
  # taxes are not

  # total payments
  for my $i (1 .. $form->{paidaccounts}) {
    $form->{"paid_$i"} = $form->parse_amount($myconfig, $form->{"paid_$i"});
    $form->{paid} += $form->{"paid_$i"};
    $form->{datepaid} = $form->{"datepaid_$i"} if ($form->{"datepaid_$i"});
  }

  my ($tax, $paiddiff) = (0, 0);

  $netamount = $form->round_amount($netamount, 2);

  # figure out rounding errors for amount paid and total amount
  if ($form->{taxincluded}) {

    $amount    = $form->round_amount($netamount * $form->{exchangerate}, 2);
    $paiddiff  = $amount - $netamount * $form->{exchangerate};
    $netamount = $amount;

    foreach $item (split / /, $form->{taxaccounts}) {
      $amount = $form->{amount}{ $form->{id} }{$item} * $form->{exchangerate};
      $form->{amount}{ $form->{id} }{$item} = $form->round_amount($amount, 2);
      $amount = $form->{amount}{ $form->{id} }{$item} * -1;
      $tax += $amount;
      $netamount -= $amount;
    }

    $invoicediff += $paiddiff;
    $expensediff += $paiddiff;

    ######## this only applies to tax included
    if ($lastinventoryaccno) {
      $form->{amount}{ $form->{id} }{$lastinventoryaccno} -= $invoicediff;
    }
    if ($lastexpenseaccno) {
      $form->{amount}{ $form->{id} }{$lastexpenseaccno} -= $expensediff;
    }

  } else {
    $amount    = $form->round_amount($netamount * $form->{exchangerate}, 2);
    $paiddiff  = $amount - $netamount * $form->{exchangerate};
    $netamount = $amount;
    foreach my $item (split / /, $form->{taxaccounts}) {
      $form->{amount}{ $form->{id} }{$item} =
        $form->round_amount($form->{amount}{ $form->{id} }{$item}, 2);
      $amount =
        $form->round_amount(
            $form->{amount}{ $form->{id} }{$item} * $form->{exchangerate} * -1,
            2);
      $paiddiff +=
        $amount - $form->{amount}{ $form->{id} }{$item} *
        $form->{exchangerate} * -1;
      $form->{amount}{ $form->{id} }{$item} =
        $form->round_amount($amount * -1, 2);
      $amount = $form->{amount}{ $form->{id} }{$item} * -1;
      $tax += $amount;
    }
  }

  $form->{amount}{ $form->{id} }{ $form->{AP} } = $netamount + $tax;

  if ($form->{paid} != 0) {
    $form->{paid} =
      $form->round_amount($form->{paid} * $form->{exchangerate} + $paiddiff,
                          2);
  }

  # update exchangerate
  if (($form->{currency} ne $form->{defaultcurrency}) && !$exchangerate) {
    $form->update_exchangerate($dbh, $form->{currency}, $form->{invdate}, 0,
                               $form->{exchangerate});
  }

  # record acc_trans transactions
  foreach my $trans_id (keys %{ $form->{amount} }) {
    foreach my $accno (keys %{ $form->{amount}{$trans_id} }) {
      if (
          ($form->{amount}{$trans_id}{$accno} =
           $form->round_amount($form->{amount}{$trans_id}{$accno}, 2)
          ) != 0
        ) {
        $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
		    transdate, taxkey)
		    VALUES ($trans_id, (SELECT c.id FROM chart c
		                         WHERE c.accno = '$accno'),
		    $form->{amount}{$trans_id}{$accno}, '$form->{invdate}',
		    (SELECT taxkey_id  FROM chart WHERE accno = '$accno'))|;
        $dbh->do($query) || $form->dberror($query);
      }
    }
  }

  # deduct payment differences from paiddiff
  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"} != 0) {
      $amount =
        $form->round_amount($form->{"paid_$i"} * $form->{exchangerate}, 2);
      $paiddiff -= $amount - $form->{"paid_$i"} * $form->{exchangerate};
    }
  }

  # force AP entry if 0
  $form->{amount}{ $form->{id} }{ $form->{AP} } = $form->{paid}
    if ($form->{amount}{ $form->{id} }{ $form->{AP} } == 0);

  # record payments and offsetting AP
  for my $i (1 .. $form->{paidaccounts}) {

    if ($form->{"paid_$i"} != 0) {
      my ($accno) = split /--/, $form->{"AP_paid_$i"};
      $form->{"datepaid_$i"} = $form->{invdate}
        unless ($form->{"datepaid_$i"});
      $form->{datepaid} = $form->{"datepaid_$i"};

      $amount = (
                 $form->round_amount(
                      $form->{"paid_$i"} * $form->{exchangerate} + $paiddiff, 2
                 )
      ) * -1;

      # record AP

      if ($form->{amount}{ $form->{id} }{ $form->{AP} } != 0) {
        $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
		    transdate)
		    VALUES ($form->{id}, (SELECT c.id FROM chart c
					WHERE c.accno = '$form->{AP}'),
		    $amount, '$form->{"datepaid_$i"}')|;
        $dbh->do($query) || $form->dberror($query);
      }

      # record payment

      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate,
                  source, memo)
                  VALUES ($form->{id}, (SELECT c.id FROM chart c
		                      WHERE c.accno = '$accno'),
                  $form->{"paid_$i"}, '$form->{"datepaid_$i"}',
		  '$form->{"source_$i"}', '$form->{"memo_$i"}')|;
      $dbh->do($query) || $form->dberror($query);

      $exchangerate = 0;

      if ($form->{currency} eq $form->{defaultcurrency}) {
        $form->{"exchangerate_$i"} = 1;
      } else {
        $exchangerate =
          $form->check_exchangerate($myconfig, $form->{currency},
                                    $form->{"datepaid_$i"}, 'sell');

        $form->{"exchangerate_$i"} =
          ($exchangerate)
          ? $exchangerate
          : $form->parse_amount($myconfig, $form->{"exchangerate_$i"});
      }

      # exchangerate difference
      $form->{fx}{$accno}{ $form->{"datepaid_$i"} } +=
        $form->{"paid_$i"} * ($form->{"exchangerate_$i"} - 1) + $paiddiff;

      # gain/loss
      $amount =
        ($form->{"paid_$i"} * $form->{exchangerate}) -
        ($form->{"paid_$i"} * $form->{"exchangerate_$i"});
      if ($amount > 0) {
        $form->{fx}{ $form->{fxgain_accno} }{ $form->{"datepaid_$i"} } +=
          $amount;
      } else {
        $form->{fx}{ $form->{fxloss_accno} }{ $form->{"datepaid_$i"} } +=
          $amount;
      }

      $paiddiff = 0;

      # update exchange rate
      if (($form->{currency} ne $form->{defaultcurrency}) && !$exchangerate) {
        $form->update_exchangerate($dbh, $form->{currency},
                                   $form->{"datepaid_$i"},
                                   0, $form->{"exchangerate_$i"});
      }
    }
  }

  # record exchange rate differences and gains/losses
  foreach my $accno (keys %{ $form->{fx} }) {
    foreach my $transdate (keys %{ $form->{fx}{$accno} }) {
      if (
          ($form->{fx}{$accno}{$transdate} =
           $form->round_amount($form->{fx}{$accno}{$transdate}, 2)
          ) != 0
        ) {

        $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
	            transdate, cleared, fx_transaction)
	            VALUES ($form->{id}, (SELECT c.id FROM chart c
		                        WHERE c.accno = '$accno'),
                    $form->{fx}{$accno}{$transdate}, '$transdate', '0', '1')|;
        $dbh->do($query) || $form->dberror($query);
      }
    }
  }

  $amount = $netamount + $tax;

  # set values which could be empty
  $form->{taxincluded} *= 1;
  my $datepaid = ($form->{paid})    ? qq|'$form->{datepaid}'| : "NULL";
  my $duedate  = ($form->{duedate}) ? qq|'$form->{duedate}'|  : "NULL";

  ($null, $form->{department_id}) = split(/--/, $form->{department});
  $form->{department_id} *= 1;

  $form->{invnumber} = $form->{id} unless $form->{invnumber};

  # save AP record
  $query = qq|UPDATE ap set
              invnumber = '$form->{invnumber}',
	      ordnumber = '$form->{ordnumber}',
	      quonumber = '$form->{quonumber}',
              transdate = '$form->{invdate}',
              vendor_id = $form->{vendor_id},
              amount = $amount,
              netamount = $netamount,
              paid = $form->{paid},
	      datepaid = $datepaid,
	      duedate = $duedate,
	      invoice = '1',
	      taxincluded = '$form->{taxincluded}',
	      notes = '$form->{notes}',
	      intnotes = '$form->{intnotes}',
	      curr = '$form->{currency}',
	      department_id = $form->{department_id},
              cp_id = $form->{contact_id}
              WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # add shipto
  $form->{name} = $form->{vendor};
  $form->{name} =~ s/--$form->{vendor_id}//;
  $form->add_shipto($dbh, $form->{id});

  # delete zero entries
  $query = qq|DELETE FROM acc_trans
              WHERE amount = 0|;
  $dbh->do($query) || $form->dberror($query);

  if ($form->{webdav}) {
    &webdav_folder($myconfig, $form);
  }

  my $rc = $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $rc;
}

sub reverse_invoice {
  $main::lxdebug->enter_sub();

  my ($dbh, $form) = @_;

  # reverse inventory items
  my $query = qq|SELECT i.parts_id, p.inventory_accno_id, p.expense_accno_id,
                 i.qty, i.allocated, i.sellprice
                 FROM invoice i, parts p
		 WHERE i.parts_id = p.id
                 AND i.trans_id = $form->{id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $netamount = 0;

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    $netamount += $form->round_amount($ref->{sellprice} * $ref->{qty} * -1, 2);

    if ($ref->{inventory_accno_id}) {

      # update onhand
      $form->update_balance($dbh, "parts", "onhand", qq|id = $ref->{parts_id}|,
                            $ref->{qty});

      # if $ref->{allocated} > 0 than we sold that many items
      if ($ref->{allocated} > 0) {

        # get references for sold items
        $query = qq|SELECT i.id, i.trans_id, i.allocated, a.transdate
	            FROM invoice i, ar a
		    WHERE i.parts_id = $ref->{parts_id}
		    AND i.allocated < 0
		    AND i.trans_id = a.id
		    ORDER BY transdate DESC|;
        my $sth = $dbh->prepare($query);
        $sth->execute || $form->dberror($query);

        while (my $pthref = $sth->fetchrow_hashref(NAME_lc)) {
          my $qty = $ref->{allocated};
          if (($ref->{allocated} + $pthref->{allocated}) > 0) {
            $qty = $pthref->{allocated} * -1;
          }

          my $amount = $form->round_amount($ref->{sellprice} * $qty, 2);

          #adjust allocated
          $form->update_balance($dbh, "invoice", "allocated",
                                qq|id = $pthref->{id}|, $qty);

          $form->update_balance(
            $dbh,
            "acc_trans",
            "amount",
            qq|trans_id = $pthref->{trans_id} AND chart_id = $ref->{expense_accno_id} AND transdate = '$pthref->{transdate}'|,
            $amount);

          $form->update_balance(
            $dbh,
            "acc_trans",
            "amount",
            qq|trans_id = $pthref->{trans_id} AND chart_id = $ref->{inventory_accno_id} AND transdate = '$pthref->{transdate}'|,
            $amount * -1);

          last if (($ref->{allocated} -= $qty) <= 0);
        }
        $sth->finish;
      }
    }
  }
  $sth->finish;

  # delete acc_trans
  $query = qq|DELETE FROM acc_trans
              WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # delete invoice entries
  $query = qq|DELETE FROM invoice
              WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $query = qq|DELETE FROM shipto
              WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $main::lxdebug->leave_sub();
}

sub delete_invoice {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  &reverse_invoice($dbh, $form);

  # delete zero entries
  my $query = qq|DELETE FROM acc_trans
                 WHERE amount = 0|;
  $dbh->do($query) || $form->dberror($query);

  # delete AP record
  my $query = qq|DELETE FROM ap
                 WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  my $rc = $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $rc;
}

sub retrieve_invoice {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query;

  if ($form->{id}) {

    # get default accounts and last invoice number
    $query = qq|SELECT (SELECT c.accno FROM chart c
                        WHERE d.inventory_accno_id = c.id) AS inventory_accno,
                       (SELECT c.accno FROM chart c
		        WHERE d.income_accno_id = c.id) AS income_accno,
                       (SELECT c.accno FROM chart c
		        WHERE d.expense_accno_id = c.id) AS expense_accno,
		       (SELECT c.accno FROM chart c
		        WHERE d.fxgain_accno_id = c.id) AS fxgain_accno,
		       (SELECT c.accno FROM chart c
		        WHERE d.fxloss_accno_id = c.id) AS fxloss_accno,
                d.curr AS currencies
	 	FROM defaults d|;
  } else {
    $query = qq|SELECT (SELECT c.accno FROM chart c
                        WHERE d.inventory_accno_id = c.id) AS inventory_accno,
                       (SELECT c.accno FROM chart c
		        WHERE d.income_accno_id = c.id) AS income_accno,
                       (SELECT c.accno FROM chart c
		        WHERE d.expense_accno_id = c.id) AS expense_accno,
		       (SELECT c.accno FROM chart c
		        WHERE d.fxgain_accno_id = c.id) AS fxgain_accno,
		       (SELECT c.accno FROM chart c
		        WHERE d.fxloss_accno_id = c.id) AS fxloss_accno,
                d.curr AS currencies,
		current_date AS invdate
	 	FROM defaults d|;
  }
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);
  map { $form->{$_} = $ref->{$_} } keys %$ref;
  $sth->finish;

  if ($form->{id}) {

    # retrieve invoice
    $query = qq|SELECT a.cp_id, a.invnumber, a.transdate AS invdate, a.duedate,
                a.ordnumber, a.quonumber, a.paid, a.taxincluded, a.notes,
		a.intnotes, a.curr AS currency
		FROM ap a
		WHERE a.id = $form->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    map { $form->{$_} = $ref->{$_} } keys %$ref;
    $sth->finish;

    $form->{exchangerate} =
      $form->get_exchangerate($dbh, $form->{currency}, $form->{invdate},
                              "sell");

    # get shipto
    $query = qq|SELECT s.* FROM shipto s
                WHERE s.trans_id = $form->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    map { $form->{$_} = $ref->{$_} } keys %$ref;
    $sth->finish;

    # retrieve individual items
    $query = qq|SELECT c1.accno AS inventory_accno,
                       c2.accno AS income_accno,
		       c3.accno AS expense_accno,
		p.partnumber, i.description, i.qty, i.fxsellprice AS sellprice,
		i.parts_id AS id, i.unit, p.bin, i.deliverydate,
		pr.projectnumber,
                i.project_id, i.serialnumber,
		pg.partsgroup
		FROM invoice i
		JOIN parts p ON (i.parts_id = p.id)
		LEFT JOIN chart c1 ON (p.inventory_accno_id = c1.id)
		LEFT JOIN chart c2 ON (p.income_accno_id = c2.id)
		LEFT JOIN chart c3 ON (p.expense_accno_id = c3.id)
		LEFT JOIN project pr ON (i.project_id = pr.id)
		LEFT JOIN partsgroup pg ON (pg.id = p.partsgroup_id)
		WHERE i.trans_id = $form->{id}
		ORDER BY i.id|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {

      #set expense_accno=inventory_accno if they are different => bilanz
      $vendor_accno =
        ($ref->{expense_accno} != $ref->{inventory_accno})
        ? $ref->{inventory_accno}
        : $ref->{expense_accno};
      $vendor_accno =
        ($ref->{inventory_accno})
        ? $ref->{inventory_accno}
        : $ref->{expense_accno};

      # get tax rates and description
      $accno_id =
        ($form->{vc} eq "customer") ? $ref->{income_accno} : $vendor_accno;
      $query = qq|SELECT c.accno, c.description, t.rate, t.taxnumber
	         FROM chart c, tax t
	         WHERE c.id=t.chart_id AND t.taxkey in (SELECT taxkey_id from chart where accno = '$accno_id')
	         ORDER BY accno|;
      $stw = $dbh->prepare($query);
      $stw->execute || $form->dberror($query);
      $ref->{taxaccounts} = "";
      while ($ptr = $stw->fetchrow_hashref(NAME_lc)) {

        #    if ($customertax{$ref->{accno}}) {
        $ref->{taxaccounts} .= "$ptr->{accno} ";
        if (!($form->{taxaccounts} =~ /$ptr->{accno}/)) {
          $form->{"$ptr->{accno}_rate"}        = $ptr->{rate};
          $form->{"$ptr->{accno}_description"} = $ptr->{description};
          $form->{"$ptr->{accno}_taxnumber"}   = $ptr->{taxnumber};
          $form->{taxaccounts} .= "$ptr->{accno} ";
        }

      }

      chop $ref->{taxaccounts};
      push @{ $form->{invoice_details} }, $ref;
      $stw->finish;
    }
    $sth->finish;

    if ($form->{webdav}) {
      &webdav_folder($myconfig, $form);
    }

  }

  my $rc = $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $rc;
}

sub get_vendor {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $dateformat = $myconfig->{dateformat};
  $dateformat .= "yy" if $myconfig->{dateformat} !~ /^y/;

  my $duedate =
    ($form->{invdate})
    ? "to_date('$form->{invdate}', '$dateformat')"
    : "current_date";

  $form->{vendor_id} *= 1;

  # get vendor
  my $query = qq|SELECT v.name AS vendor, v.creditlimit, v.terms,
                 v.email, v.cc, v.bcc, v.language,
		 v.street, v.zipcode, v.city, v.country,
                 $duedate + v.terms AS duedate, v.notes AS intnotes
                 FROM vendor v
	         WHERE v.id = $form->{vendor_id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $ref = $sth->fetchrow_hashref(NAME_lc);
  map { $form->{$_} = $ref->{$_} } keys %$ref;
  $sth->finish;

  $form->{creditremaining} = $form->{creditlimit};
  $query = qq|SELECT SUM(a.amount - a.paid)
              FROM ap a
	      WHERE a.vendor_id = $form->{vendor_id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  ($form->{creditremaining}) -= $sth->fetchrow_array;

  $sth->finish;

  $query = qq|SELECT o.amount,
                (SELECT e.sell FROM exchangerate e
		 WHERE e.curr = o.curr
		 AND e.transdate = o.transdate)
	      FROM oe o
	      WHERE o.vendor_id = $form->{vendor_id}
	      AND o.quotation = '0'
	      AND o.closed = '0'|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my ($amount, $exch) = $sth->fetchrow_array) {
    $exch = 1 unless $exch;
    $form->{creditremaining} -= $amount * $exch;
  }
  $sth->finish;

  $form->get_contacts($dbh, $form->{vendor_id});

  ($null, $form->{cp_id}) = split /--/, $form->{contact};

  # get contact if selected
  if ($form->{contact} ne "--" && $form->{contact} ne "") {
    $form->get_contact($dbh, $form->{cp_id});
  }

  # get shipto if we do not convert an order or invoice
  if (!$form->{shipto}) {
    map { delete $form->{$_} }
      qw(shiptoname shiptostreet shiptozipcode shiptocity shiptocountry shiptocontact shiptophone shiptofax shiptoemail);

    $query = qq|SELECT s.* FROM shipto s
                WHERE s.trans_id = $form->{vendor_id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    map { $form->{$_} = $ref->{$_} } keys %$ref;
    $sth->finish;
  }

  # get taxes for vendor
  $query = qq|SELECT c.accno
              FROM chart c
	      JOIN vendortax v ON (v.chart_id = c.id)
	      WHERE v.vendor_id = $form->{vendor_id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $vendortax = ();
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $vendortax{ $ref->{accno} } = 1;
  }
  $sth->finish;

  if (!$form->{id} && $form->{type} !~ /_(order|quotation)/) {

    # setup last accounts used
    $query = qq|SELECT c.accno, c.description, c.link, c.category
		FROM chart c
		JOIN acc_trans ac ON (ac.chart_id = c.id)
		JOIN ap a ON (a.id = ac.trans_id)
		WHERE a.vendor_id = $form->{vendor_id}
		AND NOT (c.link LIKE '%_tax%' OR c.link LIKE '%_paid%')
		AND a.id IN (SELECT max(a2.id) FROM ap a2
			     WHERE a2.vendor_id = $form->{vendor_id})|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    my $i = 0;
    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      if ($ref->{category} eq 'E') {
        $i++;
        $form->{"AP_amount_$i"} = "$ref->{accno}--$ref->{description}";
      }
      if ($ref->{category} eq 'L') {
        $form->{APselected} = $form->{AP_1} =
          "$ref->{accno}--$ref->{description}";
      }
    }
    $sth->finish;
    $form->{rowcount} = $i if ($i && !$form->{type});
  }

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub retrieve_item {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $i = $form->{rowcount};

  # don't include assemblies or obsolete parts
  my $where = "NOT p.assembly = '1' AND NOT p.obsolete = '1'";

  if ($form->{"partnumber_$i"}) {
    my $partnumber = $form->like(lc $form->{"partnumber_$i"});
    $where .= " AND lower(p.partnumber) LIKE '$partnumber'";
  }

  if ($form->{"description_$i"}) {
    my $description = $form->like(lc $form->{"description_$i"});
    $where .= " AND lower(p.description) LIKE '$description'";
  }

  if ($form->{"partsgroup_$i"}) {
    my $partsgroup = $form->like(lc $form->{"partsgroup_$i"});
    $where .= " AND lower(pg.partsgroup) LIKE '$partsgroup'";
  }

  if ($form->{"description_$i"}) {
    $where .= " ORDER BY p.description";
  } else {
    $where .= " ORDER BY p.partnumber";
  }

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT p.id, p.partnumber, p.description,
                 c1.accno AS inventory_accno,
		 c2.accno AS income_accno,
		 c3.accno AS expense_accno,
		 pg.partsgroup,
                 p.lastcost AS sellprice, p.unit, p.bin, p.onhand, p.notes AS partnotes
                 FROM parts p
		 LEFT JOIN chart c1 ON (p.inventory_accno_id = c1.id)
		 LEFT JOIN chart c2 ON (p.income_accno_id = c2.id)
		 LEFT JOIN chart c3 ON (p.expense_accno_id = c3.id)
		 LEFT JOIN partsgroup pg ON (pg.id = p.partsgroup_id)
	         WHERE $where|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {

    #set expense_accno=inventory_accno if they are different => bilanz
    $vendor_accno =
      ($ref->{expense_accno} != $ref->{inventory_accno})
      ? $ref->{inventory_accno}
      : $ref->{expense_accno};
    $vendor_accno =
      ($ref->{inventory_accno})
      ? $ref->{inventory_accno}
      : $ref->{expense_accno};

    # get tax rates and description
    $accno_id =
      ($form->{vc} eq "customer") ? $ref->{income_accno} : $vendor_accno;
    $query = qq|SELECT c.accno, c.description, t.rate, t.taxnumber
	      FROM chart c, tax t
	      WHERE c.id=t.chart_id AND t.taxkey in (SELECT taxkey_id from chart where accno = '$accno_id')
	      ORDER BY c.accno|;
    $stw = $dbh->prepare($query);
    $stw->execute || $form->dberror($query);

    $ref->{taxaccounts} = "";
    while ($ptr = $stw->fetchrow_hashref(NAME_lc)) {

      #    if ($customertax{$ref->{accno}}) {
      $ref->{taxaccounts} .= "$ptr->{accno} ";
      if (!($form->{taxaccounts} =~ /$ptr->{accno}/)) {
        $form->{"$ptr->{accno}_rate"}        = $ptr->{rate};
        $form->{"$ptr->{accno}_description"} = $ptr->{description};
        $form->{"$ptr->{accno}_taxnumber"}   = $ptr->{taxnumber};
        $form->{taxaccounts} .= "$ptr->{accno} ";
      }

    }

    $stw->finish;
    chop $ref->{taxaccounts};

    push @{ $form->{item_list} }, $ref;

  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub vendor_details {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  # get contact id, set it if nessessary
  ($null, $form->{cp_id}) = split /--/, $form->{contact};

  $contact = "";
  if ($form->{cp_id}) {
    $contact = "and cp.cp_id = $form->{cp_id}";
  }

  # get rest for the vendor
  # fax and phone and email as vendor*
  my $query =
    qq|SELECT ct.*, cp.*, ct.notes as vendornotes, phone as vendorphone, fax as vendorfax, email as vendoremail
                 FROM vendor ct
                 LEFT JOIN contacts cp on ct.id = cp.cp_cv_id
		 WHERE ct.id = $form->{vendor_id}  $contact order by cp.cp_id limit 1|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $ref = $sth->fetchrow_hashref(NAME_lc);

  # remove id and taxincluded before copy back
  delete @$ref{qw(id taxincluded)};
  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub item_links {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT c.accno, c.description, c.link
	         FROM chart c
	         WHERE c.link LIKE '%IC%'
		 ORDER BY c.accno|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    foreach my $key (split(/:/, $ref->{link})) {
      if ($key =~ /IC/) {
        push @{ $form->{IC_links}{$key} },
          { accno       => $ref->{accno},
            description => $ref->{description} };
      }
    }
  }

  $sth->finish;
  $main::lxdebug->leave_sub();
}

sub webdav_folder {
  $main::lxdebug->enter_sub();

  my ($myconfig, $form) = @_;

SWITCH: {
    $path = "webdav/rechnungen/" . $form->{invnumber}, last SWITCH
      if ($form->{vc} eq "customer");
    $path = "webdav/einkaufsrechnungen/" . $form->{invnumber}, last SWITCH
      if ($form->{vc} eq "vendor");
  }

  if (!-d $path) {
    mkdir($path, 0770) or die "can't make directory $!\n";
  } else {
    if ($form->{id}) {
      @files = <$path/*>;
      foreach $file (@files) {

        $file =~ /\/([^\/]*)$/;
        $fname = $1;
        $ENV{'SCRIPT_NAME'} =~ /\/([^\/]*)\//;
        $lxerp = $1;
        $link  = "http://" . $ENV{'SERVER_NAME'} . "/" . $lxerp . "/" . $file;
        $form->{WEBDAV}{$fname} = $link;
      }
    }
  }

  $main::lxdebug->leave_sub();
}

1;
