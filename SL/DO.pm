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
# Delivery Order entry module
#======================================================================

package DO;

use List::Util qw(max);
use YAML;

use SL::AM;
use SL::Common;
use SL::DBUtils;

sub transactions {
  $main::lxdebug->enter_sub();

  my ($self)   = @_;

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  # connect to database
  my $dbh = $form->get_standard_dbh($myconfig);

  my (@where, @values, $where);

  my $vc = $form->{vc} eq "customer" ? "customer" : "vendor";

  $query =
    qq|SELECT dord.id, dord.donumber, dord.ordnumber, dord.transdate,
         ct.name, dord.${vc}_id, dord.globalproject_id,
         dord.closed, dord.delivered, dord.shippingpoint, dord.shipvia,
         dord.transaction_description,
         pr.projectnumber AS globalprojectnumber,
         e.name AS employee,
         sm.name AS salesman
       FROM delivery_orders dord
       LEFT JOIN $vc ct ON (dord.${vc}_id = ct.id)
       LEFT JOIN employee e ON (dord.employee_id = e.id)
       LEFT JOIN employee sm ON (dord.salesman_id = sm.id)
       LEFT JOIN project pr ON (dord.globalproject_id = pr.id)|;

  push @where, ($form->{type} eq 'sales_delivery_order' ? '' : 'NOT ') . qq|COALESCE(dord.is_sales, FALSE)|;

  my $department_id = (split /--/, $form->{department})[1];
  if ($department_id) {
    push @where,  qq|dord.department_id = ?|;
    push @values, conv_i($department_id);
  }

  if ($form->{project_id}) {
    $query .=
      qq|(dord.globalproject_id = ?) OR EXISTS
          (SELECT * FROM delivery_order_items doi
           WHERE (doi.project_id = ?) AND (oi.delivery_order_id = dord.id))|;
    push @values, conv_i($form->{project_id}), conv_i($form->{project_id});
  }

  if ($form->{"${vc}_id"}) {
    push @where,  qq|dord.${vc}_id = ?|;
    push @values, $form->{"${vc}_id"};

  } elsif ($form->{$vc}) {
    push @where,  qq|ct.name ILIKE ?|;
    push @values, '%' . $form->{$vc} . '%';
  }

  foreach my $item (qw(employee_id salesman_id)) {
    next unless ($form->{$item});
    push @where, "dord.$item = ?";
    push @values, conv_i($form->{$item});
  }

  foreach my $item (qw(donumber ordnumber cusordnumber transaction_description)) {
    next unless ($form->{$item});
    push @where,  qq|dord.$item ILIKE ?|;
    push @values, '%' . $form->{$item} . '%';
  }

  if (!($form->{open} && $form->{closed})) {
    push @where, ($form->{open} ? "NOT " : "") . "COALESCE(dord.closed, FALSE)";
  }

  if (($form->{notdelivered} || $form->{delivered}) &&
      ($form->{notdelivered} ne $form->{delivered})) {
    push @where, ($form->{delivered} ? "" : "NOT ") . "COALESCE(dord.delivered, FALSE)";
  }

  if($form->{transdatefrom}) {
    push @where,  qq|dord.transdate >= ?|;
    push @values, conv_date($form->{transdatefrom});
  }

  if($form->{transdateto}) {
    push @where,  qq|dord.transdate <= ?|;
    push @values, conv_date($form->{transdateto});
  }

  if (@where) {
    $query .= " WHERE " . join(" AND ", map { "($_)" } @where);
  }

  my %allowed_sort_columns = (
    "transdate"               => "dord.transdate",
    "id"                      => "dord.id",
    "donumber"                => "dord.donumber",
    "ordnumber"               => "dord.ordnumber",
    "name"                    => "ct.name",
    "employee"                => "e.name",
    "salesman"                => "sm.name",
    "shipvia"                 => "dord.shipvia",
    "transaction_description" => "dord.transaction_description"
  );

  my $sortoder = "dord.id";
  if ($form->{sort} && grep($form->{sort}, keys(%allowed_sort_columns))) {
    $sortorder = $allowed_sort_columns{$form->{sort}};
  }

  $query .= qq| ORDER by | . $sortorder;

  $form->{DO} = selectall_hashref_query($form, $dbh, $query, @values);

  if (scalar @{ $form->{DO} }) {
    $query =
      qq|SELECT id
         FROM oe
         WHERE NOT COALESCE(quotation, FALSE)
           AND (ordnumber = ?)
           AND (COALESCE(${vc}_id, 0) != 0)|;

    my $sth = prepare_query($form, $dbh, $query);

    foreach my $dord (@{ $form->{DO} }) {
      do_statement($form, $sth, $query, $dord->{ordnumber});
      ($dord->{oe_id}) = $sth->fetchrow_array();
    }

    $sth->finish();
  }

  $main::lxdebug->leave_sub();
}

