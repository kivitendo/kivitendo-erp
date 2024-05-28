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
# Delivery Order entry module
#======================================================================

package DO;

use Carp;
use List::Util qw(max);
use Text::ParseWords;

use SL::AM;
use SL::Common;
use SL::CVar;
use SL::DB::DeliveryOrder;
use SL::DB::DeliveryOrder::TypeData qw(:types is_valid_type);
use SL::DB::Status;
use SL::DB::ValidityToken;
use SL::DBUtils;
use SL::Helper::ShippedQty;
use SL::HTML::Restrict;
use SL::RecordLinks;
use SL::IC;
use SL::TransNumber;
use SL::DB;
use SL::Util qw(trim);
use SL::YAML;

use strict;

sub transactions {
  $main::lxdebug->enter_sub();

  my ($self)   = @_;

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  # connect to database
  my $dbh = $form->get_standard_dbh($myconfig);

  my (@where, @values);

  my $vc = $form->{vc} eq "customer" ? "customer" : "vendor";

  $form->{l_order_confirmation_number} = 'Y' if $form->{order_confirmation_number};

  my $query =
    qq|SELECT dord.id, dord.donumber, dord.ordnumber, dord.cusordnumber,
         dord.transdate, dord.reqdate,
         dord.vendor_confirmation_number,
         ct.${vc}number, ct.name, ct.business_id,
         dord.${vc}_id, dord.globalproject_id,
         dord.closed, dord.delivered, dord.shippingpoint, dord.shipvia,
         dord.transaction_description, dord.itime::DATE AS insertdate,
         pr.projectnumber AS globalprojectnumber,
         dep.description AS department,
         dord.record_type,
         e.name AS employee,
         sm.name AS salesman
       FROM delivery_orders dord
       LEFT JOIN $vc ct ON (dord.${vc}_id = ct.id)
       LEFT JOIN contacts cp ON (dord.cp_id = cp.cp_id)
       LEFT JOIN employee e ON (dord.employee_id = e.id)
       LEFT JOIN employee sm ON (dord.salesman_id = sm.id)
       LEFT JOIN project pr ON (dord.globalproject_id = pr.id)
       LEFT JOIN department dep ON (dord.department_id = dep.id)
|;

  if ($form->{type} && is_valid_type($form->{type})) {
    push @where, 'dord.record_type = ?';
    push @values, $form->{type};
  }

  if ($form->{department_id}) {
    push @where,  qq|dord.department_id = ?|;
    push @values, conv_i($form->{department_id});
  }

  if ($form->{project_id}) {
    push @where,
      qq|(dord.globalproject_id = ?) OR EXISTS
          (SELECT * FROM delivery_order_items doi
           WHERE (doi.project_id = ?) AND (doi.delivery_order_id = dord.id))|;
    push @values, conv_i($form->{project_id}), conv_i($form->{project_id});
  }

  if ($form->{"business_id"}) {
    push @where,  qq|ct.business_id = ?|;
    push @values, conv_i($form->{"business_id"});
  }

  if ($form->{"${vc}_id"}) {
    push @where,  qq|dord.${vc}_id = ?|;
    push @values, $form->{"${vc}_id"};

  } elsif ($form->{$vc}) {
    push @where,  qq|ct.name ILIKE ?|;
    push @values, like($form->{$vc});
  }

  if ($form->{"cp_name"}) {
    push @where, "(cp.cp_name ILIKE ? OR cp.cp_givenname ILIKE ?)";
    push @values, (like($form->{"cp_name"}))x2;
  }

  foreach my $item (qw(employee_id salesman_id)) {
    next unless ($form->{$item});
    push @where, "dord.$item = ?";
    push @values, conv_i($form->{$item});
  }
  if ( !(    ($vc eq 'customer' && ($main::auth->assert('sales_all_edit',    1) || $main::auth->assert('sales_delivery_order_view',    1)))
          || ($vc eq 'vendor'   && ($main::auth->assert('purchase_all_edit', 1) || $main::auth->assert('purchase_delivery_order_view', 1))) ) ) {
    push @where, qq|dord.employee_id = (select id from employee where login= ?)|;
    push @values, $::myconfig{login};
  }

  foreach my $item (qw(donumber ordnumber cusordnumber transaction_description vendor_confirmation_number)) {
    next unless ($form->{$item});
    push @where,  qq|dord.$item ILIKE ?|;
    push @values, like($form->{$item});
  }

  if ($form->{order_confirmation_number}) {
    push @where, qq|(EXISTS (SELECT id FROM oe
                             WHERE ordnumber ILIKE ?
                               AND record_type = 'purchase_order_confirmation'
                               AND id IN
                               (SELECT from_id FROM record_links
                                WHERE to_id = dord.id
                                  AND to_table = 'delivery_orders'
                                  AND from_table = 'oe')
                    ))|;
    push @values, like($form->{order_confirmation_number});
  }

  if (($form->{open} || $form->{closed}) &&
      ($form->{open} ne $form->{closed})) {
    push @where, ($form->{open} ? "NOT " : "") . "COALESCE(dord.closed, FALSE)";
  }

  if (($form->{notdelivered} || $form->{delivered}) &&
      ($form->{notdelivered} ne $form->{delivered})) {
    push @where, ($form->{delivered} ? "" : "NOT ") . "COALESCE(dord.delivered, FALSE)";
  }

  if ($form->{serialnumber}) {
    push @where, 'dord.id IN (SELECT doi.delivery_order_id FROM delivery_order_items doi WHERE doi.serialnumber LIKE ?)';
    push @values, like($form->{serialnumber});
  }

  if($form->{transdatefrom}) {
    push @where,  qq|dord.transdate >= ?|;
    push @values, conv_date($form->{transdatefrom});
  }

  if($form->{transdateto}) {
    push @where,  qq|dord.transdate <= ?|;
    push @values, conv_date($form->{transdateto});
  }

  if($form->{reqdatefrom}) {
    push @where,  qq|dord.reqdate >= ?|;
    push @values, conv_date($form->{reqdatefrom});
  }

  if($form->{reqdateto}) {
    push @where,  qq|dord.reqdate <= ?|;
    push @values, conv_date($form->{reqdateto});
  }

  if($form->{insertdatefrom}) {
    push @where, qq|dord.itime::DATE >= ?|;
    push@values, conv_date($form->{insertdatefrom});
  }

  if($form->{insertdateto}) {
    push @where, qq|dord.itime::DATE <= ?|;
    push @values, conv_date($form->{insertdateto});
  }

  $form->{fulltext} = trim($form->{fulltext});
  if ($form->{fulltext}) {
    my @fulltext_fields = qw(dord.notes
                             dord.intnotes
                             dord.shippingpoint
                             dord.shipvia
                             dord.transaction_description
                             dord.donumber
                             dord.ordnumber
                             dord.cusordnumber
                             dord.oreqnumber
                             dord.vendor_confirmation_number
                             oe.ordnumber
                            );
    my $tmp_where = '';
    $tmp_where .= join ' OR ', map {"$_ ILIKE ?"} @fulltext_fields;
    push(@values, like($form->{fulltext})) for 1 .. (scalar @fulltext_fields);

    $tmp_where .= <<SQL;
      OR EXISTS (
        SELECT files.id FROM files LEFT JOIN file_full_texts ON (file_full_texts.file_id = files.id)
          WHERE files.object_id = dord.id AND files.object_type = ?
            AND file_full_texts.full_text ILIKE ?)
SQL
    push(@values, $form->{type});
    push(@values, like($form->{fulltext}));
    push @where, $tmp_where;

  }

  if ($form->{parts_partnumber}) {
    push @where, <<SQL;
      EXISTS (
        SELECT delivery_order_items.delivery_order_id
        FROM delivery_order_items
        LEFT JOIN parts ON (delivery_order_items.parts_id = parts.id)
        WHERE (delivery_order_items.delivery_order_id = dord.id)
          AND (parts.partnumber ILIKE ?)
        LIMIT 1
      )
SQL
    push @values, like($form->{parts_partnumber});
  }

  if ($form->{parts_description}) {
    push @where, <<SQL;
      EXISTS (
        SELECT delivery_order_items.delivery_order_id
        FROM delivery_order_items
        WHERE (delivery_order_items.delivery_order_id = dord.id)
          AND (delivery_order_items.description ILIKE ?)
        LIMIT 1
      )
SQL
    push @values, like($form->{parts_description});
  }

  if ($form->{chargenumber}) {
    push @where, <<SQL;
      EXISTS (
        SELECT delivery_order_items_stock.id
        FROM delivery_order_items_stock
        LEFT JOIN delivery_order_items ON (delivery_order_items.id = delivery_order_items_stock.delivery_order_item_id)
        WHERE delivery_order_items.delivery_order_id = dord.id
          AND delivery_order_items_stock.chargenumber ILIKE ?
        LIMIT 1
      )
SQL
    push @values, like($form->{chargenumber});
  }

  if ($form->{ids}) {
    unshift @{$form->{ids}}, 0; # no error and no results if no ids are given
    my $placeholders = join(', ', ('?') x scalar(@{$form->{ids}}));
    push @where, "dord.id IN ($placeholders)";
    push @values, @{$form->{ids}};
  }

  if ($form->{all}) {
    my @tokens = parse_line('\s+', 0, $form->{all});
    # ordnumber quonumber customer.name vendor.name transaction_description
    push @where, <<SQL for @tokens;
      (   (dord.donumber                ILIKE ?)
       OR (ct.name                      ILIKE ?)
       OR (dord.transaction_description ILIKE ?))
SQL
    push @values, (like($_))x3 for @tokens;
  }

  if (@where) {
    $query .= " WHERE " . join(" AND ", map { "($_)" } @where);
  }

  my %allowed_sort_columns = (
    "transdate"               => "dord.transdate",
    "reqdate"                 => "dord.reqdate",
    "id"                      => "dord.id",
    "donumber"                => "dord.donumber",
    "ordnumber"               => "dord.ordnumber",
    "name"                    => "ct.name",
    "employee"                => "e.name",
    "salesman"                => "sm.name",
    "shipvia"                 => "dord.shipvia",
    "transaction_description" => "dord.transaction_description",
    "department"              => "lower(dep.description)",
    "insertdate"              => "dord.itime",
    "vendor_confirmation_number" => "dord.vendor_confirmation_number",
  );

  my $sortdir   = !defined $form->{sortdir} ? 'ASC' : $form->{sortdir} ? 'ASC' : 'DESC';
  my $sortorder = "dord.id";
  if ($form->{sort} && grep($form->{sort}, keys(%allowed_sort_columns))) {
    $sortorder = $allowed_sort_columns{$form->{sort}};
  }

  $query .= qq| ORDER by | . $sortorder . " $sortdir";

  $form->{DO} = selectall_hashref_query($form, $dbh, $query, @values);

  my $record_type = $vc eq 'customer' ? 'sales_order' : 'purchase_order';
  if (scalar @{ $form->{DO} }) {
    $query =
      qq|SELECT id
         FROM oe
         WHERE (record_type = '$record_type'
           AND ordnumber = ?)|;

    my $sth = prepare_query($form, $dbh, $query);


    my ($items_query, $items_sth);
    if ($form->{l_items}) {
      $items_query =
        qq|SELECT id
          FROM delivery_order_items
          WHERE delivery_order_id = ?
          ORDER BY position|;

      $items_sth = prepare_query($form, $dbh, $items_query);
    }

    my ($order_confirmation_query, $order_confirmation_sth);
    if ($form->{l_order_confirmation_number}) {
      $order_confirmation_query =
        qq|SELECT id, ordnumber FROM oe
           WHERE id IN
               (SELECT from_id FROM record_links
                WHERE from_table = 'oe'
                  AND to_table = 'delivery_orders'
                  AND to_id = ?)
             AND record_type = 'purchase_order_confirmation' ORDER BY ordnumber|;

      $order_confirmation_sth = prepare_query($form, $dbh, $order_confirmation_query);
    }

    foreach my $dord (@{ $form->{DO} }) {
      if ($form->{l_items}) {
        do_statement($form, $items_sth, $items_query, $dord->{id});
        $dord->{item_ids} = $dbh->selectcol_arrayref($items_sth);
        $dord->{item_ids} = undef if !@{$dord->{item_ids}};
      }

      if ($form->{l_order_confirmation_number}) {
        do_statement($form, $order_confirmation_sth, $order_confirmation_query, $dord->{id});
        my @r = @{$order_confirmation_sth->fetchall_arrayref()};
        push @{$dord->{order_confirmation_numbers}}, { id => $_->[0], number => $_->[1] } for @r;
      }

      next unless ($dord->{ordnumber});
      do_statement($form, $sth, $query, $dord->{ordnumber});
      ($dord->{oe_id}) = $sth->fetchrow_array();
    }

    $sth->finish();
    $items_sth->finish()              if $form->{l_items};
    $order_confirmation_sth->finish() if $form->{l_order_confirmation_number};
  }

  $main::lxdebug->leave_sub();
}

