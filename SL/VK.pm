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
    qq|SELECT ct.id as customerid, ct.name as customername,ct.customernumber,ct.country,ar.invnumber,ar.id,ar.transdate,p.partnumber,pg.partsgroup,i.parts_id,i.qty,i.price_factor,i.discount,i.description as description,i.lastcost,i.sellprice,i.marge_total,i.marge_percent,i.unit,b.description as business,e.name as employee,e2.name as salesman, to_char(ar.transdate,'Month') as month | .
    qq|FROM invoice i | .  
    qq|JOIN ar on (i.trans_id = ar.id) | .
    qq|JOIN parts p on (i.parts_id = p.id) | .
    qq|LEFT JOIN partsgroup pg on (p.partsgroup_id = pg.id) | .
    qq|LEFT JOIN customer ct on (ct.id = ar.customer_id) | .
    qq|LEFT JOIN business b on (ct.business_id = b.id) | .
    qq|LEFT JOIN employee e ON (ar.employee_id = e.id) | .
    qq|LEFT JOIN employee e2 ON (ar.salesman_id = e2.id) |;

  my $where = "1 = 1";

  # if employee can only see his own invoices, make sure this also holds for sales report
  # limits by employees (Bearbeiter), not salesmen!
  if (!$main::auth->assert('sales_all_edit', 1)) {
    $where .= " AND ar.employee_id = (select id from employee where login= ?)";
    push (@values, $form->{login});
  }

  # Stornierte Rechnungen und Stornorechnungen in invoice rausfiltern
  # was ist mit Gutschriften?
  $where .= " AND ar.storno is not true ";

  # Bestandteile von Erzeugnissen herausfiltern
  $where .= " AND i.assemblyitem is not true ";

  my $sortorder;
  # sorting by month is a special case:
  # Sorting by month, using salesman as an example:
  # Sorting with month as mainsort: ORDER BY month,salesman,ar.transdate,ar.invnumber
  # Sorting with month as subsort:  ORDER BY salesman,ar.transdate,month,ar.invnumber
  if ($form->{mainsort} eq 'month') {
    $sortorder .= "ar.transdate,month,"
  } else {
    $sortorder .= $form->{mainsort} . ",";
  };
  if ($form->{subsort} eq 'month') {
    $sortorder .= "ar.transdate,month,"
  } else {
    $sortorder .= $form->{subsort} . ",";
  };
  $sortorder .= 'ar.transdate,' unless $form->{subsort} eq 'month';
  $sortorder .= 'ar.invnumber';

#  $sortorder =~ s/month/ar.transdate/;

  if ($form->{customer_id}) {
    $where .= " AND ar.customer_id = ?";
    push(@values, $form->{customer_id});
  };
  if ($form->{customernumber}) {
    $where .= qq| AND ct.customernumber = ? |;
    push(@values, $form->{customernumber});
  }
  if ($form->{partnumber}) {
    $where .= qq| AND (p.partnumber ILIKE ?)|;
    push(@values, '%' . $form->{partnumber} . '%');
  }
  if ($form->{partsgroup_id}) {
    $where .= qq| AND (pg.id = ?)|;
    push(@values, $form->{partsgroup_id});
  }
  if ($form->{country}) {
    $where .= qq| AND (ct.country ILIKE ?)|;
    push(@values, '%' . $form->{country} . '%');
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
  if ($form->{employee_id}) {
    $where .= " AND ar.employee_id = ?";
    push @values, conv_i($form->{employee_id});
  }

  if ($form->{salesman_id}) {
    $where .= " AND ar.salesman_id = ?";
    push @values, conv_i($form->{salesman_id});
  }
  if ($form->{project_id}) {
    $where .=
      qq|AND ((ar.globalproject_id = ?) OR EXISTS | .
      qq|  (SELECT * FROM invoice i | .
      qq|   WHERE i.project_id = ? AND i.trans_id = ar.id))|;
    push(@values, $form->{"project_id"}, $form->{"project_id"});
  }
  if ($form->{business_id}) {
    $where .= qq| AND ct.business_id = ? |; 
    push(@values, $form->{"business_id"});
  }

  my ($cvar_where_ct, @cvar_values_ct) = CVar->build_filter_query('module'    => 'CT',
                                                                  'trans_id_field' => 'ct.id',
                                                                  'filter'         => $form);

  if ($cvar_where_ct) {
    $where .= qq| AND ($cvar_where_ct)|;
    push @values, @cvar_values_ct;
  }


  my ($cvar_where_ic, @cvar_values_ic) = CVar->build_filter_query('module'         => 'IC',
                                                                  'trans_id_field' => 'p.id',
                                                                  'filter'         => $form);

  if ($cvar_where_ic) {
    $where .= qq| AND ($cvar_where_ic)|;
    push @values, @cvar_values_ic;
  }
  
  $query .= " WHERE $where ORDER BY $sortorder "; # LIMIT 5000";

  my @result = selectall_hashref_query($form, $dbh, $query, @values);

  $form->{AR} = [ @result ];

  $main::lxdebug->leave_sub();
}

1;

