#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (c) 2002
#
#  Author: Philip Reetz
#   Email: p.reetz@linet-services.de
#     Web: http://www.linet-services.de/
#
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
# Software license module
# Backend routines
#======================================================================

package LICENSES;

use SL::Form;

sub save_license {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  $dbh = $form->dbconnect($myconfig);

  $query =
    qq| INSERT INTO license (licensenumber) VALUES ('$form->{licensenumber}')|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  $sth->finish();

  $query =
    qq|SELECT l.id FROM license l WHERE l.licensenumber = '$form->{licensenumber}'|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  ($license_id) = $sth->fetchrow_array;
  $sth->finish();

  # save license
  $query = qq|UPDATE license SET
              validuntil = '$form->{validuntil}',
              licensenumber = '$form->{licensenumber}',
              parts_id = $form->{parts_id},
              customer_id = $form->{customer_id},
              comment = '$form->{comment}',
              quantity = $form->{quantity}
              WHERE id=$license_id|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  $sth->finish();

  if ($form->{own_product}) {
    $form->update_balance($dbh, "parts", "onhand", qq|id = ?|,
                          1, $form->{parts_id});
  }

  $dbh->disconnect();

  $main::lxdebug->leave_sub();

  return $license_id;
}

sub get_customers {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $ref;
  my $dbh = $form->dbconnect($myconfig);

  my $f     = $dbh->quote('%' . $form->{"customer_name"} . '%');
  my $query = qq|SELECT * FROM customer WHERE name ilike $f|;
  my $sth   = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  $form->{"all_customers"} = [];
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push(@{ $form->{"all_customers"} }, $ref);
  }
  $sth->finish();
  $dbh->disconnect();
  $main::lxdebug->leave_sub();
}

sub search {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;
  my ($ref, $sth, $f, $s, $query);
  my $dbh = $form->dbconnect($myconfig);

  if ($form->{"partnumber"} || $form->{"description"}) {
    $f = "(parts_id IN (SELECT id FROM parts WHERE ";
    if ($form->{"partnumber"}) {
      $f .=
        "(partnumber ILIKE "
        . $dbh->quote('%' . $form->{"partnumber"} . '%') . ")";
    }
    if ($form->{"description"}) {
      $f .= " AND " if ($form->{"partnumber"});
      $f .=
        "(description ILIKE "
        . $dbh->quote('%' . $form->{"description"} . '%') . ")";
    }
    $f .= "))";
  }

  if ($form->{"customer_name"}) {
    $f .= " AND " if ($f);
    $f .=
      "(l.customer_id IN (SELECT id FROM customer WHERE name ILIKE "
      . $dbh->quote('%' . $form->{"customer_name"} . '%') . "))";
  }

  if (!$form->{"all"} && $form->{"expiring_in"}) {
    $f .= " AND " if ($f);
    $f .=
      "(validuntil < now() + "
      . $dbh->quote("" . $form->{"expiring_in"} . " months") . ")";
  }

  if (!$form->{"show_expired"}) {
    $f .= " AND " if ($f);
    $f .= "(validuntil >= now())";
  }

  if ($f) {
    $f = "WHERE (inventory_accno_id notnull) AND $f";
  } else {
    $f = "WHERE (inventory_accno_id notnull)";
  }

  if ($form->{"sortby"} eq "partnumber") {
    $s = "p.partnumber";
  } elsif ($form->{"sortby"} eq "description") {
    $s = "p.description";
  } elsif ($form->{"sortby"} eq "name") {
    $s = "c.name";
  } elsif ($form->{"sortby"} eq "validuntil") {
    $s = "l.validuntil";
  } else {
    $s = "l.validuntil";
  }
  if ($form->{"sortasc"}) {
    $s .= " ASC";
  } else {
    $s .= " DESC";
  }

  $query =
      "SELECT l.*, p.partnumber, p.description, c.name, a.invnumber "
    . "FROM license l "
    . "LEFT JOIN parts p ON (p.id = l.parts_id) "
    . "LEFT JOIN customer c ON (c.id = l.customer_id) "
    . "LEFT JOIN ar a ON "
    . "(a.id = (SELECT i.trans_id FROM invoice i WHERE i.id = "
    . "(SELECT li.trans_id FROM licenseinvoice li WHERE li.license_id = l.id))) "
    . "$f ORDER BY $s";

  $sth = $dbh->prepare($query);
  $sth->execute() || $form->dberror($query);
  $form->{"licenses"} = [];
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push(@{ $form->{"licenses"} }, $ref);
  }

  $sth->finish();
  $dbh->disconnect();
  $main::lxdebug->leave_sub();
}

sub get_license {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;
  my ($ref, $sth, $query);
  my $dbh = $form->dbconnect($myconfig);

  $query =
      "SELECT l.*, p.partnumber, p.description, c.name, c.street, "
    . "c.zipcode, c.city, c.country, c.contact, c.phone, c.fax, c.homepage, "
    . "c.email, c.notes, c.customernumber, c.language, a.invnumber "
    . "FROM license l "
    . "LEFT JOIN parts p ON (p.id = l.parts_id) "
    . "LEFT JOIN customer c ON (c.id = l.customer_id) "
    . "LEFT JOIN ar a ON "
    . "(a.id = (SELECT i.trans_id FROM invoice i WHERE i.id = "
    . "(SELECT li.trans_id FROM licenseinvoice li WHERE li.license_id = l.id))) "
    . "LEFT JOIN invoice i ON "
    . "(i.id = "
    . "(SELECT li.trans_id FROM licenseinvoice li WHERE li.license_id = l.id)) "
    . "WHERE l.id = "
    . $form->{"id"};
  $sth = $dbh->prepare($query);
  $sth->execute() || $form->dberror($query);
  $form->{"license"} = $sth->fetchrow_hashref(NAME_lc);
  $sth->finish();
  $dbh->disconnect();
  $main::lxdebug->leave_sub();
}

1;
