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
# Inventory Control backend
#
#======================================================================

package IC;
use Data::Dumper;

sub get_part {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to db
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT p.*,
                 c1.accno AS inventory_accno,
		 c2.accno AS income_accno,
		 c3.accno AS expense_accno,
		 pg.partsgroup
	         FROM parts p
		 LEFT JOIN chart c1 ON (p.inventory_accno_id = c1.id)
		 LEFT JOIN chart c2 ON (p.income_accno_id = c2.id)
		 LEFT JOIN chart c3 ON (p.expense_accno_id = c3.id)
		 LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
                 WHERE p.id = $form->{id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  my $ref = $sth->fetchrow_hashref(NAME_lc);

  # copy to $form variables
  map { $form->{$_} = $ref->{$_} } (keys %{$ref});

  $sth->finish;

  my %oid = ('Pg'     => 'a.oid',
             'Oracle' => 'a.rowid');

  # part or service item
  $form->{item} = ($form->{inventory_accno}) ? 'part' : 'service';
  if ($form->{assembly}) {
    $form->{item} = 'assembly';

    # retrieve assembly items
    $query = qq|SELECT p.id, p.partnumber, p.description,
                p.sellprice, p.weight, a.qty, a.bom, p.unit,
		pg.partsgroup
                FROM parts p
		JOIN assembly a ON (a.parts_id = p.id)
		LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		WHERE a.id = $form->{id}
		ORDER BY $oid{$myconfig->{dbdriver}}|;

    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $form->{assembly_rows} = 0;
    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
      $form->{assembly_rows}++;
      foreach my $key (keys %{$ref}) {
        $form->{"${key}_$form->{assembly_rows}"} = $ref->{$key};
      }
    }
    $sth->finish;

  }

  # setup accno hash for <option checked> {amount} is used in create_links
  $form->{amount}{IC}         = $form->{inventory_accno};
  $form->{amount}{IC_income}  = $form->{income_accno};
  $form->{amount}{IC_sale}    = $form->{income_accno};
  $form->{amount}{IC_expense} = $form->{expense_accno};
  $form->{amount}{IC_cogs}    = $form->{expense_accno};

  # get prices
  $query =
    qq|SELECT p.parts_id, p.pricegroup_id, p.price, (SELECT pg.pricegroup FROM pricegroup pg WHERE pg.id=p.pricegroup_id) AS pricegroup FROM prices p
              WHERE parts_id = $form->{id}
              ORDER by pricegroup|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  @pricegroups          = ();
  @pricegroups_not_used = ();

  #for pricegroups
  my $i = 1;
  while (
         ($form->{"klass_$i"}, $form->{"pricegroup_id_$i"},
          $form->{"price_$i"}, $form->{"pricegroup_$i"})
         = $sth->fetchrow_array
    ) {
    $form->{"price_$i"} = $form->round_amount($form->{"price_$i"}, 5);
    $form->{"price_$i"} =
      $form->format_amount($myconfig, $form->{"price_$i"}, 5);
    push @pricegroups, $form->{"pricegroup_id_$i"};
    $i++;
  }

  $sth->finish;

  # get pricegroups
  $query = qq|SELECT p.id, p.pricegroup FROM pricegroup p|;

  $pkq = $dbh->prepare($query);
  $pkq->execute || $form->dberror($query);
  while ($pkr = $pkq->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{PRICEGROUPS} }, $pkr;
  }
  $pkq->finish;

  #find not used pricegroups
  while ($tmp = pop @{ $form->{PRICEGROUPS} }) {
    my $insert = 0;
    foreach $item (@pricegroups) {
      if ($item eq $tmp->{id}) {

        #drop
        $insert = 1;
      }
    }
    if ($insert == 0) {
      push @pricegroups_not_used, $tmp;
    }
  }

  # if not used pricegroups are avaible
  if (@pricegroups_not_used) {

    foreach $name (@pricegroups_not_used) {
      $form->{"klass_$i"} = "$name->{id}";
      $form->{"price_$i"} = $form->round_amount($form->{sellprice}, 5);
      $form->{"price_$i"} =
        $form->format_amount($myconfig, $form->{"price_$i"}, 5);
      $form->{"pricegroup_id_$i"} = "$name->{id}";
      $form->{"pricegroup_$i"}    = "$name->{pricegroup}";
      $i++;
    }
  }

  #correct rows
  $form->{price_rows} = $i - 1;

  unless ($form->{item} eq 'service') {

    # get makes
    if ($form->{makemodel}) {
      $query = qq|SELECT m.make, m.model FROM makemodel m
                  WHERE m.parts_id = $form->{id}|;

      $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);

      my $i = 1;
      while (($form->{"make_$i"}, $form->{"model_$i"}) = $sth->fetchrow_array)
      {
        $i++;
      }
      $sth->finish;
      $form->{makemodel_rows} = $i - 1;

    }
  }

  # now get accno for taxes
  $query = qq|SELECT c.accno
              FROM chart c, partstax pt
	      WHERE pt.chart_id = c.id
	      AND pt.parts_id = $form->{id}|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (($key) = $sth->fetchrow_array) {
    $form->{amount}{$key} = $key;
  }

  $sth->finish;

  # is it an orphan
  $query = qq|SELECT i.parts_id
              FROM invoice i
	      WHERE i.parts_id = $form->{id}
	    UNION
	      SELECT o.parts_id
	      FROM orderitems o
	      WHERE o.parts_id = $form->{id}
	    UNION
	      SELECT a.parts_id
	      FROM assembly a
	      WHERE a.parts_id = $form->{id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  ($form->{orphaned}) = $sth->fetchrow_array;
  $form->{orphaned} = !$form->{orphaned};
  $sth->finish;

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_pricegroups {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;
  my $dbh                  = $form->dbconnect($myconfig);
  my $i                    = 1;
  my @pricegroups_not_used = ();

  # get pricegroups
  my $query = qq|SELECT p.id, p.pricegroup FROM pricegroup p|;

  my $pkq = $dbh->prepare($query);
  $pkq->execute || $form->dberror($query);
  while ($pkr = $pkq->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{PRICEGROUPS} }, $pkr;
  }
  $pkq->finish;

  #find not used pricegroups
  while ($tmp = pop @{ $form->{PRICEGROUPS} }) {
    push @pricegroups_not_used, $tmp;
  }

  # if not used pricegroups are avaible
  if (@pricegroups_not_used) {

    foreach $name (@pricegroups_not_used) {
      $form->{"klass_$i"} = "$name->{id}";
      $form->{"price_$i"} = $form->round_amount($form->{sellprice}, 5);
      $form->{"price_$i"} =
        $form->format_amount($myconfig, $form->{"price_$i"}, 5);
      $form->{"pricegroup_id_$i"} = "$name->{id}";
      $form->{"pricegroup_$i"}    = "$name->{pricegroup}";
      $i++;
    }
  }

  #correct rows
  $form->{price_rows} = $i - 1;

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub save {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  if ($form->{eur} && ($form->{item} ne 'service')) {
    $form->{IC} = $form->{IC_expense};
  }

  ($form->{inventory_accno}) = split(/--/, $form->{IC});
  ($form->{expense_accno})   = split(/--/, $form->{IC_expense});
  ($form->{income_accno})    = split(/--/, $form->{IC_income});

  # connect to database, turn off AutoCommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  # save the part
  # make up a unique handle and store in partnumber field
  # then retrieve the record based on the unique handle to get the id
  # replace the partnumber field with the actual variable
  # add records for makemodel

  # if there is a $form->{id} then replace the old entry
  # delete all makemodel entries and add the new ones

  # escape '
  map { $form->{$_} =~ s/\'/\'\'/g } qw(partnumber description notes unit);

  # undo amount formatting
  map { $form->{$_} = $form->parse_amount($myconfig, $form->{$_}) }
    qw(rop weight listprice sellprice gv lastcost stock);

  # set date to NULL if nothing entered
  $form->{priceupdate} =
    ($form->{priceupdate}) ? qq|'$form->{priceupdate}'| : "NULL";

  $form->{makemodel} = (($form->{make_1}) || ($form->{model_1})) ? 1 : 0;

  $form->{alternate} = 0;
  $form->{assembly} = ($form->{item} eq 'assembly') ? 1 : 0;
  $form->{obsolete} *= 1;
  $form->{shop}     *= 1;
  $form->{onhand}   *= 1;
  $form->{ve}       *= 1;
  $form->{ge}       *= 1;

  my ($query, $sth);

  if ($form->{id}) {

    # get old price
    $query = qq|SELECT p.sellprice, p.weight
                FROM parts p
		WHERE p.id = $form->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    my ($sellprice, $weight) = $sth->fetchrow_array;
    $sth->finish;

    # if item is part of an assembly adjust all assemblies
    $query = qq|SELECT a.id, a.qty
                FROM assembly a
		WHERE a.parts_id = $form->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    while (my ($id, $qty) = $sth->fetchrow_array) {
      &update_assembly($dbh, $form, $id, $qty, $sellprice * 1, $weight * 1);
    }
    $sth->finish;

    if ($form->{item} ne 'service') {

      # delete makemodel records
      $query = qq|DELETE FROM makemodel
		  WHERE parts_id = $form->{id}|;
      $dbh->do($query) || $form->dberror($query);
    }

    if ($form->{item} eq 'assembly') {
      if ($form->{onhand} != 0) {
        &adjust_inventory($dbh, $form, $form->{id}, $form->{onhand} * -1);
      }

      # delete assembly records
      $query = qq|DELETE FROM assembly
		  WHERE id = $form->{id}|;
      $dbh->do($query) || $form->dberror($query);

      $form->{onhand} += $form->{stock};
    }

    # delete tax records
    $query = qq|DELETE FROM partstax
		WHERE parts_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);

  } else {
    my $uid = rand() . time;
    $uid .= $form->{login};

    $query = qq|SELECT p.id FROM parts p
                WHERE p.partnumber = '$form->{partnumber}'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    ($form->{id}) = $sth->fetchrow_array;
    $sth->finish;

    if ($form->{id} ne "") {
      $main::lxdebug->leave_sub();
      return 3;
    }
    $query = qq|INSERT INTO parts (partnumber, description)
                VALUES ('$uid', 'dummy')|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|SELECT p.id FROM parts p
                WHERE p.partnumber = '$uid'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{id}) = $sth->fetchrow_array;
    $sth->finish;

    $form->{orphaned} = 1;
    $form->{onhand} = $form->{stock} if $form->{item} eq 'assembly';
    if ($form->{partnumber} eq "" && $form->{inventory_accno} eq "") {
      $form->{partnumber} = $form->update_defaults($myconfig, "servicenumber");
    }
    if ($form->{partnumber} eq "" && $form->{inventory_accno} ne "") {
      $form->{partnumber} = $form->update_defaults($myconfig, "articlenumber");
    }

  }
  my $partsgroup_id = 0;

  if ($form->{partsgroup}) {
    ($partsgroup, $partsgroup_id) = split /--/, $form->{partsgroup};
  }

  $query = qq|UPDATE parts SET
	      partnumber = '$form->{partnumber}',
	      description = '$form->{description}',
	      makemodel = '$form->{makemodel}',
	      alternate = '$form->{alternate}',
	      assembly = '$form->{assembly}',
	      listprice = $form->{listprice},
	      sellprice = $form->{sellprice},
	      lastcost = $form->{lastcost},
	      weight = $form->{weight},
	      priceupdate = $form->{priceupdate},
	      unit = '$form->{unit}',
	      notes = '$form->{notes}',
	      rop = $form->{rop},
	      bin = '$form->{bin}',
	      inventory_accno_id = (SELECT c.id FROM chart c
				    WHERE c.accno = '$form->{inventory_accno}'),
	      income_accno_id = (SELECT c.id FROM chart c
				 WHERE c.accno = '$form->{income_accno}'),
	      expense_accno_id = (SELECT c.id FROM chart c
				  WHERE c.accno = '$form->{expense_accno}'),
              obsolete = '$form->{obsolete}',
	      image = '$form->{image}',
	      drawing = '$form->{drawing}',
	      shop = '$form->{shop}',
              ve = '$form->{ve}',
              gv = '$form->{gv}',
	      microfiche = '$form->{microfiche}',
	      partsgroup_id = $partsgroup_id
	      WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # delete price records
  $query = qq|DELETE FROM prices
              WHERE parts_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # insert price records only if different to sellprice
  for my $i (1 .. $form->{price_rows}) {
    if ($form->{"price_$i"} eq "0") {
      $form->{"price_$i"} = $form->{sellprice};
    }
    if (
        (   $form->{"price_$i"}
         || $form->{"klass_$i"}
         || $form->{"pricegroup_id_$i"})
        and $form->{"price_$i"} != $form->{sellprice}
      ) {
      $klass = $form->parse_amount($myconfig, $form->{"klass_$i"});
      $price = $form->parse_amount($myconfig, $form->{"price_$i"});
      $pricegroup_id =
        $form->parse_amount($myconfig, $form->{"pricegroup_id_$i"});
      $query = qq|INSERT INTO prices (parts_id, pricegroup_id, price)
                  VALUES($form->{id},$pricegroup_id,$price)|;
      $dbh->do($query) || $form->dberror($query);
    }
  }

  # insert makemodel records
  unless ($form->{item} eq 'service') {
    for my $i (1 .. $form->{makemodel_rows}) {
      if (($form->{"make_$i"}) || ($form->{"model_$i"})) {
        map { $form->{"${_}_$i"} =~ s/\'/\'\'/g } qw(make model);

        $query = qq|INSERT INTO makemodel (parts_id, make, model)
		    VALUES ($form->{id},
		    '$form->{"make_$i"}', '$form->{"model_$i"}')|;
        $dbh->do($query) || $form->dberror($query);
      }
    }
  }

  # insert taxes
  foreach $item (split / /, $form->{taxaccounts}) {
    if ($form->{"IC_tax_$item"}) {
      $query = qq|INSERT INTO partstax (parts_id, chart_id)
                  VALUES ($form->{id},
		          (SELECT c.id
			   FROM chart c
			   WHERE c.accno = '$item'))|;
      $dbh->do($query) || $form->dberror($query);
    }
  }

  # add assembly records
  if ($form->{item} eq 'assembly') {

    for my $i (1 .. $form->{assembly_rows}) {
      $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});

      if ($form->{"qty_$i"} != 0) {
        $form->{"bom_$i"} *= 1;
        $query = qq|INSERT INTO assembly (id, parts_id, qty, bom)
		    VALUES ($form->{id}, $form->{"id_$i"},
		    $form->{"qty_$i"}, '$form->{"bom_$i"}')|;
        $dbh->do($query) || $form->dberror($query);
      }
    }

    # adjust onhand for the parts
    if ($form->{onhand} != 0) {
      &adjust_inventory($dbh, $form, $form->{id}, $form->{onhand});
    }

    @a = localtime;
    $a[5] += 1900;
    $a[4]++;
    my $shippingdate = "$a[5]-$a[4]-$a[3]";

    $form->get_employee($dbh);

    # add inventory record
    $query = qq|INSERT INTO inventory (warehouse_id, parts_id, qty,
                shippingdate, employee_id) VALUES (
		0, $form->{id}, $form->{stock}, '$shippingdate',
		$form->{employee_id})|;
    $dbh->do($query) || $form->dberror($query);

  }

  #set expense_accno=inventory_accno if they are different => bilanz
  $vendor_accno =
    ($form->{expense_accno} != $form->{inventory_accno})
    ? $form->{inventory_accno}
    : $form->{expense_accno};

  # get tax rates and description
  $accno_id =
    ($form->{vc} eq "customer") ? $form->{income_accno} : $vendor_accno;
  $query = qq|SELECT c.accno, c.description, t.rate, t.taxnumber
	      FROM chart c, tax t
	      WHERE c.id=t.chart_id AND t.taxkey in (SELECT taxkey_id from chart where accno = '$accno_id')
	      ORDER BY c.accno|;
  $stw = $dbh->prepare($query);

  $stw->execute || $form->dberror($query);

  $form->{taxaccount} = "";
  while ($ptr = $stw->fetchrow_hashref(NAME_lc)) {

    #    if ($customertax{$ref->{accno}}) {
    $form->{taxaccount} .= "$ptr->{accno} ";
    if (!($form->{taxaccount2} =~ /$ptr->{accno}/)) {
      $form->{"$ptr->{accno}_rate"}        = $ptr->{rate};
      $form->{"$ptr->{accno}_description"} = $ptr->{description};
      $form->{"$ptr->{accno}_taxnumber"}   = $ptr->{taxnumber};
      $form->{taxaccount2} .= " $ptr->{accno} ";
    }

  }

  # commit
  my $rc = $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $rc;
}

