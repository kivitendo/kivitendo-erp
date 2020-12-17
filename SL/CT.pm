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
# backend code for customers and vendors
#
# CHANGE LOG:
#   DS. 2000-07-04  Created
#
#======================================================================

package CT;

use SL::Common;
use SL::CVar;
use SL::DBUtils;
use SL::DB;
use Text::ParseWords;

use strict;

sub search {
  $main::lxdebug->enter_sub();

  my ( $self, $myconfig, $form ) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $cv = $form->{db} eq "customer" ? "customer" : "vendor";
  my $join_records = $form->{l_invnumber} || $form->{l_ordnumber} || $form->{l_quonumber};

  my $where = "1 = 1";
  my @values;

  my %allowed_sort_columns = (
      "id"                 => "ct.id",
      "customernumber"     => "ct.customernumber",
      "vendornumber"       => "ct.vendornumber",
      "name"               => "ct.name",
      "contact"            => "ct.contact",
      "phone"              => "ct.phone",
      "fax"                => "ct.fax",
      "email"              => "ct.email",
      "street"             => "ct.street",
      "taxnumber"          => "ct.taxnumber",
      "business"           => "b.description",
      "invnumber"          => "ct.invnumber",
      "ordnumber"          => "ct.ordnumber",
      "quonumber"          => "ct.quonumber",
      "zipcode"            => "ct.zipcode",
      "city"               => "ct.city",
      "country"            => "ct.country",
      "gln"                => "ct.gln",
      "discount"           => "ct.discount",
      "insertdate"         => "ct.itime",
      "salesman"           => "e.name",
      "payment"            => "pt.description",
      "pricegroup"         => "pg.pricegroup",
      "ustid"              => "ct.ustid",
      "creditlimit"        => "ct.creditlimit",
      "commercial_court"   => "ct.commercial_court",
    );

  $form->{sort} ||= "name";
  my $sortorder;
  if ( $join_records ) {
    # in UNION case order by hash key, e.g. salesman
    # the UNION created an implicit select around the result
    $sortorder = $allowed_sort_columns{$form->{sort}} ? $form->{sort} : "name";
  } else {
    # in not UNION case order by hash value, e.g. e.name
    $sortorder = $allowed_sort_columns{$form->{sort}} ?  $allowed_sort_columns{$form->{sort}} : "ct.name";
  }
  my $sortdir   = !defined $form->{sortdir} ? 'ASC' : $form->{sortdir} ? 'ASC' : 'DESC';

  if ($sortorder !~ /(business|creditlimit|id|discount|itime)/ && !$join_records) {
    $sortorder  = "lower($sortorder) ${sortdir}";
  } else {
    $sortorder .= " ${sortdir}";
  }

  if ($form->{"${cv}number"}) {
    $where .= " AND ct.${cv}number ILIKE ?";
    push(@values, like($form->{"${cv}number"}));
  }

  foreach my $key (qw(name contact email)) {
    if ($form->{$key}) {
      $where .= " AND ct.$key ILIKE ?";
      push(@values, like($form->{$key}));
    }
  }

  if ($form->{cp_name}) {
    $where .= " AND ct.id IN (SELECT cp_cv_id FROM contacts WHERE lower(cp_name) LIKE lower(?))";
    push @values, like($form->{cp_name});
  }

  if ($form->{addr_street}) {
    $where .= qq| AND ((ct.street ILIKE ?) | .
              qq|      OR | .
              qq|      (ct.id IN ( | .
              qq|         SELECT sc.trans_id FROM shipto sc | .
              qq|         WHERE (sc.module = 'CT') | .
              qq|           AND (sc.shiptostreet ILIKE ?) | .
              qq|      ))) |;
    push @values, (like($form->{addr_street})) x 2;
  }

  if ($form->{addr_zipcode}) {
    $where .= qq| AND ((ct.zipcode ILIKE ?) | .
              qq|      OR | .
              qq|      (ct.id IN ( | .
              qq|         SELECT sc.trans_id FROM shipto sc | .
              qq|         WHERE (sc.module = 'CT') | .
              qq|           AND (sc.shiptozipcode ILIKE ?) | .
              qq|      ))) |;
    push @values, (like($form->{addr_zipcode})) x 2;
  }

  if ($form->{addr_city}) {
    $where .= " AND ((lower(ct.city) LIKE lower(?))
                     OR
                     (ct.id IN (
                        SELECT sc.trans_id
                        FROM shipto sc
                        WHERE (sc.module = 'CT')
                          AND (lower(sc.shiptocity) LIKE lower(?))
                      ))
                     )";
    push @values, (like($form->{addr_city})) x 2;
  }

  if ($form->{addr_country}) {
    $where .= " AND ((lower(ct.country) LIKE lower(?))
                     OR
                     (ct.id IN (
                        SELECT so.trans_id
                        FROM shipto so
                        WHERE (so.module = 'CT')
                          AND (lower(so.shiptocountry) LIKE lower(?))
                      ))
                     )";
    push @values, (like($form->{addr_country})) x 2;
  }

  if ($form->{addr_gln}) {
    $where .= " AND ((lower(ct.gln) LIKE lower(?))
                     OR
                     (ct.id IN (
                        SELECT so.trans_id
                        FROM shipto so
                        WHERE (so.module = 'CT')
                          AND (lower(so.shiptogln) LIKE lower(?))
                      ))
                     )";
    push @values, (like($form->{addr_gln})) x 2;
  }

  if ( $form->{status} eq 'orphaned' ) {
    $where .=
      qq| AND ct.id NOT IN | .
      qq|   (SELECT o.${cv}_id FROM oe o, $cv cv WHERE cv.id = o.${cv}_id)|;
    if ($cv eq 'customer') {
      $where .=
        qq| AND ct.id NOT IN | .
        qq| (SELECT a.customer_id FROM ar a, customer cv | .
        qq|  WHERE cv.id = a.customer_id)|;
    }
    if ($cv eq 'vendor') {
      $where .=
        qq| AND ct.id NOT IN | .
        qq| (SELECT a.vendor_id FROM ap a, vendor cv | .
        qq|  WHERE cv.id = a.vendor_id)|;
    }
    $form->{l_invnumber} = $form->{l_ordnumber} = $form->{l_quonumber} = "";
  }

  if ($form->{obsolete} eq "Y") {
    $where .= qq| AND ct.obsolete|;
  } elsif ($form->{obsolete} eq "N") {
    $where .= qq| AND NOT ct.obsolete|;
  }

  if ($form->{business_id}) {
    $where .= qq| AND (ct.business_id = ?)|;
    push(@values, conv_i($form->{business_id}));
  }

  if ($form->{salesman_id}) {
    $where .= qq| AND (ct.salesman_id = ?)|;
    push(@values, conv_i($form->{salesman_id}));
  }

  if($form->{insertdatefrom}) {
    $where .= qq| AND (ct.itime::DATE >= ?)|;
    push@values, conv_date($form->{insertdatefrom});
  }

  if($form->{insertdateto}) {
    $where .= qq| AND (ct.itime::DATE <= ?)|;
    push @values, conv_date($form->{insertdateto});
  }

  if ($form->{all}) {
    my @tokens = parse_line('\s+', 0, $form->{all});
      $where .= qq| AND (
          ct.${cv}number ILIKE ? OR
          ct.name        ILIKE ?
          )| for @tokens;
    push @values, ("%$_%")x2 for @tokens;
  }

  if (($form->{create_zugferd_invoices} // '') ne '') {
    $where .= qq| AND (ct.create_zugferd_invoices = ?)|;
    push @values, $form->{create_zugferd_invoices};
  }

  my ($cvar_where, @cvar_values) = CVar->build_filter_query('module'         => 'CT',
                                                            'trans_id_field' => 'ct.id',
                                                            'filter'         => $form);

  if ($cvar_where) {
    $where .= qq| AND ($cvar_where)|;
    push @values, @cvar_values;
  }

  my $pg_select = $form->{l_pricegroup} ? qq|, pg.pricegroup as pricegroup | : '';
  my $pg_join   = $form->{l_pricegroup} ? qq|LEFT JOIN pricegroup pg ON (ct.pricegroup_id = pg.id) | : '';

  my $main_cp_select = '';
  if ($form->{l_main_contact_person}) {
    $main_cp_select =  qq/, (SELECT concat(cp.cp_givenname, ' ', cp.cp_name, ' | ', cp.cp_email, ' | ', cp.cp_phone1)
                              FROM contacts cp WHERE ct.id=cp.cp_cv_id AND cp.cp_main LIMIT 1)
                              AS main_contact_person /;
  }
  my $query =
    qq|SELECT ct.*, ct.itime::DATE AS insertdate, b.description AS business, e.name as salesman, | .
    qq|  pt.description as payment | .
    $pg_select .
    $main_cp_select .
    (qq|, NULL AS invnumber, NULL AS ordnumber, NULL AS quonumber, NULL AS invid, NULL AS module, NULL AS formtype, NULL AS closed | x!! $join_records) .
    qq|FROM $cv ct | .
    qq|LEFT JOIN business b ON (ct.business_id = b.id) | .
    qq|LEFT JOIN employee e ON (ct.salesman_id = e.id) | .
    qq|LEFT JOIN payment_terms pt ON (ct.payment_id = pt.id) | .
    $pg_join .
    qq|WHERE $where|;

  my @saved_values = @values;
  # redo for invoices, orders and quotations
  if ($join_records) {
    my $union = "UNION";

    if ($form->{l_invnumber}) {
      my $ar = $cv eq 'customer' ? 'ar' : 'ap';
      my $module = $ar eq 'ar' ? 'is' : 'ir';
      push(@values, @saved_values);
      $query .=
        qq| UNION | .
        qq|SELECT ct.*, ct.itime::DATE AS insertdate, b.description AS business, e.name as salesman, | .
        qq|  pt.description as payment | .
        $pg_select .
        qq|, a.invnumber, a.ordnumber, a.quonumber, a.id AS invid, | .
        qq|  '$module' AS module, 'invoice' AS formtype, | .
        qq|  (a.amount = a.paid) AS closed | .
        qq|FROM $cv ct | .
        qq|JOIN $ar a ON (a.${cv}_id = ct.id) | .
        qq|LEFT JOIN business b ON (ct.business_id = b.id) | .
        qq|LEFT JOIN employee e ON (ct.salesman_id = e.id) | .
        qq|LEFT JOIN payment_terms pt ON (ct.payment_id = pt.id) | .
        $pg_join .
        qq|WHERE $where AND (a.invoice = '1')|;
    }

    if ( $form->{l_ordnumber} ) {
      push(@values, @saved_values);
      $query .=
        qq| UNION | .
        qq|SELECT ct.*, ct.itime::DATE AS insertdate, b.description AS business, e.name as salesman, | .
        qq|  pt.description as payment | .
        $pg_select .
        qq|, ' ' AS invnumber, o.ordnumber, o.quonumber, o.id AS invid, | .
        qq|  'oe' AS module, 'order' AS formtype, o.closed | .
        qq|FROM $cv ct | .
        qq|JOIN oe o ON (o.${cv}_id = ct.id) | .
        qq|LEFT JOIN business b ON (ct.business_id = b.id) | .
        qq|LEFT JOIN employee e ON (ct.salesman_id = e.id) | .
        qq|LEFT JOIN payment_terms pt ON (ct.payment_id = pt.id) | .
        $pg_join .
        qq|WHERE $where AND (o.quotation = '0')|;
    }

    if ( $form->{l_quonumber} ) {
      push(@values, @saved_values);
      $query .=
        qq| UNION | .
        qq|SELECT ct.*, ct.itime::DATE AS insertdate, b.description AS business, e.name as salesman, | .
        qq|  pt.description as payment | .
        $pg_select .
        qq|, ' ' AS invnumber, o.ordnumber, o.quonumber, o.id AS invid, | .
        qq|  'oe' AS module, 'quotation' AS formtype, o.closed | .
        qq|FROM $cv ct | .
        qq|JOIN oe o ON (o.${cv}_id = ct.id) | .
        qq|LEFT JOIN business b ON (ct.business_id = b.id) | .
        qq|LEFT JOIN employee e ON (ct.salesman_id = e.id) | .
        qq|LEFT JOIN payment_terms pt ON (ct.payment_id = pt.id) | .
        $pg_join .
        qq|WHERE $where AND (o.quotation = '1')|;
    }
  }

  $query .= qq| ORDER BY $sortorder|;

  $form->{CT} = selectall_hashref_query($form, $dbh, $query, @values);

  $main::lxdebug->leave_sub();
}

