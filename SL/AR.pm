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
use SL::MoreCommon;

our (%myconfig, $form);

sub post_transaction {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $provided_dbh, $payments_only) = @_;

  my ($query, $sth, $null, $taxrate, $amount, $tax);
  my $exchangerate = 0;
  my $i;

  my @values;

  my $dbh = $provided_dbh ? $provided_dbh : $form->dbconnect_noauto($myconfig);
  $form->{defaultcurrency} = $form->get_default_currency($myconfig);

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

    $form->{AR_amounts}{"tax_$i"}{taxkey}     = $form->{"taxkey_$i"};
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
  # this does not apply to stornos, where the paid field is set manually
  unless ($form->{storno}) {
    $form->{paidaccounts}-- unless $form->{"datepaid_$form->{paidaccounts}"};
    $form->{paid} = 0;

    # add payments
    for $i (1 .. $form->{paidaccounts}) {
      $form->{"paid_$i"} = $form->round_amount($form->parse_amount($myconfig, $form->{"paid_$i"}), 2);
      $form->{paid}     += $form->{"paid_$i"};
      $form->{datepaid}  = $form->{"datepaid_$i"};
    }

    $form->{amount} = $form->{netamount} + $form->{total_tax};
  }
  $form->{paid}   = $form->round_amount($form->{paid} * ($form->{exchangerate} || 1), 2);

  ($null, $form->{employee_id}) = split /--/, $form->{employee};

  $form->get_employee($dbh) unless $form->{employee_id};

  # if we have an id delete old records else make one
  if (!$payments_only) {
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
  }

  # update department
  ($null, $form->{department_id}) = split(/--/, $form->{department});
  $form->{department_id} *= 1;

  # record last payment date in ar table
  $form->{datepaid} ||= $form->{transdate} ;
  my $datepaid = ($form->{paid} != 0) ? $form->{datepaid} : undef;

  # amount for AR account
  $form->{receivables} = $form->round_amount($form->{amount}, 2) * -1;

  # update exchangerate
  $form->update_exchangerate($dbh, $form->{currency}, $form->{transdate}, $form->{exchangerate}, 0)
    if ($form->{currency} ne $form->{defaultcurrency}) && !$form->check_exchangerate($myconfig, $form->{currency}, $form->{transdate}, 'buy');

  if (!$payments_only) {
    $query =
      qq|UPDATE ar set
           invnumber = ?, ordnumber = ?, transdate = ?, customer_id = ?,
           taxincluded = ?, amount = ?, duedate = ?, paid = ?, datepaid = ?,
           netamount = ?, curr = ?, notes = ?, department_id = ?,
           employee_id = ?, storno = ?, storno_id = ?
         WHERE id = ?|;
    my @values = ($form->{invnumber}, $form->{ordnumber}, conv_date($form->{transdate}), conv_i($form->{customer_id}), $form->{taxincluded} ? 't' : 'f', $form->{amount},
                  conv_date($form->{duedate}), $form->{paid}, conv_date($datepaid), $form->{netamount}, $form->{currency}, $form->{notes}, conv_i($form->{department_id}),
                  conv_i($form->{employee_id}), $form->{storno} ? 't' : 'f', $form->{storno_id}, conv_i($form->{id}));
    do_query($form, $dbh, $query, @values);

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
  }

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

      if ($amount != 0) {
        # add receivable
        $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, project_id, taxkey)
                     VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, ?, (SELECT taxkey_id FROM chart WHERE accno = ?))|;
        @values = (conv_i($form->{id}), $form->{AR}{receivables}, $amount, conv_date($form->{"datepaid_$i"}), $project_id, $form->{AR}{receivables});
        do_query($form, $dbh, $query, @values);
      }

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

  my $rc = 1;
  if (!$provided_dbh) {
    $rc = $dbh->commit();
    $dbh->disconnect();
  }

  $main::lxdebug->leave_sub() and return $rc;
}

