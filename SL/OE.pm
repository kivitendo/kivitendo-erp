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
# Order entry module
# Quotation
#======================================================================

package OE;

use SL::AM;
use SL::DBUtils;

sub transactions {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query;
  my $ordnumber = 'ordnumber';
  my $quotation = '0';
  my ($null, $department_id) = split /--/, $form->{department};

  my $department = " AND o.department_id = $department_id" if $department_id;

  my $rate = ($form->{vc} eq 'customer') ? 'buy' : 'sell';

  if ($form->{type} =~ /_quotation$/) {
    $quotation = '1';
    $ordnumber = 'quonumber';
  }

  my $number = $form->like(lc $form->{$ordnumber});
  my $name   = $form->like(lc $form->{ $form->{vc} });

  my $query = qq|SELECT o.id, o.ordnumber, o.transdate, o.reqdate,
                 o.amount, ct.name, o.netamount, o.$form->{vc}_id,
		 ex.$rate AS exchangerate,
		 o.closed, o.quonumber, o.shippingpoint, o.shipvia,
		 e.name AS employee
	         FROM oe o
	         JOIN $form->{vc} ct ON (o.$form->{vc}_id = ct.id)
	         LEFT JOIN employee e ON (o.employee_id = e.id)
	         LEFT JOIN exchangerate ex ON (ex.curr = o.curr
		                               AND ex.transdate = o.transdate)
	         WHERE o.quotation = '$quotation'
		 $department|;

  # build query if type eq (ship|receive)_order
  if ($form->{type} =~ /(ship|receive)_order/) {
    my ($warehouse, $warehouse_id) = split /--/, $form->{warehouse};

    $query = qq|SELECT DISTINCT ON (o.id) o.id, o.ordnumber, o.transdate,
                 o.reqdate, o.amount, ct.name, o.netamount, o.$form->{vc}_id,
		 ex.$rate AS exchangerate,
		 o.closed, o.quonumber, o.shippingpoint, o.shipvia,
		 e.name AS employee
	         FROM oe o
	         JOIN $form->{vc} ct ON (o.$form->{vc}_id = ct.id)
		 JOIN orderitems oi ON (oi.trans_id = o.id)
		 JOIN parts p ON (p.id = oi.parts_id)|;

    if ($warehouse_id && $form->{type} eq 'ship_order') {
      $query .= qq|
	         JOIN inventory i ON (oi.parts_id = i.parts_id)
		 |;
    }

    $query .= qq|
	         LEFT JOIN employee e ON (o.employee_id = e.id)
	         LEFT JOIN exchangerate ex ON (ex.curr = o.curr
		                               AND ex.transdate = o.transdate)
	         WHERE o.quotation = '0'
		 AND (p.inventory_accno_id > 0 OR p.assembly = '1')
		 AND oi.qty <> oi.ship
		 $department|;

    if ($warehouse_id && $form->{type} eq 'ship_order') {
      $query .= qq|
                 AND i.warehouse_id = $warehouse_id
		 AND i.qty >= (oi.qty - oi.ship)
		 |;
    }

  }

  if ($form->{"$form->{vc}_id"}) {
    $query .= qq| AND o.$form->{vc}_id = $form->{"$form->{vc}_id"}|;
  } else {
    if ($form->{ $form->{vc} }) {
      $query .= " AND lower(ct.name) LIKE '$name'";
    }
  }
  if (!$form->{open} && !$form->{closed}) {
    $query .= " AND o.id = 0";
  } elsif (!($form->{open} && $form->{closed})) {
    $query .= ($form->{open}) ? " AND o.closed = '0'" : " AND o.closed = '1'";
  }

  my $sortorder = join ', ',
    ("o.id", $form->sort_columns(transdate, $ordnumber, name));
  $sortorder = $form->{sort} if $form->{sort};

  $query .= " AND lower($ordnumber) LIKE '$number'" if $form->{$ordnumber};
  $query .= " AND o.transdate >= '$form->{transdatefrom}'"
    if $form->{transdatefrom};
  $query .= " AND o.transdate <= '$form->{transdateto}'"
    if $form->{transdateto};
  $query .= " ORDER by $sortorder";

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my %id = ();
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{exchangerate} = 1 unless $ref->{exchangerate};
    push @{ $form->{OE} }, $ref if $ref->{id} != $id{ $ref->{id} };
    $id{ $ref->{id} } = $ref->{id};
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub save {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database, turn off autocommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  my ($query, $sth, $null);
  my $exchangerate = 0;

  my $service_units = AM->retrieve_units($myconfig,$form,"service");
  my $part_units = AM->retrieve_units($myconfig,$form,"dimension");
  $form->{service_units} =$service_units;
  $form->{part_units} =$part_units;

  ($null, $form->{employee_id}) = split /--/, $form->{employee};
  unless ($form->{employee_id}) {
    $form->get_employee($dbh);
  }

  $form->{contact_id} = $form->{cp_id};
  $form->{contact_id} *= 1;
  $form->{payment_id} *= 1;
  $form->{language_id} *= 1;
  $form->{shipto_id} *= 1;
  $form->{delivery_customer_id} *= 1;
  $form->{delivery_vendor_id} *= 1;

  my $ml = ($form->{type} eq 'sales_order') ? 1 : -1;

  if ($form->{id}) {

    &adj_onhand($dbh, $form, $ml) if $form->{type} =~ /_order$/;

    $query = qq|DELETE FROM orderitems
                WHERE trans_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|DELETE FROM shipto
                WHERE trans_id = $form->{id} AND module = 'OE'|;
    $dbh->do($query) || $form->dberror($query);

  } else {

    my $uid = rand() . time;

    $uid .= $form->{login};

    $uid = substr($uid, 2, 75);

    $query = qq|INSERT INTO oe (ordnumber, employee_id)
		VALUES ('$uid', $form->{employee_id})|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|SELECT o.id FROM oe o
                WHERE o.ordnumber = '$uid'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{id}) = $sth->fetchrow_array;
    $sth->finish;
  }

  map { $form->{$_} =~ s/\'/\'\'/g }
    qw(ordnumber quonumber shippingpoint shipvia notes intnotes message);

  my $amount;
  my $linetotal;
  my $discount;
  my $project_id;
  my $reqdate;
  my $taxrate;
  my $taxamount;
  my $fxsellprice;
  my %taxbase;
  my @taxaccounts;
  my %taxaccounts;
  my $netamount = 0;

  for my $i (1 .. $form->{rowcount}) {

    map {
      $form->{"${_}_$i"} =
        $form->parse_amount($myconfig, $form->{"${_}_$i"})
    } qw(qty ship);

    if ($form->{"qty_$i"}) {

      # get item baseunit
      $query = qq|SELECT p.unit
                  FROM parts p
                  WHERE p.id = $form->{"id_$i"}|;
      $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);

      my ($item_unit) = $sth->fetchrow_array();
      $sth->finish;

      if ($form->{"inventory_accno_$i"}) {
        if (defined($part_units->{$item_unit}->{factor}) && $part_units->{$item_unit}->{factor} ne '' && $part_units->{$item_unit}->{factor} ne '0') {
          $basefactor = $part_units->{$form->{"unit_$i"}}->{factor} / $part_units->{$item_unit}->{factor};
        } else {
          $basefactor = 1;
        }
        $baseqty = $form->{"qty_$i"} * $basefactor;
      } else {
        if (defined($service_units->{$item_unit}->{factor}) && $service_units->{$item_unit}->{factor} ne '' && $service_units->{$item_unit}->{factor} ne '0') {
          $basefactor = $service_units->{$form->{"unit_$i"}}->{factor} / $service_units->{$item_unit}->{factor};
        } else {
          $basefactor = 1;
        }
        $baseqty = $form->{"qty_$i"} * $basefactor;
      }

      map { $form->{"${_}_$i"} =~ s/\'/\'\'/g }
        qw(partnumber description unit);

      # set values to 0 if nothing entered
      $form->{"discount_$i"} =
        $form->parse_amount($myconfig, $form->{"discount_$i"}) / 100;

      $form->{"sellprice_$i"} =
        $form->parse_amount($myconfig, $form->{"sellprice_$i"});
      $fxsellprice = $form->{"sellprice_$i"};

      my ($dec) = ($form->{"sellprice_$i"} =~ /\.(\d+)/);
      $dec = length $dec;
      my $decimalplaces = ($dec > 2) ? $dec : 2;

      $discount =
        $form->round_amount($form->{"sellprice_$i"} * $form->{"discount_$i"},
                            $decimalplaces);
      $form->{"sellprice_$i"} =
        $form->round_amount($form->{"sellprice_$i"} - $discount,
                            $decimalplaces);

      $form->{"inventory_accno_$i"} *= 1;
      $form->{"expense_accno_$i"}   *= 1;

      $linetotal =
        $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"}, 2);

      @taxaccounts = split / /, $form->{"taxaccounts_$i"};
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
          foreach $item (@taxaccounts) {
            $taxamount =
              $form->round_amount($linetotal * $form->{"${item}_rate"} /
                                    (1 + abs($form->{"${item}_rate"})),
                                  2);

            $taxaccounts{$item} += $taxamount;
            $taxdiff            += $taxamount;

            $taxbase{$item} += $taxbase;
          }
          $taxaccounts{ $taxaccounts[0] } += $taxdiff;
        } else {
          foreach $item (@taxaccounts) {
            $taxaccounts{$item} += $linetotal * $form->{"${item}_rate"};
            $taxbase{$item}     += $taxbase;
          }
        }
      } else {
        foreach $item (@taxaccounts) {
          $taxaccounts{$item} +=
            $taxamount * $form->{"${item}_rate"} / $taxrate;
          $taxbase{$item} += $taxbase;
        }
      }

      $netamount += $form->{"sellprice_$i"} * $form->{"qty_$i"};

      $project_id = 'NULL';
      if ($form->{"projectnumber_$i"}) {
        $project_id = $form->{"projectnumber_$i"};
      }
      $reqdate =
        ($form->{"reqdate_$i"}) ? qq|'$form->{"reqdate_$i"}'| : "NULL";

      # get pricegroup_id and save ist
      ($null, my $pricegroup_id) = split /--/, $form->{"sellprice_pg_$i"};
      $pricegroup_id *= 1;
      $subtotal = $form->{"subtotal_$i"} * 1;

      # save detail record in orderitems table
      $query = qq|INSERT INTO orderitems (|;
      $query .= "id, " if $form->{"orderitems_id_$i"};
      $query .= qq|trans_id, parts_id, description, longdescription, qty, base_qty, sellprice, discount,
		   unit, reqdate, project_id, serialnumber, ship, pricegroup_id,
		   ordnumber, transdate, cusordnumber, subtotal)
                   VALUES (|;
      $query .= qq|$form->{"orderitems_id_$i"},|
        if $form->{"orderitems_id_$i"};
      $query .= qq|$form->{id}, $form->{"id_$i"},
		   '$form->{"description_$i"}', '$form->{"longdescription_$i"}', $form->{"qty_$i"}, $baseqty,
		   $fxsellprice, $form->{"discount_$i"},
		   '$form->{"unit_$i"}', $reqdate, (SELECT id from project where projectnumber = '$project_id'),
		   '$form->{"serialnumber_$i"}', $form->{"ship_$i"}, '$pricegroup_id',
		   '$form->{"ordnumber_$i"}', '$form->{"transdate_$i"}', '$form->{"cusordnumber_$i"}', '$subtotal')|;
      $dbh->do($query) || $form->dberror($query);

      $form->{"sellprice_$i"} = $fxsellprice;
      $form->{"discount_$i"} *= 100;
    }
  }

  # set values which could be empty
  map { $form->{$_} *= 1 }
    qw(vendor_id customer_id taxincluded closed quotation);

  $reqdate = ($form->{reqdate}) ? qq|'$form->{reqdate}'| : "NULL";

  # add up the tax
  my $tax = 0;
  map { $tax += $form->round_amount($taxaccounts{$_}, 2) } keys %taxaccounts;

  $amount = $form->round_amount($netamount + $tax, 2);
  $netamount = $form->round_amount($netamount, 2);

  if ($form->{currency} eq $form->{defaultcurrency}) {
    $form->{exchangerate} = 1;
  } else {
    $exchangerate =
      $form->check_exchangerate($myconfig,
                                $form->{currency},
                                $form->{transdate},
                                ($form->{vc} eq 'customer') ? 'buy' : 'sell');
  }

  $form->{exchangerate} =
    ($exchangerate)
    ? $exchangerate
    : $form->parse_amount($myconfig, $form->{exchangerate});

  my $quotation;

  # fill in subject if there is none
  if ($form->{type} =~ /_order$/) {
    $quotation = '0';
    $form->{subject} = qq|$form->{label} $form->{ordnumber}|
      unless $form->{subject};
  } else {
    $quotation = '1';
    $form->{subject} = qq|$form->{label} $form->{quonumber}|
      unless $form->{subject};
  }

  # if there is a message stuff it into the intnotes
  my $cc  = "Cc: $form->{cc}\\r\n"   if $form->{cc};
  my $bcc = "Bcc: $form->{bcc}\\r\n" if $form->{bcc};
  my $now = scalar localtime;
  $form->{intnotes} .= qq|\r
