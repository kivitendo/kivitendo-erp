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
# Check and receipt printing payment module backend routines
# Number to text conversion routines are in
# locale/{countrycode}/Num2text
#
#======================================================================

package CP;

sub new {
  $main::lxdebug->enter_sub();

  my ($type, $countrycode) = @_;

  $self = {};

  if ($countrycode) {
    if (-f "locale/$countrycode/Num2text") {
      require "locale/$countrycode/Num2text";
    } else {
      use SL::Num2text;
    }
  } else {
    use SL::Num2text;
  }

  $main::lxdebug->leave_sub();

  bless $self, $type;
}

sub paymentaccounts {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT c.accno, c.description, c.link
                 FROM chart c
		 WHERE c.link LIKE '%$form->{ARAP}%'
		 ORDER BY c.accno|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $form->{PR}{ $form->{ARAP} } = ();
  $form->{PR}{"$form->{ARAP}_paid"} = ();

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    foreach my $item (split /:/, $ref->{link}) {
      if ($item eq $form->{ARAP}) {
        push @{ $form->{PR}{ $form->{ARAP} } }, $ref;
      }
      if ($item eq "$form->{ARAP}_paid") {
        push @{ $form->{PR}{"$form->{ARAP}_paid"} }, $ref;
      }
    }
  }
  $sth->finish;

  # get currencies and closedto
  $query = qq|SELECT curr, closedto
              FROM defaults|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  ($form->{currencies}, $form->{closedto}) = $sth->fetchrow_array;
  $sth->finish;

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_openvc {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my $arap  = ($form->{vc} eq 'customer') ? 'ar' : 'ap';
  my $query = qq|SELECT count(*)
                 FROM $form->{vc} ct, $arap a
		 WHERE a.$form->{vc}_id = ct.id
                 AND a.amount != a.paid|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  my ($count) = $sth->fetchrow_array;
  $sth->finish;

  my $ref;

  # build selection list
  if ($count < $myconfig->{vclimit}) {
    $query = qq|SELECT DISTINCT ct.id, ct.name
                FROM $form->{vc} ct, $arap a
		WHERE a.$form->{vc}_id = ct.id
		AND a.amount != a.paid
		ORDER BY ct.name|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $form->{"all_$form->{vc}"} }, $ref;
    }

    $sth->finish;

  }

  if ($form->{ARAP} eq 'AR') {
    $query = qq|SELECT d.id, d.description
                FROM department d
		WHERE d.role = 'P'
		ORDER BY 2|;
  } else {
    $query = qq|SELECT d.id, d.description
                FROM department d
		ORDER BY 2|;
  }
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{all_departments} }, $ref;
  }
  $sth->finish;

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_openinvoices {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $where = qq|WHERE a.$form->{vc}_id = $form->{"$form->{vc}_id"}
                 AND a.curr = '$form->{currency}'
	         AND NOT a.amount = paid|;

  my ($buysell);
  if ($form->{vc} eq 'customer') {
    $buysell = "buy";
  } else {
    $buysell = "sell";
  }

  my $query =
    qq|SELECT a.id, a.invnumber, a.transdate, a.amount, a.paid, a.curr
	         FROM $form->{arap} a
		 $where
		 ORDER BY a.id|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {

    # if this is a foreign currency transaction get exchangerate
    $ref->{exchangerate} =
      $form->get_exchangerate($dbh, $ref->{curr}, $ref->{transdate}, $buysell)
      if ($form->{currency} ne $form->{defaultcurrency});
    push @{ $form->{PR} }, $ref;
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub process_payment {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database, turn AutoCommit off
  my $dbh = $form->dbconnect_noauto($myconfig);

  my ($paymentaccno) = split /--/, $form->{account};

  # if currency ne defaultcurrency update exchangerate
  if ($form->{currency} ne $form->{defaultcurrency}) {
    $form->{exchangerate} =
      $form->parse_amount($myconfig, $form->{exchangerate});

    if ($form->{vc} eq 'customer') {
      $form->update_exchangerate($dbh, $form->{currency}, $form->{datepaid},
                                 $form->{exchangerate}, 0);
    } else {
      $form->update_exchangerate($dbh, $form->{currency}, $form->{datepaid}, 0,
                                 $form->{exchangerate});
    }
  } else {
    $form->{exchangerate} = 1;
  }

  my $query = qq|SELECT fxgain_accno_id, fxloss_accno_id
                 FROM defaults|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my ($fxgain_accno_id, $fxloss_accno_id) = $sth->fetchrow_array;
  $sth->finish;

  my ($buysell);

  if ($form->{vc} eq 'customer') {
    $buysell = "buy";
  } else {
    $buysell = "sell";
  }

  my $ml;
  my $where;

  if ($form->{ARAP} eq 'AR') {
    $ml    = 1;
    $where = qq|
		(c.link = 'AR'
		OR c.link LIKE 'AR:%')
		|;
  } else {
    $ml    = -1;
    $where = qq|
                (c.link = 'AP'
                OR c.link LIKE '%:AP'
		OR c.link LIKE '%:AP:%')
		|;
  }

  $paymentamount = $form->{amount};

  #  $paymentamount = $form->{amount};
  my $null;
  ($null, $form->{department_id}) = split /--/, $form->{department};
  $form->{department_id} *= 1;

  # query to retrieve paid amount
  $query = qq|SELECT a.paid FROM ar a
              WHERE a.id = ?
 	      FOR UPDATE|;
  my $pth = $dbh->prepare($query) || $form->dberror($query);

  # go through line by line
  for my $i (1 .. $form->{rowcount}) {

    $form->{"paid_$i"} = $form->parse_amount($myconfig, $form->{"paid_$i"});
    $form->{"due_$i"}  = $form->parse_amount($myconfig, $form->{"due_$i"});

    if ($form->{"checked_$i"} && $form->{"paid_$i"}) {
      $paymentamount =
        (($paymentamount * 1000) - ($form->{"paid_$i"} * 1000)) / 1000;

      # get exchangerate for original
      $query = qq|SELECT $buysell
                  FROM exchangerate e
                  JOIN $form->{arap} a ON (a.transdate = e.transdate)
		  WHERE e.curr = '$form->{currency}'
		  AND a.id = $form->{"id_$i"}|;
      $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);

      my ($exchangerate) = $sth->fetchrow_array;
      $sth->finish;

      $exchangerate = 1 unless $exchangerate;

      $query = qq|SELECT c.id
                  FROM chart c
		  JOIN acc_trans a ON (a.chart_id = c.id)
	  	  WHERE $where
		  AND a.trans_id = $form->{"id_$i"}|;
      $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);

      my ($id) = $sth->fetchrow_array;
      $sth->finish;

      $amount = $form->round_amount($form->{"paid_$i"} * $exchangerate, 2);

      # add AR/AP
      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, transdate,
                  amount)
                  VALUES ($form->{"id_$i"}, $id, '$form->{datepaid}',
		  $amount * $ml)|;
      $dbh->do($query) || $form->dberror($query);

      # add payment
      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, transdate,
                  amount, source, memo)
                  VALUES ($form->{"id_$i"},
		         (SELECT c.id FROM chart c
		          WHERE c.accno = '$paymentaccno'),
		  '$form->{datepaid}', $form->{"paid_$i"} * $ml * -1,
		  '$form->{source}', '$form->{memo}')|;
      $dbh->do($query) || $form->dberror($query);

      # add exchangerate difference if currency ne defaultcurrency
      $amount =
        $form->round_amount($form->{"paid_$i"} * ($form->{exchangerate} - 1),
                            2);
      if ($amount != 0) {

        # exchangerate difference
        $query = qq|INSERT INTO acc_trans (trans_id, chart_id, transdate,
		    amount, cleared, fx_transaction)
		    VALUES ($form->{"id_$i"},
		           (SELECT c.id FROM chart c
			    WHERE c.accno = '$paymentaccno'),
		  '$form->{datepaid}', $amount * $ml * -1, '0', '1')|;
        $dbh->do($query) || $form->dberror($query);

        # gain/loss

        $amount =
          $form->round_amount(
                  $form->{"paid_$i"} * ($exchangerate - $form->{exchangerate}),
                  2);
        if ($amount != 0) {
          my $accno_id = ($amount < 0) ? $fxgain_accno_id : $fxloss_accno_id;
          $query = qq|INSERT INTO acc_trans (trans_id, chart_id, transdate,
		      amount, cleared, fx_transaction)
		      VALUES ($form->{"id_$i"}, $accno_id,
		      '$form->{datepaid}', $amount * $ml * -1, '0', '1')|;
          $dbh->do($query) || $form->dberror($query);
        }
      }

      $form->{"paid_$i"} =
        $form->round_amount($form->{"paid_$i"} * $exchangerate, 2);

      $pth->execute($form->{"id_$i"}) || $form->dberror;
      ($amount) = $pth->fetchrow_array;
      $pth->finish;

      $amount += $form->{"paid_$i"};

      # update AR/AP transaction
      $query = qq|UPDATE $form->{arap} set
		  paid = $amount,
		  datepaid = '$form->{datepaid}'
		  WHERE id = $form->{"id_$i"}|;
      $dbh->do($query) || $form->dberror($query);
    }
  }

  # record a AR/AP with a payment
  if ($form->round_amount($paymentamount, 2) > 0) {
    $form->{invnumber} = "";
    OP::overpayment("", $myconfig, $form, $dbh, $paymentamount, $ml, 1);
  }

  if ($form->round_amount($paymentamount, 2) < 0) {
    $dbh->rollback;
    $rc = 0;
  }
  if ($form->round_amount($paymentamount, 2) == 0) {
    $rc = $dbh->commit;
  }

  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $rc;
}

1;