sub _delete_payments {
  $main::lxdebug->enter_sub();

  my ($self, $form, $dbh) = @_;

  my @delete_oids;

  # Delete old payment entries from acc_trans.
  my $query =
    qq|SELECT oid
       FROM acc_trans
       WHERE (trans_id = ?) AND fx_transaction

       UNION

       SELECT at.oid
       FROM acc_trans at
       LEFT JOIN chart c ON (at.chart_id = c.id)
       WHERE (trans_id = ?) AND (c.link LIKE '%AR_paid%')|;
  push @delete_oids, selectall_array_query($form, $dbh, $query, conv_i($form->{id}), conv_i($form->{id}));

  $query =
    qq|SELECT at.oid
       FROM acc_trans at
       LEFT JOIN chart c ON (at.chart_id = c.id)
       WHERE (trans_id = ?)
         AND ((c.link = 'AR') OR (c.link LIKE '%:AR') OR (c.link LIKE 'AR:%'))
       ORDER BY at.oid
       OFFSET 1|;
  push @delete_oids, selectall_array_query($form, $dbh, $query, conv_i($form->{id}));

  if (@delete_oids) {
    $query = qq|DELETE FROM acc_trans WHERE oid IN (| . join(", ", @delete_oids) . qq|)|;
    do_query($form, $dbh, $query);
  }

  $main::lxdebug->leave_sub();
}

sub post_payment {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $locale) = @_;

  # connect to database, turn off autocommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  my (%payments, $old_form, $row, $item, $query, %keep_vars);

  $old_form = save_form();

  # Delete all entries in acc_trans from prior payments.
  $self->_delete_payments($form, $dbh);

  # Save the new payments the user made before cleaning up $form.
  my $payments_re = '^datepaid_\d+$|^memo_\d+$|^source_\d+$|^exchangerate_\d+$|^paid_\d+$|^paid_project_id_\d+$|^AR_paid_\d+$|^paidaccounts$';
  map { $payments{$_} = $form->{$_} } grep m/$payments_re/, keys %{ $form };

  # Clean up $form so that old content won't tamper the results.
  %keep_vars = map { $_, 1 } qw(login password id);
  map { delete $form->{$_} unless $keep_vars{$_} } keys %{ $form };

  # Retrieve the invoice from the database.
  $form->create_links('AR', $myconfig, 'customer', $dbh);

  # Restore the payment options from the user input.
  map { $form->{$_} = $payments{$_} } keys %payments;

  # Set up the content of $form in the way that AR::post_transaction() expects.

  $self->setup_form($form);

  ($form->{defaultcurrency}) = selectrow_query($form, $dbh, qq|SELECT curr FROM defaults|);
  $form->{defaultcurrency}   = (split m/:/, $form->{defaultcurrency})[0];

  $form->{exchangerate}      = $form->format_amount($myconfig, $form->{exchangerate});

  # Get the AR accno (which is normally done by Form::create_links()).
  $query =
    qq|SELECT c.accno
       FROM acc_trans at
       LEFT JOIN chart c ON (at.chart_id = c.id)
       WHERE (trans_id = ?)
         AND ((c.link = 'AR') OR (c.link LIKE '%:AR') OR (c.link LIKE 'AR:%'))
       ORDER BY at.oid
       LIMIT 1|;

  ($form->{ARselected}) = selectfirst_array_query($form, $dbh, $query, conv_i($form->{id}));

  # Post the new payments.
  $self->post_transaction($myconfig, $form, $dbh, 1);

  restore_form($old_form);

  my $rc = $dbh->commit();
  $dbh->disconnect();

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
    qq|  a.shippingpoint, a.storno, a.storno_id, a.globalproject_id, | .
    qq|  a.marge_total, a.marge_percent, | .
    qq|  a.transaction_description, | .
    qq|  pr.projectnumber AS globalprojectnumber, | .
    qq|  c.name, | .
    qq|  e.name AS employee, | .
    qq|  e2.name AS salesman | .
    qq|FROM ar a | .
    qq|JOIN customer c ON (a.customer_id = c.id) | .
    qq|LEFT JOIN employee e ON (a.employee_id = e.id) | .
    qq|LEFT JOIN employee e2 ON (a.salesman_id = e2.id) | .
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
  my $sortdir   = !defined $form->{sortdir} ? 'ASC' : $form->{sortdir} ? 'ASC' : 'DESC';
  my $sortorder = join(', ', map { "$_ $sortdir" } @a);

  if (grep({ $_ eq $form->{sort} } qw(id transdate duedate invnumber ordnumber name datepaid employee shippingpoint shipvia transaction_description))) {
    $sortorder = $form->{sort} . " $sortdir";
  }

  $query .= " WHERE $where ORDER BY $sortorder";

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