sub update_assembly {
  $main::lxdebug->enter_sub();

  my ($dbh, $form, $id, $qty, $sellprice, $weight) = @_;

  my $query = qq|SELECT a.id, a.qty
                 FROM assembly a
		 WHERE a.parts_id = $id|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my ($pid, $aqty) = $sth->fetchrow_array) {
    &update_assembly($dbh, $form, $pid, $aqty * $qty, $sellprice, $weight);
  }
  $sth->finish;

  $query = qq|UPDATE parts
              SET sellprice = sellprice +
	          $qty * ($form->{sellprice} - $sellprice),
                  weight = weight +
		  $qty * ($form->{weight} - $weight)
	      WHERE id = $id|;
  $dbh->do($query) || $form->dberror($query);

  $main::lxdebug->leave_sub();
}

sub retrieve_assemblies {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $where = '1 = 1';

  if ($form->{partnumber}) {
    my $partnumber = $form->like(lc $form->{partnumber});
    $where .= " AND lower(p.partnumber) LIKE '$partnumber'";
  }

  if ($form->{description}) {
    my $description = $form->like(lc $form->{description});
    $where .= " AND lower(p.description) LIKE '$description'";
  }
  $where .= " AND NOT p.obsolete = '1'";

  # retrieve assembly items
  my $query = qq|SELECT p.id, p.partnumber, p.description,
                 p.bin, p.onhand, p.rop,
		   (SELECT sum(p2.inventory_accno_id)
		    FROM parts p2, assembly a
		    WHERE p2.id = a.parts_id
		    AND a.id = p.id) AS inventory
                 FROM parts p
 		 WHERE $where
		 AND assembly = '1'|;

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{assembly_items} }, $ref if $ref->{inventory};
  }
  $sth->finish;

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub restock_assemblies {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  for my $i (1 .. $form->{rowcount}) {

    $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});

    if ($form->{"qty_$i"} != 0) {
      &adjust_inventory($dbh, $form, $form->{"id_$i"}, $form->{"qty_$i"});
    }

  }

  my $rc = $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $rc;
}

