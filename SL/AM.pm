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
# Administration module
#    Chart of Accounts
#    template routines
#    preferences
#
#======================================================================

package AM;

use Data::Dumper;
use SL::DBUtils;

sub get_account {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  my $query = qq{
    SELECT c.accno, c.description, c.charttype, c.category,
      c.link, c.pos_bilanz, c.pos_eur, c.new_chart_id, c.valid_from,
      c.pos_bwa, datevautomatik,
      tk.taxkey_id, tk.pos_ustva, tk.tax_id,
      tk.tax_id || '--' || tk.taxkey_id AS tax, tk.startdate
    FROM chart c
    LEFT JOIN taxkeys tk
    ON (c.id=tk.chart_id AND tk.id =
      (SELECT id FROM taxkeys
       WHERE taxkeys.chart_id = c.id AND startdate <= current_date
       ORDER BY startdate DESC LIMIT 1))
    WHERE c.id = ?
    };


  $main::lxdebug->message(LXDebug::QUERY, "\$query=\n $query");
  my $sth = $dbh->prepare($query);
  $sth->execute($form->{id}) || $form->dberror($query . " ($form->{id})");

  my $ref = $sth->fetchrow_hashref(NAME_lc);

  foreach my $key (keys %$ref) {
    $form->{"$key"} = $ref->{"$key"};
  }

  $sth->finish;

  # get default accounts
  $query = qq|SELECT inventory_accno_id, income_accno_id, expense_accno_id
              FROM defaults|;
  $main::lxdebug->message(LXDebug::QUERY, "\$query=\n $query");
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $ref = $sth->fetchrow_hashref(NAME_lc);

  map { $form->{$_} = $ref->{$_} } keys %ref;

  $sth->finish;



  # get taxkeys and description
  $query = qq{
    SELECT
      id,
      (SELECT accno FROM chart WHERE id=tax.chart_id) AS chart_accno,
      taxkey,
      id||'--'||taxkey AS tax,
      taxdescription,
      rate
    FROM tax ORDER BY taxkey
  };
  $main::lxdebug->message(LXDebug::QUERY, "\$query=\n $query");
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $form->{TAXKEY} = [];

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{TAXKEY} }, $ref;
  }

  $sth->finish;
  if ($form->{id}) {
    # get new accounts
    $query = qq|SELECT id, accno,description
                FROM chart
                WHERE link = ?
                ORDER BY accno|;
    $main::lxdebug->message(LXDebug::QUERY, "\$query=\n $query");
    $sth = $dbh->prepare($query);
    $sth->execute($form->{link}) || $form->dberror($query . " ($form->{link})");

    $form->{NEWACCOUNT} = [];
    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $form->{NEWACCOUNT} }, $ref;
    }

    $sth->finish;

    # get the taxkeys of account

    $query = qq{
      SELECT
        tk.id,
        tk.chart_id,
        c.accno,
        tk.tax_id,
        t.taxdescription,
        t.rate,
        tk.taxkey_id,
        tk.pos_ustva,
        tk.startdate
      FROM taxkeys tk
      LEFT JOIN   tax t ON (t.id = tk.tax_id)
      LEFT JOIN chart c ON (c.id = t.chart_id)

      WHERE tk.chart_id = ?
      ORDER BY startdate DESC
    };
    $main::lxdebug->message(LXDebug::QUERY, "\$query=\n $query");
    $sth = $dbh->prepare($query);

    $sth->execute($form->{id}) || $form->dberror($query . " ($form->{id})");

    $form->{ACCOUNT_TAXKEYS} = [];

    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $form->{ACCOUNT_TAXKEYS} }, $ref;
    }

    $sth->finish;

  }
  # check if we have any transactions
  $query = qq|SELECT a.trans_id FROM acc_trans a
              WHERE a.chart_id = ?|;
  $main::lxdebug->message(LXDebug::QUERY, "\$query=\n $query");
  $sth = $dbh->prepare($query);
  $sth->execute($form->{id}) || $form->dberror($query . " ($form->{id})");

  ($form->{orphaned}) = $sth->fetchrow_array;
  $form->{orphaned} = !$form->{orphaned};
  $sth->finish;

  # check if new account is active
  $form->{new_chart_valid} = 0;
  if ($form->{new_chart_id}) {
    $query = qq|SELECT current_date-valid_from FROM chart
                WHERE id = ?|;
    $main::lxdebug->message(LXDebug::QUERY, "\$query=\n $query");
    my ($count) = selectrow_query($form, $dbh, $query, $form->{id});
    if ($count >=0) {
      $form->{new_chart_valid} = 1;
    }
    $sth->finish;
  }

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub save_account {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database, turn off AutoCommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  # sanity check, can't have AR with AR_...
  if ($form->{AR} || $form->{AP} || $form->{IC}) {
    map { delete $form->{$_} }
      qw(AR_amount AR_tax AR_paid AP_amount AP_tax AP_paid IC_sale IC_cogs IC_taxpart IC_income IC_expense IC_taxservice CT_tax);
  }

  $form->{link} = "";
  foreach my $item ($form->{AR},            $form->{AR_amount},
                    $form->{AR_tax},        $form->{AR_paid},
                    $form->{AP},            $form->{AP_amount},
                    $form->{AP_tax},        $form->{AP_paid},
                    $form->{IC},            $form->{IC_sale},
                    $form->{IC_cogs},       $form->{IC_taxpart},
                    $form->{IC_income},     $form->{IC_expense},
                    $form->{IC_taxservice}, $form->{CT_tax}
    ) {
    $form->{link} .= "${item}:" if ($item);
  }
  chop $form->{link};

  # strip blanks from accno
  map { $form->{$_} =~ s/ //g; } qw(accno);

  my ($query, $sth);

  if ($form->{id} eq "NULL") {
    $form->{id} = "";
  }

  my @values;

  if ($form->{id}) {
    $query = qq|UPDATE chart SET
                  accno = ?,
                  description = ?,
                  charttype = ?,
                  category = ?,
                  link = ?,
                  pos_bwa   = ?,
                  pos_bilanz = ?,
                  pos_eur = ?,
                  new_chart_id = ?,
                  valid_from = ?,
                  datevautomatik = ?
                WHERE id = ?|;

    @values = (
                  $form->{accno},
                  $form->{description},
                  $form->{charttype},
                  $form->{category},
                  $form->{link},
                  conv_i($form->{pos_bwa}),
                  conv_i($form->{pos_bilanz}),
                  conv_i($form->{pos_eur}),
                  conv_i($form->{new_chart_id}),
                  conv_date($form->{valid_from}),
                  ($form->{datevautomatik} eq 'T') ? 'true':'false',
                $form->{id},
    );

  }
  elsif ($form->{id} && !$form->{new_chart_valid}) {

    $query = qq|
                  UPDATE chart
                  SET new_chart_id = ?,
                  valid_from = ?
                  WHERE id = ?
             |;

    @values = (
                  conv_i($form->{new_chart_id}),
                  conv_date($form->{valid_from}),
                  $form->{id}
              );
  }
  else {

    $query = qq|
                  INSERT INTO chart (
                      accno,
                      description,
                      charttype,
                      category,
                      link,
                      pos_bwa,
                      pos_bilanz,
                      pos_eur,
                      new_chart_id,
                      valid_from,
                      datevautomatik )
                  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
             |;

    @values = (
                      $form->{accno},
                      $form->{description},
                      $form->{charttype},
                      $form->{category}, $form->{link},
                      conv_i($form->{pos_bwa}),
                      conv_i($form->{pos_bilanz}), conv_i($form->{pos_eur}),
                      conv_i($form->{new_chart_id}),
                      conv_date($form->{valid_from}),
                      ($form->{datevautomatik} eq 'T') ? 'true':'false',
              );

  }

  do_query($form, $dbh, $query, @values);

  #Save Taxkeys

  my @taxkeys = ();

  my $MAX_TRIES = 10; # Maximum count of taxkeys in form
  my $tk_count;

  READTAXKEYS:
  for $tk_count (0 .. $MAX_TRIES) {

    # Loop control

    # Check if the account already exists, else cancel
    last READTAXKEYS if ( $form->{'id'} == 0);

    # check if there is a startdate
    if ( $form->{"taxkey_startdate_$tk_count"} eq '' ) {
      $tk_count++;
      next READTAXKEYS;
    }

    # check if there is at least one relation to pos_ustva or tax_id
    if ( $form->{"taxkey_pos_ustva_$tk_count"} eq '' && $form->{"taxkey_tax_$tk_count"} == 0 ) {
      $tk_count++;
      next READTAXKEYS;
    }

    # Add valid taxkeys into the array
    push @taxkeys ,
      {
        id        => ($form->{"taxkey_id_$tk_count"} eq 'NEW') ? conv_i('') : conv_i($form->{"taxkey_id_$tk_count"}),
        tax_id    => conv_i($form->{"taxkey_tax_$tk_count"}),
        startdate => conv_date($form->{"taxkey_startdate_$tk_count"}),
        chart_id  => conv_i($form->{"id"}),
        pos_ustva => $form->{"taxkey_pos_ustva_$tk_count"},
        delete    => ( $form->{"taxkey_del_$tk_count"} eq 'delete' ) ? '1' : '',
      };

    $tk_count++;
  }

  TAXKEY:
  for my $j (0 .. $#taxkeys){
    if ( defined $taxkeys[$j]{'id'} ){
      # delete Taxkey?

      if ($taxkeys[$j]{'delete'}){
        $query = qq{
          DELETE FROM taxkeys WHERE id = ?
        };

        @values = ($taxkeys[$j]{'id'});

        do_query($form, $dbh, $query, @values);

        next TAXKEY;
      }

      # UPDATE Taxkey

      $query = qq{
        UPDATE taxkeys
        SET taxkey_id = (SELECT taxkey FROM tax WHERE tax.id = ?),
            chart_id  = ?,
            tax_id    = ?,
            pos_ustva = ?,
            startdate = ?
        WHERE id = ?
      };
      @values = (
        $taxkeys[$j]{'tax_id'},
        $taxkeys[$j]{'chart_id'},
        $taxkeys[$j]{'tax_id'},
        $taxkeys[$j]{'pos_ustva'},
        $taxkeys[$j]{'startdate'},
        $taxkeys[$j]{'id'},
      );
      do_query($form, $dbh, $query, @values);
    }
    else {
      # INSERT Taxkey

      $query = qq{
        INSERT INTO taxkeys (
          taxkey_id,
          chart_id,
          tax_id,
          pos_ustva,
          startdate
        )
        VALUES ((SELECT taxkey FROM tax WHERE tax.id = ?), ?, ?, ?, ?)
      };
      @values = (
        $taxkeys[$j]{'tax_id'},
        $taxkeys[$j]{'chart_id'},
        $taxkeys[$j]{'tax_id'},
        $taxkeys[$j]{'pos_ustva'},
        $taxkeys[$j]{'startdate'},
      );

      do_query($form, $dbh, $query, @values);
    }

  }

  # commit
  my $rc = $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $rc;
}

sub delete_account {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database, turn off AutoCommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query = qq|SELECT count(*) FROM acc_trans a
                 WHERE a.chart_id = ?|;
  my ($count) = selectrow_query($form, $dbh, $query, $form->{id});

  if ($count) {
    $dbh->disconnect;
    $main::lxdebug->leave_sub();
    return;
  }

  # set inventory_accno_id, income_accno_id, expense_accno_id to defaults
  foreach my $type (qw(inventory income expense)) {
    $query =
      qq|UPDATE parts | .
      qq|SET ${type}_accno_id = (SELECT ${type}_accno_id FROM defaults) | .
      qq|WHERE ${type}_accno_id = ?|;
    do_query($form, $dbh, $query, $form->{id});
  }

  foreach my $table (qw(partstax customertax vendortax tax)) {
    $query = qq|DELETE FROM $table
                WHERE chart_id = ?|;
    do_query($form, $dbh, $query, $form->{id});
  }

  # delete chart of account record
  $query = qq|DELETE FROM chart
              WHERE id = ?|;
  do_query($form, $dbh, $query, $form->{id});

  # delete account taxkeys
  $query = qq|DELETE FROM taxkeys
              WHERE chart_id = ?|;
  do_query($form, $dbh, $query, $form->{id});

  # commit and redirect
  my $rc = $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $rc;
}

sub departments {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT d.id, d.description, d.role
                 FROM department d
                 ORDER BY 2|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $form->{ALL} = [];
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{ALL} }, $ref;
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_department {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT d.description, d.role
                 FROM department d
                 WHERE d.id = ?|;
  my $sth = $dbh->prepare($query);
  $sth->execute($form->{id}) || $form->dberror($query . " ($form->{id})");

  my $ref = $sth->fetchrow_hashref(NAME_lc);

  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;

  # see if it is in use
  $query = qq|SELECT count(*) FROM dpt_trans d
              WHERE d.department_id = ?|;
  ($form->{orphaned}) = selectrow_query($form, $dbh, $query, $form->{id});

  $form->{orphaned} = !$form->{orphaned};
  $sth->finish;

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub save_department {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my @values = ($form->{description}, $form->{role});
  if ($form->{id}) {
    $query = qq|UPDATE department SET
                description = ?, role = ?
                WHERE id = ?|;
    push(@values, $form->{id});
  } else {
    $query = qq|INSERT INTO department
                (description, role)
                VALUES (?, ?)|;
  }
  do_query($form, $dbh, $query, @values);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub delete_department {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $query = qq|DELETE FROM department
              WHERE id = ?|;
  do_query($form, $dbh, $query, $form->{id});

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub lead {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT id, lead
                 FROM leads
                 ORDER BY 2|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $form->{ALL};
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{ALL} }, $ref;
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_lead {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query =
    qq|SELECT l.id, l.lead | .
    qq|FROM leads l | .
    qq|WHERE l.id = ?|;
  my $sth = $dbh->prepare($query);
  $sth->execute($form->{id}) || $form->dberror($query . " ($form->{id})");

  my $ref = $sth->fetchrow_hashref(NAME_lc);

  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub save_lead {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my @values = ($form->{description});
  # id is the old record
  if ($form->{id}) {
    $query = qq|UPDATE leads SET
                lead = ?
                WHERE id = ?|;
    puhs(@values, $form->{id});
  } else {
    $query = qq|INSERT INTO leads
                (lead)
                VALUES (?)|;
  }
  do_query($form, $dbh, $query, @values);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub delete_lead {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $query = qq|DELETE FROM leads
              WHERE id = ?|;
  do_query($form, $dbh, $query, $form->{id});

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub business {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT id, description, discount, customernumberinit
                 FROM business
                 ORDER BY 2|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $form->{ALL};
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{ALL} }, $ref;
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_business {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query =
    qq|SELECT b.description, b.discount, b.customernumberinit
       FROM business b
       WHERE b.id = ?|;
  my $sth = $dbh->prepare($query);
  $sth->execute($form->{id}) || $form->dberror($query . " ($form->{id})");

  my $ref = $sth->fetchrow_hashref(NAME_lc);

  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub save_business {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my @values = ($form->{description}, $form->{discount},
                $form->{customernumberinit});
  # id is the old record
  if ($form->{id}) {
    $query = qq|UPDATE business SET
                description = ?,
                discount = ?,
                customernumberinit = ?
                WHERE id = ?|;
    push(@values, $form->{id});
  } else {
    $query = qq|INSERT INTO business
                (description, discount, customernumberinit)
                VALUES (?, ?, ?)|;
  }
  do_query($form, $dbh, $query, @values);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub delete_business {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $query = qq|DELETE FROM business
              WHERE id = ?|;
  do_query($form, $dbh, $query, $form->{id});

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}


sub language {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $return_list) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query =
    "SELECT id, description, template_code, article_code, " .
    "  output_numberformat, output_dateformat, output_longdates " .
    "FROM language ORDER BY description";

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ary = [];

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push(@{ $ary }, $ref);
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  if ($return_list) {
    return @{$ary};
  } else {
    $form->{ALL} = $ary;
  }
}

sub get_language {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query =
    "SELECT description, template_code, article_code, " .
    "  output_numberformat, output_dateformat, output_longdates " .
    "FROM language WHERE id = ?";
  my $sth = $dbh->prepare($query);
  $sth->execute($form->{"id"}) || $form->dberror($query . " ($form->{id})");

  my $ref = $sth->fetchrow_hashref(NAME_lc);

  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_language_details {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $id) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query =
    "SELECT template_code, " .
    "  output_numberformat, output_dateformat, output_longdates " .
    "FROM language WHERE id = ?";
  my @res = selectrow_query($form, $dbh, $query, $id);
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return @res;
}

sub save_language {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  my (@values, $query);

  map({ push(@values, $form->{$_}); }
      qw(description template_code article_code
         output_numberformat output_dateformat output_longdates));

  # id is the old record
  if ($form->{id}) {
    $query =
      "UPDATE language SET " .
      "  description = ?, template_code = ?, article_code = ?, " .
      "  output_numberformat = ?, output_dateformat = ?, " .
      "  output_longdates = ? " .
      "WHERE id = ?";
    push(@values, $form->{id});
  } else {
    $query =
      "INSERT INTO language (" .
      "  description, template_code, article_code, " .
      "  output_numberformat, output_dateformat, output_longdates" .
      ") VALUES (?, ?, ?, ?, ?, ?)";
  }
  do_query($form, $dbh, $query, @values);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub delete_language {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  foreach my $table (qw(translation_payment_terms units_language)) {
    my $query = qq|DELETE FROM $table WHERE language_id = ?|;
    do_query($form, $dbh, $query, $form->{"id"});
  }

  $query = "DELETE FROM language WHERE id = ?";
  do_query($form, $dbh, $query, $form->{"id"});

  $dbh->commit();
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}


sub buchungsgruppe {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT id, description,
                 inventory_accno_id,
                 (SELECT accno FROM chart WHERE id = inventory_accno_id) AS inventory_accno,
                 income_accno_id_0,
                 (SELECT accno FROM chart WHERE id = income_accno_id_0) AS income_accno_0,
                 expense_accno_id_0,
                 (SELECT accno FROM chart WHERE id = expense_accno_id_0) AS expense_accno_0,
                 income_accno_id_1,
                 (SELECT accno FROM chart WHERE id = income_accno_id_1) AS income_accno_1,
                 expense_accno_id_1,
                 (SELECT accno FROM chart WHERE id = expense_accno_id_1) AS expense_accno_1,
                 income_accno_id_2,
                 (SELECT accno FROM chart WHERE id = income_accno_id_2) AS income_accno_2,
                 expense_accno_id_2,
                 (select accno FROM chart WHERE id = expense_accno_id_2) AS expense_accno_2,
                 income_accno_id_3,
                 (SELECT accno FROM chart WHERE id = income_accno_id_3) AS income_accno_3,
                 expense_accno_id_3,
                 (SELECT accno FROM chart WHERE id = expense_accno_id_3) AS expense_accno_3
                 FROM buchungsgruppen
                 ORDER BY sortkey|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $form->{ALL} = [];
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{ALL} }, $ref;
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_buchungsgruppe {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  if ($form->{id}) {
    my $query =
      qq|SELECT description, inventory_accno_id,
         (SELECT accno FROM chart WHERE id = inventory_accno_id) AS inventory_accno,
         income_accno_id_0,
         (SELECT accno FROM chart WHERE id = income_accno_id_0) AS income_accno_0,
         expense_accno_id_0,
         (SELECT accno FROM chart WHERE id = expense_accno_id_0) AS expense_accno_0,
         income_accno_id_1,
         (SELECT accno FROM chart WHERE id = income_accno_id_1) AS income_accno_1,
         expense_accno_id_1,
         (SELECT accno FROM chart WHERE id = expense_accno_id_1) AS expense_accno_1,
         income_accno_id_2,
         (SELECT accno FROM chart WHERE id = income_accno_id_2) AS income_accno_2,
         expense_accno_id_2,
         (select accno FROM chart WHERE id = expense_accno_id_2) AS expense_accno_2,
         income_accno_id_3,
         (SELECT accno FROM chart WHERE id = income_accno_id_3) AS income_accno_3,
         expense_accno_id_3,
         (SELECT accno FROM chart WHERE id = expense_accno_id_3) AS expense_accno_3
         FROM buchungsgruppen
         WHERE id = ?|;
    my $sth = $dbh->prepare($query);
    $sth->execute($form->{id}) || $form->dberror($query . " ($form->{id})");

    my $ref = $sth->fetchrow_hashref(NAME_lc);

    map { $form->{$_} = $ref->{$_} } keys %$ref;

    $sth->finish;

    my $query =
      qq|SELECT count(id) = 0 AS orphaned
         FROM parts
         WHERE buchungsgruppen_id = ?|;
    ($form->{orphaned}) = selectrow_query($form, $dbh, $query, $form->{id});
  }

  $query = "SELECT inventory_accno_id, income_accno_id, expense_accno_id ".
    "FROM defaults";
  ($form->{"std_inventory_accno_id"}, $form->{"std_income_accno_id"},
   $form->{"std_expense_accno_id"}) = selectrow_query($form, $dbh, $query);

  my $module = "IC";
  $query = qq|SELECT c.accno, c.description, c.link, c.id,
              d.inventory_accno_id, d.income_accno_id, d.expense_accno_id
              FROM chart c, defaults d
              WHERE c.link LIKE '%$module%'
              ORDER BY c.accno|;


  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    foreach my $key (split(/:/, $ref->{link})) {
      if (!$form->{"std_inventory_accno_id"} && ($key eq "IC")) {
        $form->{"std_inventory_accno_id"} = $ref->{"id"};
      }
      if ($key =~ /$module/) {
        if (   ($ref->{id} eq $ref->{inventory_accno_id})
            || ($ref->{id} eq $ref->{income_accno_id})
            || ($ref->{id} eq $ref->{expense_accno_id})) {
          push @{ $form->{"${module}_links"}{$key} },
            { accno       => $ref->{accno},
              description => $ref->{description},
              selected    => "selected",
              id          => $ref->{id} };
        } else {
          push @{ $form->{"${module}_links"}{$key} },
            { accno       => $ref->{accno},
              description => $ref->{description},
              selected    => "",
              id          => $ref->{id} };
        }
      }
    }
  }
  $sth->finish;


  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub save_buchungsgruppe {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my @values = ($form->{description}, $form->{inventory_accno_id},
                $form->{income_accno_id_0}, $form->{expense_accno_id_0},
                $form->{income_accno_id_1}, $form->{expense_accno_id_1},
                $form->{income_accno_id_2}, $form->{expense_accno_id_2},
                $form->{income_accno_id_3}, $form->{expense_accno_id_3});

  my $query;

  # id is the old record
  if ($form->{id}) {
    $query = qq|UPDATE buchungsgruppen SET
                description = ?, inventory_accno_id = ?,
                income_accno_id_0 = ?, expense_accno_id_0 = ?,
                income_accno_id_1 = ?, expense_accno_id_1 = ?,
                income_accno_id_2 = ?, expense_accno_id_2 = ?,
                income_accno_id_3 = ?, expense_accno_id_3 = ?
                WHERE id = ?|;
    push(@values, $form->{id});
  } else {
    $query = qq|SELECT COALESCE(MAX(sortkey) + 1, 1) FROM buchungsgruppen|;
    my ($sortkey) = $dbh->selectrow_array($query);
    $form->dberror($query) if ($dbh->err);
    push(@values, $sortkey);
    $query = qq|INSERT INTO buchungsgruppen
                (description, inventory_accno_id,
                income_accno_id_0, expense_accno_id_0,
                income_accno_id_1, expense_accno_id_1,
                income_accno_id_2, expense_accno_id_2,
                income_accno_id_3, expense_accno_id_3,
                sortkey)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)|;
  }
  do_query($form, $dbh, $query, @values);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub delete_buchungsgruppe {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $query = qq|DELETE FROM buchungsgruppen WHERE id = ?|;
  do_query($form, $dbh, $query, $form->{id});

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub swap_sortkeys {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $table) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query =
    qq|SELECT
       (SELECT sortkey FROM $table WHERE id = ?) AS sortkey1,
       (SELECT sortkey FROM $table WHERE id = ?) AS sortkey2|;
  my @values = ($form->{"id1"}, $form->{"id2"});
  my @sortkeys = selectrow_query($form, $dbh, $query, @values);

  $query = qq|UPDATE $table SET sortkey = ? WHERE id = ?|;
  my $sth = $dbh->prepare($query);
  $sth->execute($sortkeys[1], $form->{"id1"}) ||
    $form->dberror($query . " ($sortkeys[1], $form->{id1})");
  $sth->execute($sortkeys[0], $form->{"id2"}) ||
    $form->dberror($query . " ($sortkeys[0], $form->{id2})");
  $sth->finish();

  $dbh->commit();
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub printer {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT id, printer_description, template_code, printer_command
                 FROM printers
                 ORDER BY 2|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $form->{"ALL"} = [];
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{ALL} }, $ref;
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_printer {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query =
    qq|SELECT p.printer_description, p.template_code, p.printer_command
       FROM printers p
       WHERE p.id = ?|;
  my $sth = $dbh->prepare($query);
  $sth->execute($form->{id}) || $form->dberror($query . " ($form->{id})");

  my $ref = $sth->fetchrow_hashref(NAME_lc);

  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub save_printer {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my @values = ($form->{printer_description},
                $form->{template_code},
                $form->{printer_command});

  # id is the old record
  if ($form->{id}) {
    $query = qq|UPDATE printers SET
                printer_description = ?, template_code = ?, printer_command = ?
                WHERE id = ?|;
    push(@values, $form->{id});
  } else {
    $query = qq|INSERT INTO printers
                (printer_description, template_code, printer_command)
                VALUES (?, ?, ?)|;
  }
  do_query($form, $dbh, $query, @values);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub delete_printer {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $query = qq|DELETE FROM printers
              WHERE id = ?|;
  do_query($form, $dbh, $query, $form->{id});

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub payment {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT * FROM payment_terms ORDER BY sortkey|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $form->{ALL} = [];
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{ALL} }, $ref;
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_payment {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT * FROM payment_terms WHERE id = ?|;
  my $sth = $dbh->prepare($query);
  $sth->execute($form->{"id"}) || $form->dberror($query . " ($form->{id})");

  my $ref = $sth->fetchrow_hashref(NAME_lc);
  map { $form->{$_} = $ref->{$_} } keys %$ref;
  $sth->finish();

  $query =
    qq|SELECT t.language_id, t.description_long, l.description AS language | .
    qq|FROM translation_payment_terms t | .
    qq|LEFT JOIN language l ON t.language_id = l.id | .
    qq|WHERE t.payment_terms_id = ? | .
    qq|UNION | .
    qq|SELECT l.id AS language_id, NULL AS description_long, | .
    qq|  l.description AS language | .
    qq|FROM language l|;
  $sth = $dbh->prepare($query);
  $sth->execute($form->{"id"}) || $form->dberror($query . " ($form->{id})");

  my %mapping;
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    $mapping{ $ref->{"language_id"} } = $ref
      unless (defined($mapping{ $ref->{"language_id"} }));
  }
  $sth->finish;

  $form->{"TRANSLATION"} = [sort({ $a->{"language"} cmp $b->{"language"} }
                                 values(%mapping))];

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub save_payment {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query;

  if (!$form->{id}) {
    $query = qq|SELECT nextval('id'), COALESCE(MAX(sortkey) + 1, 1) | .
      qq|FROM payment_terms|;
    my $sortkey;
    ($form->{id}, $sortkey) = selectrow_query($form, $dbh, $query);

    $query = qq|INSERT INTO payment_terms (id, sortkey) VALUES (?, ?)|;
    do_query($form, $dbh, $query, $form->{id}, $sortkey);

  } else {
    $query =
      qq|DELETE FROM translation_payment_terms | .
      qq|WHERE payment_terms_id = ?|;
    do_query($form, $dbh, $query, $form->{"id"});
  }

  $query = qq|UPDATE payment_terms SET
              description = ?, description_long = ?,
              ranking = ?,
              terms_netto = ?, terms_skonto = ?,
              percent_skonto = ?
              WHERE id = ?|;
  my @values = ($form->{description}, $form->{description_long},
                $form->{ranking} * 1,
                $form->{terms_netto} * 1, $form->{terms_skonto} * 1,
                $form->{percent_skonto} * 1,
                $form->{id});
  do_query($form, $dbh, $query, @values);

  $query = qq|SELECT id FROM language|;
  my @language_ids;
  my $sth = $dbh->prepare($query);
  $sth->execute() || $form->dberror($query);

  while (my ($id) = $sth->fetchrow_array()) {
    push(@language_ids, $id);
  }
  $sth->finish();

  $query =
    qq|INSERT INTO translation_payment_terms | .
    qq|(language_id, payment_terms_id, description_long) | .
    qq|VALUES (?, ?, ?)|;
  $sth = $dbh->prepare($query);

  foreach my $language_id (@language_ids) {
    do_statement($form, $sth, $query, $language_id, $form->{"id"},
                 $form->{"description_long_${language_id}"});
  }
  $sth->finish();

  $dbh->commit();
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub delete_payment {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query =
    qq|DELETE FROM translation_payment_terms WHERE payment_terms_id = ?|;
  do_query($form, $dbh, $query, $form->{"id"});

  $query = qq|DELETE FROM payment_terms WHERE id = ?|;
  do_query($form, $dbh, $query, $form->{"id"});

  $dbh->commit();
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}


sub prepare_template_filename {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my ($filename, $display_filename);

  if ($form->{type} eq "stylesheet") {
    $filename = "css/$myconfig->{stylesheet}";
    $display_filename = $myconfig->{stylesheet};

  } else {
    $filename = $form->{formname};

    if ($form->{language}) {
      my ($id, $template_code) = split(/--/, $form->{language});
      $filename .= "_${template_code}";
    }

    if ($form->{printer}) {
      my ($id, $template_code) = split(/--/, $form->{printer});
      $filename .= "_${template_code}";
    }

    $filename .= "." . ($form->{format} eq "html" ? "html" : "tex");
    $filename =~ s|.*/||;
    $display_filename = $filename;
    $filename = "$myconfig->{templates}/$filename";
  }

  $main::lxdebug->leave_sub();

  return ($filename, $display_filename);
}


sub load_template {
  $main::lxdebug->enter_sub();

  my ($self, $filename) = @_;

  my ($content, $lines) = ("", 0);

  local *TEMPLATE;

  if (open(TEMPLATE, $filename)) {
    while (<TEMPLATE>) {
      $content .= $_;
      $lines++;
    }
    close(TEMPLATE);
  }

  $main::lxdebug->leave_sub();

  return ($content, $lines);
}

sub save_template {
  $main::lxdebug->enter_sub();

  my ($self, $filename, $content) = @_;

  local *TEMPLATE;

  my $error = "";

  if (open(TEMPLATE, ">$filename")) {
    $content =~ s/\r\n/\n/g;
    print(TEMPLATE $content);
    close(TEMPLATE);
  } else {
    $error = $!;
  }

  $main::lxdebug->leave_sub();

  return $error;
}

sub save_preferences {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $memberfile, $userspath, $webdav) = @_;

  map { ($form->{$_}) = split(/--/, $form->{$_}) }
    qw(inventory_accno income_accno expense_accno fxgain_accno fxloss_accno);

  my @a;
  $form->{curr} =~ s/ //g;
  map { push(@a, uc pack "A3", $_) if $_ } split(/:/, $form->{curr});
  $form->{curr} = join ':', @a;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  # these defaults are database wide
  # user specific variables are in myconfig
  # save defaults
  my $query =
    qq|UPDATE defaults SET | .
    qq|inventory_accno_id = (SELECT c.id FROM chart c WHERE c.accno = ?), | .
    qq|income_accno_id = (SELECT c.id FROM chart c WHERE c.accno = ?), | .
    qq|expense_accno_id = (SELECT c.id FROM chart c WHERE c.accno = ?), | .
    qq|fxgain_accno_id = (SELECT c.id FROM chart c WHERE c.accno = ?), | .
    qq|fxloss_accno_id = (SELECT c.id FROM chart c WHERE c.accno = ?), | .
    qq|invnumber = ?, | .
    qq|cnnumber  = ?, | .
    qq|sonumber = ?, | .
    qq|ponumber = ?, | .
    qq|sqnumber = ?, | .
    qq|rfqnumber = ?, | .
    qq|customernumber = ?, | .
    qq|vendornumber = ?, | .
    qq|articlenumber = ?, | .
    qq|servicenumber = ?, | .
    qq|yearend = ?, | .
    qq|curr = ?, | .
    qq|businessnumber = ?|;
  my @values = ($form->{inventory_accno}, $form->{income_accno},
                $form->{expense_accno},
                $form->{fxgain_accno}, $form->{fxloss_accno},
                $form->{invnumber}, $form->{cnnumber},
                $form->{sonumber}, $form->{ponumber},
                $form->{sqnumber}, $form->{rfqnumber},
                $form->{customernumber}, $form->{vendornumber},
                $form->{articlenumber}, $form->{servicenumber},
                $form->{yearend}, $form->{curr},
                $form->{businessnumber});
  do_query($form, $dbh, $query, @values);

  # update name
  $query = qq|UPDATE employee
              SET name = ?
              WHERE login = ?|;
  do_query($form, $dbh, $query, $form->{name}, $form->{login});

  my $rc = $dbh->commit;
  $dbh->disconnect;

  # save first currency in myconfig
  $form->{currency} = substr($form->{curr}, 0, 3);

  my $myconfig = new User "$memberfile", "$form->{login}";

  foreach my $item (keys %$form) {
    $myconfig->{$item} = $form->{$item};
  }

  $myconfig->save_member($memberfile, $userspath);

  if ($webdav) {
    @webdavdirs =
      qw(angebote bestellungen rechnungen anfragen lieferantenbestellungen einkaufsrechnungen);
    foreach $directory (@webdavdirs) {
      $file = "webdav/" . $directory . "/webdav-user";
      if ($myconfig->{$directory}) {
        open(HTACCESS, "$file") or die "cannot open webdav-user $!\n";
        while (<HTACCESS>) {
          ($login, $password) = split(/:/, $_);
          if ($login ne $form->{login}) {
            $newfile .= $_;
          }
        }
        close(HTACCESS);
        open(HTACCESS, "> $file") or die "cannot open webdav-user $!\n";
        $newfile .= $myconfig->{login} . ":" . $myconfig->{password} . "\n";
        print(HTACCESS $newfile);
        close(HTACCESS);
      } else {
        $form->{$directory} = 0;
        open(HTACCESS, "$file") or die "cannot open webdav-user $!\n";
        while (<HTACCESS>) {
          ($login, $password) = split(/:/, $_);
          if ($login ne $form->{login}) {
            $newfile .= $_;
          }
        }
        close(HTACCESS);
        open(HTACCESS, "> $file") or die "cannot open webdav-user $!\n";
        print(HTACCESS $newfile);
        close(HTACCESS);
      }
    }
  }

  $main::lxdebug->leave_sub();

  return $rc;
}

sub defaultaccounts {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  # get defaults from defaults table
  my $query = qq|SELECT * FROM defaults|;
  my $sth   = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $form->{defaults}             = $sth->fetchrow_hashref(NAME_lc);
  $form->{defaults}{IC}         = $form->{defaults}{inventory_accno_id};
  $form->{defaults}{IC_income}  = $form->{defaults}{income_accno_id};
  $form->{defaults}{IC_expense} = $form->{defaults}{expense_accno_id};
  $form->{defaults}{FX_gain}    = $form->{defaults}{fxgain_accno_id};
  $form->{defaults}{FX_loss}    = $form->{defaults}{fxloss_accno_id};

  $sth->finish;

  $query = qq|SELECT c.id, c.accno, c.description, c.link
              FROM chart c
              WHERE c.link LIKE '%IC%'
              ORDER BY c.accno|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    foreach my $key (split(/:/, $ref->{link})) {
      if ($key =~ /IC/) {
        $nkey = $key;
        if ($key =~ /cogs/) {
          $nkey = "IC_expense";
        }
        if ($key =~ /sale/) {
          $nkey = "IC_income";
        }
        %{ $form->{IC}{$nkey}{ $ref->{accno} } } = (
                                             id          => $ref->{id},
                                             description => $ref->{description}
        );
      }
    }
  }
  $sth->finish;

  $query = qq|SELECT c.id, c.accno, c.description
              FROM chart c
              WHERE c.category = 'I'
              AND c.charttype = 'A'
              ORDER BY c.accno|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    %{ $form->{IC}{FX_gain}{ $ref->{accno} } } = (
                                             id          => $ref->{id},
                                             description => $ref->{description}
    );
  }
  $sth->finish;

  $query = qq|SELECT c.id, c.accno, c.description
              FROM chart c
              WHERE c.category = 'E'
              AND c.charttype = 'A'
              ORDER BY c.accno|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    %{ $form->{IC}{FX_loss}{ $ref->{accno} } } = (
                                             id          => $ref->{id},
                                             description => $ref->{description}
    );
  }
  $sth->finish;

  # now get the tax rates and numbers
  $query = qq|SELECT c.id, c.accno, c.description,
              t.rate * 100 AS rate, t.taxnumber
              FROM chart c, tax t
              WHERE c.id = t.chart_id|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    $form->{taxrates}{ $ref->{accno} }{id}          = $ref->{id};
    $form->{taxrates}{ $ref->{accno} }{description} = $ref->{description};
    $form->{taxrates}{ $ref->{accno} }{taxnumber}   = $ref->{taxnumber}
      if $ref->{taxnumber};
    $form->{taxrates}{ $ref->{accno} }{rate} = $ref->{rate} if $ref->{rate};
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub closedto {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT closedto, revtrans FROM defaults|;
  my $sth   = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  ($form->{closedto}, $form->{revtrans}) = $sth->fetchrow_array;

  $sth->finish;

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub closebooks {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my ($query, @values);

  if ($form->{revtrans}) {
    $query = qq|UPDATE defaults SET closedto = NULL, revtrans = '1'|;

  } elsif ($form->{closedto}) {
    $query = qq|UPDATE defaults SET closedto = ?, revtrans = '0'|;
    @values = (conv_date($form->{closedto}));

  } else {
    $query = qq|UPDATE defaults SET closedto = NULL, revtrans = '0'|;
  }

  # set close in defaults
  do_query($form, $dbh, $query, @values);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_base_unit {
  my ($self, $units, $unit_name, $factor) = @_;

  $factor = 1 unless ($factor);

  my $unit = $units->{$unit_name};

  if (!defined($unit) || !$unit->{"base_unit"} ||
      ($unit_name eq $unit->{"base_unit"})) {
    return ($unit_name, $factor);
  }

  return AM->get_base_unit($units, $unit->{"base_unit"}, $factor * $unit->{"factor"});
}

sub retrieve_units {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $type, $prefix) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my $query = "SELECT *, base_unit AS original_base_unit FROM units";
  my @values;
  if ($type) {
    $query .= " WHERE (type = ?)";
    @values = ($type);
  }

  my $sth = $dbh->prepare($query);
  $sth->execute(@values) || $form->dberror($query . " (" . join(", ", @values) . ")");

  my $units = {};
  while (my $ref = $sth->fetchrow_hashref()) {
    $units->{$ref->{"name"}} = $ref;
  }
  $sth->finish();

  my $query_lang = "SELECT id, template_code FROM language ORDER BY description";
  $sth = $dbh->prepare($query_lang);
  $sth->execute() || $form->dberror($query_lang);
  my @languages;
  while ($ref = $sth->fetchrow_hashref()) {
    push(@languages, $ref);
  }
  $sth->finish();

  $query_lang = "SELECT ul.localized, ul.localized_plural, l.id, l.template_code " .
    "FROM units_language ul " .
    "LEFT JOIN language l ON ul.language_id = l.id " .
    "WHERE ul.unit = ?";
  $sth = $dbh->prepare($query_lang);

  foreach my $unit (values(%{$units})) {
    ($unit->{"${prefix}base_unit"}, $unit->{"${prefix}factor"}) = AM->get_base_unit($units, $unit->{"name"});

    $unit->{"LANGUAGES"} = {};
    foreach my $lang (@languages) {
      $unit->{"LANGUAGES"}->{$lang->{"template_code"}} = { "template_code" => $lang->{"template_code"} };
    }

    $sth->execute($unit->{"name"}) || $form->dberror($query_lang . " (" . $unit->{"name"} . ")");
    while ($ref = $sth->fetchrow_hashref()) {
      map({ $unit->{"LANGUAGES"}->{$ref->{"template_code"}}->{$_} = $ref->{$_} } keys(%{$ref}));
    }
  }
  $sth->finish();

  $dbh->disconnect();

  $main::lxdebug->leave_sub();

  return $units;
}

sub translate_units {
  $main::lxdebug->enter_sub();

  my ($self, $form, $template_code, $unit, $amount) = @_;

  my $units = $self->retrieve_units(\%main::myconfig, $form);

  my $h = $units->{$unit}->{"LANGUAGES"}->{$template_code};
  my $new_unit = $unit;
  if ($h) {
    if (($amount != 1) && $h->{"localized_plural"}) {
      $new_unit = $h->{"localized_plural"};
    } elsif ($h->{"localized"}) {
      $new_unit = $h->{"localized"};
    }
  }

  $main::lxdebug->leave_sub();

  return $new_unit;
}

sub units_in_use {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $units) = @_;

  my $dbh = $form->dbconnect($myconfig);

  map({ $_->{"in_use"} = 0; } values(%{$units}));

  foreach my $unit (values(%{$units})) {
    my $base_unit = $unit->{"original_base_unit"};
    while ($base_unit) {
      $units->{$base_unit}->{"in_use"} = 1;
      $units->{$base_unit}->{"DEPENDING_UNITS"} = [] unless ($units->{$base_unit}->{"DEPENDING_UNITS"});
      push(@{$units->{$base_unit}->{"DEPENDING_UNITS"}}, $unit->{"name"});
      $base_unit = $units->{$base_unit}->{"original_base_unit"};
    }
  }

  foreach my $unit (values(%{$units})) {
    map({ $_ = $dbh->quote($_); } @{$unit->{"DEPENDING_UNITS"}});

    foreach my $table (qw(parts invoice orderitems)) {
      my $query = "SELECT COUNT(*) FROM $table WHERE unit ";

      if (0 == scalar(@{$unit->{"DEPENDING_UNITS"}})) {
        $query .= "= " . $dbh->quote($unit->{"name"});
      } else {
        $query .= "IN (" . $dbh->quote($unit->{"name"}) . "," .
          join(",", map({ $dbh->quote($_) } @{$unit->{"DEPENDING_UNITS"}})) . ")";
      }

      my ($count) = $dbh->selectrow_array($query);
      $form->dberror($query) if ($dbh->err);

      if ($count) {
        $unit->{"in_use"} = 1;
        last;
      }
    }
  }

  $dbh->disconnect();

  $main::lxdebug->leave_sub();
}

sub unit_select_data {
  $main::lxdebug->enter_sub();

  my ($self, $units, $selected, $empty_entry) = @_;

  my $select = [];

  if ($empty_entry) {
    push(@{$select}, { "name" => "", "base_unit" => "", "factor" => "", "selected" => "" });
  }

  foreach my $unit (sort({ $units->{$a}->{"sortkey"} <=> $units->{$b}->{"sortkey"} } keys(%{$units}))) {
    push(@{$select}, { "name" => $unit,
                       "base_unit" => $units->{$unit}->{"base_unit"},
                       "factor" => $units->{$unit}->{"factor"},
                       "selected" => ($unit eq $selected) ? "selected" : "" });
  }

  $main::lxdebug->leave_sub();

  return $select;
}

sub unit_select_html {
  $main::lxdebug->enter_sub();

  my ($self, $units, $name, $selected, $convertible_into) = @_;

  my $select = "<select name=${name}>";

  foreach my $unit (sort({ $units->{$a}->{"sortkey"} <=> $units->{$b}->{"sortkey"} } keys(%{$units}))) {
    if (!$convertible_into ||
        ($units->{$convertible_into} &&
         ($units->{$convertible_into}->{"base_unit"} eq $units->{$unit}->{"base_unit"}))) {
      $select .= "<option" . (($unit eq $selected) ? " selected" : "") . ">${unit}</option>";
    }
  }
  $select .= "</select>";

  $main::lxdebug->leave_sub();

  return $select;
}

sub add_unit {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $name, $base_unit, $factor, $type, $languages) = @_;

  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query = qq|SELECT COALESCE(MAX(sortkey), 0) + 1 FROM units|;
  my ($sortkey) = selectrow_query($form, $dbh, $query);

  $query = "INSERT INTO units (name, base_unit, factor, type, sortkey) " .
    "VALUES (?, ?, ?, ?, ?)";
  do_query($form, $dbh, $query, $name, $base_unit, $factor, $type, $sortkey);

  if ($languages) {
    $query = "INSERT INTO units_language (unit, language_id, localized, localized_plural) VALUES (?, ?, ?, ?)";
    my $sth = $dbh->prepare($query);
    foreach my $lang (@{$languages}) {
      my @values = ($name, $lang->{"id"}, $lang->{"localized"}, $lang->{"localized_plural"});
      $sth->execute(@values) || $form->dberror($query . " (" . join(", ", @values) . ")");
    }
    $sth->finish();
  }

  $dbh->commit();
  $dbh->disconnect();

  $main::lxdebug->leave_sub();
}

sub save_units {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $type, $units, $delete_units) = @_;

  my $dbh = $form->dbconnect_noauto($myconfig);

  my ($base_unit, $unit, $sth, $query);

  $query = "DELETE FROM units_language";
  $dbh->do($query) || $form->dberror($query);

  if ($delete_units && (0 != scalar(@{$delete_units}))) {
    $query = "DELETE FROM units WHERE name IN (";
    map({ $query .= "?," } @{$delete_units});
    substr($query, -1, 1) = ")";
    $dbh->do($query, undef, @{$delete_units}) ||
      $form->dberror($query . " (" . join(", ", @{$delete_units}) . ")");
  }

  $query = "UPDATE units SET name = ?, base_unit = ?, factor = ? WHERE name = ?";
  $sth = $dbh->prepare($query);

  my $query_lang = "INSERT INTO units_language (unit, language_id, localized, localized_plural) VALUES (?, ?, ?, ?)";
  my $sth_lang = $dbh->prepare($query_lang);

  foreach $unit (values(%{$units})) {
    $unit->{"depth"} = 0;
    my $base_unit = $unit;
    while ($base_unit->{"base_unit"}) {
      $unit->{"depth"}++;
      $base_unit = $units->{$base_unit->{"base_unit"}};
    }
  }

  foreach $unit (sort({ $a->{"depth"} <=> $b->{"depth"} } values(%{$units}))) {
    if ($unit->{"LANGUAGES"}) {
      foreach my $lang (@{$unit->{"LANGUAGES"}}) {
        next unless ($lang->{"id"} && $lang->{"localized"});
        my @values = ($unit->{"name"}, $lang->{"id"}, $lang->{"localized"}, $lang->{"localized_plural"});
        $sth_lang->execute(@values) || $form->dberror($query_lang . " (" . join(", ", @values) . ")");
      }
    }

    next if ($unit->{"unchanged_unit"});

    my @values = ($unit->{"name"}, $unit->{"base_unit"}, $unit->{"factor"}, $unit->{"old_name"});
    $sth->execute(@values) || $form->dberror($query . " (" . join(", ", @values) . ")");
  }

  $sth->finish();
  $sth_lang->finish();
  $dbh->commit();
  $dbh->disconnect();

  $main::lxdebug->leave_sub();
}

sub swap_units {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $dir, $name_1, $unit_type) = @_;

  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query;

  $query = qq|SELECT sortkey FROM units WHERE name = ?|;
  my ($sortkey_1) = selectrow_query($form, $dbh, $query, $name_1);

  $query =
    qq|SELECT sortkey FROM units | .
    qq|WHERE sortkey | . ($dir eq "down" ? ">" : "<") . qq| ? AND type = ? | .
    qq|ORDER BY sortkey | . ($dir eq "down" ? "ASC" : "DESC") . qq| LIMIT 1|;
  my ($sortkey_2) = selectrow_query($form, $dbh, $query, $sortkey_1, $unit_type);

  if (defined($sortkey_1)) {
    $query = qq|SELECT name FROM units WHERE sortkey = ${sortkey_2}|;
    my ($name_2) = selectrow_query($form, $dbh, $query);

    if (defined($name_2)) {
      $query = qq|UPDATE units SET sortkey = ? WHERE name = ?|;
      my $sth = $dbh->prepare($query);

      do_statement($form, $sth, $query, $sortkey_1, $name_2);
      do_statement($form, $sth, $query, $sortkey_2, $name_1);
    }
  }

  $dbh->commit();
  $dbh->disconnect();

  $main::lxdebug->leave_sub();
}

sub taxes {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT
                   t.id,
                   t.taxkey,
                   t.taxdescription,
                   round(t.rate * 100, 2) AS rate,
                   (SELECT accno FROM chart WHERE id = chart_id) AS taxnumber,
                   (SELECT description FROM chart WHERE id = chart_id) AS account_description
                 FROM tax t
                 ORDER BY taxkey|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $form->{TAX} = [];
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{TAX} }, $ref;
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_tax_accounts {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect($myconfig);

  # get Accounts from chart
  my $query = qq{ SELECT
                 id,
                 accno || ' - ' || description AS taxaccount
               FROM chart
               WHERE link LIKE '%_tax%'
               ORDER BY accno
             };

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $form->{ACCOUNTS} = [];
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{ACCOUNTS} }, $ref;
  }

  $sth->finish;

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_tax {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT
                   taxkey,
                   taxdescription,
                   round(rate * 100, 2) AS rate,
                   chart_id
                 FROM tax
                 WHERE id = ? |;

  my $sth = $dbh->prepare($query);
  $sth->execute($form->{id}) || $form->dberror($query . " ($form->{id})");

  my $ref = $sth->fetchrow_hashref(NAME_lc);

  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;

  # see if it is used by a taxkey
  $query = qq|SELECT count(*) FROM taxkeys
              WHERE tax_id = ? AND chart_id >0|;

  ($form->{orphaned}) = selectrow_query($form, $dbh, $query, $form->{id});

  $form->{orphaned} = !$form->{orphaned};
  $sth->finish;

  if (!$form->{orphaned} ) {
    $query = qq|SELECT DISTINCT c.id, c.accno
                FROM taxkeys tk
                JOIN   tax t ON (t.id = tk.tax_id)
                JOIN chart c ON (c.id = tk.chart_id)
                WHERE tk.tax_id = ?|;

    $sth = $dbh->prepare($query);
    $sth->execute($form->{id}) || $form->dberror($query . " ($form->{id})");

    $form->{TAXINUSE} = [];
    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $form->{TAXINUSE} }, $ref;
    }

    $sth->finish;
  }

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub save_tax {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->get_standard_dbh($myconfig);

  $form->{rate} = $form->{rate} / 100;

  my @values = ($form->{taxkey}, $form->{taxdescription}, $form->{rate}, $form->{chart_id}, $form->{chart_id} );
  if ($form->{id} ne "") {
    $query = qq|UPDATE tax SET
                  taxkey         = ?,
                  taxdescription = ?,
                  rate           = ?,
                  chart_id       = ?,
                  taxnumber      = (SELECT accno FROM chart WHERE id= ? )
                WHERE id = ?|;
    push(@values, $form->{id});

  } else {
    #ok
    $query = qq|INSERT INTO tax (
                  taxkey,
                  taxdescription,
                  rate,
                  chart_id,
                  taxnumber
                )
                VALUES (?, ?, ?, ?, (SELECT accno FROM chart WHERE id = ?) )|;
  }
  do_query($form, $dbh, $query, @values);

  $dbh->commit();

  $main::lxdebug->leave_sub();
}

sub delete_tax {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->get_standard_dbh($myconfig);

  $query = qq|DELETE FROM tax
              WHERE id = ?|;
  do_query($form, $dbh, $query, $form->{id});

  $dbh->commit();

  $main::lxdebug->leave_sub();
}



1;
