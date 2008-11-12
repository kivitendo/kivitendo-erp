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
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#======================================================================
#
#  Warehouse module
#
#======================================================================

package WH;

use SL::AM;
use SL::DBUtils;
use SL::Form;

sub transfer {
  $main::lxdebug->enter_sub();

  my $self = shift;

  if (!@_) {
    $main::lxdebug->leave_sub();
    return;
  }

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $form->get_standard_dbh($myconfig);

  my $units    = AM->retrieve_units($myconfig, $form);

  my $query    = qq|SELECT * FROM transfer_type|;
  my $sth      = prepare_execute_query($form, $dbh, $query);

  my %transfer_types;

  while (my $ref = $sth->fetchrow_hashref()) {
    $transfer_types{$ref->{direction}} ||= { };
    $transfer_types{$ref->{direction}}->{$ref->{description}} = $ref->{id};
  }

  my @part_ids  = map { $_->{parts_id} } @_;
  my %partunits = selectall_as_map($form, $dbh, qq|SELECT id, unit FROM parts WHERE id IN (| . join(', ', map { '?' } @part_ids ) . qq|)|, 'id', 'unit', @part_ids);

  my ($now)     = selectrow_query($form, $dbh, qq|SELECT current_date|);

  $query = qq|INSERT INTO inventory (warehouse_id, bin_id, parts_id, chargenumber, oe_id, orderitems_id, shippingdate,
                                     employee_id, project_id, trans_id, trans_type_id, comment, qty)
              VALUES (?, ?, ?, ?, ?, ?, ?, (SELECT id FROM employee WHERE login = ?), ?, ?, ?, ?, ?)|;

  $sth   = prepare_query($form, $dbh, $query);

  my @directions = (undef, 'out', 'in', 'transfer');

  while (@_) {
    my $transfer   = shift;
    my ($trans_id) = selectrow_query($form, $dbh, qq|SELECT nextval('id')|);

    my ($direction, @values) = (0);

    $direction |= 1 if ($transfer->{src_warehouse_id} && $transfer->{src_bin_id});
    $direction |= 2 if ($transfer->{dst_warehouse_id} && $transfer->{dst_bin_id});

    push @values, conv_i($transfer->{parts_id}), "$transfer->{chargenumber}", conv_i($transfer->{oe_id}), conv_i($transfer->{orderitems_id});
    push @values, $transfer->{shippingdate} eq 'current_date' ? $now : conv_date($transfer->{shippingdate}), $form->{login}, conv_i($transfer->{project_id}), $trans_id;

    if ($transfer->{transfer_type_id}) {
      push @values, $transfer->{transfer_type_id};
    } else {
      push @values, $transfer_types{$directions[$direction]}->{$transfer->{transfer_type}};
    }

    push @values, "$transfer->{comment}";

    my $qty = $transfer->{qty};

    if ($transfer->{unit}) {
      my $partunit = $partunits{$transfer->{parts_id}};

      $qty *= $units->{$transfer->{unit}}->{factor};
      $qty /= $units->{$partunit}->{factor} || 1 if ($partunit);
    }

    if ($direction & 1) {
      do_statement($form, $sth, $query, conv_i($transfer->{src_warehouse_id}), conv_i($transfer->{src_bin_id}), @values, $qty * -1);
    }

    if ($direction & 2) {
      do_statement($form, $sth, $query, conv_i($transfer->{dst_warehouse_id}), conv_i($transfer->{dst_bin_id}), @values, $qty);
    }
  }

  $sth->finish();

  $dbh->commit();

  $main::lxdebug->leave_sub();
}

