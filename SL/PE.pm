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

  my $sortorder = ($form->{sort}) ? $form->{sort} : "projectnumber";

  my $query = qq|SELECT p.id, p.projectnumber, p.description, p.active
                 FROM project p
		 WHERE 1 = 1|;

  if ($form->{projectnumber}) {
    my $projectnumber = $form->like(lc $form->{projectnumber});
    $query .= " AND lower(projectnumber) LIKE '$projectnumber'";
  }
  if ($form->{projectdescription}) {
    my $description = $form->like(lc $form->{projectdescription});
    $query .= " AND lower(description) LIKE '$description'";
  }
  if ($form->{status} eq 'orphaned') {
    $query .= " AND id NOT IN (SELECT p.id
                               FROM project p, acc_trans a
			       WHERE p.id = a.project_id)
                AND id NOT IN (SELECT p.id
		               FROM project p, invoice i
			       WHERE p.id = i.project_id)
		AND id NOT IN (SELECT p.id
		               FROM project p, orderitems o
			       WHERE p.id = o.project_id)";
  }
  if ($form->{active} eq "active") {
    $query .= " AND p.active";
  } elsif ($form->{active} eq "inactive") {
    $query .= " AND NOT p.active";
  }

  $query .= qq|
		 ORDER BY $sortorder|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $i = 0;
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{project_list} }, $ref;
    $i++;
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $i;
}

sub get_project {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT p.*
                 FROM project p
	         WHERE p.id = $form->{id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);

  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;

  # check if it is orphaned
  $query = qq|SELECT count(*)
              FROM acc_trans a
	      WHERE a.project_id = $form->{id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  ($form->{orphaned}) = $sth->fetchrow_array;
  $form->{orphaned} = !$form->{orphaned};

  $sth->finish;

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
    push(@values, $form->{active} ? 't' : 'f', $form->{id});
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

  my $var;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $sortorder = ($form->{sort}) ? $form->{sort} : "partsgroup";

  my $query = qq|SELECT g.*
                 FROM partsgroup g|;

  my $where = "1 = 1";

  if ($form->{partsgroup}) {
    $var = $form->like(lc $form->{partsgroup});
    $where .= " AND lower(g.partsgroup) LIKE '$var'";
  }
  $query .= qq|
               WHERE $where
	       ORDER BY $sortorder|;

  if ($form->{status} eq 'orphaned') {
    $query = qq|SELECT g.*
                FROM partsgroup g
                LEFT JOIN parts p ON (p.partsgroup_id = g.id)
		WHERE $where
                EXCEPT
                SELECT g.*
	        FROM partsgroup g
	        JOIN parts p ON (p.partsgroup_id = g.id)
	        WHERE $where
		ORDER BY $sortorder|;
  }

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $i = 0;
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{item_list} }, $ref;
    $i++;
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $i;
}

sub save_partsgroup {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  map { $form->{$_} =~ s/\'/\'\'/g } qw(partsgroup);
  $form->{discount} /= 100;

  if ($form->{id}) {
    $query = qq|UPDATE partsgroup SET
                partsgroup = '$form->{partsgroup}'
		WHERE id = $form->{id}|;
  } else {
    $query = qq|INSERT INTO partsgroup
                (partsgroup)
                VALUES ('$form->{partsgroup}')|;
  }
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_partsgroup {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT p.*
                 FROM partsgroup p
	         WHERE p.id = $form->{id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);

  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;

  # check if it is orphaned
  $query = qq|SELECT count(*)
              FROM parts p
	      WHERE p.partsgroup_id = $form->{id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  ($form->{orphaned}) = $sth->fetchrow_array;
  $form->{orphaned} = !$form->{orphaned};

  $sth->finish;

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub delete_tuple {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $query = qq|DELETE FROM $form->{type}
	      WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

##########################
# get pricegroups from database
#
sub pricegroups {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $var;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $sortorder = ($form->{sort}) ? $form->{sort} : "pricegroup";

  my $query = qq|SELECT g.id, g.pricegroup
                 FROM pricegroup g|;

  my $where = "1 = 1";

  if ($form->{pricegroup}) {
    $var = $form->like(lc $form->{pricegroup});
    $where .= " AND lower(g.pricegroup) LIKE '$var'";
  }
  $query .= qq|
               WHERE $where
	       ORDER BY $sortorder|;

  if ($form->{status} eq 'orphaned') {
    $query = qq|SELECT pg.*
                FROM pricegroup pg
                LEFT JOIN prices p ON (p.pricegroup_id = pg.id)
		WHERE $where
                EXCEPT
                SELECT pg.*
	        FROM pricegroup pg
	        JOIN prices p ON (p.pricegroup_id = pg.id)
	        WHERE $where
		ORDER BY $sortorder|;
  }

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $i = 0;
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{item_list} }, $ref;
    $i++;
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $i;
}
########################
# save pricegruop to database
#
sub save_pricegroup {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  map { $form->{$_} =~ s/\'/\'\'/g } qw(pricegroup);

  $form->{discount} /= 100;

  if ($form->{id}) {
    $query = qq|UPDATE pricegroup SET
                pricegroup = '$form->{pricegroup}'
		WHERE id = $form->{id}|;
  } else {
    $query = qq|INSERT INTO pricegroup
                (pricegroup)
                VALUES ('$form->{pricegroup}')|;
  }
  $dbh->do($query) || $form->dberror($query);

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

  my $query = qq|SELECT p.id, p.pricegroup
                 FROM pricegroup p
	         WHERE p.id = $form->{id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);

  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;

  # check if it is orphaned
  $query = qq|SELECT count(*)
              FROM prices p
	      WHERE p.pricegroup_id = $form->{id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  ($form->{orphaned}) = $sth->fetchrow_array;
  $form->{orphaned} = !$form->{orphaned};

  $sth->finish;

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

1;

