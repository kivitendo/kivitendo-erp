#====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 1999-2003
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
# Order entry module
# Quotation
#======================================================================

package OE;

use List::Util qw(max first);

use SL::AM;
use SL::Common;
use SL::CVar;
use SL::DB::Order;
use SL::DB::PeriodicInvoicesConfig;
use SL::DB::Project;
use SL::DB::ProjectType;
use SL::DB::RequirementSpecOrder;
use SL::DB::Status;
use SL::DB::Tax;
use SL::DBUtils;
use SL::HTML::Restrict;
use SL::IC;
use SL::TransNumber;
use SL::Util qw(trim);
use SL::DB;
use SL::YAML;
use Text::ParseWords;

use strict;

sub transactions {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->get_standard_dbh;

  my $query;
  my $ordnumber = 'ordnumber';
  my $record_type = $form->{type};

  my @values;
  my $where;

  my ($periodic_invoices_columns, $periodic_invoices_joins);

  my $rate = ($form->{vc} eq 'customer') ? 'buy' : 'sell';

  if ($form->{type} =~ /_quotation$/) {
    $ordnumber = 'quonumber';

  } elsif ($form->{type} eq 'purchase_quotation_intake') {
    $ordnumber = 'quonumber';
  } elsif ($form->{type} eq 'sales_order') {
    $periodic_invoices_columns = qq| , COALESCE(pcfg.active, 'f') AS periodic_invoices |;
    $periodic_invoices_joins   = qq| LEFT JOIN periodic_invoices_configs pcfg ON (o.id = pcfg.oe_id) |;
  }

  my $vc = $form->{vc} eq "customer" ? "customer" : "vendor";

  if ($form->{type} !~ /_quotation/) {
    $form->{hide_amounts} = !(   ($vc eq 'customer' && $::auth->assert('sales_order_reports_amounts',    1))
                              || ($vc eq 'vendor'   && $::auth->assert('purchase_order_reports_amounts', 1)) );
    $form->{hide_links}   = $form->{hide_amounts};
  }

  if ($form->{hide_amounts}) {
    $form->{"l_$_"} = '' for qw(remaining_amount remaining_netamount amount netamount marge_total marge_percent expected_netamount tax);
  }

  my %billed_amount;
  my %billed_netamount;
  if (!$form->{hide_amounts} && ($form->{l_remaining_amount} || $form->{l_remaining_netamount})) {
    my $arap = $form->{vc} eq "customer" ? "ar" : "ap";

    $query = <<"SQL";
      SELECT from_id, ${arap}.amount, $arap.netamount FROM (
        SELECT from_id, to_id
        FROM record_links
        WHERE from_table = 'oe' AND to_table = '$arap'
        UNION
        SELECT rl1.from_id, rl2.to_id
        FROM record_links rl1
        LEFT JOIN record_links rl2 ON (rl1.to_table = rl2.from_table AND rl1.to_id = rl2.from_id)
        WHERE rl1.from_table = 'oe' AND rl2.to_table = '$arap'
        UNION
        SELECT rl1.from_id, rl3.to_id
        FROM record_links rl1
        JOIN record_links rl2 ON (rl1.to_table = rl2.from_table AND rl1.to_id = rl2.from_id)
        JOIN record_links rl3 ON (rl2.to_table = rl3.from_table AND rl2.to_id = rl3.from_id)
        WHERE rl1.from_table = 'oe' AND rl2.to_table = '$arap' AND rl3.to_table = '$arap'
      ) rl
      LEFT JOIN $arap ON $arap.id = rl.to_id
SQL

    for my $ref (@{ selectall_hashref_query($form, $dbh, $query) }) {
      $billed_amount{   $ref->{from_id}} += $ref->{amount};
      $billed_netamount{$ref->{from_id}} += $ref->{netamount};
    }
  }

  my ($phone_notes_columns, $phone_notes_join);
  $form->{phone_notes} = trim($form->{phone_notes});
  if ($form->{phone_notes}) {
    $phone_notes_columns = qq| , phone_notes.subject AS phone_notes_subject, phone_notes.body AS phone_notes_body |;
    $phone_notes_join    = qq| JOIN notes phone_notes ON (o.id = phone_notes.trans_id AND phone_notes.trans_module LIKE 'oe') |;
  }

  my $amount_columns = $form->{hide_amounts}
                     ? ''
                     : qq| , o.amount, o.netamount, o.marge_total, o.marge_percent, (o.netamount * o.order_probability / 100) AS expected_netamount |;

  $query =
    qq|SELECT o.id, o.ordnumber, o.transdate, o.reqdate | .
    $amount_columns .
    qq|  , ct.${vc}number, ct.name, o.${vc}_id, o.globalproject_id, | .
    qq|  o.closed, o.delivered, o.quonumber, o.cusordnumber, o.shippingpoint, o.shipvia, | .
    qq|  o.transaction_description, | .
    qq|  o.exchangerate, | .
    qq|  o.itime::DATE AS insertdate, | .
    qq|  o.intnotes,| .
    qq|  o.vendor_confirmation_number,| .
    qq|  department.description as department, | .
    qq|  ex.$rate AS daily_exchangerate, | .
    qq|  pt.description AS payment_terms, | .
    qq|  pr.projectnumber AS globalprojectnumber, | .
    qq|  e.name AS employee, s.name AS salesman, | .
    qq|  ct.${vc}number AS vcnumber, ct.country, ct.ustid, ct.business_id,  | .
    qq|  tz.description AS taxzone, | .
    qq|  shipto.shiptoname, shipto.shiptodepartment_1, shipto.shiptodepartment_2, | .
    qq|  shipto.shiptostreet, shipto.shiptozipcode, shipto.shiptocity, shipto.shiptocountry, | .
    qq|  order_statuses.name AS order_status | .
    $periodic_invoices_columns .
    $phone_notes_columns .
    qq|  , o.order_probability, o.expected_billing_date, | .
    qq|  (employee_id = (SELECT id FROM employee WHERE login = ?)) AS is_own  | .
    qq|FROM oe o | .
    qq|JOIN $vc ct ON (o.${vc}_id = ct.id) | .
    qq|LEFT JOIN contacts cp ON (o.cp_id = cp.cp_id) | .
    qq|LEFT JOIN employee e ON (o.employee_id = e.id) | .
    qq|LEFT JOIN employee s ON (o.salesman_id = s.id) | .
    qq|LEFT JOIN exchangerate ex ON (ex.currency_id = o.currency_id | .
    qq|  AND ex.transdate = o.transdate) | .
    qq|LEFT JOIN project pr ON (o.globalproject_id = pr.id) | .
    qq|LEFT JOIN payment_terms pt ON (pt.id = o.payment_id)| .
    qq|LEFT JOIN tax_zones tz ON (o.taxzone_id = tz.id) | .
    qq|LEFT JOIN department   ON (o.department_id = department.id) | .
    qq|LEFT JOIN order_statuses ON (o.order_status_id = order_statuses.id) | .
    qq|LEFT JOIN shipto ON (
        (o.shipto_id = shipto.shipto_id) or
        (o.id = shipto.trans_id and shipto.module = 'OE')
       )| .
    qq|$periodic_invoices_joins | .
    $phone_notes_join .
    qq|WHERE (o.record_type = ?) |;


  push @values, $::myconfig{login};
  push(@values, $record_type);

  if ($form->{department_id}) {
    $query .= qq| AND o.department_id = ?|;
    push(@values, $form->{department_id});
  }

  if ($form->{"project_id"}) {
    $query .=
      qq| AND ((globalproject_id = ?) OR EXISTS | .
      qq|  (SELECT * FROM orderitems oi | .
      qq|   WHERE oi.project_id = ? AND oi.trans_id = o.id))|;
    push(@values, conv_i($form->{"project_id"}), conv_i($form->{"project_id"}));
  }

  if ($form->{"projectnumber"}) {
    $query .= <<SQL;
      AND ((pr.projectnumber ILIKE ?) OR EXISTS (
        SELECT * FROM orderitems oi
        LEFT JOIN project proi ON proi.id = oi.project_id
        WHERE proi.projectnumber ILIKE ? AND oi.trans_id = o.id
      ))
SQL
    push @values, like($form->{"projectnumber"}), like($form->{"projectnumber"});
  }

  if ($form->{"business_id"}) {
    $query .= " AND ct.business_id = ?";
    push(@values, $form->{"business_id"});
  }

  if ($form->{"${vc}_id"}) {
    $query .= " AND o.${vc}_id = ?";
    push(@values, $form->{"${vc}_id"});

  } elsif ($form->{$vc}) {
    $query .= " AND ct.name ILIKE ?";
    push(@values, like($form->{$vc}));
  }

  if ($form->{"cp_name"}) {
    $query .= " AND (cp.cp_name ILIKE ? OR cp.cp_givenname ILIKE ?)";
    push(@values, (like($form->{"cp_name"}))x2);
  }

  if ( !(    ($vc eq 'customer' && ($main::auth->assert('sales_all_edit',    1) || $main::auth->assert('sales_order_view',    1)))
          || ($vc eq 'vendor'   && ($main::auth->assert('purchase_all_edit', 1) || $main::auth->assert('purchase_order_view', 1))) ) ) {
    $query .= " AND o.employee_id = (select id from employee where login= ?)";
    push @values, $::myconfig{login};
  }
  if ($form->{employee_id}) {
    $query .= " AND o.employee_id = ?";
    push @values, conv_i($form->{employee_id});
  }

  if ($form->{salesman_id}) {
    $query .= " AND o.salesman_id = ?";
    push @values, conv_i($form->{salesman_id});
  }

  if (!$form->{open} && !$form->{closed}) {
    $query .= " AND o.id = 0";
  } elsif (!($form->{open} && $form->{closed})) {
    $query .= ($form->{open}) ? " AND o.closed = '0'" : " AND o.closed = '1'";
  }

  if (($form->{"notdelivered"} || $form->{"delivered"}) &&
      ($form->{"notdelivered"} ne $form->{"delivered"})) {
    $query .= $form->{"delivered"} ?
      " AND o.delivered " : " AND NOT o.delivered";
  }

  if ($form->{$ordnumber}) {
    $query .= qq| AND o.$ordnumber ILIKE ?|;
    push(@values, like($form->{$ordnumber}));
  }

  if ($form->{cusordnumber}) {
    $query .= qq| AND o.cusordnumber ILIKE ?|;
    push(@values, like($form->{cusordnumber}));
  }

  if ($form->{vendor_confirmation_number}) {
    $query .= qq| AND o.vendor_confirmation_number ILIKE ?|;
    push(@values, like($form->{vendor_confirmation_number}));
  }

  if($form->{transdatefrom}) {
    $query .= qq| AND o.transdate >= ?|;
    push(@values, conv_date($form->{transdatefrom}));
  }

  if($form->{transdateto}) {
    $query .= qq| AND o.transdate <= ?|;
    push(@values, conv_date($form->{transdateto}));
  }

  if($form->{reqdatefrom}) {
    $query .= qq| AND o.reqdate >= ?|;
    push(@values, conv_date($form->{reqdatefrom}));
  }

  if($form->{reqdateto}) {
    $query .= qq| AND o.reqdate <= ?|;
    push(@values, conv_date($form->{reqdateto}));
  }

  if($form->{insertdatefrom}) {
    $query .= qq| AND o.itime::DATE >= ?|;
    push(@values, conv_date($form->{insertdatefrom}));
  }

  if($form->{insertdateto}) {
    $query .= qq| AND o.itime::DATE <= ?|;
    push(@values, conv_date($form->{insertdateto}));
  }

  if ($form->{shippingpoint}) {
    $query .= qq| AND o.shippingpoint ILIKE ?|;
    push(@values, like($form->{shippingpoint}));
  }

  if ($form->{taxzone_id} ne '') { # taxzone_id could be 0
    $query .= qq| AND tz.id = ?|;
    push(@values, $form->{taxzone_id});
  }

  if ($form->{transaction_description}) {
    $query .= qq| AND o.transaction_description ILIKE ?|;
    push(@values, like($form->{transaction_description}));
  }

  if ($form->{periodic_invoices_active} ne $form->{periodic_invoices_inactive}) {
    my $not  = $form->{periodic_invoices_inactive} ? 'NOT' : '';
    $query  .= qq| AND ${not} COALESCE(pcfg.active, 'f')|;
  }

  if ($form->{reqdate_unset_or_old}) {
    $query .= qq| AND ((o.reqdate IS NULL) OR (o.reqdate < date_trunc('month', current_date)))|;
  }

  if (($form->{order_probability_value} || '') ne '') {
    my $op  = $form->{order_probability_value} eq 'le' ? '<=' : '>=';
    $query .= qq| AND (o.order_probability ${op} ?)|;
    push @values, trim($form->{order_probability_value});
  }

  if ($form->{expected_billing_date_from}) {
    $query .= qq| AND (o.expected_billing_date >= ?)|;
    push @values, conv_date($form->{expected_billing_date_from});
  }

  if ($form->{expected_billing_date_to}) {
    $query .= qq| AND (o.expected_billing_date <= ?)|;
    push @values, conv_date($form->{expected_billing_date_to});
  }

  if ($form->{intnotes}) {
    $query .= qq| AND o.intnotes ILIKE ?|;
    push(@values, like($form->{intnotes}));
  }

  if ($form->{order_status_id}) {
    $query .= qq| AND o.order_status_id = ?|;
    push(@values, $form->{order_status_id});
  }

  if ($form->{phone_notes}) {
    $query .= qq| AND (phone_notes.subject ILIKE ? OR regexp_replace(phone_notes.body, '<[^>]*>', '', 'g') ILIKE ?)|;
    push(@values, like($form->{phone_notes}), like($form->{phone_notes}));
  }

  $form->{fulltext} = trim($form->{fulltext});
  if ($form->{fulltext}) {
    my @fulltext_fields = qw(o.notes
                             o.intnotes
                             o.shippingpoint
                             o.shipvia
                             o.transaction_description
                             o.quonumber
                             o.ordnumber
                             o.cusordnumber
                             o.vendor_confirmation_number);
    $query .= ' AND (';
    $query .= join ' ILIKE ? OR ', @fulltext_fields;
    $query .= ' ILIKE ?';

    $query .= <<SQL;
      OR EXISTS (
        SELECT files.id FROM files LEFT JOIN file_full_texts ON (file_full_texts.file_id = files.id)
          WHERE files.object_id = o.id AND files.object_type = 'sales_order'
            AND file_full_texts.full_text ILIKE ?)
SQL

    $query .= <<SQL;
      OR EXISTS (
        SELECT notes.id FROM notes
          WHERE notes.trans_id = o.id AND notes.trans_module LIKE 'oe'
            AND (notes.subject ILIKE ? OR regexp_replace(notes.body, '<[^>]*>', '', 'g') ILIKE ?))
SQL

    $query .= <<SQL;
      OR EXISTS (
        SELECT follow_up_links.id FROM follow_up_links
          WHERE follow_up_links.trans_id = o.id AND trans_type = 'sales_order'
            AND EXISTS (
              SELECT notes.id FROM notes
                WHERE trans_module LIKE 'fu' AND trans_id = follow_up_links.follow_up_id
                  AND (notes.subject ILIKE ? OR notes.body ILIKE ?)))
SQL

    $query .= ')';

    push(@values, like($form->{fulltext})) for 1 .. (scalar @fulltext_fields) + 5;
  }

  if ($form->{parts_partnumber}) {
    $query .= <<SQL;
      AND EXISTS (
        SELECT orderitems.trans_id
        FROM orderitems
        LEFT JOIN parts ON (orderitems.parts_id = parts.id)
        WHERE (orderitems.trans_id = o.id)
          AND (parts.partnumber ILIKE ?)
        LIMIT 1
      )
SQL
    push @values, like($form->{parts_partnumber});
  }

  if ($form->{parts_description}) {
    $query .= <<SQL;
      AND EXISTS (
        SELECT orderitems.trans_id
        FROM orderitems
        WHERE (orderitems.trans_id = o.id)
          AND (orderitems.description ILIKE ?)
        LIMIT 1
      )
SQL
    push @values, like($form->{parts_description});
  }

  if ($form->{shiptoname}) {
    $query .= " AND shipto.shiptoname ILIKE ?";
    push(@values, like($form->{shiptoname}));
  }
  if ($form->{shiptodepartment_1}) {
    $query .= " AND shipto.shiptodepartment_1 ILIKE ?";
    push(@values, like($form->{shiptodepartment_1}));
  }
  if ($form->{shiptodepartment_2}) {
    $query .= " AND shipto.shiptodepartment_2 ILIKE ?";
    push(@values, like($form->{shiptodepartment_2}));
  }
  if ($form->{shiptostreet}) {
    $query .= " AND shipto.shiptostreet ILIKE ?";
    push(@values, like($form->{shiptostreet}));
  }
  if ($form->{shiptozipcode}) {
    $query .= " AND shipto.shiptozipcode ILIKE ?";
    push(@values, like($form->{shiptozipcode}));
  }
  if ($form->{shiptocity}) {
    $query .= " AND shipto.shiptocity ILIKE ?";
    push(@values, like($form->{shiptocity}));
  }
  if ($form->{shiptocountry}) {
    $query .= " AND shipto.shiptocountry ILIKE ?";
    push(@values, like($form->{shiptocountry}));
  }

  if ($form->{all}) {
    my @tokens = parse_line('\s+', 0, $form->{all});
    # ordnumber quonumber customer.name vendor.name transaction_description
    $query .= qq| AND (
      o.ordnumber ILIKE ? OR
      o.quonumber ILIKE ? OR
      ct.name     ILIKE ? OR
      o.transaction_description ILIKE ?
    )| for @tokens;
    push @values, (like($_))x4 for @tokens;
  }

  my ($cvar_where, @cvar_values) = CVar->build_filter_query('module'         => 'CT',
                                                            'trans_id_field' => 'ct.id',
                                                            'filter'         => $form,
                                                           );
  if ($cvar_where) {
    $query .= qq| AND ($cvar_where)|;
    push @values, @cvar_values;
  }

  my $sortdir   = !defined $form->{sortdir} ? 'ASC' : $form->{sortdir} ? 'ASC' : 'DESC';
  my $sortorder = join(', ', map { "${_} ${sortdir} " } ("o.id", $form->sort_columns("transdate", $ordnumber, "name"), "o.itime"));
  my %allowed_sort_columns = (
    "transdate"               => "o.transdate",
    "reqdate"                 => "o.reqdate",
    "id"                      => "o.id",
    "ordnumber"               => "o.ordnumber",
    "cusordnumber"            => "o.cusordnumber",
    "quonumber"               => "o.quonumber",
    "name"                    => "ct.name",
    "employee"                => "e.name",
    "salesman"                => "s.name",
    "shipvia"                 => "o.shipvia",
    "transaction_description" => "o.transaction_description",
    "shippingpoint"           => "o.shippingpoint",
    "insertdate"              => "o.itime",
    "taxzone"                 => "tz.description",
    "payment_terms"           => "pt.description",
    "department"              => "department.description",
    "intnotes"                => "o.intnotes",
    "order_status"            => "order_statuses.name",
    "vendor_confirmation_number" => "o.vendor_confirmation_number",
  );
  if ($form->{sort} && grep($form->{sort}, keys(%allowed_sort_columns))) {
    $sortorder = $allowed_sort_columns{$form->{sort}} . " ${sortdir}"  . ", o.itime ${sortdir}";
  }
  $query .= qq| ORDER by | . $sortorder;

  my $sth = $dbh->prepare($query);
  $sth->execute(@values) ||
    $form->dberror($query . " (" . join(", ", @values) . ")");

  my %id = ();
  $form->{OE} = [];
  while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
    if (!$form->{hide_amounts}) {
      $ref->{billed_amount}    = $billed_amount{$ref->{id}};
      $ref->{billed_netamount} = $billed_netamount{$ref->{id}};
      if ($ref->{billed_amount} < 0) { # case: credit note(s) higher than invoices
        $ref->{remaining_amount} = $ref->{amount} + $ref->{billed_amount};
        $ref->{remaining_netamount} = $ref->{netamount} + $ref->{billed_netamount};
      } else {
        $ref->{remaining_amount} = $ref->{amount} - $ref->{billed_amount};
        $ref->{remaining_netamount} = $ref->{netamount} - $ref->{billed_netamount};
      }
    }

    $ref->{exchangerate} ||= $ref->{daily_exchangerate};
    $ref->{exchangerate} ||= 1;

    push @{ $form->{OE} }, $ref if $ref->{id} != $id{ $ref->{id} };
    $id{ $ref->{id} } = $ref->{id};
  }

  $sth->finish;

  if ($form->{l_items} && scalar @{ $form->{OE} }) {
    my ($items_query, $items_sth);
    if ($form->{l_items}) {
      $items_query =
        qq|SELECT id
          FROM orderitems
          WHERE trans_id  = ?
          ORDER BY position|;

      $items_sth = prepare_query($form, $dbh, $items_query);
    }

    foreach my $oe (@{ $form->{OE} }) {
      do_statement($form, $items_sth, $items_query, $oe->{id});
      $oe->{item_ids} = $dbh->selectcol_arrayref($items_sth);
      $oe->{item_ids} = undef if !@{$oe->{item_ids}};
    }
    $items_sth->finish();
  }

  $main::lxdebug->leave_sub();
}

