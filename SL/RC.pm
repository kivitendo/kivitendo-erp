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
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#======================================================================
#
# Account reconciliation routines
#
#======================================================================

package RC;

sub paymentaccounts {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT c.accno, c.description
                 FROM chart c
		 WHERE c.link LIKE '%_paid%'
		 AND (c.category = 'A' OR c.category = 'L')
		 ORDER BY c.accno|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{PR} }, $ref;
  }
  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub payment_transactions {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database, turn AutoCommit off
  my $dbh = $form->dbconnect_noauto($myconfig);

  my ($query, $sth);

  # get cleared balance
  if ($form->{fromdate}) {
    $query = qq|SELECT sum(a.amount),
                     (SELECT DISTINCT c2.category FROM chart c2
                      WHERE c2accno = '$form->{accno}') AS category
		FROM acc_trans a
		JOIN chart c ON (c.id = a.chart_id)
		WHERE a.transdate < date '$form->{fromdate}'
		AND a.cleared = '1'
		AND c.accno = '$form->{accno}'
		|;
  } else {
    $query = qq|SELECT sum(a.amount),
                     (SELECT DISTINCT c2.category FROM chart c2
                      WHERE c2.accno = '$form->{accno}') AS category
		FROM acc_trans a
		JOIN chart c ON (c.id = a.chart_id)
		WHERE a.cleared = '1'
		AND c.accno = '$form->{accno}'
		|;
  }

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  ($form->{beginningbalance}, $form->{category}) = $sth->fetchrow_array;

  $sth->finish;

  my %oid = ('Pg'     => 'ac.oid',
             'Oracle' => 'ac.rowid');

  $query = qq|SELECT c.name, ac.source, ac.transdate, ac.cleared,
	      ac.fx_transaction, ac.amount, a.id,
	      $oid{$myconfig->{dbdriver}} AS oid
	      FROM customer c, acc_trans ac, ar a, chart ch
	      WHERE c.id = a.customer_id
--	      AND NOT ac.fx_transaction
	      AND ac.cleared = '0'
	      AND ac.trans_id = a.id
	      AND ac.chart_id = ch.id
	      AND ch.accno = '$form->{accno}'
	      |;

  $query .= " AND ac.transdate >= '$form->{fromdate}'" if $form->{fromdate};
  $query .= " AND ac.transdate <= '$form->{todate}'"   if $form->{todate};

  $query .= qq|

      UNION
              SELECT v.name, ac.source, ac.transdate, ac.cleared,
	      ac.fx_transaction, ac.amount, a.id,
	      $oid{$myconfig->{dbdriver}} AS oid
	      FROM vendor v, acc_trans ac, ap a, chart ch
	      WHERE v.id = a.vendor_id
--	      AND NOT ac.fx_transaction
	      AND ac.cleared = '0'
	      AND ac.trans_id = a.id
	      AND ac.chart_id = ch.id
	      AND ch.accno = '$form->{accno}'
	     |;

  $query .= " AND ac.transdate >= '$form->{fromdate}'" if $form->{fromdate};
  $query .= " AND ac.transdate <= '$form->{todate}'"   if $form->{todate};

  $query .= qq|

      UNION
	      SELECT g.description, ac.source, ac.transdate, ac.cleared,
	      ac.fx_transaction, ac.amount, g.id,
	      $oid{$myconfig->{dbdriver}} AS oid
	      FROM gl g, acc_trans ac, chart ch
	      WHERE g.id = ac.trans_id
--	      AND NOT ac.fx_transaction
	      AND ac.cleared = '0'
	      AND ac.trans_id = g.id
	      AND ac.chart_id = ch.id
	      AND ch.accno = '$form->{accno}'
	      |;

  $query .= " AND ac.transdate >= '$form->{fromdate}'" if $form->{fromdate};
  $query .= " AND ac.transdate <= '$form->{todate}'"   if $form->{todate};

  $query .= " ORDER BY 3,7,8";

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $pr = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{PR} }, $pr;
  }
  $sth->finish;

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub reconcile {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my ($query, $i);
  my %oid = ('Pg'     => 'oid',
             'Oracle' => 'rowid');

  # clear flags
  for $i (1 .. $form->{rowcount}) {
    if ($form->{"cleared_$i"}) {
      $query = qq|UPDATE acc_trans SET cleared = '1'
		  WHERE $oid{$myconfig->{dbdriver}} = $form->{"oid_$i"}|;
      $dbh->do($query) || $form->dberror($query);

      # clear fx_transaction
      if ($form->{"fxoid_$i"}) {
        $query = qq|UPDATE acc_trans SET cleared = '1'
		    WHERE $oid{$myconfig->{dbdriver}} = $form->{"fxoid_$i"}|;
        $dbh->do($query) || $form->dberror($query);
      }
    }
  }

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

1;
