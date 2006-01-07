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
# Batch printing module backend routines
#
#======================================================================

package BP;

sub get_vc {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my %arap = (invoice           => 'ar',
              packing_list      => 'ar',
              sales_order       => 'oe',
              purchase_order    => 'oe',
              sales_quotation   => 'oe',
              request_quotation => 'oe',
              check             => 'ap',
              receipt           => 'ar');

  $query = qq|SELECT count(*)
	      FROM (SELECT DISTINCT ON (vc.id) vc.id
		    FROM $form->{vc} vc, $arap{$form->{type}} a, status s
		    WHERE a.$form->{vc}_id = vc.id
		    AND s.trans_id = a.id
		    AND s.formname = '$form->{type}'
		    AND s.spoolfile IS NOT NULL) AS total|;

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  my ($count) = $sth->fetchrow_array;
  $sth->finish;

  # build selection list
  if ($count < $myconfig->{vclimit}) {
    $query = qq|SELECT DISTINCT ON (vc.id) vc.id, vc.name
                FROM $form->{vc} vc, $arap{$form->{type}} a, status s
		WHERE a.$form->{vc}_id = vc.id
		AND s.trans_id = a.id
		AND s.formname = '$form->{type}'
		AND s.spoolfile IS NOT NULL|;
  }
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{"all_$form->{vc}"} }, $ref;
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub payment_accounts {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT DISTINCT ON (s.chart_id) c.accno, c.description
                 FROM status s, chart c
		 WHERE s.chart_id = c.id
		 AND s.formname = '$form->{type}'|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{accounts} }, $ref;
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_spoolfiles {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my ($query, $arap);
  my $invnumber = "invnumber";

  if ($form->{type} eq 'check' || $form->{type} eq 'receipt') {

    $arap = ($form->{type} eq 'check') ? "ap" : "ar";
    my ($accno) = split /--/, $form->{account};

    $query = qq|SELECT a.id, s.spoolfile, vc.name, ac.transdate, a.invnumber,
                a.invoice, '$arap' AS module
                FROM status s, chart c, $form->{vc} vc, $arap a, acc_trans ac
		WHERE s.formname = '$form->{type}'
		AND s.chart_id = c.id
		AND c.accno = '$accno'
		AND s.trans_id = a.id
		AND a.$form->{vc}_id = vc.id
		AND ac.trans_id = s.trans_id
		AND ac.chart_id = c.id
		AND NOT ac.fx_transaction|;
  } else {

    $arap = "ar";
    my $invoice = "a.invoice";

    if ($form->{type} =~ /_(order|quotation)$/) {
      $invnumber = "ordnumber";
      $arap      = "oe";
      $invoice   = '0';
    }

    $query = qq|SELECT a.id, a.$invnumber AS invnumber, a.ordnumber,
		a.quonumber, a.transdate, $invoice AS invoice,
		'$arap' AS module, vc.name, s.spoolfile
		FROM $arap a, $form->{vc} vc, status s
		WHERE s.trans_id = a.id
		AND s.spoolfile IS NOT NULL
		AND s.formname = '$form->{type}'
		AND a.$form->{vc}_id = vc.id|;
  }

  if ($form->{"$form->{vc}_id"}) {
    $query .= qq| AND a.$form->{vc}_id = $form->{"$form->{vc}_id"}|;
  } else {
    if ($form->{ $form->{vc} }) {
      my $name = $form->like(lc $form->{ $form->{vc} });
      $query .= " AND lower(vc.name) LIKE '$name'";
    }
  }
  if ($form->{invnumber}) {
    my $number = $form->like(lc $form->{invnumber});
    $query .= " AND lower(a.invnumber) LIKE '$number'";
  }
  if ($form->{ordnumber}) {
    my $ordnumber = $form->like(lc $form->{ordnumber});
    $query .= " AND lower(a.ordnumber) LIKE '$ordnumber'";
  }
  if ($form->{quonumber}) {
    my $quonumber = $form->like(lc $form->{quonumber});
    $query .= " AND lower(a.quonumber) LIKE '$quonumber'";
  }

  #  $query .= " AND a.transdate >= '$form->{transdatefrom}'" if $form->{transdatefrom};
  #  $query .= " AND a.transdate <= '$form->{transdateto}'" if $form->{transdateto};

  my @a = (transdate, $invnumber, name);
  my $sortorder = join ', ', $form->sort_columns(@a);
  $sortorder = $form->{sort} if $form->{sort};

  $query .= " ORDER by $sortorder";

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{SPOOL} }, $ref;
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub delete_spool {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $spool) = @_;

  # connect to database, turn AutoCommit off
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query;

  if ($form->{type} =~ /(check|receipt)/) {
    $query = qq|DELETE FROM status
                WHERE spoolfile = ?|;
  } else {
    $query = qq|UPDATE status SET
                 spoolfile = NULL,
		 printed = '1'
                 WHERE spoolfile = ?|;
  }
  my $sth = $dbh->prepare($query) || $form->dberror($query);

  foreach my $i (1 .. $form->{rowcount}) {
    if ($form->{"checked_$i"}) {
      $sth->execute($form->{"spoolfile_$i"}) || $form->dberror($query);
      $sth->finish;
    }
  }

  # commit
  my $rc = $dbh->commit;
  $dbh->disconnect;

  if ($rc) {
    foreach my $i (1 .. $form->{rowcount}) {
      $_ = qq|$spool/$form->{"spoolfile_$i"}|;
      if ($form->{"checked_$i"}) {
        unlink;
      }
    }
  }

  $main::lxdebug->leave_sub();

  return $rc;
}

sub print_spool {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $spool) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|UPDATE status SET
		 printed = '1'
                 WHERE formname = '$form->{type}'
		 AND spoolfile = ?|;
  my $sth = $dbh->prepare($query) || $form->dberror($query);

  foreach my $i (1 .. $form->{rowcount}) {
    if ($form->{"checked_$i"}) {
      open(OUT, $form->{OUT}) or $form->error("$form->{OUT} : $!");

      $spoolfile = qq|$spool/$form->{"spoolfile_$i"}|;

      # send file to printer
      open(IN, $spoolfile) or $form->error("$spoolfile : $!");

      while (<IN>) {
        print OUT $_;
      }
      close(IN);
      close(OUT);

      $sth->execute($form->{"spoolfile_$i"}) || $form->dberror($query);
      $sth->finish;

    }
  }

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

1;