sub adjust_inventory {
  $main::lxdebug->enter_sub();

  my ($dbh, $form, $id, $qty) = @_;

  my $query = qq|SELECT p.id, p.inventory_accno_id, p.assembly, a.qty
		 FROM parts p, assembly a
		 WHERE a.parts_id = p.id
		 AND a.id = $id|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {

    my $allocate = $qty * $ref->{qty};

    # is it a service item, then loop
    $ref->{inventory_accno_id} *= 1;
    next if (($ref->{inventory_accno_id} == 0) && !$ref->{assembly});

    # adjust parts onhand
    $form->update_balance($dbh, "parts", "onhand",
                          qq|id = $ref->{id}|,
                          $allocate * -1);
  }

  $sth->finish;

  # update assembly
  my $rc = $form->update_balance($dbh, "parts", "onhand", qq|id = $id|, $qty);

  $main::lxdebug->leave_sub();

  return $rc;
}

sub delete {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database, turn off AutoCommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query = qq|DELETE FROM parts
 	         WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $query = qq|DELETE FROM partstax
	      WHERE parts_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # check if it is a part, assembly or service
  if ($form->{item} ne 'service') {
    $query = qq|DELETE FROM makemodel
		WHERE parts_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
  }

  if ($form->{item} eq 'assembly') {

    # delete inventory
    $query = qq|DELETE FROM inventory
                WHERE parts_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|DELETE FROM assembly
		WHERE id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
  }

  if ($form->{item} eq 'alternate') {
    $query = qq|DELETE FROM alternate
		WHERE id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
  }

  # commit
  my $rc = $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $rc;
}

