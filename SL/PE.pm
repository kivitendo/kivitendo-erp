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
# Project module
# also used for partsgroups
#
#======================================================================

package PE;

use Data::Dumper;

use SL::DBUtils;

sub projects {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my ($where, @values);

  foreach my $column (qw(projectnumber description)) {
    if ($form->{$column}) {
      $where .= qq|AND $column ILIKE ? |;
      push(@values, '%' . $form->{$column} . '%');
    }
  }

  if ($form->{status} eq 'orphaned') {
    my %col_prefix = ("ar" => "global", "ap" => "global", "oe" => "global");
    my $first = 1;

    $where .= qq|AND id NOT IN (|;
    foreach my $table (qw(acc_trans invoice orderitems rmaitems ar ap oe)) {
      $where .= "UNION " unless ($first);
      $first = 0;
      $where .=
        qq|SELECT DISTINCT $col_prefix{$table}project_id FROM $table | .
        qq|WHERE NOT $col_prefix{$table}project_id ISNULL |;
    }
    $where .= qq|) |;
  }

  if ($form->{active} eq "active") {
    $where .= qq|AND active |;
  } elsif ($form->{active} eq "inactive") {
    $where .= qq|AND NOT active |;
  }

  substr($where, 0, 4) = "WHERE " if ($where);

  my $sortorder = $form->{sort} ? $form->{sort} : "projectnumber";
  $sortorder =~ s/[^a-z_]//g;
  my $query =
    qq|SELECT id, projectnumber, description, active | .
    qq|FROM project | .
    $where .
    qq|ORDER BY $sortorder|;

  $main::lxdebug->message(1, $query);

  $form->{project_list} =
    selectall_hashref_query($form, $dbh, $query, @values);
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return scalar(@{ $form->{project_list} });
}