sub save {
  my ($self) = @_;
  $main::lxdebug->enter_sub();

  my $rc = SL::DB->client->with_transaction(\&_save, $self);

  $main::lxdebug->leave_sub();
  return $rc;
}

sub _save {
  $main::lxdebug->enter_sub();

  my ($self)   = @_;

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $validity_token;
  if (!$form->{id}) {
    $validity_token = SL::DB::Manager::ValidityToken->fetch_valid_token(
      scope => SL::DB::ValidityToken::SCOPE_DELIVERY_ORDER_SAVE(),
      token => $form->{form_validity_token},
    );

    die $::locale->text('The form is not valid anymore.') if !$validity_token;
  }

  my $dbh = SL::DB->client->dbh;
  my $restricter = SL::HTML::Restrict->create;

  my ($query, @values, $sth, $null);

  my $all_units = AM->retrieve_units($myconfig, $form);
  $form->{all_units} = $all_units;

  my $ic_cvar_configs = CVar->get_configs(module => 'IC',
                                          dbh    => $dbh);

  my $trans_number     = SL::TransNumber->new(type => $form->{type}, dbh => $dbh, number => $form->{donumber}, id => $form->{id});
  $form->{donumber}  ||= $trans_number->create_unique;
  $form->{employee_id} = (split /--/, $form->{employee})[1] if !$form->{employee_id};
  $form->get_employee($dbh) unless ($form->{employee_id});

  my $ml = ($form->{type} eq 'sales_delivery_order') ? 1 : -1;

  my (@processed_doi, @processed_dois);

  if ($form->{id}) {

    # only delete shipto complete
    $query = qq|DELETE FROM custom_variables
                WHERE (config_id IN (SELECT id        FROM custom_variable_configs WHERE (module = 'ShipTo')))
                  AND (trans_id  IN (SELECT shipto_id FROM shipto                  WHERE (module = 'DO') AND (trans_id = ?)))|;
    do_query($form, $dbh, $query, $form->{id});

    $query = qq|DELETE FROM shipto WHERE trans_id = ? AND module = 'DO'|;
    do_query($form, $dbh, $query, conv_i($form->{id}));

  } else {

    $query = qq|SELECT nextval('id')|;
    ($form->{id}) = selectrow_query($form, $dbh, $query);

    $query = qq|INSERT INTO delivery_orders (id, donumber, employee_id, currency_id, taxzone_id, record_type) VALUES (?, '', ?, (SELECT currency_id FROM defaults LIMIT 1), ?, ?)|;
    do_query($form, $dbh, $query, $form->{id}, conv_i($form->{employee_id}), $form->{taxzone_id}, SALES_DELIVERY_ORDER_TYPE);
  }

  my $project_id;
  my $items_reqdate;

  $form->get_lists('price_factors' => 'ALL_PRICE_FACTORS');
  my %price_factors = map { $_->{id} => $_->{factor} *1 } @{ $form->{ALL_PRICE_FACTORS} };
  my $price_factor;

  my %part_id_map = map { $_ => 1 } grep { $_ } map { $form->{"id_$_"} } (1 .. $form->{rowcount});
  my @part_ids    = keys %part_id_map;
  my %part_unit_map;

  if (@part_ids) {
    $query         = qq|SELECT id, unit FROM parts WHERE id IN (| . join(', ', map { '?' } @part_ids) . qq|)|;
    %part_unit_map = selectall_as_map($form, $dbh, $query, 'id', 'unit', @part_ids);
  }
  my $q_item = <<SQL;
    UPDATE delivery_order_items SET
       delivery_order_id = ?, position = ?, parts_id = ?, description = ?, longdescription = ?, qty = ?, base_qty = ?,
       sellprice = ?, discount = ?, unit = ?, reqdate = ?, project_id = ?, serialnumber = ?,
       lastcost = ? , price_factor_id = ?, price_factor = (SELECT factor FROM price_factors where id = ?),
       marge_price_factor = ?, pricegroup_id = ?, active_price_source = ?, active_discount_source = ?
    WHERE id = ?
SQL
  my $h_item = prepare_query($form, $dbh, $q_item);

  my $q_item_stock = <<SQL;
    UPDATE delivery_order_items_stock SET
      delivery_order_item_id = ?, qty = ?,  unit = ?,  warehouse_id = ?,
      bin_id = ?, chargenumber = ?, bestbefore = ?
    WHERE id = ?
SQL
  my $h_item_stock = prepare_query($form, $dbh, $q_item_stock);

  my $in_out       = $form->{type} =~ /^sales/ ? 'out' : 'in';

  for my $i (1 .. $form->{rowcount}) {
    next if (!$form->{"id_$i"});

    CVar->get_non_editable_ic_cvars(form               => $form,
                                    dbh                => $dbh,
                                    row                => $i,
                                    sub_module         => 'delivery_order_items',
                                    may_converted_from => ['orderitems', 'delivery_order_items']);

    my $position = $i;

    if (!$form->{"delivery_order_items_id_$i"}) {
      # there is no persistent id, therefore create one with all necessary constraints
      my $q_item_id = qq|SELECT nextval('delivery_order_items_id')|;
      my $h_item_id = prepare_query($form, $dbh, $q_item_id);
      do_statement($form, $h_item_id, $q_item_id);
      $form->{"delivery_order_items_id_$i"}  = $h_item_id->fetchrow_array();
      $query = qq|INSERT INTO delivery_order_items (id, delivery_order_id, position, parts_id) VALUES (?, ?, ?, ?)|;
      do_query($form, $dbh, $query, conv_i($form->{"delivery_order_items_id_$i"}),
                conv_i($form->{"id"}), conv_i($position), conv_i($form->{"id_$i"}));
      $h_item_id->finish();
    }

    $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});

    my $item_unit = $part_unit_map{$form->{"id_$i"}};

    my $basefactor = 1;
    if (defined($all_units->{$item_unit}->{factor}) && (($all_units->{$item_unit}->{factor} * 1) != 0)) {
      $basefactor = $all_units->{$form->{"unit_$i"}}->{factor} / $all_units->{$item_unit}->{factor};
    }
    my $baseqty = $form->{"qty_$i"} * $basefactor;

    # set values to 0 if nothing entered
    $form->{"discount_$i"}  = $form->parse_amount($myconfig, $form->{"discount_$i"});
    $form->{"sellprice_$i"} = $form->parse_amount($myconfig, $form->{"sellprice_$i"});
    $form->{"lastcost_$i"} = $form->parse_amount($myconfig, $form->{"lastcost_$i"});

    $price_factor = $price_factors{ $form->{"price_factor_id_$i"} } || 1;
    my $linetotal    = $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"} / $price_factor, 2);

    $items_reqdate = ($form->{"reqdate_$i"}) ? $form->{"reqdate_$i"} : undef;


    # Get pricegroup_id and save it. Unfortunately the interface
    # also uses ID "0" for signalling that none is selected, but "0"
    # must not be stored in the database. Therefore we cannot simply
    # use conv_i().
    my $pricegroup_id = $form->{"pricegroup_id_$i"} * 1;
    $pricegroup_id    = undef if !$pricegroup_id;

    # save detail record in delivery_order_items table
    @values = (conv_i($form->{id}), conv_i($position), conv_i($form->{"id_$i"}),
               $form->{"description_$i"}, $restricter->process($form->{"longdescription_$i"}),
               $form->{"qty_$i"}, $baseqty,
               $form->{"sellprice_$i"}, $form->{"discount_$i"} / 100,
               $form->{"unit_$i"}, conv_date($items_reqdate), conv_i($form->{"project_id_$i"}),
               trim($form->{"serialnumber_$i"}),
               $form->{"lastcost_$i"},
               conv_i($form->{"price_factor_id_$i"}), conv_i($form->{"price_factor_id_$i"}),
               conv_i($form->{"marge_price_factor_$i"}),
               $pricegroup_id,
               $form->{"active_price_source_$i"}, $form->{"active_discount_source_$i"},
               conv_i($form->{"delivery_order_items_id_$i"}));
    do_statement($form, $h_item, $q_item, @values);
    push @processed_doi, $form->{"delivery_order_items_id_$i"}; # transaction safe?

    my $stock_info = DO->unpack_stock_information('packed' => $form->{"stock_${in_out}_$i"});

    foreach my $sinfo (@{ $stock_info }) {
      # if we have stock_info, we have to check for persistents entries
      if (!$sinfo->{"delivery_order_items_stock_id"}) {
        my $q_item_stock_id = qq|SELECT nextval('id')|;
        my $h_item_stock_id = prepare_query($form, $dbh, $q_item_stock_id);
        do_statement($form, $h_item_stock_id, $q_item_stock_id);
        $sinfo->{"delivery_order_items_stock_id"} = $h_item_stock_id->fetchrow_array();
        $query = qq|INSERT INTO delivery_order_items_stock (id, delivery_order_item_id, qty, unit, warehouse_id, bin_id)
                    VALUES (?, ?, ?, ?, ?, ?)|;
        do_query($form, $dbh, $query, conv_i($sinfo->{"delivery_order_items_stock_id"}),
                  conv_i($form->{"delivery_order_items_id_$i"}), $sinfo->{qty}, $sinfo->{unit}, conv_i($sinfo->{warehouse_id}),
                  conv_i($sinfo->{bin_id}));
        $h_item_stock_id->finish();
        # write back the id to the form (important if only transfer was clicked (id fk for invoice)
        $form->{"stock_${in_out}_$i"} = SL::YAML::Dump($stock_info);
      }
      @values = ($form->{"delivery_order_items_id_$i"}, $sinfo->{qty}, $sinfo->{unit}, conv_i($sinfo->{warehouse_id}),
                 conv_i($sinfo->{bin_id}), $sinfo->{chargenumber}, conv_date($sinfo->{bestbefore}),
                 conv_i($sinfo->{"delivery_order_items_stock_id"}));
      do_statement($form, $h_item_stock, $q_item_stock, @values);
      push @processed_dois, $sinfo->{"delivery_order_items_stock_id"};
    }

    CVar->save_custom_variables(module       => 'IC',
                                sub_module   => 'delivery_order_items',
                                trans_id     => $form->{"delivery_order_items_id_$i"},
                                configs      => $ic_cvar_configs,
                                variables    => $form,
                                name_prefix  => 'ic_',
                                name_postfix => "_$i",
                                dbh          => $dbh);

    # link order items with doi, for future extension look at foreach IS.pm
    if (!$form->{saveasnew} && $form->{"converted_from_orderitems_id_$i"}) {
      RecordLinks->create_links('dbh'        => $dbh,
                                'mode'       => 'ids',
                                'from_table' => 'orderitems',
                                'from_ids'   => $form->{"converted_from_orderitems_id_$i"},
                                'to_table'   => 'delivery_order_items',
                                'to_id'      =>  $form->{"delivery_order_items_id_$i"},
      );
    }
    delete $form->{"converted_from_orderitems_id_$i"};
  }

  # 1. search for orphaned dois; processed_dois may be empty (no transfer) TODO: be supersafe and alter same statement for doi and oi
  $query  = sprintf 'SELECT id FROM delivery_order_items_stock WHERE delivery_order_item_id in
                      (select id from delivery_order_items where delivery_order_id = ?)';
  $query .= sprintf ' AND NOT id IN (%s)', join ', ', ("?") x scalar @processed_dois if (scalar @processed_dois);
  @values = (conv_i($form->{id}), map { conv_i($_) } @processed_dois);
  my @orphaned_dois_ids = map { $_->{id} } selectall_hashref_query($form, $dbh, $query, @values);
  if (scalar @orphaned_dois_ids) {
    # clean up delivery_order_items_stock
    $query  = sprintf 'DELETE FROM delivery_order_items_stock WHERE id IN (%s)', join ', ', ("?") x scalar @orphaned_dois_ids;
    do_query($form, $dbh, $query, @orphaned_dois_ids);
  }
  # 2. search for orphaned doi
  $query  = sprintf 'SELECT id FROM delivery_order_items WHERE delivery_order_id = ? AND NOT id IN (%s)', join ', ', ("?") x scalar @processed_doi;
  @values = (conv_i($form->{id}), map { conv_i($_) } @processed_doi);
  my @orphaned_ids = map { $_->{id} } selectall_hashref_query($form, $dbh, $query, @values);
  if (scalar @orphaned_ids) {
    # clean up delivery_order_items
    $query  = sprintf 'DELETE FROM delivery_order_items WHERE id IN (%s)', join ', ', ("?") x scalar @orphaned_ids;
    do_query($form, $dbh, $query, @orphaned_ids);
  }
  $h_item->finish();
  $h_item_stock->finish();


  # reqdate is last items reqdate (?: old behaviour) if not already set
  $form->{reqdate} ||= $items_reqdate;
  # save DO record
  $query =
    qq|UPDATE delivery_orders SET
         donumber = ?, ordnumber = ?, cusordnumber = ?, transdate = ?, vendor_id = ?,
         customer_id = ?, reqdate = ?, tax_point = ?,
         shippingpoint = ?, shipvia = ?, notes = ?, intnotes = ?, closed = ?,
         delivered = ?, department_id = ?, language_id = ?, shipto_id = ?, billing_address_id = ?,
         globalproject_id = ?, employee_id = ?, salesman_id = ?, cp_id = ?, transaction_description = ?,
         record_type = ?, taxzone_id = ?, taxincluded = ?, payment_id = ?, currency_id = (SELECT id FROM currencies WHERE name = ?),
         delivery_term_id = ?
       WHERE id = ?|;

  @values = ($form->{donumber}, $form->{ordnumber},
             $form->{cusordnumber}, conv_date($form->{transdate}),
             conv_i($form->{vendor_id}), conv_i($form->{customer_id}),
             conv_date($form->{reqdate}), conv_date($form->{tax_point}), $form->{shippingpoint}, $form->{shipvia},
             $restricter->process($form->{notes}), $form->{intnotes},
             $form->{closed} ? 't' : 'f', $form->{delivered} ? "t" : "f",
             conv_i($form->{department_id}), conv_i($form->{language_id}), conv_i($form->{shipto_id}), conv_i($form->{billing_address_id}),
             conv_i($form->{globalproject_id}), conv_i($form->{employee_id}),
             conv_i($form->{salesman_id}), conv_i($form->{cp_id}),
             $form->{transaction_description},
             $form->{type} =~ /^sales/ ? SALES_DELIVERY_ORDER_TYPE : PURCHASE_DELIVERY_ORDER_TYPE,
             conv_i($form->{taxzone_id}), $form->{taxincluded} ? 't' : 'f', conv_i($form->{payment_id}), $form->{currency},
             conv_i($form->{delivery_term_id}),
             conv_i($form->{id}));
  do_query($form, $dbh, $query, @values);

  $form->new_lastmtime('delivery_orders');

  $form->{name} = $form->{ $form->{vc} };
  $form->{name} =~ s/--$form->{"$form->{vc}_id"}//;

  # add shipto
  if (!$form->{shipto_id}) {
    $form->add_shipto($dbh, $form->{id}, "DO");
  }

  # save printed, emailed, queued
  $form->save_status($dbh);

  # Link this delivery order to the quotations it was created from.
  RecordLinks->create_links('dbh'        => $dbh,
                            'mode'       => 'ids',
                            'from_table' => 'oe',
                            'from_ids'   => $form->{convert_from_oe_ids},
                            'to_table'   => 'delivery_orders',
                            'to_id'      => $form->{id},
    );
  delete $form->{convert_from_oe_ids};
  unless ($::instance_conf->get_shipped_qty_require_stock_out) {
    $self->mark_orders_if_delivered('do_id' => $form->{id},
                                    'type'  => $form->{type} eq 'sales_delivery_order' ? 'sales' : 'purchase');
  }

  $form->{saved_donumber} = $form->{donumber};
  $form->{saved_ordnumber} = $form->{ordnumber};
  $form->{saved_cusordnumber} = $form->{cusordnumber};

  Common::webdav_folder($form);

  $validity_token->delete if $validity_token;
  delete $form->{form_validity_token};

  $main::lxdebug->leave_sub();

  return 1;
}