sub get_contact {
  $main::lxdebug->enter_sub();

  my ( $self, $myconfig, $form ) = @_;

  die 'Missing argument: cp_id' unless $::form->{cp_id};

  my $dbh   = SL::DB->client->dbh;
  my $query =
    qq|SELECT * FROM contacts c | .
    qq|WHERE cp_id = ? ORDER BY cp_id limit 1|;
  my $sth = prepare_execute_query($form, $dbh, $query, $form->{cp_id});
  my $ref = $sth->fetchrow_hashref("NAME_lc");

  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $query = qq|SELECT COUNT(cp_id) AS used FROM (
    SELECT cp_id FROM oe UNION
    SELECT cp_id FROM ar UNION
    SELECT cp_id FROM ap UNION
    SELECT cp_id FROM delivery_orders
  ) AS cpid WHERE cp_id = ? OR ? = 0|;
  ($form->{cp_used}) = selectfirst_array_query($form, $dbh, $query, ($form->{cp_id})x2);

  $sth->finish;

  $main::lxdebug->leave_sub();
}

sub get_bank_info {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(vc id));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

  my $table        = $params{vc} eq 'customer' ? 'customer' : 'vendor';
  my @ids          = ref $params{id} eq 'ARRAY' ? @{ $params{id} } : ($params{id});
  my $placeholders = join ", ", ('?') x scalar @ids;
  my $c_mandate    = $params{vc} eq 'customer' ? ', mandator_id, mandate_date_of_signature' : '';
  my $query        = qq|SELECT id, name, account_number, bank, bank_code, iban, bic ${c_mandate}
                        FROM ${table}
                        WHERE id IN (${placeholders})|;

  my $result       = selectall_hashref_query($form, $dbh, $query, map { conv_i($_) } @ids);

  if (ref $params{id} eq 'ARRAY') {
    $result = { map { $_->{id} => $_ } @{ $result } };
  } else {
    $result = $result->[0] || { 'id' => $params{id} };
  }

  $main::lxdebug->leave_sub();

  return $result;
}

