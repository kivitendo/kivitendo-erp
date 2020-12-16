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
#
# General ledger backend code
#
# CHANGE LOG:
#   DS. 2000-07-04  Created
#   DS. 2001-06-12  Changed relations from accno to chart_id
#
#======================================================================

package GL;

use List::Util qw(first);

use Data::Dumper;
use SL::DATEV qw(:CONSTANTS);
use SL::DBUtils;
use SL::DB::Chart;
use SL::DB::Draft;
use SL::Util qw(trim);
use SL::DB;

use strict;

sub delete_transaction {
  my ($self, $myconfig, $form) = @_;
  $main::lxdebug->enter_sub();

  SL::DB->client->with_transaction(sub {
    do_query($form, SL::DB->client->dbh, qq|DELETE FROM gl WHERE id = ?|, conv_i($form->{id}));
    1;
  }) or do { die SL::DB->client->error };

  $main::lxdebug->leave_sub();
}

sub post_transaction {
  my ($self, $myconfig, $form) = @_;
  $main::lxdebug->enter_sub();

  my $rc = SL::DB->client->with_transaction(\&_post_transaction, $self, $myconfig, $form);

  $::lxdebug->leave_sub;
  return $rc;
}

sub _post_transaction {
  my ($self, $myconfig, $form) = @_;
  $main::lxdebug->enter_sub();

  my ($debit, $credit) = (0, 0);
  my $project_id;

  my $i;

  my $dbh = SL::DB->client->dbh;

  # post the transaction
  # make up a unique handle and store in reference field
  # then retrieve the record based on the unique handle to get the id
  # replace the reference field with the actual variable
  # add records to acc_trans

  # if there is a $form->{id} replace the old transaction
  # delete all acc_trans entries and add the new ones

  if (!$form->{taxincluded}) {
    $form->{taxincluded} = 0;
  }

  my ($query, $sth, @values, $taxkey, $rate, $posted);

  if ($form->{id}) {

    # delete individual transactions
    $query = qq|DELETE FROM acc_trans WHERE trans_id = ?|;
    @values = (conv_i($form->{id}));
    do_query($form, $dbh, $query, @values);

  } else {
    $query = qq|SELECT nextval('glid')|;
    ($form->{id}) = selectrow_query($form, $dbh, $query);

    $query =
      qq|INSERT INTO gl (id, employee_id) | .
      qq|VALUES (?, (SELECT id FROM employee WHERE login = ?))|;
    @values = ($form->{id}, $::myconfig{login});
    do_query($form, $dbh, $query, @values);
  }

  $form->{ob_transaction} *= 1;
  $form->{cb_transaction} *= 1;

  $query =
    qq|UPDATE gl SET
         reference = ?, description = ?, notes = ?,
         transdate = ?, deliverydate = ?, tax_point = ?, department_id = ?, taxincluded = ?,
         storno = ?, storno_id = ?, ob_transaction = ?, cb_transaction = ?
       WHERE id = ?|;

  @values = ($form->{reference}, $form->{description}, $form->{notes},
             conv_date($form->{transdate}), conv_date($form->{deliverydate}), conv_date($form->{tax_point}), conv_i($form->{department_id}), $form->{taxincluded} ? 't' : 'f',
             $form->{storno} ? 't' : 'f', conv_i($form->{storno_id}), $form->{ob_transaction} ? 't' : 'f', $form->{cb_transaction} ? 't' : 'f',
             conv_i($form->{id}));
  do_query($form, $dbh, $query, @values);

  # insert acc_trans transactions
  for $i (1 .. $form->{rowcount}) {
    ($form->{"tax_id_$i"}) = split(/--/, $form->{"taxchart_$i"});
    if ($form->{"tax_id_$i"} ne "") {
      $query = qq|SELECT taxkey, rate FROM tax WHERE id = ?|;
      ($taxkey, $rate) = selectrow_query($form, $dbh, $query, conv_i($form->{"tax_id_$i"}));
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
      $query =
        qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate,
                                  source, memo, project_id, taxkey, ob_transaction, cb_transaction, tax_id, chart_link)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, (SELECT link FROM chart WHERE id = ?))|;
      @values = (conv_i($form->{id}), $form->{"accno_id_$i"}, $amount, conv_date($form->{transdate}),
                 $form->{"source_$i"}, $form->{"memo_$i"}, $project_id, $taxkey, $form->{ob_transaction} ? 't' : 'f', $form->{cb_transaction} ? 't' : 'f', conv_i($form->{"tax_id_$i"}), $form->{"accno_id_$i"});
      do_query($form, $dbh, $query, @values);
    }

    if ($tax != 0) {
      # add taxentry
      $query =
        qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate,
                                  source, memo, project_id, taxkey, tax_id, chart_link)
           VALUES (?, (SELECT chart_id FROM tax WHERE id = ?),
                   ?, ?, ?, ?, ?, ?, ?, (SELECT link
                                         FROM chart
                                         WHERE id = (SELECT chart_id
                                                     FROM tax
                                                     WHERE id = ?)))|;
      @values = (conv_i($form->{id}), conv_i($form->{"tax_id_$i"}),
                 $tax, conv_date($form->{transdate}), $form->{"source_$i"},
                 $form->{"memo_$i"}, $project_id, $taxkey, conv_i($form->{"tax_id_$i"}), conv_i($form->{"tax_id_$i"}));
      do_query($form, $dbh, $query, @values);
    }
  }

  if ($form->{storno} && $form->{storno_id}) {
    do_query($form, $dbh, qq|UPDATE gl SET storno = 't' WHERE id = ?|, conv_i($form->{storno_id}));
  }

  if ($form->{draft_id}) {
    SL::DB::Manager::Draft->delete_all(where => [ id => delete($form->{draft_id}) ]);
  }

  # safety check datev export
  if ($::instance_conf->get_datev_check_on_gl_transaction) {

    # create datev object
    my $datev = SL::DATEV->new(
      dbh        => $dbh,
      trans_id   => $form->{id},
    );

    $datev->generate_datev_data;

    if ($datev->errors) {
      die join "\n", $::locale->text('DATEV check returned errors:'), $datev->errors;
    }
  }

  return 1;
}