sub transactions_for_todo_list {
  $main::lxdebug->enter_sub();

  my $self                   = shift;
  my %params                 = @_;

  my $myconfig               = \%main::myconfig;
  my $form                   = $main::form;

  my $dbh                    = $params{dbh} || $form->get_standard_dbh($myconfig);

  my $query                  = qq|SELECT id FROM employee WHERE login = ?|;
  my ($e_id)                 = selectrow_query($form, $dbh, $query, $::myconfig{login});

  my $sales_purchase_filter  = 'AND (1 = 0';
  $sales_purchase_filter    .= $params{sales}    ? qq| OR customer_id IS NOT NULL| : '';
  $sales_purchase_filter    .= $params{purchase} ? qq| OR vendor_id   IS NOT NULL| : '';
  $sales_purchase_filter    .= ')';

  $query                     =
    qq|SELECT oe.id, oe.transdate, oe.reqdate, oe.quonumber, oe.transaction_description, oe.amount,
         CASE WHEN (COALESCE(oe.customer_id, 0) = 0) THEN 'vendor' ELSE 'customer' END AS vc,
         c.name AS customer,
         v.name AS vendor,
         e.name AS employee
       FROM oe
       LEFT JOIN customer c ON (oe.customer_id = c.id)
       LEFT JOIN vendor v   ON (oe.vendor_id   = v.id)
       LEFT JOIN employee e ON (oe.employee_id = e.id)
       WHERE ((oe.record_type = 'sales_quotation') OR (oe.record_type = 'request_quotation'))
         AND (COALESCE(closed,    FALSE) = FALSE)
         AND ((oe.employee_id = ?) OR (oe.salesman_id = ?))
         AND NOT (oe.reqdate ISNULL)
         AND (oe.reqdate < current_date)
         $sales_purchase_filter
       ORDER BY transdate|;

  my $quotations = selectall_hashref_query($form, $dbh, $query, $e_id, $e_id);

  $main::lxdebug->leave_sub();

  return $quotations;
}

