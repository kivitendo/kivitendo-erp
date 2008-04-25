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
  my $acc_cash_where = "";
  my $ar_cash_where = "";
  my $ap_cash_where = "";


  if ($form->{method} eq "cash") {
    $acc_cash_where = qq| AND (ac.trans_id IN (SELECT id FROM ar WHERE datepaid>='$form->{fromdate}' AND datepaid<='$form->{todate}' UNION SELECT id FROM ap WHERE datepaid>='$form->{fromdate}' AND datepaid<='$form->{todate}' UNION SELECT id FROM gl WHERE transdate>='$form->{fromdate}' AND transdate<='$form->{todate}')) |;
    $ar_ap_cash_where = qq| AND (a.datepaid>='$form->{fromdate}' AND a.datepaid<='$form->{todate}') |;
  }

  if ($form->{accno}) {

    # get category for account
    $query = qq|SELECT category FROM chart WHERE accno = ?|;
    ($form->{category}) = selectrow_query($form, $dbh, $query, $form->{accno});

    if ($form->{fromdate}) {
      # get beginning balances
      $query =
        qq|SELECT SUM(ac.amount) AS amount
            FROM acc_trans ac
            JOIN chart c ON (ac.chart_id = c.id)
            $dpt_join
            WHERE ((select date_trunc('year', ac.transdate::date)) = (select date_trunc('year', ?::date))) AND ac.ob_transaction 
              $dpt_where
              $project
            AND c.accno = ? $acc_cash_where|;
    
      ($form->{beginning_balance}) = selectrow_query($form, $dbh, $query, $form->{fromdate}, $form->{accno});

      # get last transaction date
      my $todate = ($form->{todate}) ? " AND ac.transdate <= '$form->{todate}' " : "";
      $query = qq|SELECT max(ac.transdate) FROM acc_trans ac LEFT JOIN chart c ON (ac.chart_id = c.id)WHERE ((select date_trunc('year', ac.transdate::date)) = (select date_trunc('year', ?::date))) $todate AND c.accno = ?  $acc_cash_where|;
      ($form->{last_transaction}) = selectrow_query($form, $dbh, $query, $form->{fromdate}, $form->{accno});

      # get old saldo
      $query = qq|SELECT sum(ac.amount) FROM acc_trans ac LEFT JOIN chart c ON (ac.chart_id = c.id)WHERE ((select date_trunc('year', ac.transdate::date)) = (select date_trunc('year', ?::date))) AND ac.transdate < ? AND c.accno = ?  $acc_cash_where|;
      ($form->{saldo_old}) = selectrow_query($form, $dbh, $query, $form->{fromdate}, $form->{fromdate}, $form->{accno});

      #get old balance
      $query = qq|SELECT sum(ac.amount) FROM acc_trans ac LEFT JOIN chart c ON (ac.chart_id = c.id)WHERE ((select date_trunc('year', ac.transdate::date)) = (select date_trunc('year', ?::date))) AND ac.transdate < ? AND c.accno = ? AND ac.amount < 0 AND (NOT ac.ob_transaction OR ac.ob_transaction IS NULL)  $acc_cash_where|;
      ($form->{old_balance_debit}) = selectrow_query($form, $dbh, $query, $form->{fromdate}, $form->{fromdate}, $form->{accno});

      $query = qq|SELECT sum(ac.amount) FROM acc_trans ac LEFT JOIN chart c ON (ac.chart_id = c.id)WHERE ((select date_trunc('year', ac.transdate::date)) = (select date_trunc('year', ?::date))) AND ac.transdate < ? AND c.accno = ? AND ac.amount > 0 AND (NOT ac.ob_transaction OR ac.ob_transaction IS NULL)  $acc_cash_where|;
      ($form->{old_balance_credit}) = selectrow_query($form, $dbh, $query, $form->{fromdate}, $form->{fromdate}, $form->{accno});

      # get current saldo
      my $todate = ($form->{todate} ne "") ? " AND ac.transdate <= '$form->{todate}' " : "";
      $query = qq|SELECT sum(ac.amount) FROM acc_trans ac LEFT JOIN chart c ON (ac.chart_id = c.id)WHERE ((select date_trunc('year', ac.transdate::date)) = (select date_trunc('year', ?::date))) $todate AND c.accno = ?  $acc_cash_where|;
      ($form->{saldo_new}) = selectrow_query($form, $dbh, $query, $form->{fromdate}, $form->{accno});

      #get current balance
      my $todate = ($form->{todate} ne "") ? " AND ac.transdate <= '$form->{todate}' " : "";
      $query = qq|SELECT sum(ac.amount) FROM acc_trans ac LEFT JOIN chart c ON (ac.chart_id = c.id)WHERE ((select date_trunc('year', ac.transdate::date)) = (select date_trunc('year', ?::date))) $todate AND c.accno = ? AND ac.amount < 0 AND (NOT ac.ob_transaction OR ac.ob_transaction IS NULL)  $acc_cash_where|;
      ($form->{current_balance_debit}) = selectrow_query($form, $dbh, $query, $form->{fromdate}, $form->{accno});

      my $todate = ($form->{todate} ne "") ? " AND ac.transdate <= '$form->{todate}' " : "";
      $query = qq|SELECT sum(ac.amount) FROM acc_trans ac LEFT JOIN chart c ON (ac.chart_id = c.id)WHERE ((select date_trunc('year', ac.transdate::date)) = (select date_trunc('year', ?::date))) $todate AND c.accno = ? AND ac.amount > 0 AND (NOT ac.ob_transaction OR ac.ob_transaction IS NULL)  $acc_cash_where|;
      ($form->{current_balance_credit}) = selectrow_query($form, $dbh, $query, $form->{fromdate}, $form->{accno});
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
    $query =
      qq|SELECT a.id, a.reference, a.description, ac.transdate, ac.chart_id, | .
      qq|  $false AS invoice, ac.amount, 'gl' as module, | .
      qq§(SELECT accno||'--'||rate FROM tax LEFT JOIN chart ON (tax.chart_id=chart.id) WHERE tax.id = (SELECT tax_id FROM taxkeys WHERE taxkey_id = ac.taxkey AND taxkeys.startdate <= ac.transdate ORDER BY taxkeys.startdate DESC LIMIT 1)) AS taxinfo § .
      qq|FROM acc_trans ac, gl a | .
      $dpt_join .
      qq|WHERE | . $where . $dpt_where . $project .
      qq|  AND ac.chart_id = ? | .
      qq| AND ac.trans_id = a.id | .
      qq| AND (NOT ac.ob_transaction OR ac.ob_transaction IS NULL) | .

      qq|UNION ALL | .

      qq|SELECT a.id, a.invnumber, c.name, ac.transdate, ac.chart_id, | .
      qq|  a.invoice, ac.amount, 'ar' as module, | .
      qq§(SELECT accno||'--'||rate FROM tax LEFT JOIN chart ON (tax.chart_id=chart.id) WHERE tax.id = (SELECT tax_id FROM taxkeys WHERE taxkey_id = ac.taxkey AND taxkeys.startdate <= ac.transdate ORDER BY taxkeys.startdate DESC LIMIT 1)) AS taxinfo § . 
      qq|FROM acc_trans ac, customer c, ar a | .
      $dpt_join .
      qq|WHERE | . $where . $dpt_where . $project .
      qq| AND ac.chart_id = ? | .
      qq| AND ac.trans_id = a.id | .
      qq| AND a.customer_id = c.id | .
      qq| AND (NOT ac.ob_transaction OR ac.ob_transaction IS NULL) $ar_ap_cash_where| .

      qq|UNION ALL | .

      qq|SELECT a.id, a.invnumber, v.name, ac.transdate, ac.chart_id, | .
      qq|  a.invoice, ac.amount, 'ap' as module, | .
      qq§(SELECT accno||'--'||rate FROM tax LEFT JOIN chart ON (tax.chart_id=chart.id) WHERE tax.id = (SELECT tax_id FROM taxkeys WHERE taxkey_id = ac.taxkey AND taxkeys.startdate <= ac.transdate ORDER BY taxkeys.startdate DESC LIMIT 1)) AS taxinfo § .
      qq|FROM acc_trans ac, vendor v, ap a | .
      $dpt_join .
      qq|WHERE | . $where . $dpt_where . $project .
      qq| AND ac.chart_id = ? | .
      qq| AND ac.trans_id = a.id | .
      qq| AND a.vendor_id = v.id |;
      qq| AND (NOT ac.ob_transaction OR ac.ob_transaction IS NULL) $ar_ap_cash_where| .

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
        qq|  a.invoice, ac.qty * ac.sellprice AS sellprice, 'ar' as module, | .
        qq§(SELECT accno||'--'||rate FROM tax LEFT JOIN chart ON (tax.chart_id=chart.id) WHERE tax.id = (SELECT tax_id FROM taxkeys WHERE taxkey_id = ac.taxkey AND taxkeys.startdate <= ac.transdate ORDER BY taxkeys.startdate DESC LIMIT 1)) AS taxinfo § .
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
        $ar_ap_cash_where .
        qq|UNION ALL | .

        qq|SELECT a.id, a.invnumber, v.name, a.transdate, | .
        qq|  a.invoice, ac.qty * ac.sellprice AS sellprice, 'ap' as module, | .
        qq§(SELECT accno||'--'||rate FROM tax LEFT JOIN chart ON (tax.chart_id=chart.id) WHERE tax.id = (SELECT tax_id FROM taxkeys WHERE taxkey_id = ac.taxkey AND taxkeys.startdate <= ac.transdate ORDER BY taxkeys.startdate DESC LIMIT 1)) AS taxinfo § .
        qq|FROM ap a | .
        qq|JOIN invoice ac ON (ac.trans_id = a.id) | .
        qq|JOIN parts p ON (ac.parts_id = p.id) | .
        qq|JOIN vendor v ON (a.vendor_id = v.id) | .
        $dpt_join .
        qq|WHERE p.expense_accno_id = ? | .
        $fromdate_where .
        $todate_where .
        $dpt_where .
        $project .
        $ar_ap_cash_where;
      push(@values,
           $id, @department_values, @project_values,
           $id, @department_values, @project_values);

      $fromdate_where =~ s/a\./ac\./;
      $todate_where   =~ s/a\./ac\./;

    }

    $union = qq|UNION ALL|;
  }

  my $sort = grep({ $form->{sort} eq $_ } qw(transdate reference description)) ? $form->{sort} : 'transdate';

  $query .= qq|ORDER BY $sort|;
  $sth = prepare_execute_query($form, $dbh, $query, @values);

  #get detail information for each transaction
  $trans_query =
        qq|SELECT accno, | .
        qq|amount, transdate FROM acc_trans LEFT JOIN chart ON (chart_id=chart.id) WHERE | .
        qq|trans_id = ? AND sign(amount) <> sign(?) AND chart_id <> ? AND transdate = ?|;
  my $trans_sth = $dbh->prepare($trans_query);

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

    ($ca->{ustkonto},$ca->{ustrate}) = split /--/, $ca->{taxinfo};

    #get detail information for this transaction
    $trans_sth->execute($ca->{id}, $ca->{amount}, $ca->{chart_id}, $ca->{transdate}) ||
    $form->dberror($trans_query . " (" . join(", ", $ca->{id}) . ")");
    while (my $trans = $trans_sth->fetchrow_hashref(NAME_lc)) {
      if (($ca->{transdate} eq $trans->{transdate}) && ($ca->{amount} * $trans->{amount} < 0)) {
        if ($trans->{amount} < 0) {
          $trans->{debit}  = $trans->{amount} * -1;
          $trans->{credit} = 0;
        } else {
          $trans->{credit} = $trans->{amount};
          $trans->{debit}  = 0;
        } 
        push(@{ $ca->{GEGENKONTO} }, $trans);
      } else {
        next;
      }
    }

    $ca->{index} = join "--", map { $ca->{$_} } qw(id reference description transdate);

    push(@{ $form->{CA} }, $ca);

  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

1;
