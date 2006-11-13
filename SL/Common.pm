#====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#====================================================================

package Common;

sub retrieve_parts {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $order_by, $order_dir) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my (@filter_values, $filter);
  if ($form->{"partnumber"}) {
    $filter .= " AND (partnumber ILIKE ?)";
    push(@filter_values, '%' . $form->{"partnumber"} . '%');
  }
  if ($form->{"description"}) {
    $filter .= " AND (description ILIKE ?)";
    push(@filter_values, '%' . $form->{"description"} . '%');
  }
  substr($filter, 1, 3) = "WHERE" if ($filter);

  $order_by =~ s/[^a-zA-Z_]//g;
  $order_dir = $order_dir ? "ASC" : "DESC";

  my $query = "SELECT id, partnumber, description FROM parts $filter ORDER BY $order_by $order_dir";
  my $sth = $dbh->prepare($query);
  $sth->execute(@filter_values) || $form->dberror($query . " (" . join(", ", @filter_values) . ")");
  my $parts = [];
  while (my $ref = $sth->fetchrow_hashref()) {
    push(@{$parts}, $ref);
  }
  $sth->finish();
  $dbh->disconnect();

  $main::lxdebug->leave_sub();

  return $parts;
}

sub retrieve_projects {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $order_by, $order_dir) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my (@filter_values, $filter);
  if ($form->{"projectnumber"}) {
    $filter .= " AND (projectnumber ILIKE ?)";
    push(@filter_values, '%' . $form->{"projectnumber"} . '%');
  }
  if ($form->{"description"}) {
    $filter .= " AND (description ILIKE ?)";
    push(@filter_values, '%' . $form->{"description"} . '%');
  }
  substr($filter, 1, 3) = "WHERE" if ($filter);

  $order_by =~ s/[^a-zA-Z_]//g;
  $order_dir = $order_dir ? "ASC" : "DESC";

  my $query = "SELECT id, projectnumber, description FROM project $filter ORDER BY $order_by $order_dir";
  my $sth = $dbh->prepare($query);
  $sth->execute(@filter_values) || $form->dberror($query . " (" . join(", ", @filter_values) . ")");
  my $projects = [];
  while (my $ref = $sth->fetchrow_hashref()) {
    push(@{$projects}, $ref);
  }
  $sth->finish();
  $dbh->disconnect();

  $main::lxdebug->leave_sub();

  return $projects;
}

sub retrieve_employees {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $order_by, $order_dir) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my (@filter_values, $filter);
  if ($form->{"name"}) {
    $filter .= " AND (name ILIKE ?)";
    push(@filter_values, '%' . $form->{"name"} . '%');
  }
  substr($filter, 1, 3) = "WHERE" if ($filter);

  $order_by =~ s/[^a-zA-Z_]//g;
  $order_dir = $order_dir ? "ASC" : "DESC";

  my $query = "SELECT id, name FROM employee $filter ORDER BY $order_by $order_dir";
  my $sth = $dbh->prepare($query);
  $sth->execute(@filter_values) || $form->dberror($query . " (" . join(", ", @filter_values) . ")");
  my $employees = [];
  while (my $ref = $sth->fetchrow_hashref()) {
    push(@{$employees}, $ref);
  }
  $sth->finish();
  $dbh->disconnect();

  $main::lxdebug->leave_sub();

  return $employees;
}

sub retrieve_delivery_customer {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $order_by, $order_dir) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my (@filter_values, $filter);
  if ($form->{"name"}) {
    $filter .= " (name ILIKE '%$form->{name}%') AND";
    push(@filter_values, '%' . $form->{"name"} . '%');
  }
  #substr($filter, 1, 3) = "WHERE" if ($filter);

  $order_by =~ s/[^a-zA-Z_]//g;
  $order_dir = $order_dir ? "ASC" : "DESC";

  my $query = "SELECT id, name, customernumber, (street || ', ' || zipcode || city) as address FROM customer WHERE $filter business_id=(SELECT id from business WHERE description='Endkunde') ORDER BY $order_by $order_dir";
  my $sth = $dbh->prepare($query);
  $sth->execute() || $form->dberror($query . " (" . join(", ", @filter_values) . ")");
  my $delivery_customers = [];
  while (my $ref = $sth->fetchrow_hashref()) {
    push(@{$delivery_customers}, $ref);
  }
  $sth->finish();
  $dbh->disconnect();

  $main::lxdebug->leave_sub();

  return $delivery_customers;
}

sub retrieve_vendor {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $order_by, $order_dir) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my (@filter_values, $filter);
  if ($form->{"name"}) {
    $filter .= " (name ILIKE '%$form->{name}%') AND";
    push(@filter_values, '%' . $form->{"name"} . '%');
  }
  #substr($filter, 1, 3) = "WHERE" if ($filter);

  $order_by =~ s/[^a-zA-Z_]//g;
  $order_dir = $order_dir ? "ASC" : "DESC";

  my $query = "SELECT id, name, customernumber, (street || ', ' || zipcode || city) as address FROM customer WHERE $filter business_id=(SELECT id from business WHERE description='Händler') ORDER BY $order_by $order_dir";
  my $sth = $dbh->prepare($query);
  $sth->execute() || $form->dberror($query . " (" . join(", ", @filter_values) . ")");
  my $vendors = [];
  while (my $ref = $sth->fetchrow_hashref()) {
    push(@{$vendors}, $ref);
  }
  $sth->finish();
  $dbh->disconnect();

  $main::lxdebug->leave_sub();

  return $vendors;
}

1;