sub save {
  my ($self, $myconfig, $form) = @_;
  $main::lxdebug->enter_sub();

  my $rc = SL::DB->client->with_transaction(\&_save, $self, $myconfig, $form);

  $::lxdebug->leave_sub;

  return $rc;
}

sub _save {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh = SL::DB->client->dbh;
  my $restricter = SL::HTML::Restrict->create;

  my ($query, @values, $sth, $null);
  my $exchangerate = 0;

  my $all_units = AM->retrieve_units($myconfig, $form);
  $form->{all_units} = $all_units;

  my $ic_cvar_configs = CVar->get_configs(module => 'IC',
                                          dbh    => $dbh);

  $form->{employee_id} = (split /--/, $form->{employee})[1] if !$form->{employee_id};
  unless ($form->{employee_id}) {
    $form->get_employee($dbh);
  }

  my $ml = ($form->{type} eq 'sales_order') ? 1 : -1;

  my $number_field         = $form->{type} =~ m{order} ? 'ordnumber' : 'quonumber';
  my $trans_number         = SL::TransNumber->new(type => $form->{type}, dbh => $dbh, number => $form->{$number_field}, id => $form->{id});
  $form->{$number_field} ||= $trans_number->create_unique; # set $form->{ordnumber} or $form->{quonumber}
  my $is_new               = !$form->{id};

  if ($form->{id}) {
    $query = qq|DELETE FROM custom_variables
                WHERE (config_id IN (SELECT id        FROM custom_variable_configs WHERE (module = 'ShipTo')))
                  AND (trans_id  IN (SELECT shipto_id FROM shipto                  WHERE (module = 'OE') AND (trans_id = ?)))|;
    do_query($form, $dbh, $query, $form->{id});

    $query = qq|DELETE FROM shipto | .
             qq|WHERE trans_id = ? AND module = 'OE'|;
    do_query($form, $dbh, $query, $form->{id});

  } else {

    $query = qq|SELECT nextval('id')|;
    ($form->{id}) = selectrow_query($form, $dbh, $query);

    $query = qq|INSERT INTO oe (id, ordnumber, employee_id, currency_id, taxzone_id) VALUES (?, '', ?, (SELECT currency_id FROM defaults), ?)|;
    do_query($form, $dbh, $query, $form->{id}, $form->{employee_id}, $form->{taxzone_id});
  }

  my $amount    = 0;
  my $linetotal = 0;
  my $discount  = 0;
  my $project_id;
  my $reqdate;
  my $taxrate;
  my $taxbase;
  my $taxdiff;
  my $taxamount = 0;
  my $fxsellprice;
  my %taxbase;
  my @taxaccounts;
  my %taxaccounts;
  my $netamount = 0;
  my @processed_orderitems;

  $form->get_lists('price_factors' => 'ALL_PRICE_FACTORS');
  my %price_factors = map { $_->{id} => $_->{factor} } @{ $form->{ALL_PRICE_FACTORS} };
  my $price_factor;

  for my $i (1 .. $form->{rowcount}) {

    map({ $form->{"${_}_$i"} = $form->parse_amount($myconfig, $form->{"${_}_$i"}) } qw(qty ship));

    if ($form->{"id_$i"}) {

      # get item baseunit
      $query = qq|SELECT unit FROM parts WHERE id = ?|;
      my ($item_unit) = selectrow_query($form, $dbh, $query, $form->{"id_$i"});

      my $basefactor = 1;
      if (defined($all_units->{$item_unit}->{factor}) &&
          (($all_units->{$item_unit}->{factor} * 1) != 0)) {
        $basefactor = $all_units->{$form->{"unit_$i"}}->{factor} / $all_units->{$item_unit}->{factor};
      }
      my $baseqty = $form->{"qty_$i"} * $basefactor;

      $form->{"marge_percent_$i"} = $form->parse_amount($myconfig, $form->{"marge_percent_$i"}) * 1;
      $form->{"marge_absolut_$i"} = $form->parse_amount($myconfig, $form->{"marge_absolut_$i"}) * 1;

      $form->{"lastcost_$i"} = $form->parse_amount($myconfig, $form->{"lastcost_$i"});

      # keep entered selling price
      my $fxsellprice =
        $form->parse_amount($myconfig, $form->{"sellprice_$i"});

      my ($dec) = ($fxsellprice =~ /\.(\d+)/);
      $dec = length $dec;
      my $decimalplaces = ($dec > 2) ? $dec : 2;

      # undo discount formatting
      $form->{"discount_$i"} = $form->parse_amount($myconfig, $form->{"discount_$i"}) / 100;

      # deduct discount
      $form->{"sellprice_$i"} = $fxsellprice * (1 - $form->{"discount_$i"});

      # round linetotal at least to 2 decimal places
      $price_factor = $price_factors{ $form->{"price_factor_id_$i"} } || 1;
      $linetotal    = $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"} / $price_factor, 2);

      $form->{"inventory_accno_$i"} *= 1;
      $form->{"expense_accno_$i"}   *= 1;

      @taxaccounts = split(/ /, $form->{"taxaccounts_$i"});
      $taxrate     = 0;
      $taxdiff     = 0;

      map { $taxrate += $form->{"${_}_rate"} } @taxaccounts;

      if ($form->{taxincluded}) {
        $taxamount = $linetotal * $taxrate / (1 + $taxrate);
        $taxbase   = $linetotal - $taxamount;

        # we are not keeping a natural price, do not round
        $form->{"sellprice_$i"} =
          $form->{"sellprice_$i"} * (1 / (1 + $taxrate));
      } else {
        $taxamount = $linetotal * $taxrate;
        $taxbase   = $linetotal;
      }

      if ($form->round_amount($taxrate, 7) == 0) {
        if ($form->{taxincluded}) {
          foreach my $item (@taxaccounts) {
            $taxamount = $form->round_amount($linetotal * $form->{"${item}_rate"} / (1 + abs($form->{"${item}_rate"})), 2);
            $taxaccounts{$item} += $taxamount;
            $taxdiff            += $taxamount;
            $taxbase{$item}     += $taxbase;
          }
          $taxaccounts{ $taxaccounts[0] } += $taxdiff;
        } else {
          foreach my $item (@taxaccounts) {
            $taxaccounts{$item} += $linetotal * $form->{"${item}_rate"};
            $taxbase{$item}     += $taxbase;
          }
        }
      } else {
        foreach my $item (@taxaccounts) {
          $taxaccounts{$item} += $taxamount * $form->{"${item}_rate"} / $taxrate;
          $taxbase{$item} += $taxbase;
        }
      }

      $netamount += $form->{"sellprice_$i"} * $form->{"qty_$i"} / $price_factor;

      $reqdate = ($form->{"reqdate_$i"}) ? $form->{"reqdate_$i"} : undef;

      # Get pricegroup_id and save it. Unfortunately the interface
      # also uses ID "0" for signalling that none is selected, but "0"
      # must not be stored in the database. Therefore we cannot simply
      # use conv_i().
      ($null, my $pricegroup_id) = split(/--/, $form->{"sellprice_pg_$i"});
      $pricegroup_id *= 1;
      $pricegroup_id  = undef if !$pricegroup_id;

      # force new project, if not set yet
      if ($::instance_conf->get_order_always_project && !$form->{"globalproject_id"} && ($form->{type} eq 'sales_order')) {
        require SL::DB::Customer;
        my $customer = SL::DB::Manager::Customer->find_by(id => $form->{customer_id});
        die "Can't find customer" unless $customer;
        die $main::locale->text("Error while creating project with project number of new order number, project number #1 already exists!", $form->{ordnumber})
          if SL::DB::Manager::Project->find_by(projectnumber => $form->{ordnumber});

        my $new_project = SL::DB::Project->new(
          projectnumber     => $form->{ordnumber},
          description       => $customer->name,
          customer_id       => $customer->id,
          active            => 1,
          project_type_id   => $::instance_conf->get_project_type_id,
          project_status_id => $::instance_conf->get_project_status_id,
        );
        $new_project->save;
        $form->{"globalproject_id"} = $new_project->id;
      }

      CVar->get_non_editable_ic_cvars(form               => $form,
                                      dbh                => $dbh,
                                      row                => $i,
                                      sub_module         => 'orderitems',
                                      may_converted_from => ['orderitems', 'invoice']);

      my $position = $i;

      # save detail record in orderitems table
      if (! $form->{"orderitems_id_$i"}) {
        $query = qq|SELECT nextval('orderitemsid')|;
        ($form->{"orderitems_id_$i"}) = selectrow_query($form, $dbh, $query);

        $query = qq|INSERT INTO orderitems (id, position) VALUES (?, ?)|;
        do_query($form, $dbh, $query, $form->{"orderitems_id_$i"}, conv_i($position));
      }

      my $orderitems_id = $form->{"orderitems_id_$i"};
      push @processed_orderitems, $orderitems_id;

       $query = <<SQL;
         UPDATE orderitems SET
          trans_id = ?, position = ?, parts_id = ?, description = ?, longdescription = ?, qty = ?, base_qty = ?,
          sellprice = ?, discount = ?, unit = ?, reqdate = ?, project_id = ?, serialnumber = ?, ship = ?,
          pricegroup_id = ?, subtotal = ?, recurring_billing_mode = ?,
          marge_percent = ?, marge_total = ?, lastcost = ?, price_factor_id = ?,
          active_price_source = ?, active_discount_source = ?,
          price_factor = (SELECT factor FROM price_factors WHERE id = ?), marge_price_factor = ?
        WHERE id = ?
SQL
      @values = (
           conv_i($form->{id}), conv_i($position), conv_i($form->{"id_$i"}),
           $form->{"description_$i"}, $restricter->process($form->{"longdescription_$i"}),
           $form->{"qty_$i"}, $baseqty,
           $fxsellprice, $form->{"discount_$i"},
           $form->{"unit_$i"}, conv_date($reqdate), conv_i($form->{"project_id_$i"}),
           trim($form->{"serialnumber_$i"}), $form->{"ship_$i"},
           $pricegroup_id, $form->{"subtotal_$i"} ? 't' : 'f', $form->{"recurring_billing_mode_$i"} || 'always',
           $form->{"marge_percent_$i"}, $form->{"marge_absolut_$i"},
           $form->{"lastcost_$i"}, conv_i($form->{"price_factor_id_$i"}),
           $form->{"active_price_source_$i"}, $form->{"active_discount_source_$i"},
           conv_i($form->{"price_factor_id_$i"}), conv_i($form->{"marge_price_factor_$i"}),
           conv_i($orderitems_id),
      );

      do_query($form, $dbh, $query, @values);

      $form->{"sellprice_$i"} = $fxsellprice;
      $form->{"discount_$i"} *= 100;

      CVar->save_custom_variables(module       => 'IC',
                                  sub_module   => 'orderitems',
                                  trans_id     => $orderitems_id,
                                  configs      => $ic_cvar_configs,
                                  variables    => $form,
                                  name_prefix  => 'ic_',
                                  name_postfix => "_$i",
                                  dbh          => $dbh);

      # link previous items with orderitems
      # assume we have a new workflow if we link from invoice or order to quotation
      # unluckily orderitems are used for quotation and orders - therefore one more
      # check to be sure NOT to link from order to quotation
      foreach (qw(orderitems)) {
        if (!$form->{saveasnew} && !$form->{useasnew} && $form->{"converted_from_${_}_id_$i"}
              && $form->{type} !~ 'quotation') {
          RecordLinks->create_links('dbh'        => $dbh,
                                    'mode'       => 'ids',
                                    'from_table' => $_,
                                    'from_ids'   => $form->{"converted_from_${_}_id_$i"},
                                    'to_table'   => 'orderitems',
                                    'to_id'      => $orderitems_id,
          );
        }
        delete $form->{"converted_from_${_}_id_$i"};
      }
    }
  }

  # search for orphaned ids
  $query  = sprintf 'SELECT id FROM orderitems WHERE trans_id = ? AND NOT id IN (%s)', join ', ', ("?") x scalar @processed_orderitems;
  @values = (conv_i($form->{id}), map { conv_i($_) } @processed_orderitems);
  my @orphaned_ids = map { $_->{id} } selectall_hashref_query($form, $dbh, $query, @values);

  if (scalar @orphaned_ids) {
    # clean up orderitems
    $query  = sprintf 'DELETE FROM orderitems WHERE id IN (%s)', join ', ', ("?") x scalar @orphaned_ids;
    do_query($form, $dbh, $query, @orphaned_ids);
  }

  $reqdate = ($form->{reqdate}) ? $form->{reqdate} : undef;

  # add up the tax
  my $tax = 0;
  map { $tax += $form->round_amount($taxaccounts{$_}, 2) } keys %taxaccounts;

  $amount = $form->round_amount($netamount + $tax, 2, 1);
  $netamount = $form->round_amount($netamount, 2);

  if ($form->{currency} eq $form->{defaultcurrency}) {
    $form->{exchangerate} = 1;
  } else {
    $exchangerate = $form->check_exchangerate($myconfig, $form->{currency}, $form->{transdate}, ($form->{vc} eq 'customer') ? 'buy' : 'sell');
  }

  # from inputfield (exchangerate) or hidden (forex)
  my $exchangerate_from_form = $form->{forex} || $form->parse_amount($myconfig, $form->{exchangerate});

  $form->{exchangerate} = $exchangerate || $exchangerate_from_form;

  my $quotation = $form->{type} =~ /_order$/ ? 'f' : 't';

  # save OE record
  $query =
    qq|UPDATE oe SET
         ordnumber = ?, quonumber = ?, cusordnumber = ?, transdate = ?, vendor_id = ?,
         customer_id = ?, amount = ?, netamount = ?, reqdate = ?, tax_point = ?, taxincluded = ?,
         shippingpoint = ?, shipvia = ?, notes = ?, intnotes = ?, currency_id = (SELECT id FROM currencies WHERE name=?), closed = ?,
         delivered = ?, proforma = ?, quotation = ?, department_id = ?, language_id = ?,
         taxzone_id = ?, shipto_id = ?, billing_address_id = ?, payment_id = ?, delivery_vendor_id = ?, delivery_customer_id = ?,delivery_term_id = ?,
         globalproject_id = ?, employee_id = ?, salesman_id = ?, cp_id = ?, transaction_description = ?, marge_total = ?, marge_percent = ?
         , order_probability = ?, expected_billing_date = ?
       WHERE id = ?|;

  @values = ($form->{ordnumber} || '', $form->{quonumber},
             $form->{cusordnumber}, conv_date($form->{transdate}),
             conv_i($form->{vendor_id}), conv_i($form->{customer_id}),
             $amount, $netamount, conv_date($reqdate), conv_date($form->{tax_point}),
             $form->{taxincluded} ? 't' : 'f', $form->{shippingpoint},
             $form->{shipvia}, $restricter->process($form->{notes}), $form->{intnotes},
             $form->{currency}, $form->{closed} ? 't' : 'f',
             $form->{delivered} ? "t" : "f", $form->{proforma} ? 't' : 'f',
             $quotation, conv_i($form->{department_id}),
             conv_i($form->{language_id}), conv_i($form->{taxzone_id}),
             conv_i($form->{shipto_id}), conv_i($form->{billing_address_id}), conv_i($form->{payment_id}),
             conv_i($form->{delivery_vendor_id}),
             conv_i($form->{delivery_customer_id}),
             conv_i($form->{delivery_term_id}),
             conv_i($form->{globalproject_id}), conv_i($form->{employee_id}),
             conv_i($form->{salesman_id}), conv_i($form->{cp_id}),
             $form->{transaction_description},
             $form->{marge_total} * 1, $form->{marge_percent} * 1,
             $form->{order_probability} * 1, conv_date($form->{expected_billing_date}),
             conv_i($form->{id}));
  do_query($form, $dbh, $query, @values);

  $form->new_lastmtime('oe');

  $form->{ordtotal} = $amount;

  $form->{name} = $form->{ $form->{vc} };
  $form->{name} =~ s/--\Q$form->{"$form->{vc}_id"}\E//;

  # add shipto
  if (!$form->{shipto_id}) {
    $form->add_shipto($dbh, $form->{id}, "OE");
  }

  # save printed, emailed, queued
  $form->save_status($dbh);

  # Link this record to the records it was created from.
  $form->{convert_from_oe_ids} =~ s/^\s+//;
  $form->{convert_from_oe_ids} =~ s/\s+$//;
  my @convert_from_oe_ids      =  split m/\s+/, $form->{convert_from_oe_ids};
  delete $form->{convert_from_oe_ids};
  if (!$form->{useasnew} && scalar @convert_from_oe_ids) {
    RecordLinks->create_links('dbh'        => $dbh,
                              'mode'       => 'ids',
                              'from_table' => 'oe',
                              'from_ids'   => \@convert_from_oe_ids,
                              'to_table'   => 'oe',
                              'to_id'      => $form->{id},
      );
    $self->_close_quotations_rfqs('dbh'     => $dbh,
                                  'from_id' => \@convert_from_oe_ids,
                                  'to_id'   => $form->{id});
  }

  if (($form->{currency} ne $form->{defaultcurrency}) && !$exchangerate) {
    if ($form->{vc} eq 'customer') {
      $form->update_exchangerate($dbh, $form->{currency}, $form->{transdate}, $form->{exchangerate}, 0);
    }
    if ($form->{vc} eq 'vendor') {
      $form->update_exchangerate($dbh, $form->{currency}, $form->{transdate}, 0, $form->{exchangerate});
    }
  }

  $form->{saved_xyznumber} = $form->{$form->{type} =~ /_quotation$/ ?
                                       "quonumber" : "ordnumber"};

  Common::webdav_folder($form);

  $self->save_periodic_invoices_config(dbh         => $dbh,
                                       oe_id       => $form->{id},
                                       config_yaml => $form->{periodic_invoices_config})
    if ($form->{type} eq 'sales_order');

  $self->_link_created_sales_order_to_requirement_specs_for_sales_quotations(
    type               => $form->{type},
    converted_from_ids => \@convert_from_oe_ids,
    sales_order_id     => $form->{id},
    is_new             => $is_new,
  );

  $self->_set_project_in_linked_requirement_spec(
    type           => $form->{type},
    project_id     => $form->{globalproject_id},
    sales_order_id => $form->{id},
  );

  $main::lxdebug->leave_sub();

  return 1;
}

