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

use SL::DBUtils;

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
    ($form->{"tax_id_$i"}, $NULL) = split /--/, $form->{"taxchart_$i"};

    $query =
      qq|SELECT c.accno, t.taxkey, t.rate | .
      qq|FROM tax t LEFT JOIN chart c on (c.id=t.chart_id) | .
      qq|WHERE t.id = ? | .
      qq|ORDER BY c.accno|;
    $sth = $dbh->prepare($query);
    $sth->execute($form->{"tax_id_$i"}) || $form->dberror($query . " (" . $form->{"tax_id_$i"} . ")");
    ($form->{AP_amounts}{"tax_$i"}, $form->{"taxkey_$i"}, $form->{"taxrate_$i"}) =
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
    $query = qq|DELETE FROM acc_trans WHERE trans_id = ?|;
    do_query($form, $dbh, $query, $form->{id});

  } else {
    my $uid = rand() . time;

    $uid .= $form->{login};

    $uid = substr($uid, 2, 75);

    $query =
      qq|INSERT INTO ap (invnumber, employee_id) | .
      qq|VALUES (?, (SELECT e.id FROM employee e WHERE e.login = ?))|;
    do_query($form, $dbh, $query, $uid, $form->{login});

    $query = qq|SELECT a.id FROM ap a
                WHERE a.invnumber = ?|;
    ($form->{id}) = selectrow_query($form, $dbh, $query, $uid);
  }

  $form->{invnumber} = $form->{id} unless $form->{invnumber};

  $form->{datepaid} = $form->{transdate} unless ($form->{datepaid});
  my $datepaid = ($form->{invpaid} != 0) ? $form->{datepaid} : undef;

  $query = qq|UPDATE ap SET
              invnumber = ?,
              transdate = ?,
              ordnumber = ?,
              vendor_id = ?,
              taxincluded = ?,
              amount = ?,
              duedate = ?,
              paid = ?,
              datepaid = ?,
              netamount = ?,
              curr = ?,
              notes = ?,
              department_id = ?
              WHERE id = ?|;
  my @values = ($form->{invnumber}, conv_date($form->{transdate}),
                $form->{ordnumber}, conv_i($form->{vendor_id}),
                $form->{taxincluded} ? 't' : 'f', $form->{invtotal},
                conv_date($form->{duedate}), $form->{invpaid},
                conv_date($datepaid), $form->{netamount},
                $form->{currency}, $form->{notes},
                conv_i($form->{department_id}), $form->{id});
  do_query($form, $dbh, $query, @values);

  # update exchangerate
  if (($form->{currency} ne $form->{defaultcurrency}) && !$exchangerate) {
    $form->update_exchangerate($dbh, $form->{currency}, $form->{transdate}, 0,
                               $form->{exchangerate});
  }

  # add individual transactions
  for $i (1 .. $form->{rowcount}) {
    if ($form->{"amount_$i"} != 0) {
      my $project_id;
      $project_id = conv_i($form->{"project_id_$i"});
      $taxkey = $form->{AP_amounts}{"amount_$i"}{taxkey};

      # insert detail records in acc_trans
      $query =
        qq|INSERT INTO acc_trans | .
        qq|  (trans_id, chart_id, amount, transdate, project_id, taxkey)| .
        qq|VALUES (?, (SELECT c.id FROM chart c WHERE c.accno = ?), | .
        qq|  ?, ?, ?, ?)|;
      @values = ($form->{id}, $form->{AP_amounts}{"amount_$i"},
                 $form->{"amount_$i"}, conv_date($form->{transdate}),
                 $project_id, $taxkey);
      do_query($form, $dbh, $query, @values);

      if ($form->{"tax_$i"} != 0) {
        # insert detail records in acc_trans
        $query =
          qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, | .
          qq|  project_id, taxkey) | .
          qq|VALUES (?, (SELECT c.id FROM chart c WHERE c.accno = ?), | .
          qq|  ?, ?, ?, ?)|;
        @values = ($form->{id}, $form->{AP_amounts}{"tax_$i"},
                   $form->{"tax_$i"}, conv_date($form->{transdate}),
                   $project_id, $taxkey);
        do_query($form, $dbh, $query, @values);
      }

    }
  }

  # add payables
  $query =
    qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, taxkey) | .
    qq|VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, | .
    qq|        (SELECT taxkey_id FROM chart WHERE accno = ?))|;
  @values = ($form->{id}, $form->{AP_amounts}{payables}, $form->{payables},
             conv_date($form->{transdate}), $form->{AP_amounts}{payables});
  do_query($form, $dbh, $query, @values);

  # if there is no amount but a payment record a payable
  if ($form->{amount} == 0 && $form->{invtotal} == 0) {
    $form->{payables} = $form->{invpaid};
  }

  # add paid transactions
  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"} != 0) {
      my $project_id = conv_i($form->{"paid_project_id_$i"});

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
        $query =
          qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, project_id, taxkey) | .
          qq|VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, ?, | .
          qq|        (SELECT taxkey_id FROM chart WHERE accno = ?))|;
        @values = ($form->{id}, $form->{AP}{payables}, $amount,
                   conv_date($form->{"datepaid_$i"}), $project_id,
                   $form->{AP}{payables});
        do_query($form, $dbh, $query, @values);
      }
      $form->{payables} = $amount;

      # add payment
      $query =
        qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, source, memo, project_id, taxkey) | .
        qq|VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, ?, ?, ?, | .
        qq|        (SELECT taxkey_id FROM chart WHERE accno = ?))|;
      @values = ($form->{id}, $form->{AP}{"paid_$i"}, $form->{"paid_$i"},
                 conv_date($form->{"datepaid_$i"}), $form->{"source_$i"},
                 $form->{"memo_$i"}, $project_id, $form->{AP}{"paid_$i"});
      do_query($form, $dbh, $query, @values);

      # add exchange rate difference
      $amount =
        $form->round_amount($form->{"paid_$i"} *
                            ($form->{"exchangerate_$i"} - 1), 2);
      if ($amount != 0) {
        $query =
          qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, fx_transaction, cleared, project_id, taxkey) | .
          qq|VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, 't', 'f', ?, | .
          qq|        (SELECT taxkey_id FROM chart WHERE accno = ?))|;
        @values = ($form->{id}, $form->{AP}{"paid_$i"}, $amount,
                   conv_date($form->{"datepaid_$i"}), $project_id,
                   $form->{AP}{"paid_$i"});
        do_query($form, $dbh, $query, @values);
      }

      # exchangerate gain/loss
      $amount =
        $form->round_amount($form->{"paid_$i"} *
                            ($form->{exchangerate} -
                             $form->{"exchangerate_$i"}), 2);

      if ($amount != 0) {
        $query =
          qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, fx_transaction, cleared, project_id, taxkey) | .
          qq|VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, 't', 'f', ?, | .
          qq|        (SELECT taxkey_id FROM chart WHERE accno = ?))|;
        @values = ($form->{id}, ($amount > 0) ?
                   $form->{fxgain_accno} : $form->{fxloss_accno},
                   $amount, conv_date($form->{"datepaid_$i"}), $project_id,
                   ($amount > 0) ?
                   $form->{fxgain_accno} : $form->{fxloss_accno});
        do_query($form, $dbh, $query, @values);
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

  my $query = qq|DELETE FROM ap WHERE id = ?|;
  do_query($form, $dbh, $query, $form->{id});

  $query = qq|DELETE FROM acc_trans WHERE trans_id = ?|;
  do_query($form, $dbh, $query, $form->{id});

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

  my $query =
    qq|SELECT a.id, a.invnumber, a.transdate, a.duedate, a.amount, a.paid, | .
    qq|  a.ordnumber, v.name, a.invoice, a.netamount, a.datepaid, a.notes, | .
    qq|  a.globalproject_id, | .
    qq|  pr.projectnumber AS globalprojectnumber, | .
    qq|  e.name AS employee | .
    qq|FROM ap a | .
    qq|JOIN vendor v ON (a.vendor_id = v.id) | .
    qq|LEFT JOIN employee e ON (a.employee_id = e.id) | .
    qq|LEFT JOIN project pr ON (a.globalproject_id = pr.id) |;

  my $where = qq| WHERE storno != true |;
  my @values;

  if ($form->{vendor_id}) {
    $where .= " AND a.vendor_id = ?";
    push(@values, $form->{vendor_id});
  } elsif ($form->{vendor}) {
    $where .= " AND v.name ILIKE ?";
    push(@values, $form->like($form->{vendor}));
  }
  if ($form->{department}) {
    my ($null, $department_id) = split /--/, $form->{department};
    $where .= " AND a.department_id = ?";
    push(@values, $department_id);
  }
  if ($form->{invnumber}) {
    $where .= " AND a.invnumber ILIKE ?";
    push(@values, $form->like($form->{invnumber}));
  }
  if ($form->{ordnumber}) {
    $where .= " AND a.ordnumber ILIKE ?";
    push(@values, $form->like($form->{ordnumber}));
  }
  if ($form->{notes}) {
    $where .= " AND lower(a.notes) LIKE ?";
    push(@values, $form->like($form->{notes}));
  }
  if ($form->{project_id}) {
    $where .=
      qq|AND ((a.globalproject_id = ?) OR EXISTS | .
      qq|  (SELECT * FROM invoice i | .
      qq|   WHERE i.project_id = ? AND i.trans_id = a.id))|;
    push(@values, $form->{project_id}, $form->{project_id});
  }

  if ($form->{transdatefrom}) {
    $where .= " AND a.transdate >= ?";
    push(@values, $form->{transdatefrom});
  }
  if ($form->{transdateto}) {
    $where .= " AND a.transdate <= ?";
    push(@values, $form->{transdateto});
  }
  if ($form->{open} || $form->{closed}) {
    unless ($form->{open} && $form->{closed}) {
      $where .= " AND a.amount <> a.paid" if ($form->{open});
      $where .= " AND a.amount = a.paid"  if ($form->{closed});
    }
  }

  if ($where) {
#     substr($where, 0, 4) = "WHERE";
    $query .= $where;
  }

  my @a = (transdate, invnumber, name);
  push @a, "employee" if $self->{l_employee};
  my $sortorder = join(', ', @a);

  if (grep({ $_ eq $form->{sort} }
           qw(transdate id invnumber ordnumber name netamount tax amount
              paid datepaid due duedate notes employee))) {
    $sortorder = $form->{sort};
  }

  $query .= " ORDER by $sortorder";

  my $sth = $dbh->prepare($query);
  $sth->execute(@values) ||
    $form->dberror($query . " (" . join(", ", @values) . ")");

  $form->{AP} = [];
  while (my $ap = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{AP} }, $ap;
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
    "  (SELECT transdate FROM ap WHERE id = " .
    "    (SELECT MAX(id) FROM ap) LIMIT 1), " .
    "  current_date)";
  ($form->{transdate}) = $dbh->selectrow_array($query);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}


