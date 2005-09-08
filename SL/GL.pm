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

sub delete_transaction {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;
  
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

  return $rc;
}


sub post_transaction {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;
  
  my ($debit, $credit) = (0, 0);
  my $project_id;

  my $i;
  # check if debit and credit balances
  
  $debit = abs(int($form->round_amount($form->{debit},3)*1000));
  $credit = abs(int($form->round_amount($form->{credit},3)*1000));
  $tax = abs(int($form->round_amount($form->{tax},3)*1000));
  
  if ((($debit >= $credit) && (abs($debit-($credit +$tax))>4)) || (($debit < $credit) && (abs(($debit + $tax)-$credit)>4))) {
   return -2;
  }

  if (($debit + $credit +$tax) == 0) {
    return -3;
  }

  
  $debit = $form->round_amount($form->{debit}, 2);
  $credit = $form->round_amount($form->{credit}, 2);
  $tax = $form->round_amount($form->{tax}, 2);
  debug($debit,$credit,$tax,"Betraege");
  
  if ($form->{storno}) {
  	$debit = $debit * -1;
	$credit = $credit * -1;
	$tax = $tax * -1;
	$form->{reference} = "Storno-".$form->{reference};
	$form->{description} = "Storno-".$form->{description};
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
  foreach $i  ((credit,debit)) {
    # extract accno
    ($accno) = split(/--/, $form->{"${i}chartselected"});
    my $amount = 0;
    debug("$accno $i Kontonummer");
    if ($i eq "credit") {
      $amount = $credit;
    }
    if ($i eq "debit") {
      $amount = $debit * -1;
    }
    
    if ($form->{"${i}_splited"}) {
      # if there is an amount, add the record
        for $j (2 .. $form->{"${i}rowcount"}) {
        ($accno) = split(/--/, $form->{"${i}chartselected_$j"});
        
        $amount = $form->{"${i}_$j"};
        
        ($taxkey, $taxrate) = split(/--/, $form->{"taxchartselected_$j"});
        
        if ($i eq "debit") {
          $amount *=  -1;
        }
        if ($amount != 0) {
          $project_id = ($form->{"project_id_$i"}) ? $form->{"project_id_$i"} : 'NULL'; 
          $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate,
                      source, project_id, taxkey)
                      VALUES
                      ($form->{id}, (SELECT c.id
                                    FROM chart c
                                    WHERE c.accno = '$accno'),
                      $amount, '$form->{transdate}', '$form->{reference}',
                      $project_id, $taxkey)|;
        
          $dbh->do($query) || $form->dberror($query);
        }
        
        $tax = $form->{"tax_$j"};
        print(STDERR $tax, " Steuer bei Durchlauf $j\n\n");
        if ($tax !=0) {
              # add taxentry
            if ($i eq "debit") {
            $tax = $tax * (-1);
            }
            $amount = $tax;
            
            
            $project_id = ($form->{"project_id_$i"}) ? $form->{"project_id_$i"} : 'NULL'; 
            $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate,
                    source, project_id, taxkey)
                    VALUES
                    ($form->{id}, (SELECT t.chart_id
                    FROM tax t
                    WHERE t.taxkey = $taxkey),
                    $amount, '$form->{transdate}', '$form->{reference}',
                            $project_id, $taxkey)|;
            
            $dbh->do($query) || $form->dberror($query);
        }
      }
    } else {   
        # if there is an amount, add the record
        ($taxkey, $taxrate) = split(/--/, $form->{"taxchartselected"});
        $taxkey *= 1;
        debug("$amount auf $accno buchen");
        if ($amount != 0) {
          $project_id = ($form->{"project_id_$i"}) ? $form->{"project_id_$i"} : 'NULL'; 
          $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate,
                      source, project_id, taxkey)
                      VALUES
                      ($form->{id}, (SELECT c.id
                                    FROM chart c
                                    WHERE c.accno = '$accno'),
                      $amount, '$form->{transdate}', '$form->{reference}',
                      $project_id, $taxkey)|;
        
          $dbh->do($query) || $form->dberror($query);
        }
      }
    }
    if ($tax !=0 && !($form->{credit_splited} || $form->{debit_splited})) {
          # add taxentry
          if ($form->{debittaxkey}) {
          $tax = $tax * (-1);
          }
          $amount = $tax;
          debug("$amount Steuern buchen");
          
          $project_id = ($form->{"project_id_$i"}) ? $form->{"project_id_$i"} : 'NULL'; 
          $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate,
                  source, project_id, taxkey)
                  VALUES
                  ($form->{id}, (SELECT t.chart_id
                  FROM tax t
                  WHERE t.taxkey = $taxkey),
                  $amount, '$form->{transdate}', '$form->{reference}',
                          $project_id, $taxkey)|;
          
          $dbh->do($query) || $form->dberror($query);
    }
    
  
  # commit and redirect
  my $rc = $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $rc;
}