sub _link_created_sales_order_to_requirement_specs_for_sales_quotations {
  my ($self, %params) = @_;

  # If this is a sales order created from a sales quotation and if
  # that sales quotation was created from a requirement spec document
  # then link the newly created sales order to the requirement spec
  # document, too.

  return if !$params{is_new};
  return if  $params{type} ne 'sales_order';
  return if !@{ $params{converted_from_ids} };

  my $oe_objects       = SL::DB::Manager::Order->get_all(where => [ id => $params{converted_from_ids} ]);
  my @sales_quotations = grep { $_->is_type('sales_quotation') } @{ $oe_objects };

  return if !@sales_quotations;

  my $rs_orders = SL::DB::Manager::RequirementSpecOrder->get_all(where => [ order_id => [ map { $_->id } @sales_quotations ] ]);

  return if !@{ $rs_orders };

  $rs_orders->[0]->db->with_transaction(sub {
    foreach my $rs_order (@{ $rs_orders }) {
      SL::DB::RequirementSpecOrder->new(
        order_id            => $params{sales_order_id},
        requirement_spec_id => $rs_order->requirement_spec_id,
        version_id          => $rs_order->version_id,
      )->save;
    }

    1;
  });
}

sub _set_project_in_linked_requirement_spec {
  my ($self, %params) = @_;

  return if  $params{type} ne 'sales_order';
  return if !$params{project_id} || !$params{sales_order_id};

  my $query = <<SQL;
    UPDATE requirement_specs
    SET project_id = ?
    WHERE id IN (
      SELECT so.requirement_spec_id
      FROM requirement_spec_orders so
      WHERE so.order_id = ?
    )
SQL

  do_query($::form, $::form->get_standard_dbh, $query, $params{project_id}, $params{sales_order_id});
}

