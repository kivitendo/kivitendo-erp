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
# Accounts Receivable module backend routines
#
#======================================================================

package AR;

use Data::Dumper;

sub post_transaction {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my ($null, $taxrate, $amount, $tax, $diff);
  my $exchangerate = 0;
  my $i;

  my $dbh = $form->dbconnect_noauto($myconfig);

  if ($form->{currency} eq $form->{defaultcurrency}) {
    $form->{exchangerate} = 1;
  } else {
    $exchangerate =
      $form->check_exchangerate($myconfig, $form->{currency},
                                $form->{transdate}, 'buy');
  }
  for $i (1 .. $form->{rowcount}) {
    $form->{AR_amounts}{"amount_$i"} =
      (split(/--/, $form->{"AR_amount_$i"}))[0];
  }
  ($form->{AR_amounts}{receivables}) = split(/--/, $form->{ARselected});
  ($form->{AR}{receivables})         = split(/--/, $form->{ARselected});

  $form->{exchangerate} =
    ($exchangerate)
    ? $exchangerate
    : $form->parse_amount($myconfig, $form->{exchangerate});

  for $i (1 .. $form->{rowcount}) {

    $form->{"amount_$i"} =
      $form->round_amount($form->parse_amount($myconfig, $form->{"amount_$i"})
                            * $form->{exchangerate},
                          2);

    $form->{netamount} += $form->{"amount_$i"};

    # parse tax_$i for later
    $form->{"tax_$i"} = $form->parse_amount($myconfig, $form->{"tax_$i"});
  }

  # this is for ar

  $form->{amount} = $form->{netamount};

  $form->{tax}       = 0;
  $form->{netamount} = 0;
  $form->{total_tax} = 0;

  # taxincluded doesn't make sense if there is no amount

  $form->{taxincluded} = 0 if ($form->{amount} == 0);
  for $i (1 .. $form->{rowcount}) {
    ($form->{"tax_id_$i"}, $NULL) = split /--/, $form->{"taxchart_$i"};

    $query = qq|SELECT c.accno, t.taxkey, t.rate
            FROM tax t LEFT JOIN chart c on (c.id=t.chart_id)
            WHERE t.id=$form->{"tax_id_$i"}
            ORDER BY c.accno|;

    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    ($form->{AR_amounts}{"tax_$i"}, $form->{"taxkey_$i"}, $form->{"taxrate_$i"}) =
      $sth->fetchrow_array;
    $form->{AR_amounts}{"tax_$i"}{taxkey}    = $form->{"taxkey_$i"};
    $form->{AR_amounts}{"amount_$i"}{taxkey} = $form->{"taxkey_$i"};

    $sth->finish;
    if ($form->{taxincluded} *= 1) {
      if (!$form->{"korrektur_$i"}) {
      $tax =
        $form->{"amount_$i"} -
        ($form->{"amount_$i"} / ($form->{"taxrate_$i"} + 1));
      } else {
        $tax = $form->{"tax_$i"};
      }
      $amount = $form->{"amount_$i"} - $tax;
      $form->{"amount_$i"} = $form->round_amount($amount, 2);
      $diff += $amount - $form->{"amount_$i"};
      $form->{"tax_$i"} = $form->round_amount($tax, 2);
      $form->{netamount} += $form->{"amount_$i"};
    } else {
      if (!$form->{"korrektur_$i"}) {
        $form->{"tax_$i"} = $form->{"amount_$i"} * $form->{"taxrate_$i"};
      }
      $form->{"tax_$i"} =
        $form->round_amount($form->{"tax_$i"} * $form->{exchangerate}, 2);
      $form->{netamount} += $form->{"amount_$i"};
    }
    
    $form->{total_tax} += $form->{"tax_$i"};
  }

  # adjust paidaccounts if there is no date in the last row
  $form->{paidaccounts}-- unless ($form->{"datepaid_$form->{paidaccounts}"});
  $form->{paid} = 0;

  # add payments
  for $i (1 .. $form->{paidaccounts}) {
    $form->{"paid_$i"} =
      $form->round_amount($form->parse_amount($myconfig, $form->{"paid_$i"}),
                          2);

    $form->{paid} += $form->{"paid_$i"};
    $form->{datepaid} = $form->{"datepaid_$i"};

  }

  $form->{amount} = $form->{netamount} + $form->{total_tax};
  $form->{paid}   =
    $form->round_amount($form->{paid} * $form->{exchangerate}, 2);

  my ($query, $sth, $null);

  ($null, $form->{employee_id}) = split /--/, $form->{employee};
  unless ($form->{employee_id}) {
    $form->get_employee($dbh);
  }

  # if we have an id delete old records
  if ($form->{id}) {

    # delete detail records
    $query = qq|DELETE FROM acc_trans WHERE trans_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);

  } else {
    my $uid = rand() . time;

    $uid .= $form->{login};

    $uid = substr($uid, 2, 75);

    $query = qq|INSERT INTO ar (invnumber, employee_id)
                VALUES ('$uid', $form->{employee_id})|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|SELECT a.id FROM ar a
                WHERE a.invnumber = '$uid'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{id}) = $sth->fetchrow_array;
    $sth->finish;

  }

  # update department
  ($null, $form->{department_id}) = split(/--/, $form->{department});
  $form->{department_id} *= 1;

  # escape '
  map { $form->{$_} =~ s/\'/\'\'/g } qw(invnumber ordnumber notes);

  # record last payment date in ar table
  $form->{datepaid} = $form->{transdate} unless $form->{datepaid};
  my $datepaid = ($form->{paid} != 0) ? qq|'$form->{datepaid}'| : 'NULL';

  $query = qq|UPDATE ar set
	      invnumber = '$form->{invnumber}',
	      ordnumber = '$form->{ordnumber}',
	      transdate = '$form->{transdate}',
	      customer_id = $form->{customer_id},
	      taxincluded = '$form->{taxincluded}',
	      amount = $form->{amount},
	      duedate = '$form->{duedate}',
	      paid = $form->{paid},
	      datepaid = $datepaid,
	      netamount = $form->{netamount},
	      curr = '$form->{currency}',
	      notes = '$form->{notes}',
	      department_id = $form->{department_id},
	      employee_id = $form->{employee_id}
	      WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # amount for AR account
  $form->{receivables} = $form->round_amount($form->{amount}, 2) * -1;

  # update exchangerate
  if (($form->{currency} ne $form->{defaultcurrency}) && !$exchangerate) {
    $form->update_exchangerate($dbh, $form->{currency}, $form->{transdate},
                               $form->{exchangerate}, 0);
  }

  # add individual transactions for AR, amount and taxes
  for $i (1 .. $form->{rowcount}) {
    if ($form->{"amount_$i"} != 0) {
      $project_id = 'NULL';
      if ("amount_$i" =~ /amount_/) {
        if ($form->{"project_id_$i"} && $form->{"projectnumber_$i"}) {
          $project_id = $form->{"project_id_$i"};
        }
      }
      if ("amount_$i" =~ /amount/) {
        $taxkey = $form->{AR_amounts}{"amount_$i"}{taxkey};
      }

      # insert detail records in acc_trans
      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate,
                                         project_id, taxkey)
		  VALUES ($form->{id}, (SELECT c.id FROM chart c
		                        WHERE c.accno = '$form->{AR_amounts}{"amount_$i"}'),
		  $form->{"amount_$i"}, '$form->{transdate}', $project_id, '$taxkey')|;
      $dbh->do($query) || $form->dberror($query);
      if ($form->{"tax_$i"} != 0) {

        # insert detail records in acc_trans
        $query =
          qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate,
                                          project_id, taxkey)
                    VALUES ($form->{id}, (SELECT c.id FROM chart c
                                          WHERE c.accno = '$form->{AR_amounts}{"tax_$i"}'),
                    $form->{"tax_$i"}, '$form->{transdate}', $project_id, '$taxkey')|;
        $dbh->do($query) || $form->dberror($query);
      }
    }
  }

  # add recievables
  $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate,
                                      project_id)
              VALUES ($form->{id}, (SELECT c.id FROM chart c
                                    WHERE c.accno = '$form->{AR_amounts}{receivables}'),
              $form->{receivables}, '$form->{transdate}', $project_id)|;
  $dbh->do($query) || $form->dberror($query);

  # add paid transactions
  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"} != 0) {

      $form->{"AR_paid_$i"} =~ s/\"//g;
      ($form->{AR}{"paid_$i"}) = split(/--/, $form->{"AR_paid_$i"});
      $form->{"datepaid_$i"} = $form->{transdate}
        unless ($form->{"datepaid_$i"});

      $exchangerate = 0;
      if ($form->{currency} eq $form->{defaultcurrency}) {
        $form->{"exchangerate_$i"} = 1;
      } else {
        $exchangerate =
          $form->check_exchangerate($myconfig, $form->{currency},
                                    $form->{"datepaid_$i"}, 'buy');

        $form->{"exchangerate_$i"} =
          ($exchangerate)
          ? $exchangerate
          : $form->parse_amount($myconfig, $form->{"exchangerate_$i"});
      }

      # if there is no amount and invtotal is zero there is no exchangerate
      if ($form->{amount} == 0 && $form->{netamount} == 0) {
        $form->{exchangerate} = $form->{"exchangerate_$i"};
      }

      # receivables amount
      $amount =
        $form->round_amount($form->{"paid_$i"} * $form->{exchangerate}, 2);

      if ($form->{receivables} != 0) {

        # add receivable
        $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
		    transdate)
		    VALUES ($form->{id},
		           (SELECT c.id FROM chart c
			    WHERE c.accno = '$form->{AR}{receivables}'),
		    $amount, '$form->{"datepaid_$i"}')|;
        $dbh->do($query) || $form->dberror($query);
      }
      $form->{receivables} = $amount;

      $form->{"memo_$i"} =~ s/\'/\'\'/g;

      if ($form->{"paid_$i"} != 0) {

        # add payment
        $amount = $form->{"paid_$i"} * -1;
        $query  = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
		    transdate, source, memo)
		    VALUES ($form->{id},
			   (SELECT c.id FROM chart c
			    WHERE c.accno = '$form->{AR}{"paid_$i"}'),
		    $amount, '$form->{"datepaid_$i"}',
		    '$form->{"source_$i"}', '$form->{"memo_$i"}')|;
        $dbh->do($query) || $form->dberror($query);

        # exchangerate difference for payment
        $amount =
          $form->round_amount(
                    $form->{"paid_$i"} * ($form->{"exchangerate_$i"} - 1) * -1,
                    2);

        if ($amount != 0) {
          $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
		      transdate, fx_transaction, cleared)
		      VALUES ($form->{id},
			     (SELECT c.id FROM chart c
			      WHERE c.accno = '$form->{AR}{"paid_$i"}'),
		      $amount, '$form->{"datepaid_$i"}', '1', '0')|;
          $dbh->do($query) || $form->dberror($query);
        }

        # exchangerate gain/loss
        $amount =
          $form->round_amount(
                   $form->{"paid_$i"} *
                     ($form->{exchangerate} - $form->{"exchangerate_$i"}) * -1,
                   2);

        if ($amount != 0) {
          $accno =
            ($amount > 0) ? $form->{fxgain_accno} : $form->{fxloss_accno};
          $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
		      transdate, fx_transaction, cleared)
		      VALUES ($form->{id}, (SELECT c.id FROM chart c
					    WHERE c.accno = '$accno'),
		      $amount, '$form->{"datepaid_$i"}', '1', '0')|;
          $dbh->do($query) || $form->dberror($query);
        }
      }

      # update exchangerate record
      if (($form->{currency} ne $form->{defaultcurrency}) && !$exchangerate) {
        $form->update_exchangerate($dbh, $form->{currency},
                                   $form->{"datepaid_$i"},
                                   $form->{"exchangerate_$i"}, 0);
      }
    }
  }

  my $rc = $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $rc;
}