sub assembly_item {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $i = $form->{assembly_rows};
  my $var;
  my $where = "1 = 1";

  if ($form->{"partnumber_$i"}) {
    $var = $form->like(lc $form->{"partnumber_$i"});
    $where .= " AND lower(p.partnumber) LIKE '$var'";
  }
  if ($form->{"description_$i"}) {
    $var = $form->like(lc $form->{"description_$i"});
    $where .= " AND lower(p.description) LIKE '$var'";
  }
  if ($form->{"partsgroup_$i"}) {
    $var = $form->like(lc $form->{"partsgroup_$i"});
    $where .= " AND lower(pg.partsgroup) LIKE '$var'";
  }

  if ($form->{id}) {
    $where .= " AND NOT p.id = $form->{id}";
  }

  if ($partnumber) {
    $where .= " ORDER BY p.partnumber";
  } else {
    $where .= " ORDER BY p.description";
  }

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT p.id, p.partnumber, p.description, p.sellprice,
                 p.weight, p.onhand, p.unit,
		 pg.partsgroup
		 FROM parts p
		 LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		 WHERE $where|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{item_list} }, $ref;
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub all_parts {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $where = '1 = 1';
  my $var;

  my $group;
  my $limit;

  foreach my $item (qw(partnumber drawing microfiche make model)) {
    if ($form->{$item}) {
      $var = $form->like(lc $form->{$item});

      # make will build later Bugfix 145
      if ($item ne 'make') {
        $where .= " AND lower(p.$item) LIKE '$var'";
      }
    }
  }

  # special case for description
  if ($form->{description}) {
    unless (   $form->{bought}
            || $form->{sold}
            || $form->{onorder}
            || $form->{ordered}
            || $form->{rfq}
            || $form->{quoted}) {
      $var = $form->like(lc $form->{description});
      $where .= " AND lower(p.description) LIKE '$var'";
    }
  }

  # special case for serialnumber
  if ($form->{l_serialnumber}) {
    if ($form->{serialnumber}) {
      $var = $form->like(lc $form->{serialnumber});
      $where .= " AND lower(serialnumber) LIKE '$var'";
    }
  }

  if ($form->{searchitems} eq 'part') {
    $where .= " AND p.inventory_accno_id > 0";
  }
  if ($form->{searchitems} eq 'assembly') {
    $form->{bought} = "";
    $where .= " AND p.assembly = '1'";
  }
  if ($form->{searchitems} eq 'service') {
    $where .= " AND p.inventory_accno_id IS NULL AND NOT p.assembly = '1'";

    # irrelevant for services
    $form->{make} = $form->{model} = "";
  }

  # items which were never bought, sold or on an order
  if ($form->{itemstatus} eq 'orphaned') {
    $form->{onhand}  = $form->{short}   = 0;
    $form->{bought}  = $form->{sold}    = 0;
    $form->{onorder} = $form->{ordered} = 0;
    $form->{rfq}     = $form->{quoted}  = 0;

    $form->{transdatefrom} = $form->{transdateto} = "";

    $where .= " AND p.onhand = 0
                AND p.id NOT IN (SELECT p.id FROM parts p, invoice i
				 WHERE p.id = i.parts_id)
		AND p.id NOT IN (SELECT p.id FROM parts p, assembly a
				 WHERE p.id = a.parts_id)
                AND p.id NOT IN (SELECT p.id FROM parts p, orderitems o
				 WHERE p.id = o.parts_id)";
  }

  if ($form->{itemstatus} eq 'active') {
    $where .= " AND p.obsolete = '0'";
  }
  if ($form->{itemstatus} eq 'obsolete') {
    $where .= " AND p.obsolete = '1'";
    $form->{onhand} = $form->{short} = 0;
  }
  if ($form->{itemstatus} eq 'onhand') {
    $where .= " AND p.onhand > 0";
  }
  if ($form->{itemstatus} eq 'short') {
    $where .= " AND p.onhand < p.rop";
  }
  if ($form->{make}) {
    $var = $form->like(lc $form->{make});
    $where .= " AND p.id IN (SELECT DISTINCT ON (m.parts_id) m.parts_id
                           FROM makemodel m WHERE lower(m.make) LIKE '$var')";
  }
  if ($form->{model}) {
    $var = $form->like(lc $form->{model});
    $where .= " AND p.id IN (SELECT DISTINCT ON (m.parts_id) m.parts_id
                           FROM makemodel m WHERE lower(m.model) LIKE '$var')";
  }
  if ($form->{partsgroup}) {
    $var = $form->like(lc $form->{partsgroup});
    $where .= " AND lower(pg.partsgroup) LIKE '$var'";
  }
  if ($form->{l_soldtotal}) {
    $where .= " AND p.id=i.parts_id AND  i.qty >= 0";
    $group =
      " GROUP BY  p.id,p.partnumber,p.description,p.onhand,p.unit,p.bin, p.sellprice,p.listprice,p.lastcost,p.priceupdate,pg.partsgroup";
  }
  if ($form->{top100}) {
    $limit = " LIMIT 100";
  }

  # tables revers?
  if ($form->{revers} == 1) {
    $form->{desc} = " DESC";
  } else {
    $form->{desc} = "";
  }

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $sortorder = $form->{sort};
  $sortorder .= $form->{desc};
  $sortorder = $form->{sort} if $form->{sort};

  my $query = "";

  if ($form->{l_soldtotal}) {
    $form->{soldtotal} = 'soldtotal';
    $query =
      qq|SELECT p.id,p.partnumber,p.description,p.onhand,p.unit,p.bin,p.sellprice,p.listprice,
		p.lastcost,p.priceupdate,pg.partsgroup,sum(i.qty) as soldtotal FROM parts
		p LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id), invoice i
		WHERE $where
		$group
		ORDER BY $sortorder
		$limit|;
  } else {
    $query = qq|SELECT p.id, p.partnumber, p.description, p.onhand, p.unit,
                 p.bin, p.sellprice, p.listprice, p.lastcost, p.rop, p.weight,
		 p.priceupdate, p.image, p.drawing, p.microfiche,
		 pg.partsgroup
                 FROM parts p
		 LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
  	         WHERE $where
		 $group
	         ORDER BY $sortorder|;
  }

  # rebuild query for bought and sold items
  if (   $form->{bought}
      || $form->{sold}
      || $form->{onorder}
      || $form->{ordered}
      || $form->{rfq}
      || $form->{quoted}) {

    my @a = qw(partnumber description bin priceupdate name);

    push @a, qw(invnumber serialnumber) if ($form->{bought} || $form->{sold});
    push @a, "ordnumber" if ($form->{onorder} || $form->{ordered});
    push @a, "quonumber" if ($form->{rfq}     || $form->{quoted});

    my $union = "";
    $query = "";

    if ($form->{bought} || $form->{sold}) {

      my $invwhere = "$where";
      $invwhere .= " AND i.assemblyitem = '0'";
      $invwhere .= " AND a.transdate >= '$form->{transdatefrom}'"
        if $form->{transdatefrom};
      $invwhere .= " AND a.transdate <= '$form->{transdateto}'"
        if $form->{transdateto};

      if ($form->{description}) {
        $var = $form->like(lc $form->{description});
        $invwhere .= " AND lower(i.description) LIKE '$var'";
      }

      my $flds = qq|p.id, p.partnumber, i.description, i.serialnumber,
                    i.qty AS onhand, i.unit, p.bin, i.sellprice,
		    p.listprice, p.lastcost, p.rop, p.weight,
		    p.priceupdate, p.image, p.drawing, p.microfiche,
		    pg.partsgroup,
		    a.invnumber, a.ordnumber, a.quonumber, i.trans_id,
		    ct.name|;

      if ($form->{bought}) {
        $query = qq|
	            SELECT $flds, 'ir' AS module, '' AS type,
		    1 AS exchangerate
		    FROM invoice i
		    JOIN parts p ON (p.id = i.parts_id)
		    JOIN ap a ON (a.id = i.trans_id)
		    JOIN vendor ct ON (a.vendor_id = ct.id)
		    LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		    WHERE $invwhere|;
        $union = "
	          UNION";
      }

      if ($form->{sold}) {
        $query .= qq|$union
                     SELECT $flds, 'is' AS module, '' AS type,
		     1 As exchangerate
		     FROM invoice i
		     JOIN parts p ON (p.id = i.parts_id)
		     JOIN ar a ON (a.id = i.trans_id)
		     JOIN customer ct ON (a.customer_id = ct.id)
		     LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		     WHERE $invwhere|;
        $union = "
	          UNION";
      }
    }

    if ($form->{onorder} || $form->{ordered}) {
      my $ordwhere = "$where
		     AND o.quotation = '0'";
      $ordwhere .= " AND o.transdate >= '$form->{transdatefrom}'"
        if $form->{transdatefrom};
      $ordwhere .= " AND o.transdate <= '$form->{transdateto}'"
        if $form->{transdateto};

      if ($form->{description}) {
        $var = $form->like(lc $form->{description});
        $ordwhere .= " AND lower(oi.description) LIKE '$var'";
      }

      $flds =
        qq|p.id, p.partnumber, oi.description, oi.serialnumber AS serialnumber,
                 oi.qty AS onhand, oi.unit, p.bin, oi.sellprice,
	         p.listprice, p.lastcost, p.rop, p.weight,
		 p.priceupdate, p.image, p.drawing, p.microfiche,
		 pg.partsgroup,
		 '' AS invnumber, o.ordnumber, o.quonumber, oi.trans_id,
		 ct.name|;

      if ($form->{ordered}) {
        $query .= qq|$union
                     SELECT $flds, 'oe' AS module, 'sales_order' AS type,
		    (SELECT buy FROM exchangerate ex
		     WHERE ex.curr = o.curr
		     AND ex.transdate = o.transdate) AS exchangerate
		     FROM orderitems oi
		     JOIN parts p ON (oi.parts_id = p.id)
		     JOIN oe o ON (oi.trans_id = o.id)
		     JOIN customer ct ON (o.customer_id = ct.id)
		     LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		     WHERE $ordwhere
		     AND o.customer_id > 0|;
        $union = "
	          UNION";
      }

      if ($form->{onorder}) {
        $flds =
          qq|p.id, p.partnumber, oi.description, oi.serialnumber AS serialnumber,
                   oi.qty * -1 AS onhand, oi.unit, p.bin, oi.sellprice,
		   p.listprice, p.lastcost, p.rop, p.weight,
		   p.priceupdate, p.image, p.drawing, p.microfiche,
		   pg.partsgroup,
		   '' AS invnumber, o.ordnumber, o.quonumber, oi.trans_id,
		   ct.name|;

        $query .= qq|$union
	            SELECT $flds, 'oe' AS module, 'purchase_order' AS type,
		    (SELECT sell FROM exchangerate ex
		     WHERE ex.curr = o.curr
		     AND ex.transdate = o.transdate) AS exchangerate
		    FROM orderitems oi
		    JOIN parts p ON (oi.parts_id = p.id)
		    JOIN oe o ON (oi.trans_id = o.id)
		    JOIN vendor ct ON (o.vendor_id = ct.id)
		    LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		    WHERE $ordwhere
		    AND o.vendor_id > 0|;
      }

    }

    if ($form->{rfq} || $form->{quoted}) {
      my $quowhere = "$where
		     AND o.quotation = '1'";
      $quowhere .= " AND o.transdate >= '$form->{transdatefrom}'"
        if $form->{transdatefrom};
      $quowhere .= " AND o.transdate <= '$form->{transdateto}'"
        if $form->{transdateto};

      if ($form->{description}) {
        $var = $form->like(lc $form->{description});
        $quowhere .= " AND lower(oi.description) LIKE '$var'";
      }

      $flds =
        qq|p.id, p.partnumber, oi.description, oi.serialnumber AS serialnumber,
                 oi.qty AS onhand, oi.unit, p.bin, oi.sellprice,
	         p.listprice, p.lastcost, p.rop, p.weight,
		 p.priceupdate, p.image, p.drawing, p.microfiche,
		 pg.partsgroup,
		 '' AS invnumber, o.ordnumber, o.quonumber, oi.trans_id,
		 ct.name|;

      if ($form->{quoted}) {
        $query .= qq|$union
                     SELECT $flds, 'oe' AS module, 'sales_quotation' AS type,
		    (SELECT buy FROM exchangerate ex
		     WHERE ex.curr = o.curr
		     AND ex.transdate = o.transdate) AS exchangerate
		     FROM orderitems oi
		     JOIN parts p ON (oi.parts_id = p.id)
		     JOIN oe o ON (oi.trans_id = o.id)
		     JOIN customer ct ON (o.customer_id = ct.id)
		     LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		     WHERE $quowhere
		     AND o.customer_id > 0|;
        $union = "
	          UNION";
      }

      if ($form->{rfq}) {
        $flds =
          qq|p.id, p.partnumber, oi.description, oi.serialnumber AS serialnumber,
                   oi.qty * -1 AS onhand, oi.unit, p.bin, oi.sellprice,
		   p.listprice, p.lastcost, p.rop, p.weight,
		   p.priceupdate, p.image, p.drawing, p.microfiche,
		   pg.partsgroup,
		   '' AS invnumber, o.ordnumber, o.quonumber, oi.trans_id,
		   ct.name|;

        $query .= qq|$union
	            SELECT $flds, 'oe' AS module, 'request_quotation' AS type,
		    (SELECT sell FROM exchangerate ex
		     WHERE ex.curr = o.curr
		     AND ex.transdate = o.transdate) AS exchangerate
		    FROM orderitems oi
		    JOIN parts p ON (oi.parts_id = p.id)
		    JOIN oe o ON (oi.trans_id = o.id)
		    JOIN vendor ct ON (o.vendor_id = ct.id)
		    LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		    WHERE $quowhere
		    AND o.vendor_id > 0|;
      }

    }
    $query .= qq|
		 ORDER BY $sortorder|;

  }
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{parts} }, $ref;
  }

  $sth->finish;

  # include individual items for assemblies
  if ($form->{searchitems} eq 'assembly' && $form->{bom}) {
    foreach $item (@{ $form->{parts} }) {
      push @assemblies, $item;
      $query = qq|SELECT p.id, p.partnumber, p.description, a.qty AS onhand,
                  p.unit, p.bin,
                  p.sellprice, p.listprice, p.lastcost,
		  p.rop, p.weight, p.priceupdate,
		  p.image, p.drawing, p.microfiche
		  FROM parts p, assembly a
		  WHERE p.id = a.parts_id
		  AND a.id = $item->{id}|;

      $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);

      while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
        $ref->{assemblyitem} = 1;
        push @assemblies, $ref;
      }
      $sth->finish;

      push @assemblies, { id => $item->{id} };

    }

    # copy assemblies to $form->{parts}
    @{ $form->{parts} } = @assemblies;
  }

  $dbh->disconnect;
  $main::lxdebug->leave_sub();
}