sub mark_orders_if_delivered {
  my ($self, %params) = @_;

  Common::check_params(\%params, qw(do_id type));

  my $do     = SL::DB::Manager::DeliveryOrder->find_by(id => $params{do_id});
  my $orders = $do->linked_records(from => 'Order');

  SL::Helper::ShippedQty->new->calculate($orders)->write_to_objects;

  SL::DB->client->with_transaction(sub {
    for my $oe (@$orders) {
      next if $params{type} eq 'sales'    && !$oe->customer_id;
      next if $params{type} eq 'purchase' && !$oe->vendor_id;

      $oe->update_attributes(delivered => $oe->{delivered});
    }
    1;
  }) or do { die SL::DB->client->error };
}

sub close_orders {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(ids));

  if (('ARRAY' ne ref $params{ids}) || !scalar @{ $params{ids} }) {
    $main::lxdebug->leave_sub();
    return;
  }

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  SL::DB->client->with_transaction(sub {
    my $dbh      = $params{dbh} || SL::DB->client->dbh;

    my $query    = qq|UPDATE delivery_orders SET closed = TRUE WHERE id IN (| . join(', ', ('?') x scalar(@{ $params{ids} })) . qq|)|;

    do_query($form, $dbh, $query, map { conv_i($_) } @{ $params{ids} });
    1;
  }) or die { SL::DB->client->error };

  $form->new_lastmtime('delivery_orders');

  $main::lxdebug->leave_sub();
}

