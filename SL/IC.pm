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
use SL::DBUtils;

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
                 WHERE p.id = ? |;
  my @vars = ($form->{id});
  my $sth = $dbh->prepare($query);
  $sth->execute(@vars) || $form->dberror("$query (" . join(', ', @vars) . ")");
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
		WHERE a.id = ?
		ORDER BY ?|;
    @vars = ($form->{id}, $oid{$myconfig->{dbdriver}});
    $sth = $dbh->prepare($query);
    $sth->execute(@vars) || $form->dberror("$query (" . join(', ', @vars) . ")");
    
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
              WHERE parts_id = ? 
              ORDER by pricegroup|;

  @vars = ($form->{id});
  $sth = $dbh->prepare($query);
  $sth->execute(@vars) || $form->dberror("$query (" . join(', ', @vars) . ")");

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
                  WHERE m.parts_id = ?|;
      @vars = ($form->{id});
      $sth = $dbh->prepare($query);
      $sth->execute(@vars) || $form->dberror("$query (" . join(', ', @vars) . ")");

      my $i = 1;
      while (($form->{"make_$i"}, $form->{"model_$i"}) = $sth->fetchrow_array)
      {
        $i++;
      }
      $sth->finish;
      $form->{makemodel_rows} = $i - 1;

    }
  }

  # get translations
  $form->{language_values} = "";
  $query = qq|SELECT language_id, translation FROM translation WHERE parts_id = ?|;
  @vars = ($form->{id});
  $trq = $dbh->prepare($query);
  $trq->execute(@vars) || $form->dberror("$query (" . join(', ', @vars) . ")");
  while ($tr = $trq->fetchrow_hashref(NAME_lc)) {
    $form->{language_values} .= "---+++---".$tr->{language_id}."--++--".$tr->{translation};
  }
  $trq->finish;

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

  $form->{"unit_changeable"} = 1;
  foreach my $table (qw(invoice assembly orderitems inventory license)) {
    $query = "SELECT COUNT(*) FROM $table WHERE parts_id = ?";
    my ($count) = $dbh->selectrow_array($query, undef, $form->{"id"});
    $form->dberror($query . " (" . $form->{"id"} . ")") if ($dbh->err);

    if ($count) {
      $form->{"unit_changeable"} = 0;
      last;
    }
  }

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

sub retrieve_buchungsgruppen {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my ($query, $sth);

  my $dbh = $form->dbconnect($myconfig);

  # get buchungsgruppen
  $query = qq|SELECT id, description
              FROM buchungsgruppen
              ORDER BY sortkey|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $form->{BUCHUNGSGRUPPEN} = [];
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push(@{ $form->{BUCHUNGSGRUPPEN} }, $ref);
  }
  $sth->finish;

  $main::lxdebug->leave_sub();
}