sub create_links {
  $main::lxdebug->enter_sub();

  my ($self, $module, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  if ($form->{id}) {
    $query = qq|SELECT c.accno, c.description, c.link, c.id,
			p.inventory_accno_id, p.income_accno_id, p.expense_accno_id
			FROM chart c, parts p
			WHERE c.link LIKE '%$module%'
			AND p.id = $form->{id}
			ORDER BY c.accno|;
  } else {
    $query = qq|SELECT c.accno, c.description, c.link, c.id,
		d.inventory_accno_id, d.income_accno_id, d.expense_accno_id
		FROM chart c, defaults d
		WHERE c.link LIKE '%$module%'
		ORDER BY c.accno|;
  }

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    foreach my $key (split /:/, $ref->{link}) {
      if ($key =~ /$module/) {
        if (   ($ref->{id} eq $ref->{inventory_accno_id})
            || ($ref->{id} eq $ref->{income_accno_id})
            || ($ref->{id} eq $ref->{expense_accno_id})) {
          push @{ $form->{"${module}_links"}{$key} },
            { accno       => $ref->{accno},
              description => $ref->{description},
              selected    => "selected" };
            } else {
          push @{ $form->{"${module}_links"}{$key} },
            { accno       => $ref->{accno},
              description => $ref->{description},
              selected    => "" };
        }
      }
    }
  }
  $sth->finish;

  if ($form->{id}) {
    $query = qq|SELECT weightunit
                FROM defaults|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{weightunit}) = $sth->fetchrow_array;
    $sth->finish;

  } else {
    $query = qq|SELECT weightunit, current_date
                FROM defaults|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{weightunit}, $form->{priceupdate}) = $sth->fetchrow_array;
    $sth->finish;
  }

  $dbh->disconnect;
  $main::lxdebug->leave_sub();
}