sub all_transactions {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

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
  if ($form->{gifi_accno}) {
    $glwhere .= " AND c.gifi_accno = '$form->{gifi_accno}'";
    $arwhere .= " AND c.gifi_accno = '$form->{gifi_accno}'";
    $apwhere .= " AND c.gifi_accno = '$form->{gifi_accno}'";
  }
  if ($form->{category} ne 'X') {
    $glwhere .= " AND c.category = '$form->{category}'";
    $arwhere .= " AND c.category = '$form->{category}'";
    $apwhere .= " AND c.category = '$form->{category}'";
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
  
  if ($form->{gifi_accno}) {
    # get category for account
    $query = qq|SELECT c.category
                FROM chart c
		WHERE c.gifi_accno = '$form->{gifi_accno}'|;
    $sth = $dbh->prepare($query); 

    $sth->execute || $form->dberror($query); 
    ($form->{ml}) = $sth->fetchrow_array; 
    $sth->finish; 
   
    if ($form->{datefrom}) {
      $query = qq|SELECT SUM(ac.amount)
		  FROM acc_trans ac, chart c
		  WHERE ac.chart_id = c.id
		  AND c.gifi_accno = '$form->{gifi_accno}'
		  AND ac.transdate < date '$form->{datefrom}'
		  |;
      $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);

      ($form->{balance}) = $sth->fetchrow_array;
      $sth->finish;
    }
  }

  my $false = ($myconfig->{dbdriver} eq 'Pg') ? FALSE : q|'0'|;

  
  my $query = qq|SELECT g.id, 'gl' AS type, $false AS invoice, g.reference, ac.taxkey, t.taxkey AS sorttax,
                 g.description, ac.transdate, ac.source, ac.trans_id,
		 ac.amount, c.accno, c.gifi_accno, g.notes, t.chart_id, ac.oid
                 FROM gl g, acc_trans ac, chart c LEFT JOIN tax t ON
                 (t.chart_id=c.id)
                 WHERE $glwhere
		 AND ac.chart_id = c.id
		 AND g.id = ac.trans_id
	UNION
	         SELECT a.id, 'ar' AS type, a.invoice, a.invnumber, ac.taxkey, t.taxkey AS sorttax,
		 ct.name, ac.transdate, ac.source, ac.trans_id,
		 ac.amount, c.accno, c.gifi_accno, a.notes, t.chart_id, ac.oid
		 FROM ar a, acc_trans ac, customer ct, chart c LEFT JOIN tax t ON
                 (t.chart_id=c.id)
		 WHERE $arwhere
		 AND ac.chart_id = c.id
		 AND a.customer_id = ct.id
		 AND a.id = ac.trans_id
	UNION
	         SELECT a.id, 'ap' AS type, a.invoice, a.invnumber, ac.taxkey, t.taxkey AS sorttax,
		 ct.name, ac.transdate, ac.source, ac.trans_id,
		 ac.amount, c.accno, c.gifi_accno, a.notes, t.chart_id, ac.oid
		 FROM ap a, acc_trans ac, vendor ct, chart c LEFT JOIN tax t ON
                 (t.chart_id=c.id)
		 WHERE $apwhere
		 AND ac.chart_id = c.id
		 AND a.vendor_id = ct.id
		 AND a.id = ac.trans_id
	         ORDER BY transdate, trans_id, taxkey DESC, sorttax DESC, oid|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    print(STDERR $ref->{id}, " Transaction\n");
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
    $balance=$ref->{amount};
    $i = 0;
    $j = 0;
    $k = 0;
    $l = 0;
    if ($ref->{amount} < 0) {
      if ($ref->{chart_id} >0) {
        $ref->{debit_tax}{$i} = $ref->{amount} * -1;
        $ref->{debit_tax_accno}{$i} = $ref->{accno};
        }
      else {
        $ref->{debit}{$k} = $ref->{amount} * -1;
        $ref->{debit_accno}{$k} = $ref->{accno};
        $ref->{debit_taxkey}{$k} = $ref->{taxkey};
        }
    } else {
      if ($ref->{chart_id} >0) {
        $ref->{credit_tax}{$j} = $ref->{amount};
        $ref->{credit_tax_accno}{$j} = $ref->{accno};
        }
      else {
        $ref->{credit}{$l} = $ref->{amount};
        $ref->{credit_accno}{$l} = $ref->{accno};
        $ref->{credit_taxkey}{$l} = $ref->{taxkey};
        }
    }

    while (abs($balance)>=0.015) {
      my $ref2 = $sth->fetchrow_hashref(NAME_lc) || $form->error("Unbalanced ledger!");

      $balance = (int($balance * 100000) + int(100000 * $ref2->{amount})) / 100000;
      print(STDERR $balance," BAlance\n");
      if ($ref2->{amount} < 0) {
        if ($ref2->{chart_id} >0) {
          if ($ref->{debit_tax_accno}{$i} ne "") {
            $i++;
          }
          $ref->{debit_tax}{$i} = $ref2->{amount} * -1;
          $ref->{debit_tax_accno}{$i} = $ref2->{accno};
          }
        else {
          if ($ref->{debit_accno}{$k} ne "") {
            $k++;
          }
          $ref->{debit}{$k} = $ref2->{amount} * -1;
          $ref->{debit_accno}{$k} = $ref2->{accno};
          $ref->{debit_taxkey}{$k} = $ref2->{taxkey};
          }
      } else {
        if ($ref2->{chart_id} >0) {
          if ($ref->{credit_tax_accno}{$j} ne "") {
            $j++;
          }
          $ref->{credit_tax}{$j} = $ref2->{amount};
          $ref->{credit_tax_accno}{$j} = $ref2->{accno};
          }
        else {
          if ($ref->{credit_accno}{$l} ne "") {
            $l++;
          }
          $ref->{credit}{$l} = $ref2->{amount};
          $ref->{credit_accno}{$l} = $ref2->{accno};
          $ref->{credit_taxkey}{$l} = $ref2->{taxkey};
          }
      }
    }
#    print(STDERR Dumper($ref));       
    push @{ $form->{GL} }, $ref;
    $balance=0;
  }
  $sth->finish;

  if ($form->{accno}) {
    $query = qq|SELECT c.description FROM chart c WHERE c.accno = '$form->{accno}'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{account_description}) = $sth->fetchrow_array;
    $sth->finish;
  }
  if ($form->{gifi_accno}) {
    $query = qq|SELECT g.description FROM gifi g WHERE g.accno = '$form->{gifi_accno}'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{gifi_account_description}) = $sth->fetchrow_array;
    $sth->finish;
  }
 
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}


