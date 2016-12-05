#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 2002
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
# Account reconciliation routines
#
#======================================================================

package RC;

use SL::DBUtils;
use SL::DB;

use strict;

sub paymentaccounts {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh = SL::DB->client->dbh;

  my $query =
    qq|SELECT accno, description | .
    qq|FROM chart | .
    qq|WHERE link LIKE '%_paid%' AND category IN ('A', 'L') | .
    qq|ORDER BY accno|;

  $form->{PR} = selectall_hashref_query($form, $dbh, $query);

  $main::lxdebug->leave_sub();
}

sub payment_transactions {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database, turn AutoCommit off
  my $dbh = SL::DB->client->dbh;

  my ($query, @values);

  # get cleared balance
  if ($form->{fromdate}) {
    $query =
      qq|SELECT sum(a.amount), | .
      qq|  (SELECT DISTINCT c2.category FROM chart c2 | .
      qq|   WHERE c2.accno = ?) AS category | .
      qq|FROM acc_trans a | .
      qq|JOIN chart c ON (c.id = a.chart_id) | .
      qq|WHERE a.transdate < ? AND a.cleared = '1' AND c.accno = ?|;
    @values = ($form->{accno}, conv_date($form->{fromdate}), $form->{accno});

  } else {
    $query =
      qq|SELECT sum(a.amount), | .
      qq|  (SELECT DISTINCT c2.category FROM chart c2 | .
      qq|   WHERE c2.accno = ?) AS category | .
      qq|FROM acc_trans a | .
      qq|JOIN chart c ON (c.id = a.chart_id) | .
      qq|WHERE a.cleared = '1' AND c.accno = ?|;
    @values = ($form->{accno}, $form->{accno});
  }

  ($form->{beginningbalance}, $form->{category}) =
    selectrow_query($form, $dbh, $query, @values);

  @values = ();
  $query =
    qq|SELECT c.name, ac.source, ac.transdate, ac.cleared, | .
    qq|  ac.fx_transaction, ac.amount, a.id, | .
    qq|  ac.acc_trans_id AS oid | .
    qq|FROM customer c, acc_trans ac, ar a, chart ch | .
    qq|WHERE c.id = a.customer_id | .
    qq|  AND ac.cleared = '0' | .
    qq|  AND ac.trans_id = a.id | .
    qq|  AND ac.chart_id = ch.id | .
    qq|  AND ch.accno = ? |;
  push(@values, $form->{accno});

  if($form->{fromdate}) {
    $query .= qq|  AND ac.transdate >= ? |;
    push(@values, conv_date($form->{fromdate}));
  }

  if($form->{todate}){
    $query .= qq|  AND ac.transdate <= ? |;
    push(@values, conv_date($form->{todate}));
  }

  if($form->{additional_fromdate}) {
    $query .= qq|  AND ac.transdate >= ? |;
    push(@values, conv_date($form->{additional_fromdate}));
  }

  if($form->{additional_todate}){
    $query .= qq|  AND ac.transdate <= ? |;
    push(@values, conv_date($form->{additional_todate}));
  }

  if($form->{filter_amount}){
    $query .= qq|  AND ac.amount = ? |;
    push(@values, conv_i($form->{filter_amount}));
  }

  $query .=
    qq|UNION | .

    qq|SELECT v.name, ac.source, ac.transdate, ac.cleared, | .
    qq|  ac.fx_transaction, ac.amount, a.id, | .
    qq|  ac.acc_trans_id AS oid | .
    qq|FROM vendor v, acc_trans ac, ap a, chart ch | .
    qq|WHERE v.id = a.vendor_id | .
    qq|  AND ac.cleared = '0' | .
    qq|  AND ac.trans_id = a.id | .
    qq|  AND ac.chart_id = ch.id | .
    qq|  AND ch.accno = ? |;

  push(@values, $form->{accno});

  if($form->{fromdate}) {
    $query .= qq| AND ac.transdate >= ? |;
    push(@values, conv_date($form->{fromdate}));
  }

  if($form->{todate}){
    $query .= qq| AND ac.transdate <= ? |;
    push(@values, conv_date($form->{todate}));
  }

  if($form->{additional_fromdate}) {
    $query .= qq| AND ac.transdate >= ? |;
    push(@values, conv_date($form->{additional_fromdate}));
  }

  if($form->{additional_todate}){
    $query .= qq| AND ac.transdate <= ? |;
    push(@values, conv_date($form->{additional_todate}));
  }

  if($form->{filter_amount}){
    $query .= qq| AND ac.amount = ? |;
    push(@values, conv_i($form->{filter_amount}));
  }

  $query .=
    qq|UNION | .

    qq|SELECT g.description, ac.source, ac.transdate, ac.cleared, | .
    qq|  ac.fx_transaction, ac.amount, g.id, | .
    qq|  ac.acc_trans_id AS oid | .
    qq|FROM gl g, acc_trans ac, chart ch | .
    qq|WHERE g.id = ac.trans_id | .
    qq|  AND ac.cleared = '0' | .
    qq|  AND ac.trans_id = g.id | .
    qq|  AND ac.chart_id = ch.id | .
    qq|  AND ch.accno = ? |;

  push(@values, $form->{accno});

  if($form->{fromdate}) {
    $query .= qq| AND ac.transdate >= ? |;
    push(@values, conv_date($form->{fromdate}));
  }

  if($form->{todate}){
    $query .= qq| AND ac.transdate <= ? |;
    push(@values, conv_date($form->{todate}));
  }

  if($form->{additional_fromdate}) {
    $query .= qq| AND ac.transdate >= ? |;
    push(@values, conv_date($form->{additional_fromdate}));
  }

  if($form->{additional_todate}){
    $query .= qq| AND ac.transdate <= ? |;
    push(@values, conv_date($form->{additional_todate}));
  }

  if($form->{filter_amount}){
    $query .= qq| AND ac.amount = ? |;
    push(@values, conv_i($form->{filter_amount}));
  }

  $query .= " ORDER BY 3,7,8";

  $form->{PR} = selectall_hashref_query($form, $dbh, $query, @values);

  $main::lxdebug->leave_sub();
}

sub reconcile {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  SL::DB->client->with_transaction(sub {
    my $dbh = SL::DB->client->dbh;

    my ($query, $i);

    # clear flags
    for $i (1 .. $form->{rowcount}) {
      if ($form->{"cleared_$i"}) {
        $query =
          qq|UPDATE acc_trans SET cleared = '1' | .
          qq|WHERE acc_trans_id = ?|;
        do_query($form, $dbh, $query, $form->{"oid_$i"});

        # clear fx_transaction
        if ($form->{"fxoid_$i"}) {
          $query =
            qq|UPDATE acc_trans SET cleared = '1' | .
            qq|WHERE acc_trans_id = ?|;
          do_query($form, $dbh, $query, $form->{"fxoid_$i"});
        }
      }
    }
    1;
  }) or do { die SL::DB->client->error };

  $main::lxdebug->leave_sub();
}

sub get_statement_balance {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database, turn AutoCommit off
  my $dbh = SL::DB->client->dbh;

  my ($query, @values);

  $query = qq|SELECT sum(amount) FROM acc_trans where chart_id=45 AND cleared='1'|;

  if($form->{fromdate}) {
    $query .= qq| AND transdate >= ? |;
    push(@values, conv_date($form->{fromdate}));
  }

  if($form->{todate}){
    $query .= qq| AND transdate <= ? |;
    push(@values, conv_date($form->{todate}));
  }

  ($form->{statement_balance}) = selectrow_query($form, $dbh, $query, @values);

  $main::lxdebug->leave_sub();
}

1;
