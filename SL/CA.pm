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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1335, USA.
#======================================================================
# chart of accounts
#
# CHANGE LOG:
#   DS. 2000-07-04  Created
#
#======================================================================

use utf8;
use strict;

package CA;
use Data::Dumper;
use SL::DBUtils;
use SL::DB;

sub all_accounts {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $chart_id) = @_;

  my (%amount, $acc_cash_where);

  # connect to database
  my $dbh = SL::DB->client->dbh;

  # bug 1071 Warum sollte bei Erreichen eines neuen Jahres die Kontenübersicht nur noch die
  # bereits bebuchten Konten anzeigen?
  # Folgende Erweiterung:
  # 1.) Gehe zurück bis zu dem Datum an dem die Bücher geschlossen wurden
  # 2.) Falls die Bücher noch nie geschlossen wurden, gehe zurück bis zum Bearbeitungsstart
  # COALESCE((SELECT closedto FROM defaults),(SELECT itime FROM defaults))
  # PROBLEM: Das date_trunc schneidet auf den 1.1.20XX ab und KEINE Buchungen werden angezeigt
  # Lösung: date_trunc rausgeworfen und nicht mehr auf itime geprüft, sondern auf die erste Buchung
  # in transdate jan 11.04.2011

  my $closedto_sql = "COALESCE((SELECT closedto FROM defaults),
                               (SELECT transdate from acc_trans order by transdate limit 1))";

  if ($form->{method} eq "cash") {  # EÜR
    $acc_cash_where = qq| AND (a.trans_id IN (SELECT id FROM ar WHERE datepaid>= $closedto_sql
                          UNION SELECT id FROM ap WHERE datepaid>= $closedto_sql
                          UNION SELECT id FROM gl WHERE transdate>= $closedto_sql
                        )) |;
  } else {  # Bilanzierung
    $acc_cash_where = " AND (a.transdate >= $closedto_sql) ";
  }

  my $query =
    qq|SELECT c.accno, SUM(a.amount) AS amount | .
    qq|FROM chart c, acc_trans a | .
    qq|WHERE c.id = a.chart_id | .
    qq|$acc_cash_where| .
    qq|GROUP BY c.accno|;

  foreach my $ref (selectall_hashref_query($form, $dbh, $query)) {
    $amount{ $ref->{accno} } = $ref->{amount};
  }

  my $where = $chart_id ne '' ? "AND c.id = $chart_id" : '';

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
      array_agg(tk.startdate) AS startdates,
      array_agg(tk.taxkey_id) AS taxkeys,
      array_agg(tx.taxdescription || to_char (tx.rate, '99V99' ) || '%') AS taxdescriptions,
      array_agg(taxchart.accno) AS taxaccounts,
      array_agg(tk.pos_ustva) AS pos_ustvas,
      ( SELECT accno
      FROM chart c2
      WHERE c2.id = c.id
      ) AS new_account
    FROM chart c
    LEFT JOIN taxkeys tk ON (c.id = tk.chart_id)
    LEFT JOIN tax tx ON (tk.tax_id = tx.id)
    LEFT JOIN chart taxchart ON (taxchart.id = tx.chart_id)
    WHERE 1=1
    $where
    GROUP BY c.accno, c.id, c.description, c.charttype,
      c.category, c.link, c.pos_bwa, c.pos_bilanz, c.pos_eur, c.valid_from,
      c.datevautomatik
    ORDER BY c.accno
  };

  my $sth = prepare_execute_query($form, $dbh, $query);

  $form->{CA} = [];

  while (my $ca = $sth->fetchrow_hashref("NAME_lc")) {
    $ca->{amount} = $amount{ $ca->{accno} };
    if ($ca->{amount} < 0) {
      $ca->{debit} = $ca->{amount} * -1;
    } else {
      $ca->{credit} = $ca->{amount};
    }
    push(@{ $form->{CA} }, $ca);
  }

  $sth->finish;

  $main::lxdebug->leave_sub();
}

