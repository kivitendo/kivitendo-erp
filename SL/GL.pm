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
# General ledger backend code
#
# CHANGE LOG:
#   DS. 2000-07-04  Created
#   DS. 2001-06-12  Changed relations from accno to chart_id
#
#======================================================================

package GL;

use Data::Dumper;
use SL::DBUtils;

sub delete_transaction {
  my ($self, $myconfig, $form) = @_;
  $main::lxdebug->enter_sub();

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query = qq|DELETE FROM gl WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $query = qq|DELETE FROM acc_trans WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # commit and redirect
  my $rc = $dbh->commit;
  $dbh->disconnect;
  $main::lxdebug->leave_sub();

  $rc;

}

sub post_transaction {
  my ($self, $myconfig, $form) = @_;
  $main::lxdebug->enter_sub();

  my ($debit, $credit) = (0, 0);
  my $project_id;

  my $i;

  # check if debit and credit balances

  if ($form->{storno}) {
    $form->{reference}   = "Storno-" . $form->{reference};
    $form->{description} = "Storno-" . $form->{description};
  }

  # connect to database, turn off AutoCommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  # post the transaction
  # make up a unique handle and store in reference field
  # then retrieve the record based on the unique handle to get the id
  # replace the reference field with the actual variable
  # add records to acc_trans

  # if there is a $form->{id} replace the old transaction
  # delete all acc_trans entries and add the new ones

  # escape '
  map { $form->{$_} =~ s/\'/\'\'/g } qw(reference description notes);

  if (!$form->{taxincluded}) {
    $form->{taxincluded} = 0;
  }

  my ($query, $sth);

  if ($form->{id}) {

    # delete individual transactions
    $query = qq|DELETE FROM acc_trans 
                WHERE trans_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);

  } else {
    my $uid = time;
    $uid .= $form->{login};

    $query = qq|INSERT INTO gl (reference, employee_id)
                VALUES ('$uid', (SELECT e.id FROM employee e
		                 WHERE e.login = '$form->{login}'))|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|SELECT g.id FROM gl g
                WHERE g.reference = '$uid'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{id}) = $sth->fetchrow_array;
    $sth->finish;

  }

  my ($null, $department_id) = split /--/, $form->{department};
  $department_id *= 1;

  $query = qq|UPDATE gl SET 
	      reference = '$form->{reference}',
	      description = '$form->{description}',
	      notes = '$form->{notes}',
	      transdate = '$form->{transdate}',
	      department_id = $department_id,
	      taxincluded = '$form->{taxincluded}'
	      WHERE id = $form->{id}|;

  $dbh->do($query) || $form->dberror($query);
  ($taxkey, $rate) = split(/--/, $form->{taxkey});

  # insert acc_trans transactions
  for $i (1 .. $form->{rowcount}) {
    my $taxkey;
    my $rate;
    # extract accno
    print(STDERR $form->{"taxchart_$i"}, "TAXCHART\n");
    my ($accno) = split(/--/, $form->{"accno_$i"});
    my ($taxkey, $rate) = split(/--/, $form->{"taxchart_$i"});
    ($form->{"tax_id_$i"}, $NULL) = split /--/, $form->{"taxchart_$i"};
    if ($form->{"tax_id_$i"} ne "") {
      $query = qq|SELECT t.taxkey, t.rate
              FROM tax t
              WHERE t.id=$form->{"tax_id_$i"}|;
  
      $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);
      ($taxkey, $rate) =
        $sth->fetchrow_array;
      $sth->finish;
    }

    my $amount = 0;
    my $debit  = $form->{"debit_$i"};
    my $credit = $form->{"credit_$i"};
    my $tax    = $form->{"tax_$i"};

    if ($credit) {
      $amount = $credit;
      $posted = 0;
    }
    if ($debit) {
      $amount = $debit * -1;
      $tax    = $tax * -1;
      $posted = 0;
    }

    $project_id = conv_i($form->{"project_id_$i"});

    # if there is an amount, add the record
    if ($amount != 0) {
      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate,
                  source, memo, project_id, taxkey)
		  VALUES
		  ($form->{id}, (SELECT c.id
		                 FROM chart c
				 WHERE c.accno = '$accno'),
		   $amount, '$form->{transdate}', |
        . $dbh->quote($form->{"source_$i"}) . qq|, |
        . $dbh->quote($form->{"memo_$i"}) . qq|,
		  ?, $taxkey)|;

      do_query($form, $dbh, $query, $project_id);
    }

    if ($tax != 0) {
      # add taxentry
      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate,
                  source, memo, project_id, taxkey)
                  VALUES
                  ($form->{id}, (SELECT t.chart_id
                  FROM tax t
                  WHERE t.id = $form->{"tax_id_$i"}),
                  $tax, '$form->{transdate}', |
        . $dbh->quote($form->{"source_$i"}) . qq|, |
        . $dbh->quote($form->{"memo_$i"}) . qq|, ?, $taxkey)|;

      do_query($form, $dbh, $query, $project_id);
    }
  }

  # commit and redirect
  my $rc = $dbh->commit;
  $dbh->disconnect;
  $main::lxdebug->leave_sub();

  $rc;

}