sub save_periodic_invoices_config {
  my ($self, %params) = @_;

  return if !$params{oe_id};

  my $config = $params{config_yaml} ? SL::YAML::Load($params{config_yaml}) : undef;
  return if 'HASH' ne ref $config;

  my $obj  = SL::DB::Manager::PeriodicInvoicesConfig->find_by(oe_id => $params{oe_id})
          || SL::DB::PeriodicInvoicesConfig->new(oe_id => $params{oe_id});
  $obj->update_attributes(%{ $config });
}

sub load_periodic_invoice_config {
  my $self = shift;
  my $form = shift;

  delete $form->{periodic_invoices_config};

  if ($form->{id}) {
    my $config_obj = SL::DB::Manager::PeriodicInvoicesConfig->find_by(oe_id => $form->{id});

    if ($config_obj) {
      my $config = { map { $_ => $config_obj->$_ } qw(active terminated periodicity order_value_periodicity start_date_as_date end_date_as_date first_billing_date_as_date extend_automatically_by ar_chart_id
                                                      print printer_id copies direct_debit send_email email_recipient_contact_id email_recipient_address email_sender email_subject email_body) };
      $form->{periodic_invoices_config} = SL::YAML::Dump($config);
    }
  }
}

sub _close_quotations_rfqs {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(from_id to_id));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || SL::DB->client->dbh;

  SL::DB->client->with_transaction(sub {

    my $query    = qq|SELECT record_type FROM oe WHERE id = ?|;
    my $sth      = prepare_query($form, $dbh, $query);

    do_statement($form, $sth, $query, conv_i($params{to_id}));

    my ($record_type) = $sth->fetchrow_array();

    if ($record_type =~ /_quotation$/) {
      return 1;
    }

    my @close_ids;

    foreach my $from_id (@{ $params{from_id} }) {
      $from_id = conv_i($from_id);
      do_statement($form, $sth, $query, $from_id);
      ($record_type) = $sth->fetchrow_array();
      push @close_ids, $from_id if ($record_type =~ /_quotation$/);
    }

    $sth->finish();

    if (scalar @close_ids) {
      $query = qq|UPDATE oe SET closed = TRUE WHERE id IN (| . join(', ', ('?') x scalar @close_ids) . qq|)|;
      do_query($form, $dbh, $query, @close_ids);
    }
    1;
  }) or do { die SL::DB->client->error };

  $main::lxdebug->leave_sub();
}

sub delete {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $rc = SL::DB::Order->new->db->with_transaction(sub {
    my @spoolfiles = grep { $_ } map { $_->spoolfile } @{ SL::DB::Manager::Status->get_all(where => [ trans_id => $form->{id} ]) };

    SL::DB::Order->new(id => $form->{id})->delete;

    my $spool = $::lx_office_conf{paths}->{spool};
    unlink map { "$spool/$_" } @spoolfiles if $spool;

    1;
  }) or do { die SL::DB->client->error };

  $main::lxdebug->leave_sub();

  return $rc;
}

sub retrieve {
  my ($self, $myconfig, $form) = @_;
  $main::lxdebug->enter_sub();

  my $rc = SL::DB->client->with_transaction(\&_retrieve, $self, $myconfig, $form);

  $::lxdebug->leave_sub;
  return $rc;
}