sub delete {
  $main::lxdebug->enter_sub();

  my ($self)   = @_;

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;
  my $spool    = $::lx_office_conf{paths}->{spool};

  my $rc = SL::DB::Order->new->db->with_transaction(sub {
    my @spoolfiles = grep { $_ } map { $_->spoolfile } @{ SL::DB::Manager::Status->get_all(where => [ trans_id => $form->{id} ]) };

    SL::DB::DeliveryOrder->new(id => $form->{id})->delete;

    my $spool = $::lx_office_conf{paths}->{spool};
    unlink map { "$spool/$_" } @spoolfiles if $spool;

    1;
  });

  $main::lxdebug->leave_sub();

  return $rc;
}

sub delete_transfers {
  $main::lxdebug->enter_sub();

  my ($self)   = @_;

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $rc = SL::DB::Order->new->db->with_transaction(sub {

    my $do = SL::DB::DeliveryOrder->new(id => $form->{id})->load;
    die "No valid delivery order found" unless ref $do eq 'SL::DB::DeliveryOrder';

    my $dt = DateTime->today->subtract(days => $::instance_conf->get_undo_transfer_interval);
    croak "Wrong call. Please check undoing interval" unless $do->itime > $dt;

    foreach my $doi (@{ $do->orderitems }) {
      foreach my $dois (@{ $doi->delivery_order_stock_entries}) {
        $dois->inventory->delete;
        $dois->delete;
      }
    }
    $do->update_attributes(delivered => 0);

    1;
  });

  $main::lxdebug->leave_sub();

  return $rc;
}