sub all_transactions {
  my ($self, $myconfig, $form) = @_;
  $main::lxdebug->enter_sub();

  my $dbh = SL::DB->client->dbh;
  my ($query, $sth, $source, $null, $space);

  my ($glwhere, $arwhere, $apwhere) = ("1 = 1", "1 = 1", "1 = 1");
  my (@glvalues, @arvalues, @apvalues);

  if ($form->{reference}) {
    $glwhere .= qq| AND g.reference ILIKE ?|;
    $arwhere .= qq| AND a.invnumber ILIKE ?|;
    $apwhere .= qq| AND a.invnumber ILIKE ?|;
    push(@glvalues, like($form->{reference}));
    push(@arvalues, like($form->{reference}));
    push(@apvalues, like($form->{reference}));
  }

  if ($form->{department_id}) {
    $glwhere .= qq| AND g.department_id = ?|;
    $arwhere .= qq| AND a.department_id = ?|;
    $apwhere .= qq| AND a.department_id = ?|;
    push(@glvalues, $form->{department_id});
    push(@arvalues, $form->{department_id});
    push(@apvalues, $form->{department_id});
  }

  if ($form->{source}) {
    $glwhere .= " AND ac.trans_id IN (SELECT trans_id from acc_trans WHERE source ILIKE ?)";
    $arwhere .= " AND ac.trans_id IN (SELECT trans_id from acc_trans WHERE source ILIKE ?)";
    $apwhere .= " AND ac.trans_id IN (SELECT trans_id from acc_trans WHERE source ILIKE ?)";
    push(@glvalues, like($form->{source}));
    push(@arvalues, like($form->{source}));
    push(@apvalues, like($form->{source}));
  }

  # default Datumseinschränkung falls nicht oder falsch übergeben (sollte nie passieren)
  $form->{datesort} = 'transdate' unless $form->{datesort} =~ /^(transdate|gldate)$/;

  if (trim($form->{datefrom})) {
    $glwhere .= " AND ac.$form->{datesort} >= ?";
    $arwhere .= " AND ac.$form->{datesort} >= ?";
    $apwhere .= " AND ac.$form->{datesort} >= ?";
    push(@glvalues, trim($form->{datefrom}));
    push(@arvalues, trim($form->{datefrom}));
    push(@apvalues, trim($form->{datefrom}));
  }

  if (trim($form->{dateto})) {
    $glwhere .= " AND ac.$form->{datesort} <= ?";
    $arwhere .= " AND ac.$form->{datesort} <= ?";
    $apwhere .= " AND ac.$form->{datesort} <= ?";
    push(@glvalues, trim($form->{dateto}));
    push(@arvalues, trim($form->{dateto}));
    push(@apvalues, trim($form->{dateto}));
  }

  if (trim($form->{description})) {
    $glwhere .= " AND g.description ILIKE ?";
    $arwhere .= " AND ct.name ILIKE ?";
    $apwhere .= " AND ct.name ILIKE ?";
    push(@glvalues, like($form->{description}));
    push(@arvalues, like($form->{description}));
    push(@apvalues, like($form->{description}));
  }

  if ($form->{employee_id}) {
    $glwhere .= " AND g.employee_id = ? ";
    $arwhere .= " AND a.employee_id = ? ";
    $apwhere .= " AND a.employee_id = ? ";
    push(@glvalues, conv_i($form->{employee_id}));
    push(@arvalues, conv_i($form->{employee_id}));
    push(@apvalues, conv_i($form->{employee_id}));
  }

  if (trim($form->{notes})) {
    $glwhere .= " AND g.notes ILIKE ?";
    $arwhere .= " AND a.notes ILIKE ?";
    $apwhere .= " AND a.notes ILIKE ?";
    push(@glvalues, like($form->{notes}));
    push(@arvalues, like($form->{notes}));
    push(@apvalues, like($form->{notes}));
  }

  if ($form->{accno}) {
    $glwhere .= " AND c.accno = '$form->{accno}'";
    $arwhere .= " AND c.accno = '$form->{accno}'";
    $apwhere .= " AND c.accno = '$form->{accno}'";
  }

  if ($form->{category} ne 'X') {
    $glwhere .= qq| AND g.id in (SELECT trans_id FROM acc_trans ac2 WHERE ac2.chart_id IN (SELECT id FROM chart c2 WHERE c2.category = ?))|;
    $arwhere .= qq| AND a.id in (SELECT trans_id FROM acc_trans ac2 WHERE ac2.chart_id IN (SELECT id FROM chart c2 WHERE c2.category = ?))|;
    $apwhere .= qq| AND a.id in (SELECT trans_id FROM acc_trans ac2 WHERE ac2.chart_id IN (SELECT id FROM chart c2 WHERE c2.category = ?))|;
    push(@glvalues, $form->{category});
    push(@arvalues, $form->{category});
    push(@apvalues, $form->{category});
  }

  if ($form->{project_id}) {
    $glwhere .= qq| AND g.id IN (SELECT DISTINCT trans_id FROM acc_trans WHERE project_id = ?)|;
    $arwhere .=
      qq| AND ((a.globalproject_id = ?) OR
               (a.id IN (SELECT DISTINCT trans_id FROM acc_trans WHERE project_id = ?)))|;
    $apwhere .=
      qq| AND ((a.globalproject_id = ?) OR
               (a.id IN (SELECT DISTINCT trans_id FROM acc_trans WHERE project_id = ?)))|;
    my $project_id = conv_i($form->{project_id});
    push(@glvalues, $project_id);
    push(@arvalues, $project_id, $project_id);
    push(@apvalues, $project_id, $project_id);
  }

  my ($project_columns,            $project_join);
  my ($arap_globalproject_columns, $arap_globalproject_join);
  my ($gl_globalproject_columns);
  if ($form->{"l_projectnumbers"}) {
    $project_columns            = qq|, ac.project_id, pr.projectnumber|;
    $project_join               = qq|LEFT JOIN project pr ON (ac.project_id = pr.id)|;
    $arap_globalproject_columns = qq|, a.globalproject_id, globalpr.projectnumber AS globalprojectnumber|;
    $arap_globalproject_join    = qq|LEFT JOIN project globalpr ON (a.globalproject_id = globalpr.id)|;
    $gl_globalproject_columns   = qq|, NULL AS globalproject_id, '' AS globalprojectnumber|;
  }

  if ($form->{accno}) {
    # get category for account
    $query = qq|SELECT category FROM chart WHERE accno = ?|;
    ($form->{ml}) = selectrow_query($form, $dbh, $query, $form->{accno});

    if ($form->{datefrom}) {
      $query =
        qq|SELECT SUM(ac.amount)
           FROM acc_trans ac
           LEFT JOIN chart c ON (ac.chart_id = c.id)
           WHERE (c.accno = ?) AND (ac.$form->{datesort} < ?)|;
      ($form->{balance}) = selectrow_query($form, $dbh, $query, $form->{accno}, conv_date($form->{datefrom}));
    }
  }

  my %sort_columns =  (
    'id'           => [ qw(id)                   ],
    'transdate'    => [ qw(transdate id)         ],
    'gldate'       => [ qw(gldate id)         ],
    'reference'    => [ qw(lower_reference id)   ],
    'description'  => [ qw(lower_description id) ],
    'accno'        => [ qw(accno transdate id)   ],
    'department'   => [ qw(department transdate id)   ],
    );
  my %lowered_columns =  (
    'reference'       => { 'gl' => 'g.reference',   'arap' => 'a.invnumber', },
    'source'          => { 'gl' => 'ac.source',     'arap' => 'ac.source',   },
    'description'     => { 'gl' => 'g.description', 'arap' => 'ct.name',     },
    );

  # sortdir = sort direction (ascending or descending)
  my $sortdir   = !defined $form->{sortdir} ? 'ASC' : $form->{sortdir} ? 'ASC' : 'DESC';
  my $sortkey   = $sort_columns{$form->{sort}} ? $form->{sort} : $form->{datesort};  # default used to be transdate
  my $sortorder = join ', ', map { "$_ $sortdir" } @{ $sort_columns{$sortkey} };

  my %columns_for_sorting = ( 'gl' => '', 'arap' => '', );
  foreach my $spec (@{ $sort_columns{$sortkey} }) {
    next if ($spec !~ m/^lower_(.*)$/);

    my $column = $1;
    map { $columns_for_sorting{$_} .= sprintf(', lower(%s) AS lower_%s', $lowered_columns{$column}->{$_}, $column) } qw(gl arap);
  }

  $query =
    qq|SELECT
        ac.acc_trans_id, g.id, 'gl' AS type, FALSE AS invoice, g.reference, ac.taxkey, c.link,
        g.description, ac.transdate, ac.gldate, ac.source, ac.trans_id,
        ac.amount, c.accno, g.notes, t.chart_id,
        d.description AS department,
        CASE WHEN (COALESCE(e.name, '') = '') THEN e.login ELSE e.name END AS employee
        $project_columns $gl_globalproject_columns
        $columns_for_sorting{gl}
      FROM gl g
      LEFT JOIN employee e ON (g.employee_id = e.id)
      LEFT JOIN department d ON (g.department_id = d.id),
      acc_trans ac $project_join, chart c
      LEFT JOIN tax t ON (t.chart_id = c.id)
      WHERE $glwhere
        AND (ac.chart_id = c.id)
        AND (g.id = ac.trans_id)

      UNION

      SELECT ac.acc_trans_id, a.id, 'ar' AS type, a.invoice, a.invnumber, ac.taxkey, c.link,
        ct.name, ac.transdate, ac.gldate, ac.source, ac.trans_id,
        ac.amount, c.accno, a.notes, t.chart_id,
        d.description AS department,
        CASE WHEN (COALESCE(e.name, '') = '') THEN e.login ELSE e.name END AS employee
        $project_columns $arap_globalproject_columns
        $columns_for_sorting{arap}
      FROM ar a
      LEFT JOIN employee e ON (a.employee_id = e.id)
      LEFT JOIN department d ON (a.department_id = d.id)
      $arap_globalproject_join,
      acc_trans ac $project_join, customer ct, chart c
      LEFT JOIN tax t ON (t.chart_id=c.id)
      WHERE $arwhere
        AND (ac.chart_id = c.id)
        AND (a.customer_id = ct.id)
        AND (a.id = ac.trans_id)

      UNION

      SELECT ac.acc_trans_id, a.id, 'ap' AS type, a.invoice, a.invnumber, ac.taxkey, c.link,
        ct.name, ac.transdate, ac.gldate, ac.source, ac.trans_id,
        ac.amount, c.accno, a.notes, t.chart_id,
        d.description AS department,
        CASE WHEN (COALESCE(e.name, '') = '') THEN e.login ELSE e.name END AS employee
        $project_columns $arap_globalproject_columns
        $columns_for_sorting{arap}
      FROM ap a
      LEFT JOIN employee e ON (a.employee_id = e.id)
      LEFT JOIN department d ON (a.department_id = d.id)
      $arap_globalproject_join,
      acc_trans ac $project_join, vendor ct, chart c
      LEFT JOIN tax t ON (t.chart_id=c.id)
      WHERE $apwhere
        AND (ac.chart_id = c.id)
        AND (a.vendor_id = ct.id)
        AND (a.id = ac.trans_id)

      ORDER BY $sortorder, acc_trans_id $sortdir|;
#      ORDER BY gldate DESC, id DESC, acc_trans_id DESC

  my @values = (@glvalues, @arvalues, @apvalues);

  # Show all $query in Debuglevel LXDebug::QUERY
  my $callingdetails = (caller (0))[3];
  dump_query(LXDebug->QUERY(), "$callingdetails", $query, @values);

  $sth = prepare_execute_query($form, $dbh, $query, @values);
  my $trans_id  = "";
  my $trans_id2 = "";
  my $balance;

  my ($i, $j, $k, $l, $ref, $ref2);

  $form->{GL} = [];
  while (my $ref0 = $sth->fetchrow_hashref("NAME_lc")) {

    $trans_id = $ref0->{id};

    my $source = $ref0->{source};
    undef($ref0->{source});

    if ($trans_id != $trans_id2) { # first line of a booking

      if ($trans_id2) {
        push(@{ $form->{GL} }, $ref);
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
      $ref->{"projectnumbers"}->{$ref->{"projectnumber"}}       = 1 if ($ref->{"projectnumber"});
      $ref->{"projectnumbers"}->{$ref->{"globalprojectnumber"}} = 1 if ($ref->{"globalprojectnumber"});

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
          $ref->{source}{$k}       = $source;
        } else {
          $ref->{credit}{$l}        = $ref->{amount} * 1;
          $ref->{credit_accno}{$l}  = $ref->{accno};
          $ref->{credit_taxkey}{$l} = $ref->{taxkey};
          $ref->{ac_transdate}{$l}  = $ref->{transdate};
          $ref->{source}{$l}        = $source;
        }
      }

    } else { # following lines of a booking, line increasing

      $ref2      = $ref0;
#      $trans_old = $trans_id2;   # doesn't seem to be used anymore
      $trans_id2 = $ref2->{id};

      $balance =
        (int($balance * 100000) + int(100000 * $ref2->{amount})) / 100000;

      $ref->{"projectnumbers"}->{$ref2->{"projectnumber"}}       = 1 if ($ref2->{"projectnumber"});
      $ref->{"projectnumbers"}->{$ref2->{"globalprojectnumber"}} = 1 if ($ref2->{"globalprojectnumber"});

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
          if ($ref->{source}{$k} ne "") {
            $space = " | ";
          } else {
            $space = "";
          }
          $ref->{debit}{$k}        = $ref2->{amount} * - 1;
          $ref->{debit_accno}{$k}  = $ref2->{accno};
          $ref->{debit_taxkey}{$k} = $ref2->{taxkey};
          $ref->{ac_transdate}{$k} = $ref2->{transdate};
          $ref->{source}{$k}       = $source . $space . $ref->{source}{$k};
        } else {
          if ($ref->{credit_accno}{$l} ne "") {
            $l++;
          }
          if ($ref->{source}{$l} ne "") {
            $space = " | ";
          } else {
            $space = "";
          }
          $ref->{credit}{$l}        = $ref2->{amount};
          $ref->{credit_accno}{$l}  = $ref2->{accno};
          $ref->{credit_taxkey}{$l} = $ref2->{taxkey};
          $ref->{ac_transdate}{$l}  = $ref2->{transdate};
          $ref->{source}{$l}        = $ref->{source}{$l} . $space . $source;
        }
      }
    }
  }

  push @{ $form->{GL} }, $ref;
  $sth->finish;

  if ($form->{accno}) {
    $query = qq|SELECT c.description FROM chart c WHERE c.accno = ?|;
    ($form->{account_description}) = selectrow_query($form, $dbh, $query, $form->{accno});
  }

  $main::lxdebug->leave_sub();
}