\r| if $form->{intnotes};

  $form->{intnotes} .= qq|[email]\r
Date: $now
To: $form->{email}\r
$cc${bcc}Subject: $form->{subject}\r
\r
Message: $form->{message}\r| if $form->{message};

  ($null, $form->{department_id}) = split(/--/, $form->{department});
  $form->{department_id} *= 1;
  $form->{payment_id} *= 1;
  $form->{language_id} *= 1;
  $form->{taxzone_id} *= 1;
  $form->{proforma} *= 1;



  # save OE record
  $query = qq|UPDATE oe set
	      ordnumber = '$form->{ordnumber}',
	      quonumber = '$form->{quonumber}',
              cusordnumber = '$form->{cusordnumber}',
              transdate = '$form->{transdate}',
              vendor_id = $form->{vendor_id},
	      customer_id = $form->{customer_id},
              amount = $amount,
              netamount = $netamount,
	      reqdate = $reqdate,
	      taxincluded = '$form->{taxincluded}',
	      shippingpoint = '$form->{shippingpoint}',
	      shipvia = '$form->{shipvia}',
	      notes = '$form->{notes}',
	      intnotes = '$form->{intnotes}',
	      curr = '$form->{currency}',
	      closed = '$form->{closed}',
	      proforma = '$form->{proforma}',
	      quotation = '$quotation',
	      department_id = $form->{department_id},
	      language_id = $form->{language_id},
	      taxzone_id = $form->{taxzone_id},
	      shipto_id = $form->{shipto_id},
	      payment_id = $form->{payment_id},
	      delivery_vendor_id = $form->{delivery_vendor_id},
	      delivery_customer_id = $form->{delivery_customer_id},
	      employee_id = $form->{employee_id},
              cp_id = $form->{contact_id}
              WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $form->{ordtotal} = $amount;

  if ($form->{webdav}) {
    &webdav_folder($myconfig, $form);
  }

  # add shipto
  $form->{name} = $form->{ $form->{vc} };
  $form->{name} =~ s/--$form->{"$form->{vc}_id"}//;

  if (!$form->{shipto_id}) {
    $form->add_shipto($dbh, $form->{id}, "OE");
  }

  # save printed, emailed, queued
  $form->save_status($dbh);

  if (($form->{currency} ne $form->{defaultcurrency}) && !$exchangerate) {
    if ($form->{vc} eq 'customer') {
      $form->update_exchangerate($dbh, $form->{currency}, $form->{transdate},
                                 $form->{exchangerate}, 0);
    }
    if ($form->{vc} eq 'vendor') {
      $form->update_exchangerate($dbh, $form->{currency}, $form->{transdate},
                                 0, $form->{exchangerate});
    }
  }

  if ($form->{type} =~ /_order$/) {

    # adjust onhand
    &adj_onhand($dbh, $form, $ml * -1);
    &adj_inventory($dbh, $myconfig, $form);
  }

  my $rc = $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $rc;
}