sub save {
  $main::lxdebug->enter_sub();

  my ($self)   = @_;

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  # connect to database, turn off autocommit
  my $dbh = $form->get_standard_dbh($myconfig);

  my ($query, @values, $sth, $null);

  my $all_units = AM->retrieve_units($myconfig, $form);
  $form->{all_units} = $all_units;

  $form->{donumber}    = $form->update_defaults($myconfig, $form->{type} eq 'sales_delivery_order' ? 'sdonumber' : 'pdonumber', $dbh) unless $form->{donumber};
  $form->{employee_id} = (split /--/, $form->{employee})[1] if !$form->{employee_id};
  $form->get_employee($dbh) unless ($form->{employee_id});

  my $ml = ($form->{type} eq 'sales_delivery_order') ? 1 : -1;

  if ($form->{id}) {

    $query = qq|DELETE FROM delivery_order_items_stock WHERE delivery_order_item_id IN (SELECT id FROM delivery_order_items WHERE delivery_order_id = ?)|;
    do_query($form, $dbh, $query, conv_i($form->{id}));

    $query = qq|DELETE FROM delivery_order_items WHERE delivery_order_id = ?|;
    do_query($form, $dbh, $query, conv_i($form->{id}));

    $query = qq|DELETE FROM shipto WHERE trans_id = ? AND module = 'DO'|;
    do_query($form, $dbh, $query, conv_i($form->{id}));

  } else {

    $query = qq|SELECT nextval('id')|;
    ($form->{id}) = selectrow_query($form, $dbh, $query);

    $query = qq|INSERT INTO delivery_orders (id, donumber, employee_id) VALUES (?, '', ?)|;
    do_query($form, $dbh, $query, $form->{id}, conv_i($form->{employee_id}));
  }

  my $project_id;
  my $reqdate;

  $form->get_lists('price_factors' => 'ALL_PRICE_FACTORS');
  my %price_factors = map { $_->{id} => $_->{factor} } @{ $form->{ALL_PRICE_FACTORS} };
  my $price_factor;

  my %part_id_map = map { $_ => 1 } grep { $_ } map { $form->{"id_$_"} } (1 .. $form->{rowcount});
  my @part_ids    = keys %part_id_map;
  my %part_unit_map;

  if (@part_ids) {
    $query         = qq|SELECT id, unit FROM parts WHERE id IN (| . join(', ', map { '?' } @part_ids) . qq|)|;
    %part_unit_map = selectall_as_map($form, $dbh, $query, 'id', 'unit', @part_ids);
  }

  my $q_item_id = qq|SELECT nextval('delivery_order_items_id')|;
  my $h_item_id = prepare_query($form, $dbh, $q_item_id);

  my $q_item =
    qq|INSERT INTO delivery_order_items (
         id, delivery_order_id, parts_id, description, longdescription, qty, base_qty,
         sellprice, discount, unit, reqdate, project_id, serialnumber,
         ordnumber, transdate, cusordnumber,
         lastcost, price_factor_id, price_factor, marge_price_factor)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
         (SELECT factor FROM price_factors WHERE id = ?), ?)|;
  my $h_item = prepare_query($form, $dbh, $q_item);

  my $q_item_stock =
    qq|INSERT INTO delivery_order_items_stock (delivery_order_item_id, qty, unit, warehouse_id, bin_id, chargenumber)
       VALUES (?, ?, ?, ?, ?, ?)|;
  my $h_item_stock = prepare_query($form, $dbh, $q_item_stock);

  my $in_out       = $form->{type} =~ /^sales/ ? 'out' : 'in';

  for my $i (1 .. $form->{rowcount}) {
    next if (!$form->{"id_$i"});

    $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});

    my $item_unit = $part_unit_map{$form->{"id_$i"}};

    my $basefactor = 1;
    if (defined($all_units->{$item_unit}->{factor}) && (($all_units->{$item_unit}->{factor} * 1) != 0)) {
      $basefactor = $all_units->{$form->{"unit_$i"}}->{factor} / $all_units->{$item_unit}->{factor};
    }
    my $baseqty = $form->{"qty_$i"} * $basefactor;

    $form->{"lastcost_$i"} *= 1;

    # set values to 0 if nothing entered
    $form->{"discount_$i"}  = $form->parse_amount($myconfig, $form->{"discount_$i"}) / 100;
    $form->{"sellprice_$i"} = $form->parse_amount($myconfig, $form->{"sellprice_$i"});

    $price_factor = $price_factors{ $form->{"price_factor_id_$i"} } || 1;
    $linetotal    = $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"} / $price_factor, 2);

    $reqdate = ($form->{"reqdate_$i"}) ? $form->{"reqdate_$i"} : undef;

    do_statement($form, $h_item_id, $q_item_id);
    my ($item_id) = $h_item_id->fetchrow_array();

    # save detail record in delivery_order_items table
    @values = (conv_i($item_id), conv_i($form->{id}), conv_i($form->{"id_$i"}),
               $form->{"description_$i"}, $form->{"longdescription_$i"},
               $form->{"qty_$i"}, $baseqty,
               $form->{"sellprice_$i"}, $form->{"discount_$i"},
               $form->{"unit_$i"}, conv_date($reqdate), conv_i($form->{"project_id_$i"}),
               $form->{"serialnumber_$i"},
               $form->{"ordnumber_$i"}, conv_date($form->{"transdate_$i"}),
               $form->{"cusordnumber_$i"},
               $form->{"lastcost_$i"},
               conv_i($form->{"price_factor_id_$i"}), conv_i($form->{"price_factor_id_$i"}),
               conv_i($form->{"marge_price_factor_$i"}));
    do_statement($form, $h_item, $q_item, @values);

    my $stock_info = DO->unpack_stock_information('packed' => $form->{"stock_${in_out}_$i"});

    foreach my $sinfo (@{ $stock_info }) {
      @values = ($item_id, $sinfo->{qty}, $sinfo->{unit}, conv_i($sinfo->{warehouse_id}),
                 conv_i($sinfo->{bin_id}), $sinfo->{chargenumber});
      do_statement($form, $h_item_stock, $q_item_stock, @values);
    }
  }

  $h_item_id->finish();
  $h_item->finish();
  $h_item_stock->finish();

  ($null, $form->{department_id}) = split(/--/, $form->{department});

  # save DO record
  $query =
    qq|UPDATE delivery_orders SET
         donumber = ?, ordnumber = ?, cusordnumber = ?, transdate = ?, vendor_id = ?,
         customer_id = ?, reqdate = ?,
         shippingpoint = ?, shipvia = ?, notes = ?, intnotes = ?, closed = ?,
         delivered = ?, department_id = ?, language_id = ?, shipto_id = ?,
         globalproject_id = ?, employee_id = ?, salesman_id = ?, cp_id = ?, transaction_description = ?,
         is_sales = ?
       WHERE id = ?|;

  @values = ($form->{donumber}, $form->{ordnumber},
             $form->{cusordnumber}, conv_date($form->{transdate}),
             conv_i($form->{vendor_id}), conv_i($form->{customer_id}),
             conv_date($reqdate), $form->{shippingpoint}, $form->{shipvia},
             $form->{notes}, $form->{intnotes},
             $form->{closed} ? 't' : 'f', $form->{delivered} ? "t" : "f",
             conv_i($form->{department_id}), conv_i($form->{language_id}), conv_i($form->{shipto_id}),
             conv_i($form->{globalproject_id}), conv_i($form->{employee_id}),
             conv_i($form->{salesman_id}), conv_i($form->{cp_id}),
             $form->{transaction_description},
             $form->{type} =~ /^sales/ ? 't' : 'f',
             conv_i($form->{id}));
  do_query($form, $dbh, $query, @values);

  # add shipto
  $form->{name} = $form->{ $form->{vc} };
  $form->{name} =~ s/--$form->{"$form->{vc}_id"}//;

  if (!$form->{shipto_id}) {
    $form->add_shipto($dbh, $form->{id}, "DO");
  }

  # save printed, emailed, queued
  $form->save_status($dbh);

  my $rc = $dbh->commit();

  $form->{saved_donumber} = $form->{donumber};

  Common::webdav_folder($form) if ($main::webdav);

  $main::lxdebug->leave_sub();

  return $rc;
}