sub delete_transaction {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database, turn AutoCommit off
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query = qq|DELETE FROM ar WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $query = qq|DELETE FROM acc_trans WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # commit
  my $rc = $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $rc;
}

sub ar_transactions {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT a.id, a.invnumber, a.ordnumber, a.transdate,
                 a.duedate, a.netamount, a.amount, a.paid, c.name,
		 a.invoice, a.datepaid, a.terms, a.notes, a.shipvia,
		 a.shippingpoint, a.storno,
		 e.name AS employee
	         FROM ar a
	      JOIN customer c ON (a.customer_id = c.id)
	      LEFT JOIN employee e ON (a.employee_id = e.id)|;

  my $where = "1 = 1";
  if ($form->{customer_id}) {
    $where .= " AND a.customer_id = $form->{customer_id}";
  } else {
    if ($form->{customer}) {
      my $customer = $form->like(lc $form->{customer});
      $where .= " AND lower(c.name) LIKE '$customer'";
    }
  }
  if ($form->{department}) {
    my ($null, $department_id) = split /--/, $form->{department};
    $where .= " AND a.department_id = $department_id";
  }
  if ($form->{invnumber}) {
    my $invnumber = $form->like(lc $form->{invnumber});
    $where .= " AND lower(a.invnumber) LIKE '$invnumber'";
  }
  if ($form->{ordnumber}) {
    my $ordnumber = $form->like(lc $form->{ordnumber});
    $where .= " AND lower(a.ordnumber) LIKE '$ordnumber'";
  }
  if ($form->{notes}) {
    my $notes = $form->like(lc $form->{notes});
    $where .= " AND lower(a.notes) LIKE '$notes'";
  }

  $where .= " AND a.transdate >= '$form->{transdatefrom}'"
    if $form->{transdatefrom};
  $where .= " AND a.transdate <= '$form->{transdateto}'"
    if $form->{transdateto};
  if ($form->{open} || $form->{closed}) {
    unless ($form->{open} && $form->{closed}) {
      $where .= " AND a.amount <> a.paid" if ($form->{open});
      $where .= " AND a.amount = a.paid"  if ($form->{closed});
    }
  }

  my @a = (transdate, invnumber, name);
  push @a, "employee" if $form->{l_employee};
  my $sortorder = join ', ', $form->sort_columns(@a);
  $sortorder = $form->{sort} if $form->{sort};

  $query .= "WHERE $where
             ORDER by $sortorder";

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ar = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{AR} }, $ar;
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_transdate {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query =
    "SELECT COALESCE(" .
    "  (SELECT transdate FROM ar WHERE id = " .
    "    (SELECT MAX(id) FROM ar) LIMIT 1), " .
    "  current_date)";
  ($form->{transdate}) = $dbh->selectrow_array($query);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

1;

