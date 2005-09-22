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

sub get_account {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  $form->{id} = "NULL" unless ($form->{id});

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT c.accno, c.description, c.charttype, c.gifi_accno,
                 c.category, c.link, c.taxkey_id, c.pos_ustva, c.pos_bwa, c.pos_bilanz,c.pos_eur
                 FROM chart c
	         WHERE c.id = $form->{id}|;

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);

  foreach my $key (keys %$ref) {
    $form->{"$key"} = $ref->{"$key"};
  }

  $sth->finish;

  # get default accounts
  $query = qq|SELECT inventory_accno_id, income_accno_id, expense_accno_id
              FROM defaults|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $ref = $sth->fetchrow_hashref(NAME_lc);

  map { $form->{$_} = $ref->{$_} } keys %ref;

  $sth->finish;

  # get taxkeys and description
  $query = qq|SELECT taxkey, taxdescription
              FROM tax|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $ref = $sth->fetchrow_hashref(NAME_lc);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{TAXKEY} }, $ref;
  }

  $sth->finish;

  # check if we have any transactions
  $query = qq|SELECT a.trans_id FROM acc_trans a
              WHERE a.chart_id = $form->{id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  ($form->{orphaned}) = $sth->fetchrow_array;
  $form->{orphaned} = !$form->{orphaned};
  $sth->finish;

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

  # if we have an id then replace the old record
  $form->{description} =~ s/\'/\'\'/g;

  # strip blanks from accno
  map { $form->{$_} =~ s/ //g; } qw(accno);

  my ($query, $sth);

  if ($form->{id} eq "NULL") {
    $form->{id} = "";
  }

  map({ $form->{$_} = "NULL" unless ($form->{$_}); }
      qw(pos_ustva pos_bwa pos_bilanz pos_eur));

  if ($form->{id}) {
    $query = qq|UPDATE chart SET
                accno = '$form->{accno}',
		description = '$form->{description}',
		charttype = '$form->{charttype}',
		gifi_accno = '$form->{gifi_accno}',
		category = '$form->{category}',
		link = '$form->{link}',
                taxkey_id = $form->{taxkey_id},
                pos_ustva = $form->{pos_ustva},
                pos_bwa   = $form->{pos_bwa},
                pos_bilanz = $form->{pos_bilanz},
                pos_eur = $form->{pos_eur}
		WHERE id = $form->{id}|;
  } else {

    $query = qq|INSERT INTO chart
                (accno, description, charttype, gifi_accno, category, link, taxkey_id, pos_ustva, pos_bwa, pos_bilanz,pos_eur)
                VALUES ('$form->{accno}', '$form->{description}',
		'$form->{charttype}', '$form->{gifi_accno}',
		'$form->{category}', '$form->{link}', $form->{taxkey_id}, $form->{pos_ustva}, $form->{pos_bwa}, $form->{pos_bilanz}, $form->{pos_eur})|;
  }
  $dbh->do($query) || $form->dberror($query);

  if ($form->{IC_taxpart} || $form->{IC_taxservice} || $form->{CT_tax}) {

    my $chart_id = $form->{id};

    unless ($form->{id}) {

      # get id from chart
      $query = qq|SELECT c.id
                  FROM chart c
		  WHERE c.accno = '$form->{accno}'|;
      $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);

      ($chart_id) = $sth->fetchrow_array;
      $sth->finish;
    }

    # add account if it doesn't exist in tax
    $query = qq|SELECT t.chart_id
                FROM tax t
		WHERE t.chart_id = $chart_id|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    my ($tax_id) = $sth->fetchrow_array;
    $sth->finish;

    # add tax if it doesn't exist
    unless ($tax_id) {
      $query = qq|INSERT INTO tax (chart_id, rate)
                  VALUES ($chart_id, 0)|;
      $dbh->do($query) || $form->dberror($query);
    }
  } else {

    # remove tax
    if ($form->{id}) {
      $query = qq|DELETE FROM tax
		  WHERE chart_id = $form->{id}|;
      $dbh->do($query) || $form->dberror($query);
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
                 WHERE a.chart_id = $form->{id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  if ($sth->fetchrow_array) {
    $sth->finish;
    $dbh->disconnect;
    $main::lxdebug->leave_sub();
    return;
  }
  $sth->finish;

  # delete chart of account record
  $query = qq|DELETE FROM chart
              WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # set inventory_accno_id, income_accno_id, expense_accno_id to defaults
  $query = qq|UPDATE parts
              SET inventory_accno_id =
	                 (SELECT inventory_accno_id FROM defaults)
	      WHERE inventory_accno_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $query = qq|UPDATE parts
              SET income_accno_id =
	                 (SELECT income_accno_id FROM defaults)
	      WHERE income_accno_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $query = qq|UPDATE parts
              SET expense_accno_id =
	                 (SELECT expense_accno_id FROM defaults)
	      WHERE expense_accno_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  foreach my $table (qw(partstax customertax vendortax tax)) {
    $query = qq|DELETE FROM $table
		WHERE chart_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
  }

  # commit and redirect
  my $rc = $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $rc;
}

sub gifi_accounts {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT accno, description
                 FROM gifi
		 ORDER BY accno|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{ALL} }, $ref;
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_gifi {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT g.accno, g.description
                 FROM gifi g
	         WHERE g.accno = '$form->{accno}'|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);

  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;

  # check for transactions
  $query = qq|SELECT count(*) FROM acc_trans a, chart c, gifi g
              WHERE c.gifi_accno = g.accno
	      AND a.chart_id = c.id
	      AND g.accno = '$form->{accno}'|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  ($form->{orphaned}) = $sth->fetchrow_array;
  $sth->finish;
  $form->{orphaned} = !$form->{orphaned};

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub save_gifi {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->{description} =~ s/\'/\'\'/g;

  # id is the old account number!
  if ($form->{id}) {
    $query = qq|UPDATE gifi SET
                accno = '$form->{accno}',
		description = '$form->{description}'
		WHERE accno = '$form->{id}'|;
  } else {
    $query = qq|INSERT INTO gifi
                (accno, description)
                VALUES ('$form->{accno}', '$form->{description}')|;
  }
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub delete_gifi {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  # id is the old account number!
  $query = qq|DELETE FROM gifi
	      WHERE accno = '$form->{id}'|;
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub warehouses {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT id, description
                 FROM warehouse
		 ORDER BY 2|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{ALL} }, $ref;
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_warehouse {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT w.description
                 FROM warehouse w
	         WHERE w.id = $form->{id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);

  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;

  # see if it is in use
  $query = qq|SELECT count(*) FROM inventory i
              WHERE i.warehouse_id = $form->{id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  ($form->{orphaned}) = $sth->fetchrow_array;
  $form->{orphaned} = !$form->{orphaned};
  $sth->finish;

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub save_warehouse {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->{description} =~ s/\'/\'\'/g;

  if ($form->{id}) {
    $query = qq|UPDATE warehouse SET
		description = '$form->{description}'
		WHERE id = $form->{id}|;
  } else {
    $query = qq|INSERT INTO warehouse
                (description)
                VALUES ('$form->{description}')|;
  }
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub delete_warehouse {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $query = qq|DELETE FROM warehouse
	      WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
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
	         WHERE d.id = $form->{id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);

  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;

  # see if it is in use
  $query = qq|SELECT count(*) FROM dpt_trans d
              WHERE d.department_id = $form->{id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  ($form->{orphaned}) = $sth->fetchrow_array;
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

  $form->{description} =~ s/\'/\'\'/g;

  if ($form->{id}) {
    $query = qq|UPDATE department SET
		description = '$form->{description}',
		role = '$form->{role}'
		WHERE id = $form->{id}|;
  } else {
    $query = qq|INSERT INTO department
                (description, role)
                VALUES ('$form->{description}', '$form->{role}')|;
  }
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub delete_department {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $query = qq|DELETE FROM department
	      WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub business {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT id, description, discount, customernumberinit, salesman
                 FROM business
		 ORDER BY 2|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

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
    qq|SELECT b.description, b.discount, b.customernumberinit, b.salesman
                 FROM business b
	         WHERE b.id = $form->{id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

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

  $form->{description} =~ s/\'/\'\'/g;
  $form->{discount} /= 100;
  $form->{salesman} *= 1;

  # id is the old record
  if ($form->{id}) {
    $query = qq|UPDATE business SET
		description = '$form->{description}',
		discount = $form->{discount},
                customernumberinit = '$form->{customernumberinit}',
                salesman = '$form->{salesman}'
		WHERE id = $form->{id}|;
  } else {
    $query = qq|INSERT INTO business
                (description, discount, customernumberinit, salesman)
                VALUES ('$form->{description}', $form->{discount}, '$form->{customernumberinit}', '$form->{salesman}')|;
  }
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub delete_business {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $query = qq|DELETE FROM business
	      WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub sic {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT code, sictype, description
                 FROM sic
		 ORDER BY code|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{ALL} }, $ref;
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_sic {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT s.code, s.sictype, s.description
                 FROM sic s
	         WHERE s.code = '$form->{code}'|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);

  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub save_sic {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->{code}        =~ s/\'/\'\'/g;
  $form->{description} =~ s/\'/\'\'/g;

  # if there is an id
  if ($form->{id}) {
    $query = qq|UPDATE sic SET
                code = '$form->{code}',
		sictype = '$form->{sictype}',
		description = '$form->{description}'
		WHERE code = '$form->{id}'|;
  } else {
    $query = qq|INSERT INTO sic
                (code, sictype, description)
                VALUES ('$form->{code}', '$form->{sictype}', '$form->{description}')|;
  }
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub delete_sic {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $query = qq|DELETE FROM sic
	      WHERE code = '$form->{code}'|;
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub load_template {
  $main::lxdebug->enter_sub();

  my ($self, $form) = @_;

  open(TEMPLATE, "$form->{file}") or $form->error("$form->{file} : $!");

  while (<TEMPLATE>) {
    $form->{body} .= $_;
  }

  close(TEMPLATE);

  $main::lxdebug->leave_sub();
}

sub save_template {
  $main::lxdebug->enter_sub();

  my ($self, $form) = @_;

  open(TEMPLATE, ">$form->{file}") or $form->error("$form->{file} : $!");

  # strip
  $form->{body} =~ s/\r\n/\n/g;
  print TEMPLATE $form->{body};

  close(TEMPLATE);

  $main::lxdebug->leave_sub();
}

sub save_preferences {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $memberfile, $userspath, $webdav) = @_;

  map { ($form->{$_}) = split /--/, $form->{$_} }
    qw(inventory_accno income_accno expense_accno fxgain_accno fxloss_accno);

  my @a;
  $form->{curr} =~ s/ //g;
  map { push(@a, uc pack "A3", $_) if $_ } split /:/, $form->{curr};
  $form->{curr} = join ':', @a;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  # these defaults are database wide
  # user specific variables are in myconfig
  # save defaults
  my $query = qq|UPDATE defaults SET
                 inventory_accno_id =
		     (SELECT c.id FROM chart c
		                WHERE c.accno = '$form->{inventory_accno}'),
                 income_accno_id =
		     (SELECT c.id FROM chart c
		                WHERE c.accno = '$form->{income_accno}'),
	         expense_accno_id =
		     (SELECT c.id FROM chart c
		                WHERE c.accno = '$form->{expense_accno}'),
	         fxgain_accno_id =
		     (SELECT c.id FROM chart c
		                WHERE c.accno = '$form->{fxgain_accno}'),
	         fxloss_accno_id =
		     (SELECT c.id FROM chart c
		                WHERE c.accno = '$form->{fxloss_accno}'),
	         invnumber = '$form->{invnumber}',
	         sonumber = '$form->{sonumber}',
	         ponumber = '$form->{ponumber}',
		 sqnumber = '$form->{sqnumber}',
		 rfqnumber = '$form->{rfqnumber}',
                 customernumber = '$form->{customernumber}',
		 vendornumber = '$form->{vendornumber}',
                 articlenumber = '$form->{articlenumber}',
                 servicenumber = '$form->{servicenumber}',
                 yearend = '$form->{yearend}',
		 curr = '$form->{curr}',
		 weightunit = '$form->{weightunit}',
		 businessnumber = '$form->{businessnumber}'
		|;
  $dbh->do($query) || $form->dberror($query);

  # update name
  my $name = $form->{name};
  $name =~ s/\'/\'\'/g;
  $query = qq|UPDATE employee
              SET name = '$name'
	      WHERE login = '$form->{login}'|;
  $dbh->do($query) || $form->dberror($query);

  foreach my $item (split / /, $form->{taxaccounts}) {
    $query = qq|UPDATE tax
		SET rate = | . ($form->{$item} / 100) . qq|,
		taxnumber = '$form->{"taxnumber_$item"}'
		WHERE chart_id = $item|;
    $dbh->do($query) || $form->dberror($query);
  }

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

sub backup {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $userspath) = @_;

  my $mail;
  my $err;
  my $boundary = time;
  my $tmpfile  =
    "$userspath/$boundary.$myconfig->{dbname}-$form->{dbversion}.sql";
  my $out = $form->{OUT};
  $form->{OUT} = ">$tmpfile";

  if ($form->{media} eq 'email') {

    use SL::Mailer;
    $mail = new Mailer;

    $mail->{to}      = qq|"$myconfig->{name}" <$myconfig->{email}>|;
    $mail->{from}    = qq|"$myconfig->{name}" <$myconfig->{email}>|;
    $mail->{subject} =
      "Lx-Office Backup / $myconfig->{dbname}-$form->{dbversion}.sql";
    @{ $mail->{attachments} } = ($tmpfile);
    $mail->{version} = $form->{version};
    $mail->{fileid}  = "$boundary.";

    $myconfig->{signature} =~ s/\\n/\r\n/g;
    $mail->{message} = "--\n$myconfig->{signature}";

  }

  open(OUT, "$form->{OUT}") or $form->error("$form->{OUT} : $!");

  # get sequences, functions and triggers
  open(FH, "sql/lx-office.sql") or $form->error("sql/lx-office.sql : $!");

  my @sequences = ();
  my @functions = ();
  my @triggers  = ();
  my @indices   = ();
  my %tablespecs;

  my $query = "";
  my @quote_chars;

  while (<FH>) {

    # Remove DOS and Unix style line endings.
    s/[\r\n]//g;

    # ignore comments or empty lines
    next if /^(--.*|\s+)$/;

    for (my $i = 0; $i < length($_); $i++) {
      my $char = substr($_, $i, 1);

      # Are we inside a string?
      if (@quote_chars) {
        if ($char eq $quote_chars[-1]) {
          pop(@quote_chars);
        }
        $query .= $char;

      } else {
        if (($char eq "'") || ($char eq "\"")) {
          push(@quote_chars, $char);

        } elsif ($char eq ";") {

          # Query is complete. Check for triggers and functions.
          if ($query =~ /^create\s+function\s+\"?(\w+)\"?/i) {
            push(@functions, $query);

          } elsif ($query =~ /^create\s+trigger\s+\"?(\w+)\"?/i) {
            push(@triggers, $query);

          } elsif ($query =~ /^create\s+sequence\s+\"?(\w+)\"?/i) {
            push(@sequences, $1);

          } elsif ($query =~ /^create\s+table\s+\"?(\w+)\"?/i) {
            $tablespecs{$1} = $query;

          } elsif ($query =~ /^create\s+index\s+\"?(\w+)\"?/i) {
            push(@indices, $query);

          }

          $query = "";
          $char  = "";
        }

        $query .= $char;
      }
    }
  }
  close(FH);

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  # get all the tables
  my @tables = $dbh->tables('', '', 'customer', '', { noprefix => 0 });

  my $today = scalar localtime;

  $myconfig->{dbhost} = 'localhost' unless $myconfig->{dbhost};

  print OUT qq|-- Lx-Office Backup
-- Dataset: $myconfig->{dbname}
-- Version: $form->{dbversion}
-- Host: $myconfig->{dbhost}
-- Login: $form->{login}
-- User: $myconfig->{name}
-- Date: $today
--
-- set options
$myconfig->{dboptions};
--
|;

  print OUT "-- DROP Sequences\n";
  my $item;
  foreach $item (@sequences) {
    print OUT qq|DROP SEQUENCE $item;\n|;
  }

  print OUT "-- DROP Triggers\n";

  foreach $item (@triggers) {
    if ($item =~ /^create\s+trigger\s+\"?(\w+)\"?\s+.*on\s+\"?(\w+)\"?\s+/i) {
      print OUT qq|DROP TRIGGER "$1" ON "$2";\n|;
    }
  }

  print OUT "-- DROP Functions\n";

  foreach $item (@functions) {
    if ($item =~ /^create\s+function\s+\"?(\w+)\"?/i) {
      print OUT qq|DROP FUNCTION "$1" ();\n|;
    }
  }

  foreach $table (@tables) {
    if (!($table =~ /^sql_.*/)) {
      my $query = qq|SELECT * FROM $table|;

      my $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);

      $query = "INSERT INTO $table (";
      map { $query .= qq|$sth->{NAME}->[$_],| }
        (0 .. $sth->{NUM_OF_FIELDS} - 1);
      chop $query;

      $query .= ") VALUES";

      if ($tablespecs{$table}) {
        print(OUT "--\n");
        print(OUT "DROP TABLE $table;\n");
        print(OUT $tablespecs{$table}, ";\n");
      } else {
        print(OUT "--\n");
        print(OUT "DELETE FROM $table;\n");
      }
      while (my @arr = $sth->fetchrow_array) {

        $fields = "(";
        foreach my $item (@arr) {
          if (defined $item) {
            $item =~ s/\'/\'\'/g;
            $fields .= qq|'$item',|;
          } else {
            $fields .= 'NULL,';
          }
        }

        chop $fields;
        $fields .= ")";

        print OUT qq|$query $fields;\n|;
      }

      $sth->finish;
    }
  }

  # create indices, sequences, functions and triggers

  print(OUT "-- CREATE Indices\n");
  map({ print(OUT "$_;\n"); } @indices);

  print OUT "-- CREATE Sequences\n";
  foreach $item (@sequences) {
    $query = qq|SELECT last_value FROM $item|;
    $sth   = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    my ($id) = $sth->fetchrow_array;
    $sth->finish;

    print OUT qq|--
CREATE SEQUENCE $item START $id;
|;
  }

  print OUT "-- CREATE Functions\n";

  # functions
  map { print(OUT $_, ";\n"); } @functions;

  print OUT "-- CREATE Triggers\n";

  # triggers
  map { print(OUT $_, ";\n"); } @triggers;

  close(OUT);

  $dbh->disconnect;

  # compress backup
  my @args = ("gzip", "$tmpfile");
  system(@args) == 0 or $form->error("$args[0] : $?");

  $tmpfile .= ".gz";

  if ($form->{media} eq 'email') {
    @{ $mail->{attachments} } = ($tmpfile);
    $err = $mail->send($out);
  }

  if ($form->{media} eq 'file') {

    open(IN,  "$tmpfile") or $form->error("$tmpfile : $!");
    open(OUT, ">-")       or $form->error("STDOUT : $!");

    print OUT qq|Content-Type: application/x-tar-gzip;
Content-Disposition: attachment; filename="$myconfig->{dbname}-$form->{dbversion}.sql.gz"

|;

    while (<IN>) {
      print OUT $_;
    }

    close(IN);
    close(OUT);

  }

  unlink "$tmpfile";

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

  if ($form->{revtrans}) {

    $query = qq|UPDATE defaults SET closedto = NULL,
				    revtrans = '1'|;
  } else {
    if ($form->{closedto}) {

      $query = qq|UPDATE defaults SET closedto = '$form->{closedto}',
				      revtrans = '0'|;
    } else {

      $query = qq|UPDATE defaults SET closedto = NULL,
				      revtrans = '0'|;
    }
  }

  # set close in defaults
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

1;