sub post_payment {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $locale) = @_;

  # connect to database, turn off autocommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  $form->{datepaid} = $form->{transdate};

  # total payments, don't move we need it here
  for my $i (1 .. $form->{paidaccounts}) {
    $form->{"paid_$i"} = $form->parse_amount($myconfig, $form->{"paid_$i"});
    $form->{paid} += $form->{"paid_$i"};
    $form->{datepaid} = $form->{"datepaid_$i"} if ($form->{"datepaid_$i"});
  }

  $form->{exchangerate} =
      $form->get_exchangerate($dbh, $form->{currency}, $form->{transdate},
                              "buy");

  my (@values, $query);

  my ($accno_ap) = split(/--/, $form->{APselected});

  # record payments and offsetting AP
  for my $i (1 .. $form->{paidaccounts}) {

    if ($form->{"paid_$i"} != 0) {
      my ($accno) = split /--/, $form->{"AP_paid_$i"};
      $form->{"datepaid_$i"} = $form->{transdate}
        unless ($form->{"datepaid_$i"});
      $form->{datepaid} = $form->{"datepaid_$i"};

      $exchangerate = 0;
      if (($form->{currency} eq $form->{defaultcurrency}) || ($form->{defaultcurrency} eq "")) {
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

      # record AP
      $amount =
        $form->round_amount($form->{"paid_$i"} * $form->{"exchangerate"},
                            2) * -1;

      $query =
        qq|DELETE FROM acc_trans | .
        qq|WHERE trans_id = ? | .
        qq|  AND chart_id = (SELECT c.id FROM chart c WHERE c.accno = ?) | .
        qq|  AND amount = ? AND transdate = ?|;
      @values = ($form->{id}, $accno_ap, $amount,
                 conv_date($form->{"datepaid_$i"}));
      do_query($form, $dbh, $query, @values);

      $query =
        qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, project_id, taxkey) | .
        qq|VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, ?, | .
        qq|        (SELECT taxkey_id FROM chart WHERE accno = ?))|;
      @values = ($form->{id}, $accno_ap, $amount,
                 conv_date($form->{"datepaid_$i"}),
                 conv_i($form->{"paid_project_id_$i"}), $accno_ap);
      do_query($form, $dbh, $query, @values);

      $query =
        qq|DELETE FROM acc_trans | .
        qq|WHERE trans_id = ? | .
        qq|  AND chart_id = (SELECT c.id FROM chart c WHERE c.accno = ?) | .
        qq|  AND amount = ? AND transdate = ? AND source = ? AND memo = ?|;
      @values = ($form->{id}, $accno, $form->{"paid_$i"},
                 conv_date($form->{"datepaid_$i"}), $form->{"source_$i"},
                 $form->{"memo_$i"});
      do_query($form, $dbh, $query, @values);

      $query =
        qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, source, memo, project_id, taxkey) | .
        qq|VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, ?, ?, ?, | .
        qq|        (SELECT taxkey_id FROM chart WHERE accno = ?))|;
      @values = ($form->{id}, $accno, $form->{"paid_$i"},
                 $form->{"datepaid_$i"},
                 $form->{"source_$i"}, $form->{"memo_$i"},
                 conv_i($form->{"paid_project_id_$i"}), $accno);
      do_query($form, $dbh, $query, @values);

      # gain/loss
      $amount =
        $form->{"paid_$i"} * $form->{exchangerate} - $form->{"paid_$i"} *
        $form->{"exchangerate_$i"};
      if ($amount > 0) {
        $form->{fx}{ $form->{fxgain_accno} }{ $form->{"datepaid_$i"} } +=
          $amount;
      } else {
        $form->{fx}{ $form->{fxloss_accno} }{ $form->{"datepaid_$i"} } +=
          $amount;
      }

      $diff = 0;

      # update exchange rate
      if (($form->{currency} ne $form->{defaultcurrency}) && !$exchangerate) {
        $form->update_exchangerate($dbh, $form->{currency},
                                   $form->{"datepaid_$i"},
                                   $form->{"exchangerate_$i"}, 0);
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
        $query =
          qq|DELETE FROM acc_trans | .
          qq|WHERE trans_id = ? AND chart_id = | .
          qq|  (SELECT c.id FROM chart c WHERE c.accno = ?) AND amount = ? | .
          qq|  AND transdate = ? AND cleared = 'f' AND fx_transaction = 't'|;
        @values = ($form->{id}, $accno, $form->{fx}{$accno}{$transdate},
                   conv_date($transdate),);
        do_query($form, $dbh, $query, @values);

        $query =
          qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, cleared, fx_transaction, taxkey) | .
          qq|VALUES (?, (SELECT c.id FROM chart c WHERE c.accno = ?), ?, ?, 'f', 't', | .
          qq|        (SELECT taxkey_id FROM chart WHERE accno = ?))|;
        @values = ($form->{id}, $accno, $form->{fx}{$accno}{$transdate},
                   conv_date($transdate), $accno);
        do_query($form, $dbh, $query, @values);
      }
    }
  }

  # save AP record
  my $query = qq|UPDATE ap SET paid = ?, datepaid = ? WHERE id = ?|;
  @values = ($form->{paid}, $form->{paid} ? $form->{datepaid} : undef,
             $form->{id});
  do_query($form, $dbh, $query, @values);

  my $rc = $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $rc;
}

1;