sub close_order {
  $main::lxdebug->enter_sub();

  my ($self)   = @_;

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  return $main::lxdebug->leave_sub() unless ($form->{id});

  my $dbh = $form->get_standard_dbh($myconfig);
  do_query($form, $dbh, qq|UPDATE do SET closed = TRUE where id = ?|, conv_i($form->{id}));
  $dbh->commit();

  $main::lxdebug->leave_sub();
}

sub delete {
  $main::lxdebug->enter_sub();

  my ($self)   = @_;

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;
  my $spool    = $main::spool;

  # connect to database
  my $dbh = $form->get_standard_dbh($myconfig);

  # delete spool files
  my $query = qq|SELECT s.spoolfile FROM status s WHERE s.trans_id = ?|;
  my $sth   = prepare_execute_query($form, $dbh, $query, conv_i($form->{id}));

  my $spoolfile;
  my @spoolfiles = ();

  while (($spoolfile) = $sth->fetchrow_array) {
    push @spoolfiles, $spoolfile;
  }
  $sth->finish();

  # delete-values
  @values = (conv_i($form->{id}));

  # delete status entries
  $query = qq|DELETE FROM status
              WHERE trans_id = ?|;
  do_query($form, $dbh, $query, @values);

  # delete individual entries
  $query = qq|DELETE FROM delivery_order_items_stock
              WHERE delivery_order_item_id IN (
                SELECT id FROM delivery_order_items
                WHERE delivery_order_id = ?
              )|;
  do_query($form, $dbh, $query, @values);

  # delete individual entries
  $query = qq|DELETE FROM delivery_order_items
              WHERE delivery_order_id = ?|;
  do_query($form, $dbh, $query, @values);

  # delete DO record
  $query = qq|DELETE FROM delivery_orders
              WHERE id = ?|;
  do_query($form, $dbh, $query, @values);

  $query = qq|DELETE FROM shipto
              WHERE trans_id = ? AND module = 'DO'|;
  do_query($form, $dbh, $query, @values);

  my $rc = $dbh->commit();

  if ($rc) {
    foreach $spoolfile (@spoolfiles) {
      unlink "$spool/$spoolfile" if $spoolfile;
    }
  }

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

  my $vc   = $params{vc} eq 'customer' ? 'customer' : 'vendor';

  my $mode = !$params{ids} ? 'default' : ref $params{ids} eq 'ARRAY' ? 'multi' : 'single';

  if ($mode eq 'default') {
    $ref = selectfirst_hashref_query($form, $dbh, qq|SELECT current_date AS transdate, current_date AS reqdate|);
    map { $form->{$_} = $ref->{$_} } keys %$ref;

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
    qq|SELECT dord.cp_id, dord.donumber, dord.ordnumber, dord.transdate, dord.reqdate,
         dord.shippingpoint, dord.shipvia, dord.notes, dord.intnotes,
         e.name AS employee, dord.employee_id, dord.salesman_id,
         dord.${vc}_id, cv.name AS ${vc},
         dord.closed, dord.reqdate, dord.department_id, dord.cusordnumber,
         d.description AS department, dord.language_id,
         dord.shipto_id,
         dord.globalproject_id, dord.delivered, dord.transaction_description
       FROM delivery_orders dord
       JOIN ${vc} cv ON (dord.${vc}_id = cv.id)
       LEFT JOIN employee e ON (dord.employee_id = e.id)
       LEFT JOIN department d ON (dord.department_id = d.id)
       WHERE dord.id IN ($do_ids_placeholders)|;
  $sth = prepare_execute_query($form, $dbh, $query, @do_ids);

  delete $form->{"${vc}_id"};
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    if ($form->{"${vc}_id"} && ($ref->{"${vc}_id"} != $form->{"${vc}_id"})) {
      $sth->finish();
      $main::lxdebug->leave_sub();

      return 0;
    }

    map { $form->{$_} = $ref->{$_} } keys %$ref if ($ref);
  }
  $sth->finish();

  $form->{saved_donumber} = $form->{donumber};

  # if not given, fill transdate with current_date
  $form->{transdate} = $form->current_date($myconfig) unless $form->{transdate};

  if ($mode eq 'single') {
    $query = qq|SELECT s.* FROM shipto s WHERE s.trans_id = ? AND s.module = 'DO'|;
    $sth   = prepare_execute_query($form, $dbh, $query, $form->{id});

    $ref   = $sth->fetchrow_hashref(NAME_lc);
    delete $ref->{id};
    map { $form->{$_} = $ref->{$_} } keys %$ref;
    $sth->finish();

    # get printed, emailed and queued
    $query = qq|SELECT s.printed, s.emailed, s.spoolfile, s.formname FROM status s WHERE s.trans_id = ?|;
    $sth   = prepare_execute_query($form, $dbh, $query, conv_i($form->{id}));

    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      $form->{printed} .= "$ref->{formname} " if $ref->{printed};
      $form->{emailed} .= "$ref->{formname} " if $ref->{emailed};
      $form->{queued}  .= "$ref->{formname} $ref->{spoolfile} " if $ref->{spoolfile};
    }
    $sth->finish();
    map { $form->{$_} =~ s/ +$//g } qw(printed emailed queued);

  } else {
    delete $form->{id};
  }

  my %oid = ('Pg'     => 'oid',
             'Oracle' => 'rowid');

  # retrieve individual items
  # this query looks up all information about the items
  # stuff different from the whole will not be overwritten, but saved with a suffix.
  $query =
    qq|SELECT doi.id AS delivery_order_items_id,
         p.partnumber, p.assembly, doi.description, doi.qty,
         doi.sellprice, doi.parts_id AS id, doi.unit, doi.discount, p.bin, p.notes AS partnotes,
         doi.reqdate, doi.project_id, doi.serialnumber, doi.lastcost,
         doi.ordnumber, doi.transdate, doi.cusordnumber, doi.longdescription,
         doi.price_factor_id, doi.price_factor, doi.marge_price_factor,
         pr.projectnumber,
         pg.partsgroup
       FROM delivery_order_items doi
       JOIN parts p ON (doi.parts_id = p.id)
       JOIN delivery_orders dord ON (doi.delivery_order_id = dord.id)
       LEFT JOIN project pr ON (doi.project_id = pr.id)
       LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
       WHERE doi.delivery_order_id IN ($do_ids_placeholders)
       ORDER BY doi.$oid{$myconfig->{dbdriver}}|;

  $form->{form_details} = selectall_hashref_query($form, $dbh, $query, @do_ids);

  if ($mode eq 'single') {
    my $in_out = $form->{type} =~ /^sales/ ? 'out' : 'in';

    $query =
      qq|SELECT qty, unit, bin_id, warehouse_id, chargenumber
         FROM delivery_order_items_stock
         WHERE delivery_order_item_id = ?|;
    my $sth = prepare_query($form, $dbh, $query);

    foreach my $doi (@{ $form->{form_details} }) {
      do_statement($form, $sth, $query, conv_i($doi->{delivery_order_items_id}));
      my $requests = [];
      while (my $ref = $sth->fetchrow_hashref()) {
        push @{ $requests }, $ref;
      }

      $doi->{"stock_${in_out}"} = YAML::Dump($requests);
    }

    $sth->finish();
  }

  Common::webdav_folder($form) if ($main::webdav);

  $main::lxdebug->leave_sub();

  return 1;
}