sub retrieve {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  # connect to database
  my $dbh = $form->get_standard_dbh($myconfig);

  my ($query, $query_add, @values, $sth, $ref);

  my $ic_cvar_configs = CVar->get_configs(module => 'IC',
                                          dbh    => $dbh);

  my $vc   = $params{vc} eq 'customer' ? 'customer' : 'vendor';

  my $mode = !$params{ids} ? 'default' : ref $params{ids} eq 'ARRAY' ? 'multi' : 'single';

  if ($mode eq 'default') {
    $ref = selectfirst_hashref_query($form, $dbh, qq|SELECT current_date AS transdate|);
    map { $form->{$_} = $ref->{$_} } keys %$ref;

    # if reqdate is not set from oe-workflow, set it to transdate (which is current date)
    $form->{reqdate} ||= $form->{transdate};

    # get last name used
    $form->lastname_used($dbh, $myconfig, $vc) unless $form->{"${vc}_id"};

    $main::lxdebug->leave_sub();

    return 1;
  }

  my @do_ids              = map { conv_i($_) } ($mode eq 'multi' ? @{ $params{ids} } : ($params{ids}));
  my $do_ids_placeholders = join(', ', ('?') x scalar(@do_ids));

  # retrieve order for single id
  # NOTE: this query is intended to fetch all information only ONCE.
  # so if any of these infos is important (or even different) for any item,
  # it will be killed out and then has to be fetched from the item scope query further down
  $query =
    qq|SELECT dord.cp_id, dord.donumber, dord.ordnumber, dord.transdate, dord.reqdate, dord.tax_point,
         dord.shippingpoint, dord.shipvia, dord.notes, dord.intnotes,
         e.name AS employee, dord.employee_id, dord.salesman_id,
         dord.${vc}_id, cv.name AS ${vc},
         dord.closed, dord.reqdate, dord.department_id, dord.cusordnumber,
         d.description AS department, dord.language_id,
         dord.shipto_id, dord.billing_address_id,
         dord.itime, dord.mtime,
         dord.globalproject_id, dord.delivered, dord.transaction_description,
         dord.taxzone_id, dord.taxincluded, dord.payment_id, (SELECT cu.name FROM currencies cu WHERE cu.id=dord.currency_id) AS currency,
         dord.delivery_term_id, dord.itime::DATE AS insertdate
       FROM delivery_orders dord
       JOIN ${vc} cv ON (dord.${vc}_id = cv.id)
       LEFT JOIN employee e ON (dord.employee_id = e.id)
       LEFT JOIN department d ON (dord.department_id = d.id)
       WHERE dord.id IN ($do_ids_placeholders)|;
  $sth = prepare_execute_query($form, $dbh, $query, @do_ids);

  delete $form->{"${vc}_id"};
  my $pos = 0;
  $form->{ordnumber_array} = ' ';
  $form->{cusordnumber_array} = ' ';
  while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
    if ($form->{"${vc}_id"} && ($ref->{"${vc}_id"} != $form->{"${vc}_id"})) {
      $sth->finish();
      $main::lxdebug->leave_sub();

      return 0;
    }

    map { $form->{$_} = $ref->{$_} } keys %$ref if ($ref);
    $form->{donumber_array} .= $form->{donumber} . ' ';
    $pos = index($form->{ordnumber_array},' ' . $form->{ordnumber} . ' ');
    if ($pos == -1) {
      $form->{ordnumber_array} .= $form->{ordnumber} . ' ';
    }
    $pos = index($form->{cusordnumber_array},' ' . $form->{cusordnumber} . ' ');
    if ($pos == -1) {
      $form->{cusordnumber_array} .= $form->{cusordnumber} . ' ';
    }
  }
  $sth->finish();
  $form->{mtime}   ||= $form->{itime};
  $form->{lastmtime} = $form->{mtime};
  $form->{donumber_array} =~ s/\s*$//g;
  $form->{ordnumber_array} =~ s/ //;
  $form->{ordnumber_array} =~ s/\s*$//g;
  $form->{cusordnumber_array} =~ s/ //;
  $form->{cusordnumber_array} =~ s/\s*$//g;

  $form->{saved_donumber} = $form->{donumber};
  $form->{saved_ordnumber} = $form->{ordnumber};
  $form->{saved_cusordnumber} = $form->{cusordnumber};

  # if not given, fill transdate with current_date
  $form->{transdate} = $form->current_date($myconfig) unless $form->{transdate};

  if ($mode eq 'single') {
    $query = qq|SELECT s.* FROM shipto s WHERE s.trans_id = ? AND s.module = 'DO'|;
    $sth   = prepare_execute_query($form, $dbh, $query, $form->{id});

    $ref   = $sth->fetchrow_hashref("NAME_lc");
    $form->{$_} = $ref->{$_} for grep { m{^shipto(?!_id$)} } keys %$ref;
    $sth->finish();

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
    $sth   = prepare_execute_query($form, $dbh, $query, conv_i($form->{id}));

    while ($ref = $sth->fetchrow_hashref("NAME_lc")) {
      $form->{printed} .= "$ref->{formname} " if $ref->{printed};
      $form->{emailed} .= "$ref->{formname} " if $ref->{emailed};
      $form->{queued}  .= "$ref->{formname} $ref->{spoolfile} " if $ref->{spoolfile};
    }
    $sth->finish();
    map { $form->{$_} =~ s/ +$//g } qw(printed emailed queued);

  } else {
    delete $form->{id};
  }

  # retrieve individual items
  # this query looks up all information about the items
  # stuff different from the whole will not be overwritten, but saved with a suffix.
  $query =
    qq|SELECT doi.id AS delivery_order_items_id,
         p.partnumber, p.part_type, p.listprice, doi.description, doi.qty,
         doi.sellprice, doi.parts_id AS id, doi.unit, doi.discount, p.notes AS partnotes,
         doi.reqdate, doi.project_id, doi.serialnumber, doi.lastcost,
         doi.ordnumber, doi.transdate, doi.cusordnumber, doi.longdescription,
         doi.price_factor_id, doi.price_factor, doi.marge_price_factor, doi.pricegroup_id,
         doi.active_price_source, doi.active_discount_source,
         pr.projectnumber, dord.transdate AS dord_transdate, dord.donumber,
         pg.partsgroup
       FROM delivery_order_items doi
       JOIN parts p ON (doi.parts_id = p.id)
       JOIN delivery_orders dord ON (doi.delivery_order_id = dord.id)
       LEFT JOIN project pr ON (doi.project_id = pr.id)
       LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
       WHERE doi.delivery_order_id IN ($do_ids_placeholders)
       ORDER BY doi.delivery_order_id, doi.position|;

  $form->{form_details} = selectall_hashref_query($form, $dbh, $query, @do_ids);

  # Retrieve custom variables.
  foreach my $doi (@{ $form->{form_details} }) {
    my $cvars = CVar->get_custom_variables(dbh        => $dbh,
                                           module     => 'IC',
                                           sub_module => 'delivery_order_items',
                                           trans_id   => $doi->{delivery_order_items_id},
                                          );
    map { $doi->{"ic_cvar_$_->{name}"} = $_->{value} } @{ $cvars };

    my $makemodel = SL::DB::Manager::MakeModel->find_by(parts_id => $doi->{id}, make =>$form->{vendor_id});
    $doi->{vendor_partnumber} = $makemodel->model if $makemodel;
  }
  if ($mode eq 'single') {
    my $in_out = $form->{type} =~ /^sales/ ? 'out' : 'in';

    $query =
      qq|SELECT id as delivery_order_items_stock_id, qty, unit, bin_id,
                warehouse_id, chargenumber, bestbefore
         FROM delivery_order_items_stock
         WHERE delivery_order_item_id = ?|;
    my $sth = prepare_query($form, $dbh, $query);

    foreach my $doi (@{ $form->{form_details} }) {
      do_statement($form, $sth, $query, conv_i($doi->{delivery_order_items_id}));
      my $requests = [];
      while (my $ref = $sth->fetchrow_hashref()) {
        push @{ $requests }, $ref;
      }

      $doi->{"stock_${in_out}"} = SL::YAML::Dump($requests);
    }

    $sth->finish();
  }

  Common::webdav_folder($form);

  $main::lxdebug->leave_sub();

  return 1;
}

