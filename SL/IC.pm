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
use YAML;

use SL::DBUtils;

sub get_part {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to db
  my $dbh = $form->dbconnect($myconfig);

  my $sth;

  my $query =
    qq|SELECT p.*,
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
  my $ref = selectfirst_hashref_query($form, $dbh, $query, conv_i($form->{id}));

  # copy to $form variables
  map { $form->{$_} = $ref->{$_} } (keys %{$ref});

  $form->{onhand} *= 1;

  my %oid = ('Pg'     => 'a.oid',
             'Oracle' => 'a.rowid');

  # part or service item
  $form->{item} = ($form->{inventory_accno}) ? 'part' : 'service';
  if ($form->{assembly}) {
    $form->{item} = 'assembly';

    # retrieve assembly items
    $query =
      qq|SELECT p.id, p.partnumber, p.description,
           p.sellprice, p.weight, a.qty, a.bom, p.unit,
           pg.partsgroup
         FROM parts p
         JOIN assembly a ON (a.parts_id = p.id)
         LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
         WHERE (a.id = ?)
         ORDER BY $oid{$myconfig->{dbdriver}}|;
    $sth = prepare_execute_query($form, $dbh, $query, conv_i($form->{id}));

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

  my @pricegroups          = ();
  my @pricegroups_not_used = ();

  # get prices
  $query =
    qq|SELECT p.parts_id, p.pricegroup_id, p.price,
         (SELECT pg.pricegroup
          FROM pricegroup pg
          WHERE pg.id = p.pricegroup_id) AS pricegroup
       FROM prices p
       WHERE (parts_id = ?)
       ORDER BY pricegroup|;
  $sth = prepare_execute_query($form, $dbh, $query, conv_i($form->{id}));

  #for pricegroups
  my $i = 1;
  while (($form->{"klass_$i"}, $form->{"pricegroup_id_$i"},
          $form->{"price_$i"}, $form->{"pricegroup_$i"})
         = $sth->fetchrow_array()) {
    $form->{"price_$i"} = $form->round_amount($form->{"price_$i"}, 5);
    $form->{"price_$i"} = $form->format_amount($myconfig, $form->{"price_$i"}, -2);
    push @pricegroups, $form->{"pricegroup_id_$i"};
    $i++;
  }

  $sth->finish;

  # get pricegroups
  $query = qq|SELECT id, pricegroup FROM pricegroup|;
  $form->{PRICEGROUPS} = selectall_hashref_query($form, $dbh, $query);

  #find not used pricegroups
  while ($tmp = pop(@{ $form->{PRICEGROUPS} })) {
    my $in_use = 0;
    foreach my $item (@pricegroups) {
      if ($item eq $tmp->{id}) {
        $in_use = 1;
        last;
      }
    }
    push(@pricegroups_not_used, $tmp) unless ($in_use);
  }

  # if not used pricegroups are avaible
  if (@pricegroups_not_used) {

    foreach $name (@pricegroups_not_used) {
      $form->{"klass_$i"} = "$name->{id}";
      $form->{"price_$i"} = $form->round_amount($form->{sellprice}, 5);
      $form->{"price_$i"} = $form->format_amount($myconfig, $form->{"price_$i"}, -2);
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
      $query = qq|SELECT m.make, m.model FROM makemodel m | .
               qq|WHERE m.parts_id = ?|;
      @values = ($form->{id});
      $sth = $dbh->prepare($query);
      $sth->execute(@values) || $form->dberror("$query (" . join(', ', @values) . ")");

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
  my $trq = prepare_execute_query($form, $dbh, $query, conv_i($form->{id}));
  while ($tr = $trq->fetchrow_hashref(NAME_lc)) {
    $form->{language_values} .= "---+++---".$tr->{language_id}."--++--".$tr->{translation};
  }
  $trq->finish;

  # now get accno for taxes
  $query =
    qq|SELECT c.accno
       FROM chart c, partstax pt
       WHERE (pt.chart_id = c.id) AND (pt.parts_id = ?)|;
  $sth = prepare_execute_query($form, $dbh, $query, conv_i($form->{id}));
  while (($key) = $sth->fetchrow_array) {
    $form->{amount}{$key} = $key;
  }

  $sth->finish;

  # is it an orphan
  my @referencing_tables = qw(invoice orderitems invoice inventory rmaitems);
  my %column_map         = ( );
  my $parts_id           = conv_i($form->{id});

  $form->{orphaned}      = 1;

  foreach my $table (@referencing_tables) {
    my $column  = $column_map{$table} || 'parts_id';
    $query      = qq|SELECT $column FROM $table WHERE $column = ? LIMIT 1|;
    my ($found) = selectrow_query($form, $dbh, $query, $parts_id);

    if ($found) {
      $form->{orphaned} = 0;
      last;
    }
  }

  $form->{"unit_changeable"} = $form->{orphaned};

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub get_pricegroups {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect($myconfig);

  # get pricegroups
  my $query = qq|SELECT id, pricegroup FROM pricegroup|;
  my $pricegroups = selectall_hashref_query($form, $dbh, $query);

  my $i = 1;
  foreach $pg (@{ $pricegroups }) {
    $form->{"klass_$i"} = "$pg->{id}";
    $form->{"price_$i"} = $form->format_amount($myconfig, $form->{"price_$i"}, -2);
    $form->{"pricegroup_id_$i"} = "$pg->{id}";
    $form->{"pricegroup_$i"}    = "$pg->{pricegroup}";
    $i++;
  }

  #correct rows
  $form->{price_rows} = $i - 1;

  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $pricegroups;
}

sub retrieve_buchungsgruppen {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my ($query, $sth);

  my $dbh = $form->dbconnect($myconfig);

  # get buchungsgruppen
  $query = qq|SELECT id, description FROM buchungsgruppen ORDER BY sortkey|;
  $form->{BUCHUNGSGRUPPEN} = selectall_hashref_query($form, $dbh, $query);

  $main::lxdebug->leave_sub();
}

sub save {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;
  my @values;
  # connect to database, turn off AutoCommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  # save the part
  # make up a unique handle and store in partnumber field
  # then retrieve the record based on the unique handle to get the id
  # replace the partnumber field with the actual variable
  # add records for makemodel

  # if there is a $form->{id} then replace the old entry
  # delete all makemodel entries and add the new ones

  # undo amount formatting
  map { $form->{$_} = $form->parse_amount($myconfig, $form->{$_}) }
    qw(rop weight listprice sellprice gv lastcost stock);

  my $makemodel = (($form->{make_1}) || ($form->{model_1})) ? 1 : 0;

  $form->{assembly} = ($form->{item} eq 'assembly') ? 1 : 0;

  my ($query, $sth);

  if ($form->{id}) {

    # get old price
    $query = qq|SELECT sellprice, weight FROM parts WHERE id = ?|;
    my ($sellprice, $weight) = selectrow_query($form, $dbh, $query, conv_i($form->{id}));

    # if item is part of an assembly adjust all assemblies
    $query = qq|SELECT id, qty FROM assembly WHERE parts_id = ?|;
    $sth = prepare_execute_query($form, $dbh, $query, conv_i($form->{id}));
    while (my ($id, $qty) = $sth->fetchrow_array) {
      &update_assembly($dbh, $form, $id, $qty, $sellprice * 1, $weight * 1);
    }
    $sth->finish;

    if ($form->{item} ne 'service') {
      # delete makemodel records
      do_query($form, $dbh, qq|DELETE FROM makemodel WHERE parts_id = ?|, conv_i($form->{id}));
    }

    if ($form->{item} eq 'assembly') {
      # delete assembly records
      do_query($form, $dbh, qq|DELETE FROM assembly WHERE id = ?|, conv_i($form->{id}));
    }

    # delete tax records
    do_query($form, $dbh, qq|DELETE FROM partstax WHERE parts_id = ?|, conv_i($form->{id}));

    # delete translations
    do_query($form, $dbh, qq|DELETE FROM translation WHERE parts_id = ?|, conv_i($form->{id}));

  } else {
    my ($count) = selectrow_query($form, $dbh, qq|SELECT COUNT(*) FROM parts WHERE partnumber = ?|, $form->{partnumber});
    if ($count) {
      $main::lxdebug->leave_sub();
      return 3;
    }

    ($form->{id}) = selectrow_query($form, $dbh, qq|SELECT nextval('id')|);
    do_query($form, $dbh, qq|INSERT INTO parts (id, partnumber) VALUES (?, '')|, $form->{id});

    $form->{orphaned} = 1;
    if ($form->{partnumber} eq "" && $form->{"item"} eq "service") {
      $form->{partnumber} = $form->update_defaults($myconfig, "servicenumber");
    }
    if ($form->{partnumber} eq "" && $form->{"item"} ne "service") {
      $form->{partnumber} = $form->update_defaults($myconfig, "articlenumber");
    }

  }
  my $partsgroup_id = 0;

  if ($form->{partsgroup}) {
    ($partsgroup, $partsgroup_id) = split(/--/, $form->{partsgroup});
  }

  my ($subq_inventory, $subq_expense, $subq_income);
  if ($form->{"item"} eq "part") {
    $subq_inventory =
      qq|(SELECT bg.inventory_accno_id
          FROM buchungsgruppen bg
          WHERE bg.id = | . conv_i($form->{"buchungsgruppen_id"}, 'NULL') . qq|)|;
  } else {
    $subq_inventory = "NULL";
  }

  if ($form->{"item"} ne "assembly") {
    $subq_expense =
      qq|(SELECT bg.expense_accno_id_0
          FROM buchungsgruppen bg
          WHERE bg.id = | . conv_i($form->{"buchungsgruppen_id"}, 'NULL') . qq|)|;
  } else {
    $subq_expense = "NULL";
  }

  $query =
    qq|UPDATE parts SET
         partnumber = ?,
         description = ?,
         makemodel = ?,
         alternate = 'f',
         assembly = ?,
         listprice = ?,
         sellprice = ?,
         lastcost = ?,
         weight = ?,
         priceupdate = ?,
         unit = ?,
         notes = ?,
         formel = ?,
         rop = ?,
         bin = ?,
         buchungsgruppen_id = ?,
         payment_id = ?,
         inventory_accno_id = $subq_inventory,
         income_accno_id = (SELECT bg.income_accno_id_0 FROM buchungsgruppen bg WHERE bg.id = ?),
         expense_accno_id = $subq_expense,
         obsolete = ?,
         image = ?,
         drawing = ?,
         shop = ?,
         ve = ?,
         gv = ?,
         ean = ?,
         not_discountable = ?,
         microfiche = ?,
         partsgroup_id = ?,
         price_factor_id = ?
       WHERE id = ?|;
  @values = ($form->{partnumber},
             $form->{description},
             $makemodel ? 't' : 'f',
             $form->{assembly} ? 't' : 'f',
             $form->{listprice},
             $form->{sellprice},
             $form->{lastcost},
             $form->{weight},
             conv_date($form->{priceupdate}),
             $form->{unit},
             $form->{notes},
             $form->{formel},
             $form->{rop},
             $form->{bin},
             conv_i($form->{buchungsgruppen_id}),
             conv_i($form->{payment_id}),
             conv_i($form->{buchungsgruppen_id}),
             $form->{obsolete} ? 't' : 'f',
             $form->{image},
             $form->{drawing},
             $form->{shop} ? 't' : 'f',
             conv_i($form->{ve}),
             conv_i($form->{gv}),
             $form->{ean},
             $form->{not_discountable} ? 't' : 'f',
             $form->{microfiche},
             conv_i($partsgroup_id),
             conv_i($form->{price_factor_id}),
             conv_i($form->{id})
  );
  do_query($form, $dbh, $query, @values);

  # delete translation records
  do_query($form, $dbh, qq|DELETE FROM translation WHERE parts_id = ?|, conv_i($form->{id}));

  if ($form->{language_values} ne "") {
    foreach $item (split(/---\+\+\+---/, $form->{language_values})) {
      my ($language_id, $translation, $longdescription) = split(/--\+\+--/, $item);
      if ($translation ne "") {
        $query = qq|INSERT into translation (parts_id, language_id, translation, longdescription)
                    VALUES ( ?, ?, ?, ? )|;
        @values = (conv_i($form->{id}), conv_i($language_id), $translation, $longdescription);
        do_query($form, $dbh, $query, @values);
      }
    }
  }

  # delete price records
  do_query($form, $dbh, qq|DELETE FROM prices WHERE parts_id = ?|, conv_i($form->{id}));

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
      #$klass = $form->parse_amount($myconfig, $form->{"klass_$i"});
      $price = $form->parse_amount($myconfig, $form->{"price_$i"});
      $pricegroup_id =
        $form->parse_amount($myconfig, $form->{"pricegroup_id_$i"});
      $query = qq|INSERT INTO prices (parts_id, pricegroup_id, price) | .
               qq|VALUES(?, ?, ?)|;
      @values = (conv_i($form->{id}), conv_i($pricegroup_id), $price);
      do_query($form, $dbh, $query, @values);
    }
  }

  # insert makemodel records
  unless ($form->{item} eq 'service') {
    for my $i (1 .. $form->{makemodel_rows}) {
      if (($form->{"make_$i"}) || ($form->{"model_$i"})) {
        map { $form->{"${_}_$i"} =~ s/\'/\'\'/g } qw(make model);

        $query = qq|INSERT INTO makemodel (parts_id, make, model) | .
		             qq|VALUES (?, ?, ?)|;
		    @values = (conv_i($form->{id}), $form->{"make_$i"}, $form->{"model_$i"});
        do_query($form, $dbh, $query, @values);
      }
    }
  }

  # insert taxes
  foreach $item (split(/ /, $form->{taxaccounts})) {
    if ($form->{"IC_tax_$item"}) {
      $query =
        qq|INSERT INTO partstax (parts_id, chart_id)
           VALUES (?, (SELECT id FROM chart WHERE accno = ?))|;
			@values = (conv_i($form->{id}), $item);
      do_query($form, $dbh, $query, @values);
    }
  }

  # add assembly records
  if ($form->{item} eq 'assembly') {

    for my $i (1 .. $form->{assembly_rows}) {
      $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});

      if ($form->{"qty_$i"} != 0) {
        $form->{"bom_$i"} *= 1;
        $query = qq|INSERT INTO assembly (id, parts_id, qty, bom) | .
		             qq|VALUES (?, ?, ?, ?)|;
		    @values = (conv_i($form->{id}), conv_i($form->{"id_$i"}), conv_i($form->{"qty_$i"}), $form->{"bom_$i"} ? 't' : 'f');
        do_query($form, $dbh, $query, @values);
      }
    }

    @a = localtime;
    $a[5] += 1900;
    $a[4]++;
    my $shippingdate = "$a[5]-$a[4]-$a[3]";

    $form->get_employee($dbh);

  }

  #set expense_accno=inventory_accno if they are different => bilanz
  $vendor_accno =
    ($form->{expense_accno} != $form->{inventory_accno})
    ? $form->{inventory_accno}
    : $form->{expense_accno};

  # get tax rates and description
  $accno_id =
    ($form->{vc} eq "customer") ? $form->{income_accno} : $vendor_accno;
  $query =
    qq|SELECT c.accno, c.description, t.rate, t.taxnumber
       FROM chart c, tax t
       WHERE (c.id = t.chart_id) AND (t.taxkey IN (SELECT taxkey_id FROM chart where accno = ?))
       ORDER BY c.accno|;
  $stw = prepare_execute_query($form, $dbh, $query, $accno_id);

  $form->{taxaccount} = "";
  while ($ptr = $stw->fetchrow_hashref(NAME_lc)) {
    $form->{taxaccount} .= "$ptr->{accno} ";
    if (!($form->{taxaccount2} =~ /\Q$ptr->{accno}\E/)) {
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

  my $query = qq|SELECT id, qty FROM assembly WHERE parts_id = ?|;
  my $sth = prepare_execute_query($form, $dbh, $query, conv_i($id));

  while (my ($pid, $aqty) = $sth->fetchrow_array) {
    &update_assembly($dbh, $form, $pid, $aqty * $qty, $sellprice, $weight);
  }
  $sth->finish;

  $query =
    qq|UPDATE parts SET sellprice = sellprice + ?, weight = weight + ?
       WHERE id = ?|;
  @values = ($qty * ($form->{sellprice} - $sellprice),
             $qty * ($form->{weight} - $weight), conv_i($id));
  do_query($form, $dbh, $query, @values);

  $main::lxdebug->leave_sub();
}

sub retrieve_assemblies {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $where = qq|NOT p.obsolete|;
  my @values;

  if ($form->{partnumber}) {
    $where .= qq| AND (p.partnumber ILIKE ?)|;
    push(@values, '%' . $form->{partnumber} . '%');
  }

  if ($form->{description}) {
    $where .= qq| AND (p.description ILIKE ?)|;
    push(@values, '%' . $form->{description} . '%');
  }

  # retrieve assembly items
  my $query =
    qq|SELECT p.id, p.partnumber, p.description,
         p.bin, p.onhand, p.rop,
         (SELECT sum(p2.inventory_accno_id)
          FROM parts p2, assembly a
          WHERE (p2.id = a.parts_id) AND (a.id = p.id)) AS inventory
       FROM parts p
       WHERE NOT p.obsolete AND p.assembly $where|;

  $form->{assembly_items} = selectall_hashref_query($form, $dbh, $query, @values);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub delete {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;
  my @values = (conv_i($form->{id}));
  # connect to database, turn off AutoCommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  my %columns = ( "assembly" => "id", "parts" => "id" );

  for my $table (qw(prices partstax makemodel inventory assembly license translation parts)) {
    my $column = defined($columns{$table}) ? $columns{$table} : "parts_id";
    do_query($form, $dbh, qq|DELETE FROM $table WHERE $column = ?|, @values);
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
  my $where = qq|1 = 1|;
  my @values;

  my %columns = ("partnumber" => "p", "description" => "p", "partsgroup" => "pg");

  while (my ($column, $table) = each(%columns)) {
    next unless ($form->{"${column}_$i"});
    $where .= qq| AND ${table}.${column} ILIKE ?|;
    push(@values, '%' . $form->{"${column}_$i"} . '%');
  }

  if ($form->{id}) {
    $where .= qq| AND NOT (p.id = ?)|;
    push(@values, conv_i($form->{id}));
  }

  if ($partnumber) {
    $where .= qq| ORDER BY p.partnumber|;
  } else {
    $where .= qq| ORDER BY p.description|;
  }

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query =
    qq|SELECT p.id, p.partnumber, p.description, p.sellprice, p.weight, p.onhand, p.unit, pg.partsgroup
       FROM parts p
       LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
       WHERE $where|;
  $form->{item_list} = selectall_hashref_query($form, $dbh, $query, @values);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

#
# Report for Wares.
# Warning, deep magic ahead.
# This function gets all parts from the database according to the filters specified
#
# specials:
#   sort revers  - sorting field + direction
#   top100
#
# simple filter strings (every one of those also has a column flag prefixed with 'l_' associated):
#   partnumber ean description partsgroup microfiche drawing
#
# column flags:
#   l_partnumber l_description l_listprice l_sellprice l_lastcost l_priceupdate l_weight l_unit l_bin l_rop l_image l_drawing l_microfiche l_partsgroup
#
# exclusives:
#   itemstatus  = active | onhand | short | obsolete | orphaned
#   searchitems = part | assembly | service
#
# joining filters:
#   make model                               - makemodel
#   serialnumber transdatefrom transdateto   - invoice/orderitems
#
# binary flags:
#   bought sold onorder ordered rfq quoted   - aggreg joins with invoices/orders
#   l_linetotal l_subtotal                   - aggreg joins to display totals (complicated) - NOT IMPLEMENTED here, implementation at frontend
#   l_soldtotal                              - aggreg join to display total of sold quantity
#   onhand                                   - as above, but masking the simple itemstatus results (doh!)
#   short                                    - NOT IMPLEMENTED as form filter, only as itemstatus option
#   l_serialnumber                           - belonges to serialnumber filter
#   l_deliverydate                           - displays deliverydate is sold etc. flags are active
#   l_soldtotal                              - aggreg join to display total of sold quantity, works as long as there's no bullshit in soldtotal
#
# not working:
#   onhand                                   - as above, but masking the simple itemstatus results (doh!)
#   masking of onhand in bsooqr mode         - ToDO: fixme
#
# disabled sanity checks and changes:
#  - searchitems = assembly will no longer disable bought
#  - searchitems = service will no longer disable make and model, although services don't have make/model, it doesn't break the query
#  - itemstatus = orphaned will no longer disable onhand short bought sold onorder ordered rfq quoted transdate[from|to]
#  - itemstatus = obsolete will no longer disable onhand, short
#  - allow sorting by ean
#  - serialnumber filter also works if l_serialnumber isn't ticked
#  - onhand doesn't get masked by it's oi or invoice counterparts atm. ToDO: fix this
#  - sorting will now change sorting if the requested sorting column isn't checked and doesn't get checked as a side effect
#
sub all_parts {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;
  my $dbh = $form->get_standard_dbh($myconfig);

  $form->{parts}     = +{ };
  $form->{soldtotal} = undef if $form->{l_soldtotal}; # security fix. top100 insists on putting strings in there...

  my @simple_filters       = qw(partnumber ean description partsgroup microfiche drawing onhand);
  my @makemodel_filters    = qw(make model);
  my @invoice_oi_filters   = qw(serialnumber soldtotal);
  my @apoe_filters         = qw(transdate);
  my @all_columns          = (@simple_filters, @makemodel_filters, @apoe_filters, qw(serialnumber));
  my @simple_l_switches    = (@all_columns, qw(listprice sellprice lastcost priceupdate weight unit bin rop image));
  my @oe_flags             = qw(bought sold onorder ordered rfq quoted);
  my @qsooqr_flags         = qw(invnumber ordnumber quonumber trans_id name module);
  my @deliverydate_flags   = qw(deliverydate);
#  my @other_flags          = qw(onhand); # ToDO: implement these
#  my @inactive_flags       = qw(l_subtotal short l_linetotal);

  my %joins = (
    partsgroup => 'LEFT JOIN partsgroup pg      ON (pg.id       = p.partsgroup_id)',
    makemodel  => 'LEFT JOIN makemodel mm       ON (mm.parts_id = p.id)',
    pfac       => 'LEFT JOIN price_factors pfac ON (pfac.id     = p.price_factor_id)',
    invoice_oi =>
      q|LEFT JOIN (
         SELECT parts_id, description, serialnumber, trans_id, unit, sellprice, qty,          assemblyitem, 'invoice'    AS ioi FROM invoice UNION
         SELECT parts_id, description, serialnumber, trans_id, unit, sellprice, qty, FALSE AS assemblyitem, 'orderitems' AS ioi FROM orderitems
       ) AS ioi ON ioi.parts_id = p.id|,
    apoe       =>
      q|LEFT JOIN (
         SELECT id, transdate, 'ir' AS module, ordnumber, quonumber,         invnumber, FALSE AS quotation, NULL AS customer_id,         vendor_id, NULL AS deliverydate FROM ap UNION
         SELECT id, transdate, 'is' AS module, ordnumber, quonumber,         invnumber, FALSE AS quotation,         customer_id, NULL AS vendor_id,         deliverydate FROM ar UNION
         SELECT id, transdate, 'oe' AS module, ordnumber, quonumber, NULL AS invnumber,          quotation,         customer_id,         vendor_id, NULL AS deliverydate FROM oe
       ) AS apoe ON ioi.trans_id = apoe.id|,
    cv         =>
      q|LEFT JOIN (
           SELECT id, name, 'customer' AS cv FROM customer UNION
           SELECT id, name, 'vendor'   AS cv FROM vendor
         ) AS cv ON cv.id = apoe.customer_id OR cv.id = apoe.vendor_id|,
  );
  my @join_order = qw(partsgroup makemodel invoice_oi apoe cv pfac);
  my %joins_needed;

  #===== switches and simple filters ========#

  my @select_tokens = qw(id factor);
  my @where_tokens  = qw(1=1);
  my @group_tokens  = ();

  # special case transdate
  if (grep { $form->{$_} } qw(transdatefrom transdateto)) {
    $form->{"l_transdate"} = 1;
    push @select_tokens, 'transdate';
    for (qw(transdatefrom transdateto)) {
      next unless $form->{$_};
      push @where_tokens, sprintf "transdate %s ?", /from$/ ? '>=' : '<=';
      push @bind_vars,    $form->{$_};
    }
  }

  my %simple_filter_table_prefix = (
     description  => 'p.',
  );

  foreach (@simple_filters, @makemodel_filters, @invoice_oi_filters) {
    next unless $form->{$_};
    $form->{"l_$_"} = '1'; # show the column
    push @where_tokens, "$simple_filter_table_prefix{$_}$_ ILIKE ?";
    push @bind_vars,    "%$form->{$_}%";
  }

  foreach (@simple_l_switches) {
    next unless $form->{"l_$_"};
    push @select_tokens, $_;
  }

  for ($form->{searchitems}) {
    push @where_tokens, 'p.inventory_accno_id > 0'     if /part/;
    push @where_tokens, 'p.inventory_accno_id IS NULL' if /service/;
    push @where_tokens, 'NOT p.assembly'               if /service/;
    push @where_tokens, '    p.assembly'               if /assembly/;
  }

  for ($form->{itemstatus}) {
    push @where_tokens, 'p.id NOT IN
        (SELECT DISTINCT parts_id FROM invoice UNION
         SELECT DISTINCT parts_id FROM assembly UNION
         SELECT DISTINCT parts_id FROM orderitems)'    if /orphaned/;
    push @where_tokens, 'p.onhand = 0'                 if /orphaned/;
    push @where_tokens, 'NOT p.obsolete'               if /active/;
    push @where_tokens, '    p.obsolete',              if /obsolete/;
    push @where_tokens, 'p.onhand > 0',                if /onhand/;
    push @where_tokens, 'p.onhand < p.rop',            if /short/;
  }


  my @sort_cols = (@simple_filters, qw(id bin priceupdate onhand invnumber ordnumber quonumber name serialnumber soldtotal deliverydate));
  $form->{sort} = 'id' unless grep { $form->{"l_$_"} } grep { $form->{sort} eq $_ } @sort_cols;

  my $sort_order = ($form->{revers} ? ' DESC' : ' ASC');

  # special case: sorting by partnumber
  # since partnumbers are expected to be prefixed integers, a special sorting is implemented sorting first lexically by prefix and then by suffix.
  # and yes, that expression is designed to hold that array of regexes only once, so the map is kinda messy, sorry about that.
  # ToDO: implement proper functional sorting
  $form->{sort} = join ', ', map { push @select_tokens, $_; ($table_prefix{$_} = "substring(partnumber,'[") . $_ } qw|^[:digit:]]+') [:digit:]]+')::INTEGER|
    if $form->{sort} eq 'partnumber';

  my $order_clause = " ORDER BY $form->{sort} $sort_order";

  my $limit_clause = " LIMIT 100" if $form->{top100};

  #=== joins and complicated filters ========#

  my $bsooqr = $form->{bought}  || $form->{sold}
            || $form->{ordered} || $form->{onorder}
            || $form->{quoted}  || $form->{rfq};

  my @bsooqr;
  push @select_tokens, @qsooqr_flags                                          if $bsooqr;
  push @select_tokens, @deliverydate_flags                                    if $bsooqr && $form->{l_deliverydate};
  push @bsooqr_tokens, q|module = 'ir' AND NOT ioi.assemblyitem|              if $form->{bought};
  push @bsooqr_tokens, q|module = 'is' AND NOT ioi.assemblyitem|              if $form->{sold};
  push @bsooqr_tokens, q|module = 'oe' AND NOT quotation AND cv = 'customer'| if $form->{ordered};
  push @bsooqr_tokens, q|module = 'oe' AND NOT quotation AND cv = 'vendor'|   if $form->{onorder};
  push @bsooqr_tokens, q|module = 'oe' AND     quotation AND cv = 'customer'| if $form->{quoted};
  push @bsooqr_tokens, q|module = 'oe' AND     quotation AND cv = 'vendor'|   if $form->{rfq};
  push @where_tokens, join ' OR ', map { "($_)" } @bsooqr_tokens              if $bsooqr;

  $joins_needed{partsgroup}  = 1;
  $joins_needed{pfac}        = 1;
  $joins_needed{makemodel}   = 1 if grep { $form->{$_} || $form->{"l_$_"} } @makemodel_filters;
  $joins_needed{cv}          = 1 if $bsooqr;
  $joins_needed{apoe}        = 1 if $joins_needed{cv}   || grep { $form->{$_} || $form->{"l_$_"} } @apoe_filters;
  $joins_needed{invoice_oi}  = 1 if $joins_needed{apoe} || grep { $form->{$_} || $form->{"l_$_"} } @invoice_oi_filters;

  # special case for description search.
  # up in the simple filter section the description filter got interpreted as something like: WHERE description ILIKE '%$form->{description}%'
  # now we'd like to search also for the masked description entered in orderitems and invoice, so...
  # find the old entries in of @where_tokens and @bind_vars, and adjust them
  if ($joins_needed{invoice_oi}) {
    for (my ($wi, $bi) = (0)x2; $wi <= $#where_tokens; $bi++ if $where_tokens[$wi++] =~ /\?/) {
      next unless $where_tokens[$wi] =~ /^description ILIKE/;
      splice @where_tokens, $wi, 1, 'p.description ILIKE ? OR ioi.description ILIKE ?';
      splice @bind_vars,    $bi, 0, $bind_vars[$bi];
      last;
    }
  }

  # now the master trick: soldtotal.
  if ($form->{l_soldtotal}) {
    push @where_tokens, 'ioi.qty >= 0';
    push @group_tokens, @select_tokens;
    push @select_tokens, 'SUM(ioi.qty)';
  }

  #============= build query ================#

  %table_prefix = (
     %table_prefix,
     deliverydate => 'apoe.', serialnumber => 'ioi.',
     transdate    => 'apoe.', trans_id     => 'ioi.',
     module       => 'apoe.', name         => 'cv.',
     ordnumber    => 'apoe.', make         => 'mm.',
     quonumber    => 'apoe.', model        => 'mm.',
     invnumber    => 'apoe.', partsgroup   => 'pg.',
     factor       => 'pfac.',
     'SUM(ioi.qty)' => ' ',
  );

  my %renamed_columns = (
    'factor'       => 'price_factor',
    'SUM(ioi.qty)' => 'soldtotal',
  );

  map { $table_prefix{$_} = 'ioi.' } qw(description serialnumber qty unit) if $joins_needed{invoice_oi};
  map { $renamed_columns{$_} = ' AS ' . $renamed_columns{$_} } keys %renamed_columns;

  my $select_clause = join ', ',    map { ($table_prefix{$_} || "p.") . $_ . $renamed_columns{$_} } @select_tokens;
  my $join_clause   = join ' ',     @joins{ grep $joins_needed{$_}, @join_order };
  my $where_clause  = join ' AND ', map { "($_)" } @where_tokens;
  my $group_clause  = ' GROUP BY ' . join ', ',    map { ($table_prefix{$_} || "p.") . $_ } @group_tokens if scalar @group_tokens;

  my $query = qq|SELECT DISTINCT $select_clause FROM parts p $join_clause WHERE $where_clause $group_clause $order_clause $limit_clause|;

  $form->{parts} = selectall_hashref_query($form, $dbh, $query, @bind_vars);

  map { $_->{onhand} *= 1 } @{ $form->{parts} };

##  my $where = qq|1 = 1|;
##  my (@values, $var, $flds, $group, $limit);
##
##  foreach my $item (qw(partnumber drawing microfiche ean pg.partsgroup)) {
##    my $column = $item;
##    $column =~ s/.*\.//; # get rid of table prefixes
##    if ($form->{$column}) {
##      $where .= qq| AND ($item ILIKE ?)|;
##      push(@values, "%$form->{$column}%");
##    }
##  }
##
##  # special case for description
##  if ($form->{description}
##      && !(   $form->{bought}  || $form->{sold} || $form->{onorder}
##           || $form->{ordered} || $form->{rfq} || $form->{quoted})) {
##    $where .= qq| AND (p.description ILIKE ?)|;
##    push(@values, "%$form->{description}%");
##  }
##
##  # special case for serialnumber
##  if ($form->{l_serialnumber} && $form->{serialnumber}) {
##    $where .= qq| AND (serialnumber ILIKE ?)|;
##    push(@values, "%$form->{serialnumber}%");
##  }
##
##  if ($form->{searchitems} eq 'part') {
##    $where .= qq| AND (p.inventory_accno_id > 0) |;
##  }
##
##  if ($form->{searchitems} eq 'assembly') {
##    $form->{bought} = "";
##    $where .= qq| AND p.assembly|;
##  }
##
##  if ($form->{searchitems} eq 'service') {
##    $where .= qq| AND (p.inventory_accno_id IS NULL) AND NOT (p.assembly = '1')|;
##    # irrelevant for services
##    map { $form->{$_} = '' } qw(make model);
##  }
##
##  # items which were never bought, sold or on an order
##  if ($form->{itemstatus} eq 'orphaned') {
##    map { $form->{$_} = 0  } qw(onhand short bought sold onorder ordered rfq quoted);
##    map { $form->{$_} = '' } qw(transdatefrom transdateto);
##
##    $where .=
##      qq| AND (p.onhand = 0)
##          AND p.id NOT IN
##            (
##              SELECT DISTINCT parts_id FROM invoice
##              UNION
##              SELECT DISTINCT parts_id FROM assembly
##              UNION
##              SELECT DISTINCT parts_id FROM orderitems
##            )|;
##  }
##
##  my %status2condition = (
##    active   => " AND (p.obsolete = '0')",
##    obsolete => " AND (p.obsolete = '1')",
##    onhand   => " AND (p.onhand > 0)",
##    short    => " AND (p.onhand < p.rop)",
##  );
##  $where .= $status2condition{$form->{itemstatus}};
##
##  $form->{onhand} = $form->{short} = 0 if ($form->{itemstatus} eq 'obsolete');
##
##  my @subcolumns;
##  foreach my $column (qw(make model)) {
##    push @subcolumns, $column if $form->{$column};
##  }
##  if (@subcolumns) {
##    $where .= qq| AND p.id IN (SELECT DISTINCT parts_id FROM makemodel WHERE | . (join " AND ", map { "($_ ILIKE ?)"; } @subcolumns) . ")";
##    push @values, map { '%' . $form->{$_} . '%' } @subcolumns;
##  }
##
##  if ($form->{l_soldtotal}) {
##    $where .= qq| AND (p.id = i.parts_id) AND (i.qty >= 0)|;
##    $group = qq| GROUP BY p.id, p.partnumber, p.description, p.onhand, p.unit, p.bin, p.sellprice, p.listprice, p.lastcost, p.priceupdate, pg.partsgroup|;
##  }
##
##  $limit = qq| LIMIT 100| if ($form->{top100});
##
##  # connect to database
##  my $dbh = $form->dbconnect($myconfig);
##
##  my @sort_cols = qw(id partnumber description partsgroup bin priceupdate onhand
##                     invnumber ordnumber quonumber name drawing microfiche
##                     serialnumber soldtotal deliverydate);
##
##  my $sortorder = "partnumber";
##  $sortorder = $form->{sort} if ($form->{sort} && grep({ $_ eq $form->{sort} } @sort_cols));
##  $sortorder .= " DESC" if ($form->{revers});
##
##  my $query = "";
##
##  if ($form->{l_soldtotal}) {
##    $form->{soldtotal} = 'soldtotal';
##    $query =
##      qq|SELECT p.id, p.partnumber, p.description, p.onhand, p.unit,
##           p.bin, p.sellprice, p.listprice, p.lastcost,
##           p.priceupdate, pg.partsgroup,sum(i.qty) AS soldtotal
##         FROM parts p
##         LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id), invoice i
##         WHERE $where
##         $group
##         ORDER BY $sortorder $limit|;
##  } else {
##    $query =
##      qq|SELECT p.id, p.partnumber, p.description, p.onhand, p.unit,
##           p.bin, p.sellprice, p.listprice, p.lastcost, p.rop, p.weight,
##           p.priceupdate, p.image, p.drawing, p.microfiche,
##           pg.partsgroup
##         FROM parts p
##         LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
##         WHERE $where
##         $group
##         ORDER BY $sortorder $limit|;
##  }
##
##  my @all_values = @values;
##
##  # rebuild query for bought and sold items
##  if (   $form->{bought}
##      || $form->{sold}
##      || $form->{onorder}
##      || $form->{ordered}
##      || $form->{rfq}
##      || $form->{quoted}) {
##    my $union = "";
##    $query = "";
##    @all_values = ();
##
##    if ($form->{bought} || $form->{sold}) {
##
##      my @invvalues = @values;
##      my $invwhere = "$where";
#      $invwhere .= qq| AND i.assemblyitem = '0'|;
##
##      if ($form->{transdatefrom}) {
##        $invwhere .= qq| AND a.transdate >= ?|;
##        push(@invvalues, $form->{transdatefrom});
##      }
##
##      if ($form->{transdateto}) {
##        $invwhere .= qq| AND a.transdate <= ?|;
##        push(@invvalues, $form->{transdateto});
##      }
##
##      if ($form->{description}) {
##        $invwhere .= qq| AND i.description ILIKE ?|;
##        push(@invvalues, '%' . $form->{description} . '%');
##      }
##
##      $flds =
##        qq|p.id, p.partnumber, i.description, i.serialnumber,
#           i.qty AS onhand, i.unit, p.bin, i.sellprice,
##           p.listprice, p.lastcost, p.rop, p.weight,
##           p.priceupdate, p.image, p.drawing, p.microfiche,
##           pg.partsgroup,
##           a.invnumber, a.ordnumber, a.quonumber, i.trans_id,
##           ct.name, i.deliverydate|;
##
##      if ($form->{bought}) {
##        $query =
##          qq|SELECT $flds, 'ir' AS module, '' AS type, 1 AS exchangerate
##             FROM invoice i
##             JOIN parts p ON (p.id = i.parts_id)
##             JOIN ap a ON (a.id = i.trans_id)
##             JOIN vendor ct ON (a.vendor_id = ct.id)
##             LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
##             WHERE $invwhere|;
##
##        $union = qq| UNION |;
##
##        push(@all_values, @invvalues);
##      }
##
##      if ($form->{sold}) {
##        $query .=
##          qq|$union
##
##             SELECT $flds, 'is' AS module, '' AS type, 1 As exchangerate
##             FROM invoice i
##             JOIN parts p ON (p.id = i.parts_id)
##             JOIN ar a ON (a.id = i.trans_id)
##             JOIN customer ct ON (a.customer_id = ct.id)
##             LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
##             WHERE $invwhere|;
##        $union = qq| UNION |;
##
##        push(@all_values, @invvalues);
##      }
##    }
##
##    if ($form->{onorder} || $form->{ordered}) {
##      my @ordvalues = @values;
##      my $ordwhere = $where . qq| AND o.quotation = '0'|;
##
##      if ($form->{transdatefrom}) {
##        $ordwhere .= qq| AND o.transdate >= ?|;
##        push(@ordvalues, $form->{transdatefrom});
##      }
##
##      if ($form->{transdateto}) {
##        $ordwhere .= qq| AND o.transdate <= ?|;
##        push(@ordvalues, $form->{transdateto});
##      }
##
##      if ($form->{description}) {
##        $ordwhere .= qq| AND oi.description ILIKE ?|;
##        push(@ordvalues, '%' . $form->{description} . '%');
##      }
##
##      if ($form->{ordered}) {
##        $query .=
##          qq|$union
##
##             SELECT p.id, p.partnumber, oi.description, oi.serialnumber AS serialnumber,
##               oi.qty AS onhand, oi.unit, p.bin, oi.sellprice,
##               p.listprice, p.lastcost, p.rop, p.weight,
##               p.priceupdate, p.image, p.drawing, p.microfiche,
##               pg.partsgroup,
##               '' AS invnumber, o.ordnumber, o.quonumber, oi.trans_id,
##               ct.name, NULL AS deliverydate,
##               'oe' AS module, 'sales_order' AS type,
##               (SELECT buy FROM exchangerate ex
##                WHERE ex.curr = o.curr AND ex.transdate = o.transdate) AS exchangerate
##             FROM orderitems oi
##             JOIN parts p ON (oi.parts_id = p.id)
##             JOIN oe o ON (oi.trans_id = o.id)
##             JOIN customer ct ON (o.customer_id = ct.id)
##             LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
##             WHERE $ordwhere AND (o.customer_id > 0)|;
##        $union = qq| UNION |;
##
##        push(@all_values, @ordvalues);
##      }
##
##      if ($form->{onorder}) {
##        $query .=
##          qq|$union
##
##             SELECT p.id, p.partnumber, oi.description, oi.serialnumber AS serialnumber,
##               oi.qty * -1 AS onhand, oi.unit, p.bin, oi.sellprice,
##               p.listprice, p.lastcost, p.rop, p.weight,
##               p.priceupdate, p.image, p.drawing, p.microfiche,
##               pg.partsgroup,
##               '' AS invnumber, o.ordnumber, o.quonumber, oi.trans_id,
##               ct.name, NULL AS deliverydate,
##               'oe' AS module, 'purchase_order' AS type,
##               (SELECT sell FROM exchangerate ex
##               WHERE ex.curr = o.curr AND (ex.transdate = o.transdate)) AS exchangerate
##             FROM orderitems oi
##             JOIN parts p ON (oi.parts_id = p.id)
##             JOIN oe o ON (oi.trans_id = o.id)
##             JOIN vendor ct ON (o.vendor_id = ct.id)
##             LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
##             WHERE $ordwhere AND (o.vendor_id > 0)|;
##        $union = qq| UNION |;
##
##        push(@all_values, @ordvalues);
##      }
##
##    }
##
##    if ($form->{rfq} || $form->{quoted}) {
##      my $quowhere = $where . qq| AND o.quotation = '1'|;
##      my @quovalues = @values;
##
##      if ($form->{transdatefrom}) {
##        $quowhere .= qq| AND o.transdate >= ?|;
##        push(@quovalues, $form->{transdatefrom});
##      }
##
##      if ($form->{transdateto}) {
##        $quowhere .= qq| AND o.transdate <= ?|;
##        push(@quovalues, $form->{transdateto});
##      }
##
##      if ($form->{description}) {
##        $quowhere .= qq| AND oi.description ILIKE ?|;
##        push(@quovalues, '%' . $form->{description} . '%');
##      }
##
##      if ($form->{quoted}) {
##        $query .=
##          qq|$union
##
##             SELECT
##               p.id, p.partnumber, oi.description, oi.serialnumber AS serialnumber,
##               oi.qty AS onhand, oi.unit, p.bin, oi.sellprice,
##               p.listprice, p.lastcost, p.rop, p.weight,
##               p.priceupdate, p.image, p.drawing, p.microfiche,
##               pg.partsgroup,
##               '' AS invnumber, o.ordnumber, o.quonumber, oi.trans_id,
##               ct.name, NULL AS deliverydate, 'oe' AS module, 'sales_quotation' AS type,
##               (SELECT buy FROM exchangerate ex
##                WHERE (ex.curr = o.curr) AND (ex.transdate = o.transdate)) AS exchangerate
##             FROM orderitems oi
##             JOIN parts p ON (oi.parts_id = p.id)
##             JOIN oe o ON (oi.trans_id = o.id)
##             JOIN customer ct ON (o.customer_id = ct.id)
##             LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
##             WHERE $quowhere
##             AND o.customer_id > 0|;
##        $union = qq| UNION |;
##
##        push(@all_values, @quovalues);
##      }
##
##      if ($form->{rfq}) {
##        $query .=
##          qq|$union
##
##             SELECT p.id, p.partnumber, oi.description, oi.serialnumber AS serialnumber,
##               oi.qty * -1 AS onhand, oi.unit, p.bin, oi.sellprice,
##               p.listprice, p.lastcost, p.rop, p.weight,
##               p.priceupdate, p.image, p.drawing, p.microfiche,
##               pg.partsgroup,
##               '' AS invnumber, o.ordnumber, o.quonumber, oi.trans_id,
##               ct.name, NULL AS deliverydate,
##               'oe' AS module, 'request_quotation' AS type,
##               (SELECT sell FROM exchangerate ex
##               WHERE (ex.curr = o.curr) AND (ex.transdate = o.transdate)) AS exchangerate
##             FROM orderitems oi
##             JOIN parts p ON (oi.parts_id = p.id)
##             JOIN oe o ON (oi.trans_id = o.id)
##             JOIN vendor ct ON (o.vendor_id = ct.id)
##             LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
##             WHERE $quowhere
##             AND o.vendor_id > 0|;
##
##        push(@all_values, @quovalues);
##      }
##
##    }
##    $query .= qq| ORDER BY  | . $sortorder;
##
##  }
##
##  $form->{parts} = selectall_hashref_query($form, $dbh, $query, @all_values);
#
  my @assemblies;
  # include individual items for assemblies
  if ($form->{searchitems} eq 'assembly' && $form->{bom}) {
    $query =
      qq|SELECT p.id, p.partnumber, p.description, a.qty AS onhand,
           p.unit, p.bin,
           p.sellprice, p.listprice, p.lastcost,
           p.rop, p.weight, p.priceupdate,
           p.image, p.drawing, p.microfiche
         FROM parts p, assembly a
         WHERE (p.id = a.parts_id) AND (a.id = ?)|;
    $sth = prepare_query($form, $dbh, $query);

    foreach $item (@{ $form->{parts} }) {
      push(@assemblies, $item);
      do_statement($form, $sth, $query, conv_i($item->{id}));

      while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
        $ref->{assemblyitem} = 1;
        push(@assemblies, $ref);
      }
      $sth->finish;
    }

    # copy assemblies to $form->{parts}
    $form->{parts} = \@assemblies;
  }

  $main::lxdebug->leave_sub();
}

sub update_prices {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;
  my @where_values;
  my $where = '1 = 1';
  my $var;

  my $group;
  my $limit;

  if ($item ne 'make') {
    foreach my $item (qw(partnumber drawing microfiche make model pg.partsgroup)) {
      my $column = $item;
      $column =~ s/.*\.//;
      next unless ($form->{$column});
      $where .= qq| AND $item ILIKE ?|;
      push(@where_values, '%' . $form->{$column} . '%');
    }
  }

  # special case for description
  if ($form->{description}
      && !(   $form->{bought}  || $form->{sold} || $form->{onorder}
           || $form->{ordered} || $form->{rfq} || $form->{quoted})) {
    $where .= qq| AND (p.description ILIKE ?)|;
    push(@where_values, '%' . $form->{description} . '%');
  }

  # special case for serialnumber
  if ($form->{l_serialnumber} && $form->{serialnumber}) {
    $where .= qq| AND serialnumber ILIKE ?|;
    push(@where_values, '%' . $form->{serialnumber} . '%');
  }


  # items which were never bought, sold or on an order
  if ($form->{itemstatus} eq 'orphaned') {
    $form->{onhand}  = $form->{short}   = 0;
    $form->{bought}  = $form->{sold}    = 0;
    $form->{onorder} = $form->{ordered} = 0;
    $form->{rfq}     = $form->{quoted}  = 0;

    $form->{transdatefrom} = $form->{transdateto} = "";

    $where .=
      qq| AND (p.onhand = 0)
          AND p.id NOT IN
            (
              SELECT DISTINCT parts_id FROM invoice
              UNION
              SELECT DISTINCT parts_id FROM assembly
              UNION
              SELECT DISTINCT parts_id FROM orderitems
            )|;
  }

  if ($form->{itemstatus} eq 'active') {
    $where .= qq| AND p.obsolete = '0'|;
  }

  if ($form->{itemstatus} eq 'obsolete') {
    $where .= qq| AND p.obsolete = '1'|;
    $form->{onhand} = $form->{short} = 0;
  }

  if ($form->{itemstatus} eq 'onhand') {
    $where .= qq| AND p.onhand > 0|;
  }

  if ($form->{itemstatus} eq 'short') {
    $where .= qq| AND p.onhand < p.rop|;
  }

  foreach my $column (qw(make model)) {
    next unless ($form->{$colum});
    $where .= qq| AND p.id IN (SELECT DISTINCT parts_id FROM makemodel WHERE $column ILIKE ?|;
    push(@where_values, '%' . $form->{$column} . '%');
  }

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  for my $column (qw(sellprice listprice)) {
    next if ($form->{$column} eq "");

    my $value = $form->parse_amount($myconfig, $form->{$column});
    my $operator = '+';

    if ($form->{"${column}_type"} eq "percent") {
      $value = ($value / 100) + 1;
      $operator = '*';
    }

    $query =
      qq|UPDATE parts SET $column = $column $operator ?
         WHERE id IN
           (SELECT p.id
            FROM parts p
            LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
            WHERE $where)|;
    do_query($from, $dbh, $query, $value, @where_values);
  }

  my $q_add =
    qq|UPDATE prices SET price = price + ?
       WHERE parts_id IN
         (SELECT p.id
          FROM parts p
          LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
          WHERE $where) AND (pricegroup_id = ?)|;
  my $sth_add = prepare_query($form, $dbh, $q_add);

  my $q_multiply =
    qq|UPDATE prices SET price = price * ?
       WHERE parts_id IN
         (SELECT p.id
          FROM parts p
          LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
          WHERE $where) AND (pricegroup_id = ?)|;
  my $sth_multiply = prepare_query($form, $dbh, $q_multiply);

  for my $i (1 .. $form->{price_rows}) {
    next if ($form->{"price_$i"} eq "");

    my $value = $form->parse_amount($myconfig, $form->{"price_$i"});

    if ($form->{"pricegroup_type_$i"} eq "percent") {
      do_statement($form, $sth_multiply, $q_multiply, ($value / 100) + 1, @where_values, conv_i($form->{"pricegroup_id_$i"}));
    } else {
      do_statement($form, $sth_add, $q_add, $value, @where_values, conv_i($form->{"pricegroup_id_$i"}));
    }
  }

  $sth_add->finish();
  $sth_multiply->finish();

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

  my @values = ('%' . $module . '%');

  if ($form->{id}) {
    $query =
      qq|SELECT c.accno, c.description, c.link, c.id,
           p.inventory_accno_id, p.income_accno_id, p.expense_accno_id
         FROM chart c, parts p
         WHERE (c.link LIKE ?) AND (p.id = ?)
         ORDER BY c.accno|;
    push(@values, conv_i($form->{id}));

  } else {
    $query =
      qq|SELECT c.accno, c.description, c.link, c.id,
           d.inventory_accno_id, d.income_accno_id, d.expense_accno_id
         FROM chart c, defaults d
         WHERE c.link LIKE ?
         ORDER BY c.accno|;
  }

  my $sth = prepare_execute_query($form, $dbh, $query, @values);
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    foreach my $key (split(/:/, $ref->{link})) {
      if ($key =~ /\Q$module\E/) {
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
  $form->{BUCHUNGSGRUPPEN} = selectall_hashref_query($form, $dbh, qq|SELECT id, description FROM buchungsgruppen|);

  # get payment terms
  $form->{payment_terms} = selectall_hashref_query($form, $dbh, qq|SELECT id, description FROM payment_terms ORDER BY sortkey|);

  if (!$form->{id}) {
    ($form->{priceupdate}) = selectrow_query($form, $dbh, qq|SELECT current_date|);
  }

  $dbh->disconnect;
  $main::lxdebug->leave_sub();
}

# get partnumber, description, unit, sellprice and soldtotal with choice through $sortorder for Top100
sub get_parts {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $sortorder) = @_;
  my $dbh   = $form->dbconnect($myconfig);
  my $order = qq| p.partnumber|;
  my $where = qq|1 = 1|;
  my @values;

  if ($sortorder eq "all") {
    $where .= qq| AND (partnumber ILIKE ?) AND (description ILIKE ?)|;
    push(@values, '%' . $form->{partnumber} . '%', '%' . $form->{description} . '%');

  } elsif ($sortorder eq "partnumber") {
    $where .= qq| AND (partnumber ILIKE ?)|;
    push(@values, '%' . $form->{partnumber} . '%');

  } elsif ($sortorder eq "description") {
    $where .= qq| AND (description ILIKE ?)|;
    push(@values, '%' . $form->{description} . '%');
    $order = "description";

  }

  my $query =
    qq|SELECT id, partnumber, description, unit, sellprice
       FROM parts
       WHERE $where ORDER BY $order|;

  my $sth = prepare_execute_query($form, $dbh, $query, @values);

  my $j = 0;
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    if (($ref->{partnumber} eq "*") && ($ref->{description} eq "")) {
      next;
    }

    $j++;
    $form->{"id_$j"}          = $ref->{id};
    $form->{"partnumber_$j"}  = $ref->{partnumber};
    $form->{"description_$j"} = $ref->{description};
    $form->{"unit_$j"}        = $ref->{unit};
    $form->{"sellprice_$j"}   = $ref->{sellprice};
    $form->{"soldtotal_$j"}   = get_soldtotal($dbh, $ref->{id});
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

  my $query = qq|SELECT sum(qty) FROM invoice WHERE parts_id = ?|;
  my ($sum) = selectrow_query($form, $dbh, $query, conv_i($id));
  $sum ||= 0;

  $main::lxdebug->leave_sub();

  return $sum;
}    #end get_soldtotal

sub retrieve_languages {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my @values;
  my $where;

  if ($form->{language_values} ne "") {
    $query =
      qq|SELECT l.id, l.description, tr.translation, tr.longdescription
         FROM language l
         LEFT OUTER JOIN translation tr ON (tr.language_id = l.id) AND (tr.parts_id = ?)
         ORDER BY lower(l.description)|;
    @values = (conv_i($form->{id}));

  } else {
    $query = qq|SELECT id, description
                FROM language
                ORDER BY lower(description)|;
  }

  my $languages = selectall_hashref_query($form, $dbh, $query, @values);

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
    qq|SELECT c.new_chart_id, date($transdate) >= c.valid_from AS is_valid, | .
    qq|  cnew.accno | .
    qq|FROM chart c | .
    qq|LEFT JOIN chart cnew ON c.new_chart_id = cnew.id | .
    qq|WHERE (c.id = ?) AND NOT c.new_chart_id ISNULL AND (c.new_chart_id > 0)|;
  $sth = prepare_query($form, $dbh, $query);

  while (1) {
    do_statement($form, $sth, $query, $accno_id);
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

  my ($self, $myconfig, $form, $parts_id, $index) = @_;

  my ($query, $sth, $dbh);

  $form->{"taxzone_id"} *= 1;

  $dbh = $form->get_standard_dbh($myconfig);

  my $transdate = "";
  if ($form->{type} eq "invoice") {
    if (($form->{vc} eq "vendor") || !$form->{deliverydate}) {
      $transdate = $form->{invdate};
    } else {
      $transdate = $form->{deliverydate};
    }
  } elsif (($form->{type} eq "credit_note") || ($form->{script} eq 'ir.pl')) {
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
    qq|SELECT | .
    qq|  p.inventory_accno_id AS is_part, | .
    qq|  bg.inventory_accno_id, | .
    qq|  bg.income_accno_id_$form->{taxzone_id} AS income_accno_id, | .
    qq|  bg.expense_accno_id_$form->{taxzone_id} AS expense_accno_id, | .
    qq|  c1.accno AS inventory_accno, | .
    qq|  c2.accno AS income_accno, | .
    qq|  c3.accno AS expense_accno | .
    qq|FROM parts p | .
    qq|LEFT JOIN buchungsgruppen bg ON p.buchungsgruppen_id = bg.id | .
    qq|LEFT JOIN chart c1 ON bg.inventory_accno_id = c1.id | .
    qq|LEFT JOIN chart c2 ON bg.income_accno_id_$form->{taxzone_id} = c2.id | .
    qq|LEFT JOIN chart c3 ON bg.expense_accno_id_$form->{taxzone_id} = c3.id | .
    qq|WHERE p.id = ?|;
  my $ref = selectfirst_hashref_query($form, $dbh, $query, $parts_id);

  return $main::lxdebug->leave_sub(2) if (!$ref);

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
    qq|SELECT c.accno, t.taxdescription AS description, t.rate, t.taxnumber | .
    qq|FROM tax t | .
    qq|LEFT JOIN chart c ON c.id = t.chart_id | .
    qq|WHERE t.id IN | .
    qq|  (SELECT tk.tax_id | .
    qq|   FROM taxkeys tk | .
    qq|   WHERE tk.chart_id = ? AND startdate <= | . quote_db_date($transdate) .
    qq|   ORDER BY startdate DESC LIMIT 1) |;
  $ref = selectfirst_hashref_query($form, $dbh, $query, $accno_id);

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

sub get_basic_part_info {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(id));

  my @ids      = 'ARRAY' eq ref $params{id} ? @{ $params{id} } : ($params{id});

  if (!scalar @ids) {
    $main::lxdebug->leave_sub();
    return ();
  }

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $form->get_standard_dbh($myconfig);

  my $query    = qq|SELECT id, partnumber, description, unit FROM parts WHERE id IN (| . join(', ', ('?') x scalar(@ids)) . qq|)|;

  my $info     = selectall_hashref_query($form, $dbh, $query, map { conv_i($_) } @ids);

  if ('' eq ref $params{id}) {
    $info = $info->[0] || { };

    $main::lxdebug->leave_sub();
    return $info;
  }

  my %info_map = map { $_->{id} => $_ } @{ $info };

  $main::lxdebug->leave_sub();

  return %info_map;
}


1;
