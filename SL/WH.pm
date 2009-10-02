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
use warnings;
#use strict;
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

sub transfer_assembly {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;
  Common::check_params(\%params, qw(assembly_id dst_warehouse_id login qty unit dst_bin_id chargenumber comment));

#  my $maxcreate=WH->check_assembly_max_create(assembly_id =>$params{'assembly_id'}, dbh => $my_dbh);

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;
  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);


  # Ablauferklärung
  #
  # ... Standard-Check oben Ende. Hier die eigentliche SQL-Abfrage
  # select parts_id,qty from assembly where id=1064;
  # Erweiterung für bug 935 am 23.4.09 - Erzeugnisse können Dienstleistungen enthalten, die ja nicht 'lagerbar' sind.
  # select parts_id,qty from assembly inner join parts on assembly.parts_id = parts.id  where assembly.id=1066 and inventory_accno_id IS NOT NULL;
  # Erweiterung für bug 23.4.09 -2 Erzeugnisse in Erzeugnissen können nicht ausgelagert werden, wenn assembly nicht überprüft wird ...
  # patch von joachim eingespielt 24.4.2009:
  # my $query    = qq|select parts_id,qty from assembly inner join parts
  # on assembly.parts_id = parts.id  where assembly.id = ? and
  # (inventory_accno_id IS NOT NULL or parts.assembly = TRUE)|;


  # my $query    = qq|select parts_id,qty from assembly where id = ?|;
  my $query	= qq|select parts_id,qty from assembly inner join parts on assembly.parts_id = parts.id  where assembly.id = ? and (inventory_accno_id IS NOT NULL or parts.assembly = TRUE)|;

  my $sth_part_qty_assembly      = prepare_execute_query($form, $dbh, $query, $params{assembly_id});

  # Hier wird das prepared Statement für die Schleife über alle Lagerplätze vorbereitet
  my $transferPartSQL = qq|INSERT INTO inventory (parts_id, warehouse_id, bin_id, chargenumber, comment, employee_id, qty, trans_id, trans_type_id)
			    VALUES (?, ?, ?, ?, ?,(SELECT id FROM employee WHERE login = ?), ?, nextval('id'),
				    (SELECT id FROM transfer_type WHERE direction = 'out' AND description = 'used'))|;
  my $sthTransferPartSQL   = prepare_query($form, $dbh, $transferPartSQL);

  my $kannNichtFertigen ="";	# der return-string für die fehlermeldung inkl. welche waren zum fertigen noch fehlen

  while (my $hash_ref = $sth_part_qty_assembly->fetchrow_hashref()) {	# Schleife für $query=select parts_id,qty from assembly

    my $partsQTY = $hash_ref->{qty} * $params{qty}; # benötigte teile * anzahl erzeugnisse
    my $currentPart_ID = $hash_ref->{parts_id};

    # Überprüfen, ob diese Anzahl gefertigt werden kann
    my $max_parts = get_max_qty_parts($self, parts_id => $currentPart_ID, warehouse_id => $params{dst_warehouse_id}); #$self angeben, damit die Standardkonvention (Name, Parameter) eingehalten wird

    if ($partsQTY  > $max_parts){
      # Gibt es hier ein Problem mit nicht "escapten" Zeichen? 25.4.09 Antwort: Ja.  Aber erst wenn im Frontend die locales-Funktion aufgerufen wird
      $kannNichtFertigen .= "Zum Fertigen fehlen:" . abs($partsQTY - $max_parts) . " Einheiten der Ware:" . get_part_description($self, parts_id => $currentPart_ID) . ", um das Erzeugnis herzustellen. <br>";	# Konnte die Menge nicht mit der aktuellen Anzahl der Waren fertigen
      next;	# die weiteren Überprüfungen sind unnötig
    }

    # Eine kurze Vorabfrage, um den Lagerplatz und die Chargennummber zu bestimmen
    # Offen: Die Summe über alle Lagerplätze wird noch nicht gebildet
    # Gelöst: Wir haben vorher schon die Abfrage durchgeführt, ob wir fertigen können.
    # Noch besser gelöst: Wir laufen durch alle benötigten Waren zum Fertigen und geben eine Rückmeldung an den Benutzer was noch fehlt
    # und lösen den Rest dann so wie bei xplace im Barcode-Programm
    # S.a. Kommentar im bin/mozilla-Code mb übernimmt und macht das in ordentlich

    my $tempquery =	qq|SELECT SUM(qty), bin_id, chargenumber   FROM inventory  WHERE warehouse_id = ? AND parts_id = ?  GROUP BY bin_id, chargenumber having SUM(qty)>0|;
    my $tempsth	  =	prepare_execute_query($form, $dbh, $tempquery, $params{dst_warehouse_id}, $currentPart_ID);

    # Alle Werte zu dem einzelnen Artikel, die wir später auslagern
    my $tmpPartsQTY = $partsQTY;

    while (my $temphash_ref = $tempsth->fetchrow_hashref()) {
      my $temppart_bin_id	= $temphash_ref->{bin_id}; # kann man hier den quelllagerplatz beim verbauen angeben?
      my $temppart_chargenumber	= $temphash_ref->{chargenumber};
      my $temppart_qty	= $temphash_ref->{sum};
      if ($tmpPartsQTY > $temppart_qty) {	# wir haben noch mehr waren zum wegbuchen. Wir buchen den kompletten Lagerplatzbestand und zählen die Hilfsvariable runter
	$tmpPartsQTY = $tmpPartsQTY - $temppart_qty;
	$temppart_qty = $temppart_qty * -1;	# beim analyiseren des sql-trace, war dieser wert positiv, wenn * -1 als berechnung in der parameter-übergabe angegeben wird. Dieser Wert IST und BLEIBT positiv!! Hilfe. Liegt das daran, dass dieser Wert aus einem SQL-Statement stammt?
	do_statement($form, $sthTransferPartSQL, $transferPartSQL, $currentPart_ID, $params{dst_warehouse_id}, $temppart_bin_id, $temppart_chargenumber, 'Verbraucht für ' . get_part_description($self, parts_id => $params{assembly_id}), $params{login}, $temppart_qty);

	# hier ist noch ein fehler am besten mit definierten erzeugnissen debuggen 02/2009 jb
	# idee: ausbuch algorithmus mit rekursion lösen und an- und abschaltbar machen
	# das problem könnte sein, dass strict nicht an war und sth global eine andere zuweisung bekam
	# auf jeden fall war der internal-server-error nach aktivierung von strict und warnings plus ein paar my-definitionen weg
      }	else {	# okay, wir haben weniger oder gleich Waren die wir wegbuchen müssen, wir können also aufhören
	$tmpPartsQTY *=-1;
        do_statement($form, $sthTransferPartSQL, $transferPartSQL, $currentPart_ID, $params{dst_warehouse_id}, $temppart_bin_id, $temppart_chargenumber, 'Verbraucht für ' . get_part_description($self, parts_id => $params{assembly_id}), $params{login}, $tmpPartsQTY);
        last;	# beendet die schleife (springt zum letzten element)
      }
    }	# ende while SELECT SUM(qty), bin_id, chargenumber   FROM inventory  WHERE warehouse_id
  } #ende while select parts_id,qty from assembly where id = ?
  if ($kannNichtFertigen) {
    return $kannNichtFertigen;
  }

  # soweit alles gut. Jetzt noch die wirkliche Lagerbewegung für das Erzeugnis ausführen ...
  my $transferAssemblySQL = qq|INSERT INTO inventory (parts_id, warehouse_id, bin_id, chargenumber, comment, employee_id, qty, trans_id, trans_type_id)
			    VALUES (?, ?, ?, ?, ?, (SELECT id FROM employee WHERE login = ?), ?, nextval('id'),
				    (SELECT id FROM transfer_type WHERE direction = 'in' AND description = 'stock'))|;
  my $sthTransferAssemblySQL   = prepare_query($form, $dbh, $transferAssemblySQL);
  do_statement($form, $sthTransferAssemblySQL, $transferAssemblySQL, $params{assembly_id}, $params{dst_warehouse_id}, $params{dst_bin_id}, $params{chargenumber}, $params{comment}, $params{login}, $params{qty});
  $dbh->commit();

  $main::lxdebug->leave_sub();
  return 1;	# Alles erfolgreich
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
  my $sort_col   = $form->{sort};
  my $sort_order = $form->{order};

  $sort_col      = $filter{sort}         unless $sort_col;
  $sort_order    = ($sort_col = 'itime') unless $sort_col;
  $sort_col      = 'itime'               if     $sort_col eq 'date';
  $sort_order    = $filter{order}        unless $sort_order;
  my $sort_spec  = "${sort_col} " . ($sort_order ? " DESC" : " ASC");

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
     "oe_id"                => "COALESCE(i1.oe_id, i2.oe_id)",
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
    ORDER BY r_${sort_spec}|;

  my $sth = prepare_execute_query($form, $dbh, $query, @filter_vars, @filter_vars, @filter_vars);

  my ($h_oe_id, $q_oe_id);
  if ($form->{l_oe_id}) {
    $q_oe_id = <<SQL;
      SELECT oe.id AS id,
        CASE WHEN oe.quotation THEN oe.quonumber ELSE oe.ordnumber END AS number,
        CASE
          WHEN oe.customer_id IS NOT NULL AND     COALESCE(oe.quotation, FALSE) THEN 'sales_quotation'
          WHEN oe.customer_id IS NOT NULL AND NOT COALESCE(oe.quotation, FALSE) THEN 'sales_order'
          WHEN oe.customer_id IS     NULL AND     COALESCE(oe.quotation, FALSE) THEN 'request_quotation'
          ELSE                                                                       'purchase_order'
        END AS type
      FROM oe
      WHERE oe.id = ?

      UNION

      SELECT dord.id AS id, dord.donumber AS number,
        CASE
          WHEN dord.customer_id IS NULL THEN 'purchase_delivery_order'
          ELSE                               'sales_delivery_order'
        END AS type
      FROM delivery_orders dord
      WHERE dord.id = ?

      UNION

      SELECT ar.id AS id, ar.invnumber AS number, 'sales_invoice' AS type
      FROM ar
      WHERE ar.id = ?

      UNION

      SELECT ap.id AS id, ap.invnumber AS number, 'purchase_invoice' AS type
      FROM ap
      WHERE ap.id = ?
SQL
    $h_oe_id = prepare_query($form, $dbh, $q_oe_id);
  }

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

    if ($h_oe_id && $ref->{oe_id}) {
      do_statement($form, $h_oe_id, $q_oe_id, ($ref->{oe_id}) x 4);
      $ref->{oe_id_info} = $h_oe_id->fetchrow_hashref() || {};
    }

    push @contents, $ref;
  }

  $sth->finish();
  $h_oe_id->finish() if $h_oe_id;

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
#  - ean	  - will return only matches where the given string is a substring of the ean as stored in the table parts (article)
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
  my (@filter_ary, @filter_vars, @wh_bin_filter_ary, @wh_bin_filter_vars);

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
  if ($filter{ean}) {
    push @filter_ary,  "p.ean ILIKE ?";
    push @filter_vars, '%' . $filter{ean} . '%';
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
  my $sort_col    =  $form->{sort};
  my $sort_order  = $form->{order};

  $sort_col       =  $filter{sort}  unless $sort_col;
  $sort_col       =  "parts_id"     unless $sort_col;
  $sort_order     =  $filter{order} unless $sort_order;
  $sort_col       =~ s/ASC|DESC//; # kill stuff left in from previous queries
  my $orderby     =  $sort_col;
  my $sort_spec   =  "${sort_col} " . ($sort_order ? " DESC" : " ASC");

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
     "ean"         	    => "p.ean",
     "chargeid"             => "c.id",
     "warehousedescription" => "w.description",
     "partunit"             => "p.unit",
     "stock_value"          => "p.lastcost / COALESCE(pfac.factor, 1)",
  );
  my $select_clause = join ', ', map { +/^l_/; "$select_tokens{$'} AS $'" }
        ( grep( { !/qty/ and /^l_/ and $form->{$_} eq 'Y' } keys %$form),
          qw(l_parts_id l_qty l_partunit) );

  my $group_clause = join ", ", map { +/^l_/; "$'" }
        ( grep( { !/qty/ and /^l_/ and $form->{$_} eq 'Y' } keys %$form),
          qw(l_parts_id l_partunit) );

  my %join_tokens = (
    "stock_value" => "LEFT JOIN price_factors pfac ON (p.price_factor_id = pfac.id)",
    );

  my $joins = join ' ', grep { $_ } map { +/^l_/; $join_tokens{"$'"} }
        ( grep( { !/qty/ and /^l_/ and $form->{$_} eq 'Y' } keys %$form),
          qw(l_parts_id l_qty l_partunit) );

  my $query =
    qq|SELECT $select_clause
      FROM inventory i
      LEFT JOIN parts     p ON i.parts_id     = p.id
      LEFT JOIN bin       b ON i.bin_id       = b.id
      LEFT JOIN warehouse w ON i.warehouse_id = w.id
      $joins
      WHERE $where_clause
      GROUP BY $group_clause
      ORDER BY $sort_spec|;

  my $sth = prepare_execute_query($form, $dbh, $query, @filter_vars);

  my (%non_empty_bins, @all_fields, @contents);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{qty} *= 1;
    my $qty      = $ref->{qty};

    next unless ($qty != 0);

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

    $ref->{stock_value} = ($ref->{stock_value} || 0) * $ref->{qty};

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

    while (my $ref = $sth->fetchrow_hashref()) {
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
#
# Eingabe: 	Teilenummer, Lagernummer (warehouse)
# Ausgabe:	Die maximale Anzahl der Teile in diesem Lager
#
sub get_max_qty_parts {
$main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(parts_id warehouse_id)); #die brauchen wir

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh();

  my $query = qq| SELECT SUM(qty), bin_id, chargenumber  FROM inventory where parts_id = ? AND warehouse_id = ? GROUP BY bin_id, chargenumber|;

  my $sth_QTY      = prepare_execute_query($form, $dbh, $query, ,$params{parts_id}, $params{warehouse_id}); #info: aufruf an DBUtils.pm

  my $max_qty_parts = 0; #Initialisierung mit 0
  while (my $ref = $sth_QTY->fetchrow_hashref()) {	# wir laufen über alle chargen und Lagerorte (s.a. SQL-Query oben)
    $max_qty_parts += $ref->{sum};
  }

  $main::lxdebug->leave_sub();

  return $max_qty_parts;
}

#
# Eingabe: 	Teilenummer, Lagernummer (warehouse)
# Ausgabe:	Die Beschreibung der Ware bzw. Erzeugnis
#
sub get_part_description {
$main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(parts_id )); #die brauchen wir

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh();

  my $query = qq| SELECT partnumber, description FROM parts where id = ? |;

  my $sth      = prepare_execute_query($form, $dbh, $query, ,$params{parts_id}); #info: aufruf zu DBUtils.pm

  my $ref = $sth->fetchrow_hashref();
  my $part_description = $ref->{partnumber} . " " . $ref->{description};

  $main::lxdebug->leave_sub();

  return $part_description;
}


1;
