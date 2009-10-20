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
#
#======================================================================

package Projects;

use Data::Dumper;

use SL::DBUtils;
use SL::CVar;

use strict;

my %project_id_column_prefixes  = ("ar"              => "global",
                                   "ap"              => "global",
                                   "oe"              => "global",
                                   "delivery_orders" => "global");

my @tables_with_project_id_cols = qw(acc_trans
                                     invoice
                                     orderitems
                                     rmaitems
                                     ar
                                     ap
                                     oe
                                     delivery_orders
                                     delivery_order_items);

sub search_projects {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

  my (@filters, @values);

  foreach my $column (qw(projectnumber description)) {
    if ($params{$column}) {
      push @filters, "p.$column ILIKE ?";
      push @values, '%' . $params{$column} . '%';
    }
  }

  if ($params{status} eq 'orphaned') {
    my @sub_filters;

    foreach my $table (@tables_with_project_id_cols) {
      push @sub_filters, qq|SELECT DISTINCT $project_id_column_prefixes{$table}project_id FROM $table
                            WHERE NOT $project_id_column_prefixes{$table}project_id ISNULL|;
    }

    push @filters, "p.id NOT IN (" . join(" UNION ", @sub_filters) . ")";
  }

  if ($params{active} eq "active") {
    push @filters, 'p.active';

  } elsif ($params{active} eq "inactive") {
    push @filters, 'NOT COALESCE(p.active, FALSE)';
  }

  my ($cvar_where, @cvar_values) = CVar->build_filter_query('module'         => 'Projects',
                                                            'trans_id_field' => 'p.id',
                                                            'filter'         => $form);

  if ($cvar_where) {
    push @filters, $cvar_where;
    push @values,  @cvar_values;
  }


  my $where = 'WHERE ' . join(' AND ', map { "($_)" } @filters) if (scalar @filters);

  my $sortorder =  $params{sort} ? $params{sort} : "projectnumber";
  $sortorder    =~ s/[^a-z_]//g;
  my $query     = qq|SELECT p.id, p.projectnumber, p.description, p.active
                     FROM project p
                     $where
                     ORDER BY $sortorder|;

  $form->{project_list} = selectall_hashref_query($form, $dbh, $query, @values);

  $main::lxdebug->leave_sub();

  return scalar(@{ $form->{project_list} });
}

sub get_project {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  if (!$params{id}) {
    $main::lxdebug->leave_sub();
    return { };
  }

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

  my $project  = selectfirst_hashref_query($form, $dbh, qq|SELECT * FROM project WHERE id = ?|, conv_i($params{id})) || { };

  if ($params{orphaned}) {
    # check if it is orphaned
    my (@values, $query);

    foreach my $table (@tables_with_project_id_cols) {
      $query .= " + " if ($query);
      $query .= qq|(SELECT COUNT(*) FROM $table
                    WHERE $project_id_column_prefixes{$table}project_id = ?) |;
      push @values, conv_i($params{id});
    }

    $query = 'SELECT ' . $query;

    ($project->{orphaned}) = selectrow_query($form, $dbh, $query, @values);
    $project->{orphaned}   = !$project->{orphaned};
  }

  $main::lxdebug->leave_sub();

  return $project;
}

sub save_project {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

  my @values;

  if (!$params{id}) {
    ($params{id}) = selectfirst_array_query($form, $dbh, qq|SELECT nextval('id')|);
    do_query($form, $dbh, qq|INSERT INTO project (id) VALUES (?)|, conv_i($params{id}));

    $params{active} = 1;
  }

  my $query  = qq|UPDATE project SET projectnumber = ?, description = ?, active = ?
               WHERE id = ?|;

  @values = ($params{projectnumber}, $params{description}, $params{active} ? 't' : 'f', conv_i($params{id}));
  do_query($form, $dbh, $query, @values);

  CVar->save_custom_variables('dbh'       => $dbh,
                              'module'    => 'Projects',
                              'trans_id'  => $params{id},
                              'variables' => $form);

  $dbh->commit();

  $main::lxdebug->leave_sub();

  return $params{id};
}

sub delete_project {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(id));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

  do_query($form, $dbh, qq|DELETE FROM project WHERE id = ?|, conv_i($params{id}));

  $dbh->commit();

  $main::lxdebug->leave_sub();
}

1;

