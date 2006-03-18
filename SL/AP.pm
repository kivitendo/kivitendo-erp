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
# Accounts Payables database backend routines
#
#======================================================================

package AP;

sub post_transaction {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my ($null, $taxrate, $amount);
  my $exchangerate = 0;

  ($null, $form->{department_id}) = split(/--/, $form->{department});
  $form->{department_id} *= 1;

  if ($form->{currency} eq $form->{defaultcurrency}) {
    $form->{exchangerate} = 1;
  } else {
    $exchangerate =
      $form->check_exchangerate($myconfig, $form->{currency},
                                $form->{transdate}, 'sell');

    $form->{exchangerate} =
      ($exchangerate)
      ? $exchangerate
      : $form->parse_amount($myconfig, $form->{exchangerate});
  }

  for $i (1 .. $form->{rowcount}) {
    $form->{AP_amounts}{"amount_$i"} =
      (split(/--/, $form->{"AP_amount_$i"}))[0];
  }
  ($form->{AP_amounts}{payables}) = split(/--/, $form->{APselected});
  ($form->{AP}{payables})         = split(/--/, $form->{APselected});

  # reverse and parse amounts
  for my $i (1 .. $form->{rowcount}) {
    $form->{"amount_$i"} =
      $form->round_amount(
                         $form->parse_amount($myconfig, $form->{"amount_$i"}) *
                           $form->{exchangerate} * -1,
                         2);
    $amount += ($form->{"amount_$i"} * -1);

    # parse tax_$i for later
    $form->{"tax_$i"} = $form->parse_amount($myconfig, $form->{"tax_$i"}) * -1;
  }

  # this is for ap
  $form->{amount} = $amount;

  # taxincluded doesn't make sense if there is no amount
  $form->{taxincluded} = 0 if ($form->{amount} == 0);

  for $i (1 .. $form->{rowcount}) {
    ($form->{"taxkey_$i"}, $NULL) = split /--/, $form->{"taxchart_$i"};

    $query =
      qq| SELECT c.accno, t.rate FROM chart c, tax t where c.id=t.chart_id AND t.taxkey=$form->{"taxkey_$i"}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    ($form->{AP_amounts}{"tax_$i"}, $form->{"taxrate_$i"}) =
      $sth->fetchrow_array;
    $form->{AP_amounts}{"tax_$i"}{taxkey}    = $form->{"taxkey_$i"};
    $form->{AP_amounts}{"amount_$i"}{taxkey} = $form->{"taxkey_$i"};

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
      } else {
        $tax = $form->{"tax_$i"};
      }
      $form->{"tax_$i"} =
        $form->round_amount($form->{"tax_$i"} * $form->{exchangerate}, 2);
      $form->{netamount} += $form->{"amount_$i"};
    }
    $form->{total_tax} += $form->{"tax_$i"} * -1;
  }

  # adjust paidaccounts if there is no date in the last row
  $form->{paidaccounts}-- unless ($form->{"datepaid_$form->{paidaccounts}"});

  $form->{invpaid} = 0;
  $form->{netamount} *= -1;

  # add payments
  for my $i (1 .. $form->{paidaccounts}) {
    $form->{"paid_$i"} =
      $form->round_amount($form->parse_amount($myconfig, $form->{"paid_$i"}),
                          2);

    $form->{invpaid} += $form->{"paid_$i"};
    $form->{datepaid} = $form->{"datepaid_$i"};

  }

  $form->{invpaid} =
    $form->round_amount($form->{invpaid} * $form->{exchangerate}, 2);

  # store invoice total, this goes into ap table
  $form->{invtotal} = $form->{netamount} + $form->{total_tax};

  # amount for total AP
  $form->{payables} = $form->{invtotal};

  my ($query, $sth);

  # if we have an id delete old records
  if ($form->{id}) {

    # delete detail records
    $query = qq|DELETE FROM acc_trans WHERE trans_id = $form->{id}|;

    $dbh->do($query) || $form->dberror($query);

  } else {
    my $uid = rand() . time;

    $uid .= $form->{login};

    $uid = substr($uid, 2, 75);

    $query = qq|INSERT INTO ap (invnumber, employee_id)
                VALUES ('$uid', (SELECT e.id FROM employee e
		                 WHERE e.login = '$form->{login}') )|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|SELECT a.id FROM ap a
                WHERE a.invnumber = '$uid'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{id}) = $sth->fetchrow_array;
    $sth->finish;

  }

  $form->{invnumber} = $form->{id} unless $form->{invnumber};

  # escape '
  map { $form->{$_} =~ s/\'/\'\'/g } qw(invnumber ordnumber notes);

  $form->{datepaid} = $form->{transdate} unless ($form->{datepaid});
  my $datepaid = ($form->{invpaid} != 0) ? qq|'$form->{datepaid}'| : 'NULL';

  $query = qq|UPDATE ap SET
	      invnumber = '$form->{invnumber}',
	      transdate = '$form->{transdate}',
	      ordnumber = '$form->{ordnumber}',
	      vendor_id = $form->{vendor_id},
	      taxincluded = '$form->{taxincluded}',
	      amount = $form->{invtotal},
	      duedate = '$form->{duedate}',
	      paid = $form->{invpaid},
	      datepaid = $datepaid,
	      netamount = $form->{netamount},
	      curr = '$form->{currency}',
	      notes = '$form->{notes}',
	      department_id = $form->{department_id}
	      WHERE id = $form->{id}
	     |;
  $dbh->do($query) || $form->dberror($query);

  # update exchangerate
  if (($form->{currency} ne $form->{defaultcurrency}) && !$exchangerate) {
    $form->update_exchangerate($dbh, $form->{currency}, $form->{transdate}, 0,
                               $form->{exchangerate});
  }

  # add individual transactions
  for $i (1 .. $form->{rowcount}) {
    if ($form->{"amount_$i"} != 0) {
      $project_id = 'NULL';
      if ("amount_$i" =~ /amount_/) {
        if ($form->{"project_id_$i"} && $form->{"projectnumber_$i"}) {
          $project_id = $form->{"project_id_$i"};
        }
      }
      if ("amount_$i" =~ /amount/) {
        $taxkey = $form->{AP_amounts}{"amount_$i"}{taxkey};
      }

      # insert detail records in acc_trans
      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate,
                                         project_id, taxkey)
                  VALUES ($form->{id}, (SELECT c.id FROM chart c
                                         WHERE c.accno = '$form->{AP_amounts}{"amount_$i"}'),
                    $form->{"amount_$i"}, '$form->{transdate}', $project_id, '$taxkey')|;
      $dbh->do($query) || $form->dberror($query);

      if ($form->{"tax_$i"} != 0) {

        # insert detail records in acc_trans
        $query =
          qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate,
                                          project_id, taxkey)
                    VALUES ($form->{id}, (SELECT c.id FROM chart c
                                          WHERE c.accno = '$form->{AP_amounts}{"tax_$i"}'),
                    $form->{"tax_$i"}, '$form->{transdate}', $project_id, '$taxkey')|;
        $dbh->do($query) || $form->dberror($query);
      }

    }
  }

  # add payables
  $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate,
                                      project_id)
              VALUES ($form->{id}, (SELECT c.id FROM chart c
                                    WHERE c.accno = '$form->{AP_amounts}{payables}'),
              $form->{payables}, '$form->{transdate}', $project_id)|;
  $dbh->do($query) || $form->dberror($query);

  # if there is no amount but a payment record a payable
  if ($form->{amount} == 0 && $form->{invtotal} == 0) {
    $form->{payables} = $form->{invpaid};
  }

  # add paid transactions
  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"} != 0) {

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
      $form->{"AP_paid_$i"} =~ s/\"//g;

      # get paid account

      ($form->{AP}{"paid_$i"}) = split(/--/, $form->{"AP_paid_$i"});
      $form->{"datepaid_$i"} = $form->{transdate}
        unless ($form->{"datepaid_$i"});

      # if there is no amount and invtotal is zero there is no exchangerate
      if ($form->{amount} == 0 && $form->{invtotal} == 0) {
        $form->{exchangerate} = $form->{"exchangerate_$i"};
      }

      $amount =
        $form->round_amount($form->{"paid_$i"} * $form->{exchangerate} * -1,
                            2);
      if ($form->{payables}) {
        $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
		    transdate)
		    VALUES ($form->{id},
		           (SELECT c.id FROM chart c
			    WHERE c.accno = '$form->{AP}{payables}'),
		    $amount, '$form->{"datepaid_$i"}')|;
        $dbh->do($query) || $form->dberror($query);
      }
      $form->{payables} = $amount;

      $form->{"memo_$i"} =~ s/\'/\'\'/g;

      # add payment
      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
                  transdate, source, memo)
                  VALUES ($form->{id},
		         (SELECT c.id FROM chart c
		          WHERE c.accno = '$form->{AP}{"paid_$i"}'),
		  $form->{"paid_$i"}, '$form->{"datepaid_$i"}',
		  '$form->{"source_$i"}', '$form->{"memo_$i"}')|;
      $dbh->do($query) || $form->dberror($query);

      # add exchange rate difference
      $amount =
        $form->round_amount(
                         $form->{"paid_$i"} * ($form->{"exchangerate_$i"} - 1),
                         2);
      if ($amount != 0) {
        $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
		    transdate, fx_transaction, cleared)
		    VALUES ($form->{id},
		           (SELECT c.id FROM chart c
			    WHERE c.accno = '$form->{AP}{"paid_$i"}'),
		    $amount, '$form->{"datepaid_$i"}', '1', '0')|;

        $dbh->do($query) || $form->dberror($query);
      }

      # exchangerate gain/loss
      $amount =
        $form->round_amount(
                        $form->{"paid_$i"} *
                          ($form->{exchangerate} - $form->{"exchangerate_$i"}),
                        2);

      if ($amount != 0) {
        $accno = ($amount > 0) ? $form->{fxgain_accno} : $form->{fxloss_accno};
        $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
		    transdate, fx_transaction, cleared)
		    VALUES ($form->{id}, (SELECT c.id FROM chart c
					  WHERE c.accno = '$accno'),
		    $amount, '$form->{"datepaid_$i"}', '1', '0')|;
        $dbh->do($query) || $form->dberror($query);
      }

      # update exchange rate record
      if (($form->{currency} ne $form->{defaultcurrency}) && !$exchangerate) {
        $form->update_exchangerate($dbh, $form->{currency},
                                   $form->{"datepaid_$i"},
                                   0, $form->{"exchangerate_$i"});
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

  my ($self, $myconfig, $form, $spool) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query = qq|DELETE FROM ap WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $query = qq|DELETE FROM acc_trans WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # commit and redirect
  my $rc = $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $rc;
}

sub ap_transactions {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT a.id, a.invnumber, a.transdate, a.duedate,
                 a.amount, a.paid, a.ordnumber, v.name, a.invoice,
	         a.netamount, a.datepaid, a.notes, e.name AS employee
	         FROM ap a
	      JOIN vendor v ON (a.vendor_id = v.id)
	      LEFT JOIN employee e ON (a.employee_id = e.id)|;

  my $where = "1 = 1";

  if ($form->{vendor_id}) {
    $where .= " AND a.vendor_id = $form->{vendor_id}";
  } else {
    if ($form->{vendor}) {
      my $vendor = $form->like(lc $form->{vendor});
      $where .= " AND lower(v.name) LIKE '$vendor'";
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
  push @a, "employee" if $self->{l_employee};
  my $sortorder = join ', ', $form->sort_columns(@a);
  $sortorder = $form->{sort} if $form->{sort};

  $query .= "WHERE $where
             ORDER by $sortorder";

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ap = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{AP} }, $ap;
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

1;

