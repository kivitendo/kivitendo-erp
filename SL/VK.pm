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

  # default usage: always use parts.description for (sub-)totalling and in header and subheader lines
  # but use invoice.description in article mode
  # so we extract both versions in our query and later overwrite the description in article mode

  my $query =
    qq|SELECT ct.id as customerid, ct.name as customername,ct.customernumber,ct.country,ar.invnumber,ar.shipvia,ar.id,ar.transdate,p.partnumber,p.description as description, pg.partsgroup,i.parts_id,i.qty,i.price_factor,i.discount,i.description as invoice_description,i.lastcost,i.sellprice,i.fxsellprice,i.marge_total,i.marge_percent,i.unit,b.description as business,e.name as employee,e2.name as salesman, to_char(ar.transdate,'Month') as month, to_char(ar.transdate, 'YYYYMM') as nummonth, p.unit as parts_unit, p.weight, ar.taxincluded | .
    qq|, COALESCE(er.buy, 1) | .
    qq|FROM invoice i | .
    qq|RIGHT JOIN ar on (i.trans_id = ar.id) | .
    qq|JOIN parts p on (i.parts_id = p.id) | .
    qq|LEFT JOIN exchangerate er on (er.transdate = ar.transdate and ar.currency_id = er.currency_id) | .
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
    push (@values, $::myconfig{login});
  }

  # Stornierte Rechnungen und Stornorechnungen in invoice rausfiltern
  # was ist mit Gutschriften?
  $where .= " AND ar.storno is not true ";

  # Bestandteile von Erzeugnissen herausfiltern
  $where .= " AND i.assemblyitem is not true ";

  # filter allowed parameters for mainsort and subsort as passed by POST
  my @databasefields = qw(description customername country partsgroup business salesman month shipvia);
  my ($mainsort) = grep { /^$form->{mainsort}$/ } @databasefields;
  my ($subsort) = grep { /^$form->{subsort}$/ } @databasefields;
  die "illegal parameter for mainsort or subsort" unless $mainsort and $subsort;

  my $sortorder;
  # sorting by month is a special case, we don't want to sort alphabetically by
  # month name, so we also extract a numerical month in the from YYYYMM to sort
  # by in case of month sorting
  # Sorting by month, using description as an example:
  # Sorting with month as mainsort: ORDER BY nummonth,description,ar.transdate,ar.invnumber
  # Sorting with month as subsort:  ORDER BY description,nummonth,ar.transdate,ar.invnumber
  if ($form->{mainsort} eq 'month') {
    $sortorder .= "nummonth,"
  } else {
    $sortorder .= $mainsort . ",";
  };
  if ($form->{subsort} eq 'month') {
    $sortorder .= "nummonth,"
  } else {
    $sortorder .= $subsort . ",";
  };
  $sortorder .= 'ar.transdate,ar.invnumber';  # Default sorting order after mainsort und subsort

  if ($form->{customer_id}) {
    $where .= " AND ar.customer_id = ?";
    push(@values, $form->{customer_id});
  } elsif ($form->{customer}) {
    $where .= " AND ct.name ILIKE ?";
    push(@values, like($form->{customer}));
  }
  if ($form->{customernumber}) {
    $where .= qq| AND ct.customernumber = ? |;
    push(@values, $form->{customernumber});
  }
  if ($form->{partnumber}) {
    $where .= qq| AND (p.partnumber ILIKE ?)|;
    push(@values, like($form->{partnumber}));
  }
  if ($form->{partsgroup_id}) {
    $where .= qq| AND (pg.id = ?)|;
    push(@values, $form->{partsgroup_id});
  }
  if ($form->{country}) {
    $where .= qq| AND (ct.country ILIKE ?)|;
    push(@values, like($form->{country}));
  }

  # when filtering for parts by description we probably want to filter by the description of the part as per the master data
  # invoice.description may differ due to manually changing the description in the invoice or because of translations of the description
  # at least in the translation case we probably want the report to also include translated articles, so we have to filter via parts.description
  if ($form->{description}) {
    $where .= qq| AND (p.description ILIKE ?)|;
    push(@values, like($form->{description}));
  }
  if ($form->{transdatefrom}) {
    $where .= " AND ar.transdate >= ?";
    push(@values, $form->{transdatefrom});
  }
  if ($form->{transdateto}) {
    $where .= " AND ar.transdate <= ?";
    push(@values, $form->{transdateto});
  }
  if ($form->{department_id}) {
    $where .= " AND ar.department_id = ?";
    push @values, conv_i($form->{department_id});
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
      qq| AND ((ar.globalproject_id = ?) OR EXISTS | .
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