sub order_details {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->get_standard_dbh($myconfig);
  my $query;
  my @values = ();
  my $sth;
  my $item;
  my $i;
  my @partsgroup = ();
  my $partsgroup;
  my $position = 0;
  my $subtotal_header = 0;
  my $subposition = 0;
  my $si_position = 0;

  my (@project_ids);

  push(@project_ids, $form->{"globalproject_id"}) if ($form->{"globalproject_id"});

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

  my $q_pg     = qq|SELECT p.partnumber, p.description, p.unit, a.qty, pg.partsgroup
                    FROM assembly a
                    JOIN parts p ON (a.parts_id = p.id)
                    LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
                    WHERE a.bom = '1'
                      AND a.id = ?|;
  my $h_pg     = prepare_query($form, $dbh, $q_pg);

  my $q_bin_wh = qq|SELECT (SELECT description FROM bin       WHERE id = ?) AS bin,
                           (SELECT description FROM warehouse WHERE id = ?) AS warehouse|;
  my $h_bin_wh = prepare_query($form, $dbh, $q_bin_wh);

  my $in_out   = $form->{type} =~ /^sales|^supplier/ ? 'out' : 'in';

  my $num_si   = 0;

  my $ic_cvar_configs = CVar->get_configs(module => 'IC');
  my $project_cvar_configs = CVar->get_configs(module => 'Projects');

  # get some values of parts from db on store them in extra array,
  # so that they can be sorted in later
  my %prepared_template_arrays = IC->prepare_parts_for_printing(myconfig => $myconfig, form => $form);
  my @prepared_arrays          = keys %prepared_template_arrays;

  $form->{TEMPLATE_ARRAYS} = { };

  my @arrays =
    qw(runningnumber number description longdescription qty qty_nofmt unit
       partnotes serialnumber reqdate projectnumber projectdescription
       weight weight_nofmt lineweight lineweight_nofmt
       si_runningnumber si_number si_description
       si_warehouse si_bin si_chargenumber si_bestbefore
       si_qty si_qty_nofmt si_unit);

  map { $form->{TEMPLATE_ARRAYS}->{$_} = [] } (@arrays, @prepared_arrays);

  push @arrays, map { "ic_cvar_$_->{name}" } @{ $ic_cvar_configs };
  push @arrays, map { "project_cvar_$_->{name}" } @{ $project_cvar_configs };

  $form->get_lists('price_factors' => 'ALL_PRICE_FACTORS');
  my %price_factors = map { $_->{id} => $_->{factor} *1 } @{ $form->{ALL_PRICE_FACTORS} };

  my $totalweight = 0;
  my $sameitem = "";
  foreach $item (sort { $a->[1] cmp $b->[1] } @partsgroup) {
    $i = $item->[0];

    next if (!$form->{"id_$i"});

    if ($item->[1] ne $sameitem) {
      push(@{ $form->{TEMPLATE_ARRAYS}->{entry_type}  }, 'partsgroup');
      push(@{ $form->{TEMPLATE_ARRAYS}->{description} }, qq|$item->[1]|);
      $sameitem = $item->[1];

      map({ push(@{ $form->{TEMPLATE_ARRAYS}->{$_} }, "") } grep({ $_ ne "description" && $_ !~ /^si_/} (@arrays, @prepared_arrays)));
      map({ push(@{ $form->{TEMPLATE_ARRAYS}->{$_} }, []) } grep({ $_ =~ /^si_/} @arrays));
      $si_position++;
    }

    $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});

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

    $si_position++;

    my $price_factor = $price_factors{$form->{"price_factor_id_$i"}} || { 'factor' => 1 };
    my $project = $projects_by_id{$form->{"project_id_$i"}} || SL::DB::Project->new;

    push(@{ $form->{TEMPLATE_ARRAYS}{$_} },              $prepared_template_arrays{$_}[$i - 1]) for @prepared_arrays;

    push @{ $form->{TEMPLATE_ARRAYS}{entry_type} },      'normal';
    push @{ $form->{TEMPLATE_ARRAYS}{runningnumber} },   $position;
    push @{ $form->{TEMPLATE_ARRAYS}{number} },          $form->{"partnumber_$i"};
    push @{ $form->{TEMPLATE_ARRAYS}{description} },     $form->{"description_$i"};
    push @{ $form->{TEMPLATE_ARRAYS}{longdescription} }, $form->{"longdescription_$i"};
    push @{ $form->{TEMPLATE_ARRAYS}{qty} },             $form->format_amount($myconfig, $form->{"qty_$i"});
    push @{ $form->{TEMPLATE_ARRAYS}{qty_nofmt} },       $form->{"qty_$i"};
    push @{ $form->{TEMPLATE_ARRAYS}{unit} },            $form->{"unit_$i"};
    push @{ $form->{TEMPLATE_ARRAYS}{partnotes} },       $form->{"partnotes_$i"};
    push @{ $form->{TEMPLATE_ARRAYS}{serialnumber} },    $form->{"serialnumber_$i"};
    push @{ $form->{TEMPLATE_ARRAYS}{reqdate} },         $form->{"reqdate_$i"};
    push @{ $form->{TEMPLATE_ARRAYS}{projectnumber} },   $project->projectnumber;
    push @{ $form->{TEMPLATE_ARRAYS}{projectdescription} }, $project->description;

    if ($form->{"subtotal_$i"} && $subtotal_header && ($subtotal_header != $i)) {
      $subtotal_header     = 0;
    }

    my $lineweight = $form->{"qty_$i"} * $form->{"weight_$i"};
    $totalweight += $lineweight;
    push @{ $form->{TEMPLATE_ARRAYS}->{weight} },            $form->format_amount($myconfig, $form->{"weight_$i"}, 3);
    push @{ $form->{TEMPLATE_ARRAYS}->{weight_nofmt} },      $form->{"weight_$i"};
    push @{ $form->{TEMPLATE_ARRAYS}->{lineweight} },        $form->format_amount($myconfig, $lineweight, 3);
    push @{ $form->{TEMPLATE_ARRAYS}->{lineweight_nofmt} },  $lineweight;

    my $stock_info = DO->unpack_stock_information('packed' => $form->{"stock_${in_out}_$i"});

    foreach my $si (@{ $stock_info }) {
      $num_si++;

      do_statement($form, $h_bin_wh, $q_bin_wh, conv_i($si->{bin_id}), conv_i($si->{warehouse_id}));
      my $bin_wh = $h_bin_wh->fetchrow_hashref();

      push @{ $form->{TEMPLATE_ARRAYS}{si_runningnumber}[$si_position-1] }, $num_si;
      push @{ $form->{TEMPLATE_ARRAYS}{si_number}[$si_position-1] },        $form->{"partnumber_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}{si_description}[$si_position-1] },   $form->{"description_$i"};
      push @{ $form->{TEMPLATE_ARRAYS}{si_warehouse}[$si_position-1] },     $bin_wh->{warehouse};
      push @{ $form->{TEMPLATE_ARRAYS}{si_bin}[$si_position-1] },           $bin_wh->{bin};
      push @{ $form->{TEMPLATE_ARRAYS}{si_chargenumber}[$si_position-1] },  $si->{chargenumber};
      push @{ $form->{TEMPLATE_ARRAYS}{si_bestbefore}[$si_position-1] },    $si->{bestbefore};
      push @{ $form->{TEMPLATE_ARRAYS}{si_qty}[$si_position-1] },           $form->format_amount($myconfig, $si->{qty} * 1);
      push @{ $form->{TEMPLATE_ARRAYS}{si_qty_nofmt}[$si_position-1] },     $si->{qty} * 1;
      push @{ $form->{TEMPLATE_ARRAYS}{si_unit}[$si_position-1] },          $si->{unit};
    }

    if ($form->{"part_type_$i"} eq 'assembly') {
      $sameitem = "";

      # get parts and push them onto the stack
      my $sortorder = "";
      if ($form->{groupitems}) {
        $sortorder =
          qq|ORDER BY pg.partsgroup, a.position|;
      } else {
        $sortorder = qq|ORDER BY a.position|;
      }

      do_statement($form, $h_pg, $q_pg, conv_i($form->{"id_$i"}));

      while (my $ref = $h_pg->fetchrow_hashref("NAME_lc")) {
        if ($form->{groupitems} && $ref->{partsgroup} ne $sameitem) {
          map({ push(@{ $form->{TEMPLATE_ARRAYS}->{$_} }, "") } grep({ $_ ne "description" && $_ !~ /^si_/} (@arrays, @prepared_arrays)));
          map({ push(@{ $form->{TEMPLATE_ARRAYS}->{$_} }, []) } grep({ $_ =~ /^si_/} @arrays));
          $sameitem = ($ref->{partsgroup}) ? $ref->{partsgroup} : "--";
          push(@{ $form->{TEMPLATE_ARRAYS}->{entry_type}  }, 'assembly-item-partsgroup');
          push(@{ $form->{TEMPLATE_ARRAYS}->{description} }, $sameitem);
          $si_position++;
        }

        push(@{ $form->{TEMPLATE_ARRAYS}->{entry_type}  },  'assembly-item');
        push(@{ $form->{TEMPLATE_ARRAYS}->{description} }, $form->format_amount($myconfig, $ref->{qty} * $form->{"qty_$i"}) . qq| -- $ref->{partnumber}, $ref->{description}|);
        map({ push(@{ $form->{TEMPLATE_ARRAYS}->{$_} }, "") } grep({ $_ ne "description" && $_ !~ /^si_/} (@arrays, @prepared_arrays)));
        map({ push(@{ $form->{TEMPLATE_ARRAYS}->{$_} }, []) } grep({ $_ =~ /^si_/} @arrays));
        $si_position++;
      }
    }

    CVar->get_non_editable_ic_cvars(form               => $form,
                                    dbh                => $dbh,
                                    row                => $i,
                                    sub_module         => 'delivery_order_items',
                                    may_converted_from => ['orderitems', 'delivery_order_items']);

    push @{ $form->{TEMPLATE_ARRAYS}->{"ic_cvar_$_->{name}"} },
      CVar->format_to_template(CVar->parse($form->{"ic_cvar_$_->{name}_$i"}, $_), $_)
        for @{ $ic_cvar_configs };

    push @{ $form->{TEMPLATE_ARRAYS}->{"project_cvar_" . $_->config->name} }, $_->value_as_text for @{ $project->cvars_by_config };
  }

  $form->{totalweight}       = $form->format_amount($myconfig, $totalweight, 3);
  $form->{totalweight_nofmt} = $totalweight;
  my $defaults = AM->get_defaults();
  $form->{weightunit}        = $defaults->{weightunit};

  $h_pg->finish();
  $h_bin_wh->finish();

  $form->{department}    = SL::DB::Manager::Department->find_by(id => $form->{department_id})->description if $form->{department_id};
  $form->{delivery_term} = SL::DB::Manager::DeliveryTerm->find_by(id => $form->{delivery_term_id} || undef);
  $form->{delivery_term}->description_long($form->{delivery_term}->translated_attribute('description_long', $form->{language_id})) if $form->{delivery_term} && $form->{language_id};

  $form->{username} = $myconfig->{name};

  $main::lxdebug->leave_sub();
}