sub all_transactions {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh = SL::DB->client->dbh;

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

  my (@values, @where_values, @subwhere_values, $subwhere);
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
      # get beginning balances
      $query =
        qq|SELECT SUM(ac.amount) AS amount
            FROM acc_trans ac
            JOIN chart c ON (ac.chart_id = c.id)
            WHERE ((select date_trunc('year', ac.transdate::date)) = (select date_trunc('year', ?::date))) AND ac.ob_transaction
              $project
            AND c.accno = ?|;

      ($form->{beginning_balance}) = selectrow_query($form, $dbh, $query, $form->{fromdate}, $form->{accno});

      # get last transaction date
      my $todate = ($form->{todate}) ? " AND ac.transdate <= '$form->{todate}' " : "";
      $query = qq|SELECT max(ac.transdate) FROM acc_trans ac LEFT JOIN chart c ON (ac.chart_id = c.id) WHERE ((select date_trunc('year', ac.transdate::date)) >= (select date_trunc('year', ?::date))) $todate AND c.accno = ?|;
      ($form->{last_transaction}) = selectrow_query($form, $dbh, $query, $form->{fromdate}, $form->{accno});

      # get old saldo
      $query = qq|SELECT sum(ac.amount) FROM acc_trans ac LEFT JOIN chart c ON (ac.chart_id = c.id) WHERE ((select date_trunc('year', ac.transdate::date)) >= (select date_trunc('year', ?::date))) AND ac.transdate < ? AND c.accno = ?  AND (NOT ac.ob_transaction OR ac.ob_transaction IS NULL)|;
      ($form->{saldo_old}) = selectrow_query($form, $dbh, $query, $form->{fromdate}, $form->{fromdate}, $form->{accno});

      #get old balance
      $query = qq|SELECT sum(ac.amount) FROM acc_trans ac LEFT JOIN chart c ON (ac.chart_id = c.id) WHERE ((select date_trunc('year', ac.transdate::date)) >= (select date_trunc('year', ?::date))) AND ac.transdate < ? AND c.accno = ? AND ac.amount < 0 AND (NOT ac.ob_transaction OR ac.ob_transaction IS NULL)|;
      ($form->{old_balance_debit}) = selectrow_query($form, $dbh, $query, $form->{fromdate}, $form->{fromdate}, $form->{accno});

      $query = qq|SELECT sum(ac.amount) FROM acc_trans ac LEFT JOIN chart c ON (ac.chart_id = c.id) WHERE ((select date_trunc('year', ac.transdate::date)) >= (select date_trunc('year', ?::date))) AND ac.transdate < ? AND c.accno = ? AND ac.amount > 0 AND (NOT ac.ob_transaction OR ac.ob_transaction IS NULL)|;
      ($form->{old_balance_credit}) = selectrow_query($form, $dbh, $query, $form->{fromdate}, $form->{fromdate}, $form->{accno});

      # get current saldo
      $todate = ($form->{todate} ne "") ? " AND ac.transdate <= '$form->{todate}' " : "";
      $query = qq|SELECT sum(ac.amount) FROM acc_trans ac LEFT JOIN chart c ON (ac.chart_id = c.id) WHERE ((select date_trunc('year', ac.transdate::date)) >= (select date_trunc('year', ?::date))) $todate AND c.accno = ? AND (NOT ac.ob_transaction OR ac.ob_transaction IS NULL)|;
      ($form->{saldo_new}) = selectrow_query($form, $dbh, $query, $form->{fromdate}, $form->{accno});

      #get current balance
      $todate = ($form->{todate} ne "") ? " AND ac.transdate <= '$form->{todate}' " : "";
      $query = qq|SELECT sum(ac.amount) FROM acc_trans ac LEFT JOIN chart c ON (ac.chart_id = c.id) WHERE ((select date_trunc('year', ac.transdate::date)) >= (select date_trunc('year', ?::date))) $todate AND c.accno = ? AND ac.amount < 0 AND (NOT ac.ob_transaction OR ac.ob_transaction IS NULL)|;
      ($form->{current_balance_debit}) = selectrow_query($form, $dbh, $query, $form->{fromdate}, $form->{accno});

      $todate = ($form->{todate} ne "") ? " AND ac.transdate <= '$form->{todate}' " : "";
      $query = qq|SELECT sum(ac.amount) FROM acc_trans ac LEFT JOIN chart c ON (ac.chart_id = c.id)WHERE ((select date_trunc('year', ac.transdate::date)) >= (select date_trunc('year', ?::date))) $todate AND c.accno = ? AND ac.amount > 0 AND (NOT ac.ob_transaction OR ac.ob_transaction IS NULL)|;
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
      qq|SELECT ac.itime, a.id, a.reference, a.description, ac.transdate, ac.chart_id, | .
      qq|  FALSE AS invoice, ac.amount, 'gl' as module, | .
      qq§(SELECT accno||'--'||rate FROM tax LEFT JOIN chart ON (tax.chart_id=chart.id) WHERE tax.id = (SELECT tax_id FROM taxkeys WHERE taxkey_id = ac.taxkey AND taxkeys.startdate <= ac.transdate ORDER BY taxkeys.startdate DESC LIMIT 1)) AS taxinfo, ac.source || ' ' || ac.memo AS memo § .
      qq|FROM acc_trans ac, gl a | .
      $dpt_join .
      qq|WHERE | . $where . $dpt_where . $project .
      qq|  AND ac.chart_id = ? | .
      qq| AND ac.trans_id = a.id | .
      qq| AND (NOT ac.ob_transaction OR ac.ob_transaction IS NULL) | .

      qq|UNION ALL | .

      qq|SELECT ac.itime, a.id, a.invnumber, c.name, ac.transdate, ac.chart_id, | .
      qq|  a.invoice, ac.amount, 'ar' as module, | .
      qq§(SELECT accno||'--'||rate FROM tax LEFT JOIN chart ON (tax.chart_id=chart.id) WHERE tax.id = (SELECT tax_id FROM taxkeys WHERE taxkey_id = ac.taxkey AND taxkeys.startdate <= ac.transdate ORDER BY taxkeys.startdate DESC LIMIT 1)) AS taxinfo, ac.source || ' ' || ac.memo AS memo  § .
      qq|FROM acc_trans ac, customer c, ar a | .
      $dpt_join .
      qq|WHERE | . $where . $dpt_where . $project .
      qq| AND ac.chart_id = ? | .
      qq| AND ac.trans_id = a.id | .
      qq| AND a.customer_id = c.id | .
      qq| AND (NOT ac.ob_transaction OR ac.ob_transaction IS NULL)| .

      qq|UNION ALL | .

      qq|SELECT ac.itime, a.id, a.invnumber, v.name, ac.transdate, ac.chart_id, | .
      qq|  a.invoice, ac.amount, 'ap' as module, | .
      qq§(SELECT accno||'--'||rate FROM tax LEFT JOIN chart ON (tax.chart_id=chart.id) WHERE tax.id = (SELECT tax_id FROM taxkeys WHERE taxkey_id = ac.taxkey AND taxkeys.startdate <= ac.transdate ORDER BY taxkeys.startdate DESC LIMIT 1)) AS taxinfo, ac.source || ' ' || ac.memo AS memo  § .
      qq|FROM acc_trans ac, vendor v, ap a | .
      $dpt_join .
      qq|WHERE | . $where . $dpt_where . $project .
      qq| AND ac.chart_id = ? | .
      qq| AND ac.trans_id = a.id | .
      qq| AND a.vendor_id = v.id | .
      qq| AND (NOT ac.ob_transaction OR ac.ob_transaction IS NULL)|;
    push(@values,
         @where_values, @department_values, @project_values, $id,
         @where_values, @department_values, @project_values, $id,
         @where_values, @department_values, @project_values, $id);

    $union = qq|UNION ALL |;

    if ($form->{project_id}) {

      $fromdate_where =~ s/ac\./a\./;
      $todate_where   =~ s/ac\./a\./;

# strict check 20.10.2009 sschoeling
# the previous version contained the var $ar_ap_cash_where, which was ONLY set by
# RP->trial_balance() I tried to figure out which bizarre flow through the
# program would happen to set that var, so that it would be used here later on,
# (which would be nonsense, since you would normally load chart before
# calculating balance of said charts) and then decided that any mechanic that
# complex should fail anyway.

# if anyone is missing a time check on charts, that broke around the time
# trial_balance was rewritten, this would be it

      $query .=
        qq|UNION ALL | .

        qq|SELECT ac.itime, a.id, a.invnumber, c.name, a.transdate, | .
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
        qq|UNION ALL | .

        qq|SELECT ac.itime, a.id, a.invnumber, v.name, a.transdate, | .
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
        $project;
      push(@values,
           $id, @department_values, @project_values,
           $id, @department_values, @project_values);

      $fromdate_where =~ s/a\./ac\./;
      $todate_where   =~ s/a\./ac\./;

    }

    $union = qq|UNION ALL|;
  }

  my $sort = grep({ $form->{sort} eq $_ } qw(transdate reference description)) ? $form->{sort} : 'transdate';
  $sort = ($sort eq 'transdate') ? 'transdate, itime' : $sort;
  my $sort2 = ($sort eq 'reference') ? 'transdate, itime' : 'reference';
  $query .= qq|ORDER BY $sort , $sort2 |;
  my $sth = prepare_execute_query($form, $dbh, $query, @values);

  #get detail information for each transaction
  my $trans_query =
        qq|SELECT accno, | .
        qq|amount, transdate FROM acc_trans LEFT JOIN chart ON (chart_id=chart.id) WHERE | .
        qq|trans_id = ? AND sign(amount) <> sign(?) AND chart_id <> ? AND transdate = ?|;
  my $trans_sth = $dbh->prepare($trans_query);

  $form->{CA} = [];
  while (my $ca = $sth->fetchrow_hashref("NAME_lc")) {
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
    while (my $trans = $trans_sth->fetchrow_hashref("NAME_lc")) {
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
#     $ca->{index} = $ca->{$form->{sort}};
    push(@{ $form->{CA} }, $ca);

  }

  $sth->finish;

  $main::lxdebug->leave_sub();
}

1;