sub get_warehouse_journal {
  $main::lxdebug->enter_sub();

  my $self      = shift;
  my %filter    = @_;

  my $myconfig  = \%main::myconfig;
  my $form      = $main::form;

  my $all_units = AM->retrieve_units($myconfig, $form);

  # connect to database
  my $dbh = $form->get_standard_dbh($myconfig);

  # filters
  my (@filter_ary, @filter_vars, $joins);

  if ($filter{warehouse_id} ne '') {
    push @filter_ary, "w1.id = ? OR w2.id = ?";
    push @filter_vars, $filter{warehouse_id}, $filter{warehouse_id};
  }

  if ($filter{bin_id} ne '') {
    push @filter_ary, "b1.id = ? OR b2.id = ?";
    push @filter_vars, $filter{bin_id}, $filter{bin_id};
  }

  if ($filter{partnumber}) {
    push @filter_ary, "p.partnumber ILIKE ?";
    push @filter_vars, '%' . $filter{partnumber} . '%';
  }

  if ($filter{description}) {
    push @filter_ary, "(p.description ILIKE ?)";
    push @filter_vars, '%' . $filter{description} . '%';
  }

  if ($filter{chargenumber}) {
    push @filter_ary, "i1.chargenumber ILIKE ?";
    push @filter_vars, '%' . $filter{chargenumber} . '%';
  }

  if ($form->{fromdate}) {
    push @filter_ary, "?::DATE <= i1.itime::DATE";
    push @filter_vars, $form->{fromdate};
  }

  if ($form->{todate}) {
    push @filter_ary, "?::DATE >= i1.itime::DATE";
    push @filter_vars, $form->{todate};
  }

  if ($form->{l_employee}) {
    $joins .= "";
  }

  # prepare qty comparison for later filtering
  my ($f_qty_op, $f_qty, $f_qty_base_unit);
  if ($filter{qty_op} && defined($filter{qty}) && $filter{qty_unit} && $all_units->{$filter{qty_unit}}) {
    $f_qty_op        = $filter{qty_op};
    $f_qty           = $filter{qty} * $all_units->{$filter{qty_unit}}->{factor};
    $f_qty_base_unit = $all_units->{$filter{qty_unit}}->{base_unit};
  }

  map { $_ = "(${_})"; } @filter_ary;

  # if of a property number or description is requested,
  # automatically check the matching id too.
  map { $form->{"l_${_}id"} = "Y" if ($form->{"l_${_}description"} || $form->{"l_${_}number"}); } qw(warehouse bin);

  # customize shown entry for not available fields.
  $filter{na} = '-' unless $filter{na};

  # make order, search in $filter and $form
  $form->{sort}   = $filter{sort}             unless $form->{sort};
  $form->{order}  = ($form->{sort} = 'itime') unless $form->{sort};
  $form->{sort}   = 'itime'                   if     $form->{sort} eq "date";
  $form->{order}  = $filter{order}            unless $form->{order};
  $form->{sort}  .= (($form->{order}) ? " DESC" : " ASC");

  my $where_clause = join(" AND ", @filter_ary) . " AND " if (@filter_ary);

  $select_tokens{'trans'} = {
     "parts_id"             => "i1.parts_id",
     "qty"                  => "ABS(SUM(i1.qty))",
     "partnumber"           => "p.partnumber",
     "partdescription"      => "p.description",
     "bindescription"       => "b.description",
     "chargenumber"         => "i1.chargenumber",
     "warehousedescription" => "w.description",
     "partunit"             => "p.unit",
     "bin_from"             => "b1.description",
     "bin_to"               => "b2.description",
     "warehouse_from"       => "w1.description",
     "warehouse_to"         => "w2.description",
     "comment"              => "i1.comment",
     "trans_type"           => "tt.description",
     "trans_id"             => "i1.trans_id",
     "date"                 => "i1.itime::DATE",
     "itime"                => "i1.itime",
     "employee"             => "e.name",
     "projectnumber"        => "COALESCE(pr.projectnumber, '$filter{na}')",
     };

  $select_tokens{'out'} = {
     "bin_to"               => "'$filter{na}'",
     "warehouse_to"         => "'$filter{na}'",
     };

  $select_tokens{'in'} = {
     "bin_from"             => "'$filter{na}'",
     "warehouse_from"       => "'$filter{na}'",
     };

  # build the select clauses.
  # take all the requested ones from the first hash and overwrite them from the out/in hashes if present.
  for my $i ('trans', 'out', 'in') {
    $select{$i} = join ', ', map { +/^l_/; ($select_tokens{$i}{"$'"} || $select_tokens{'trans'}{"$'"}) . " AS r_$'" }
          ( grep( { !/qty$/ and /^l_/ and $form->{$_} eq 'Y' } keys %$form), qw(l_parts_id l_qty l_partunit l_itime) );
  }

  my $group_clause = join ", ", map { +/^l_/; "r_$'" }
        ( grep( { !/qty$/ and /^l_/ and $form->{$_} eq 'Y' } keys %$form), qw(l_parts_id l_partunit l_itime) );

  my $query =
  qq|SELECT DISTINCT $select{trans}
    FROM inventory i1
    LEFT JOIN inventory i2 ON i1.trans_id = i2.trans_id
    LEFT JOIN parts p ON i1.parts_id = p.id
    LEFT JOIN bin b1 ON i1.bin_id = b1.id
    LEFT JOIN bin b2 ON i2.bin_id = b2.id
    LEFT JOIN warehouse w1 ON i1.warehouse_id = w1.id
    LEFT JOIN warehouse w2 ON i2.warehouse_id = w2.id
    LEFT JOIN transfer_type tt ON i1.trans_type_id = tt.id
    LEFT JOIN project pr ON i1.project_id = pr.id
    LEFT JOIN employee e ON i1.employee_id = e.id
    WHERE $where_clause i2.qty = -i1.qty AND i2.qty > 0 AND
          i1.trans_id IN ( SELECT i.trans_id FROM inventory i GROUP BY i.trans_id HAVING COUNT(i.trans_id) = 2 )
    GROUP BY $group_clause

    UNION

    SELECT DISTINCT $select{out}
    FROM inventory i1
    LEFT JOIN inventory i2 ON i1.trans_id = i2.trans_id
    LEFT JOIN parts p ON i1.parts_id = p.id
    LEFT JOIN bin b1 ON i1.bin_id = b1.id
    LEFT JOIN bin b2 ON i2.bin_id = b2.id
    LEFT JOIN warehouse w1 ON i1.warehouse_id = w1.id
    LEFT JOIN warehouse w2 ON i2.warehouse_id = w2.id
    LEFT JOIN transfer_type tt ON i1.trans_type_id = tt.id
    LEFT JOIN project pr ON i1.project_id = pr.id
    LEFT JOIN employee e ON i1.employee_id = e.id
    WHERE $where_clause i1.qty < 0 AND
          i1.trans_id IN ( SELECT i.trans_id FROM inventory i GROUP BY i.trans_id HAVING COUNT(i.trans_id) = 1 )
    GROUP BY $group_clause

    UNION

    SELECT DISTINCT $select{in}
    FROM inventory i1
    LEFT JOIN inventory i2 ON i1.trans_id = i2.trans_id
    LEFT JOIN parts p ON i1.parts_id = p.id
    LEFT JOIN bin b1 ON i1.bin_id = b1.id
    LEFT JOIN bin b2 ON i2.bin_id = b2.id
    LEFT JOIN warehouse w1 ON i1.warehouse_id = w1.id
    LEFT JOIN warehouse w2 ON i2.warehouse_id = w2.id
    LEFT JOIN transfer_type tt ON i1.trans_type_id = tt.id
    LEFT JOIN project pr ON i1.project_id = pr.id
    LEFT JOIN employee e ON i1.employee_id = e.id
    WHERE $where_clause i1.qty > 0 AND
          i1.trans_id IN ( SELECT i.trans_id FROM inventory i GROUP BY i.trans_id HAVING COUNT(i.trans_id) = 1 )
    GROUP BY $group_clause
    ORDER BY r_$form->{sort}|;

  my $sth = prepare_execute_query($form, $dbh, $query, @filter_vars, @filter_vars, @filter_vars);

  my @contents = ();
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    map { /^r_/; $ref->{"$'"} = $ref->{$_} } keys %$ref;
    my $qty = $ref->{"qty"} * 1;

    next unless ($qty > 0);

    if ($f_qty_op) {
      my $part_unit = $all_units->{$ref->{"partunit"}};
      next unless ($part_unit && ($part_unit->{"base_unit"} eq $f_qty_base_unit));
      $qty *= $part_unit->{"factor"};
      next if (('=' eq $f_qty_op) && ($qty != $f_qty));
      next if (('>=' eq $f_qty_op) && ($qty < $f_qty));
      next if (('<=' eq $f_qty_op) && ($qty > $f_qty));
    }

    push @contents, $ref;
  }

  $sth->finish();

  $main::lxdebug->leave_sub();

  return @contents;
}