sub _retrieve {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = SL::DB->client->dbh;

  my ($query, $query_add, @values, @ids, $sth);

  # translate the ids (given by id_# and trans_id_#) into one array of ids, so we can join them later
  map {
    push @ids, $form->{"trans_id_$_"}
      if ($form->{"multi_id_$_"} and $form->{"trans_id_$_"})
  } (1 .. $form->{"rowcount"});

  if ($form->{rowcount} && scalar @ids) {
    $form->{convert_from_oe_ids} = join ' ', @ids;
  }

  # if called in multi id mode, and still only got one id, switch back to single id
  if ($form->{"rowcount"} and $#ids == 0) {
    $form->{"id"} = $ids[0];
    undef @ids;
    delete $form->{convert_from_oe_ids};
  }

  # and remember for the rest of the function
  my $is_collective_order = scalar @ids;

  # If collective order was created from exactly 1 order, we assume the same
  # behaviour as a "save as new" from within an order is actually desired, i.e.
  # the original order isn't part of a workflow where we want to remember
  # record_links, but simply a quick way of generating a new order from an old
  # one without having to enter everything again.
  # Setting useasnew will prevent the creation of record_links for the items
  # when saving the new order.
  # This form variable is probably not necessary, could just set saveasnew instead
  $form->{useasnew} = 1 if $is_collective_order == 1;

  if (!$form->{id}) {
    my $extra_days = $form->{type} eq 'sales_quotation' ? $::instance_conf->get_reqdate_interval       :
                     $form->{type} eq 'sales_order'     ? $::instance_conf->get_delivery_date_interval : 1;
    if (   ($form->{type} eq 'sales_order'     &&  !$::instance_conf->get_deliverydate_on)
        || ($form->{type} eq 'sales_quotation' &&  !$::instance_conf->get_reqdate_on)) {
      $form->{reqdate}   = '';
    } else {
      $form->{reqdate}   = DateTime->today_local->next_workday(extra_days => $extra_days)->to_kivitendo;
    }
    $form->{transdate} = DateTime->today_local->to_kivitendo;
  }

  # get default accounts
  $query = qq|SELECT (SELECT c.accno FROM chart c WHERE d.inventory_accno_id = c.id) AS inventory_accno,
                     (SELECT c.accno FROM chart c WHERE d.income_accno_id    = c.id) AS income_accno,
                     (SELECT c.accno FROM chart c WHERE d.expense_accno_id   = c.id) AS expense_accno,
                     (SELECT c.accno FROM chart c WHERE d.fxgain_accno_id    = c.id) AS fxgain_accno,
                     (SELECT c.accno FROM chart c WHERE d.fxloss_accno_id    = c.id) AS fxloss_accno,
                     (SELECT c.accno FROM chart c WHERE d.rndgain_accno_id   = c.id) AS rndgain_accno,
                     (SELECT c.accno FROM chart c WHERE d.rndloss_accno_id   = c.id) AS rndloss_accno
              $query_add
              FROM defaults d|;
  my $ref = selectfirst_hashref_query($form, $dbh, $query);
  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $form->{currency} = $form->get_default_currency($myconfig);

  # set reqdate if this is an invoice->order conversion. If someone knows a better check to ensure
  # we come from invoices, feel free.
  $form->{reqdate} = $form->{deliverydate}
    if (    $form->{deliverydate}
        and $form->{callback} =~ /action=ar_transactions/);

  my $vc = $form->{vc} eq "customer" ? "customer" : "vendor";

  if ($form->{id} or @ids) {

    # retrieve order for single id
    # NOTE: this query is intended to fetch all information only ONCE.
    # so if any of these infos is important (or even different) for any item,
    # it will be killed out and then has to be fetched from the item scope query further down
    $query =
      qq|SELECT o.cp_id, o.ordnumber, o.transdate, o.reqdate,
           o.taxincluded, o.shippingpoint, o.shipvia, o.notes, o.intnotes,
           (SELECT cu.name FROM currencies cu WHERE cu.id=o.currency_id) AS currency, e.name AS employee, o.employee_id, o.salesman_id,
           o.${vc}_id, cv.name AS ${vc}, o.amount AS invtotal,
           o.closed, o.reqdate, o.tax_point, o.quonumber, o.department_id, o.cusordnumber,
           o.mtime, o.itime,
           d.description AS department, o.payment_id, o.language_id, o.taxzone_id,
           o.delivery_customer_id, o.delivery_vendor_id, o.proforma, o.shipto_id, o.billing_address_id,
           o.globalproject_id, o.delivered, o.transaction_description, o.delivery_term_id,
           o.itime::DATE AS insertdate, o.order_probability, o.expected_billing_date
         FROM oe o
         JOIN ${vc} cv ON (o.${vc}_id = cv.id)
         LEFT JOIN employee e ON (o.employee_id = e.id)
         LEFT JOIN department d ON (o.department_id = d.id) | .
        ($form->{id}
         ? "WHERE o.id = ?"
         : "WHERE o.id IN (" . join(', ', map("? ", @ids)) . ")"
        );
    @values = $form->{id} ? ($form->{id}) : @ids;
    $sth = prepare_execute_query($form, $dbh, $query, @values);

    $ref = $sth->fetchrow_hashref("NAME_lc");

    if ($ref) {
      map { $form->{$_} = $ref->{$_} } keys %$ref;

      $form->{saved_xyznumber} = $form->{$form->{type} =~ /_quotation$/ ? "quonumber" : "ordnumber"};

      # set all entries for multiple ids blank that yield different information
      while ($ref = $sth->fetchrow_hashref("NAME_lc")) {
        map { $form->{$_} = '' if ($ref->{$_} ne $form->{$_}) } keys %$ref;
      }
    }
    $form->{mtime}   ||= $form->{itime};
    $form->{lastmtime} = $form->{mtime};

    # if not given, fill transdate with current_date
    $form->{transdate} = $form->current_date($myconfig)
      unless $form->{transdate};

    $sth->finish;

    if ($form->{delivery_customer_id}) {
      $query = qq|SELECT name FROM customer WHERE id = ?|;
      ($form->{delivery_customer_string}) = selectrow_query($form, $dbh, $query, $form->{delivery_customer_id});
    }

    if ($form->{delivery_vendor_id}) {
      $query = qq|SELECT name FROM customer WHERE id = ?|;
      ($form->{delivery_vendor_string}) = selectrow_query($form, $dbh, $query, $form->{delivery_vendor_id});
    }

    # shipto and pinted/mailed/queued status makes only sense for single id retrieve
    if (!@ids) {
      $query = qq|SELECT s.* FROM shipto s WHERE s.trans_id = ? AND s.module = 'OE'|;
      $sth = prepare_execute_query($form, $dbh, $query, $form->{id});

      $ref = $sth->fetchrow_hashref("NAME_lc");
      $form->{$_} = $ref->{$_} for grep { m{^shipto(?!_id$)} } keys %$ref;
      $sth->finish;

      if ($ref->{shipto_id}) {
        my $cvars = CVar->get_custom_variables(
          dbh      => $dbh,
          module   => 'ShipTo',
          trans_id => $ref->{shipto_id},
        );
        $form->{"shiptocvar_$_->{name}"} = $_->{value} for @{ $cvars };
      }

      # get printed, emailed and queued
      $query = qq|SELECT s.printed, s.emailed, s.spoolfile, s.formname FROM status s WHERE s.trans_id = ?|;
      $sth = prepare_execute_query($form, $dbh, $query, $form->{id});

      while ($ref = $sth->fetchrow_hashref("NAME_lc")) {
        $form->{printed} .= "$ref->{formname} " if $ref->{printed};
        $form->{emailed} .= "$ref->{formname} " if $ref->{emailed};
        $form->{queued}  .= "$ref->{formname} $ref->{spoolfile} " if $ref->{spoolfile};
      }
      $sth->finish;
      map { $form->{$_} =~ s/ +$//g } qw(printed emailed queued);
    }    # if !@ids

    my $transdate = $form->{tax_point} ? $dbh->quote($form->{tax_point}) : $form->{transdate} ? $dbh->quote($form->{transdate}) : "current_date";

    $form->{taxzone_id} = 0 unless ($form->{taxzone_id});
    unshift @values, ($form->{taxzone_id}) x 2;

    # retrieve individual items
    # this query looks up all information about the items
    # stuff different from the whole will not be overwritten, but saved with a suffix.
    $query =
      qq|SELECT o.id AS orderitems_id,
           c1.accno AS inventory_accno, c1.new_chart_id AS inventory_new_chart, date($transdate) - c1.valid_from as inventory_valid,
           c2.accno AS income_accno,    c2.new_chart_id AS income_new_chart,    date($transdate) - c2.valid_from as income_valid,
           c3.accno AS expense_accno,   c3.new_chart_id AS expense_new_chart,   date($transdate) - c3.valid_from as expense_valid,
           oe.ordnumber AS ordnumber_oe, oe.transdate AS transdate_oe, oe.cusordnumber AS cusordnumber_oe,
           p.partnumber, p.part_type, p.listprice, o.description, o.qty,
           p.classification_id,
           o.sellprice, o.parts_id AS id, o.unit, o.discount, p.notes AS partnotes, p.part_type,
           o.reqdate, o.project_id, o.serialnumber, o.ship, o.lastcost,
           o.ordnumber, o.transdate, o.cusordnumber, o.subtotal, o.recurring_billing_mode, o.longdescription,
           o.price_factor_id, o.price_factor, o.marge_price_factor, o.active_price_source, o.active_discount_source,
           pr.projectnumber, p.formel,
           pg.partsgroup, o.pricegroup_id, (SELECT pricegroup FROM pricegroup WHERE id=o.pricegroup_id) as pricegroup,
           e.name as orderer, e.id as orderer_id
         FROM orderitems o
         JOIN parts p ON (o.parts_id = p.id)
         JOIN oe ON (o.trans_id = oe.id)
         LEFT JOIN chart c1 ON ((SELECT inventory_accno_id                   FROM buchungsgruppen WHERE id=p.buchungsgruppen_id) = c1.id)
         LEFT JOIN chart c2 ON ((SELECT tc.income_accno_id  FROM taxzone_charts tc WHERE tc.taxzone_id = ? and tc.buchungsgruppen_id = p.buchungsgruppen_id) = c2.id)
         LEFT JOIN chart c3 ON ((SELECT tc.expense_accno_id FROM taxzone_charts tc WHERE tc.taxzone_id = ? and tc.buchungsgruppen_id = p.buchungsgruppen_id) = c3.id)
         LEFT JOIN project pr ON (o.project_id = pr.id)
         LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
         LEFT JOIN employee e ON (o.orderer_id = e.id) | .
      ($form->{id}
       ? qq|WHERE o.trans_id = ?|
       : qq|WHERE o.trans_id IN (| . join(", ", map("?", @ids)) . qq|)|) .
      qq| ORDER BY o.trans_id, o.position|;

    @ids = $form->{id} ? ($form->{id}) : @ids;
    $sth = prepare_execute_query($form, $dbh, $query, @values);

    while ($ref = $sth->fetchrow_hashref("NAME_lc")) {
      # Retrieve custom variables.
      my $cvars = CVar->get_custom_variables(dbh        => $dbh,
                                             module     => 'IC',
                                             sub_module => 'orderitems',
                                             trans_id   => $ref->{orderitems_id},
                                            );
      map { $ref->{"ic_cvar_$_->{name}"} = $_->{value} } @{ $cvars };

      # Handle accounts.
      if (!$ref->{"part_type"} eq 'part') {
        map({ delete($ref->{$_}); } qw(inventory_accno inventory_new_chart inventory_valid));
      }
      # delete($ref->{"part_inventory_accno_id"});

      # in collective order, copy global ordnumber, transdate, cusordnumber into item scope
      #   unless already present there
      # remove _oe entries afterwards
      map { $ref->{$_} = $ref->{"${_}_oe"} if ($ref->{$_} eq '') }
        qw|ordnumber transdate cusordnumber|
        if (@ids);
      map { delete $ref->{$_} } qw|ordnumber_oe transdate_oe cusordnumber_oe|;



      while ($ref->{inventory_new_chart} && ($ref->{inventory_valid} >= 0)) {
        my $query =
          qq|SELECT accno AS inventory_accno, | .
          qq|  new_chart_id AS inventory_new_chart, | .
          qq|  date($transdate) - valid_from AS inventory_valid | .
          qq|FROM chart WHERE id = $ref->{inventory_new_chart}|;
        ($ref->{inventory_accno}, $ref->{inventory_new_chart},
         $ref->{inventory_valid}) = selectrow_query($form, $dbh, $query);
      }

      while ($ref->{income_new_chart} && ($ref->{income_valid} >= 0)) {
        my $query =
          qq|SELECT accno AS income_accno, | .
          qq|  new_chart_id AS income_new_chart, | .
          qq|  date($transdate) - valid_from AS income_valid | .
          qq|FROM chart WHERE id = $ref->{income_new_chart}|;
        ($ref->{income_accno}, $ref->{income_new_chart},
         $ref->{income_valid}) = selectrow_query($form, $dbh, $query);
      }

      while ($ref->{expense_new_chart} && ($ref->{expense_valid} >= 0)) {
        my $query =
          qq|SELECT accno AS expense_accno, | .
          qq|  new_chart_id AS expense_new_chart, | .
          qq|  date($transdate) - valid_from AS expense_valid | .
          qq|FROM chart WHERE id = $ref->{expense_new_chart}|;
        ($ref->{expense_accno}, $ref->{expense_new_chart},
         $ref->{expense_valid}) = selectrow_query($form, $dbh, $query);
      }

      # delete orderitems_id in collective orders, so that they get cloned no matter what
      # is this correct? or is the following meant?
      # remember orderitems_ids in converted_from_orderitems_ids, so that they may be linked
      $ref->{converted_from_orderitems_id} = delete $ref->{orderitems_id} if $is_collective_order;

      # get tax rates and description
      my $accno_id = ($form->{vc} eq "customer") ? $ref->{income_accno} : $ref->{expense_accno};
      $query =
        qq|SELECT c.accno, t.taxdescription, t.rate, t.id as tax_id, c.accno as taxnumber | .
        qq|FROM tax t | .
        qq|LEFT JOIN chart c on (c.id = t.chart_id) | .
        qq|WHERE t.id IN (SELECT tk.tax_id FROM taxkeys tk | .
        qq|               WHERE tk.chart_id = (SELECT id FROM chart WHERE accno = ?) | .
        qq|                 AND startdate <= $transdate ORDER BY startdate DESC LIMIT 1) | .
        qq|ORDER BY c.accno|;
      my $stw = prepare_execute_query($form, $dbh, $query, $accno_id);
      $ref->{taxaccounts} = "";
      my $i = 0;
      while (my $ptr = $stw->fetchrow_hashref("NAME_lc")) {
        if (($ptr->{accno} eq "") && ($ptr->{rate} == 0)) {
          $i++;
          $ptr->{accno} = $i;
        }
        $ref->{taxaccounts} .= "$ptr->{accno} ";
        if (!($form->{taxaccounts} =~ /\Q$ptr->{accno}\E/)) {
          $form->{"$ptr->{accno}_rate"}        = $ptr->{rate};
          $form->{"$ptr->{accno}_description"} = $ptr->{taxdescription};
          $form->{"$ptr->{accno}_taxnumber"}   = $ptr->{taxnumber};
          $form->{"$ptr->{accno}_tax_id"}      = $ptr->{tax_id};
          $form->{taxaccounts} .= "$ptr->{accno} ";
        }

      }

      chop $ref->{taxaccounts};

      push @{ $form->{form_details} }, $ref;
      $stw->finish;
    }
    $sth->finish;

  } else {

    # get last name used
    $form->lastname_used($dbh, $myconfig, $form->{vc})
      unless $form->{"$form->{vc}_id"};

  }

  $form->{exchangerate} = $form->check_exchangerate($myconfig, $form->{currency}, $form->{transdate}, ($form->{vc} eq 'customer') ? "buy" : "sell");

  Common::webdav_folder($form);

  $self->load_periodic_invoice_config($form);

  return 1;
}

sub retrieve_simple {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(id));

  my $myconfig    = \%main::myconfig;
  my $form        = $main::form;

  my $dbh         = $params{dbh} || $form->get_standard_dbh($myconfig);

  my $oe_query    = qq|SELECT * FROM oe         WHERE id = ?|;
  my $oi_query    = qq|SELECT * FROM orderitems WHERE trans_id = ? ORDER BY position|;

  my $order            = selectfirst_hashref_query($form, $dbh, $oe_query, conv_i($params{id}));
  $order->{orderitems} = selectall_hashref_query(  $form, $dbh, $oi_query, conv_i($params{id}));

  $main::lxdebug->leave_sub();

  return $order;
}