sub save {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

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
  $form->{buchungsgruppen_id}       *= 1;
  $form->{not_discountable}       *= 1;
  $form->{payment_id}       *= 1;

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

    # delete translations
    $query = qq|DELETE FROM translation
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
    if ($form->{partnumber} eq "" && $form->{"item"} eq "service") {
      $form->{partnumber} = $form->update_defaults($myconfig, "servicenumber");
    }
    if ($form->{partnumber} eq "" && $form->{"item"} ne "service") {
      $form->{partnumber} = $form->update_defaults($myconfig, "articlenumber");
    }

  }
  my $partsgroup_id = 0;

  if ($form->{partsgroup}) {
    ($partsgroup, $partsgroup_id) = split /--/, $form->{partsgroup};
  }

  my ($subq_inventory, $subq_expense, $subq_income);
  if ($form->{"item"} eq "part") {
    $subq_inventory =
      qq|(SELECT bg.inventory_accno_id | .
      qq| FROM buchungsgruppen bg | .
      qq| WHERE bg.id = | . $dbh->quote($form->{"buchungsgruppen_id"}) . qq|)|;
  } else {
    $subq_inventory = "NULL";
  }

  if ($form->{"item"} ne "assembly") {
    $subq_expense =
      qq|(SELECT bg.expense_accno_id_0 | .
      qq| FROM buchungsgruppen bg | .
      qq| WHERE bg.id = | . $dbh->quote($form->{"buchungsgruppen_id"}) . qq|)|;
  } else {
    $subq_expense = "NULL";
  }

  $subq_income =
    qq|(SELECT bg.income_accno_id_0 | .
    qq| FROM buchungsgruppen bg | .
    qq| WHERE bg.id = | . $dbh->quote($form->{"buchungsgruppen_id"}) . qq|)|;

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
	      formel = '$form->{formel}',
	      rop = $form->{rop},
	      bin = '$form->{bin}',
	      buchungsgruppen_id = '$form->{buchungsgruppen_id}',
	      payment_id = '$form->{payment_id}',
	      inventory_accno_id = $subq_inventory,
	      income_accno_id = $subq_income,
	      expense_accno_id = $subq_expense,
              obsolete = '$form->{obsolete}',
	      image = '$form->{image}',
	      drawing = '$form->{drawing}',
	      shop = '$form->{shop}',
              ve = '$form->{ve}',
              gv = '$form->{gv}',
              ean = '$form->{ean}',
              not_discountable = '$form->{not_discountable}',
	      microfiche = '$form->{microfiche}',
	      partsgroup_id = $partsgroup_id
	      WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # delete translation records
  $query = qq|DELETE FROM translation
              WHERE parts_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  if ($form->{language_values} ne "") {
    split /---\+\+\+---/,$form->{language_values};
    foreach $item (@_) {
      my ($language_id, $translation, $longdescription) = split /--\+\+--/, $item;
      if ($translation ne "") {
        $query = qq|INSERT into translation (parts_id, language_id, translation, longdescription) VALUES
                    ($form->{id}, $language_id, | . $dbh->quote($translation) . qq|, | . $dbh->quote($longdescription) . qq| )|;
        $dbh->do($query) || $form->dberror($query);
      }
    }
  }
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
  my $rc = $form->update_balance($dbh, "parts", "onhand", qq|id = ?|, $qty, $id);

  $main::lxdebug->leave_sub();

  return $rc;
}