sub order_details {
  $main::lxdebug->enter_sub();

  my ($self)   = @_;

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

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

  my %oid = ('Pg'     => 'oid',
             'Oracle' => 'rowid');

  my (@project_ids, %projectnumbers);

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

  if (@project_ids) {
    $query = "SELECT id, projectnumber FROM project WHERE id IN (" .
      join(", ", map("?", @project_ids)) . ")";
    $sth = prepare_execute_query($form, $dbh, $query, @project_ids);
    while (my $ref = $sth->fetchrow_hashref()) {
      $projectnumbers{$ref->{id}} = $ref->{projectnumber};
    }
    $sth->finish();
  }

  $form->{"globalprojectnumber"} =
    $projectnumbers{$form->{"globalproject_id"}};

  my $q_pg     = qq|SELECT p.partnumber, p.description, p.unit, a.qty, pg.partsgroup
                    FROM assembly a
                    JOIN parts p ON (a.parts_id = p.id)
                    LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
                    WHERE a.bom = '1'
                      AND a.id = ? $sortorder|;
  my $h_pg     = prepare_query($form, $dbh, $q_pg);

  my $q_bin_wh = qq|SELECT (SELECT description FROM bin       WHERE id = ?) AS bin,
                           (SELECT description FROM warehouse WHERE id = ?) AS warehouse|;
  my $h_bin_wh = prepare_query($form, $dbh, $q_bin_wh);

  my $in_out   = $form->{type} =~ /^sales/ ? 'out' : 'in';

  my $num_si   = 0;

  my @arrays =
    qw(runningnumber number description longdescription qty unit
       partnotes serialnumber reqdate projectnumber
       si_runningnumber si_number si_description
       si_warehouse si_bin si_chargenumber si_qty si_unit);

  my $sameitem = "";
  foreach $item (sort { $a->[1] cmp $b->[1] } @partsgroup) {
    $i = $item->[0];

    next if (!$form->{"id_$i"});

    $position++;

    if ($item->[1] ne $sameitem) {
      push(@{ $form->{description} }, qq|$item->[1]|);
      $sameitem = $item->[1];

      map({ push(@{ $form->{$_} }, "") } grep({ $_ ne "description" } @arrays));
    }

    $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});

    # add number, description and qty to $form->{number}, ....

    my $price_factor = $price_factors{$form->{"price_factor_id_$i"}} || { 'factor' => 1 };

    push @{ $form->{runningnumber} },   $position;
    push @{ $form->{number} },          $form->{"partnumber_$i"};
    push @{ $form->{description} },     $form->{"description_$i"};
    push @{ $form->{longdescription} }, $form->{"longdescription_$i"};
    push @{ $form->{qty} },             $form->format_amount($myconfig, $form->{"qty_$i"});
    push @{ $form->{unit} },            $form->{"unit_$i"};
    push @{ $form->{partnotes} },       $form->{"partnotes_$i"};
    push @{ $form->{serialnumber} },    $form->{"serialnumber_$i"};
    push @{ $form->{reqdate} },         $form->{"reqdate_$i"};
    push @{ $form->{projectnumber} },   $projectnumbers{$form->{"project_id_$i"}};

    if ($form->{"assembly_$i"}) {
      $sameitem = "";

      # get parts and push them onto the stack
      my $sortorder = "";
      if ($form->{groupitems}) {
        $sortorder =
          qq|ORDER BY pg.partsgroup, a.$oid{$myconfig->{dbdriver}}|;
      } else {
        $sortorder = qq|ORDER BY a.$oid{$myconfig->{dbdriver}}|;
      }

      do_statement($form, $h_pg, $q_pg, conv_i($form->{"id_$i"}));

      while (my $ref = $h_pg->fetchrow_hashref(NAME_lc)) {
        if ($form->{groupitems} && $ref->{partsgroup} ne $sameitem) {
          map({ push(@{ $form->{$_} }, "") } grep({ $_ ne "description" } @arrays));
          $sameitem = ($ref->{partsgroup}) ? $ref->{partsgroup} : "--";
          push(@{ $form->{description} }, $sameitem);
        }

        push(@{ $form->{description} }, $form->format_amount($myconfig, $ref->{qty} * $form->{"qty_$i"}) . qq|, $ref->{partnumber}, $ref->{description}|);

        map({ push(@{ $form->{$_} }, "") } grep({ $_ ne "description" } @arrays));
      }
    }

    if ($form->{"inventory_accno_$i"} && !$form->{"assembly_$i"}) {
      my $stock_info = DO->unpack_stock_information('packed' => $form->{"stock_${in_out}_$i"});

      foreach my $si (@{ $stock_info }) {
        $num_si++;

        do_statement($form, $h_bin_wh, $q_bin_wh, conv_i($si->{bin_id}), conv_i($si->{warehouse_id}));
        my $bin_wh = $h_bin_wh->fetchrow_hashref();

        push @{ $form->{si_runningnumber} }, $num_si;
        push @{ $form->{si_number} },        $form->{"partnumber_$i"};
        push @{ $form->{si_description} },   $form->{"description_$i"};
        push @{ $form->{si_warehouse} },     $bin_wh->{warehouse};
        push @{ $form->{si_bin} },           $bin_wh->{bin};
        push @{ $form->{si_chargenumber} },  $si->{chargenumber};
        push @{ $form->{si_qty} },           $form->format_amount($myconfig, $si->{qty} * 1);
        push @{ $form->{si_unit} },          $si->{unit};
      }
    }
  }

  $h_pg->finish();
  $h_bin_wh->finish();

  $form->{username} = $myconfig->{name};

  $main::lxdebug->leave_sub();
}