# this function closes multiple orders given in $form->{ordnumber_#}.
# use this for multiple orders that don't have to be saved back
# single orders should use OE::save instead.
sub close_orders {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  for my $i (1 .. $form->{rowcount}) {

    map {
      $form->{"${_}_$i"} =
        $form->parse_amount($myconfig, $form->{"${_}_$i"})
    } qw(qty ship);
    if ($delete_oe_id) {
      $form->{"orderitems_id_$i"} = "";
    }

    if ($form->{"qty_$i"}) {

      # set values to 0 if nothing entered
      $form->{"discount_$i"} =
        $form->parse_amount($myconfig, $form->{"discount_$i"});

      $form->{"sellprice_$i"} =
        $form->parse_amount($myconfig, $form->{"sellprice_$i"});
    }
  }

  # get ids from $form
  map { push @ids, $form->{"ordnumber_$_"} if $form->{"ordnumber_$_"} }
    (1 .. $form->{rowcount});

  my $dbh = $form->dbconnect($myconfig);
  $query = qq|UPDATE oe SET
              closed = TRUE
              WHERE ordnumber IN (|
    . join(', ', map { $dbh->quote($_) } @ids) . qq|)|;
  $dbh->do($query) || $form->dberror($query);
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub close_order {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  $main::lxdebug->leave_sub() unless ($form->{"id"});

  my $dbh = $form->dbconnect($myconfig);
  do_query($form, $dbh, qq|UPDATE oe SET closed = TRUE where ordnumber = ?|,
           $form->{"id"});
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub delete {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $spool) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  # delete spool files
  my $query = qq|SELECT s.spoolfile FROM status s
                 WHERE s.trans_id = $form->{id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  my $spoolfile;
  my @spoolfiles = ();

  while (($spoolfile) = $sth->fetchrow_array) {
    push @spoolfiles, $spoolfile;
  }
  $sth->finish;

  $query = qq|SELECT o.parts_id, o.ship FROM orderitems o
              WHERE o.trans_id = $form->{id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  while (my ($id, $ship) = $sth->fetchrow_array) {
    $form->update_balance($dbh, "parts", "onhand", qq|id = $id|, $ship * -1);
  }
  $sth->finish;

  # delete inventory
  $query = qq|DELETE FROM inventory
              WHERE oe_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # delete status entries
  $query = qq|DELETE FROM status
              WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # delete OE record
  $query = qq|DELETE FROM oe
              WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # delete individual entries
  $query = qq|DELETE FROM orderitems
              WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $query = qq|DELETE FROM shipto
              WHERE trans_id = $form->{id} AND module = 'OE'|;
  $dbh->do($query) || $form->dberror($query);

  my $rc = $dbh->commit;
  $dbh->disconnect;

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

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query, @ids;

  # translate the ids (given by id_# and trans_id_#) into one array of ids, so we can join them later
  map {
    push @ids, $form->{"trans_id_$_"}
      if ($form->{"id_$_"} and $form->{"trans_id_$_"})
  } (1 .. $form->{"rowcount"});

  # if called in multi id mode, and still only got one id, switch back to single id
  if ($form->{"rowcount"} and $#ids == 0) {
    $form->{"id"} = $ids[0];
    undef @ids;
  }

  if ($form->{id}) {

    # get default accounts and last order number
    $query = qq|SELECT (SELECT c.accno FROM chart c
                        WHERE d.inventory_accno_id = c.id) AS inventory_accno,
                       (SELECT c.accno FROM chart c
		        WHERE d.income_accno_id = c.id) AS income_accno,
                       (SELECT c.accno FROM chart c
		        WHERE d.expense_accno_id = c.id) AS expense_accno,
                       (SELECT c.accno FROM chart c
		        WHERE d.fxgain_accno_id = c.id) AS fxgain_accno,
                       (SELECT c.accno FROM chart c
		        WHERE d.fxloss_accno_id = c.id) AS fxloss_accno,
                d.curr AS currencies
	 	FROM defaults d|;
  } else {
    $query = qq|SELECT (SELECT c.accno FROM chart c
                        WHERE d.inventory_accno_id = c.id) AS inventory_accno,
                       (SELECT c.accno FROM chart c
		        WHERE d.income_accno_id = c.id) AS income_accno,
                       (SELECT c.accno FROM chart c
		        WHERE d.expense_accno_id = c.id) AS expense_accno,
                       (SELECT c.accno FROM chart c
		        WHERE d.fxgain_accno_id = c.id) AS fxgain_accno,
                       (SELECT c.accno FROM chart c
		        WHERE d.fxloss_accno_id = c.id) AS fxloss_accno,
                d.curr AS currencies,
		current_date AS transdate, current_date AS reqdate
	 	FROM defaults d|;
  }
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);
  map { $form->{$_} = $ref->{$_} } keys %$ref;
  $sth->finish;

  ($form->{currency}) = split /:/, $form->{currencies};

  # set reqdate if this is an invoice->order conversion. If someone knows a better check to ensure
  # we come from invoices, feel free.
  $form->{reqdate} = $form->{deliverydate}
    if (    $form->{deliverydate}
        and $form->{callback} =~ /action=ar_transactions/);

  if ($form->{id} or @ids) {

    # retrieve order for single id
    # NOTE: this query is intended to fetch all information only ONCE.
    # so if any of these infos is important (or even different) for any item,
    # it will be killed out and then has to be fetched from the item scope query further down
    $query = qq|SELECT o.cp_id, o.ordnumber, o.transdate, o.reqdate,
                o.taxincluded, o.shippingpoint, o.shipvia, o.notes, o.intnotes,
		o.curr AS currency, e.name AS employee, o.employee_id,
		o.$form->{vc}_id, cv.name AS $form->{vc}, o.amount AS invtotal,
		o.closed, o.reqdate, o.quonumber, o.department_id, o.cusordnumber,
		d.description AS department, o.payment_id, o.language_id, o.taxzone_id, o.delivery_customer_id, o.delivery_vendor_id, o.proforma, o.shipto_id
		FROM oe o
	        JOIN $form->{vc} cv ON (o.$form->{vc}_id = cv.id)
	        LEFT JOIN employee e ON (o.employee_id = e.id)
	        LEFT JOIN department d ON (o.department_id = d.id)
		|
      . ($form->{id}
         ? qq|WHERE o.id = $form->{id}|
         : qq|WHERE o.id IN (| . join(', ', @ids) . qq|)|);

    #$main::lxdebug->message(0, $query);

    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    map { $form->{$_} = $ref->{$_} } keys %$ref;



    # set all entries for multiple ids blank that yield different information
    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      map { $form->{$_} = '' if ($ref->{$_} ne $form->{$_}) } keys %$ref;
    }

    # if not given, fill transdate with current_date
    $form->{transdate} = $form->current_date($myconfig)
      unless $form->{transdate};

    $sth->finish;

    if ($form->{delivery_customer_id}) {
      $query = qq|SELECT name FROM customer WHERE id=$form->{delivery_customer_id}|;
      $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);
      ($form->{delivery_customer_string}) = $sth->fetchrow_array();
      $sth->finish;
    }

    if ($form->{delivery_vendor_id}) {
      $query = qq|SELECT name FROM customer WHERE id=$form->{delivery_vendor_id}|;
      $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);
      ($form->{delivery_vendor_string}) = $sth->fetchrow_array();
      $sth->finish;
    }

    # shipto and pinted/mailed/queued status makes only sense for single id retrieve
    if (!@ids) {
      $query = qq|SELECT s.* FROM shipto s
                  WHERE s.trans_id = $form->{id} AND s.module = 'OE'|;
      $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);

      $ref = $sth->fetchrow_hashref(NAME_lc);
      delete($ref->{id});
      map { $form->{$_} = $ref->{$_} } keys %$ref;
      $sth->finish;

      # get printed, emailed and queued
      $query = qq|SELECT s.printed, s.emailed, s.spoolfile, s.formname
                  FROM status s
                  WHERE s.trans_id = $form->{id}|;
      $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);

      while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
        $form->{printed} .= "$ref->{formname} " if $ref->{printed};
        $form->{emailed} .= "$ref->{formname} " if $ref->{emailed};
        $form->{queued} .= "$ref->{formname} $ref->{spoolfile} "
          if $ref->{spoolfile};
      }
      $sth->finish;
      map { $form->{$_} =~ s/ +$//g } qw(printed emailed queued);
    }    # if !@ids

    my %oid = ('Pg'     => 'oid',
               'Oracle' => 'rowid');

    my $transdate =
      $form->{transdate} ? $dbh->quote($form->{transdate}) : "current_date";

    if(!$form->{taxzone_id}) {
      $form->{taxzone_id} = 0;
    }
    # retrieve individual items
    # this query looks up all information about the items
    # stuff different from the whole will not be overwritten, but saved with a suffix.
    $query = qq|SELECT o.id AS orderitems_id,
                c1.accno AS inventory_accno, c1.new_chart_id AS inventory_new_chart, date($transdate) - c1.valid_from as inventory_valid,
	        c2.accno AS income_accno, c2.new_chart_id AS income_new_chart, date($transdate)  - c2.valid_from as income_valid,
		c3.accno AS expense_accno, c3.new_chart_id AS expense_new_chart, date($transdate) - c3.valid_from as expense_valid,
		oe.ordnumber AS ordnumber_oe, oe.transdate AS transdate_oe, oe.cusordnumber AS cusordnumber_oe, 
                p.partnumber, p.assembly, o.description, o.qty,
		o.sellprice, o.parts_id AS id, o.unit, o.discount, p.bin, p.notes AS partnotes, p.inventory_accno_id AS part_inventory_accno_id,
                o.reqdate, o.project_id, o.serialnumber, o.ship,
		o.ordnumber, o.transdate, o.cusordnumber, o.subtotal, o.longdescription,
		pr.projectnumber, p.formel,
		pg.partsgroup, o.pricegroup_id, (SELECT pricegroup FROM pricegroup WHERE id=o.pricegroup_id) as pricegroup
		FROM orderitems o
		JOIN parts p ON (o.parts_id = p.id)
		JOIN oe ON (o.trans_id = oe.id)
		LEFT JOIN chart c1 ON ((select inventory_accno_id from buchungsgruppen where id=p.buchungsgruppen_id) = c1.id)
		LEFT JOIN chart c2 ON ((select income_accno_id_$form->{taxzone_id} from buchungsgruppen where id=p.buchungsgruppen_id) = c2.id)
		LEFT JOIN chart c3 ON ((select expense_accno_id_$form->{taxzone_id} from buchungsgruppen where id=p.buchungsgruppen_id) = c3.id)
		LEFT JOIN project pr ON (o.project_id = pr.id)
		LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		|
      . ($form->{id}
         ? qq|WHERE o.trans_id = $form->{id}|
         : qq|WHERE o.trans_id IN (| . join(", ", @ids) . qq|)|)
      . qq|
                ORDER BY o.$oid{$myconfig->{dbdriver}}|;

    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      if (!$ref->{"part_inventory_accno_id"}) {
        map({ delete($ref->{$_}); } qw(inventory_accno inventory_new_chart inventory_valid));
      }
      delete($ref->{"part_inventory_accno_id"});

      # in collective order, copy global ordnumber, transdate, cusordnumber into item scope
      #   unless already present there
      # remove _oe entries afterwards
      map { $ref->{$_} = $ref->{"${_}_oe"} if ($ref->{$_} eq '') }
        qw|ordnumber transdate cusordnumber|
        if (@ids);
      map { delete $ref->{$_} } qw|ordnumber_oe transdate_oe cusordnumber_oe|;



    while ($ref->{inventory_new_chart} && ($ref->{inventory_valid} >=0)) {
      my $query = qq| SELECT accno AS inventory_accno, new_chart_id AS inventory_new_chart, date($transdate) - valid_from AS inventory_valid FROM chart WHERE id = $ref->{inventory_new_chart}|;
      my $stw = $dbh->prepare($query);
      $stw->execute || $form->dberror($query);
      ($ref->{inventory_accno}, $ref->{inventory_new_chart}, $ref->{inventory_valid}) = $stw->fetchrow_array;
      $stw->finish;
    }

    while ($ref->{income_new_chart} && ($ref->{income_valid} >=0)) {
      my $query = qq| SELECT accno AS income_accno, new_chart_id AS income_new_chart, date($transdate) - valid_from AS income_valid FROM chart WHERE id = $ref->{income_new_chart}|;
      my $stw = $dbh->prepare($query);
      $stw->execute || $form->dberror($query);
      ($ref->{income_accno}, $ref->{income_new_chart}, $ref->{income_valid}) = $stw->fetchrow_array;
      $stw->finish;
    }

    while ($ref->{expense_new_chart} && ($ref->{expense_valid} >=0)) {
      my $query = qq| SELECT accno AS expense_accno, new_chart_id AS expense_new_chart, date($transdate) - valid_from AS expense_valid FROM chart WHERE id = $ref->{expense_new_chart}|;
      my $stw = $dbh->prepare($query);
      $stw->execute || $form->dberror($query);
      ($ref->{expense_accno}, $ref->{expense_new_chart}, $ref->{expense_valid}) = $stw->fetchrow_array;
      $stw->finish;
    }

      # delete orderitems_id in collective orders, so that they get cloned no matter what
      delete $ref->{orderitems_id} if (@ids);

      # get tax rates and description
      $accno_id =
        ($form->{vc} eq "customer") ? $ref->{income_accno} : $ref->{expense_accno};
      $query = qq|SELECT c.accno, t.taxdescription, t.rate, t.taxnumber
	      FROM tax t LEFT JOIN chart c on (c.id=t.chart_id)
	      WHERE t.id in (SELECT tk.tax_id from taxkeys tk where tk.chart_id = (SELECT id from chart WHERE accno='$accno_id') AND startdate<=$transdate ORDER BY startdate desc LIMIT 1)
	      ORDER BY c.accno|;
      $stw = $dbh->prepare($query);
      $stw->execute || $form->dberror($query);
      $ref->{taxaccounts} = "";
      my $i = 0;
      while ($ptr = $stw->fetchrow_hashref(NAME_lc)) {

        #    if ($customertax{$ref->{accno}}) {
        if (($ptr->{accno} eq "") && ($ptr->{rate} == 0)) {
          $i++;
          $ptr->{accno} = $i;
        }
        $ref->{taxaccounts} .= "$ptr->{accno} ";
        if (!($form->{taxaccounts} =~ /$ptr->{accno}/)) {
          $form->{"$ptr->{accno}_rate"}        = $ptr->{rate};
          $form->{"$ptr->{accno}_description"} = $ptr->{taxdescription};
          $form->{"$ptr->{accno}_taxnumber"}   = $ptr->{taxnumber};
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

  $form->{exchangerate} =
    $form->get_exchangerate($dbh, $form->{currency}, $form->{transdate},
                            ($form->{vc} eq 'customer') ? "buy" : "sell");

  if ($form->{webdav}) {
    &webdav_folder($myconfig, $form);
  }

  # get tax zones
  $query = qq|SELECT id, description
              FROM tax_zones|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);


  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{TAXZONE} }, $ref;
  }
  $sth->finish;


  my $rc = $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $rc;
}