sub transaction {
  my ($self, $myconfig, $form) = @_;
  $main::lxdebug->enter_sub();

  my ($query, $sth, $ref, @values);

  my $dbh = SL::DB->client->dbh;

  $query = qq|SELECT closedto, revtrans FROM defaults|;
  ($form->{closedto}, $form->{revtrans}) = selectrow_query($form, $dbh, $query);

  $query = qq|SELECT id, gldate
              FROM gl
              WHERE id = (SELECT max(id) FROM gl)|;
  ($form->{previous_id}, $form->{previous_gldate}) = selectrow_query($form, $dbh, $query);

  if ($form->{id}) {
    $query =
      qq|SELECT g.reference, g.description, g.notes, g.transdate, g.deliverydate, g.tax_point,
           g.storno, g.storno_id,
           g.department_id, d.description AS department,
           e.name AS employee, g.taxincluded, g.gldate,
         g.ob_transaction, g.cb_transaction
         FROM gl g
         LEFT JOIN department d ON (d.id = g.department_id)
         LEFT JOIN employee e ON (e.id = g.employee_id)
         WHERE g.id = ?|;
    $ref = selectfirst_hashref_query($form, $dbh, $query, conv_i($form->{id}));
    map { $form->{$_} = $ref->{$_} } keys %$ref;

    # retrieve individual rows
    $query =
      qq|SELECT c.accno, t.taxkey AS accnotaxkey, a.amount, a.memo, a.source,
           a.transdate, a.cleared, a.project_id, p.projectnumber,
           a.taxkey, t.rate AS taxrate, t.id, a.chart_id,
           (SELECT c1.accno
            FROM chart c1, tax t1
            WHERE (t1.id = t.id) AND (c1.id = t.chart_id)) AS taxaccno,
           (SELECT tk.tax_id
            FROM taxkeys tk
            WHERE (tk.chart_id = a.chart_id) AND (tk.startdate <= a.transdate)
            ORDER BY tk.startdate desc LIMIT 1) AS tax_id
         FROM acc_trans a
         JOIN chart c ON (c.id = a.chart_id)
         LEFT JOIN project p ON (p.id = a.project_id)
         LEFT JOIN tax t ON (t.id = a.tax_id)
         WHERE (a.trans_id = ?)
           AND (a.fx_transaction = '0')
         ORDER BY a.acc_trans_id, a.transdate|;
    $form->{GL} = selectall_hashref_query($form, $dbh, $query, conv_i($form->{id}));

  } else {
    $query =
      qq|SELECT COALESCE(
           (SELECT transdate
            FROM gl
            WHERE id = (SELECT MAX(id) FROM gl)
            LIMIT 1),
           current_date)|;
    ($form->{transdate}) = selectrow_query($form, $dbh, $query);
  }

  # get tax description
  $query = qq|SELECT * FROM tax ORDER BY taxkey|;
  $form->{TAX} = selectall_hashref_query($form, $dbh, $query);

  # get chart of accounts
  $query =
    qq|SELECT c.accno, c.description, c.link, tk.taxkey_id, tk.tax_id
       FROM chart c
       LEFT JOIN taxkeys tk ON (tk.id =
         (SELECT id
          FROM taxkeys
          WHERE (taxkeys.chart_id = c.id)
            AND (startdate <= ?)
          ORDER BY startdate DESC
          LIMIT 1))
       ORDER BY c.accno|;
  $form->{chart} = selectall_hashref_query($form, $dbh, $query, conv_date($form->{transdate}));

  $main::lxdebug->leave_sub();
}