sub delete {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database, turn off AutoCommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  # first delete prices of pricegroup 
  my $query = qq|DELETE FROM prices
           WHERE parts_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

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

  foreach my $item (qw(partnumber drawing microfiche)) {
    if ($form->{$item}) {
      $var = $form->like(lc $form->{$item});
      $where .= " AND lower(p.$item) LIKE '$var'";
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

  if ($form->{ean}) {
    $var = $form->like(lc $form->{ean});
    $where .= " AND lower(ean) LIKE '$var'";
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
		    ct.name, i.deliverydate|;

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
		 ct.name, NULL AS deliverydate|;

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
		   ct.name, NULL AS deliverydate|;

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
		 ct.name, NULL AS deliverydate|;

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
		   ct.name, NULL AS deliverydate|;

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

sub update_prices {
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


  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  if ($form->{"sellprice"} ne "") {
    my $update = "";
    my $faktor = $form->parse_amount($myconfig,$form->{"sellprice"});
    if ($form->{"sellprice_type"} eq "percent") {
      my $faktor = $form->parse_amount($myconfig,$form->{"sellprice"})/100 +1;
      $update = "sellprice* $faktor";
    } else {
      $update = "sellprice+$faktor";
    }
  
    $query = qq|UPDATE parts set sellprice=$update WHERE id IN (SELECT p.id
                  FROM parts p
                  LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
                  WHERE $where)|;
    $dbh->do($query);
  }

  if ($form->{"listprice"} ne "") {
    my $update = "";
    my $faktor = $form->parse_amount($myconfig,$form->{"listprice"});
    if ($form->{"listprice_type"} eq "percent") {
      my $faktor = $form->parse_amount($myconfig,$form->{"sellprice"})/100 +1;
      $update = "listprice* $faktor";
    } else {
      $update = "listprice+$faktor";
    }
  
    $query = qq|UPDATE parts set listprice=$update WHERE id IN (SELECT p.id
                  FROM parts p
                  LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
                  WHERE $where)|;
  
    $dbh->do($query);
  }




  for my $i (1 .. $form->{price_rows}) {

    my $query = "";
    
  
    if ($form->{"price_$i"} ne "") {
      my $update = "";
      my $faktor = $form->parse_amount($myconfig,$form->{"price_$i"});
      if ($form->{"pricegroup_type_$i"} eq "percent") {
        my $faktor = $form->parse_amount($myconfig,$form->{"sellprice"})/100 +1;
        $update = "price* $faktor";
      } else {
        $update = "price+$faktor";
      }
    
      $query = qq|UPDATE prices set price=$update WHERE parts_id IN (SELECT p.id
                    FROM parts p
                    LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
                    WHERE $where) AND pricegroup_id=$form->{"pricegroup_id_$i"}|;
    
      $dbh->do($query);
    }
  }



  my $rc= $dbh->commit;
  $dbh->disconnect;
  $main::lxdebug->leave_sub();

  return $rc;
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
          $form->{"${key}_default"} = "$ref->{accno}--$ref->{description}";
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

  # get buchungsgruppen
  $query = qq|SELECT id, description
              FROM buchungsgruppen|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $form->{BUCHUNGSGRUPPEN} = [];
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{BUCHUNGSGRUPPEN} }, $ref;
  }
  $sth->finish;

  # get payment terms
  $query = qq|SELECT id, description
              FROM payment_terms
              ORDER BY sortkey|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $self->{payment_terms} }, $ref;
  }
  $sth->finish;

  if (!$form->{id}) {
    $query = qq|SELECT current_date FROM defaults|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{priceupdate}) = $sth->fetchrow_array;
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

sub retrieve_languages {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  if ($form->{id}) {
    $where .= "tr.parts_id=$form->{id}";
  }


  if ($form->{language_values} ne "") {
  $query = qq|SELECT l.id, l.description, tr.translation, tr.longdescription
                 FROM language l LEFT OUTER JOIN translation tr ON (tr.language_id=l.id AND $where)|;
  } else {
  $query = qq|SELECT l.id, l.description
                 FROM language l|;
  }
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push(@{$languages}, $ref);
  }
  $sth->finish;

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
  return $languages;

}

sub follow_account_chain {
  $main::lxdebug->enter_sub(2);

  my ($self, $form, $dbh, $transdate, $accno_id, $accno) = @_;

  my @visited_accno_ids = ($accno_id);

  my ($query, $sth);

  $query =
    "SELECT c.new_chart_id, date($transdate) >= c.valid_from AS is_valid, " .
    "  cnew.accno " .
    "FROM chart c " .
    "LEFT JOIN chart cnew ON c.new_chart_id = cnew.id " .
    "WHERE (c.id = ?) AND NOT c.new_chart_id ISNULL AND (c.new_chart_id > 0)";
  $sth = $dbh->prepare($query);

  while (1) {
    $sth->execute($accno_id) || $form->dberror($query . " ($accno_id)");
    $ref = $sth->fetchrow_hashref();
    last unless ($ref && $ref->{"is_valid"} &&
                 !grep({ $_ == $ref->{"new_chart_id"} } @visited_accno_ids));
    $accno_id = $ref->{"new_chart_id"};
    $accno = $ref->{"accno"};
    push(@visited_accno_ids, $accno_id);
  }

  $main::lxdebug->leave_sub(2);

  return ($accno_id, $accno);
}

