#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 1998-2002
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
#  Contributors: Benjamin Lee <benjaminlee@consultant.com>
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
# backend code for reports
#
#======================================================================

package RP;

sub income_statement {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $last_period = 0;
  my @categories = qw(I E);
  my $category;

  $form->{decimalplaces} *= 1;

  &get_accounts($dbh, $last_period, $form->{fromdate}, $form->{todate}, $form, \@categories);
  
  # if there are any compare dates
  if ($form->{comparefromdate} || $form->{comparetodate}) {
    $last_period = 1;

    &get_accounts($dbh, $last_period, $form->{comparefromdate}, $form->{comparetodate}, $form, \@categories);
  }  

  
  # disconnect
  $dbh->disconnect;


  # now we got $form->{I}{accno}{ }
  # and $form->{E}{accno}{  }
  
  my %account = ( 'I' => { 'label' => 'income',
                           'labels' => 'income',
			   'ml' => 1 },
		  'E' => { 'label' => 'expense',
		           'labels' => 'expenses',
			   'ml' => -1 }
		);
  
  my $str;
  
  foreach $category (@categories) {
    
    foreach $key (sort keys %{ $form->{$category} }) {
      # push description onto array
      
      $str = ($form->{l_heading}) ? $form->{padding} : "";
      
      if ($form->{$category}{$key}{charttype} eq "A") {
	$str .= ($form->{l_accno}) ? "$form->{$category}{$key}{accno} - $form->{$category}{$key}{description}" : "$form->{$category}{$key}{description}";
      }
      if ($form->{$category}{$key}{charttype} eq "H") {
	if ($account{$category}{subtotal} && $form->{l_subtotal}) {
	  $dash = "- ";
	  push(@{$form->{"$account{$category}{label}_account"}}, "$str$form->{bold}$account{$category}{subdescription}$form->{endbold}");
	  push(@{$form->{"$account{$category}{labels}_this_period"}}, $form->format_amount($myconfig, $account{$category}{subthis} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
	  
	  if ($last_period) {
	    push(@{$form->{"$account{$category}{labels}_last_period"}}, $form->format_amount($myconfig, $account{$category}{sublast} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
	  }
	  
	}
	
	$str = "$form->{br}$form->{bold}$form->{$category}{$key}{description}$form->{endbold}";

	$account{$category}{subthis} = $form->{$category}{$key}{this};
	$account{$category}{sublast} = $form->{$category}{$key}{last};
	$account{$category}{subdescription} = $form->{$category}{$key}{description};
	$account{$category}{subtotal} = 1;

	$form->{$category}{$key}{this} = 0;
	$form->{$category}{$key}{last} = 0;

	next unless $form->{l_heading};

	$dash = " ";
      }
      
      push(@{$form->{"$account{$category}{label}_account"}}, $str);
      
      if ($form->{$category}{$key}{charttype} eq 'A') {
	$form->{"total_$account{$category}{labels}_this_period"} += $form->{$category}{$key}{this} * $account{$category}{ml};
	$dash = "- ";
      }
      
      push(@{$form->{"$account{$category}{labels}_this_period"}}, $form->format_amount($myconfig, $form->{$category}{$key}{this} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
      
      # add amount or - for last period
      if ($last_period) {
	$form->{"total_$account{$category}{labels}_last_period"} += $form->{$category}{$key}{last} * $account{$category}{ml};

	push(@{$form->{"$account{$category}{labels}_last_period"}}, $form->format_amount($myconfig,$form->{$category}{$key}{last} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
      }
    }

    $str = ($form->{l_heading}) ? $form->{padding} : "";
    if ($account{$category}{subtotal} && $form->{l_subtotal}) {
      push(@{$form->{"$account{$category}{label}_account"}}, "$str$form->{bold}$account{$category}{subdescription}$form->{endbold}");
      push(@{$form->{"$account{$category}{labels}_this_period"}}, $form->format_amount($myconfig, $account{$category}{subthis} * $account{$category}{ml}, $form->{decimalplaces}, $dash));

      if ($last_period) {
	push(@{$form->{"$account{$category}{labels}_last_period"}}, $form->format_amount($myconfig, $account{$category}{sublast} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
      }
    }
      
  }


  # totals for income and expenses
  $form->{total_income_this_period} = $form->round_amount($form->{total_income_this_period}, $form->{decimalplaces});
  $form->{total_expenses_this_period} = $form->round_amount($form->{total_expenses_this_period}, $form->{decimalplaces});

  # total for income/loss
  $form->{total_this_period} = $form->{total_income_this_period} - $form->{total_expenses_this_period};
  
  if ($last_period) {
    # total for income/loss
    $form->{total_last_period} = $form->format_amount($myconfig, $form->{total_income_last_period} - $form->{total_expenses_last_period}, $form->{decimalplaces}, "- ");
    
    # totals for income and expenses for last_period
    $form->{total_income_last_period} = $form->format_amount($myconfig, $form->{total_income_last_period}, $form->{decimalplaces}, "- ");
    $form->{total_expenses_last_period} = $form->format_amount($myconfig, $form->{total_expenses_last_period}, $form->{decimalplaces}, "- ");

  }


  $form->{total_income_this_period} = $form->format_amount($myconfig,$form->{total_income_this_period}, $form->{decimalplaces}, "- ");
  $form->{total_expenses_this_period} = $form->format_amount($myconfig,$form->{total_expenses_this_period}, $form->{decimalplaces}, "- ");
  $form->{total_this_period} = $form->format_amount($myconfig,$form->{total_this_period}, $form->{decimalplaces}, "- ");

  $main::lxdebug->leave_sub();
}


sub balance_sheet {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $last_period = 0;
  my @categories = qw(A C L Q);

  # if there are any dates construct a where
  if ($form->{asofdate}) {
    
    $form->{this_period} = "$form->{asofdate}";
    $form->{period} = "$form->{asofdate}";
    
  }

  $form->{decimalplaces} *= 1;

  &get_accounts($dbh, $last_period, "", $form->{asofdate}, $form, \@categories);
  
  # if there are any compare dates
  if ($form->{compareasofdate}) {

    $last_period = 1;
    &get_accounts($dbh, $last_period, "", $form->{compareasofdate}, $form, \@categories);
  
    $form->{last_period} = "$form->{compareasofdate}";

  }  

  
  # disconnect
  $dbh->disconnect;


  # now we got $form->{A}{accno}{ }    assets
  # and $form->{L}{accno}{ }           liabilities
  # and $form->{Q}{accno}{ }           equity
  # build asset accounts
  
  my $str;
  my $key;
  
  my %account  = ( 'A' => { 'label' => 'asset',
                            'labels' => 'assets',
			    'ml' => -1 },
		   'L' => { 'label' => 'liability',
		            'labels' => 'liabilities',
			    'ml' => 1 },
		   'Q' => { 'label' => 'equity',
		            'labels' => 'equity',
			    'ml' => 1 }
		);	    
			    
  foreach $category (grep { !/C/ } @categories) {

    foreach $key (sort keys %{ $form->{$category} }) {

      $str = ($form->{l_heading}) ? $form->{padding} : "";

      if ($form->{$category}{$key}{charttype} eq "A") {
	$str .= ($form->{l_accno}) ? "$form->{$category}{$key}{accno} - $form->{$category}{$key}{description}" : "$form->{$category}{$key}{description}";
      }
      if ($form->{$category}{$key}{charttype} eq "H") {
	if ($account{$category}{subtotal} && $form->{l_subtotal}) {
	  $dash = "- ";
	  push(@{$form->{"$account{$category}{label}_account"}}, "$str$form->{bold}$account{$category}{subdescription}$form->{endbold}");
	  push(@{$form->{"$account{$category}{label}_this_period"}}, $form->format_amount($myconfig, $account{$category}{subthis} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
	  
	  if ($last_period) {
	    push(@{$form->{"$account{$category}{label}_last_period"}}, $form->format_amount($myconfig, $account{$category}{sublast} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
	  }
	}

	$str = "$form->{bold}$form->{$category}{$key}{description}$form->{endbold}";
	
	$account{$category}{subthis} = $form->{$category}{$key}{this};
	$account{$category}{sublast} = $form->{$category}{$key}{last};
	$account{$category}{subdescription} = $form->{$category}{$key}{description};
	$account{$category}{subtotal} = 1;
	
	$form->{$category}{$key}{this} = 0;
	$form->{$category}{$key}{last} = 0;

	next unless $form->{l_heading};

	$dash = " ";
      }
      
      # push description onto array
      push(@{$form->{"$account{$category}{label}_account"}}, $str);
      
      if ($form->{$category}{$key}{charttype} eq 'A') {
	$form->{"total_$account{$category}{labels}_this_period"} += $form->{$category}{$key}{this} * $account{$category}{ml};
	$dash = "- ";
      }

      push(@{$form->{"$account{$category}{label}_this_period"}}, $form->format_amount($myconfig, $form->{$category}{$key}{this} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
      
      if ($last_period) {
	$form->{"total_$account{$category}{labels}_last_period"} += $form->{$category}{$key}{last} * $account{$category}{ml};

	push(@{$form->{"$account{$category}{label}_last_period"}}, $form->format_amount($myconfig, $form->{$category}{$key}{last} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
      }
    }

    $str = ($form->{l_heading}) ? $form->{padding} : "";
    if ($account{$category}{subtotal} && $form->{l_subtotal}) {
      push(@{$form->{"$account{$category}{label}_account"}}, "$str$form->{bold}$account{$category}{subdescription}$form->{endbold}");
      push(@{$form->{"$account{$category}{label}_this_period"}}, $form->format_amount($myconfig, $account{$category}{subthis} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
      
      if ($last_period) {
	push(@{$form->{"$account{$category}{label}_last_period"}}, $form->format_amount($myconfig, $account{$category}{sublast} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
      }
    }

  }

  
  # totals for assets, liabilities
  $form->{total_assets_this_period} = $form->round_amount($form->{total_assets_this_period}, $form->{decimalplaces});
  $form->{total_liabilities_this_period} = $form->round_amount($form->{total_liabilities_this_period}, $form->{decimalplaces});
  $form->{total_equity_this_period} = $form->round_amount($form->{total_equity_this_period}, $form->{decimalplaces});

  # calculate earnings
  $form->{earnings_this_period} = $form->{total_assets_this_period} - $form->{total_liabilities_this_period} - $form->{total_equity_this_period};

  push(@{$form->{equity_this_period}}, $form->format_amount($myconfig, $form->{earnings_this_period}, $form->{decimalplaces}, "- "));
  
  $form->{total_equity_this_period} = $form->round_amount($form->{total_equity_this_period} + $form->{earnings_this_period}, $form->{decimalplaces});
  
  # add liability + equity
  $form->{total_this_period} = $form->format_amount($myconfig, $form->{total_liabilities_this_period} + $form->{total_equity_this_period}, $form->{decimalplaces}, "- ");


  if ($last_period) {
    # totals for assets, liabilities
    $form->{total_assets_last_period} = $form->round_amount($form->{total_assets_last_period}, $form->{decimalplaces});
    $form->{total_liabilities_last_period} = $form->round_amount($form->{total_liabilities_last_period}, $form->{decimalplaces});
    $form->{total_equity_last_period} = $form->round_amount($form->{total_equity_last_period}, $form->{decimalplaces});

    # calculate retained earnings
    $form->{earnings_last_period} = $form->{total_assets_last_period} - $form->{total_liabilities_last_period} - $form->{total_equity_last_period};

    push(@{$form->{equity_last_period}}, $form->format_amount($myconfig,$form->{earnings_last_period}, $form->{decimalplaces}, "- "));
    
    $form->{total_equity_last_period} = $form->round_amount($form->{total_equity_last_period} + $form->{earnings_last_period}, $form->{decimalplaces});

    # add liability + equity
    $form->{total_last_period} = $form->format_amount($myconfig, $form->{total_liabilities_last_period} + $form->{total_equity_last_period}, $form->{decimalplaces}, "- ");

  }

  
  $form->{total_liabilities_last_period} = $form->format_amount($myconfig, $form->{total_liabilities_last_period}, $form->{decimalplaces}, "- ") if ($form->{total_liabilities_last_period} != 0);
  
  $form->{total_equity_last_period} = $form->format_amount($myconfig, $form->{total_equity_last_period}, $form->{decimalplaces}, "- ") if ($form->{total_equity_last_period} != 0);
  
  $form->{total_assets_last_period} = $form->format_amount($myconfig, $form->{total_assets_last_period}, $form->{decimalplaces}, "- ") if ($form->{total_assets_last_period} != 0);
  
  $form->{total_assets_this_period} = $form->format_amount($myconfig, $form->{total_assets_this_period}, $form->{decimalplaces}, "- ");
  
  $form->{total_liabilities_this_period} = $form->format_amount($myconfig, $form->{total_liabilities_this_period}, $form->{decimalplaces}, "- ");
  
  $form->{total_equity_this_period} = $form->format_amount($myconfig, $form->{total_equity_this_period}, $form->{decimalplaces}, "- ");

  $main::lxdebug->leave_sub();
}


sub get_accounts {
  $main::lxdebug->enter_sub();

  my ($dbh, $last_period, $fromdate, $todate, $form, $categories) = @_;

  my ($null, $department_id) = split /--/, $form->{department};
  
  my $query;
  my $dpt_where;
  my $dpt_join;
  my $project;
  my $where = "1 = 1";
  my $glwhere = "";
  my $subwhere = "";
  my $item;
 
  my $category = "AND (";
  foreach $item (@{ $categories }) {
    $category .= qq|c.category = '$item' OR |;
  }
  $category =~ s/OR $/\)/;


  # get headings
  $query = qq|SELECT c.accno, c.description, c.category
	      FROM chart c
	      WHERE c.charttype = 'H'
	      $category
	      ORDER by c.accno|;

  if ($form->{accounttype} eq 'gifi')
  {
    $query = qq|SELECT g.accno, g.description, c.category
		FROM gifi g
		JOIN chart c ON (c.gifi_accno = g.accno)
		WHERE c.charttype = 'H'
		$category
		ORDER BY g.accno|;
  }

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  my @headingaccounts = ();
  while ($ref = $sth->fetchrow_hashref(NAME_lc))
  {
    $form->{$ref->{category}}{$ref->{accno}}{description} = "$ref->{description}";
    $form->{$ref->{category}}{$ref->{accno}}{charttype} = "H";
    $form->{$ref->{category}}{$ref->{accno}}{accno} = $ref->{accno};
    
    push @headingaccounts, $ref->{accno};
  }

  $sth->finish;

  if ($fromdate) {
    if ($form->{method} eq 'cash') {
      $subwhere .= " AND transdate >= '$fromdate'";
      $glwhere = " AND ac.transdate >= '$fromdate'";
    } else {
      $where .= " AND ac.transdate >= '$fromdate'";
    }
  }

  if ($todate) {
    $where .= " AND ac.transdate <= '$todate'";
    $subwhere .= " AND transdate <= '$todate'";
  }


  if ($department_id)
  {
    $dpt_join = qq|
               JOIN department t ON (a.department_id = t.id)
		  |;
    $dpt_where = qq|
               AND t.id = $department_id
	           |;
  }

  if ($form->{project_id})
  {
    $project = qq|
                 AND ac.project_id = $form->{project_id}
		 |;
  }


  if ($form->{accounttype} eq 'gifi')
  {
    
    if ($form->{method} eq 'cash')
    {

	$query = qq|
	
	         SELECT g.accno, sum(ac.amount) AS amount,
		 g.description, c.category
		 FROM acc_trans ac
	         JOIN chart c ON (c.id = ac.chart_id)
	         JOIN ar a ON (a.id = ac.trans_id)
	         JOIN gifi g ON (g.accno = c.gifi_accno)
	         $dpt_join
		 WHERE $where
		 $dpt_where
		 $category
		 AND ac.trans_id IN
		   (
		     SELECT trans_id
		     FROM acc_trans
		     JOIN chart ON (chart_id = id)
		     WHERE link LIKE '%AR_paid%'
		     $subwhere
		   )
		 $project
		 GROUP BY g.accno, g.description, c.category
		 
       UNION ALL
       
		 SELECT '' AS accno, SUM(ac.amount) AS amount,
		 '' AS description, c.category
		 FROM acc_trans ac
	         JOIN chart c ON (c.id = ac.chart_id)
	         JOIN ar a ON (a.id = ac.trans_id)
	         $dpt_join
		 WHERE $where
		 $dpt_where
		 $category
		 AND c.gifi_accno = ''
		 AND ac.trans_id IN
		   (
		     SELECT trans_id
		     FROM acc_trans
		     JOIN chart ON (chart_id = id)
		     WHERE link LIKE '%AR_paid%'
		     $subwhere
		   )
		 $project
		 GROUP BY c.category

       UNION ALL

       	         SELECT g.accno, sum(ac.amount) AS amount,
		 g.description, c.category
		 FROM acc_trans ac
	         JOIN chart c ON (c.id = ac.chart_id)
	         JOIN ap a ON (a.id = ac.trans_id)
	         JOIN gifi g ON (g.accno = c.gifi_accno)
	         $dpt_join
		 WHERE $where
		 $dpt_where
		 $category
		 AND ac.trans_id IN
		   (
		     SELECT trans_id
		     FROM acc_trans
		     JOIN chart ON (chart_id = id)
		     WHERE link LIKE '%AP_paid%'
		     $subwhere
		   )
		 $project
		 GROUP BY g.accno, g.description, c.category
		 
       UNION ALL
       
		 SELECT '' AS accno, SUM(ac.amount) AS amount,
		 '' AS description, c.category
		 FROM acc_trans ac
	         JOIN chart c ON (c.id = ac.chart_id)
	         JOIN ap a ON (a.id = ac.trans_id)
	         $dpt_join
		 WHERE $where
		 $dpt_where
		 $category
		 AND c.gifi_accno = ''
		 AND ac.trans_id IN
		   (
		     SELECT trans_id
		     FROM acc_trans
		     JOIN chart ON (chart_id = id)
		     WHERE link LIKE '%AP_paid%'
		     $subwhere
		   )
		 $project
		 GROUP BY c.category

       UNION ALL

-- add gl
	
	         SELECT g.accno, sum(ac.amount) AS amount,
		 g.description, c.category
		 FROM acc_trans ac
	         JOIN chart c ON (c.id = ac.chart_id)
	         JOIN gifi g ON (g.accno = c.gifi_accno)
	         JOIN gl a ON (a.id = ac.trans_id)
	         $dpt_join
		 WHERE $where
		 $glwhere
		 $dpt_where
		 $category
		 AND NOT (c.link = 'AR' OR c.link = 'AP')
		 $project
		 GROUP BY g.accno, g.description, c.category
		 
       UNION ALL
       
		 SELECT '' AS accno, SUM(ac.amount) AS amount,
		 '' AS description, c.category
		 FROM acc_trans ac
	         JOIN chart c ON (c.id = ac.chart_id)
	         JOIN gl a ON (a.id = ac.trans_id)
	         $dpt_join
		 WHERE $where
		 $glwhere
		 $dpt_where
		 $category
		 AND c.gifi_accno = ''
		 AND NOT (c.link = 'AR' OR c.link = 'AP')
		 $project
		 GROUP BY c.category
		 |;

        if ($form->{project_id}) {

	  $query .= qq|
	  
       UNION ALL
       
		 SELECT g.accno AS accno, SUM(ac.sellprice * ac.qty) AS amount,
		 g.description AS description, c.category
		 FROM invoice ac
	         JOIN ar a ON (a.id = ac.trans_id)
		 JOIN parts p ON (ac.parts_id = p.id)
		 JOIN chart c on (p.income_accno_id = c.id)
	         JOIN gifi g ON (g.accno = c.gifi_accno)
	         $dpt_join
	-- use transdate from subwhere
		 WHERE 1 = 1 $subwhere
		 AND c.category = 'I'
		 $dpt_where
		 AND ac.trans_id IN
		   (
		     SELECT trans_id
		     FROM acc_trans
		     JOIN chart ON (chart_id = id)
		     WHERE link LIKE '%AR_paid%'
		     $subwhere
		   )
		 $project
		 GROUP BY g.accno, g.description, c.category

       UNION ALL
       
		 SELECT g.accno AS accno, SUM(ac.sellprice * ac.qty) * -1 AS amount,
		 g.description AS description, c.category
		 FROM invoice ac
	         JOIN ap a ON (a.id = ac.trans_id)
		 JOIN parts p ON (ac.parts_id = p.id)
		 JOIN chart c on (p.expense_accno_id = c.id)
	         JOIN gifi g ON (g.accno = c.gifi_accno)
	         $dpt_join
		 WHERE 1 = 1 $subwhere
		 AND c.category = 'E'
		 $dpt_where
		 AND ac.trans_id IN
		   (
		     SELECT trans_id
		     FROM acc_trans
		     JOIN chart ON (chart_id = id)
		     WHERE link LIKE '%AP_paid%'
		     $subwhere
		   )
		 $project
		 GROUP BY g.accno, g.description, c.category
		 |;
	}

    } else {

      if ($department_id)
      {
	$dpt_join = qq|
	      JOIN dpt_trans t ON (t.trans_id = ac.trans_id)
	      |;
	$dpt_where = qq|
               AND t.department_id = $department_id
	      |;

      }

      $query = qq|
      
	      SELECT g.accno, SUM(ac.amount) AS amount,
	      g.description, c.category
	      FROM acc_trans ac
	      JOIN chart c ON (c.id = ac.chart_id)
	      JOIN gifi g ON (c.gifi_accno = g.accno)
	      $dpt_join
	      WHERE $where
	      $dpt_from
	      $category
	      $project
	      GROUP BY g.accno, g.description, c.category
	      
	   UNION ALL
	   
	      SELECT '' AS accno, SUM(ac.amount) AS amount,
	      '' AS description, c.category
	      FROM acc_trans ac
	      JOIN chart c ON (c.id = ac.chart_id)
	      $dpt_join
	      WHERE $where
	      $dpt_from
	      $category
	      AND c.gifi_accno = ''
	      $project
	      GROUP BY c.category
	      |;

       if ($form->{project_id})
       {

	 $query .= qq|
	  
	 UNION ALL
       
		 SELECT g.accno AS accno, SUM(ac.sellprice * ac.qty) AS amount,
		 g.description AS description, c.category
		 FROM invoice ac
	         JOIN ar a ON (a.id = ac.trans_id)
		 JOIN parts p ON (ac.parts_id = p.id)
		 JOIN chart c on (p.income_accno_id = c.id)
		 JOIN gifi g ON (c.gifi_accno = g.accno)
	         $dpt_join
	-- use transdate from subwhere
		 WHERE 1 = 1 $subwhere
		 AND c.category = 'I'
		 $dpt_where
		 $project
		 GROUP BY g.accno, g.description, c.category

       UNION ALL
       
		 SELECT g.accno AS accno, SUM(ac.sellprice * ac.qty) * -1 AS amount,
		 g.description AS description, c.category
		 FROM invoice ac
	         JOIN ap a ON (a.id = ac.trans_id)
		 JOIN parts p ON (ac.parts_id = p.id)
		 JOIN chart c on (p.expense_accno_id = c.id)
		 JOIN gifi g ON (c.gifi_accno = g.accno)
	         $dpt_join
		 WHERE 1 = 1 $subwhere
		 AND c.category = 'E'
		 $dpt_where
		 $project
		 GROUP BY g.accno, g.description, c.category
		 |;
	}

    }
    
  } else {    # standard account

    if ($form->{method} eq 'cash')
    {

      $query = qq|
	
	         SELECT c.accno, sum(ac.amount) AS amount,
		 c.description, c.category
		 FROM acc_trans ac
		 JOIN chart c ON (c.id = ac.chart_id)
		 JOIN ar a ON (a.id = ac.trans_id)
		 $dpt_join
		 WHERE $where
		 $dpt_where
		 $category
		 AND ac.trans_id IN
		   (
		     SELECT trans_id
		     FROM acc_trans
		     JOIN chart ON (chart_id = id)
		     WHERE link LIKE '%AR_paid%'
		     $subwhere
		   )
		     
		 $project
		 GROUP BY c.accno, c.description, c.category
		 
	UNION ALL
	
	         SELECT c.accno, sum(ac.amount) AS amount,
		 c.description, c.category
		 FROM acc_trans ac
		 JOIN chart c ON (c.id = ac.chart_id)
		 JOIN ap a ON (a.id = ac.trans_id)
		 $dpt_join
		 WHERE $where
		 $dpt_where
		 $category
		 AND ac.trans_id IN
		   (
		     SELECT trans_id
		     FROM acc_trans
		     JOIN chart ON (chart_id = id)
		     WHERE link LIKE '%AP_paid%'
		     $subwhere
		   )
		     
		 $project
		 GROUP BY c.accno, c.description, c.category
		 
        UNION ALL

		 SELECT c.accno, sum(ac.amount) AS amount,
		 c.description, c.category
		 FROM acc_trans ac
		 JOIN chart c ON (c.id = ac.chart_id)
		 JOIN gl a ON (a.id = ac.trans_id)
		 $dpt_join
		 WHERE $where
		 $glwhere
		 $dpt_from
		 $category
		 AND NOT (c.link = 'AR' OR c.link = 'AP')
		 $project
		 GROUP BY c.accno, c.description, c.category
		 |;
		 
       if ($form->{project_id})
       {

	  $query .= qq|
	  
	 UNION ALL
       
		 SELECT c.accno AS accno, SUM(ac.sellprice * ac.qty) AS amount,
		 c.description AS description, c.category
		 FROM invoice ac
	         JOIN ar a ON (a.id = ac.trans_id)
		 JOIN parts p ON (ac.parts_id = p.id)
		 JOIN chart c on (p.income_accno_id = c.id)
	         $dpt_join
	-- use transdate from subwhere
		 WHERE 1 = 1 $subwhere
		 AND c.category = 'I'
		 $dpt_where
		 AND ac.trans_id IN
		   (
		     SELECT trans_id
		     FROM acc_trans
		     JOIN chart ON (chart_id = id)
		     WHERE link LIKE '%AR_paid%'
		     $subwhere
		   )

		 $project
		 GROUP BY c.accno, c.description, c.category

	 UNION ALL
       
		 SELECT c.accno AS accno, SUM(ac.sellprice) AS amount,
		 c.description AS description, c.category
		 FROM invoice ac
	         JOIN ap a ON (a.id = ac.trans_id)
		 JOIN parts p ON (ac.parts_id = p.id)
		 JOIN chart c on (p.expense_accno_id = c.id)
	         $dpt_join
		 WHERE 1 = 1 $subwhere
		 AND c.category = 'E'
		 $dpt_where
		 AND ac.trans_id IN
		   (
		     SELECT trans_id
		     FROM acc_trans
		     JOIN chart ON (chart_id = id)
		     WHERE link LIKE '%AP_paid%'
		     $subwhere
		   )

		 $project
		 GROUP BY c.accno, c.description, c.category
		 |;
      }

    } else {
     
      if ($department_id)
      {
	$dpt_join = qq|
	      JOIN dpt_trans t ON (t.trans_id = ac.trans_id)
	      |;
	$dpt_where = qq|
               AND t.department_id = $department_id
	      |;
      }

	
      $query = qq|
      
		 SELECT c.accno, sum(ac.amount) AS amount,
		 c.description, c.category
		 FROM acc_trans ac
		 JOIN chart c ON (c.id = ac.chart_id)
		 $dpt_join
		 WHERE $where
		 $dpt_where
		 $category
		 $project
		 GROUP BY c.accno, c.description, c.category
		 |;

      if ($form->{project_id})
      {

	$query .= qq|
	  
	UNION ALL
       
		 SELECT c.accno AS accno, SUM(ac.sellprice * ac.qty) AS amount,
		 c.description AS description, c.category
		 FROM invoice ac
	         JOIN ar a ON (a.id = ac.trans_id)
		 JOIN parts p ON (ac.parts_id = p.id)
		 JOIN chart c on (p.income_accno_id = c.id)
	         $dpt_join
	-- use transdate from subwhere
		 WHERE 1 = 1 $subwhere
		 AND c.category = 'I'
		 $dpt_where
		 $project
		 GROUP BY c.accno, c.description, c.category

	UNION ALL
       
		 SELECT c.accno AS accno, SUM(ac.sellprice * ac.qty) * -1 AS amount,
		 c.description AS description, c.category
		 FROM invoice ac
	         JOIN ap a ON (a.id = ac.trans_id)
		 JOIN parts p ON (ac.parts_id = p.id)
		 JOIN chart c on (p.expense_accno_id = c.id)
	         $dpt_join
		 WHERE 1 = 1 $subwhere
		 AND c.category = 'E'
		 $dpt_where
		 $project
		 GROUP BY c.accno, c.description, c.category
		 |;

      }
    }
  }


  my @accno;
  my $accno;
  my $ref;
  
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc))
  {

    if ($ref->{category} eq 'C') {
      $ref->{category} = 'A';
    }
      
    # get last heading account
    @accno = grep { $_ le "$ref->{accno}" } @headingaccounts;
    $accno = pop @accno;
    if ($accno) {
      if ($last_period)
      {
	$form->{$ref->{category}}{$accno}{last} += $ref->{amount};
      } else {
	$form->{$ref->{category}}{$accno}{this} += $ref->{amount};
      }
    }
    
    $form->{$ref->{category}}{$ref->{accno}}{accno} = $ref->{accno};
    $form->{$ref->{category}}{$ref->{accno}}{description} = $ref->{description};
    $form->{$ref->{category}}{$ref->{accno}}{charttype} = "A";
    
    if ($last_period)
    {
      $form->{$ref->{category}}{$ref->{accno}}{last} += $ref->{amount};
    } else {
      $form->{$ref->{category}}{$ref->{accno}}{this} += $ref->{amount};
    }
  }
  $sth->finish;

  
  # remove accounts with zero balance
  foreach $category (@{ $categories }) {
    foreach $accno (keys %{ $form->{$category} }) {
      $form->{$category}{$accno}{last} = $form->round_amount($form->{$category}{$accno}{last}, $form->{decimalplaces});
      $form->{$category}{$accno}{this} = $form->round_amount($form->{$category}{$accno}{this}, $form->{decimalplaces});

      delete $form->{$category}{$accno} if ($form->{$category}{$accno}{this} == 0 && $form->{$category}{$accno}{last} == 0);
    }
  }

  $main::lxdebug->leave_sub();
}


sub get_accounts_g {
  $main::lxdebug->enter_sub();

  my ($dbh, $last_period, $fromdate, $todate, $form, $category) = @_;

  my ($null, $department_id) = split /--/, $form->{department};
  
  my $query;
  my $dpt_where;
  my $dpt_join;
  my $project;
  my $where = "1 = 1";
  my $glwhere = "";
  my $subwhere = "";
  my $item;
 



  if ($fromdate) {
    if ($form->{method} eq 'cash') {
      $subwhere .= " AND transdate >= '$fromdate'";
      $glwhere = " AND ac.transdate >= '$fromdate'";
    } else {
      $where .= " AND ac.transdate >= '$fromdate'";
    }
  }

  if ($todate) {
    $where .= " AND ac.transdate <= '$todate'";
    $subwhere .= " AND transdate <= '$todate'";
  }


  if ($department_id)
  {
    $dpt_join = qq|
               JOIN department t ON (a.department_id = t.id)
		  |;
    $dpt_where = qq|
               AND t.id = $department_id
	           |;
  }

  if ($form->{project_id})
  {
    $project = qq|
                 AND ac.project_id = $form->{project_id}
		 |;
  }


    if ($form->{method} eq 'cash')
    {

      $query = qq|
	
	         SELECT sum(ac.amount) AS amount,
		 c.$category
		 FROM acc_trans ac
		 JOIN chart c ON (c.id = ac.chart_id)
		 JOIN ar a ON (a.id = ac.trans_id)
		 $dpt_join
		 WHERE $where
		 $dpt_where
		 AND ac.trans_id IN
		   (
		     SELECT trans_id
		     FROM acc_trans
		     JOIN chart ON (chart_id = id)
		     WHERE link LIKE '%AR_paid%'
		     $subwhere
		   )
		     
		 $project
		 GROUP BY c.$category
		 
	UNION
	
	         SELECT sum(ac.amount) AS amount,
		 c.$category
		 FROM acc_trans ac
		 JOIN chart c ON (c.id = ac.chart_id)
		 JOIN ap a ON (a.id = ac.trans_id)
		 $dpt_join
		 WHERE $where
		 $dpt_where
		 AND ac.trans_id IN
		   (
		     SELECT trans_id
		     FROM acc_trans
		     JOIN chart ON (chart_id = id)
		     WHERE link LIKE '%AP_paid%'
		     $subwhere
		   )
		     
		 $project
		 GROUP BY c.$category
		 
        UNION

		 SELECT sum(ac.amount) AS amount,
		 c.$category
		 FROM acc_trans ac
		 JOIN chart c ON (c.id = ac.chart_id)
		 JOIN gl a ON (a.id = ac.trans_id)
		 $dpt_join
		 WHERE $where
		 $glwhere
		 $dpt_from
		 AND NOT (c.link = 'AR' OR c.link = 'AP')
		 $project
		 GROUP BY c.$category
		 |;
		 
       if ($form->{project_id})
       {

	  $query .= qq|
	  
	 UNION
       
		 SELECT SUM(ac.sellprice * ac.qty) AS amount,
		 c.$category
		 FROM invoice ac
	         JOIN ar a ON (a.id = ac.trans_id)
		 JOIN parts p ON (ac.parts_id = p.id)
		 JOIN chart c on (p.income_accno_id = c.id)
	         $dpt_join
	-- use transdate from subwhere
		 WHERE 1 = 1 $subwhere
		 AND c.category = 'I'
		 $dpt_where
		 AND ac.trans_id IN
		   (
		     SELECT trans_id
		     FROM acc_trans
		     JOIN chart ON (chart_id = id)
		     WHERE link LIKE '%AR_paid%'
		     $subwhere
		   )

		 $project
		 GROUP BY c.$category

	 UNION
       
		 SELECT SUM(ac.sellprice) AS amount,
		 c.$category
		 FROM invoice ac
	         JOIN ap a ON (a.id = ac.trans_id)
		 JOIN parts p ON (ac.parts_id = p.id)
		 JOIN chart c on (p.expense_accno_id = c.id)
	         $dpt_join
		 WHERE 1 = 1 $subwhere
		 AND c.category = 'E'
		 $dpt_where
		 AND ac.trans_id IN
		   (
		     SELECT trans_id
		     FROM acc_trans
		     JOIN chart ON (chart_id = id)
		     WHERE link LIKE '%AP_paid%'
		     $subwhere
		   )

		 $project
		 GROUP BY c.$category
		 |;
      }

    } else {
     
      if ($department_id)
      {
	$dpt_join = qq|
	      JOIN dpt_trans t ON (t.trans_id = ac.trans_id)
	      |;
	$dpt_where = qq|
               AND t.department_id = $department_id
	      |;
      }

	
      $query = qq|
      
		 SELECT sum(ac.amount) AS amount,
		 c.$category
		 FROM acc_trans ac
		 JOIN chart c ON (c.id = ac.chart_id)
		 $dpt_join
		 WHERE $where
		 $dpt_where
		 $project
		 GROUP BY c.$category
		 |;

      if ($form->{project_id})
      {

	$query .= qq|
	  
	UNION
       
		 SELECT SUM(ac.sellprice * ac.qty) AS amount,
		 c.$category
		 FROM invoice ac
	         JOIN ar a ON (a.id = ac.trans_id)
		 JOIN parts p ON (ac.parts_id = p.id)
		 JOIN chart c on (p.income_accno_id = c.id)
	         $dpt_join
	-- use transdate from subwhere
		 WHERE 1 = 1 $subwhere
		 AND c.category = 'I'
		 $dpt_where
		 $project
		 GROUP BY c.$category

	UNION
       
		 SELECT SUM(ac.sellprice * ac.qty) * -1 AS amount,
		 c.$category
		 FROM invoice ac
	         JOIN ap a ON (a.id = ac.trans_id)
		 JOIN parts p ON (ac.parts_id = p.id)
		 JOIN chart c on (p.expense_accno_id = c.id)
	         $dpt_join
		 WHERE 1 = 1 $subwhere
		 AND c.category = 'E'
		 $dpt_where
		 $project
		 GROUP BY c.$category
		 |;

      }
    }


  my @accno;
  my $accno;
  my $ref;

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc))
  {
    if ($ref->{amount} < 0) {
      $ref->{amount} *= -1;
    }
    if ($category eq "pos_bwa") {
	if ($last_period)
	{
	$form->{$ref->{$category}}{kumm} += $ref->{amount};
	} else {
	$form->{$ref->{$category}}{jetzt} += $ref->{amount};
	}
    } else {
    	$form->{$ref->{$category}} += $ref->{amount};
    }
  }
  $sth->finish;

  $main::lxdebug->leave_sub();
}

sub trial_balance {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my ($query, $sth, $ref);
  my %balance = ();
  my %trb = ();
  my ($null, $department_id) = split /--/, $form->{department};
  my @headingaccounts = ();
  my $dpt_where;
  my $dpt_join;
  my $project;

  my $where = "1 = 1";
  my $invwhere = $where;
  
  if ($department_id) {
    $dpt_join = qq|
                JOIN dpt_trans t ON (ac.trans_id = t.trans_id)
		  |;
    $dpt_where = qq|
                AND t.department_id = $department_id
		|;
  }
  
  
  # project_id only applies to getting transactions
  # it has nothing to do with a trial balance
  # but we use the same function to collect information
  
  if ($form->{project_id}) {
    $project = qq|
                AND ac.project_id = $form->{project_id}
		|;
  }
  
  # get beginning balances
  if ($form->{fromdate}) {

    if ($form->{accounttype} eq 'gifi') {
      
      $query = qq|SELECT g.accno, c.category, SUM(ac.amount) AS amount,
                  g.description
		  FROM acc_trans ac
		  JOIN chart c ON (ac.chart_id = c.id)
		  JOIN gifi g ON (c.gifi_accno = g.accno)
		  $dpt_join
		  WHERE ac.transdate < '$form->{fromdate}'
		  $dpt_where
		  $project
		  GROUP BY g.accno, c.category, g.description
		  |;
   
    } else {
      
      $query = qq|SELECT c.accno, c.category, SUM(ac.amount) AS amount,
                  c.description
		  FROM acc_trans ac
		  JOIN chart c ON (ac.chart_id = c.id)
		  $dpt_join
		  WHERE ac.transdate < '$form->{fromdate}'
		  $dpt_where
		  $project
		  GROUP BY c.accno, c.category, c.description
		  |;
		  
    }

    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
      $balance{$ref->{accno}} = $ref->{amount};

      if ($ref->{amount} != 0 && $form->{all_accounts}) {
	$trb{$ref->{accno}}{description} = $ref->{description};
	$trb{$ref->{accno}}{charttype} = 'A';
	$trb{$ref->{accno}}{category} = $ref->{category};
      }

    }
    $sth->finish;

  }


  # get headings
  $query = qq|SELECT c.accno, c.description, c.category
	      FROM chart c
	      WHERE c.charttype = 'H'
	      ORDER by c.accno|;

  if ($form->{accounttype} eq 'gifi')
  {
    $query = qq|SELECT g.accno, g.description, c.category
		FROM gifi g
		JOIN chart c ON (c.gifi_accno = g.accno)
		WHERE c.charttype = 'H'
		ORDER BY g.accno|;
  }

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc))
  {
    $trb{$ref->{accno}}{description} = $ref->{description};
    $trb{$ref->{accno}}{charttype} = 'H';
    $trb{$ref->{accno}}{category} = $ref->{category};
   
    push @headingaccounts, $ref->{accno};
  }

  $sth->finish;

  $where = " 1 = 1 ";
  
  if ($form->{fromdate} || $form->{todate}) {
    if ($form->{fromdate}) {
      $tofrom .= " AND ac.transdate >= '$form->{fromdate}'";
      $subwhere .= " AND transdate >= '$form->{fromdate}'";
      $invwhere .= " AND a.transdate >= '$form->{fromdate}'";
      $glwhere = " AND ac.transdate >= '$form->{fromdate}'";
    }
    if ($form->{todate}) {
      $tofrom .= " AND ac.transdate <= '$form->{todate}'";
      $invwhere .= " AND a.transdate <= '$form->{todate}'";
      $subwhere .= " AND transdate <= '$form->{todate}'";
      $glwhere .= " AND ac.transdate <= '$form->{todate}'";
    }
  }
  if ($form->{eur}) {
    $where .= qq| AND ((ac.trans_id in (SELECT id from ar)
                  AND ac.trans_id IN
		   (
		     SELECT trans_id
		     FROM acc_trans
		     JOIN chart ON (chart_id = id)
		     WHERE link LIKE '%AR_paid%'
		     $subwhere
		   )) OR (ac.trans_id in (SELECT id from ap)
                   AND ac.trans_id IN
		   (
		     SELECT trans_id
		     FROM acc_trans
		     JOIN chart ON (chart_id = id)
		     WHERE link LIKE '%AP_paid%'
		     $subwhere
		   )) OR (ac.trans_id in (SELECT id from gl)
                   $glwhere))|;
  } else {
    $where .= $tofrom;
  }
  
  if ($form->{accounttype} eq 'gifi') {

    $query = qq|SELECT g.accno, g.description, c.category,
                SUM(ac.amount) AS amount
		FROM acc_trans ac
		JOIN chart c ON (c.id = ac.chart_id)
		JOIN gifi g ON (c.gifi_accno = g.accno)
		$dpt_join
		WHERE $where
		$dpt_where
		$project
		GROUP BY g.accno, g.description, c.category
		|;

    if ($form->{project_id}) {

      $query .= qq|

	-- add project transactions from invoice
	
	UNION ALL
	
	        SELECT g.accno, g.description, c.category,
		SUM(ac.sellprice * ac.qty) AS amount
		FROM invoice ac
		JOIN ar a ON (ac.trans_id = a.id)
		JOIN parts p ON (ac.parts_id = p.id)
		JOIN chart c ON (p.income_accno_id = c.id)
		JOIN gifi g ON (c.gifi_accno = g.accno)
		$dpt_join
		WHERE $invwhere
		$dpt_where
		$project
		GROUP BY g.accno, g.description, c.category

	UNION ALL
	
	        SELECT g.accno, g.description, c.category,
		SUM(ac.sellprice * ac.qty) * -1 AS amount
		FROM invoice ac
		JOIN ap a ON (ac.trans_id = a.id)
		JOIN parts p ON (ac.parts_id = p.id)
		JOIN chart c ON (p.expense_accno_id = c.id)
		JOIN gifi g ON (c.gifi_accno = g.accno)
		$dpt_join
		WHERE $invwhere
		$dpt_where
		$project
		GROUP BY g.accno, g.description, c.category
		|;
    }

    $query .= qq|
		ORDER BY accno|;
    
  } else {

    $query = qq|SELECT c.accno, c.description, c.category,
                SUM(ac.amount) AS amount
		FROM acc_trans ac
		JOIN chart c ON (c.id = ac.chart_id)
		$dpt_join
		WHERE $where
		$dpt_where
		$project
		GROUP BY c.accno, c.description, c.category
		|;

    if ($form->{project_id}) {

      $query .= qq|

	-- add project transactions from invoice
	
	UNION ALL
	
	        SELECT c.accno, c.description, c.category,
		SUM(ac.sellprice * ac.qty) AS amount
		FROM invoice ac
		JOIN ar a ON (ac.trans_id = a.id)
		JOIN parts p ON (ac.parts_id = p.id)
		JOIN chart c ON (p.income_accno_id = c.id)
		$dpt_join
		WHERE $invwhere
		$dpt_where
		$project
		GROUP BY c.accno, c.description, c.category

	UNION ALL
	
	        SELECT c.accno, c.description, c.category,
		SUM(ac.sellprice * ac.qty) * -1 AS amount
		FROM invoice ac
		JOIN ap a ON (ac.trans_id = a.id)
		JOIN parts p ON (ac.parts_id = p.id)
		JOIN chart c ON (p.expense_accno_id = c.id)
		$dpt_join
		WHERE $invwhere
		$dpt_where
		$project
		GROUP BY c.accno, c.description, c.category
		|;
    }

    $query .= qq|
                ORDER BY accno|;

  }

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);


  # prepare query for each account
  $query = qq|SELECT (SELECT SUM(ac.amount) * -1
	      FROM acc_trans ac
	      JOIN chart c ON (c.id = ac.chart_id)
	      $dpt_join
	      WHERE $where
	      $dpt_where
	      $project
	      AND ac.amount < 0
	      AND c.accno = ?) AS debit,
	      
	     (SELECT SUM(ac.amount)
	      FROM acc_trans ac
	      JOIN chart c ON (c.id = ac.chart_id)
	      $dpt_join
	      WHERE $where
	      $dpt_where
	      $project
	      AND ac.amount > 0
	      AND c.accno = ?) AS credit
	      |;

  if ($form->{accounttype} eq 'gifi') {

    $query = qq|SELECT (SELECT SUM(ac.amount) * -1
		FROM acc_trans ac
		JOIN chart c ON (c.id = ac.chart_id)
		$dpt_join
		WHERE $where
		$dpt_where
		$project
		AND ac.amount < 0
		AND c.gifi_accno = ?) AS debit,
		
	       (SELECT SUM(ac.amount)
		FROM acc_trans ac
		JOIN chart c ON (c.id = ac.chart_id)
		$dpt_join
		WHERE $where
		$dpt_where
		$project
		AND ac.amount > 0
		AND c.gifi_accno = ?) AS credit|;
  
  }
  
  $drcr = $dbh->prepare($query);

  
  if ($form->{project_id}) {
    # prepare query for each account
    $query = qq|SELECT (SELECT SUM(ac.sellprice * ac.qty) * -1
	      FROM invoice ac
	      JOIN parts p ON (ac.parts_id = p.id)
	      JOIN ap a ON (ac.trans_id = a.id)
	      JOIN chart c ON (p.expense_accno_id = c.id)
	      $dpt_join
	      WHERE $invwhere
	      $dpt_where
	      $project
	      AND c.accno = ?) AS debit,
	      
	     (SELECT SUM(ac.sellprice * ac.qty)
	      FROM invoice ac
	      JOIN parts p ON (ac.parts_id = p.id)
	      JOIN ar a ON (ac.trans_id = a.id)
	      JOIN chart c ON (p.income_accno_id = c.id)
	      $dpt_join
	      WHERE $invwhere
	      $dpt_where
	      $project
	      AND c.accno = ?) AS credit
	      |;

    $project_drcr = $dbh->prepare($query);
  
  }
 
  # calculate the debit and credit in the period
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $trb{$ref->{accno}}{description} = $ref->{description};
    $trb{$ref->{accno}}{charttype} = 'A';
    $trb{$ref->{accno}}{category} = $ref->{category};
    $trb{$ref->{accno}}{amount} += $ref->{amount};
  }
  $sth->finish;

  my ($debit, $credit);
  
  foreach my $accno (sort keys %trb) {
    $ref = ();
    
    $ref->{accno} = $accno;
    map { $ref->{$_} = $trb{$accno}{$_} } qw(description category charttype amount);
    
    $ref->{balance} = $form->round_amount($balance{$ref->{accno}}, 2);

    if ($trb{$accno}{charttype} eq 'A') {
      # get DR/CR
      $drcr->execute($ref->{accno}, $ref->{accno}) || $form->dberror($query);
      
      ($debit, $credit) = (0,0);
      while (($debit, $credit) = $drcr->fetchrow_array) {
	$ref->{debit} += $debit;
	$ref->{credit} += $credit;
      }
      $drcr->finish;

      if ($form->{project_id}) {
	# get DR/CR
	$project_drcr->execute($ref->{accno}, $ref->{accno}) || $form->dberror($query);
	
	($debit, $credit) = (0,0);
	while (($debit, $credit) = $project_drcr->fetchrow_array) {
	  $ref->{debit} += $debit;
	  $ref->{credit} += $credit;
	}
	$project_drcr->finish;
      }

      $ref->{debit} = $form->round_amount($ref->{debit}, 2);
      $ref->{credit} = $form->round_amount($ref->{credit}, 2);
    
    }

    # add subtotal
    @accno = grep { $_ le "$ref->{accno}" } @headingaccounts;
    $accno = pop @accno;
    if ($accno) {
      $trb{$accno}{debit} += $ref->{debit};
      $trb{$accno}{credit} += $ref->{credit};
    }

    push @{ $form->{TB} }, $ref;
    
  }

  $dbh->disconnect;

  # debits and credits for headings
  foreach $accno (@headingaccounts) {
    foreach $ref (@{ $form->{TB} }) {
      if ($accno eq $ref->{accno}) {
        $ref->{debit} = $trb{$accno}{debit};
        $ref->{credit} = $trb{$accno}{credit};
      }
    }
  }

  $main::lxdebug->leave_sub();
}


sub aging {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  my $invoice = ($form->{arap} eq 'ar') ? 'is' : 'ir';
  
  $form->{todate} = $form->current_date($myconfig) unless ($form->{todate});

  my $where = "1 = 1";
  my ($name, $null);

  if ($form->{"$form->{ct}_id"}) {
    $where .= qq| AND ct.id = $form->{"$form->{ct}_id"}|;
  } else {
    if ($form->{$form->{ct}}) {
      $name = $form->like(lc $form->{$form->{ct}});
      $where .= qq| AND lower(ct.name) LIKE '$name'| if $form->{$form->{ct}};
    }
  }

  my $dpt_join;
  if ($form->{department}) {
    ($null, $department_id) = split /--/, $form->{department};
    $dpt_join = qq|
               JOIN department d ON (a.department_id = d.id)
	          |;

    $where .= qq| AND a.department_id = $department_id|;
  }
  
  # select outstanding vendors or customers, depends on $ct
  my $query = qq|SELECT DISTINCT ct.id, ct.name
                 FROM $form->{ct} ct, $form->{arap} a
		 $dpt_join
		 WHERE $where
                 AND a.$form->{ct}_id = ct.id
                 AND a.paid != a.amount
                 AND (a.transdate <= '$form->{todate}')
                 ORDER BY ct.name|;

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror;

  my $buysell = ($form->{arap} eq 'ar') ? 'buy' : 'sell';
  
  # for each company that has some stuff outstanding
  while ( my ($id) = $sth->fetchrow_array ) {
  
    $query = qq|

-- between 0-30 days

	SELECT $form->{ct}.id AS ctid, $form->{ct}.name,
	street, zipcode, city, country, contact, email,
	phone as customerphone, fax as customerfax, $form->{ct}number,
	"invnumber", "transdate",
	(amount - paid) as "c0", 0.00 as "c30", 0.00 as "c60", 0.00 as "c90",
	"duedate", invoice, $form->{arap}.id,
	  (SELECT $buysell FROM exchangerate
	   WHERE $form->{arap}.curr = exchangerate.curr
	   AND exchangerate.transdate = $form->{arap}.transdate) AS exchangerate
  FROM $form->{arap}, $form->{ct} 
	WHERE paid != amount
	AND $form->{arap}.$form->{ct}_id = $form->{ct}.id
	AND $form->{ct}.id = $id
	AND (
	        transdate <= (date '$form->{todate}' - interval '0 days') 
	        AND transdate >= (date '$form->{todate}' - interval '30 days')
	    )
	
	UNION

-- between 31-60 days

	SELECT $form->{ct}.id AS ctid, $form->{ct}.name,
	street, zipcode, city, country, contact, email,
	phone as customerphone, fax as customerfax, $form->{ct}number,
	"invnumber", "transdate", 
	0.00 as "c0", (amount - paid) as "c30", 0.00 as "c60", 0.00 as "c90",
	"duedate", invoice, $form->{arap}.id,
	  (SELECT $buysell FROM exchangerate
	   WHERE $form->{arap}.curr = exchangerate.curr
	   AND exchangerate.transdate = $form->{arap}.transdate) AS exchangerate
  FROM $form->{arap}, $form->{ct}
	WHERE paid != amount 
	AND $form->{arap}.$form->{ct}_id = $form->{ct}.id 
	AND $form->{ct}.id = $id
	AND (
		transdate < (date '$form->{todate}' - interval '30 days') 
		AND transdate >= (date '$form->{todate}' - interval '60 days')
		)

	UNION
  
-- between 61-90 days

	SELECT $form->{ct}.id AS ctid, $form->{ct}.name,
	street, zipcode, city, country, contact, email,
	phone as customerphone, fax as customerfax, $form->{ct}number,
	"invnumber", "transdate", 
	0.00 as "c0", 0.00 as "c30", (amount - paid) as "c60", 0.00 as "c90",
	"duedate", invoice, $form->{arap}.id,
	  (SELECT $buysell FROM exchangerate
	   WHERE $form->{arap}.curr = exchangerate.curr
	   AND exchangerate.transdate = $form->{arap}.transdate) AS exchangerate
	FROM $form->{arap}, $form->{ct} 
	WHERE paid != amount
	AND $form->{arap}.$form->{ct}_id = $form->{ct}.id 
	AND $form->{ct}.id = $id
	AND (
		transdate < (date '$form->{todate}' - interval '60 days') 
		AND transdate >= (date '$form->{todate}' - interval '90 days')
		)

	UNION
  
-- over 90 days

	SELECT $form->{ct}.id AS ctid, $form->{ct}.name,
	street, zipcode, city, country, contact, email,
	phone as customerphone, fax as customerfax, $form->{ct}number,
	"invnumber", "transdate", 
	0.00 as "c0", 0.00 as "c30", 0.00 as "c60", (amount - paid) as "c90",
	"duedate", invoice, $form->{arap}.id,
	  (SELECT $buysell FROM exchangerate
	   WHERE $form->{arap}.curr = exchangerate.curr
	   AND exchangerate.transdate = $form->{arap}.transdate) AS exchangerate
	FROM $form->{arap}, $form->{ct} 
	WHERE paid != amount
	AND $form->{arap}.$form->{ct}_id = $form->{ct}.id 
	AND $form->{ct}.id = $id
	AND transdate < (date '$form->{todate}' - interval '90 days') 

	ORDER BY
  
  ctid, transdate, invnumber
  
		|;

    my $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror;

    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
      $ref->{module} = ($ref->{invoice}) ? $invoice : $form->{arap};
      $ref->{exchangerate} = 1 unless $ref->{exchangerate};
      push @{ $form->{AG} }, $ref;
    }
    
    $sth->finish;

  }

  $sth->finish;
  # disconnect
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}


sub get_customer {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT ct.name, ct.email, ct.cc, ct.bcc
                 FROM $form->{ct} ct
		 WHERE ct.id = $form->{"$form->{ct}_id"}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror;

  ($form->{$form->{ct}}, $form->{email}, $form->{cc}, $form->{bcc}) = $sth->fetchrow_array;
  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}


sub get_taxaccounts {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  # get tax accounts
  my $query = qq|SELECT c.accno, c.description, t.rate
                 FROM chart c, tax t
		 WHERE c.link LIKE '%CT_tax%'
		 AND c.id = t.chart_id
                 ORDER BY c.accno|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror;

  my $ref = ();
  while ($ref = $sth->fetchrow_hashref(NAME_lc) ) {
    push @{ $form->{taxaccounts} }, $ref;
  }
  $sth->finish;

  # get gifi tax accounts
  my $query = qq|SELECT DISTINCT ON (g.accno) g.accno, g.description,
                 sum(t.rate) AS rate
                 FROM gifi g, chart c, tax t
		 WHERE g.accno = c.gifi_accno
		 AND c.id = t.chart_id
		 AND c.link LIKE '%CT_tax%'
		 GROUP BY g.accno, g.description
                 ORDER BY accno|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror;

  while ($ref = $sth->fetchrow_hashref(NAME_lc) ) {
    push @{ $form->{gifi_taxaccounts} }, $ref;
  }
  $sth->finish;

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}



sub tax_report {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my ($null, $department_id) = split /--/, $form->{department};
  
  # build WHERE
  my $where = "1 = 1";

  if ($department_id) {
    $where .= qq|
                 AND a.department_id = $department_id
		|;
  }
		 
  my ($accno, $rate);
  
  if ($form->{accno}) {
    if ($form->{accno} =~ /^gifi_/) {
      ($null, $accno) = split /_/, $form->{accno};
      $rate = $form->{"$form->{accno}_rate"};
      $accno = qq| AND ch.gifi_accno = '$accno'|;
    } else {
      $accno = $form->{accno};
      $rate = $form->{"$form->{accno}_rate"};
      $accno = qq| AND ch.accno = '$accno'|;
    }
  }
  $rate *= 1;



  my ($table, $ARAP);
  
  if ($form->{db} eq 'ar') {
    $table = "customer";
    $ARAP = "AR";
  }
  if ($form->{db} eq 'ap') {
    $table = "vendor";
    $ARAP = "AP";
  }

  my $transdate = "a.transdate";
  
  if ($form->{method} eq 'cash') {
    $transdate = "a.datepaid";

    my $todate = ($form->{todate}) ? $form->{todate} : $form->current_date($myconfig);
    
    $where .= qq|
		 AND ac.trans_id IN
		   (
		     SELECT trans_id
		     FROM acc_trans
		     JOIN chart ON (chart_id = id)
		     WHERE link LIKE '%${ARAP}_paid%'
		     AND transdate <= '$todate'
		   )
		  |;
  }

 
  # if there are any dates construct a where
  if ($form->{fromdate} || $form->{todate}) {
    if ($form->{fromdate}) {
      $where .= " AND $transdate >= '$form->{fromdate}'";
    }
    if ($form->{todate}) {
      $where .= " AND $transdate <= '$form->{todate}'";
    }
  }
 
  my $ml = ($form->{db} eq 'ar') ? 1 : -1;
  
  my $sortorder = join ', ', $form->sort_columns(qw(transdate invnumber name));
  $sortorder = $form->{sort} unless $sortorder;
  
  $query = qq|SELECT a.id, '0' AS invoice, $transdate AS transdate,
              a.invnumber, n.name, a.netamount,
	      ac.amount * $ml AS tax
              FROM acc_trans ac
	    JOIN $form->{db} a ON (a.id = ac.trans_id)
	    JOIN chart ch ON (ch.id = ac.chart_id)
	    JOIN $table n ON (n.id = a.${table}_id)
	      WHERE $where
	      $accno
	      AND a.invoice = '0'
	    UNION
	      SELECT a.id, '1' AS invoice, $transdate AS transdate,
	      a.invnumber, n.name, i.sellprice * i.qty AS netamount,
	      i.sellprice * i.qty * $rate * $ml AS tax
	      FROM acc_trans ac
	    JOIN $form->{db} a ON (a.id = ac.trans_id)
	    JOIN chart ch ON (ch.id = ac.chart_id)
	    JOIN $table n ON (n.id = a.${table}_id)
	    JOIN ${table}tax t ON (t.${table}_id = n.id)
	    JOIN invoice i ON (i.trans_id = a.id)
	    JOIN partstax p ON (p.parts_id = i.parts_id)
	      WHERE $where
	      $accno
	      AND a.invoice = '1'
	      ORDER by $sortorder|;

  if ($form->{report} =~ /nontaxable/) {
    # only gather up non-taxable transactions
    $query = qq|SELECT a.id, '0' AS invoice, $transdate AS transdate,
		a.invnumber, n.name, a.netamount
		FROM acc_trans ac
	      JOIN $form->{db} a ON (a.id = ac.trans_id)
	      JOIN $table n ON (n.id = a.${table}_id)
		WHERE $where
		AND a.invoice = '0'
		AND a.netamount = a.amount
	      UNION
		SELECT a.id, '1' AS invoice, $transdate AS transdate,
		a.invnumber, n.name, i.sellprice * i.qty AS netamount
		FROM acc_trans ac
	      JOIN $form->{db} a ON (a.id = ac.trans_id)
	      JOIN $table n ON (n.id = a.${table}_id)
	      JOIN invoice i ON (i.trans_id = a.id)
		WHERE $where
		AND a.invoice = '1'
		AND (
		  a.${table}_id NOT IN (
		        SELECT ${table}_id FROM ${table}tax t (${table}_id)
			               ) OR
	          i.parts_id NOT IN (
		        SELECT parts_id FROM partstax p (parts_id)
			            )
		    )
		GROUP BY a.id, a.invnumber, $transdate, n.name, i.sellprice, i.qty
		ORDER by $sortorder|;
  }

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ( my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{TR} }, $ref;
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}


sub paymentaccounts {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;
 
  # connect to database, turn AutoCommit off
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $ARAP = uc $form->{db};
  
  # get A(R|P)_paid accounts
  my $query = qq|SELECT c.accno, c.description
                 FROM chart c
                 WHERE c.link LIKE '%${ARAP}_paid%'|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
 
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{PR} }, $ref;
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

 
sub payments {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database, turn AutoCommit off
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $ml = 1;
  if ($form->{db} eq 'ar') {
    $table = 'customer';
    $ml = -1;
  }
  if ($form->{db} eq 'ap') {
    $table = 'vendor';
  }
     

  my ($query, $sth);
  my $dpt_join;
  my $where;

  if ($form->{department_id}) {
    $dpt_join = qq|
	         JOIN dpt_trans t ON (t.trans_id = ac.trans_id)
		 |;

    $where = qq|
		 AND t.department_id = $form->{department_id}
		|;
  }

  if ($form->{fromdate}) {
    $where .= " AND ac.transdate >= '$form->{fromdate}'";
  }
  if ($form->{todate}) {
    $where .= " AND ac.transdate <= '$form->{todate}'";
  }
  if (!$form->{fx_transaction}) {
    $where .= " AND ac.fx_transaction = '0'";
  }
  
  my $invnumber;
  my $reference;
  if ($form->{reference}) {
    $reference = $form->like(lc $form->{reference});
    $invnumber = " AND lower(a.invnumber) LIKE '$reference'";
    $reference = " AND lower(g.reference) LIKE '$reference'";
  }
  if ($form->{source}) {
    my $source = $form->like(lc $form->{source});
    $where .= " AND lower(ac.source) LIKE '$source'";
  }
  if ($form->{memo}) {
    my $memo = $form->like(lc $form->{memo});
    $where .= " AND lower(ac.memo) LIKE '$memo'";
  }


  my $sortorder = join ', ', $form->sort_columns(qw(name invnumber ordnumber transdate source));
  
  
  # cycle through each id
  foreach my $accno (split(/ /, $form->{paymentaccounts})) {

    $query = qq|SELECT c.id, c.accno, c.description
                FROM chart c
		WHERE c.accno = '$accno'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    my $ref = $sth->fetchrow_hashref(NAME_lc);
    push @{ $form->{PR} }, $ref;
    $sth->finish;

   
    $query = qq|SELECT c.name, a.invnumber, a.ordnumber,
		ac.transdate, ac.amount * $ml AS paid, ac.source,
		a.invoice, a.id, ac.memo, '$form->{db}' AS module
		FROM acc_trans ac
	        JOIN $form->{db} a ON (ac.trans_id = a.id)
	        JOIN $table c ON (c.id = a.${table}_id)
	        $dpt_join
		WHERE ac.chart_id = $ref->{id}
		$where
		$invnumber
		
 	UNION
		SELECT g.description, g.reference, NULL AS ordnumber,
		ac.transdate, ac.amount * $ml AS paid, ac.source,
		'0' as invoice, g.id, ac.memo, 'gl' AS module
		FROM acc_trans ac
	        JOIN gl g ON (g.id = ac.trans_id)
	        $dpt_join
		WHERE ac.chart_id = $ref->{id}
		$where
		$reference
		AND (ac.amount * $ml) > 0
                ORDER BY $sortorder|;

    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while (my $pr = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $form->{$ref->{id}} }, $pr;
    }
    $sth->finish;

  }
  
  $dbh->disconnect;
  
  $main::lxdebug->leave_sub();
}

sub bwa {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $last_period = 0;
  my $category = "pos_bwa";
  my @categories = qw(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40);

  $form->{decimalplaces} *= 1;

  &get_accounts_g($dbh, $last_period, $form->{fromdate}, $form->{todate}, $form, $category);
  
  # if there are any compare dates
  if ($form->{fromdate} || $form->{todate}) {
    $last_period = 1;
    if ($form->{fromdate}) {
      $form->{fromdate} =~ /[0-9]*\.[0-9]*\.([0-9]*)/;
      $year = $1;
   } else {
        $form->{todate} =~ /[0-9]*\.[0-9]*\.([0-9]*)/;
        $year = $1;
   }    
    $kummfromdate = $form->{comparefromdate};
    $kummtodate = $form->{comparetodate};
    &get_accounts_g($dbh, $last_period, $kummfromdate, $kummtodate, $form, $category);
  }  

  
  
  @periods = qw(jetzt kumm);
  @gesamtleistung = qw(1 2 3);
  @gesamtkosten = qw (10 11 12 13 14 15 16 17 18 19 20);
  @ergebnisse = qw (rohertrag betriebrohertrag betriebsergebnis neutraleraufwand neutralerertrag ergebnisvorsteuern ergebnis gesamtleistung gesamtkosten);

  
  foreach $key (@periods) {
    $form->{"$key"."gesamtleistung"} = 0;
    $form->{"$key"."gesamtkosten"} = 0;
    
    foreach  $category (@categories){

      if (defined($form->{$category}{$key})) {
         $form->{"$key$category"} = $form->format_amount($myconfig, $form->round_amount( $form->{$category}{$key},2));
      }
    }
    foreach $item (@gesamtleistung) {
      $form->{"$key"."gesamtleistung"} += $form->{$item}{$key};
    }
    foreach $item (@gesamtkosten) {
      $form->{"$key"."gesamtkosten"} += $form->{$item}{$key};
    }
    $form->{"$key"."rohertrag"} = $form->{"$key"."gesamtleistung"} - $form->{4}{$key};
    $form->{"$key"."betriebrohertrag"} = $form->{"$key"."rohertrag"} + $form->{5}{$key};
    $form->{"$key"."betriebsergebnis"} = $form->{"$key"."betriebrohertrag"} - $form->{"$key"."gesamtkosten"};
    $form->{"$key"."neutraleraufwand"} = $form->{30}{$key} + $form->{31}{$key};
    $form->{"$key"."neutralertrag"} = $form->{32}{$key} + $form->{33}{$key} + $form->{34}{$key};
    $form->{"$key"."ergebnisvorsteuern"} = $form->{"$key"."betriebsergebnis"} - ($form->{"$key"."neutraleraufwand"} + $form->{"$key"."neutralertrag"});
    $form->{"$key"."ergebnis"} =  $form->{"$key"."ergebnisvorsteuern"} +  $form->{35}{$key};
        
    if ($form->{"$key"."gesamtleistung"} > 0) {
	foreach $category (@categories) {
		if (defined($form->{$category}{$key})) {
			$form->{"$key"."gl"."$category"} = $form->format_amount($myconfig, $form->round_amount( ($form->{$category}{$key}/$form->{"$key"."gesamtleistung"}*100),2));
		}
	}
	foreach $item (@ergebnisse) {
		$form->{"$key"."gl"."$item"} = $form->format_amount($myconfig, $form->round_amount( ($form->{"$key"."$item"}/$form->{"$key"."gesamtleistung"}*100),2));
	}
    }
    
    if ($form->{"$key"."gesamtkosten"} > 0) {
	foreach $category (@categories) {
		if (defined($form->{$category}{$key})) {
			$form->{"$key"."gk"."$category"} = $form->format_amount($myconfig, $form->round_amount( ($form->{$category}{$key}/$form->{"$key"."gesamtkosten"}*100),2));
		}
	}
	foreach $item (@ergebnisse) {
		$form->{"$key"."gk"."$item"} = $form->format_amount($myconfig, $form->round_amount( ($form->{"$key"."$item"}/$form->{"$key"."gesamtkosten"}*100),2));
	}	
    }
    
    if ($form->{10}{$key} > 0) {
	foreach $category (@categories) {
		if (defined($form->{$category}{$key})) {
			$form->{"$key"."pk"."$category"} = $form->format_amount($myconfig, $form->round_amount( ($form->{$category}{$key}/$form->{10}{$key}*100),2));
		}
	}
	foreach $item (@ergebnisse) {
		$form->{"$key"."pk"."$item"} = $form->format_amount($myconfig, $form->round_amount( ($form->{"$key"."$item"}/$form->{10}{$key}*100),2));
	}
    }
    
    if ($form->{4}{$key} > 0) {
	foreach $category (@categories) {
		if (defined($form->{$category}{$key})) {
			$form->{"$key"."auf"."$category"} = $form->format_amount($myconfig, $form->round_amount( ($form->{$category}{$key}/$form->{4}{$key}*100),2));
		}
	}
	foreach $item (@ergebnisse) {
		$form->{"$key"."auf"."$item"} = $form->format_amount($myconfig, $form->round_amount( ($form->{"$key"."$item"}/$form->{4}{$key}*100),2));
	}
    }
    
    foreach $item (@ergebnisse) {
	$form->{"$key"."$item"} =  $form->format_amount($myconfig, $form->round_amount( $form->{"$key"."$item"},2));
    }

    
 }
 $dbh->disconnect; 
 
  $main::lxdebug->leave_sub();
}

sub ustva {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $last_period = 0;
  my $category = "pos_ustva";
  my @categories_cent = qw(51r 86r 97r 93r 96 66 43 45 53 62 65 67);
  my @categories_euro = qw(48 51 86 91 97 93 94);
  $form->{decimalplaces} *= 1;
  
  foreach $item (@categories_cent) {
  	$form->{"$item"} = 0;
  }
  foreach $item (@categories_euro) {
  	$form->{"$item"} = 0;
  }

  &get_accounts_g($dbh, $last_period, $form->{fromdate}, $form->{todate}, $form, $category);
  
#   foreach $item (@categories_cent) {
#   	if ($form->{$item}{"jetzt"} > 0) {
#   		$form->{$item} = $form->{$item}{"jetzt"};
# 		delete $form->{$item}{"jetzt"};
# 	}
#   }
#   foreach $item (@categories_euro) {
#   	if ($form->{$item}{"jetzt"} > 0) {
#   		$form->{$item} = $form->{$item}{"jetzt"};
# 		delete $form->{$item}{"jetzt"};
# 	}  foreach $item (@categories_cent) {
#   	if ($form->{$item}{"jetzt"} > 0) {
#   		$form->{$item} = $form->{$item}{"jetzt"};
# 		delete $form->{$item}{"jetzt"};
# 	}
#   }
#   foreach $item (@categories_euro) {
#   	if ($form->{$item}{"jetzt"} > 0) {
#   		$form->{$item} = $form->{$item}{"jetzt"};
# 		delete $form->{$item}{"jetzt"};
# 	}
#   }  
# 
#    }  
  

  $form->{"51r"} = $form->{"51"} * 0.16;
  $form->{"86r"} = $form->{"86"} * 0.07;
  $form->{"97r"} = $form->{"97"} * 0.16;
  $form->{"93r"} = $form->{"93"} * 0.07;
  $form->{"96"} = $form->{"94"} * 0.16;
  $form->{"43"} =  $form->{"51r"} + $form->{"86r"} + $form->{"97r"} + $form->{"93r"} + $form->{"96"};
  $form->{"45"} = $form->{"43"};
  $form->{"53"} = $form->{"43"};
  $form->{"62"} = $form->{"43"} - $form->{"66"};
  $form->{"65"} = $form->{"43"} - $form->{"66"};  
  $form->{"67"} = $form->{"43"} - $form->{"66"};
  

  foreach $item (@categories_cent) {
  	$form->{$item} =  $form->format_amount($myconfig, $form->round_amount( $form->{$item},2));
  } 

  foreach $item (@categories_euro) {
  	$form->{$item} =  $form->format_amount($myconfig, $form->round_amount( $form->{$item},0));
  } 
  
  $dbh->disconnect; 
 
  $main::lxdebug->leave_sub();
}

sub income_statement {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $last_period = 0;
  my $category = "pos_eur";
  my @categories_einnahmen = qw(1 2 3 4 5 6 7);
  my @categories_ausgaben = qw(8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31);
  
  my @ergebnisse = qw(sumeura sumeurb guvsumme);
  
  $form->{decimalplaces} *= 1;
  
  foreach $item (@categories_einnahmen) {
  	$form->{$item} = 0;
  }
  foreach $item (@categories_ausgaben) {
  	$form->{$item} = 0;
  }
  
  foreach $item (@ergebnisse) {
  	$form->{$item} = 0;
  }
  
  &get_accounts_g($dbh, $last_period, $form->{fromdate}, $form->{todate}, $form, $category);
  
  foreach $item (@categories_einnahmen) {
	$form->{"eur${item}"} =  $form->format_amount($myconfig, $form->round_amount( $form->{$item},2));
	$form->{"sumeura"} += $form->{$item}; 
  } 
  foreach $item (@categories_ausgaben) {
	$form->{"eur${item}"} =  $form->format_amount($myconfig, $form->round_amount( $form->{$item},2));
	$form->{"sumeurb"} += $form->{$item}; 
  }
  
  $form->{"guvsumme"} = $form->{"sumeura"} - $form->{"sumeurb"};
  
  foreach $item (@ergebnisse) {  
	$form->{$item} =  $form->format_amount($myconfig, $form->round_amount( $form->{$item},2));
  }
  $main::lxdebug->leave_sub();
}
1;