sub all_transactions {
  my ($self, $myconfig, $form) = @_;
  $main::lxdebug->enter_sub();

  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  my ($query, $sth, $source, $null);

  my ($glwhere, $arwhere, $apwhere) = ("1 = 1", "1 = 1", "1 = 1");

  if ($form->{reference}) {
    $source = $form->like(lc $form->{reference});
    $glwhere .= " AND lower(g.reference) LIKE '$source'";
    $arwhere .= " AND lower(a.invnumber) LIKE '$source'";
    $apwhere .= " AND lower(a.invnumber) LIKE '$source'";
  }
  if ($form->{department}) {
    ($null, $source) = split /--/, $form->{department};
    $glwhere .= " AND g.department_id = $source";
    $arwhere .= " AND a.department_id = $source";
    $apwhere .= " AND a.department_id = $source";
  }

  if ($form->{source}) {
    $source = $form->like(lc $form->{source});
    $glwhere .= " AND lower(ac.source) LIKE '$source'";
    $arwhere .= " AND lower(ac.source) LIKE '$source'";
    $apwhere .= " AND lower(ac.source) LIKE '$source'";
  }
  if ($form->{datefrom}) {
    $glwhere .= " AND ac.transdate >= '$form->{datefrom}'";
    $arwhere .= " AND ac.transdate >= '$form->{datefrom}'";
    $apwhere .= " AND ac.transdate >= '$form->{datefrom}'";
  }
  if ($form->{dateto}) {
    $glwhere .= " AND ac.transdate <= '$form->{dateto}'";
    $arwhere .= " AND ac.transdate <= '$form->{dateto}'";
    $apwhere .= " AND ac.transdate <= '$form->{dateto}'";
  }
  if ($form->{description}) {
    my $description = $form->like(lc $form->{description});
    $glwhere .= " AND lower(g.description) LIKE '$description'";
    $arwhere .= " AND lower(ct.name) LIKE '$description'";
    $apwhere .= " AND lower(ct.name) LIKE '$description'";
  }
  if ($form->{notes}) {
    my $notes = $form->like(lc $form->{notes});
    $glwhere .= " AND lower(g.notes) LIKE '$notes'";
    $arwhere .= " AND lower(a.notes) LIKE '$notes'";
    $apwhere .= " AND lower(a.notes) LIKE '$notes'";
  }
  if ($form->{accno}) {
    $glwhere .= " AND c.accno = '$form->{accno}'";
    $arwhere .= " AND c.accno = '$form->{accno}'";
    $apwhere .= " AND c.accno = '$form->{accno}'";
  }
  if ($form->{category} ne 'X') {
    $glwhere .=
      " AND gl.id in (SELECT trans_id FROM acc_trans ac2 WHERE ac2.chart_id IN (SELECT id FROM chart c2 WHERE c2.category = '$form->{category}'))";
    $arwhere .=
      " AND ar.id in (SELECT trans_id FROM acc_trans ac2 WHERE ac2.chart_id IN (SELECT id FROM chart c2 WHERE c2.category = '$form->{category}'))";
    $apwhere .=
      " AND ap.id in (SELECT trans_id FROM acc_trans ac2 WHERE ac2.chart_id IN (SELECT id FROM chart c2 WHERE c2.category = '$form->{category}'))";
  }
  if ($form->{project_id}) {
    $glwhere .= " AND g.id IN (SELECT DISTINCT trans_id FROM acc_trans WHERE project_id = " . conv_i($form->{project_id}, 'NULL') . ")";
    $arwhere .=
      " AND ((a.globalproject_id = " . conv_i($form->{project_id}, 'NULL') . ") OR " .
      "      (a.id IN (SELECT DISTINCT trans_id FROM acc_trans WHERE project_id = " . conv_i($form->{project_id}, 'NULL') . ")))";
    $apwhere .=
      " AND ((a.globalproject_id = " . conv_i($form->{project_id}, 'NULL') . ") OR " .
      "      (a.id IN (SELECT DISTINCT trans_id FROM acc_trans WHERE project_id = " . conv_i($form->{project_id}, 'NULL') . ")))";
  }

  my ($project_columns, %project_join);
  if ($form->{"l_projectnumbers"}) {
    $project_columns = ", ac.project_id, pr.projectnumber";
    $project_join = "LEFT JOIN project pr ON (ac.project_id = pr.id)";
  }

  if ($form->{accno}) {

    # get category for account
    $query = qq|SELECT c.category
                FROM chart c
		WHERE c.accno = '$form->{accno}'|;
    $sth = $dbh->prepare($query);

    $sth->execute || $form->dberror($query);
    ($form->{ml}) = $sth->fetchrow_array;
    $sth->finish;

    if ($form->{datefrom}) {
      $query = qq|SELECT SUM(ac.amount)
		  FROM acc_trans ac, chart c
		  WHERE ac.chart_id = c.id
		  AND c.accno = '$form->{accno}'
		  AND ac.transdate < date '$form->{datefrom}'
		  |;
      $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);

      ($form->{balance}) = $sth->fetchrow_array;
      $sth->finish;
    }
  }

  my $false = ($myconfig->{dbdriver} eq 'Pg') ? FALSE: q|'0'|;

  my $sortorder = join ', ',
    $form->sort_columns(qw(transdate reference source description accno));
  my %ordinal = (transdate   => 6,
                 reference   => 4,
                 source      => 7,
                 description => 5);
  map { $sortorder =~ s/$_/$ordinal{$_}/ } keys %ordinal;

  if ($form->{sort}) {
    $sortorder = $form->{sort} . ",";
  } else {
    $sortorder = "";
  }

  my $query =
    qq|SELECT ac.oid AS acoid, g.id, 'gl' AS type, $false AS invoice, g.reference, ac.taxkey, c.link,
                 g.description, ac.transdate, ac.source, ac.trans_id,
		 ac.amount, c.accno, g.notes, t.chart_id, ac.oid
                 $project_columns
                 FROM gl g, acc_trans ac $project_join, chart c LEFT JOIN tax t ON
                 (t.chart_id=c.id)
                 WHERE $glwhere
		 AND ac.chart_id = c.id
		 AND g.id = ac.trans_id
	UNION
	         SELECT ac.oid AS acoid, a.id, 'ar' AS type, a.invoice, a.invnumber, ac.taxkey, c.link,
		 ct.name, ac.transdate, ac.source, ac.trans_id,
		 ac.amount, c.accno, a.notes, t.chart_id, ac.oid
                 $project_columns
		 FROM ar a, acc_trans ac $project_join, customer ct, chart c LEFT JOIN tax t ON
                 (t.chart_id=c.id)
		 WHERE $arwhere
		 AND ac.chart_id = c.id
		 AND a.customer_id = ct.id
		 AND a.id = ac.trans_id
	UNION
	         SELECT ac.oid AS acoid, a.id, 'ap' AS type, a.invoice, a.invnumber, ac.taxkey, c.link,
		 ct.name, ac.transdate, ac.source, ac.trans_id,
		 ac.amount, c.accno, a.notes, t.chart_id, ac.oid
                 $project_columns
		 FROM ap a, acc_trans ac $project_join, vendor ct, chart c LEFT JOIN tax t ON
                 (t.chart_id=c.id)
		 WHERE $apwhere
		 AND ac.chart_id = c.id
		 AND a.vendor_id = ct.id
		 AND a.id = ac.trans_id
	         ORDER BY $sortorder transdate, trans_id, acoid, taxkey DESC|;

  # Show all $query in Debuglevel LXDebug::QUERY
  $callingdetails = (caller (0))[3];
  $main::lxdebug->message(LXDebug::QUERY, "$callingdetails \$query=\n $query");
      
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  my $trans_id  = "";
  my $trans_id2 = "";

  while (my $ref0 = $sth->fetchrow_hashref(NAME_lc)) {
    
    $trans_id = $ref0->{id};
    
    if ($trans_id != $trans_id2) { # first line of a booking
    
      if ($trans_id2) {
        push @{ $form->{GL} }, $ref;
        $balance = 0;
      }
    
      $ref       = $ref0;
      $trans_id2 = $ref->{id};

      # gl
      if ($ref->{type} eq "gl") {
        $ref->{module} = "gl";
      }

      # ap
      if ($ref->{type} eq "ap") {
        if ($ref->{invoice}) {
          $ref->{module} = "ir";
        } else {
          $ref->{module} = "ap";
        }
      }

      # ar
      if ($ref->{type} eq "ar") {
        if ($ref->{invoice}) {
          $ref->{module} = "is";
        } else {
          $ref->{module} = "ar";
        }
      }

      $ref->{"projectnumbers"} = {};
      $ref->{"projectnumbers"}->{$ref->{"projectnumber"}} = 1 if ($ref->{"projectnumber"});

      $balance = $ref->{amount};
    
      # Linenumbers of General Ledger  
      $k       = 0; # Debit      # AP      # Soll
      $l       = 0; # Credit     # AR      # Haben
      $i       = 0; # Debit Tax  # AP_tax  # VSt
      $j       = 0; # Credit Tax # AR_tax  # USt
      

      if ($ref->{chart_id} > 0) { # all tax accounts first line, no line increasing
        if ($ref->{amount} < 0) {
          if ($ref->{link} =~ /AR_tax/) {
            $ref->{credit_tax}{$j}       = $ref->{amount};
            $ref->{credit_tax_accno}{$j} = $ref->{accno};              
          }
          if ($ref->{link} =~ /AP_tax/) {
            $ref->{debit_tax}{$i}       = $ref->{amount} * -1;
            $ref->{debit_tax_accno}{$i} = $ref->{accno};   
          }
        } else {
          if ($ref->{link} =~ /AR_tax/) {
            $ref->{credit_tax}{$j}       = $ref->{amount};
            $ref->{credit_tax_accno}{$j} = $ref->{accno};              
          }
          if ($ref->{link} =~ /AP_tax/) {
            $ref->{debit_tax}{$i}       = $ref->{amount} * -1;
            $ref->{debit_tax_accno}{$i} = $ref->{accno};   
          }
        }
      } else { #all other accounts first line
        if ($ref->{amount} < 0) {
          $ref->{debit}{$k}        = $ref->{amount} * -1;
          $ref->{debit_accno}{$k}  = $ref->{accno};
          $ref->{debit_taxkey}{$k} = $ref->{taxkey};
          $ref->{ac_transdate}{$k} = $ref->{transdate};

        } else {
          $ref->{credit}{$l}        = $ref->{amount} * 1;
          $ref->{credit_accno}{$l}  = $ref->{accno};
          $ref->{credit_taxkey}{$l} = $ref->{taxkey};
          $ref->{ac_transdate}{$l}  = $ref->{transdate};


        }
      }

    } else { # following lines of a booking, line increasing

      $ref2      = $ref0;
      $trans_old  =$trans_id2;
      $trans_id2 = $ref2->{id};
  
      $balance =
        (int($balance * 100000) + int(100000 * $ref2->{amount})) / 100000;

      $ref->{"projectnumbers"}->{$ref2->{"projectnumber"}} = 1 if ($ref2->{"projectnumber"});

      if ($ref2->{chart_id} > 0) { # all tax accounts, following lines
        if ($ref2->{amount} < 0) {
          if ($ref2->{link} =~ /AR_tax/) {
            if ($ref->{credit_tax_accno}{$j} ne "") {
              $j++;
            }
            $ref->{credit_tax}{$j}       = $ref2->{amount};
            $ref->{credit_tax_accno}{$j} = $ref2->{accno};              
          }
          if ($ref2->{link} =~ /AP_tax/) {
            if ($ref->{debit_tax_accno}{$i} ne "") {
              $i++;
            }
            $ref->{debit_tax}{$i}       = $ref2->{amount} * -1;
            $ref->{debit_tax_accno}{$i} = $ref2->{accno};   
          }
        } else {
          if ($ref2->{link} =~ /AR_tax/) {
            if ($ref->{credit_tax_accno}{$j} ne "") {
              $j++;
            }
            $ref->{credit_tax}{$j}       = $ref2->{amount};
            $ref->{credit_tax_accno}{$j} = $ref2->{accno};              
          }
          if ($ref2->{link} =~ /AP_tax/) {
            if ($ref->{debit_tax_accno}{$i} ne "") {
              $i++;
            }
            $ref->{debit_tax}{$i}       = $ref2->{amount} * -1;
            $ref->{debit_tax_accno}{$i} = $ref2->{accno};   
          }
        }
      } else { # all other accounts, following lines
        if ($ref2->{amount} < 0) {
          if ($ref->{debit_accno}{$k} ne "") {
            $k++;
          }
          $ref->{debit}{$k}        = $ref2->{amount} * - 1;
          $ref->{debit_accno}{$k}  = $ref2->{accno};
          $ref->{debit_taxkey}{$k} = $ref2->{taxkey};
          $ref->{ac_transdate}{$k} = $ref2->{transdate};
        } else {
          if ($ref->{credit_accno}{$l} ne "") {
            $l++;
          }
          $ref->{credit}{$l}        = $ref2->{amount};
          $ref->{credit_accno}{$l}  = $ref2->{accno};
          $ref->{credit_taxkey}{$l} = $ref2->{taxkey};
          $ref->{ac_transdate}{$l}  = $ref2->{transdate};
        }
      }
    }
  }
  push @{ $form->{GL} }, $ref;
  $sth->finish;

  if ($form->{accno}) {
    $query =
      qq|SELECT c.description FROM chart c WHERE c.accno = '$form->{accno}'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{account_description}) = $sth->fetchrow_array;
    $sth->finish;
  }

  $main::lxdebug->leave_sub();

  $dbh->disconnect;

}