sub setup_form {
  $main::lxdebug->enter_sub();

  my ($self, $form) = @_;

  my ($exchangerate, $key, $akey, $i, $j, $k, $index, $taxamount, $totaltax, $taxrate, $diff);

  # forex
  $form->{forex} = $form->{exchangerate};
  $exchangerate  = $form->{exchangerate} ? $form->{exchangerate} : 1;

  foreach $key (keys %{ $form->{AR_links} }) {
    # if there is a value we have an old entry
    $j = 0;
    $k = 0;

    for $i (1 .. scalar @{ $form->{acc_trans}{$key} }) {
      if ($key eq "AR_paid") {
        $j++;
        $form->{"AR_paid_$j"} = $form->{acc_trans}{$key}->[$i-1]->{accno};

        # reverse paid
        $form->{"paid_$j"}            = $form->{acc_trans}{$key}->[$i - 1]->{amount} * -1;
        $form->{"datepaid_$j"}        = $form->{acc_trans}{$key}->[$i - 1]->{transdate};
        $form->{"source_$j"}          = $form->{acc_trans}{$key}->[$i - 1]->{source};
        $form->{"memo_$j"}            = $form->{acc_trans}{$key}->[$i - 1]->{memo};
        $form->{"forex_$j"}           = $form->{acc_trans}{$key}->[$i - 1]->{exchangerate};
        $form->{"exchangerate_$i"}    = $form->{"forex_$j"};
        $form->{"paid_project_id_$j"} = $form->{acc_trans}{$key}->[$i - 1]->{project_id};
        $form->{paidaccounts}++;

      } else {

        $akey = $key;
        $akey =~ s/AR_//;

        if ($key eq "AR_tax" || $key eq "AP_tax") {
          $form->{"${key}_$form->{acc_trans}{$key}->[$i-1]->{accno}"}  = "$form->{acc_trans}{$key}->[$i-1]->{accno}--$form->{acc_trans}{$key}->[$i-1]->{description}";
          $form->{"${akey}_$form->{acc_trans}{$key}->[$i-1]->{accno}"} = $form->round_amount($form->{acc_trans}{$key}->[$i - 1]->{amount} / $exchangerate, 2);

          if ($form->{"$form->{acc_trans}{$key}->[$i-1]->{accno}_rate"} > 0) {
            $totaltax += $form->{"${akey}_$form->{acc_trans}{$key}->[$i-1]->{accno}"};
            $taxrate  += $form->{"$form->{acc_trans}{$key}->[$i-1]->{accno}_rate"};

          } else {
            $totalwithholding += $form->{"${akey}_$form->{acc_trans}{$key}->[$i-1]->{accno}"};
            $withholdingrate  += $form->{"$form->{acc_trans}{$key}->[$i-1]->{accno}_rate"};
          }

          $index                 = $form->{acc_trans}{$key}->[$i - 1]->{index};
          $form->{"tax_$index"}  = $form->{acc_trans}{$key}->[$i - 1]->{amount};
          $totaltax             += $form->{"tax_$index"};

        } else {
          $k++;
          $form->{"${akey}_$k"} = $form->round_amount($form->{acc_trans}{$key}->[$i - 1]->{amount} / $exchangerate, 2);

          if ($akey eq 'amount') {
            $form->{rowcount}++;
            $totalamount += $form->{"${akey}_$i"};

            $form->{"oldprojectnumber_$k"} = $form->{acc_trans}{$key}->[$i-1]->{projectnumber};
            $form->{"projectnumber_$k"}    = $form->{acc_trans}{$key}->[$i-1]->{projectnumber};
            $form->{taxrate}               = $form->{acc_trans}{$key}->[$i - 1]->{rate};
            $form->{"project_id_$k"}       = $form->{acc_trans}{$key}->[$i-1]->{project_id};
          }

          $form->{"${key}_$i"} = "$form->{acc_trans}{$key}->[$i-1]->{accno}--$form->{acc_trans}{$key}->[$i-1]->{description}";

          if ($akey eq "AR") {
            $form->{ARselected} = $form->{acc_trans}{$key}->[$i-1]->{accno};

          } elsif ($akey eq "amount") {
            $form->{"${key}_$k"}   = $form->{acc_trans}{$key}->[$i-1]->{accno} . "--" . $form->{acc_trans}{$key}->[$i-1]->{id};
            $form->{"taxchart_$k"} = $form->{acc_trans}{$key}->[$i-1]->{id}    . "--" . $form->{acc_trans}{$key}->[$i-1]->{rate};
          }
        }
      }
    }
  }

  $form->{taxincluded}  = $taxincluded if ($form->{id});
  $form->{paidaccounts} = 1            if not defined $form->{paidaccounts};

  if ($form->{taxincluded} && $form->{taxrate} && $totalamount) {

    # add tax to amounts and invtotal
    for $i (1 .. $form->{rowcount}) {
      $taxamount            = ($totaltax + $totalwithholding) * $form->{"amount_$i"} / $totalamount;
      $tax                  = $form->round_amount($taxamount, 2);
      $diff                += ($taxamount - $tax);
      $form->{"amount_$i"} += $form->{"tax_$i"};
    }
    $form->{amount_1} += $form->round_amount($diff, 2);
  }

  $taxamount   = $form->round_amount($taxamount, 2);
  $form->{tax} = $taxamount;

  $form->{invtotal} = $totalamount + $totaltax;

  $main::lxdebug->leave_sub();
}