sub order_details {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  my $query;
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

  my %oid = ('Pg'     => 'oid',
             'Oracle' => 'rowid');

  # sort items by partsgroup
  for $i (1 .. $form->{rowcount}) {
    $partsgroup = "";
    if ($form->{"partsgroup_$i"} && $form->{groupitems}) {
      $partsgroup = $form->{"partsgroup_$i"};
    }
    push @partsgroup, [$i, $partsgroup];
  }

  # if there is a warehouse limit picking
  if ($form->{warehouse_id} && $form->{formname} =~ /(pick|packing)_list/) {

    # run query to check for inventory
    $query = qq|SELECT sum(i.qty) AS qty
                FROM inventory i
		WHERE i.parts_id = ?
		AND i.warehouse_id = ?|;
    $sth = $dbh->prepare($query) || $form->dberror($query);

    for $i (1 .. $form->{rowcount}) {
      $sth->execute($form->{"id_$i"}, $form->{warehouse_id}) || $form->dberror;

      ($qty) = $sth->fetchrow_array;
      $sth->finish;

      $form->{"qty_$i"} = 0 if $qty == 0;

      if ($form->parse_amount($myconfig, $form->{"ship_$i"}) > $qty) {
        $form->{"ship_$i"} = $form->format_amount($myconfig, $qty);
      }
    }
  }

  my $sameitem = "";
  foreach $item (sort { $a->[1] cmp $b->[1] } @partsgroup) {
    $i = $item->[0];

    if ($item->[1] ne $sameitem) {
      push(@{ $form->{description} }, qq|$item->[1]|);
      $sameitem = $item->[1];

      map { push(@{ $form->{$_} }, "") }
        qw(runningnumber number qty ship unit bin partnotes
           serialnumber reqdate sellprice listprice netprice
           discount p_discount linetotal);
    }

    $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});

    if ($form->{"qty_$i"} != 0) {

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

      push(@{ $form->{runningnumber} }, $i);
      push(@{ $form->{number} },        qq|$form->{"partnumber_$i"}|);
      push(@{ $form->{description} },   qq|$form->{"description_$i"}|);
      push(@{ $form->{longdescription} },   qq|$form->{"longdescription_$i"}|);
      push(@{ $form->{qty} },
           $form->format_amount($myconfig, $form->{"qty_$i"}));
      push(@{ $form->{ship} },
           $form->format_amount($myconfig, $form->{"ship_$i"}));
      push(@{ $form->{unit} },         qq|$form->{"unit_$i"}|);
      push(@{ $form->{bin} },          qq|$form->{"bin_$i"}|);
      push(@{ $form->{"partnotes"} },  qq|$form->{"partnotes_$i"}|);
      push(@{ $form->{serialnumber} }, qq|$form->{"serialnumber_$i"}|);
      push(@{ $form->{reqdate} },      qq|$form->{"reqdate_$i"}|);

      push(@{ $form->{sellprice} }, $form->{"sellprice_$i"});

      push(@{ $form->{listprice} }, $form->{"listprice_$i"});

      my $sellprice = $form->parse_amount($myconfig, $form->{"sellprice_$i"});
      my ($dec) = ($sellprice =~ /\.(\d+)/);
      $dec = length $dec;
      my $decimalplaces = ($dec > 2) ? $dec : 2;

      my $i_discount =
        $form->round_amount(
                            $sellprice * $form->parse_amount($myconfig,
                                                 $form->{"discount_$i"}) / 100,
                            $decimalplaces);

      my $discount =
        $form->round_amount($form->{"qty_$i"} * $i_discount, $decimalplaces);

      # keep a netprice as well, (sellprice - discount)
      #$form->{"netprice_$i"} = $sellprice - $discount;
      $form->{"netprice_$i"} = $sellprice - $i_discount;
      my $nodiscount_linetotal =
        $form->round_amount($form->{"qty_$i"} * $sellprice, 2);
      my $linetotal =
        $form->round_amount($form->{"qty_$i"} * $form->{"netprice_$i"}, 2);

      push(@{ $form->{netprice} },
           ($form->{"netprice_$i"} != 0)
           ? $form->format_amount(
                                 $myconfig, $form->{"netprice_$i"},
                                 $decimalplaces
             )
           : " ");

      $discount =
        ($discount != 0)
        ? $form->format_amount($myconfig, $discount * -1, $decimalplaces)
        : " ";
      $linetotal = ($linetotal != 0) ? $linetotal : " ";

      push(@{ $form->{discount} },   $discount);
      push(@{ $form->{p_discount} }, $form->{"discount_$i"});

      $form->{ordtotal} += $linetotal;
     $discount_subtotal += $linetotal;
      $form->{nodiscount_total} += $nodiscount_linetotal;
      $nodiscount_subtotal += $nodiscount_linetotal;
      $form->{discount_total} += $form->parse_amount($myconfig, $discount);

      if ($form->{"subtotal_$i"} && $subtotal_header && ($subtotal_header != $i)) {
        $discount_subtotal = $form->format_amount($myconfig, $discount_subtotal, 2);
        push(@{ $form->{discount_sub} },  $discount_subtotal);
        $nodiscount_subtotal = $form->format_amount($myconfig, $nodiscount_subtotal, 2);
        push(@{ $form->{nodiscount_sub} }, $nodiscount_subtotal);
        $discount_subtotal = 0;
        $nodiscount_subtotal = 0;
        $subtotal_header = 0;
      } else {
        push(@{ $form->{discount_sub} }, "");
        push(@{ $form->{nodiscount_sub} }, "");
      }

      if ($linetotal == $netto_linetotal) {
        $nodiscount += $linetotal;
      }
      push(@{ $form->{linetotal} },
           $form->format_amount($myconfig, $linetotal, 2));
      push(@{ $form->{nodiscount_linetotal} },
           $form->format_amount($myconfig, $nodiscount_linetotal, 2));

      my ($taxamount, $taxbase);
      my $taxrate = 0;

      map { $taxrate += $form->{"${_}_rate"} } split / /,
        $form->{"taxaccounts_$i"};

      if ($form->{taxincluded}) {

        # calculate tax
        $taxamount = $linetotal * $taxrate / (1 + $taxrate);
        $taxbase = $linetotal / (1 + $taxrate);
      } else {
        $taxamount = $linetotal * $taxrate;
        $taxbase   = $linetotal;
      }

      if ($taxamount != 0) {
        foreach my $item (split / /, $form->{"taxaccounts_$i"}) {
          $taxaccounts{$item} +=
            $taxamount * $form->{"${item}_rate"} / $taxrate;
          $taxbase{$item} += $taxbase;
        }
      }

      $tax_rate = $taxrate * 100;
      push(@{ $form->{tax_rate} }, qq|$tax_rate|);

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

        $query = qq|SELECT p.partnumber, p.description, p.unit, a.qty,
	            pg.partsgroup
	            FROM assembly a
		    JOIN parts p ON (a.parts_id = p.id)
		    LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		    WHERE a.bom = '1'
		    AND a.id = '$form->{"id_$i"}'
		    $sortorder|;
        $sth = $dbh->prepare($query);
        $sth->execute || $form->dberror($query);

        while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
          if ($form->{groupitems} && $ref->{partsgroup} ne $sameitem) {
            map { push(@{ $form->{$_} }, "") }
              qw(runningnumber ship bin serialnumber number unit bin qty reqdate sellprice listprice netprice discount linetotal nodiscount_linetotal);
            $sameitem = ($ref->{partsgroup}) ? $ref->{partsgroup} : "--";
            push(@{ $form->{description} }, $sameitem);
          }

          push(@{ $form->{description} },
               $form->format_amount($myconfig, $ref->{qty} * $form->{"qty_$i"}
                 )
                 . qq|, $ref->{partnumber}, $ref->{description}|);

          map { push(@{ $form->{$_} }, "") }
            qw(number unit qty runningnumber ship bin serialnumber reqdate sellprice listprice netprice discount linetotal nodiscount_linetotal);

        }
        $sth->finish;
      }

    }
  }

  my $tax = 0;
  foreach $item (sort keys %taxaccounts) {
      push(@{ $form->{taxbase} },
           $form->format_amount($myconfig, $taxbase{$item}, 2));

      $tax += $taxamount = $form->round_amount($taxaccounts{$item}, 2);

      push(@{ $form->{tax} }, $form->format_amount($myconfig, $taxamount, 2));
      push(@{ $form->{taxdescription} }, $form->{"${item}_description"});
      push(@{ $form->{taxrate} },
           $form->format_amount($myconfig, $form->{"${item}_rate"} * 100));
      push(@{ $form->{taxnumber} }, $form->{"${item}_taxnumber"});
  }
  $form->{subtotal} = $form->format_amount($myconfig, $form->{total}, 2);
  $yesdiscount = $form->{nodiscount_total} - $nodiscount;
  $form->{nodiscount_subtotal} = $form->format_amount($myconfig, $form->{nodiscount_total}, 2);
  $form->{discount_total} = $form->format_amount($myconfig, $form->{discount_total}, 2);
  $form->{nodiscount} = $form->format_amount($myconfig, $nodiscount, 2);
  $form->{yesdiscount} = $form->format_amount($myconfig, $yesdiscount, 2);

  $form->{subtotal} = $form->format_amount($myconfig, $form->{ordtotal}, 2);
  $form->{ordtotal} =
    ($form->{taxincluded}) ? $form->{ordtotal} : $form->{ordtotal} + $tax;

  # format amounts
  $form->{quototal} = $form->{ordtotal} =
    $form->format_amount($myconfig, $form->{ordtotal}, 2);

  if ($form->{type} =~ /_quotation/) {
    $form->set_payment_options($myconfig, $form->{quodate});
  } else {
    $form->set_payment_options($myconfig, $form->{orddate});
  }

  # myconfig variables
  map { $form->{$_} = $myconfig->{$_} }
    (qw(company address tel fax signature businessnumber));
  $form->{username} = $myconfig->{name};

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub project_description {
  $main::lxdebug->enter_sub();

  my ($self, $dbh, $id) = @_;

  my $query = qq|SELECT p.description
                 FROM project p
		 WHERE p.id = $id|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  ($_) = $sth->fetchrow_array;

  $sth->finish;

  $main::lxdebug->leave_sub();

  return $_;
}