#
# This sub is the primary function to retrieve information about items in warehouses.
# $filter is a hashref and supports the following keys:
#  - warehouse_id - will return matches with this warehouse_id only
#  - partnumber   - will return only matches where the given string is a substring of the partnumber
#  - partsid      - will return matches with this parts_id only
#  - description  - will return only matches where the given string is a substring of the description
#  - chargenumber - will return only matches where the given string is a substring of the chargenumber
#  - charge_ids   - must be an arrayref. will return contents with these ids only
#  - expires_in   - will only return matches that expire within the given number of days
#                   will also add a column named 'has_expired' containing if the match has already expired or not
#  - hazardous    - will return matches with the flag hazardous only
#  - oil          - will return matches with the flag oil only
#  - qty, qty_op  - quantity filter (more info to come)
#  - sort, order_by - sorting (more to come)
#  - reservation  - will provide an extra column containing the amount reserved of this match
# note: reservation flag turns off warehouse_* or bin_* information. both together don't make sense, since reserved info is stored separately
#
sub get_warehouse_report {
  $main::lxdebug->enter_sub();

  my $self      = shift;
  my %filter    = @_;

  my $myconfig  = \%main::myconfig;
  my $form      = $main::form;

  my $all_units = AM->retrieve_units($myconfig, $form);

  # connect to database
  my $dbh = $form->get_standard_dbh($myconfig);

  # filters
  my (@filter_ary, @filter_vars, @wh_bin_filter_ary, @wh_bin_filter_vars, $columns, $group_by);

  delete $form->{include_empty_bins} unless ($form->{l_warehousedescription} || $form->{l_bindescription});

  if ($filter{warehouse_id}) {
    push @wh_bin_filter_ary,  "w.id = ?";
    push @wh_bin_filter_vars, $filter{warehouse_id};
  }

  if ($filter{bin_id}) {
    push @wh_bin_filter_ary,  "b.id = ?";
    push @wh_bin_filter_vars, $filter{bin_id};
  }

  push @filter_ary,  @wh_bin_filter_ary;
  push @filter_vars, @wh_bin_filter_vars;

  if ($filter{partnumber}) {
    push @filter_ary,  "p.partnumber ILIKE ?";
    push @filter_vars, '%' . $filter{partnumber} . '%';
  }

  if ($filter{description}) {
    push @filter_ary,  "p.description ILIKE ?";
    push @filter_vars, '%' . $filter{description} . '%';
  }

  if ($filter{partsid}) {
    push @filter_ary,  "p.id = ?";
    push @filter_vars, $filter{partsid};
  }

  if ($filter{chargenumber}) {
    push @filter_ary,  "i.chargenumber ILIKE ?";
    push @filter_vars, '%' . $filter{chargenumber} . '%';
  }

  # prepare qty comparison for later filtering
  my ($f_qty_op, $f_qty, $f_qty_base_unit);

  if ($filter{qty_op} && defined $filter{qty} && $filter{qty_unit} && $all_units->{$filter{qty_unit}}) {
    $f_qty_op        = $filter{qty_op};
    $f_qty           = $filter{qty} * $all_units->{$filter{qty_unit}}->{factor};
    $f_qty_base_unit = $all_units->{$filter{qty_unit}}->{base_unit};
  }

  map { $_ = "(${_})"; } @filter_ary;

  # if of a property number or description is requested,
  # automatically check the matching id too.
  map { $form->{"l_${_}id"} = "Y" if ($form->{"l_${_}description"} || $form->{"l_${_}number"}); } qw(warehouse bin);

  # make order, search in $filter and $form
  $form->{sort}  =  $filter{sort}  unless $form->{sort};
  $form->{sort}  =  "parts_id"     unless $form->{sort};
  $form->{order} =  $filter{order} unless $form->{order};
  $form->{sort}  =~ s/ASC|DESC//; # kill stuff left in from previous queries
  my $orderby    =  $form->{sort};
  $form->{sort} .=  (($form->{order}) ? " DESC" : " ASC");

  my $where_clause = join " AND ", ("1=1", @filter_ary);

  my %select_tokens = (
     "parts_id"              => "i.parts_id",
     "qty"                  => "SUM(i.qty)",
     "warehouseid"          => "i.warehouse_id",
     "partnumber"           => "p.partnumber",
     "partdescription"      => "p.description",
     "bindescription"       => "b.description",
     "binid"                => "b.id",
     "chargenumber"         => "i.chargenumber",
     "chargeid"             => "c.id",
     "warehousedescription" => "w.description",
     "partunit"             => "p.unit",
  );
  my $select_clause = join ', ', map { +/^l_/; "$select_tokens{$'} AS $'" }
        ( grep( { !/qty/ and /^l_/ and $form->{$_} eq 'Y' } keys %$form),
          qw(l_parts_id l_qty l_partunit) );

  my $group_clause = join ", ", map { +/^l_/; "$'" }
        ( grep( { !/qty/ and /^l_/ and $form->{$_} eq 'Y' } keys %$form),
          qw(l_parts_id l_partunit) );

  my $query =
    qq|SELECT $select_clause
      $columns
      FROM inventory i
      LEFT JOIN parts     p ON i.parts_id     = p.id
      LEFT JOIN bin       b ON i.bin_id       = b.id
      LEFT JOIN warehouse w ON i.warehouse_id = w.id
      WHERE $where_clause
      GROUP BY $group_clause $group_by
      ORDER BY $form->{sort}|;

  my $sth = prepare_execute_query($form, $dbh, $query, @filter_vars);

  my (%non_empty_bins, @all_fields, @contents);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{qty} *= 1;
    my $qty      = $ref->{qty};

    next unless ($qty > 0);

    if ($f_qty_op) {
      my $part_unit = $all_units->{$ref->{partunit}};
      next if (!$part_unit || ($part_unit->{base_unit} ne $f_qty_base_unit));
      $qty *= $part_unit->{factor};
      next if (('='  eq $f_qty_op) && ($qty != $f_qty));
      next if (('>=' eq $f_qty_op) && ($qty <  $f_qty));
      next if (('<=' eq $f_qty_op) && ($qty >  $f_qty));
    }

    if ($form->{include_empty_bins}) {
      $non_empty_bins{$ref->{binid}} = 1;
      @all_fields                    = keys %{ $ref } unless (@all_fields);
    }

    push @contents, $ref;
  }

  $sth->finish();

  if ($form->{include_empty_bins}) {
    $query =
      qq|SELECT
           w.id AS warehouseid, w.description AS warehousedescription,
           b.id AS binid, b.description AS bindescription
         FROM bin b
         LEFT JOIN warehouse w ON (b.warehouse_id = w.id)|;

    @filter_ary  = @wh_bin_filter_ary;
    @filter_vars = @wh_bin_filter_vars;

    my @non_empty_bin_ids = keys %non_empty_bins;
    if (@non_empty_bin_ids) {
      push @filter_ary,  qq|NOT b.id IN (| . join(', ', map { '?' } @non_empty_bin_ids) . qq|)|;
      push @filter_vars, @non_empty_bin_ids;
    }

    $query .= qq| WHERE | . join(' AND ', map { "($_)" } @filter_ary) if (@filter_ary);

    $sth    = prepare_execute_query($form, $dbh, $query, @filter_vars);

    while ($ref = $sth->fetchrow_hashref()) {
      map { $ref->{$_} ||= "" } @all_fields;
      push @contents, $ref;
    }
    $sth->finish();

    if (grep { $orderby eq $_ } qw(bindescription warehousedescription)) {
      @contents = sort { ($a->{$orderby} cmp $b->{$orderby}) * (($form->{order}) ? 1 : -1) } @contents;
    }
  }

  $main::lxdebug->leave_sub();

  return @contents;
}