sub transaction {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;
  
  my ($query, $sth, $ref);
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  $form->{creditrowcount} = 1;
  $form->{debitrowcount} = 1;
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
    $query = "SELECT c.accno, a.amount, project_id,
                (SELECT p.projectnumber FROM project p
		 WHERE a.project_id = p.id) AS projectnumber, a.taxkey, (SELECT c1.accno FROM chart c1, tax t WHERE t.taxkey=a.taxkey AND c1.id=t.chart_id) AS taxaccno
	      FROM acc_trans a, chart c
	      WHERE a.chart_id = c.id
	      AND a.trans_id = $form->{id}
	      ORDER BY accno";
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    
    $debitcount=2;
    $creditcount=2;
    $taxcount=2;
    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {

      if ($ref->{accno} eq $ref->{taxaccno}) {
        $form->{"tax_$taxcount"}= $ref->{amount};
        $form->{"tax"} += $ref->{amount};
        $form->{"taxchartselected_$taxcount"} = $ref->{taxkey};
        $taxcount++;
      } else {
      
		if ($ref->{amount} < 0) {
			$form->{"debit_$debitcount"} = $ref->{amount} * -1;
                        $form->{"debit"} += $ref->{amount} * -1;
			$form->{"debitchartselected_$debitcount"} = $ref->{accno};
                        $debitcount++;
		}
		if ($ref->{amount} > 0) {
                        
			$form->{"credit_$creditcount"} = $ref->{amount};
			$form->{"credit"} += $ref->{amount};
			$form->{"creditchartselected_$creditcount"} = $ref->{accno};
                        $creditcount++;
		}
	}
      
      $taxkey = $ref->{taxkey} *1;
    }
    if ($creditcount > 3) {
      $form->{credit_splited} = 1;
      $form->{credit} = $form->{credit} + $form->{tax};
      $form->{creditrowcount} = $creditcount - 1;
    } else {
      $form->{credit} = $form->{credit_2};
      $form->{amount} = $form->{amount_2};
      $form->{creditaccno} = $form->{creditchartselected_2};
    }
    if ($debitcount > 3) {
      $form->{debit_splited} = 1;
      $form->{debit} = $form->{debit} + $form->{tax};
      $form->{debitrowcount} = $debitcount - 1;
    } else {
      $form->{debit} = $form->{debit_2};
      $form->{debitaccno} = $form->{debitchartselected_2};
    }
    
    if ((($form->{credit} > $form->{debit}) && (!$form->{taxincluded})) || (($form->{credit} > $form->{debit}) && ($form->{taxincluded}))) {
    	$form->{amount} = $form->{debit};
    } else {
    	$form->{amount} = $form->{credit};
    }
    
      # get tax description
    $query = qq| SELECT * FROM tax t|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);  
    $form->{TAX} = ();
    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $form->{TAX} }, $ref;
    }
  
    $sth->finish;
  } else {
    $query = "SELECT current_date AS transdate, closedto, revtrans
              FROM defaults";
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{transdate}, $form->{closedto}, $form->{revtrans}) = $sth->fetchrow_array;
    
      # get tax description
    $query = qq| SELECT * FROM tax t order by t.taxkey|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);  
    $form->{TAX} = ();
    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $form->{TAX} }, $ref;
    }
  }

  $sth->finish;

  # get chart of accounts
  $query = qq|SELECT c.accno, c.description, c.taxkey_id
              FROM chart c
	      WHERE c.charttype = 'A'
              ORDER by c.accno|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  $form->{chart} = ();
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{chart} }, $ref;
  }
  $sth->finish;
  

  
  $sth->finish;
  
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub debug {
  local *OUT;
  if (open(OUT, ">>/tmp/linet.log")) {
#    chomp(@_);
    print(OUT join("\n", @_), "\n");
    close(OUT);
  } else {
    print(STDERR "noe: $!\n");
  }
}

1;