sub get_warehouses {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect($myconfig);

  # setup warehouses
  my $query = qq|SELECT id, description
                 FROM warehouse|;

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{all_warehouses} }, $ref;
  }
  $sth->finish;

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub save_inventory {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my ($null, $warehouse_id) = split /--/, $form->{warehouse};
  $warehouse_id *= 1;

  my $employee_id;
  ($null, $employee_id) = split /--/, $form->{employee};

  my $ml = ($form->{type} eq 'ship_order') ? -1 : 1;

  my $dbh = $form->dbconnect_noauto($myconfig);
  my $sth;
  my $wth;
  my $serialnumber;
  my $ship;

  $query = qq|SELECT o.serialnumber, o.ship
              FROM orderitems o
              WHERE o.trans_id = ?
	      AND o.id = ?
	      FOR UPDATE|;
  $sth = $dbh->prepare($query) || $form->dberror($query);

  $query = qq|SELECT sum(i.qty)
              FROM inventory i
	      WHERE i.parts_id = ?
	      AND i.warehouse_id = ?|;
  $wth = $dbh->prepare($query) || $form->dberror($query);

  for my $i (1 .. $form->{rowcount} - 1) {

    $ship =
      (abs($form->{"ship_$i"}) > abs($form->{"qty_$i"}))
      ? $form->{"qty_$i"}
      : $form->{"ship_$i"};

    if ($warehouse_id && $form->{type} eq 'ship_order') {

      $wth->execute($form->{"id_$i"}, $warehouse_id) || $form->dberror;

      ($qty) = $wth->fetchrow_array;
      $wth->finish;

      if ($ship > $qty) {
        $ship = $qty;
      }
    }

    if ($ship != 0) {

      $ship *= $ml;
      $query = qq|INSERT INTO inventory (parts_id, warehouse_id,
                  qty, oe_id, orderitems_id, shippingdate, employee_id)
                  VALUES ($form->{"id_$i"}, $warehouse_id,
		  $ship, $form->{"id"},
		  $form->{"orderitems_id_$i"}, '$form->{shippingdate}',
		  $employee_id)|;
      $dbh->do($query) || $form->dberror($query);

      # add serialnumber, ship to orderitems
      $sth->execute($form->{id}, $form->{"orderitems_id_$i"})
        || $form->dberror;
      ($serialnumber, $ship) = $sth->fetchrow_array;
      $sth->finish;

      $serialnumber .= " " if $serialnumber;
      $serialnumber .= qq|$form->{"serialnumber_$i"}|;
      $ship += $form->{"ship_$i"};

      $query = qq|UPDATE orderitems SET
                  serialnumber = '$serialnumber',
		  ship = $ship
		  WHERE trans_id = $form->{id}
		  AND id = $form->{"orderitems_id_$i"}|;
      $dbh->do($query) || $form->dberror($query);

      # update order with ship via
      $query = qq|UPDATE oe SET
                  shippingpoint = '$form->{shippingpoint}',
                  shipvia = '$form->{shipvia}'
		  WHERE id = $form->{id}|;
      $dbh->do($query) || $form->dberror($query);

      # update onhand for parts
      $form->update_balance($dbh, "parts", "onhand",
                            qq|id = $form->{"id_$i"}|,
                            $form->{"ship_$i"} * $ml);

    }
  }

  my $rc = $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $rc;
}