sub storno {
  my ($self, $form, $myconfig, $id) = @_;
  $main::lxdebug->enter_sub();

  my $rc = SL::DB->client->with_transaction(\&_storno, $self, $form, $myconfig, $id);

  $::lxdebug->leave_sub;
  return $rc;
}

sub _storno {
  my ($self, $form, $myconfig, $id) = @_;

  my ($query, $new_id, $storno_row, $acc_trans_rows);
  my $dbh = SL::DB->client->dbh;

  $query = qq|SELECT nextval('glid')|;
  ($new_id) = selectrow_query($form, $dbh, $query);

  $query = qq|SELECT * FROM gl WHERE id = ?|;
  $storno_row = selectfirst_hashref_query($form, $dbh, $query, $id);

  $storno_row->{id}          = $new_id;
  $storno_row->{storno_id}   = $id;
  $storno_row->{storno}      = 't';
  $storno_row->{reference}   = 'Storno-' . $storno_row->{reference};

  $query = qq|SELECT id FROM employee WHERE login = ?|;
  my ($employee_id) = selectrow_query($form, $dbh, $query, $::myconfig{login});
  $storno_row->{employee_id} = $employee_id;

  delete @$storno_row{qw(itime mtime gldate)};

  $query = sprintf 'INSERT INTO gl (%s) VALUES (%s)', join(', ', keys %$storno_row), join(', ', map '?', values %$storno_row);
  do_query($form, $dbh, $query, (values %$storno_row));

  $query = qq|UPDATE gl SET storno = 't' WHERE id = ?|;
  do_query($form, $dbh, $query, $id);

  # now copy acc_trans entries
  $query = qq|SELECT * FROM acc_trans WHERE trans_id = ?|;
  my $rowref = selectall_hashref_query($form, $dbh, $query, $id);

  for my $row (@$rowref) {
    delete @$row{qw(itime mtime acc_trans_id gldate)};
    $query = sprintf 'INSERT INTO acc_trans (%s) VALUES (%s)', join(', ', keys %$row), join(', ', map '?', values %$row);
    $row->{trans_id}   = $new_id;
    $row->{amount}    *= -1;
    do_query($form, $dbh, $query, (values %$row));
  }

  return 1;
}