sub search_contacts {
  $::lxdebug->enter_sub;

  my $self      = shift;
  my %params    = @_;

  my $dbh       = $params{dbh} || $::form->get_standard_dbh;

  my %sortspecs = (
    'cp_name'   => 'cp_name, cp_givenname',
    'vcname'    => 'vcname, cp_name, cp_givenname',
    'vcnumber'  => 'vcnumber, cp_name, cp_givenname',
    );

  my %sortcols  = map { $_ => 1 } qw(cp_name cp_givenname cp_phone1 cp_phone2 cp_mobile1 cp_email cp_street cp_zipcode cp_city cp_position vcname vcnumber);

  my $order_by  = $sortcols{$::form->{sort}} ? $::form->{sort} : 'cp_name';
  $::form->{sort} = $order_by;
  $order_by     = $sortspecs{$order_by} if ($sortspecs{$order_by});

  my $sortdir   = $::form->{sortdir} ? 'ASC' : 'DESC';
  $order_by     =~ s/,/ ${sortdir},/g;
  $order_by    .= " $sortdir";

  my @where_tokens = ();
  my @values;

  if ($params{search_term}) {
    my @tokens;
    push @tokens,
      'cp.cp_name      ILIKE ?',
      'cp.cp_givenname ILIKE ?',
      'cp.cp_email     ILIKE ?';
    push @values, (like($params{search_term})) x 3;

    if (($params{search_term} =~ m/\d/) && ($params{search_term} !~ m/[^\d \(\)+\-]/)) {
      my $number =  $params{search_term};
      $number    =~ s/[^\d]//g;
      $number    =  join '[ /\(\)+\-]*', split(m//, $number);

      push @tokens, map { "($_ ~ '$number')" } qw(cp_phone1 cp_phone2 cp_mobile1 cp_mobile2);
    }

    push @where_tokens, map { "($_)" } join ' OR ', @tokens;
  }

  my ($cvar_where, @cvar_values) = CVar->build_filter_query('module'         => 'Contacts',
                                                            'trans_id_field' => 'cp.cp_id',
                                                            'filter'         => $params{filter});

  if ($cvar_where) {
    push @where_tokens, $cvar_where;
    push @values, @cvar_values;
  }

  if (my $filter = $params{filter}) {
    for (qw(name title givenname email project abteilung)) {
      next unless $filter->{"cp_$_"};
      add_token(\@where_tokens, \@values, col =>  "cp.cp_$_", val => $filter->{"cp_$_"}, method => 'ILIKE', esc => 'substr');
    }

    push @where_tokens, 'cp.cp_cv_id IS NOT NULL' if $filter->{status} eq 'active';
    push @where_tokens, 'cp.cp_cv_id IS NULL'     if $filter->{status} eq 'orphaned';
  }

  my $where = @where_tokens ? 'WHERE ' . join ' AND ', @where_tokens : '';

  my $query     = qq|SELECT cp.*,
                       COALESCE(c.id,             v.id)           AS vcid,
                       COALESCE(c.name,           v.name)         AS vcname,
                       COALESCE(c.customernumber, v.vendornumber) AS vcnumber,
                       CASE WHEN c.name IS NULL THEN 'vendor' ELSE 'customer' END AS db
                     FROM contacts cp
                     LEFT JOIN customer c ON (cp.cp_cv_id = c.id)
                     LEFT JOIN vendor v   ON (cp.cp_cv_id = v.id)
                     $where
                     ORDER BY $order_by|;

  my $contacts  = selectall_hashref_query($::form, $dbh, $query, @values);

  $::lxdebug->leave_sub;

  return @{ $contacts };
}


1;