# get partnumber, description, unit, sellprice and soldtotal with choice through $sortorder for Top100
sub get_parts {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $sortorder) = @_;
  my $dbh   = $form->dbconnect($myconfig);
  my $order = " p.partnumber";
  my $where = "1 = 1";

  if ($sortorder eq "all") {
    $where .= " AND p.partnumber LIKE '%$form->{partnumber}%'";
    $where .= " AND p.description LIKE '%$form->{description}%'";
  } else {
    if ($sortorder eq "partnumber") {
      $where .= " AND p.partnumber LIKE '%$form->{partnumber}%'";
      $order = qq|p.$sortorder|;
    }
    if ($sortorder eq "description") {
      $where .= " AND p.description LIKE '%$form->{description}%'";
    }
  }

  my $query =
    qq|SELECT p.id, p.partnumber, p.description, p.unit, p.sellprice FROM parts p WHERE $where ORDER BY $order|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);
  my $j = 0;
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    if (($ref->{partnumber} eq "*") && ($ref->{description} eq "")) {
    } else {
      $j++;
      $form->{"id_$j"}          = $ref->{id};
      $form->{"partnumber_$j"}  = $ref->{partnumber};
      $form->{"description_$j"} = $ref->{description};
      $form->{"unit_$j"}        = $ref->{unit};
      $form->{"sellprice_$j"}   = $ref->{sellprice};
      $form->{"soldtotal_$j"}   = get_soldtotal($dbh, $ref->{id});
    }    #fi
  }    #while
  $form->{rows} = $j;
  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $self;
}    #end get_parts()