sub transaction {
  my ($self, $myconfig, $form) = @_;
  $main::lxdebug->enter_sub();

  my ($query, $sth, $ref);

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  if ($form->{id}) {
    $query = "SELECT closedto, revtrans
              FROM defaults";
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{closedto}, $form->{revtrans}) = $sth->fetchrow_array;
    $sth->finish;

    $query = "SELECT g.reference, g.description, g.notes, g.transdate,
              d.description AS department, e.name as employee, g.taxincluded, g.gldate
              FROM gl g
	    LEFT JOIN department d ON (d.id = g.department_id)  
	    LEFT JOIN employee e ON (e.id = g.employee_id)  
	    WHERE g.id = $form->{id}";
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    $ref = $sth->fetchrow_hashref(NAME_lc);
    map { $form->{$_} = $ref->{$_} } keys %$ref;
    $sth->finish;

    # retrieve individual rows
    $query = qq|SELECT c.accno, t.taxkey AS accnotaxkey, a.amount, a.memo,
                a.transdate, a.cleared, a.project_id, p.projectnumber,
		 a.taxkey, t.rate AS taxrate, t.id, (SELECT c1.accno FROM chart c1, tax t1 WHERE t1.id=t.id AND c1.id=t.chart_id) AS taxaccno, (SELECT tk.tax_id FROM taxkeys tk WHERE tk.chart_id =a.chart_id AND tk.startdate<=a.transdate ORDER BY tk.startdate desc LIMIT 1) AS tax_id
		FROM acc_trans a
		JOIN chart c ON (c.id = a.chart_id)
		LEFT JOIN project p ON (p.id = a.project_id)
                LEFT JOIN tax t ON (t.id=(SELECT tk.tax_id from taxkeys tk WHERE (tk.taxkey_id=a.taxkey) AND ((CASE WHEN a.chart_id IN (SELECT chart_id FROM taxkeys WHERE taxkey_id=a.taxkey) THEN tk.chart_id=a.chart_id ELSE 1=1 END) OR (c.link LIKE '%tax%')) AND startdate <=a.transdate ORDER BY startdate DESC LIMIT 1)) 
                WHERE a.trans_id = $form->{id}
		AND a.fx_transaction = '0'
		ORDER BY a.oid,a.transdate|;

    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $form->{GL} = [];
    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $form->{GL} }, $ref;
    }

    # get tax description
    $query = qq| SELECT * FROM tax t order by t.taxkey|;
    $sth   = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    $form->{TAX} = [];
    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $form->{TAX} }, $ref;
    }

    $sth->finish;
  } else {
    $query = "SELECT closedto, revtrans FROM defaults";
    ($form->{closedto}, $form->{revtrans}) = $dbh->selectrow_array($query);
    $query =
      "SELECT COALESCE(" .
      "  (SELECT transdate FROM gl WHERE id = " .
      "    (SELECT MAX(id) FROM gl) LIMIT 1), " .
      "  current_date)";
    ($form->{transdate}) = $dbh->selectrow_array($query);

    # get tax description
    $query = qq| SELECT * FROM tax t order by t.taxkey|;
    $sth   = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    $form->{TAX} = ();
    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $form->{TAX} }, $ref;
    }
  }

  $sth->finish;
  my $transdate = "current_date";
  if ($form->{transdate}) {
    $transdate = qq|'$form->{transdate}'|;
  }
  # get chart of accounts
  $query = qq|SELECT c.accno, c.description, c.link, tk.taxkey_id, tk.tax_id
                FROM chart c 
                LEFT JOIN taxkeys tk ON (tk.id = (SELECT id from taxkeys where taxkeys.chart_id =c.id AND startdate<=$transdate ORDER BY startdate desc LIMIT 1))
                ORDER BY c.accno|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  $form->{chart} = ();
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{chart} }, $ref;
  }
  $sth->finish;

  $sth->finish;
  $main::lxdebug->leave_sub();

  $dbh->disconnect;

}

1;