sub convert_qty_op {
  $main::lxdebug->enter_sub();

  my ($self, $qty_op) = @_;

  if (!$qty_op || ($qty_op eq "dontcare")) {
    $main::lxdebug->leave_sub();
    return undef;
  }

  if ($qty_op eq "atleast") {
    $qty_op = '>=';
  } elsif ($qty_op eq "atmost") {
    $qty_op = '<=';
  } else {
    $qty_op = '=';
  }

  $main::lxdebug->leave_sub();

  return $qty_op;
}

sub retrieve_transfer_types {
  $main::lxdebug->enter_sub();

  my $self      = shift;
  my $direction = shift;

  my $myconfig  = \%main::myconfig;
  my $form      = $main::form;

  my $dbh       = $form->get_standard_dbh($myconfig);

  my $types     = selectall_hashref_query($form, $dbh, qq|SELECT * FROM transfer_type WHERE direction = ? ORDER BY sortkey|, $direction);

  $main::lxdebug->leave_sub();

  return $types;
}

sub get_basic_bin_info {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(id));

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh();

  my @ids      = 'ARRAY' eq ref $params{id} ? @{ $params{id} } : ($params{id});

  my $query    =
    qq|SELECT b.id AS bin_id, b.description AS bin_description,
         w.id AS warehouse_id, w.description AS warehouse_description
       FROM bin b
       LEFT JOIN warehouse w ON (b.warehouse_id = w.id)
       WHERE b.id IN (| . join(', ', ('?') x scalar(@ids)) . qq|)|;

  my $result = selectall_hashref_query($form, $dbh, $query, map { conv_i($_) } @ids);

  if ('' eq ref $params{id}) {
    $result = $result->[0] || { };
    $main::lxdebug->leave_sub();

    return $result;
  }

  $main::lxdebug->leave_sub();

  return map { $_->{bin_id} => $_ } @{ $result };
}


1;