sub project_description {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $id) = @_;

  my $query = qq|SELECT description FROM project WHERE id = ?|;
  my ($value) = selectrow_query($form, $dbh, $query, $id);

  $main::lxdebug->leave_sub();

  return $value;
}

sub unpack_stock_information {
  $main::lxdebug->enter_sub();

  my $self   = shift;
  my %params = @_;

  Common::check_params_x(\%params, qw(packed));

  my $unpacked;

  eval { $unpacked = $params{packed} ? YAML::Load($params{packed}) : []; };

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
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(parts_id));

  my @parts_ids = 'ARRAY' eq ref $params{parts_id} ? @{ $params{parts_id} } : ($params{parts_id});
  my $form      = $main::form;

  my $query     =
    qq|SELECT i.warehouse_id, i.bin_id, i.chargenumber, SUM(qty) AS qty, i.parts_id,
         w.description AS warehousedescription,
         b.description AS bindescription
       FROM inventory i
       LEFT JOIN warehouse w ON (i.warehouse_id = w.id)
       LEFT JOIN bin b       ON (i.bin_id       = b.id)
       WHERE (i.parts_id IN (| . join(', ', ('?') x scalar(@parts_ids)) . qq|))
         AND qty > 0
       GROUP BY i.warehouse_id, i.bin_id, i.chargenumber, i.parts_id, w.description, b.description
       ORDER BY LOWER(w.description), LOWER(b.description), LOWER(i.chargenumber)|;

  my $contents = selectall_hashref_query($form, $form->get_standard_dbh($myconfig), $query, @parts_ids);

  $main::lxdebug->leave_sub();

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
               ($row->{chargenumber} ne $sinfo->{chargenumber}));

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
      'parts_id'               => $request->{parts_id},
      "${prefix}_warehouse_id" => $request->{warehouse_id},
      "${prefix}_bin_id"       => $request->{bin_id},
      'chargenumber'           => $request->{chargenumber},
      'qty'                    => $request->{qty},
      'unit'                   => $request->{unit},
      'oe_id'                  => $form->{id},
      'shippingdate'           => 'current_date',
      'transfer_type'          => $params{direction} eq 'in' ? 'stock' : 'shipped',
    };
  }

  WH->transfer(@transfers);

  $main::lxdebug->leave_sub();
}

1;
