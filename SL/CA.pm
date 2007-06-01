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
# chart of accounts
#
# CHANGE LOG:
#   DS. 2000-07-04  Created
#
#======================================================================

package CA;
use Data::Dumper;
use SL::DBUtils;

sub all_accounts {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $chart_id) = @_;

  my %amount;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query =
    qq|SELECT c.accno, SUM(a.amount) AS amount | .
    qq|FROM chart c, acc_trans a | .
    qq|WHERE c.id = a.chart_id | .
    qq|GROUP BY c.accno|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    $amount{ $ref->{accno} } = $ref->{amount};
  }
  $sth->finish;

  my $where = "AND c.id = $chart_id" if ($chart_id ne '');

  $query = qq{
    SELECT 
      c.accno,
      c.id,
      c.description,
      c.charttype,
      c.category,
      c.link,
      c.pos_bwa,
      c.pos_bilanz,
      c.pos_eur,
      c.valid_from,
      c.datevautomatik,
      comma(tk.startdate) AS startdate,
      comma(tk.taxkey_id) AS taxkey,
      comma(tx.taxdescription || to_char (tx.rate, '99V99' ) || '%') AS taxdescription,
      comma(tx.taxnumber) AS taxaccount,
      comma(tk.pos_ustva) AS tk_ustva,
      ( SELECT accno
      FROM chart c2
      WHERE c2.id = c.id
      ) AS new_account
    FROM chart c
    LEFT JOIN taxkeys tk ON (c.id = tk.chart_id)
    LEFT JOIN tax tx ON (tk.tax_id = tx.id)
    WHERE 1=1
    $where
    GROUP BY c.accno, c.id, c.description, c.charttype, c.gifi_accno,
      c.category, c.link, c.pos_bwa, c.pos_bilanz, c.pos_eur, c.valid_from,      
      c.datevautomatik
    ORDER BY c.accno
  };

  my $sth = prepare_execute_query($form, $dbh, $query);

  $form->{CA} = [];

  while (my $ca = $sth->fetchrow_hashref(NAME_lc)) {
    $ca->{amount} = $amount{ $ca->{accno} };
    if ($ca->{amount} < 0) {
      $ca->{debit} = $ca->{amount} * -1;
    } else {
      $ca->{credit} = $ca->{amount};
    }
    push(@{ $form->{CA} }, $ca);
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub all_transactions {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  # get chart_id
  my $query = qq|SELECT id FROM chart WHERE accno = ?|;
  my @id = selectall_array_query($form, $dbh, $query, $form->{accno});

  my $fromdate_where;
  my $todate_where;

  my $where = qq|1 = 1|;

  # build WHERE clause from dates if any
  #  if ($form->{fromdate}) {
  #    $where .= " AND ac.transdate >= '$form->{fromdate}'";
  #  }
  #  if ($form->{todate}) {
  #    $where .= " AND ac.transdate <= '$form->{todate}'";
  #  }

  my (@values, @where_values, @subwhere_values);
  if ($form->{fromdate}) {
    $where .= qq| AND ac.transdate >= ?|;
    $subwhere .= qq| AND transdate >= ?|;
    push(@where_values, conv_date($form->{fromdate}));
    push(@subwhere_values, conv_date($form->{fromdate}));
  }

  if ($form->{todate}) {
    $where .= qq| AND ac.transdate <= ?|;
    $subwhere .= qq| AND transdate <= ?|;
    push(@where_values, conv_date($form->{todate}));
    push(@subwhere_values, conv_date($form->{todate}));
  }


  my $sortorder = join ', ',
    $form->sort_columns(qw(transdate reference description));
  my $false = ($myconfig->{dbdriver} eq 'Pg') ? FALSE: q|'0'|;

  # Oracle workaround, use ordinal positions
  my %ordinal = (transdate   => 4,
                 reference   => 2,
                 description => 3);
  map { $sortorder =~ s/$_/$ordinal{$_}/ } keys %ordinal;

  my ($null, $department_id) = split(/--/, $form->{department});
  my ($dpt_where, $dpt_join, @department_values);
  if ($department_id) {
    $dpt_join = qq| JOIN department t ON (t.id = a.department_id) |;
    $dpt_where = qq| AND t.id = ? |;
    @department_values = ($department_id);
  }

  my ($project, @project_values);
  if ($form->{project_id}) {
    $project = qq| AND ac.project_id = ? |;
    @project_values = (conv_i($form->{project_id}));
  }

  if ($form->{accno}) {

    # get category for account
    $query = qq|SELECT category FROM chart WHERE accno = ?|;
    ($form->{category}) = selectrow_query($form, $dbh, $query, $form->{accno});

    if ($form->{fromdate}) {
      # get beginning balance
      $query =
        qq|SELECT SUM(ac.amount) | .
        qq|FROM acc_trans ac | .
        qq|JOIN chart c ON (ac.chart_id = c.id) | .
        $dpt_join .
        qq|WHERE c.accno = ? | .
        qq|AND ac.transdate < ? | .
        $dpt_where .
        $project;
      @values = ($form->{accno}, conv_date($form->{fromdate}),
                 @department_values, @project_values);

      if ($form->{project_id}) {
        $query .=
          qq|UNION | .

          qq|SELECT SUM(ac.qty * ac.sellprice) | .
          qq|FROM invoice ac | .
          qq|JOIN ar a ON (ac.trans_id = a.id) | .
          qq|JOIN parts p ON (ac.parts_id = p.id) | .
          qq|JOIN chart c ON (p.income_accno_id = c.id) | .
          $dpt_join .
          qq|WHERE c.accno = ? | .
          qq|  AND a.transdate < ? | .
          qq|  AND c.category = 'I' | .
          $dpt_where .
          $project .

          qq|UNION | .

          qq|SELECT SUM(ac.qty * ac.sellprice) | .
          qq|FROM invoice ac | .
          qq|JOIN ap a ON (ac.trans_id = a.id) | .
          qq|JOIN parts p ON (ac.parts_id = p.id) | .
          qq|JOIN chart c ON (p.expense_accno_id = c.id) | .
          $dpt_join .
          qq|WHERE c.accno = ? | .
          qq|  AND a.transdate < ? | .
          qq|  AND c.category = 'E' | .
          $dpt_where .
          $project;

        push(@values,
             $form->{accno}, conv_date($form->{transdate}),
             @department_values, @project_values,
             $form->{accno}, conv_date($form->{transdate}),
             @department_values, @project_values);
      }

      ($form->{balance}) = selectrow_query($form, $dbh, $query, @values);
    }
  }

  $query = "";
  my $union = "";
  @values = ();

  foreach my $id (@id) {
    
    # NOTE: Postgres is really picky about the order of implicit CROSS
    #  JOINs with ',' if you alias the tables and want to use the
    #  alias later in another JOIN.  the alias you want to use has to
    #  be the most recent in the list, otherwise Postgres will
    #  overwrite the alias internally and complain.  For this reason,
    #  in the next 3 SELECTs, the 'a' alias is last in the list.
    #  Don't change this, and if you do, substitute the ',' with CROSS
    #  JOIN ... that also works.

    # get all transactions
    $query .=
      $union .
      qq|SELECT a.id, a.reference, a.description, ac.transdate, | .
      qq|  $false AS invoice, ac.amount, 'gl' as module | .
      qq|FROM acc_trans ac, gl a | .
      $dpt_join .
      qq|WHERE | . $where . $dpt_where . $project .
      qq|  AND ac.chart_id = ? | .

      qq|UNION | .

      qq|SELECT a.id, a.invnumber, c.name, ac.transdate, | .
      qq|  a.invoice, ac.amount, 'ar' as module | .
      qq|FROM acc_trans ac, customer c, ar a | .
      $dpt_join .
      qq|WHERE | . $where . $dpt_where . $project .
      qq| AND ac.chart_id = ? | .
      qq| AND NOT a.storno | .
      qq| AND a.customer_id = c.id | .

      qq|UNION | .

      qq|SELECT a.id, a.invnumber, v.name, ac.transdate, | .
      qq|  a.invoice, ac.amount, 'ap' as module | .
      qq|FROM acc_trans ac, vendor v, ap a | .
      $dpt_join .
      qq|WHERE | . $where . $dpt_where . $project .
      qq| AND ac.chart_id = ? | .
      qq| AND NOT a.storno | .
      qq| AND a.vendor_id = v.id |;

    push(@values,
         @where_values, @department_values, @project_values, $id,
         @where_values, @department_values, @project_values, $id,
         @where_values, @department_values, @project_values, $id);

    $union = qq|UNION ALL |;

    if ($form->{project_id}) {

      $fromdate_where =~ s/ac\./a\./;
      $todate_where   =~ s/ac\./a\./;

      $query .=
        qq|UNION ALL | .

        qq|SELECT a.id, a.invnumber, c.name, a.transdate, | .
        qq|  a.invoice, ac.qty * ac.sellprice AS sellprice, 'ar' as module | .
        qq|FROM ar a | .
        qq|JOIN invoice ac ON (ac.trans_id = a.id) | .
        qq|JOIN parts p ON (ac.parts_id = p.id) | .
        qq|JOIN customer c ON (a.customer_id = c.id) | .
        $dpt_join .
        qq|WHERE p.income_accno_id = ? | .
        $fromdate_where .
        $todate_where .
        $dpt_where .
        $project .

        qq|UNION ALL | .

        qq|SELECT a.id, a.invnumber, v.name, a.transdate, | .
        qq|  a.invoice, ac.qty * ac.sellprice AS sellprice, 'ap' as module | .
        qq|FROM ap a | .
        qq|JOIN invoice ac ON (ac.trans_id = a.id) | .
        qq|JOIN parts p ON (ac.parts_id = p.id) | .
        qq|JOIN vendor v ON (a.vendor_id = v.id) | .
        $dpt_join .
        qq|WHERE p.expense_accno_id = ? | .
        $fromdate_where .
        $todate_where .
        $dpt_where .
        $project;

      push(@values,
           $id, @department_values, @project_values,
           $id, @department_values, @project_values);

      $fromdate_where =~ s/a\./ac\./;
      $todate_where   =~ s/a\./ac\./;

    }

    $union = qq|UNION ALL|;
  }

  $query .= qq|ORDER BY | . $form->{sort};
  $sth = prepare_execute_query($form, $dbh, $query, @values);

  $form->{CA} = [];
  while (my $ca = $sth->fetchrow_hashref(NAME_lc)) {
    # ap
    if ($ca->{module} eq "ap") {
      $ca->{module} = ($ca->{invoice}) ? 'ir' : 'ap';
    }

    # ar
    if ($ca->{module} eq "ar") {
      $ca->{module} = ($ca->{invoice}) ? 'is' : 'ar';
    }

    if ($ca->{amount} < 0) {
      $ca->{debit}  = $ca->{amount} * -1;
      $ca->{credit} = 0;
    } else {
      $ca->{credit} = $ca->{amount};
      $ca->{debit}  = 0;
    }

    push(@{ $form->{CA} }, $ca);

  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

1;