sub unpack_stock_information {
  $main::lxdebug->enter_sub();

  my $self   = shift;
  my %params = @_;

  Common::check_params_x(\%params, qw(packed));

  my $unpacked;

  eval { $unpacked = $params{packed} ? SL::YAML::Load($params{packed}) : []; };

  $unpacked = [] if (!$unpacked || ('ARRAY' ne ref $unpacked));

  foreach my $entry (@{ $unpacked }) {
    next if ('HASH' eq ref $entry);
    $unpacked = [];
    last;
  }

  $main::lxdebug->leave_sub();

  return $unpacked;
}

sub get_item_availability {
  $::lxdebug->enter_sub;

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(parts_id));

  my @parts_ids = 'ARRAY' eq ref $params{parts_id} ? @{ $params{parts_id} } : ($params{parts_id});

  my $query     =
    qq|SELECT i.warehouse_id, i.bin_id, i.chargenumber, i.bestbefore, SUM(qty) AS qty, i.parts_id,
         w.description AS warehousedescription,
         b.description AS bindescription
       FROM inventory i
       LEFT JOIN warehouse w ON (i.warehouse_id = w.id)
       LEFT JOIN bin b       ON (i.bin_id       = b.id)
       WHERE (i.parts_id IN (| . join(', ', ('?') x scalar(@parts_ids)) . qq|))
       GROUP BY i.warehouse_id, i.bin_id, i.chargenumber, i.bestbefore, i.parts_id, w.description, b.description
       HAVING SUM(qty) > 0
       ORDER BY LOWER(w.description), LOWER(b.description), LOWER(i.chargenumber), i.bestbefore