sub adj_onhand {
  $main::lxdebug->enter_sub();

  my ($dbh, $form, $ml) = @_;

  my $service_units = $form->{service_units};
  my $part_units = $form->{part_units};

  my $query = qq|SELECT oi.parts_id, oi.ship, oi.unit, p.inventory_accno_id, p.assembly
                 FROM orderitems oi
		 JOIN parts p ON (p.id = oi.parts_id)
                 WHERE oi.trans_id = $form->{id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $query = qq|SELECT sum(p.inventory_accno_id)
	      FROM parts p
	      JOIN assembly a ON (a.parts_id = p.id)
	      WHERE a.id = ?|;
  my $ath = $dbh->prepare($query) || $form->dberror($query);

  my $ispa;

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
  #print(STDERR "Bin in Schleife $ref->{inventory_accno_id}\n");

    if ($ref->{inventory_accno_id} || $ref->{assembly}) {

      # do not update if assembly consists of all services
      if ($ref->{assembly}) {
        $ath->execute($ref->{parts_id}) || $form->dberror($query);

        ($ispa) = $sth->fetchrow_array;
        $ath->finish;

        next unless $ispa;

      }

      # get item baseunit
      $query = qq|SELECT p.unit
                  FROM parts p
                  WHERE p.id = $ref->{parts_id}|;
      my $stw = $dbh->prepare($query);
      $stw->execute || $form->dberror($query);

      my ($item_unit) = $stw->fetchrow_array();
      $stw->finish;

      if ($ref->{inventory_accno_id}) {        
        if (defined($part_units->{$item_unit}->{factor}) && $part_units->{$item_unit}->{factor} ne '' && $part_units->{$item_unit}->{factor} ne '0') {
          $basefactor = $part_units->{$ref->{unit}}->{factor} / $part_units->{$item_unit}->{factor};
        } else {
          $basefactor = 1;
        }
        $baseqty = $ref->{ship} * $basefactor;
      } else {
        if (defined($service_units->{$item_unit}->{factor}) && $service_units->{$item_unit}->{factor} ne '' && $service_units->{$item_unit}->{factor} ne '0') {
          $basefactor = $service_units->{$ref->{unit}}->{factor} / $part_units->{$item_unit}->{factor};
        } else {
          $basefactor = 1;
        }
        $baseqty = $ref->{ship} * $basefactor;
      }  
      #print(STDERR "$baseqty Basismenge\n");

      # adjust onhand in parts table
      $form->update_balance($dbh, "parts", "onhand",
                            qq|id = $ref->{parts_id}|,
                            $baseqty * $ml);
    }
  }

  $sth->finish;

  $main::lxdebug->leave_sub();
}