sub storno {
  $main::lxdebug->enter_sub();

  my ($self, $form, $myconfig, $id) = @_;

  my ($query, $new_id, $storno_row, $acc_trans_rows);
  my $dbh = $form->get_standard_dbh($myconfig);

  $query = qq|SELECT nextval('glid')|;
  ($new_id) = selectrow_query($form, $dbh, $query);

  $query = qq|SELECT * FROM ar WHERE id = ?|;
  $storno_row = selectfirst_hashref_query($form, $dbh, $query, $id);

  $storno_row->{id}         = $new_id;
  $storno_row->{storno_id}  = $id;
  $storno_row->{storno}     = 't';
  $storno_row->{invnumber}  = 'Storno-' . $storno_row->{invnumber};
  $storno_row->{amount}    *= -1;
  $storno_row->{netamount} *= -1;
  $storno_row->{paid}       = $storno_row->{amount};

  delete @$storno_row{qw(itime mtime)};

  $query = sprintf 'INSERT INTO ar (%s) VALUES (%s)', join(', ', keys %$storno_row), join(', ', map '?', values %$storno_row);
  do_query($form, $dbh, $query, (values %$storno_row));

  $query = qq|UPDATE ar SET paid = amount + paid, storno = 't' WHERE id = ?|;
  do_query($form, $dbh, $query, $id);

  # now copy acc_trans entries
  $query = qq|SELECT a.*, c.link FROM acc_trans a LEFT JOIN chart c ON a.chart_id = c.id WHERE a.trans_id = ? ORDER BY a.oid|;
  my $rowref = selectall_hashref_query($form, $dbh, $query, $id); 

  # kill all entries containing payments, which are the last 2n rows, of which the last has link =~ /paid/
  while ($rowref->[-1]{link} =~ /paid/) {
    splice(@$rowref, -2);
  }

  for my $row (@$rowref) {
    delete @$row{qw(itime mtime link)};
    $query = sprintf 'INSERT INTO acc_trans (%s) VALUES (%s)', join(', ', keys %$row), join(', ', map '?', values %$row);
    $row->{trans_id}   = $new_id;
    $row->{amount}    *= -1;
    do_query($form, $dbh, $query, (values %$row));
  }

  $dbh->commit;

  $main::lxdebug->leave_sub();
}


1;