sub retrieve_accounts {
  $main::lxdebug->enter_sub(2);

  my ($self, $myconfig, $form, $parts_id, $index, $copy_accnos) = @_;

  my ($query, $sth, $dbh);

  $form->{"taxzone_id"} *= 1;

  $dbh = $form->dbconnect($myconfig);

  my $transdate = "";
  if ($form->{type} eq "invoice") {
    if (($form->{vc} eq "vendor") || !$form->{deliverydate}) {
      $transdate = $form->{invdate};
    } else {
      $transdate = $form->{deliverydate};
    }
  } elsif ($form->{type} eq "credit_note") {
    $transdate = $form->{invdate};
  } else {
    $transdate = $form->{transdate};
  }

  if ($transdate eq "") {
    $transdate = "current_date";
  } else {
    $transdate = $dbh->quote($transdate);
  }

  $query =
    "SELECT " .
    "  p.inventory_accno_id AS is_part, " .
    "  bg.inventory_accno_id, " .
    "  bg.income_accno_id_$form->{taxzone_id} AS income_accno_id, " .
    "  bg.expense_accno_id_$form->{taxzone_id} AS expense_accno_id, " .
    "  c1.accno AS inventory_accno, " .
    "  c2.accno AS income_accno, " .
    "  c3.accno AS expense_accno " .
    "FROM parts p " .
    "LEFT JOIN buchungsgruppen bg ON p.buchungsgruppen_id = bg.id " .
    "LEFT JOIN chart c1 ON bg.inventory_accno_id = c1.id " .
    "LEFT JOIN chart c2 ON bg.income_accno_id_$form->{taxzone_id} = c2.id " .
    "LEFT JOIN chart c3 ON bg.expense_accno_id_$form->{taxzone_id} = c3.id " .
    "WHERE p.id = ?";
  $sth = $dbh->prepare($query);
  $sth->execute($parts_id) || $form->dberror($query . " ($parts_id)");
  my $ref = $sth->fetchrow_hashref();
  $sth->finish();

#   $main::lxdebug->message(0, "q $query");

  if (!$ref) {
    $dbh->disconnect();
    return $main::lxdebug->leave_sub(2);
  }

  $ref->{"inventory_accno_id"} = undef unless ($ref->{"is_part"});

  my %accounts;
  foreach my $type (qw(inventory income expense)) {
    next unless ($ref->{"${type}_accno_id"});
    ($accounts{"${type}_accno_id"}, $accounts{"${type}_accno"}) =
      $self->follow_account_chain($form, $dbh, $transdate,
                                  $ref->{"${type}_accno_id"},
                                  $ref->{"${type}_accno"});
  }

  map({ $form->{"${_}_accno_$index"} = $accounts{"${_}_accno"} }
      qw(inventory income expense));

  my $inc_exp = $form->{"vc"} eq "customer" ? "income" : "expense";
  my $accno_id = $accounts{"${inc_exp}_accno_id"};

  $query =
    "SELECT c.accno, t.taxdescription AS description, t.rate, t.taxnumber " .
    "FROM tax t " .
    "LEFT JOIN chart c ON c.id = t.chart_id " .
    "WHERE t.id IN " .
    "  (SELECT tk.tax_id " .
    "   FROM taxkeys tk " .
    "   WHERE tk.chart_id = ? AND startdate <= " . quote_db_date($transdate) .
    "   ORDER BY startdate DESC LIMIT 1) ";
  @vars = ($accno_id);
  $sth = $dbh->prepare($query);
  $sth->execute(@vars) || $form->dberror("$query (" . join(', ', @vars) . ")");
  $ref = $sth->fetchrow_hashref();
  $sth->finish();
  $dbh->disconnect();

  unless ($ref) {
    $main::lxdebug->leave_sub(2);
    return;
  }

  $form->{"taxaccounts_$index"} = $ref->{"accno"};
  if ($form->{"taxaccounts"} !~ /$ref->{accno}/) {
    $form->{"taxaccounts"} .= "$ref->{accno} ";
  }
  map({ $form->{"$ref->{accno}_${_}"} = $ref->{$_}; }
      qw(rate description taxnumber));

#   $main::lxdebug->message(0, "formvars: rate " . $form->{"$ref->{accno}_rate"} .
#                           " description " . $form->{"$ref->{accno}_description"} .
#                           " taxnumber " . $form->{"$ref->{accno}_taxnumber"} .
#                           " || taxaccounts_$index " . $form->{"taxaccounts_$index"} .
#                           " || taxaccounts " . $form->{"taxaccounts"});

  $main::lxdebug->leave_sub(2);
}

1;
