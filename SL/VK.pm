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
# Sold Items report
#
#======================================================================

package VK;

use SL::DBUtils;
use SL::IO;
use SL::MoreCommon;

use strict;

sub invoice_transactions {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->get_standard_dbh($myconfig);

  my @values;

  my $query =
    qq|SELECT cus.name,ar.invnumber,ar.id,ar.transdate,p.partnumber,i.parts_id,i.qty,i.price_factor,i.discount,i.description,i.lastcost,i.sellprice,i.marge_total,i.marge_percent,i.unit | .
    qq|FROM invoice i | .  
    qq|join ar on (i.trans_id = ar.id) | .
    qq|join parts p on (i.parts_id = p.id) | .
    qq|join customer cus on (cus.id = ar.customer_id) |;

  my $where = "1 = 1";

  # Stornierte Rechnungen und Stornorechnungen in invoice rausfiltern
  $where .= " AND ar.storno is not true ";

  my $sortorder = "cus.name,i.parts_id,ar.transdate";
  if ($form->{sortby} eq 'artikelsort') {
    $sortorder = "i.parts_id,cus.name,ar.transdate";
  };

  if ($form->{customer_id}) {
    $where .= " AND ar.customer_id = ?";
    push(@values, $form->{customer_id});
  };
  if ($form->{partnumber}) {
    $where .= qq| AND (p.partnumber ILIKE ?)|;
    push(@values, '%' . $form->{partnumber} . '%');
  }
  # nimmt man description am Besten aus invoice oder parts?
  if ($form->{description}) {
    $where .= qq| AND (i.description ILIKE ?)|;
    push(@values, '%' . $form->{description} . '%');
  }
  if ($form->{transdatefrom}) {
    $where .= " AND ar.transdate >= ?";
    push(@values, $form->{transdatefrom});
  }
  if ($form->{transdateto}) {
    $where .= " AND ar.transdate <= ?";
    push(@values, $form->{transdateto});
  }
  if ($form->{department}) {
    my ($null, $department_id) = split /--/, $form->{department};
    $where .= " AND ar.department_id = ?";
    push(@values, $department_id);
  }
  if ($form->{project_id}) {
    $where .=
      qq|AND ((ar.globalproject_id = ?) OR EXISTS | .
      qq|  (SELECT * FROM invoice i | .
      qq|   WHERE i.project_id = ? AND i.trans_id = ar.id))|;
    push(@values, $form->{"project_id"}, $form->{"project_id"});
  }

  $query .= " WHERE $where ORDER BY $sortorder";

  my @result = selectall_hashref_query($form, $dbh, $query, @values);

  $form->{AR} = [ @result ];

  $main::lxdebug->leave_sub();
}

1;

