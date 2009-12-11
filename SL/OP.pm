#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 2003
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
# Overpayment function
# used in AR, AP, IS, IR, OE, CP
#======================================================================

package OP;

use SL::DBUtils;

use strict;

sub overpayment {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $dbh, $amount, $ml) = @_;

  my $fxamount = $form->round_amount($amount * $form->{exchangerate}, 2);
  my ($paymentaccno) = split(/--/, $form->{account});

  my $vc_id = $form->{vc} eq "customer" ? "customer_id" : "vendor_id";
  my $arap = $form->{arap} eq "ar" ? "ar" : "ap";

  my $query = qq|SELECT nextval('glid')|;
  my ($new_id) = selectrow_query($form, $dbh, $query);

  # add AR/AP header transaction with a payment
  $query =
    qq|INSERT INTO $arap (id, invnumber, employee_id) | .
    qq|VALUES (?, ?, (SELECT id FROM employee WHERE login = ?))|;
  my @values = ($new_id, $form->{login}, $form->{login});
  do_query($form, $dbh, $query, @values);

  my $invnumber = ($form->{invnumber}) ? $form->{invnumber} : $new_id;
  $query =
    qq|UPDATE $arap SET invnumber = ?, $vc_id = ?, transdate = ?, datepaid = ?, | .
    qq|duedate = ?, netamount = ?, amount = ?, paid = ?, | .
    qq|curr = ?, department_id = ? | .
    qq|WHERE id = ?|;
  @values = ($invnumber, $form->{$vc_id},
             conv_date($form->{datepaid}), conv_date($form->{datepaid}),
             conv_date($form->{datepaid}), 0, 0, $fxamount, $form->{currency},
             $form->{department_id}, $new_id);
  do_query($form, $dbh, $query, @values);

  # add AR/AP
  my ($accno) = split /--/, $form->{ $form->{ARAP} };

  $query =
    qq|INSERT INTO acc_trans (trans_id, chart_id, transdate, amount) | .
    qq|VALUES (?, (SELECT id FROM chart WHERE accno = ? ), ?, ?)|;
  @values = ($new_id, $accno, conv_date($form->{datepaid}), $fxamount * $ml);
  do_query($form, $dbh, $query, @values);

  # add payment
  $query =
    qq|INSERT INTO acc_trans (trans_id, chart_id, transdate, amount, source, memo) | .
    qq|VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, ?, ?)|;
  @values = ($new_id, $paymentaccno, conv_date($form->{datepaid}),
             $amount * $ml * -1, $form->{source}, $form->{memo});
  do_query($form, $dbh, $query, @values);

  # add exchangerate difference
  if ($fxamount != $amount) {
    $query =
      qq|INSERT INTO acc_trans (trans_id, chart_id, transdate, amount, cleared, fx_transaction) | .
      qq|VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, ?, ?)|;
    @values = ($new_id, $paymentaccno, conv_date($form->{datepaid}),
               (($fxamount - $amount) * $ml * -1), 1, 1);
    do_query($form, $dbh, $query, @values);
  }

  $main::lxdebug->leave_sub();
}

1;