|;
  my $contents = selectall_hashref_query($::form, $::form->get_standard_dbh, $query, @parts_ids);

  $::lxdebug->leave_sub;

  return @{ $contents };
}


sub check_stock_availability {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(requests parts_id));

  my $myconfig    = \%main::myconfig;
  my $form        =  $main::form;

  my $dbh         = $form->get_standard_dbh($myconfig);

  my $units       = AM->retrieve_units($myconfig, $form);

  my ($partunit)  = selectrow_query($form, $dbh, qq|SELECT unit FROM parts WHERE id = ?|, conv_i($params{parts_id}));
  my $unit_factor = $units->{$partunit}->{factor} || 1;

  my @contents    = $self->get_item_availability(%params);

  my @errors;

  foreach my $sinfo (@{ $params{requests} }) {
    my $found = 0;

    foreach my $row (@contents) {
      next if (($row->{bin_id}       != $sinfo->{bin_id}) ||
               ($row->{warehouse_id} != $sinfo->{warehouse_id}) ||
               ($row->{chargenumber} ne $sinfo->{chargenumber}) ||
               ($row->{bestbefore}   ne $sinfo->{bestbefore}));

      $found       = 1;

      my $base_qty = $sinfo->{qty} * $units->{$sinfo->{unit}}->{factor} / $unit_factor;

      if ($base_qty > $row->{qty}) {
        $sinfo->{error} = 1;
        push @errors, $sinfo;

        last;
      }
    }

    push @errors, $sinfo if (!$found);
  }

  $main::lxdebug->leave_sub();

  return @errors;
}

sub transfer_in_out {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(direction requests));

  if (!@{ $params{requests} }) {
    $main::lxdebug->leave_sub();
    return;
  }

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $prefix   = $params{direction} eq 'in' ? 'dst' : 'src';

  my @transfers;

  foreach my $request (@{ $params{requests} }) {
    push @transfers, {
      'parts_id'                      => $request->{parts_id},
      "${prefix}_warehouse_id"        => $request->{warehouse_id},
      "${prefix}_bin_id"              => $request->{bin_id},
      'chargenumber'                  => $request->{chargenumber},
      'bestbefore'                    => $request->{bestbefore},
      'qty'                           => $request->{qty},
      'unit'                          => $request->{unit},
      'oe_id'                         => $form->{id},
      'shippingdate'                  => 'current_date',
      'transfer_type'                 => $params{direction} eq 'in' ? 'stock' : 'shipped',
      'project_id'                    => $request->{project_id},
      'delivery_order_items_stock_id' => $request->{delivery_order_items_stock_id},
      'comment'                       => $request->{comment},
    };
  }

  WH->transfer(@transfers);

  if ($::instance_conf->get_shipped_qty_require_stock_out) {
    $self->mark_orders_if_delivered('do_id' => $form->{id},
                                    'type'  => $form->{type} eq 'sales_delivery_order' ? 'sales' : 'purchase');
  }

  $main::lxdebug->leave_sub();
}

sub is_marked_as_delivered {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(id));

  my $myconfig    = \%main::myconfig;
  my $form        = $main::form;

  my $dbh         = $params{dbh} || $form->get_standard_dbh($myconfig);

  my ($delivered) = selectfirst_array_query($form, $dbh, qq|SELECT delivered FROM delivery_orders WHERE id = ?|, conv_i($params{id}));

  $main::lxdebug->leave_sub();

  return $delivered ? 1 : 0;
}

1;