sub adj_inventory {
  $main::lxdebug->enter_sub();

  my ($dbh, $myconfig, $form) = @_;

  my %oid = ('Pg'     => 'oid',
             'Oracle' => 'rowid');

  # increase/reduce qty in inventory table
  my $query = qq|SELECT oi.id, oi.parts_id, oi.ship
                 FROM orderitems oi
                 WHERE oi.trans_id = $form->{id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $query = qq|SELECT $oid{$myconfig->{dbdriver}} AS oid, qty,
                     (SELECT SUM(qty) FROM inventory
                      WHERE oe_id = $form->{id}
		      AND orderitems_id = ?) AS total
	      FROM inventory
              WHERE oe_id = $form->{id}
	      AND orderitems_id = ?|;
  my $ith = $dbh->prepare($query) || $form->dberror($query);

  my $qty;
  my $ml = ($form->{type} =~ /(ship|sales)_order/) ? -1 : 1;

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {

    $ith->execute($ref->{id}, $ref->{id}) || $form->dberror($query);

    while (my $inv = $ith->fetchrow_hashref(NAME_lc)) {

      if (($qty = (($inv->{total} * $ml) - $ref->{ship})) >= 0) {
        $qty = $inv->{qty} if ($qty > ($inv->{qty} * $ml));

        $form->update_balance($dbh, "inventory", "qty",
                              qq|$oid{$myconfig->{dbdriver}} = $inv->{oid}|,
                              $qty * -1 * $ml);
      }
    }
    $ith->finish;

  }
  $sth->finish;

  # delete inventory entries if qty = 0
  $query = qq|DELETE FROM inventory
              WHERE oe_id = $form->{id}
	      AND qty = 0|;
  $dbh->do($query) || $form->dberror($query);

  $main::lxdebug->leave_sub();
}

sub get_inventory {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my ($null, $warehouse_id) = split /--/, $form->{warehouse};
  $warehouse_id *= 1;

  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT p.id, p.partnumber, p.description, p.onhand,
                 pg.partsgroup
                 FROM parts p
		 LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
	         WHERE p.onhand > 0|;

  if ($form->{partnumber}) {
    $var = $form->like(lc $form->{partnumber});
    $query .= "
                 AND lower(p.partnumber) LIKE '$var'";
  }
  if ($form->{description}) {
    $var = $form->like(lc $form->{description});
    $query .= "
                 AND lower(p.description) LIKE '$var'";
  }
  if ($form->{partsgroup}) {
    $var = $form->like(lc $form->{partsgroup});
    $query .= "
                 AND lower(pg.partsgroup) LIKE '$var'";
  }

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $query = qq|SELECT sum(i.qty), w.description, w.id
              FROM inventory i
	      LEFT JOIN warehouse w ON (w.id = i.warehouse_id)
	      WHERE i.parts_id = ?
	      AND NOT i.warehouse_id = $warehouse_id
	      GROUP BY w.description, w.id|;
  $wth = $dbh->prepare($query) || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {

    $wth->execute($ref->{id}) || $form->dberror;

    while (($qty, $warehouse, $warehouse_id) = $wth->fetchrow_array) {
      push @{ $form->{all_inventory} },
        { 'id'           => $ref->{id},
          'partnumber'   => $ref->{partnumber},
          'description'  => $ref->{description},
          'partsgroup'   => $ref->{partsgroup},
          'qty'          => $qty,
          'warehouse_id' => $warehouse_id,
          'warehouse'    => $warehouse }
        if $qty > 0;
    }
    $wth->finish;
  }
  $sth->finish;

  $dbh->disconnect;

  # sort inventory
  @{ $form->{all_inventory} } =
    sort { $a->{ $form->{sort} } cmp $b->{ $form->{sort} } }
    @{ $form->{all_inventory} };

  $main::lxdebug->leave_sub();

  return @{ $form->{all_inventory} };
}

sub transfer {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query = qq|INSERT INTO inventory
                 (warehouse_id, parts_id, qty, shippingdate, employee_id)
		 VALUES (?, ?, ?, ?, ?)|;
  $sth = $dbh->prepare($query) || $form->dberror($query);

  $form->get_employee($dbh);

  my @a = localtime;
  $a[5] += 1900;
  $a[4]++;
  $shippingdate = "$a[5]-$a[4]-$a[3]";

  for my $i (1 .. $form->{rowcount}) {
    $qty = $form->parse_amount($myconfig, $form->{"transfer_$i"});

    $qty = $form->{"qty_$i"} if ($qty > $form->{"qty_$i"});

    if ($qty) {

      # to warehouse
      $sth->execute($form->{warehouse_id}, $form->{"id_$i"}, $qty,
                    $shippingdate, $form->{employee_id})
        || $form->dberror;

      $sth->finish;

      # from warehouse
      $sth->execute($form->{"warehouse_id_$i"},
                    $form->{"id_$i"}, $qty * -1, $shippingdate,
                    $form->{employee_id})
        || $form->dberror;

      $sth->finish;
    }
  }

  my $rc = $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $rc;
}

sub webdav_folder {
  $main::lxdebug->enter_sub();

  my ($myconfig, $form) = @_;

SWITCH: {
    $path = "webdav/angebote/" . $form->{quonumber}, last SWITCH
      if ($form->{type} eq "sales_quotation");
    $path = "webdav/bestellungen/" . $form->{ordnumber}, last SWITCH
      if ($form->{type} eq "sales_order");
    $path = "webdav/anfragen/" . $form->{quonumber}, last SWITCH
      if ($form->{type} eq "request_quotation");
    $path = "webdav/lieferantenbestellungen/" . $form->{ordnumber}, last SWITCH
      if ($form->{type} eq "purchase_order");
  }

  if (!-d $path) {
    mkdir($path, 0770) or die "can't make directory $!\n";
  } else {
    if ($form->{id}) {
      @files = <$path/*>;
      foreach $file (@files) {
        $file =~ /\/([^\/]*)$/;
        $fname = $1;
        $ENV{'SCRIPT_NAME'} =~ /\/([^\/]*)\//;
        $lxerp = $1;
        $link  = "http://" . $ENV{'SERVER_NAME'} . "/" . $lxerp . "/" . $file;
        $form->{WEBDAV}{$fname} = $link;
      }
    }
  }

  $main::lxdebug->leave_sub();
}
1;