sub order_details {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = SL::DB->client->dbh;
  my $query;
  my @values = ();
  my $sth;
  my $nodiscount;
  my $yesdiscount;
  my $nodiscount_subtotal = 0;
  my $discount_subtotal = 0;
  my $item;
  my $i;
  my @partsgroup = ();
  my $partsgroup;
  my $position = 0;
  my $subtotal_header = 0;
  my $subposition = 0;
  my %taxaccounts;
  my %taxbase;
  my $tax_rate;
  my $taxamount;

  my (@project_ids);

  push(@project_ids, $form->{"globalproject_id"}) if ($form->{"globalproject_id"});

  $form->get_lists('price_factors' => 'ALL_PRICE_FACTORS');
  my %price_factors;

  foreach my $pfac (@{ $form->{ALL_PRICE_FACTORS} }) {
    $price_factors{$pfac->{id}}  = $pfac;
    $pfac->{factor}             *= 1;
    $pfac->{formatted_factor}    = $form->format_amount($myconfig, $pfac->{factor});
  }

  # sort items by partsgroup
  for $i (1 .. $form->{rowcount}) {
    $partsgroup = "";
    if ($form->{"partsgroup_$i"} && $form->{groupitems}) {
      $partsgroup = $form->{"partsgroup_$i"};
    }
    push @partsgroup, [$i, $partsgroup];
    push(@project_ids, $form->{"project_id_$i"}) if ($form->{"project_id_$i"});
  }

  my $projects = [];
  my %projects_by_id;
  if (@project_ids) {
    $projects = SL::DB::Manager::Project->get_all(query => [ id => \@project_ids ]);
    %projects_by_id = map { $_->id => $_ } @$projects;
  }

  if ($projects_by_id{$form->{"globalproject_id"}}) {
    $form->{globalprojectnumber} = $projects_by_id{$form->{"globalproject_id"}}->projectnumber;
    $form->{globalprojectdescription} = $projects_by_id{$form->{"globalproject_id"}}->description;

    for (@{ $projects_by_id{$form->{"globalproject_id"}}->cvars_by_config }) {
      $form->{"project_cvar_" . $_->config->name} = $_->value_as_text;
    }
  }

  $form->{discount} = [];

  # get some values of parts from db on store them in extra array,
  # so that they can be sorted in later
  my %prepared_template_arrays = IC->prepare_parts_for_printing(myconfig => $myconfig, form => $form);
  my @prepared_arrays          = keys %prepared_template_arrays;
  my @separate_totals          = qw(non_separate_subtotal);

  $form->{TEMPLATE_ARRAYS} = { };

  my $ic_cvar_configs = CVar->get_configs(module => 'IC');
  my $project_cvar_configs = CVar->get_configs(module => 'Projects');

  my @arrays =
    qw(runningnumber number description longdescription qty qty_nofmt ship ship_nofmt unit bin
       partnotes serialnumber reqdate sellprice sellprice_nofmt listprice listprice_nofmt netprice netprice_nofmt
       orderer
       discount discount_nofmt p_discount discount_sub discount_sub_nofmt nodiscount_sub nodiscount_sub_nofmt
       linetotal linetotal_nofmt nodiscount_linetotal nodiscount_linetotal_nofmt tax_rate projectnumber projectdescription
       price_factor price_factor_name partsgroup weight weight_nofmt lineweight lineweight_nofmt optional);

  push @arrays, map { "ic_cvar_$_->{name}" } @{ $ic_cvar_configs };
  push @arrays, map { "project_cvar_$_->{name}" } @{ $project_cvar_configs };

  my @tax_arrays = qw(taxbase tax taxdescription taxrate taxnumber);

  map { $form->{TEMPLATE_ARRAYS}->{$_} = [] } (@arrays, @tax_arrays, @prepared_arrays);

  my $totalweight = 0;
  my $sameitem = "";
  foreach $item (sort { $a->[1] cmp $b->[1] } @partsgroup) {
    $i = $item->[0];

    if ($item->[1] ne $sameitem) {
      push(@{ $form->{TEMPLATE_ARRAYS}->{entry_type}  }, 'partsgroup');
      push(@{ $form->{TEMPLATE_ARRAYS}->{description} }, qq|$item->[1]|);
      $sameitem = $item->[1];

      map({ push(@{ $form->{TEMPLATE_ARRAYS}->{$_} }, "") } grep({ $_ ne "description" } (@arrays, @prepared_arrays)));
    }

    $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});

    if ($form->{"id_$i"} != 0) {

      # add number, description and qty to $form->{number}, ....

      if ($form->{"subtotal_$i"} && !$subtotal_header) {
        $subtotal_header = $i;
        $position = int($position);
        $subposition = 0;
        $position++;
      } elsif ($subtotal_header) {
        $subposition += 1;
        $position = int($position);
        $position = $position.".".$subposition;
      } else {
        $position = int($position);
        $position++;
      }

      my $price_factor = $price_factors{$form->{"price_factor_id_$i"}} || { 'factor' => 1 };

      push(@{ $form->{TEMPLATE_ARRAYS}->{$_} },                $prepared_template_arrays{$_}[$i - 1]) for @prepared_arrays;

      push @{ $form->{TEMPLATE_ARRAYS}->{entry_type} },        'normal';
      push @{ $form->{TEMPLATE_ARRAYS}->{runningnumber} },     $position;
      push @{ $form->{TEMPLATE_ARRAYS}->{number} },            $form->{"partnumber_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{description} },       $form->{"description_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{longdescription} },   $form->{"longdescription_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{qty} },               $form->format_amount($myconfig, $form->{"qty_$i"});
      push @{ $form->{TEMPLATE_ARRAYS}->{qty_nofmt} },         $form->{"qty_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{ship} },              $form->format_amount($myconfig, $form->{"ship_$i"});
      push @{ $form->{TEMPLATE_ARRAYS}->{ship_nofmt} },        $form->{"ship_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{unit} },              $form->{"unit_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{bin} },               $form->{"bin_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{partnotes} },         $form->{"partnotes_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{serialnumber} },      $form->{"serialnumber_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{reqdate} },           $form->{"reqdate_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{sellprice} },         $form->{"sellprice_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{sellprice_nofmt} },   $form->parse_amount($myconfig, $form->{"sellprice_$i"});
      push @{ $form->{TEMPLATE_ARRAYS}->{listprice} },         $form->format_amount($myconfig, $form->{"listprice_$i"}, 2);
      push @{ $form->{TEMPLATE_ARRAYS}->{listprice_nofmt} },   $form->{"listprice_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{price_factor} },      $price_factor->{formatted_factor};
      push @{ $form->{TEMPLATE_ARRAYS}->{price_factor_name} }, $price_factor->{description};
      push @{ $form->{TEMPLATE_ARRAYS}->{partsgroup} },        $form->{"partsgroup_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{optional} },          $form->{"optional_$i"};

      my $sellprice     = $form->parse_amount($myconfig, $form->{"sellprice_$i"});
      my ($dec)         = ($sellprice =~ /\.(\d+)/);
      my $decimalplaces = max 2, length($dec);

      my $parsed_discount            = $form->parse_amount($myconfig, $form->{"discount_$i"});

      my $linetotal_exact            = $form->{"qty_$i"} * $sellprice * (100 - $parsed_discount) / 100 / $price_factor->{factor};
      my $linetotal                  = $form->round_amount($linetotal_exact, 2);

      my $nodiscount_exact_linetotal = $form->{"qty_$i"} * $sellprice                                  / $price_factor->{factor};
      my $nodiscount_linetotal       = $form->round_amount($nodiscount_exact_linetotal,2);

      my $discount                   = $nodiscount_linetotal - $linetotal; # is always rounded because $nodiscount_linetotal and $linetotal are rounded

      my $discount_round_error       = $discount + ($linetotal_exact - $nodiscount_exact_linetotal); # not used

      $form->{"netprice_$i"}   = $form->round_amount($form->{"qty_$i"} ? ($linetotal / $form->{"qty_$i"}) : 0, $decimalplaces);

      push @{ $form->{TEMPLATE_ARRAYS}->{netprice} },       ($form->{"netprice_$i"} != 0) ? $form->format_amount($myconfig, $form->{"netprice_$i"}, $decimalplaces) : '';
      push @{ $form->{TEMPLATE_ARRAYS}->{netprice_nofmt} }, ($form->{"netprice_$i"} != 0) ? $form->{"netprice_$i"} : '';

      $linetotal = ($linetotal != 0) ? $linetotal : '';

      push @{ $form->{TEMPLATE_ARRAYS}->{discount} },       ($discount != 0) ? $form->format_amount($myconfig, $discount * -1, 2) : '';
      push @{ $form->{TEMPLATE_ARRAYS}->{discount_nofmt} }, ($discount != 0) ? $discount * -1 : '';
      push @{ $form->{TEMPLATE_ARRAYS}->{p_discount} },     $form->{"discount_$i"};

      if ( $prepared_template_arrays{separate}[$i - 1]  ) {
        my $pabbr = $prepared_template_arrays{separate}[$i - 1];
        if ( ! $form->{"separate_${pabbr}_subtotal"} ) {
            push @separate_totals , "separate_${pabbr}_subtotal";
            $form->{"separate_${pabbr}_subtotal"} = 0;
        }
        $form->{"separate_${pabbr}_subtotal"} += $linetotal;
      } else {
        $form->{non_separate_subtotal} += $linetotal;
      }

      $form->{ordtotal}         += $linetotal unless $form->{"optional_$i"};
      $form->{nodiscount_total} += $nodiscount_linetotal;
      $form->{discount_total}   += $discount;

      if ($subtotal_header) {
        $discount_subtotal   += $linetotal;
        $nodiscount_subtotal += $nodiscount_linetotal;
      }

      if ($form->{"subtotal_$i"} && $subtotal_header && ($subtotal_header != $i)) {
        push @{ $form->{TEMPLATE_ARRAYS}->{discount_sub} },         $form->format_amount($myconfig, $discount_subtotal,   2);
        push @{ $form->{TEMPLATE_ARRAYS}->{discount_sub_nofmt} },   $discount_subtotal;
        push @{ $form->{TEMPLATE_ARRAYS}->{nodiscount_sub} },       $form->format_amount($myconfig, $nodiscount_subtotal, 2);
        push @{ $form->{TEMPLATE_ARRAYS}->{nodiscount_sub_nofmt} }, $nodiscount_subtotal;

        $discount_subtotal   = 0;
        $nodiscount_subtotal = 0;
        $subtotal_header     = 0;

      } else {
        push @{ $form->{TEMPLATE_ARRAYS}->{$_} }, "" for qw(discount_sub nodiscount_sub discount_sub_nofmt nodiscount_sub_nofmt);
      }

      if (!$form->{"discount_$i"}) {
        $nodiscount += $linetotal;
      }

      my $project = $projects_by_id{$form->{"project_id_$i"}} || SL::DB::Project->new;

      push @{ $form->{TEMPLATE_ARRAYS}->{linetotal} },                  $form->format_amount($myconfig, $linetotal, 2);
      push @{ $form->{TEMPLATE_ARRAYS}->{linetotal_nofmt} },            $linetotal_exact;
      push @{ $form->{TEMPLATE_ARRAYS}->{nodiscount_linetotal} },       $form->format_amount($myconfig, $nodiscount_linetotal, 2);
      push @{ $form->{TEMPLATE_ARRAYS}->{nodiscount_linetotal_nofmt} }, $nodiscount_linetotal;
      push @{ $form->{TEMPLATE_ARRAYS}->{projectnumber} },              $project->projectnumber;
      push @{ $form->{TEMPLATE_ARRAYS}->{projectdescription} },         $project->description;

      my $lineweight = $form->{"qty_$i"} * $form->{"weight_$i"};
      $totalweight += $lineweight;
      push @{ $form->{TEMPLATE_ARRAYS}->{weight} },            $form->format_amount($myconfig, $form->{"weight_$i"}, 3);
      push @{ $form->{TEMPLATE_ARRAYS}->{weight_nofmt} },      $form->{"weight_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}->{lineweight} },        $form->format_amount($myconfig, $lineweight, 3);
      push @{ $form->{TEMPLATE_ARRAYS}->{lineweight_nofmt} },  $lineweight;

      my ($taxamount, $taxbase);
      my $taxrate = 0;

      map { $taxrate += $form->{"${_}_rate"} } split(/ /, $form->{"taxaccounts_$i"});

      unless ($form->{"optional_$i"}) {
        if ($form->{taxincluded}) {

          # calculate tax
          $taxamount = $linetotal * $taxrate / (1 + $taxrate);
          $taxbase = $linetotal / (1 + $taxrate);
        } else {
          $taxamount = $linetotal * $taxrate;
          $taxbase   = $linetotal;
        }
      }

      if ($taxamount != 0) {
        foreach my $accno (split / /, $form->{"taxaccounts_$i"}) {
          $taxaccounts{$accno} += $taxamount * $form->{"${accno}_rate"} / $taxrate;
          $taxbase{$accno}     += $taxbase;
        }
      }

      $tax_rate = $taxrate * 100;
      push(@{ $form->{TEMPLATE_ARRAYS}->{tax_rate} }, qq|$tax_rate|);

      if ($form->{"part_type_$i"} eq 'assembly') {
        $sameitem = "";

        # get parts and push them onto the stack
        my $sortorder = "";
        if ($form->{groupitems}) {
          $sortorder = qq|ORDER BY pg.partsgroup, a.position|;
        } else {
          $sortorder = qq|ORDER BY a.position|;
        }

        $query = qq|SELECT p.partnumber, p.description, p.unit, a.qty, | .
                 qq|pg.partsgroup | .
                 qq|FROM assembly a | .
                 qq|  JOIN parts p ON (a.parts_id = p.id) | .
                 qq|    LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id) | .
                 qq|    WHERE a.bom = '1' | .
                 qq|    AND a.id = ? | . $sortorder;
        @values = ($form->{"id_$i"});
        $sth = $dbh->prepare($query);
        $sth->execute(@values) || $form->dberror($query);

        while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
          if ($form->{groupitems} && $ref->{partsgroup} ne $sameitem) {
            map({ push(@{ $form->{TEMPLATE_ARRAYS}->{$_} }, "") } grep({ $_ ne "description" } (@arrays, @prepared_arrays)));
            $sameitem = ($ref->{partsgroup}) ? $ref->{partsgroup} : "--";
            push(@{ $form->{TEMPLATE_ARRAYS}->{entry_type}  }, 'assembly-item-partsgroup');
            push(@{ $form->{TEMPLATE_ARRAYS}->{description} }, $sameitem);
          }

          push(@{ $form->{TEMPLATE_ARRAYS}->{entry_type}  }, 'assembly-item');
          push(@{ $form->{TEMPLATE_ARRAYS}->{description} }, $form->format_amount($myconfig, $ref->{qty} * $form->{"qty_$i"}) . qq|, $ref->{partnumber}, $ref->{description}|);
          map({ push(@{ $form->{TEMPLATE_ARRAYS}->{$_} }, "") } grep({ $_ ne "description" } (@arrays, @prepared_arrays)));
        }
        $sth->finish;
      }

      CVar->get_non_editable_ic_cvars(form               => $form,
                                      dbh                => $dbh,
                                      row                => $i,
                                      sub_module         => 'orderitems',
                                      may_converted_from => ['orderitems', 'invoice']);

      push @{ $form->{TEMPLATE_ARRAYS}->{"ic_cvar_$_->{name}"} },
        CVar->format_to_template(CVar->parse($form->{"ic_cvar_$_->{name}_$i"}, $_), $_)
          for @{ $ic_cvar_configs };

      push @{ $form->{TEMPLATE_ARRAYS}->{"project_cvar_" . $_->config->name} }, $_->value_as_text for @{ $project->cvars_by_config };
    }
  }

  $form->{totalweight}       = $form->format_amount($myconfig, $totalweight, 3);
  $form->{totalweight_nofmt} = $totalweight;
  my $defaults = AM->get_defaults();
  $form->{weightunit}        = $defaults->{weightunit};

  my $tax = 0;
  foreach $item (sort keys %taxaccounts) {
    $tax += $taxamount = $form->round_amount($taxaccounts{$item}, 2);

    push(@{ $form->{TEMPLATE_ARRAYS}->{taxbase} },        $form->format_amount($myconfig, $taxbase{$item}, 2));
    push(@{ $form->{TEMPLATE_ARRAYS}->{taxbase_nofmt} },  $taxbase{$item});
    push(@{ $form->{TEMPLATE_ARRAYS}->{tax} },            $form->format_amount($myconfig, $taxamount,      2));
    push(@{ $form->{TEMPLATE_ARRAYS}->{tax_nofmt} },      $taxamount);
    push(@{ $form->{TEMPLATE_ARRAYS}->{taxrate} },        $form->format_amount($myconfig, $form->{"${item}_rate"} * 100));
    push(@{ $form->{TEMPLATE_ARRAYS}->{taxrate_nofmt} },  $form->{"${item}_rate"} * 100);
    push(@{ $form->{TEMPLATE_ARRAYS}->{taxnumber} },      $form->{"${item}_taxnumber"});
    push(@{ $form->{TEMPLATE_ARRAYS}->{tax_id} },         $form->{"${item}_tax_id"});

    if ( $form->{"${item}_tax_id"} ) {
      my $tax_obj = SL::DB::Manager::Tax->find_by(id => $form->{"${item}_tax_id"}) or die "Can't find tax with id " . $form->{"${item}_tax_id"};
      my $description = $tax_obj ? $tax_obj->translated_attribute('taxdescription',  $form->{language_id}, 0) : '';
      push(@{ $form->{TEMPLATE_ARRAYS}->{taxdescription} }, $description . q{ } . 100 * $form->{"${item}_rate"} . q{%});
    }
  }

  $form->{nodiscount_subtotal} = $form->format_amount($myconfig, $form->{nodiscount_total}, 2);
  $form->{discount_total}      = $form->format_amount($myconfig, $form->{discount_total}, 2);
  $form->{nodiscount}          = $form->format_amount($myconfig, $nodiscount, 2);
  $form->{yesdiscount}         = $form->format_amount($myconfig, $form->{nodiscount_total} - $nodiscount, 2);

  if($form->{taxincluded}) {
    $form->{subtotal}       = $form->format_amount($myconfig, $form->{ordtotal} - $tax, 2);
    $form->{subtotal_nofmt} = $form->{ordtotal} - $tax;
  } else {
    $form->{subtotal}       = $form->format_amount($myconfig, $form->{ordtotal}, 2);
    $form->{subtotal_nofmt} = $form->{ordtotal};
  }

  my $grossamount = ($form->{taxincluded}) ? $form->{ordtotal} : $form->{ordtotal} + $tax;
  $form->{ordtotal} = $form->round_amount( $grossamount, 2, 1);
  $form->{rounding} = $form->round_amount(
    $form->{ordtotal} - $form->round_amount($grossamount, 2),
    2
  );

  # format amounts
  $form->{rounding} = $form->format_amount($myconfig, $form->{rounding}, 2);
  $form->{quototal} = $form->{ordtotal} = $form->format_amount($myconfig, $form->{ordtotal}, 2);

  $form->set_payment_options($myconfig, $form->{$form->{type} =~ /_quotation/ ? 'quodate' : 'orddate'}, $form->{type});

  $form->{username} = $myconfig->{name};

  $form->{department}    = SL::DB::Manager::Department->find_by(id => $form->{department_id})->description if $form->{department_id};
  $form->{delivery_term} = SL::DB::Manager::DeliveryTerm->find_by(id => $form->{delivery_term_id} || undef);
  $form->{delivery_term}->description_long($form->{delivery_term}->translated_attribute('description_long', $form->{language_id})) if $form->{delivery_term} && $form->{language_id};

  $form->{order} = SL::DB::Manager::Order->find_by(id => $form->{id}) if $form->{id};
  $form->{$_} = $form->format_amount($myconfig, $form->{$_}, 2) for @separate_totals;

  $main::lxdebug->leave_sub();
}

1;

__END__

=head1 NAME

OE.pm - Order entry module

=head1 DESCRIPTION

OE.pm is part of the OE module. OE is responsible for sales and purchase orders, as well as sales quotations and purchase requests. This file abstracts the database tables C<oe> and C<orderitems>.

=head1 FUNCTIONS

=over 4

=item retrieve_simple PARAMS

simple OE retrieval by id. does not look up customer, vendor, units or any other stuff. only oe and orderitems.

  my $order = retrieve_simple(id => 2);

  $order => {
    %_OE_CONTENT,
    orderitems => [
      %_ORDERITEM_ROW_1,
      %_ORDERITEM_ROW_2,
      ...
    ]
  }

=back

=cut
