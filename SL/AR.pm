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
use SL::DBUtils;

sub post_transaction {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my ($query, $sth, $null, $taxrate, $amount, $tax);
  my $exchangerate = 0;
  my $i;

  my @values;

  my $dbh = $form->dbconnect_noauto($myconfig);

  # set exchangerate
  $form->{exchangerate} = ($form->{currency} eq $form->{defaultcurrency}) ? 1 :
      ( $form->check_exchangerate($myconfig, $form->{currency}, $form->{transdate}, 'buy') ||
        $form->parse_amount($myconfig, $form->{exchangerate}) );

  # get the charts selected
  map { ($form->{AR_amounts}{"amount_$_"}) = split /--/, $form->{"AR_amount_$_"} } 1 .. $form->{rowcount};

  $form->{AR_amounts}{receivables} = $form->{ARselected};
  $form->{AR}{receivables}         = $form->{ARselected};

  # parsing
  for $i (1 .. $form->{rowcount}) {
    $form->{"amount_$i"} = $form->round_amount($form->parse_amount($myconfig, $form->{"amount_$i"}) * $form->{exchangerate}, 2);
    $form->{amount}     += $form->{"amount_$i"};
    $form->{"tax_$i"}    = $form->parse_amount($myconfig, $form->{"tax_$i"});
  }

  # this is for ar
  $form->{tax}       = 0;
  $form->{netamount} = 0;
  $form->{total_tax} = 0;

  # taxincluded doesn't make sense if there is no amount
  $form->{taxincluded} = 0 unless $form->{amount};

  for $i (1 .. $form->{rowcount}) {
    ($form->{"tax_id_$i"}) = split /--/, $form->{"taxchart_$i"};

    $query = qq|SELECT c.accno, t.taxkey, t.rate FROM tax t LEFT JOIN chart c ON (c.id = t.chart_id) WHERE t.id = ? ORDER BY c.accno|;
    ($form->{AR_amounts}{"tax_$i"}, $form->{"taxkey_$i"}, $form->{"taxrate_$i"}) = selectrow_query($form, $dbh, $query, $form->{"tax_id_$i"});

    $form->{AR_amounts}{"tax_$i"}{taxkey}    = $form->{"taxkey_$i"};
    $form->{AR_amounts}{"amounts_$i"}{taxkey} = $form->{"taxkey_$i"};

    if ($form->{taxincluded} *= 1) {
      $tax = $form->{"korrektur_$i"}
        ? $form->{"tax_$i"}
        : $form->{"amount_$i"} - ($form->{"amount_$i"} / ($form->{"taxrate_$i"} + 1)); # should be same as taxrate * amount / (taxrate + 1)
      $form->{"amount_$i"} = $form->round_amount($form->{"amount_$i"} - $tax, 2);
      $form->{"tax_$i"}    = $form->round_amount($tax, 2);
    } else {
      $form->{"tax_$i"}    = $form->{"amount_$i"} * $form->{"taxrate_$i"} unless $form->{"korrektur_$i"};
      $form->{"tax_$i"}    = $form->round_amount($form->{"tax_$i"} * $form->{exchangerate}, 2);
    }
    $form->{netamount}  += $form->{"amount_$i"};
    $form->{total_tax}  += $form->{"tax_$i"};
  }

  # adjust paidaccounts if there is no date in the last row
  $form->{paidaccounts}-- unless $form->{"datepaid_$form->{paidaccounts}"};
  $form->{paid} = 0;

  # add payments
  for $i (1 .. $form->{paidaccounts}) {
    $form->{"paid_$i"} = $form->round_amount($form->parse_amount($myconfig, $form->{"paid_$i"}), 2);
    $form->{paid}     += $form->{"paid_$i"};
    $form->{datepaid}  = $form->{"datepaid_$i"};
  }

  $form->{amount} = $form->{netamount} + $form->{total_tax};
  $form->{paid}   = $form->round_amount($form->{paid} * $form->{exchangerate}, 2);

  ($null, $form->{employee_id}) = split /--/, $form->{employee};

  $form->get_employee($dbh) unless $form->{employee_id};

  # if we have an id delete old records else make one
  if ($form->{id}) {
    # delete detail records
    $query = qq|DELETE FROM acc_trans WHERE trans_id = ?|;
    do_query($form, $dbh, $query, $form->{id});
  } else {
    $query = qq|SELECT nextval('glid')|;
    ($form->{id}) = selectrow_query($form, $dbh, $query);
    $query = qq|INSERT INTO ar (id, invnumber, employee_id) VALUES (?, 'dummy', ?)|;
    do_query($form, $dbh, $query, $form->{id}, $form->{employee_id});
    $form->{invnumber} = $form->update_defaults($myconfig, "invnumber", $dbh) unless $form->{invnumber};
  }

  # update department
  ($null, $form->{department_id}) = split(/--/, $form->{department});
  $form->{department_id} *= 1;

  # record last payment date in ar table
  $form->{datepaid} ||= $form->{transdate} ;
  my $datepaid = ($form->{paid} != 0) ? $form->{datepaid} : undef;

  $query =
    qq|UPDATE ar set
         invnumber = ?, ordnumber = ?, transdate = ?, customer_id = ?,
         taxincluded = ?, amount = ?, duedate = ?, paid = ?, datepaid = ?,
         netamount = ?, curr = ?, notes = ?, department_id = ?,
         employee_id = ?
       WHERE id = ?|;
  my @values = ($form->{invnumber}, $form->{ordnumber}, conv_date($form->{transdate}), conv_i($form->{customer_id}), $form->{taxincluded} ? 't' : 'f', $form->{amount},
                conv_date($form->{duedate}), $form->{paid}, conv_date($datepaid), $form->{netamount}, $form->{currency}, $form->{notes}, conv_i($form->{department_id}),
                conv_i($form->{employee_id}), conv_i($form->{id}));
  do_query($form, $dbh, $query, @values);

  # amount for AR account
  $form->{receivables} = $form->round_amount($form->{amount}, 2) * -1;

  # update exchangerate
  $form->update_exchangerate($dbh, $form->{currency}, $form->{transdate}, $form->{exchangerate}, 0)
    if ($form->{currency} ne $form->{defaultcurrency}) && $form->check_exchangerate($myconfig, $form->{currency}, $form->{transdate}, 'buy');


  # add individual transactions for AR, amount and taxes
  for $i (1 .. $form->{rowcount}) {
    if ($form->{"amount_$i"} != 0) {
      my $project_id = conv_i($form->{"project_id_$i"});
      $taxkey = $form->{AR_amounts}{"amounts_$i"}{taxkey};

      # insert detail records in acc_trans
      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, project_id, taxkey)
                   VALUES (?, (SELECT c.id FROM chart c WHERE c.accno = ?), ?, ?, ?, ?)|;
      @values = (conv_i($form->{id}), conv_i($form->{AR_amounts}{"amount_$i"}), conv_i($form->{"amount_$i"}), conv_date($form->{transdate}), $project_id, conv_i($taxkey));
      do_query($form, $dbh, $query, @values);

      if ($form->{"tax_$i"} != 0) {
        # insert detail records in acc_trans
        $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, project_id, taxkey)
                     VALUES (?, (SELECT c.id FROM chart c WHERE c.accno = ?), ?, ?, ?, ?)|;
        @values = (conv_i($form->{id}), conv_i($form->{AR_amounts}{"tax_$i"}), conv_i($form->{"tax_$i"}), conv_date($form->{transdate}), $project_id, conv_i($taxkey));
        do_query($form, $dbh, $query, @values);
      }
    }
  }

  # add recievables
  $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, taxkey)
               VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, (SELECT taxkey_id FROM chart WHERE accno = ?))|;
  @values = (conv_i($form->{id}), $form->{AR_amounts}{receivables}, conv_i($form->{receivables}), conv_date($form->{transdate}), $form->{AR_amounts}{receivables});
  do_query($form, $dbh, $query, @values);

  # add paid transactions
  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"} != 0) {
      my $project_id = conv_i($form->{"paid_project_id_$i"});

      $form->{"AR_paid_$i"} =~ s/\"//g;
      ($form->{AR}{"paid_$i"}) = split(/--/, $form->{"AR_paid_$i"});
      $form->{"datepaid_$i"} = $form->{transdate}
        unless ($form->{"datepaid_$i"});

      $form->{"exchangerate_$i"} = ($form->{currency} eq $form->{defaultcurrency}) ? 1 :
        ( $form->check_exchangerate($myconfig, $form->{currency}, $form->{"datepaid_$i"}, 'buy') ||
          $form->parse_amount($myconfig, $form->{"exchangerate_$i"}) );

      # if there is no amount and invtotal is zero there is no exchangerate
      $form->{exchangerate} = $form->{"exchangerate_$i"}
        if ($form->{amount} == 0 && $form->{netamount} == 0);

      # receivables amount
      $amount = $form->round_amount($form->{"paid_$i"} * $form->{exchangerate}, 2);

      if ($form->{receivables} != 0) {
        # add receivable
        $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, project_id, taxkey)
                     VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, ?, (SELECT taxkey_id FROM chart WHERE accno = ?))|;
        @values = (conv_i($form->{id}), $form->{AR}{receivables}, $amount, conv_date($form->{"datepaid_$i"}), $project_id, $form->{AR}{receivables});
        do_query($form, $dbh, $query, @values);
      }
      $form->{receivables} = $amount;

      if ($form->{"paid_$i"} != 0) {
        my $project_id = conv_i($form->{"paid_project_id_$i"});
        # add payment
        $amount = $form->{"paid_$i"} * -1;
        $query  = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, source, memo, project_id, taxkey)
                     VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, ?, ?, ?, (SELECT taxkey_id FROM chart WHERE accno = ?))|;
        @values = (conv_i($form->{id}), $form->{AR}{"paid_$i"}, $amount, conv_date($form->{"datepaid_$i"}), $form->{"source_$i"}, $form->{"memo_$i"}, $project_id, $form->{AR}{"paid_$i"});
        do_query($form, $dbh, $query, @values);

        # exchangerate difference for payment
        $amount = $form->round_amount( $form->{"paid_$i"} * ($form->{"exchangerate_$i"} - 1) * -1, 2);

        if ($amount != 0) {
          $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, fx_transaction, cleared, project_id, taxkey)
                       VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, 't', 'f', ?, (SELECT taxkey_id FROM chart WHERE accno = ?))|;
          @values = (conv_i($form->{id}), $form->{AR}{"paid_$i"}, $amount, conv_date($form->{"datepaid_$i"}), $project_id, $form->{AR}{"paid_$i"});
          do_query($form, $dbh, $query, @values);
        }

        # exchangerate gain/loss
        $amount = $form->round_amount( $form->{"paid_$i"} * ($form->{exchangerate} - $form->{"exchangerate_$i"}) * -1, 2);

        if ($amount != 0) {
          $accno = ($amount > 0) ? $form->{fxgain_accno} : $form->{fxloss_accno};
          $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, fx_transaction, cleared, project_id, taxkey)
                       VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, 't', 'f', ?, (SELECT taxkey_id FROM chart WHERE accno = ?))|;
          @values = (conv_i($form->{id}), $accno, $amount, conv_date($form->{"datepaid_$i"}), $project_id, $accno);
          do_query($form, $dbh, $query, @values);
        }
      }

      # update exchangerate record
      $form->update_exchangerate($dbh, $form->{currency}, $form->{"datepaid_$i"}, $form->{"exchangerate_$i"}, 0)
        if ($form->{currency} ne $form->{defaultcurrency}) && !$form->check_exchangerate($myconfig, $form->{currency}, $form->{"datepaid_$i"}, 'buy');
    }
  }

  my $rc = $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub() and return $rc;
}