sub get_chart_balances {
  my ($self, @chart_ids) = @_;

  return () unless @chart_ids;

  my $placeholders = join ', ', ('?') x scalar(@chart_ids);
  my $query = qq|SELECT chart_id, SUM(amount) AS sum
                 FROM acc_trans
                 WHERE chart_id IN (${placeholders})
                 GROUP BY chart_id|;

  my %balances = selectall_as_map($::form, $::form->get_standard_dbh(\%::myconfig), $query, 'chart_id', 'sum', @chart_ids);

  return %balances;
}

sub get_active_taxes_for_chart {
  my ($self, $chart_id, $transdate, $tax_id) = @_;

  my $chart         = SL::DB::Chart->new(id => $chart_id)->load;
  my $active_taxkey = $chart->get_active_taxkey($transdate);

  my $where = [ chart_categories => { like => '%' . $chart->category . '%' } ];

  if ( defined $tax_id && $tax_id >= 0 ) {
    $where = [ or => [ chart_categories => { like => '%' . $chart->category . '%' },
                       id               => $tax_id
                     ]
             ];
  }

  my $taxes         = SL::DB::Manager::Tax->get_all(
    where   => $where,
    sort_by => 'taxkey, rate',
  );

  my $default_tax            = first { $active_taxkey->tax_id == $_->id } @{ $taxes };
  $default_tax->{is_default} = 1 if $default_tax;

  return @{ $taxes };
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::GL - some useful GL functions

=head1 FUNCTIONS

=over 4

=item C<get_active_taxes_for_chart> $transdate $tax_id

Returns a list of valid taxes for a certain chart.

If the optional param transdate exists one entry in the returning list
may get the attribute C<is_default> for this specific tax-dependent date.
The possible entries are filtered by the charttype of the tax, i.e. only taxes
whose chart_categories match the category of the chart will be shown.

In the case of existing records, e.g. when opening an old ar record, due to
changes in the configurations the desired tax might not be available in the
dropdown anymore. If we are loading an old record and know its tax_id (from
acc_trans), we can pass $tax_id as the third parameter and be sure that the
original tax always appears in the dropdown.

The functions returns an array which may be used for building dropdowns in ar/ap/gl code.

=back

=head1 TODO

Nothing here yet.

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

G. Richardson E<lt>grichardson@kivitec.deE<gt>

=cut
