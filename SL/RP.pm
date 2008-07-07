###=====================================================================
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

use SL::DBUtils;
use Data::Dumper;

sub balance_sheet {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $last_period = 0;
  my @categories  = qw(A C L Q);

  # if there are any dates construct a where
  if ($form->{asofdate}) {
    $form->{period} = $form->{this_period} = conv_dateq($form->{asofdate});
  }

  $form->{decimalplaces} *= 1;

  &get_accounts($dbh, $last_period, "", $form->{asofdate}, $form,
                \@categories);

  # if there are any compare dates
  if ($form->{compareasofdate}) {

    $last_period = 1;
    &get_accounts($dbh, $last_period, "", $form->{compareasofdate},
                  $form, \@categories);

    $form->{last_period} = conv_dateq($form->{compareasofdate});

  }

  # disconnect
  $dbh->disconnect;

  # now we got $form->{A}{accno}{ }    assets
  # and $form->{L}{accno}{ }           liabilities
  # and $form->{Q}{accno}{ }           equity
  # build asset accounts

  my $str;
  my $key;

  my %account = (
                 'A' => { 'label'  => 'asset',
                          'labels' => 'assets',
                          'ml'     => -1
                 },
                 'L' => { 'label'  => 'liability',
                          'labels' => 'liabilities',
                          'ml'     => 1
                 },
                 'Q' => { 'label'  => 'equity',
                          'labels' => 'equity',
                          'ml'     => 1
                 });

  foreach my $category (grep { !/C/ } @categories) {

    foreach $key (sort keys %{ $form->{$category} }) {

      $str = ($form->{l_heading}) ? $form->{padding} : "";

      if ($form->{$category}{$key}{charttype} eq "A") {
        $str .=
          ($form->{l_accno})
          ? "$form->{$category}{$key}{accno} - $form->{$category}{$key}{description}"
          : "$form->{$category}{$key}{description}";
      }
      if ($form->{$category}{$key}{charttype} eq "H") {
        if ($account{$category}{subtotal} && $form->{l_subtotal}) {
          $dash = "- ";
          push(@{ $form->{"$account{$category}{label}_account"} },
               "$str$form->{bold}$account{$category}{subdescription}$form->{endbold}"
          );
          push(@{ $form->{"$account{$category}{label}_this_period"} },
               $form->format_amount(
                        $myconfig,
                        $account{$category}{subthis} * $account{$category}{ml},
                        $form->{decimalplaces}, $dash
               ));

          if ($last_period) {
            push(@{ $form->{"$account{$category}{label}_last_period"} },
                 $form->format_amount(
                        $myconfig,
                        $account{$category}{sublast} * $account{$category}{ml},
                        $form->{decimalplaces}, $dash
                 ));
          }
        }

        $str =
          "$form->{bold}$form->{$category}{$key}{description}$form->{endbold}";

        $account{$category}{subthis}        = $form->{$category}{$key}{this};
        $account{$category}{sublast}        = $form->{$category}{$key}{last};
        $account{$category}{subdescription} =
          $form->{$category}{$key}{description};
        $account{$category}{subtotal} = 1;

        $form->{$category}{$key}{this} = 0;
        $form->{$category}{$key}{last} = 0;

        next unless $form->{l_heading};

        $dash = " ";
      }

      # push description onto array
      push(@{ $form->{"$account{$category}{label}_account"} }, $str);

      if ($form->{$category}{$key}{charttype} eq 'A') {
        $form->{"total_$account{$category}{labels}_this_period"} +=
          $form->{$category}{$key}{this} * $account{$category}{ml};
        $dash = "- ";
      }

      push(@{ $form->{"$account{$category}{label}_this_period"} },
           $form->format_amount(
                      $myconfig,
                      $form->{$category}{$key}{this} * $account{$category}{ml},
                      $form->{decimalplaces}, $dash
           ));

      if ($last_period) {
        $form->{"total_$account{$category}{labels}_last_period"} +=
          $form->{$category}{$key}{last} * $account{$category}{ml};

        push(@{ $form->{"$account{$category}{label}_last_period"} },
             $form->format_amount(
                      $myconfig,
                      $form->{$category}{$key}{last} * $account{$category}{ml},
                      $form->{decimalplaces}, $dash
             ));
      }
    }

    $str = ($form->{l_heading}) ? $form->{padding} : "";
    if ($account{$category}{subtotal} && $form->{l_subtotal}) {
      push(@{ $form->{"$account{$category}{label}_account"} },
           "$str$form->{bold}$account{$category}{subdescription}$form->{endbold}"
      );
      push(@{ $form->{"$account{$category}{label}_this_period"} },
           $form->format_amount(
                        $myconfig,
                        $account{$category}{subthis} * $account{$category}{ml},
                        $form->{decimalplaces}, $dash
           ));

      if ($last_period) {
        push(@{ $form->{"$account{$category}{label}_last_period"} },
             $form->format_amount(
                        $myconfig,
                        $account{$category}{sublast} * $account{$category}{ml},
                        $form->{decimalplaces}, $dash
             ));
      }
    }

  }

  # totals for assets, liabilities
  $form->{total_assets_this_period} =
    $form->round_amount($form->{total_assets_this_period},
                        $form->{decimalplaces});
  $form->{total_liabilities_this_period} =
    $form->round_amount($form->{total_liabilities_this_period},
                        $form->{decimalplaces});
  $form->{total_equity_this_period} =
    $form->round_amount($form->{total_equity_this_period},
                        $form->{decimalplaces});

  # calculate earnings
  $form->{earnings_this_period} =
    $form->{total_assets_this_period} -
    $form->{total_liabilities_this_period} - $form->{total_equity_this_period};

  push(@{ $form->{equity_this_period} },
       $form->format_amount($myconfig,
                            $form->{earnings_this_period},
                            $form->{decimalplaces}, "- "
       ));

  $form->{total_equity_this_period} =
    $form->round_amount(
             $form->{total_equity_this_period} + $form->{earnings_this_period},
             $form->{decimalplaces});

  # add liability + equity
  $form->{total_this_period} =
    $form->format_amount(
    $myconfig,
    $form->{total_liabilities_this_period} + $form->{total_equity_this_period},
    $form->{decimalplaces},
    "- ");

  if ($last_period) {

    # totals for assets, liabilities
    $form->{total_assets_last_period} =
      $form->round_amount($form->{total_assets_last_period},
                          $form->{decimalplaces});
    $form->{total_liabilities_last_period} =
      $form->round_amount($form->{total_liabilities_last_period},
                          $form->{decimalplaces});
    $form->{total_equity_last_period} =
      $form->round_amount($form->{total_equity_last_period},
                          $form->{decimalplaces});

    # calculate retained earnings
    $form->{earnings_last_period} =
      $form->{total_assets_last_period} -
      $form->{total_liabilities_last_period} -
      $form->{total_equity_last_period};

    push(@{ $form->{equity_last_period} },
         $form->format_amount($myconfig,
                              $form->{earnings_last_period},
                              $form->{decimalplaces}, "- "
         ));

    $form->{total_equity_last_period} =
      $form->round_amount(
             $form->{total_equity_last_period} + $form->{earnings_last_period},
             $form->{decimalplaces});

    # add liability + equity
    $form->{total_last_period} =
      $form->format_amount($myconfig,
                           $form->{total_liabilities_last_period} +
                             $form->{total_equity_last_period},
                           $form->{decimalplaces},
                           "- ");

  }

  $form->{total_liabilities_last_period} =
    $form->format_amount($myconfig,
                         $form->{total_liabilities_last_period},
                         $form->{decimalplaces}, "- ")
    if ($form->{total_liabilities_last_period} != 0);

  $form->{total_equity_last_period} =
    $form->format_amount($myconfig,
                         $form->{total_equity_last_period},
                         $form->{decimalplaces}, "- ")
    if ($form->{total_equity_last_period} != 0);

  $form->{total_assets_last_period} =
    $form->format_amount($myconfig,
                         $form->{total_assets_last_period},
                         $form->{decimalplaces}, "- ")
    if ($form->{total_assets_last_period} != 0);

  $form->{total_assets_this_period} =
    $form->format_amount($myconfig,
                         $form->{total_assets_this_period},
                         $form->{decimalplaces}, "- ");

  $form->{total_liabilities_this_period} =
    $form->format_amount($myconfig,
                         $form->{total_liabilities_this_period},
                         $form->{decimalplaces}, "- ");

  $form->{total_equity_this_period} =
    $form->format_amount($myconfig,
                         $form->{total_equity_this_period},
                         $form->{decimalplaces}, "- ");

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
  my $where    = "1 = 1";
  my $glwhere  = "";
  my $subwhere = "";
  my $item;
  my $sth;

  my $category = qq| AND (| . join(" OR ", map({ "(c.category = " . $dbh->quote($_) . ")" } @{$categories})) . qq|) |;

  # get headings
  $query =
    qq|SELECT c.accno, c.description, c.category
       FROM chart c
       WHERE (c.charttype = 'H')
         $category
       ORDER by c.accno|;

  $sth = prepare_execute_query($form, $dbh, $query);

  my @headingaccounts = ();
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $form->{ $ref->{category} }{ $ref->{accno} }{description} =
      "$ref->{description}";
    $form->{ $ref->{category} }{ $ref->{accno} }{charttype} = "H";
    $form->{ $ref->{category} }{ $ref->{accno} }{accno}     = $ref->{accno};

    push @headingaccounts, $ref->{accno};
  }

  $sth->finish;

  if ($fromdate) {
    $fromdate = conv_dateq($fromdate);
    if ($form->{method} eq 'cash') {
      $subwhere .= " AND (transdate >= $fromdate)";
      $glwhere = " AND (ac.transdate >= $fromdate)";
    } else {
      $where .= " AND (ac.transdate >= $fromdate)";
    }
  }

  if ($todate) {
    $todate = conv_dateq($todate);
    $where    .= " AND (ac.transdate <= $todate)";
    $subwhere .= " AND (transdate <= $todate)";
  }

  if ($department_id) {
    $dpt_join = qq| JOIN department t ON (a.department_id = t.id) |;
    $dpt_where = qq| AND (t.id = | . conv_i($department_id, 'NULL') . qq|)|;
  }

  if ($form->{project_id}) {
    $project = qq| AND (ac.project_id = | . conv_i($form->{project_id}, 'NULL') . qq|) |;
  }

  if ($form->{method} eq 'cash') {
    $query =
      qq|SELECT c.accno, sum(ac.amount) AS amount, c.description, c.category
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
               WHERE (link LIKE '%AR_paid%')
               $subwhere
             )
           $project
         GROUP BY c.accno, c.description, c.category

         UNION ALL

         SELECT c.accno, sum(ac.amount) AS amount, c.description, c.category
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
               WHERE (link LIKE '%AP_paid%')
               $subwhere
             )
           $project
         GROUP BY c.accno, c.description, c.category

         UNION ALL

         SELECT c.accno, sum(ac.amount) AS amount, c.description, c.category
         FROM acc_trans ac
         JOIN chart c ON (c.id = ac.chart_id)
         JOIN gl a ON (a.id = ac.trans_id)
         $dpt_join
         WHERE $where
           $glwhere
           $dpt_where
           $category
             AND NOT ((c.link = 'AR') OR (c.link = 'AP'))
           $project
         GROUP BY c.accno, c.description, c.category |;

    if ($form->{project_id}) {
      $query .=
        qq|
         UNION ALL

         SELECT c.accno AS accno, SUM(ac.sellprice * ac.qty) AS amount, c.description AS description, c.category
         FROM invoice ac
         JOIN ar a ON (a.id = ac.trans_id)
         JOIN parts p ON (ac.parts_id = p.id)
         JOIN chart c on (p.income_accno_id = c.id)
         $dpt_join
         -- use transdate from subwhere
         WHERE (c.category = 'I')
           $subwhere
           $dpt_where
           AND ac.trans_id IN
             (
               SELECT trans_id
               FROM acc_trans
               JOIN chart ON (chart_id = id)
               WHERE (link LIKE '%AR_paid%')
               $subwhere
             )
           $project
         GROUP BY c.accno, c.description, c.category

         UNION ALL

         SELECT c.accno AS accno, SUM(ac.sellprice) AS amount, c.description AS description, c.category
         FROM invoice ac
         JOIN ap a ON (a.id = ac.trans_id)
         JOIN parts p ON (ac.parts_id = p.id)
         JOIN chart c on (p.expense_accno_id = c.id)
         $dpt_join
         WHERE (c.category = 'E')
           $subwhere
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
         GROUP BY c.accno, c.description, c.category |;
    }

  } else {                      # if ($form->{method} eq 'cash')
    if ($department_id) {
      $dpt_join = qq| JOIN dpt_trans t ON (t.trans_id = ac.trans_id) |;
      $dpt_where = qq| AND t.department_id = $department_id |;
    }

    $query = qq|
      SELECT c.accno, sum(ac.amount) AS amount, c.description, c.category
      FROM acc_trans ac
      JOIN chart c ON (c.id = ac.chart_id)
      $dpt_join
      WHERE $where
        $dpt_where
        $category
        $project
      GROUP BY c.accno, c.description, c.category |;

    if ($form->{project_id}) {
      $query .= qq|
      UNION ALL

      SELECT c.accno AS accno, SUM(ac.sellprice * ac.qty) AS amount, c.description AS description, c.category
      FROM invoice ac
      JOIN ar a ON (a.id = ac.trans_id)
      JOIN parts p ON (ac.parts_id = p.id)
      JOIN chart c on (p.income_accno_id = c.id)
      $dpt_join
      -- use transdate from subwhere
      WHERE (c.category = 'I')
        $subwhere
        $dpt_where
        $project
      GROUP BY c.accno, c.description, c.category

      UNION ALL

      SELECT c.accno AS accno, SUM(ac.sellprice * ac.qty) * -1 AS amount, c.description AS description, c.category
      FROM invoice ac
      JOIN ap a ON (a.id = ac.trans_id)
      JOIN parts p ON (ac.parts_id = p.id)
      JOIN chart c on (p.expense_accno_id = c.id)
      $dpt_join
      WHERE (c.category = 'E')
        $subwhere
        $dpt_where
        $project
      GROUP BY c.accno, c.description, c.category |;
    }
  }

  my @accno;
  my $accno;
  my $ref;

  my $sth = prepare_execute_query($form, $dbh, $query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {

    if ($ref->{category} eq 'C') {
      $ref->{category} = 'A';
    }

    # get last heading account
    @accno = grep { $_ le "$ref->{accno}" } @headingaccounts;
    $accno = pop @accno;
    if ($accno) {
      if ($last_period) {
        $form->{ $ref->{category} }{$accno}{last} += $ref->{amount};
      } else {
        $form->{ $ref->{category} }{$accno}{this} += $ref->{amount};
      }
    }

    $form->{ $ref->{category} }{ $ref->{accno} }{accno}       = $ref->{accno};
    $form->{ $ref->{category} }{ $ref->{accno} }{description} =
      $ref->{description};
    $form->{ $ref->{category} }{ $ref->{accno} }{charttype} = "A";

    if ($last_period) {
      $form->{ $ref->{category} }{ $ref->{accno} }{last} += $ref->{amount};
    } else {
      $form->{ $ref->{category} }{ $ref->{accno} }{this} += $ref->{amount};
    }
  }
  $sth->finish;

  # remove accounts with zero balance
  foreach $category (@{$categories}) {
    foreach $accno (keys %{ $form->{$category} }) {
      $form->{$category}{$accno}{last} =
        $form->round_amount($form->{$category}{$accno}{last},
                            $form->{decimalplaces});
      $form->{$category}{$accno}{this} =
        $form->round_amount($form->{$category}{$accno}{this},
                            $form->{decimalplaces});

      delete $form->{$category}{$accno}
        if (   $form->{$category}{$accno}{this} == 0
            && $form->{$category}{$accno}{last} == 0);
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
  my $where    = "1 = 1";
  my $glwhere  = "";
  my $prwhere  = "";
  my $subwhere = "";
  my $item;

  if ($fromdate) {
    $fromdate = conv_dateq($fromdate);
    if ($form->{method} eq 'cash') {
      $subwhere .= " AND (transdate    >= $fromdate)";
      $glwhere   = " AND (ac.transdate >= $fromdate)";
      $prwhere   = " AND (ar.transdate >= $fromdate)";
    } else {
      $where    .= " AND (ac.transdate >= $fromdate)";
    }
  }

  if ($todate) {
    $todate = conv_dateq($todate);
    $subwhere   .= " AND (transdate    <= $todate)";
    $where      .= " AND (ac.transdate <= $todate)";
    $prwhere    .= " AND (ar.transdate <= $todate)";
  }

  if ($department_id) {
    $dpt_join = qq| JOIN department t ON (a.department_id = t.id) |;
    $dpt_where = qq| AND (t.id = | . conv_i($department_id, 'NULL') . qq|) |;
  }

  if ($form->{project_id}) {
    $project = qq| AND (ac.project_id = | . conv_i($form->{project_id}) . qq|) |;
  }

  if ($form->{method} eq 'cash') {
    $query =
      qq|
       SELECT SUM(ac.amount * chart_category_to_sgn(c.category)) AS amount, c.$category
         FROM acc_trans ac
         JOIN chart c ON (c.id = ac.chart_id)
         JOIN ar a ON (a.id = ac.trans_id)
         $dpt_join
         WHERE $where $dpt_where
           AND ac.trans_id IN ( SELECT trans_id FROM acc_trans JOIN chart ON (chart_id = id) WHERE (link LIKE '%AR_paid%') $subwhere)
           $project
         GROUP BY c.$category 

         UNION

         SELECT SUM(ac.amount * chart_category_to_sgn(c.category)) AS amount, c.$category
         FROM acc_trans ac
         JOIN chart c ON (c.id = ac.chart_id)
         JOIN ap a ON (a.id = ac.trans_id)
         $dpt_join
         WHERE $where $dpt_where
           AND ac.trans_id IN ( SELECT trans_id FROM acc_trans JOIN chart ON (chart_id = id) WHERE (link LIKE '%AP_paid%') $subwhere)
           $project
         GROUP BY c.$category 

         UNION

         SELECT SUM(ac.amount * chart_category_to_sgn(c.category)) AS amount, c.$category
         FROM acc_trans ac
         JOIN chart c ON (c.id = ac.chart_id)
         JOIN gl a ON (a.id = ac.trans_id)
         $dpt_join
         WHERE $where $dpt_where $glwhere 
           AND NOT ((c.link = 'AR') OR (c.link = 'AP'))
           $project

         $project_union
        GROUP BY c.$category 
        |;

    if ($form->{project_id}) {
      $project_union = qq|
         UNION

         SELECT SUM(ac.sellprice * ac.qty * chart_category_to_sgn(c.category)) AS amount, c.$category
         FROM invoice ac
         JOIN ar a ON (a.id = ac.trans_id)
         JOIN parts p ON (ac.parts_id = p.id)
         JOIN chart c on (p.income_accno_id = c.id)
         $dpt_join
         WHERE (c.category = 'I') $prwhere $dpt_where
           AND ac.trans_id IN ( SELECT trans_id FROM acc_trans JOIN chart ON (chart_id = id) WHERE (link LIKE '%AR_paid%') $subwhere)
           $project
         GROUP BY c.$category 

         UNION

         SELECT SUM(ac.sellprice * chart_category_to_sgn(c.category)) AS amount, c.$category
         FROM invoice ac
         JOIN ap a ON (a.id = ac.trans_id)
         JOIN parts p ON (ac.parts_id = p.id)
         JOIN chart c on (p.expense_accno_id = c.id)
         $dpt_join
         WHERE (c.category = 'E') $prwhere $dpt_where
           AND ac.trans_id IN ( SELECT trans_id FROM acc_trans JOIN chart ON (chart_id = id) WHERE (link LIKE '%AP_paid%') $subwhere)
         $project
         GROUP BY c.$category 
         |;
    }

  } else {                      # if ($form->{method} eq 'cash')
    if ($department_id) {
      $dpt_join = qq| JOIN dpt_trans t ON (t.trans_id = ac.trans_id) |;
      $dpt_where = qq| AND (t.department_id = | . conv_i($department_id, 'NULL') . qq|) |;
    }

    $query = qq|
        SELECT sum(ac.amount * chart_category_to_sgn(c.category)) AS amount, c.$category
        FROM acc_trans ac
        JOIN chart c ON (c.id = ac.chart_id)
        $dpt_join
        WHERE $where
          $dpt_where
          $project
        GROUP BY c.$category |;

    if ($form->{project_id}) {
      $query .= qq|
        UNION

        SELECT SUM(ac.sellprice * ac.qty * chart_category_to_sgn(c.category)) AS amount, c.$category
        FROM invoice ac
        JOIN ar a ON (a.id = ac.trans_id)
        JOIN parts p ON (ac.parts_id = p.id)
        JOIN chart c on (p.income_accno_id = c.id)
        $dpt_join
        WHERE (c.category = 'I')
          $prwhere
          $dpt_where
          $project
        GROUP BY c.$category

        UNION

        SELECT SUM(ac.sellprice * ac.qty * chart_category_to_sgn(c.category)) AS amount, c.$category
        FROM invoice ac
        JOIN ap a ON (a.id = ac.trans_id)
        JOIN parts p ON (ac.parts_id = p.id)
        JOIN chart c on (p.expense_accno_id = c.id)
        $dpt_join
        WHERE (c.category = 'E')
          $prwhere
          $dpt_where
          $project
        GROUP BY c.$category |;
    }
  }

  my @accno;
  my $accno;
  my $ref;

  my $sth = prepare_execute_query($form, $dbh, $query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    if ($category eq "pos_bwa") {
      if ($last_period) {
        $form->{ $ref->{$category} }{kumm} += $ref->{amount};
      } else {
        $form->{ $ref->{$category} }{jetzt} += $ref->{amount};
      }
    } else {
      $form->{ $ref->{$category} } += $ref->{amount};
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
  my %trb     = ();
  my ($null, $department_id) = split /--/, $form->{department};
  my @headingaccounts = ();
  my $dpt_where;
  my $dpt_join;
  my $project;

  my $where    = "1 = 1";
  my $invwhere = $where;

  if ($department_id) {
    $dpt_join = qq| JOIN dpt_trans t ON (ac.trans_id = t.trans_id) |;
    $dpt_where = qq| AND (t.department_id = | . conv_i($department_id, 'NULL') . qq|) |;
  }

  # project_id only applies to getting transactions
  # it has nothing to do with a trial balance
  # but we use the same function to collect information

  if ($form->{project_id}) {
    $project = qq| AND (ac.project_id = | . conv_i($form->{project_id}, 'NULL') . qq|) |;
  }

  my $acc_cash_where = "";
  my $ar_cash_where = "";
  my $ap_cash_where = "";


  if ($form->{method} eq "cash") {
    $acc_cash_where = qq| AND (ac.trans_id IN (SELECT id FROM ar WHERE datepaid>='$form->{fromdate}' AND datepaid<='$form->{todate}' UNION SELECT id FROM ap WHERE datepaid>='$form->{fromdate}' AND datepaid<='$form->{todate}' UNION SELECT id FROM gl WHERE transdate>='$form->{fromdate}' AND transdate<='$form->{todate}')) |;
    $ar_ap_cash_where = qq| AND (a.datepaid>='$form->{fromdate}' AND a.datepaid<='$form->{todate}') |;
  }

  # get beginning balances
  $query =
    qq|SELECT c.accno, c.category, SUM(ac.amount) AS amount, c.description
        FROM acc_trans ac
        LEFT JOIN chart c ON (ac.chart_id = c.id)
        $dpt_join
        WHERE ((select date_trunc('year', ac.transdate::date)) = (select date_trunc('year', ?::date))) AND ac.ob_transaction $acc_cash_where
          $dpt_where
          $project
        GROUP BY c.accno, c.category, c.description |;

  $sth = prepare_execute_query($form, $dbh, $query, $form->{fromdate});

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {

    if ($ref->{amount} != 0 || $form->{all_accounts}) {
      $trb{ $ref->{accno} }{description} = $ref->{description};
      $trb{ $ref->{accno} }{charttype}   = 'A';
   
      if ($ref->{amount} > 0) {
        $trb{ $ref->{accno} }{haben_eb}   = $ref->{amount};
      } else {
        $trb{ $ref->{accno} }{soll_eb}   = $ref->{amount} * -1;
      }
      $trb{ $ref->{accno} }{category}    = $ref->{category};
    }

  }
  $sth->finish;


  # get headings
  $query =
    qq|SELECT c.accno, c.description, c.category
       FROM chart c
       WHERE c.charttype = 'H'
       ORDER by c.accno|;

  $sth = prepare_execute_query($form, $dbh, $query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $trb{ $ref->{accno} }{description} = $ref->{description};
    $trb{ $ref->{accno} }{charttype}   = 'H';
    $trb{ $ref->{accno} }{category}    = $ref->{category};

    push @headingaccounts, $ref->{accno};
  }

  $sth->finish;

  $where = " 1 = 1 ";
  $saldowhere = " 1 = 1 ";
  $sumwhere = " 1 = 1 ";
  my $tofrom;

  if ($form->{fromdate} || $form->{todate}) {
    if ($form->{fromdate}) {
      my $fromdate = conv_dateq($form->{fromdate});
      $tofrom   .= " AND (ac.transdate >= $fromdate)";
      $subwhere .= " AND (transdate >= $fromdate)";
      $sumsubwhere .= " AND (transdate >= (select date_trunc('year', date $fromdate))) ";
      $saldosubwhere .= " AND transdate>=(select date_trunc('year', date $fromdate))  ";
      $invwhere .= " AND (a.transdate >= $fromdate)";
      $glsaldowhere .= " AND ac.transdate>=(select date_trunc('year', date $fromdate)) ";
      $glwhere = " AND (ac.transdate >= $fromdate)";
      $glsumwhere = " AND (ac.transdate >= (select date_trunc('year', date $fromdate))) ";
    }
    if ($form->{todate}) {
      my $todate = conv_dateq($form->{todate});
      $tofrom   .= " AND (ac.transdate <= $todate)";
      $invwhere .= " AND (a.transdate <= $todate)";
      $saldosubwhere .= " AND (transdate <= $todate)";
      $sumsubwhere .= " AND (transdate <= $todate)";
      $subwhere .= " AND (transdate <= $todate)";
      $glwhere  .= " AND (ac.transdate <= $todate)";
      $glsumwhere .= " AND (ac.transdate <= $todate) ";
      $glsaldowhere .= " AND (ac.transdate <= $todate) ";
   }
  }

  if ($form->{method} eq "cash") {
    $where .=
      qq| AND ((ac.trans_id IN (SELECT id from ar) AND
                ac.trans_id IN
                  (
                    SELECT trans_id
                    FROM acc_trans
                    JOIN chart ON (chart_id = id)
                    WHERE (link LIKE '%AR_paid%')
                      $subwhere
                  )
               )
               OR
               (ac.trans_id in (SELECT id from ap) AND
                ac.trans_id IN
                  (
                    SELECT trans_id
                    FROM acc_trans
                    JOIN chart ON (chart_id = id)
                    WHERE (link LIKE '%AP_paid%')
                      $subwhere
                  )
               )
               OR
               (ac.trans_id in (SELECT id from gl)
                $glwhere)
              )|;
    $saldowhere .=       
qq| AND ((ac.trans_id IN (SELECT id from ar) AND
                ac.trans_id IN
                  (
                    SELECT trans_id
                    FROM acc_trans
                    JOIN chart ON (chart_id = id)
                    WHERE (link LIKE '%AR_paid%')
                      $saldosubwhere
                  )
               )
               OR
               (ac.trans_id in (SELECT id from ap) AND
                ac.trans_id IN
                  (
                    SELECT trans_id
                    FROM acc_trans
                    JOIN chart ON (chart_id = id)
                    WHERE (link LIKE '%AP_paid%')
                      $saldosubwhere
                  )
               )
               OR
               (ac.trans_id in (SELECT id from gl)
                $glsaldowhere)
              )|;
    $sumwhere .=       
qq| AND ((ac.trans_id IN (SELECT id from ar) AND
                ac.trans_id IN
                  (
                    SELECT trans_id
                    FROM acc_trans
                    JOIN chart ON (chart_id = id)
                    WHERE (link LIKE '%AR_paid%')
                      $sumsubwhere
                  )
               )
               OR
               (ac.trans_id in (SELECT id from ap) AND
                ac.trans_id IN
                  (
                    SELECT trans_id
                    FROM acc_trans
                    JOIN chart ON (chart_id = id)
                    WHERE (link LIKE '%AP_paid%')
                      $sumsubwhere
                  )
               )
               OR
               (ac.trans_id in (SELECT id from gl)
                $glsumwhere)
              )|;

  } else {
    $where .= $tofrom . " AND (NOT ac.ob_transaction OR ac.ob_transaction IS NULL) AND (NOT ac.cb_transaction OR ac.cb_transaction IS NULL)";
    $saldowhere .= $glsaldowhere . " AND (NOT ac.cb_transaction OR ac.cb_transaction IS NULL)";
    $sumwhere .= $glsumwhere . " AND (NOT ac.ob_transaction OR ac.ob_transaction IS NULL) AND (NOT ac.cb_transaction OR ac.cb_transaction IS NULL)";
  }

  $query = qq|
       SELECT c.accno, c.description, c.category, SUM(ac.amount) AS amount
       FROM acc_trans ac
       JOIN chart c ON (c.id = ac.chart_id)
       $dpt_join
       WHERE $where
         $dpt_where
         $project
       GROUP BY c.accno, c.description, c.category |;

  if ($form->{project_id}) {
    $query .= qq|
      -- add project transactions from invoice

      UNION ALL

      SELECT c.accno, c.description, c.category, SUM(ac.sellprice * ac.qty) AS amount
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

      SELECT c.accno, c.description, c.category, SUM(ac.sellprice * ac.qty) * -1 AS amount
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

  $query .= qq| ORDER BY accno|;

  $sth = prepare_execute_query($form, $dbh, $query);

  # calculate the debit and credit in the period
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $trb{ $ref->{accno} }{description} = $ref->{description};
    $trb{ $ref->{accno} }{charttype}   = 'A';
    $trb{ $ref->{accno} }{category}    = $ref->{category};
    $trb{ $ref->{accno} }{amount} += $ref->{amount};
  }
  $sth->finish;

  # prepare query for each account
  my ($q_drcr, $drcr, $q_project_drcr, $project_drcr);

  $q_drcr =
    qq|SELECT
         (SELECT SUM(ac.amount) * -1
          FROM acc_trans ac
          JOIN chart c ON (c.id = ac.chart_id)
          $dpt_join
          WHERE $where
            $dpt_where
            $project
          AND (ac.amount < 0)
          AND (c.accno = ?)) AS debit,

         (SELECT SUM(ac.amount)
          FROM acc_trans ac
          JOIN chart c ON (c.id = ac.chart_id)
          $dpt_join
          WHERE $where
            $dpt_where
            $project
          AND ac.amount > 0
          AND c.accno = ?) AS credit,
        (SELECT SUM(ac.amount)
         FROM acc_trans ac
         JOIN chart c ON (ac.chart_id = c.id)
         $dpt_join
         WHERE $saldowhere
           $dpt_where
           $project
         AND c.accno = ?) AS saldo,

        (SELECT SUM(ac.amount)
         FROM acc_trans ac
         JOIN chart c ON (ac.chart_id = c.id)
         $dpt_join
         WHERE $sumwhere
           $dpt_where
           $project
         AND amount > 0
         AND c.accno = ?) AS sum_credit,

        (SELECT SUM(ac.amount)
         FROM acc_trans ac
         JOIN chart c ON (ac.chart_id = c.id)
         $dpt_join
         WHERE $sumwhere
           $dpt_where
           $project
         AND amount < 0
         AND c.accno = ?) AS sum_debit,

        (SELECT max(ac.transdate) FROM acc_trans ac
        JOIN chart c ON (ac.chart_id = c.id)
        $dpt_join
        WHERE $where
          $dpt_where
          $project
        AND c.accno = ?) AS last_transaction


 |;

  $drcr = prepare_query($form, $dbh, $q_drcr);

  if ($form->{project_id}) {
    # prepare query for each account
    $q_project_drcr =
      qq|SELECT
          (SELECT SUM(ac.sellprice * ac.qty) * -1
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
           AND c.accno = ?) AS credit,

        (SELECT SUM(ac.amount)
         FROM acc_trans ac
         JOIN chart c ON (ac.chart_id = c.id)
         $dpt_join
         WHERE $saldowhere
           $dpt_where
           $project
         AND c.accno = ?) AS saldo,

        (SELECT SUM(ac.amount)
         FROM acc_trans ac
         JOIN chart c ON (ac.chart_id = c.id)
         $dpt_join
         WHERE $sumwhere
           $dpt_where
           $project
         AND amount > 0
         AND c.accno = ?) AS sum_credit,

        (SELECT SUM(ac.amount)
         FROM acc_trans ac
         JOIN chart c ON (ac.chart_id = c.id)
         $dpt_join
         WHERE $sumwhere
           $dpt_where
           $project
         AND amount < 0
         AND c.accno = ?) AS sum_debit,


        (SELECT max(ac.transdate) FROM acc_trans ac
        JOIN chart c ON (ac.chart_id = c.id)
        $dpt_join
        WHERE $where
          $dpt_where
          $project
        AND c.accno = ?) AS last_transaction
 |;

    $project_drcr = prepare_query($form, $dbh, $q_project_drcr);
  }


  my ($debit, $credit, $saldo, $soll_saldo, $haben_saldo,$soll_kummuliert, $haben_kummuliert, $last_transaction);

  foreach my $accno (sort keys %trb) {
    $ref = {};

    $ref->{accno} = $accno;
    map { $ref->{$_} = $trb{$accno}{$_} }
      qw(description category charttype amount soll_eb haben_eb);

    $ref->{balance} = $form->round_amount($balance{ $ref->{accno} }, 2);

    if ($trb{$accno}{charttype} eq 'A') {

      # get DR/CR
      do_statement($form, $drcr, $q_drcr, $ref->{accno}, $ref->{accno}, $ref->{accno}, $ref->{accno}, $ref->{accno}, $ref->{accno});

      ($debit, $credit, $saldo, $haben_saldo, $soll_saldo, $soll_kumuliert, $haben_kumuliert) = (0, 0, 0, 0, 0, 0, 0);
      $last_transaction = "";
      while (($debit, $credit, $saldo, $haben_kumuliert, $soll_kumuliert, $last_transaction) = $drcr->fetchrow_array) {
        $ref->{debit}  += $debit;
        $ref->{credit} += $credit;
        if ($saldo >= 0) {
          $ref->{haben_saldo} += $saldo;
        } else {
          $ref->{soll_saldo} += $saldo * -1;
        }
        $ref->{last_transaction} = $last_transaction;
        $ref->{soll_kumuliert} = $soll_kumuliert * -1;
        $ref->{haben_kumuliert} = $haben_kumuliert;
      }
      $drcr->finish;

      if ($form->{project_id}) {

        # get DR/CR
        do_statement($form, $project_drcr, $q_project_drcr, $ref->{accno}, $ref->{accno}, $ref->{accno}, $ref->{accno}, $ref->{accno}, $ref->{accno});

        ($debit, $credit) = (0, 0);
        while (($debit, $credit, $saldo, $haben_kumuliert, $soll_kumuliert, $last_transaction) = $project_drcr->fetchrow_array) {
          $ref->{debit}  += $debit;
          $ref->{credit} += $credit;
          if ($saldo >= 0) {
            $ref->{haben_saldo} += $saldo;
          } else {
            $ref->{soll_saldo} += $saldo * -1;
          }
          $ref->{soll_kumuliert} += $soll_kumuliert * -1;
          $ref->{haben_kumuliert} += $haben_kumuliert;
        }
        $project_drcr->finish;
      }

      $ref->{debit}  = $form->round_amount($ref->{debit},  2);
      $ref->{credit} = $form->round_amount($ref->{credit}, 2);
      $ref->{haben_saldo}  = $form->round_amount($ref->{haben_saldo},  2);
      $ref->{soll_saldo} = $form->round_amount($ref->{soll_saldo}, 2);
      $ref->{haben_kumuliert}  = $form->round_amount($ref->{haben_kumuliert},  2);
      $ref->{soll_kumuliert} = $form->round_amount($ref->{soll_kumuliert}, 2);
    }

    # add subtotal
    @accno = grep { $_ le "$ref->{accno}" } @headingaccounts;
    $accno = pop @accno;
    if ($accno) {
      $trb{$accno}{debit}  += $ref->{debit};
      $trb{$accno}{credit} += $ref->{credit};
      $trb{$accno}{soll_saldo}  += $ref->{soll_saldo};
      $trb{$accno}{haben_saldo} += $ref->{haben_saldo};
      $trb{$accno}{soll_kumuliert}  += $ref->{soll_kumuliert};
      $trb{$accno}{haben_kumuliert} += $ref->{haben_kumuliert};
    }

    push @{ $form->{TB} }, $ref;

  }

  $dbh->disconnect;

  # debits and credits for headings
  foreach $accno (@headingaccounts) {
    foreach $ref (@{ $form->{TB} }) {
      if ($accno eq $ref->{accno}) {
        $ref->{debit}  = $trb{$accno}{debit};
        $ref->{credit} = $trb{$accno}{credit};
        $ref->{soll_saldo}  = $trb{$accno}{soll_saldo};
        $ref->{haben_saldo} = $trb{$accno}{haben_saldo};
        $ref->{soll_kumuliert}  = $trb{$accno}{soll_kumuliert};
        $ref->{haben_kumuliert} = $trb{$accno}{haben_kumuliert};      }
    }
  }

  $main::lxdebug->leave_sub();
}

sub get_storno {
  $main::lxdebug->enter_sub();
  my ($self, $dbh, $form) = @_;
  my $arap = $form->{arap} eq "ar" ? "ar" : "ap";
  my $query = qq|SELECT invnumber FROM $arap WHERE invnumber LIKE "Storno zu "|;
  my $sth =  $dbh->prepare($query);
  while(my $ref = $sth->fetchrow_hashref()) {
    $ref->{invnumer} =~ s/Storno zu //g;
    $form->{storno}{$ref->{invnumber}} = 1;
  }
  $main::lxdebug->leave_sub();
}

sub aging {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh     = $form->dbconnect($myconfig);

  my ($invoice, $arap, $buysell, $ct, $ct_id, $ml);

  if ($form->{ct} eq "customer") {
    $invoice = "is";
    $arap = "ar";
    $buysell = "buy";
    $ct = "customer";
    $ml = -1;
  } else {
    $invoice = "ir";
    $arap = "ap";
    $buysell = "sell";
    $ct = "vendor";
    $ml = 1;
  }
  $ct_id = "${ct}_id";

  $form->{todate} = $form->current_date($myconfig) unless ($form->{todate});
  my $todate = conv_dateq($form->{todate});
  my $fromdate = conv_dateq($form->{fromdate});

  my $fromwhere = ($form->{fromdate} ne "") ? " AND (transdate >= (date $fromdate)) " : "";

  my $where = " 1 = 1 ";
  my ($name, $null);

  if ($form->{$ct_id}) {
    $where .= qq| AND (ct.id = | . conv_i($form->{$ct_id}) . qq|)|;
  } elsif ($form->{ $form->{ct} }) {
    $where .= qq| AND (ct.name ILIKE | . $dbh->quote('%' . $form->{$ct} . '%') . qq|)|;
  }

  my $dpt_join;
  if ($form->{department}) {
    ($null, $department_id) = split /--/, $form->{department};
    $dpt_join = qq| JOIN department d ON (a.department_id = d.id) |;
    $where .= qq| AND (a.department_id = | . conv_i($department_id, 'NULL') . qq|)|;
  }

  my $q_details = qq|
    -- between 0-30 days

    SELECT ${ct}.id AS ctid, ${ct}.name,
      street, zipcode, city, country, contact, email,
      phone as customerphone, fax as customerfax, ${ct}number,
      "invnumber", "transdate",
      (amount - COALESCE((SELECT sum(amount)*$ml FROM acc_trans LEFT JOIN chart ON (acc_trans.chart_id=chart.id) WHERE link ilike '%paid%' AND acc_trans.trans_id=${arap}.id AND acc_trans.transdate <= (date $todate)),0)) as "open", "amount",
      "duedate", invoice, ${arap}.id,
      (SELECT $buysell
       FROM exchangerate
       WHERE (${arap}.curr = exchangerate.curr)
         AND (exchangerate.transdate = ${arap}.transdate)) AS exchangerate
    FROM ${arap}, ${ct}
    WHERE ((paid != amount) OR (datepaid > (date $todate) AND datepaid is not null))
      AND (${arap}.storno IS FALSE)
      AND (${arap}.${ct}_id = ${ct}.id)
      AND (${ct}.id = ?)
      AND (transdate <= (date $todate) $fromwhere )

    ORDER BY ctid, transdate, invnumber |;

  my $sth_details = prepare_query($form, $dbh, $q_details);

  # select outstanding vendors or customers, depends on $ct
  my $query =
    qq|SELECT DISTINCT ct.id, ct.name
       FROM $ct ct, $arap a
       $dpt_join
       WHERE $where
         AND (a.${ct_id} = ct.id)
         AND ((a.paid != a.amount) OR ((a.datepaid > $todate) AND (datepaid is NOT NULL)))
         AND (a.transdate <= $todate $fromwhere)
       ORDER BY ct.name|;

  my $sth = prepare_execute_query($form, $dbh, $query);

  $form->{AG} = [];
  # for each company that has some stuff outstanding
  while (my ($id) = $sth->fetchrow_array) {
    do_statement($form, $sth_details, $q_details, $id);

    while (my $ref = $sth_details->fetchrow_hashref(NAME_lc)) {
      $ref->{module} = ($ref->{invoice}) ? $invoice : $arap;
      $ref->{exchangerate} = 1 unless $ref->{exchangerate};
      push @{ $form->{AG} }, $ref;
    }

    $sth_details->finish;

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

  my $ct = $form->{ct} eq "customer" ? "customer" : "vendor";

  my $query =
    qq|SELECT ct.name, ct.email, ct.cc, ct.bcc
       FROM $ct ct
       WHERE ct.id = ?|;
  ($form->{ $form->{ct} }, $form->{email}, $form->{cc}, $form->{bcc}) =
    selectrow_query($form, $dbh, $query, $form->{"${ct}_id"});
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_taxaccounts {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  # get tax accounts
  my $query =
    qq|SELECT c.accno, c.description, t.rate
       FROM chart c, tax t
       WHERE (c.link LIKE '%CT_tax%') AND (c.id = t.chart_id)
       ORDER BY c.accno|;
  $form->{taxaccounts} = selectall_hashref_quert($form, $dbh, $query);

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
    $where .= qq| AND (a.department_id = | . conv_i($department_id, 'NULL') . qq|) |;
  }

  my ($accno, $rate);

  if ($form->{accno}) {
    $accno = $form->{accno};
    $rate  = $form->{"$form->{accno}_rate"};
    $accno = qq| AND (ch.accno = | . $dbh->quote($accno) . qq|)|;
  }
  $rate *= 1;

  my ($table, $ARAP);

  if ($form->{db} eq 'ar') {
    $table = "customer";
    $ARAP  = "AR";
  } else {
    $table = "vendor";
    $ARAP  = "AP";
  }

  my $arap = lc($ARAP);

  my $transdate = "a.transdate";

  if ($form->{method} eq 'cash') {
    $transdate = "a.datepaid";

    my $todate = conv_dateq($form->{todate} ? $form->{todate} : $form->current_date($myconfig));

    $where .= qq|
      AND ac.trans_id IN
        (
          SELECT trans_id
          FROM acc_trans
          JOIN chart ON (chart_id = id)
          WHERE (link LIKE '%${ARAP}_paid%')
          AND (transdate <= $todate)
        )
      |;
  }

  # if there are any dates construct a where
  $where .= " AND ($transdate >= " . conv_dateq($form->{fromdate}) . ") " if ($form->{fromdate});
  $where .= " AND ($transdate <= " . conv_dateq($form->{todate}) . ") " if ($form->{todate});

  my $ml = ($form->{db} eq 'ar') ? 1 : -1;

  my $sortorder = join ', ', $form->sort_columns(qw(transdate invnumber name));
  $sortorder = $form->{sort} if ($form->{sort} && grep({ $_ eq $form->{sort} } qw(id transdate invnumber name netamount tax)));

  if ($form->{report} !~ /nontaxable/) {
    $query =
      qq|SELECT a.id, '0' AS invoice, $transdate AS transdate, a.invnumber, n.name, a.netamount,
          ac.amount * $ml AS tax
         FROM acc_trans ac
         JOIN ${arap} a ON (a.id = ac.trans_id)
         JOIN chart ch ON (ch.id = ac.chart_id)
         JOIN $table n ON (n.id = a.${table}_id)
         WHERE
           $where
           $accno
           AND (a.invoice = '0')

         UNION

         SELECT a.id, '1' AS invoice, $transdate AS transdate, a.invnumber, n.name, i.sellprice * i.qty AS netamount,
           i.sellprice * i.qty * $rate * $ml AS tax
         FROM acc_trans ac
         JOIN ${arap} a ON (a.id = ac.trans_id)
         JOIN chart ch ON (ch.id = ac.chart_id)
         JOIN $table n ON (n.id = a.${table}_id)
         JOIN ${table}tax t ON (t.${table}_id = n.id)
         JOIN invoice i ON (i.trans_id = a.id)
         JOIN partstax p ON (p.parts_id = i.parts_id)
         WHERE
           $where
           $accno
           AND (a.invoice = '1')
         ORDER BY $sortorder|;
  } else {
    # only gather up non-taxable transactions
    $query =
      qq|SELECT a.id, '0' AS invoice, $transdate AS transdate, a.invnumber, n.name, a.netamount
         FROM acc_trans ac
         JOIN ${arap} a ON (a.id = ac.trans_id)
         JOIN $table n ON (n.id = a.${table}_id)
         WHERE
           $where
           AND (a.invoice = '0')
           AND (a.netamount = a.amount)

         UNION

         SELECT a.id, '1' AS invoice, $transdate AS transdate, a.invnumber, n.name, i.sellprice * i.qty AS netamount
         FROM acc_trans ac
         JOIN ${arap} a ON (a.id = ac.trans_id)
         JOIN $table n ON (n.id = a.${table}_id)
         JOIN invoice i ON (i.trans_id = a.id)
         WHERE
           $where
           AND (a.invoice = '1')
           AND (
             a.${table}_id NOT IN (SELECT ${table}_id FROM ${table}tax t (${table}_id))
             OR
             i.parts_id NOT IN (SELECT parts_id FROM partstax p (parts_id))
           )
         GROUP BY a.id, a.invnumber, $transdate, n.name, i.sellprice, i.qty
         ORDER by $sortorder|;
  }

  $form->{TR} = selectall_hashref_query($form, $dbh, $query);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub paymentaccounts {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database, turn AutoCommit off
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $ARAP = $form->{db} eq "ar" ? "AR" : "AP";

  # get A(R|P)_paid accounts
  my $query =
    qq|SELECT accno, description
       FROM chart
       WHERE link LIKE '%${ARAP}_paid%'|;
  $form->{PR} = selectall_hashref_query($form, $dbh, $query);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub payments {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database, turn AutoCommit off
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $ml = 1;
  my $arap;
  if ($form->{db} eq 'ar') {
    $table = 'customer';
    $ml = -1;
    $arap = 'ar';
  } else {
    $table = 'vendor';
    $arap = 'ap';
  }

  my ($query, $sth);
  my $dpt_join;
  my $where;

  if ($form->{department_id}) {
    $dpt_join = qq| JOIN dpt_trans t ON (t.trans_id = ac.trans_id) |;
    $where = qq| AND (t.department_id = | . conv_i($form->{department_id}, 'NULL') . qq|) |;
  }

  if ($form->{fromdate}) {
    $where .= " AND (ac.transdate >= " . $dbh->quote($form->{fromdate}) . ") ";
  }
  if ($form->{todate}) {
    $where .= " AND (ac.transdate <= " . $dbh->quote($form->{todate}) . ") ";
  }
  if (!$form->{fx_transaction}) {
    $where .= " AND ac.fx_transaction = '0'";
  }

  my $invnumber;
  my $reference;
  if ($form->{reference}) {
    $reference = $dbh->quote('%' . $form->{reference} . '%');
    $invnumber = " AND (a.invnumber LIKE $reference)";
    $reference = " AND (g.reference LIKE $reference)";
  }
  if ($form->{source}) {
    $where .= " AND (ac.source ILIKE " . $dbh->quote('%' . $form->{source} . '%') . ") ";
  }
  if ($form->{memo}) {
    $where .= " AND (ac.memo ILIKE " . $dbh->quote('%' . $form->{memo} . '%') . ") ";
  }

  my %sort_columns =  (
    'transdate'    => [ qw(transdate lower_invnumber lower_name) ],
    'invnumber'    => [ qw(lower_invnumber lower_name transdate) ],
    'name'         => [ qw(lower_name transdate)                 ],
    'source'       => [ qw(lower_source)                         ],
    'memo'         => [ qw(lower_memo)                           ],
    );
  my %lowered_columns =  (
    'invnumber'       => { 'gl' => 'g.reference',   'arap' => 'a.invnumber', },
    'memo'            => { 'gl' => 'ac.memo',       'arap' => 'ac.memo',     },
    'source'          => { 'gl' => 'ac.source',     'arap' => 'ac.source',   },
    'name'            => { 'gl' => 'g.description', 'arap' => 'c.name',      },
    );

  my $sortdir   = !defined $form->{sortdir} ? 'ASC' : $form->{sortdir} ? 'ASC' : 'DESC';
  my $sortkey   = $sort_columns{$form->{sort}} ? $form->{sort} : 'transdate';
  my $sortorder = join ', ', map { "$_ $sortdir" } @{ $sort_columns{$sortkey} };


  my %columns_for_sorting = ( 'gl' => '', 'arap' => '', );
  foreach my $spec (@{ $sort_columns{$sortkey} }) {
    next if ($spec !~ m/^lower_(.*)$/);

    my $column = $1;
    map { $columns_for_sorting{$_} .= sprintf(', lower(%s) AS lower_%s', $lowered_columns{$column}->{$_}, $column) } qw(gl arap);
  }

  $query = qq|SELECT id, accno, description FROM chart WHERE accno = ?|;
  my $sth = prepare_query($form, $dbh, $query);

  my $q_details =
      qq|SELECT c.name, a.invnumber, a.ordnumber,
           ac.transdate, ac.amount * $ml AS paid, ac.source,
           a.invoice, a.id, ac.memo, '${arap}' AS module
           $columns_for_sorting{arap}
         FROM acc_trans ac
         JOIN $arap a ON (ac.trans_id = a.id)
         JOIN $table c ON (c.id = a.${table}_id)
         $dpt_join
         WHERE (ac.chart_id = ?)
           $where
           $invnumber

         UNION

         SELECT g.description, g.reference, NULL AS ordnumber,
           ac.transdate, ac.amount * $ml AS paid, ac.source,
           '0' as invoice, g.id, ac.memo, 'gl' AS module
           $columns_for_sorting{gl}
         FROM acc_trans ac
         JOIN gl g ON (g.id = ac.trans_id)
         $dpt_join
         WHERE (ac.chart_id = ?)
           $where
           $reference
           AND (ac.amount * $ml) > 0

         ORDER BY $sortorder|;
  my $sth_details = prepare_query($form, $dbh, $q_details);

  $form->{PR} = [];

  # cycle through each id
  foreach my $accno (split(/ /, $form->{paymentaccounts})) {
    do_statement($form, $sth, $query, $accno);
    my $ref = $sth->fetchrow_hashref();
    push(@{ $form->{PR} }, $ref);
    $sth->finish();

    $form->{ $ref->{id} } = [] unless ($form->{ $ref->{id} });

    do_statement($form, $sth_details, $q_details, $ref->{id}, $ref->{id});
    while (my $pr = $sth_details->fetchrow_hashref()) {
      push(@{ $form->{ $ref->{id} } }, $pr);
    }
    $sth_details->finish();
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
  my $category;
  my @categories  =
    qw(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40);

  $form->{decimalplaces} *= 1;

  &get_accounts_g($dbh, $last_period, $form->{fromdate}, $form->{todate}, $form, "pos_bwa");

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
    $kummtodate   = $form->{comparetodate};
    &get_accounts_g($dbh, $last_period, $kummfromdate, $kummtodate, $form, "pos_bwa");
  }

  @periods        = qw(jetzt kumm);
  @gesamtleistung = qw(1 2 3);
  @gesamtkosten   = qw (10 11 12 13 14 15 16 17 18 19 20);
  @ergebnisse     =
    qw (rohertrag betriebrohertrag betriebsergebnis neutraleraufwand neutralerertrag ergebnisvorsteuern ergebnis gesamtleistung gesamtkosten);

  foreach $key (@periods) {
    $form->{ "$key" . "gesamtleistung" } = 0;
    $form->{ "$key" . "gesamtkosten" }   = 0;

    foreach $category (@categories) {

      if (defined($form->{$category}{$key})) {
        $form->{"$key$category"} =
          $form->format_amount($myconfig,
                               $form->round_amount($form->{$category}{$key}, 2
                               ),
                               $form->{decimalplaces},
                               '0');
      }
    }
    foreach $item (@gesamtleistung) {
      $form->{ "$key" . "gesamtleistung" } += $form->{$item}{$key};
    }
    foreach $item (@gesamtkosten) {
      $form->{ "$key" . "gesamtkosten" } += $form->{$item}{$key};
    }
    $form->{ "$key" . "rohertrag" } =
      $form->{ "$key" . "gesamtleistung" } - $form->{4}{$key};
    $form->{ "$key" . "betriebrohertrag" } =
      $form->{ "$key" . "rohertrag" } + $form->{5}{$key};
    $form->{ "$key" . "betriebsergebnis" } =
      $form->{ "$key" . "betriebrohertrag" } -
      $form->{ "$key" . "gesamtkosten" };
    $form->{ "$key" . "neutraleraufwand" } =
      $form->{30}{$key} + $form->{31}{$key};
    $form->{ "$key" . "neutralertrag" } =
      $form->{32}{$key} + $form->{33}{$key} + $form->{34}{$key};
    $form->{ "$key" . "ergebnisvorsteuern" } =
      $form->{ "$key" . "betriebsergebnis" } -
      $form->{ "$key" . "neutraleraufwand" } +
      $form->{ "$key" . "neutralertrag" };
    $form->{ "$key" . "ergebnis" } =
      $form->{ "$key" . "ergebnisvorsteuern" } - $form->{35}{$key};

    if ($form->{ "$key" . "gesamtleistung" } > 0) {
      foreach $category (@categories) {
        if (defined($form->{$category}{$key})) {
          $form->{ "$key" . "gl" . "$category" } =
            $form->format_amount(
                               $myconfig,
                               $form->round_amount(
                                 ($form->{$category}{$key} /
                                    $form->{ "$key" . "gesamtleistung" } * 100
                                 ),
                                 $form->{decimalplaces}
                               ),
                               $form->{decimalplaces},
                               '0');
        }
      }
      foreach $item (@ergebnisse) {
        $form->{ "$key" . "gl" . "$item" } =
          $form->format_amount($myconfig,
                               $form->round_amount(
                                 ( $form->{ "$key" . "$item" } /
                                     $form->{ "$key" . "gesamtleistung" } * 100
                                 ),
                                 $form->{decimalplaces}
                               ),
                               $form->{decimalplaces},
                               '0');
      }
    }

    if ($form->{ "$key" . "gesamtkosten" } > 0) {
      foreach $category (@categories) {
        if (defined($form->{$category}{$key})) {
          $form->{ "$key" . "gk" . "$category" } =
            $form->format_amount($myconfig,
                                 $form->round_amount(
                                   ($form->{$category}{$key} /
                                      $form->{ "$key" . "gesamtkosten" } * 100
                                   ),
                                   $form->{decimalplaces}
                                 ),
                                 $form->{decimalplaces},
                                 '0');
        }
      }
      foreach $item (@ergebnisse) {
        $form->{ "$key" . "gk" . "$item" } =
          $form->format_amount($myconfig,
                               $form->round_amount(
                                   ($form->{ "$key" . "$item" } /
                                      $form->{ "$key" . "gesamtkosten" } * 100
                                   ),
                                   $form->{decimalplaces}
                               ),
                               $form->{decimalplaces},
                               '0');
      }
    }

    if ($form->{10}{$key} > 0) {
      foreach $category (@categories) {
        if (defined($form->{$category}{$key})) {
          $form->{ "$key" . "pk" . "$category" } =
            $form->format_amount(
                        $myconfig,
                        $form->round_amount(
                          ($form->{$category}{$key} / $form->{10}{$key} * 100),
                          $form->{decimalplaces}
                        ),
                        $form->{decimalplaces},
                        '0');
        }
      }
      foreach $item (@ergebnisse) {
        $form->{ "$key" . "pk" . "$item" } =
          $form->format_amount($myconfig,
                               $form->round_amount(
                                                ($form->{ "$key" . "$item" } /
                                                   $form->{10}{$key} * 100
                                                ),
                                                $form->{decimalplaces}
                               ),
                               $form->{decimalplaces},
                               '0');
      }
    }

    if ($form->{4}{$key} > 0) {
      foreach $category (@categories) {
        if (defined($form->{$category}{$key})) {
          $form->{ "$key" . "auf" . "$category" } =
            $form->format_amount(
                         $myconfig,
                         $form->round_amount(
                           ($form->{$category}{$key} / $form->{4}{$key} * 100),
                           $form->{decimalplaces}
                         ),
                         $form->{decimalplaces},
                         '0');
        }
      }
      foreach $item (@ergebnisse) {
        $form->{ "$key" . "auf" . "$item" } =
          $form->format_amount($myconfig,
                               $form->round_amount(
                                                ($form->{ "$key" . "$item" } /
                                                   $form->{4}{$key} * 100
                                                ),
                                                $form->{decimalplaces}
                               ),
                               $form->{decimalplaces},
                               '0');
      }
    }

    foreach $item (@ergebnisse) {
      $form->{ "$key" . "$item" } =
        $form->format_amount($myconfig,
                             $form->round_amount($form->{ "$key" . "$item" },
                                                 $form->{decimalplaces}
                             ),
                             $form->{decimalplaces},
                             '0');
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

  my $last_period     = 0;
  my @categories_cent = qw(51r 511 86r 861 97r 971 93r 931
    96 66 43 45 53 62 65 67);
  my @categories_euro = qw(48 51 86 91 97 93 94);
  $form->{decimalplaces} *= 1;

  foreach $item (@categories_cent) {
    $form->{"$item"} = 0;
  }
  foreach $item (@categories_euro) {
    $form->{"$item"} = 0;
  }

  &get_accounts_g($dbh, $last_period, $form->{fromdate}, $form->{todate}, $form, "pos_ustva");

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

  #
  # Berechnung der USTVA Formularfelder
  #
  $form->{"51r"} = $form->{"511"};
  $form->{"86r"} = $form->{"861"};
  $form->{"97r"} = $form->{"971"};
  $form->{"93r"} = $form->{"931"};

  #$form->{"96"}  = $form->{"94"} * 0.16;
  $form->{"43"} =
    $form->{"51r"} + $form->{"86r"} + $form->{"97r"} + $form->{"93r"} +
    $form->{"96"};
  $form->{"45"} = $form->{"43"};
  $form->{"53"} = $form->{"43"};
  $form->{"62"} = $form->{"43"} - $form->{"66"};
  $form->{"65"} = $form->{"43"} - $form->{"66"};
  $form->{"67"} = $form->{"43"} - $form->{"66"};

  foreach $item (@categories_cent) {
    $form->{$item} =
      $form->format_amount($myconfig, $form->round_amount($form->{$item}, 2),
                           2, '0');
  }

  foreach $item (@categories_euro) {
    $form->{$item} =
      $form->format_amount($myconfig, $form->round_amount($form->{$item}, 0),
                           0, '0');
  }

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub income_statement {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $last_period          = 0;
  my @categories_einnahmen = qw(1 2 3 4 5 6 7);
  my @categories_ausgaben  =
    qw(8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31);

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

  &get_accounts_g($dbh, $last_period, $form->{fromdate}, $form->{todate},
                  $form, "pos_eur");

  foreach $item (@categories_einnahmen) {
    $form->{"eur${item}"} =
      $form->format_amount($myconfig, $form->round_amount($form->{$item}, 2));
    $form->{"sumeura"} += $form->{$item};
  }
  foreach $item (@categories_ausgaben) {
    $form->{"eur${item}"} =
      $form->format_amount($myconfig, $form->round_amount($form->{$item}, 2));
    $form->{"sumeurb"} += $form->{$item};
  }

  $form->{"guvsumme"} = $form->{"sumeura"} - $form->{"sumeurb"};

  foreach $item (@ergebnisse) {
    $form->{$item} =
      $form->format_amount($myconfig, $form->round_amount($form->{$item}, 2));
  }
  $main::lxdebug->leave_sub();
}
1;