sub post_payment {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $locale) = @_;

  # connect to database, turn off autocommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  $form->{datepaid} = $form->{transdate};

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

  $form->{exchangerate} =
      $form->get_exchangerate($dbh, $form->{currency}, $form->{transdate},
                              "buy");

  my $accno_ar = $form->{ARselected};

  # record payments and offsetting AR
  for my $i (1 .. $form->{paidaccounts}) {

    if ($form->{"paid_$i"} != 0) {
      my $project_id = conv_i($form->{"paid_project_id_$i"});

      my ($accno) = split /--/, $form->{"AR_paid_$i"};
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

      # record AR
      $amount =
        $form->round_amount($form->{"paid_$i"} * $form->{"exchangerate"},
                            2);


      $query =
        qq|DELETE FROM acc_trans | .
        qq|WHERE trans_id = ? AND amount = ? AND transdate = ? AND | .
        qq|  chart_id = (SELECT c.id FROM chart c WHERE c.accno = ?)|;
      @values = (conv_i($form->{id}), $amount,
                 conv_date($form->{"datepaid_$i"}), $accno_ar);
      do_query($form, $dbh, $query, @values);

      $query =
        qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, project_id, taxkey) | .
        qq|VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, ?, | .
        qq|        (SELECT taxkey_id FROM chart WHERE accno = ?))|;
      @values = (conv_i($form->{id}), $accno_ar, conv_i($amount),
                 conv_date($form->{"datepaid_$i"}), $project_id, $accno_ar);
      do_query($form, $dbh, $query, @values);

      # record payment
      $form->{"paid_$i"} *= -1;

      $query =
        qq|DELETE FROM acc_trans | .
        qq|WHERE trans_id = ? AND | .
        qq|  chart_id = (SELECT c.id FROM chart c WHERE c.accno = ?) AND | .
        qq|  amount = ? AND transdate = ? AND source = ? AND memo = ?|;
      @values = (conv_i($form->{id}), $accno, conv_i($form->{"paid_$i"}),
                 conv_date($form->{"datepaid_$i"}),
                 $form->{"source_$i"}, $form->{"memo_$i"});
      do_query($form, $dbh, $query, @values);

      $query =
        qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, source, memo, project_id, taxkey) | .
        qq|VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, ?, ?, ?, | .
        qq|        (SELECT taxkey_id FROM chart WHERE accno = ?))|;
      @values = (conv_i($form->{id}), $accno, conv_i($form->{"paid_$i"}),
                 conv_date($form->{"datepaid_$i"}),
                 $form->{"source_$i"}, $form->{"memo_$i"}, $project_id, $accno);
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
          qq|WHERE trans_id = ? AND | .
          qq|  chart_id = (SELECT c.id FROM chart c WHERE c.accno = ?) AND | .
          qq|  amount = ? AND transdate = ? AND cleared = 'f' AND fx_transaction = 't'|;
        @values = (conv_i($form->{id}), $accno,
                   conv_i($form->{fx}{$accno}{$transdate}),
                   conv_date($transdate));
        do_query($form, $dbh, $query, @values);

        $query =
          qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, cleared, fx_transaction, project_id, taxkey) | .
          qq|VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, 'f', 't', ?, | .
          qq|        (SELECT taxkey_id FROM chart WHERE accno = ?))|;
        @values = (conv_i($form->{id}), $accno,
                   $form->{fx}{$accno}{$transdate},
                   conv_date($transdate), $project_id,
                   $form->{fx}{$accno}{$transdate});
        do_query($form, $dbh, $query, @values);
      }
    }
  }
  my $datepaid = ($form->{paid}) ? $form->{datepaid} : "NULL";

  # save AR record
  my $query =
    qq|UPDATE ar set paid = ?, datepaid = ? WHERE id = ?|;
  @values = (conv_i($form->{paid}), conv_date($datepaid), conv_i($form->{id}));
  do_query($form, $dbh, $query, @values);

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

  my $query = qq|DELETE FROM ar WHERE id = ?|;
  do_query($form, $dbh, $query, $form->{id});

  $query = qq|DELETE FROM acc_trans WHERE trans_id = ?|;
  do_query($form, $dbh, $query, $form->{id});

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

  my @values;

  my $query =
    qq|SELECT a.id, a.invnumber, a.ordnumber, a.transdate, | .
    qq|  a.duedate, a.netamount, a.amount, a.paid, | .
    qq|  a.invoice, a.datepaid, a.terms, a.notes, a.shipvia, | .
    qq|  a.shippingpoint, a.storno, a.globalproject_id, | .
    qq|  a.transaction_description, | .
    qq|  pr.projectnumber AS globalprojectnumber, | .
    qq|  c.name, | .
    qq|  e.name AS employee | .
    qq|FROM ar a | .
    qq|JOIN customer c ON (a.customer_id = c.id) | .
    qq|LEFT JOIN employee e ON (a.employee_id = e.id) | .
    qq|LEFT JOIN project pr ON (a.globalproject_id = pr.id)|;

  my $where = "1 = 1";
  if ($form->{customer_id}) {
    $where .= " AND a.customer_id = ?";
    push(@values, $form->{customer_id});
  } elsif ($form->{customer}) {
    $where .= " AND c.name ILIKE ?";
    push(@values, $form->like($form->{customer}));
  }
  if ($form->{department}) {
    my ($null, $department_id) = split /--/, $form->{department};
    $where .= " AND a.department_id = ?";
    push(@values, $department_id);
  }
  foreach my $column (qw(invnumber ordnumber notes transaction_description)) {
    if ($form->{$column}) {
      $where .= " AND a.$column ILIKE ?";
      push(@values, $form->like($form->{$column}));
    }
  }
  if ($form->{"project_id"}) {
    $where .=
      qq|AND ((a.globalproject_id = ?) OR EXISTS | .
      qq|  (SELECT * FROM invoice i | .
      qq|   WHERE i.project_id = ? AND i.trans_id = a.id))|;
    push(@values, $form->{"project_id"}, $form->{"project_id"});
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

  my @a = (transdate, invnumber, name);
  push @a, "employee" if $form->{l_employee};
  my $sortorder = join(', ', @a);

  if (grep({ $_ eq $form->{sort} }
           qw(id transdate duedate invnumber ordnumber name
              datepaid employee shippingpoint shipvia))) {
    $sortorder = $form->{sort};
  }

  $query .= " WHERE $where ORDER by $sortorder";

  my $sth = $dbh->prepare($query);
  $sth->execute(@values) ||
    $form->dberror($query . " (" . join(", ", @values) . ")");

  $form->{AR} = [];
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