# gets sum of sold part with part_id
sub get_soldtotal {
  $main::lxdebug->enter_sub();

  my ($dbh, $id) = @_;

  my $query =
    qq|SELECT sum(i.qty) as totalsold FROM invoice i WHERE i.parts_id = $id|;

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $sum = 0;
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {

    $sum = $ref->{totalsold};
  }    #while
  $sth->finish;

  if ($sum eq undef) {
    $sum = 0;
  }    #fi

  $main::lxdebug->leave_sub();

  return $sum;
}    #end get_soldtotal

sub retrieve_item {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;
  my $i     = $form->{rowcount};
  my $where = "NOT p.obsolete = '1'";

  if ($form->{"partnumber_$i"}) {
    my $partnumber = $form->like(lc $form->{"partnumber_$i"});
    $where .= " AND lower(p.partnumber) LIKE '$partnumber'";
  }
  if ($form->{"description_$i"}) {
    my $description = $form->like(lc $form->{"description_$i"});
    $where .= " AND lower(p.description) LIKE '$description'";
  }

  if ($form->{"partsgroup_$i"}) {
    my $partsgroup = $form->like(lc $form->{"partsgroup_$i"});
    $where .= " AND lower(pg.partsgroup) LIKE '$partsgroup'";
  }

  if ($form->{"description_$i"}) {
    $where .= " ORDER BY description";
  } else {
    $where .= " ORDER BY partnumber";
  }

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT p.id, p.partnumber, p.description, p.sellprice,
                        p.listprice,
                        c1.accno AS inventory_accno,
			c2.accno AS income_accno,
			c3.accno AS expense_accno,
		 p.unit, p.assembly, p.bin, p.onhand, p.notes AS partnotes,
		 pg.partsgroup
                 FROM parts p
		 LEFT JOIN chart c1 ON (p.inventory_accno_id = c1.id)
		 LEFT JOIN chart c2 ON (p.income_accno_id = c2.id)
		 LEFT JOIN chart c3 ON (p.expense_accno_id = c3.id)
		 LEFT JOIN partsgroup pg ON (pg.id = p.partsgroup_id)
	         WHERE $where|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  #while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {

  # get tax rates and description
  #$accno_id = ($form->{vc} eq "customer") ? $ref->{income_accno} : $ref->{inventory_accno};
  #$query = qq|SELECT c.accno, c.description, t.rate, t.taxnumber
  #	      FROM chart c, tax t
  #	      WHERE c.id=t.chart_id AND t.taxkey in (SELECT taxkey_id from chart where accno = '$accno_id')
  #	      ORDER BY accno|;
  # $stw = $dbh->prepare($query);
  #$stw->execute || $form->dberror($query);

  #$ref->{taxaccounts} = "";
  #while ($ptr = $stw->fetchrow_hashref(NAME_lc)) {

  #   $form->{"$ptr->{accno}_rate"} = $ptr->{rate};
  #  $form->{"$ptr->{accno}_description"} = $ptr->{description};
  #   $form->{"$ptr->{accno}_taxnumber"} = $ptr->{taxnumber};
  #   $form->{taxaccounts} .= "$ptr->{accno} ";
  #   $ref->{taxaccounts} .= "$ptr->{accno} ";

  #}

  #$stw->finish;
  #chop $ref->{taxaccounts};

  push @{ $form->{item_list} }, $ref;

  #}
  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

1;