sub get_project {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query =
    qq|SELECT * FROM project | .
    qq|WHERE id = ?|;
	my @values = ($form->{id});
  my $sth = $dbh->prepare($query);
  $sth->execute(@values) || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);

  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;

  # check if it is orphaned
  my %col_prefix = ("ar" => "global", "ap" => "global", "oe" => "global");
  @values = ();
  $query = qq|SELECT |;
  my $first = 1;
  foreach my $table (qw(acc_trans invoice orderitems rmaitems ar ap oe)) {
    $query .= " + " unless ($first);
    $first = 0;
    $query .=
      qq|(SELECT COUNT(*) FROM $table | .
      qq| WHERE $col_prefix{$table}project_id = ?) |;
    push(@values, $form->{id});
  }

  ($form->{orphaned}) = selectrow_query($form, $dbh, $query, @values);
  $form->{orphaned} = !$form->{orphaned};

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub save_project {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my @values = ($form->{projectnumber}, $form->{description});

  if ($form->{id}) {
    $query =
      qq|UPDATE project SET projectnumber = ?, description = ?, active = ? | .
      qq|WHERE id = ?|;
    push(@values, ($form->{active} ? 't' : 'f'), $form->{id});
  } else {
    $query =
      qq|INSERT INTO project (projectnumber, description, active) | .
      qq|VALUES (?, ?, 't')|;
  }
  do_query($form, $dbh, $query, @values);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub partsgroups {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my ($where, @values);

  if ($form->{partsgroup}) {
    $where .= qq| AND partsgroup ILIKE ?|;
    push(@values, '%' . $form->{partsgroup} . '%');
  }

  if ($form->{status} eq 'orphaned') {
    $where .=
      qq| AND id NOT IN | .
      qq|  (SELECT DISTINCT partsgroup_id FROM parts | .
      qq|   WHERE NOT partsgroup_id ISNULL) |;
  }

  substr($where, 0, 4) = "WHERE " if ($where);

  my $sortorder = $form->{sort} ? $form->{sort} : "partsgroup";
  $sortorder =~ s/[^a-z_]//g;

  my $query =
    qq|SELECT id, partsgroup FROM partsgroup | .
    $where .
    qq|ORDER BY $sortorder|;

  $form->{item_list} = selectall_hashref_query($form, $dbh, $query, @values);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return scalar(@{ $form->{item_list} });
}

sub save_partsgroup {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $form->{discount} /= 100;

  my @values = ($form->{partsgroup});

  if ($form->{id}) {
    $query = qq|UPDATE partsgroup SET partsgroup = ? WHERE id = ?|;
		push(@values, $form->{id});
  } else {
    $query = qq|INSERT INTO partsgroup (partsgroup) VALUES (?)|;
  }
  do_query($form, $dbh, $query, @values);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_partsgroup {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query =
    qq|SELECT pg.*, | .
    qq|(SELECT COUNT(*) FROM parts WHERE partsgroup_id = ?) = 0 AS orphaned | .
    qq|FROM partsgroup pg | .
    qq|WHERE pg.id = ?|;
  my $sth = prepare_execute_query($form, $dbh, $query, $form->{id},
                                  $form->{id});
  my $ref = $sth->fetchrow_hashref(NAME_lc);

  map({ $form->{$_} = $ref->{$_} } keys(%{$ref}));
  $sth->finish;

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub delete_tuple {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $table =
    $form->{type} eq "project" ? "project" :
    $form->{type} eq "pricegroup" ? "pricegroup" :
    "partsgroup";

  $query = qq|DELETE FROM $table WHERE id = ?|;
  do_query($form, $dbh, $query, $form->{id});

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

##########################
# get pricegroups from database
#
sub pricegroups {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my ($where, @values);

  if ($form->{pricegroup}) {
    $where .= qq| AND pricegroup ILIKE ?|;
    push(@values, '%' . $form->{pricegroup} . '%');
  }

  if ($form->{status} eq 'orphaned') {
    my $first = 1;

    $where .= qq| AND id NOT IN (|;
    foreach my $table (qw(invoice orderitems prices rmaitems)) {
      $where .= "UNION " unless ($first);
      $first = 0;
      $where .=
        qq|SELECT DISTINCT pricegroup_id FROM $table | .
        qq|WHERE NOT pricegroup_id ISNULL |;
    }
    $where .= qq|) |;
  }

  substr($where, 0, 4) = "WHERE " if ($where);

  my $sortorder = $form->{sort} ? $form->{sort} : "pricegroup";
  $sortorder =~ s/[^a-z_]//g;

  my $query =
    qq|SELECT id, pricegroup FROM pricegroup | .
    $where .
    qq|ORDER BY $sortorder|;

  $form->{item_list} = selectall_hashref_query($form, $dbh, $query, @values);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return scalar(@{ $form->{item_list} });
}

########################
# save pricegruop to database
#
sub save_pricegroup {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  my $query;

  $form->{discount} /= 100;

  my @values = ($form->{pricegroup});

  if ($form->{id}) {
    $query = qq|UPDATE pricegroup SET pricegroup = ? WHERE id = ? |;
		push(@values, $form->{id});
  } else {
    $query = qq|INSERT INTO pricegroup (pricegroup) VALUES (?)|;
  }
  do_query($form, $dbh, $query, @values);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

############################
# get one pricegroup from database
#
sub get_pricegroup {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT id, pricegroup FROM pricegroup WHERE id = ?|;
  my $sth = prepare_execute_query($form, $dbh, $query, $form->{id});
  my $ref = $sth->fetchrow_hashref(NAME_lc);

  map({ $form->{$_} = $ref->{$_} } keys(%{$ref}));

  $sth->finish;

  my $first = 1;

  my @values = ();
  $query = qq|SELECT |;
  foreach my $table (qw(invoice orderitems prices rmaitems)) {
    $query .= " + " unless ($first);
    $first = 0;
    $query .= qq|(SELECT COUNT(*) FROM $table WHERE pricegroup_id = ?) |;
    push(@values, $form->{id});
  }

  ($form->{orphaned}) = selectrow_query($form, $dbh, $query, @values);
  $form->{orphaned} = !$form->{orphaned};

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

1;

