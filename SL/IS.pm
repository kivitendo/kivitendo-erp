#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 1998-2002
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
# Inventory invoicing module
#
#======================================================================

package IS;

use Data::Dumper;

sub invoice_details {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $locale) = @_;

  $form->{duedate} = $form->{invdate} unless ($form->{duedate});

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT date '$form->{duedate}' - date '$form->{invdate}'
                 AS terms
		 FROM defaults|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  ($form->{terms}) = $sth->fetchrow_array;
  $sth->finish;

  my $tax = 0;
  my $item;
  my $i;
  my @partsgroup = ();
  my $partsgroup;
  my %oid = ('Pg'     => 'oid',
             'Oracle' => 'rowid');

  # sort items by partsgroup
  for $i (1 .. $form->{rowcount}) {
    $partsgroup = "";
    if ($form->{"partsgroup_$i"} && $form->{groupitems}) {
      $form->format_string("partsgroup_$i");
      $partsgroup = $form->{"partsgroup_$i"};
    }
    push @partsgroup, [$i, $partsgroup];
  }

  my $sameitem = "";
  my @taxaccounts;
  my %taxaccounts;
  my %taxbase;
  my $taxrate;
  my $taxamount;
  my $taxbase;
  my $taxdiff;

  foreach $item (sort { $a->[1] cmp $b->[1] } @partsgroup) {
    $i = $item->[0];

    if ($item->[1] ne $sameitem) {
      push(@{ $form->{description} }, qq|$item->[1]|);
      $sameitem = $item->[1];

      map { push(@{ $form->{$_} }, "") }
        qw(runningnumber number serialnumber bin partnotes qty unit deliverydate sellprice listprice netprice discount linetotal);
    }

    $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});

    if ($form->{"qty_$i"} != 0) {

      # add number, description and qty to $form->{number}, ....
      push(@{ $form->{runningnumber} }, $i);
      push(@{ $form->{number} },        qq|$form->{"partnumber_$i"}|);
      push(@{ $form->{serialnumber} },  qq|$form->{"serialnumber_$i"}|);
      push(@{ $form->{bin} },           qq|$form->{"bin_$i"}|);
      push(@{ $form->{"partnotes"} },   qq|$form->{"partnotes_$i"}|);
      push(@{ $form->{description} },   qq|$form->{"description_$i"}|);
      push(@{ $form->{qty} },
           $form->format_amount($myconfig, $form->{"qty_$i"}));
      push(@{ $form->{unit} },         qq|$form->{"unit_$i"}|);
      push(@{ $form->{deliverydate} }, qq|$form->{"deliverydate_$i"}|);

      push(@{ $form->{sellprice} }, $form->{"sellprice_$i"});
      push(@{ $form->{ordnumber_oe} }, qq|$form->{"ordnumber_$i"}|);
      push(@{ $form->{transdate_oe} }, qq|$form->{"transdate_$i"}|);

      if ($form->{lizenzen}) {
        if ($form->{"licensenumber_$i"}) {
          $query =
            qq|SELECT l.licensenumber, l.validuntil FROM license l WHERE l.id = $form->{"licensenumber_$i"}|;
          $sth = $dbh->prepare($query);
          $sth->execute || $form->dberror($query);

          ($licensenumber, $validuntil) = $sth->fetchrow_array;
          push(@{ $form->{licensenumber} }, $licensenumber);
          push(@{ $form->{validuntil} },
               $locale->date($myconfig, $validuntil, 0));
          $sth->finish;
        } else {
          push(@{ $form->{licensenumber} }, "");
          push(@{ $form->{validuntil} },    "");
        }
      }

      # listprice
      push(@{ $form->{listprice} }, $form->{"listprice_$i"});

      my $sellprice = $form->parse_amount($myconfig, $form->{"sellprice_$i"});
      my ($dec) = ($sellprice =~ /\.(\d+)/);
      $dec = length $dec;
      my $decimalplaces = ($dec > 2) ? $dec : 2;

      my $i_discount = $form->round_amount($sellprice * 
                                           $form->parse_amount($myconfig, $form->{"discount_$i"}) / 100, $decimalplaces);

      my $discount = $form->round_amount($form->{"qty_$i"} * $i_discount, $decimalplaces);

      # keep a netprice as well, (sellprice - discount)
      $form->{"netprice_$i"} = $sellprice - $i_discount;

      push(@{ $form->{netprice} },
           ($form->{"netprice_$i"} != 0)
           ? $form->format_amount(
                                 $myconfig, $form->{"netprice_$i"},
                                 $decimalplaces
             )
           : " ");

      my $linetotal =
        $form->round_amount($form->{"qty_$i"} * $form->{"netprice_$i"}, 2);

      $discount =
        ($discount != 0)
        ? $form->format_amount($myconfig, $discount * -1, $decimalplaces)
        : " ";
      $linetotal = ($linetotal != 0) ? $linetotal : " ";

      push(@{ $form->{discount} }, $discount);
      push(@{ $form->{p_discount} }, $form->{"discount_$i"});

      $form->{total} += $linetotal;

      push(@{ $form->{linetotal} },
           $form->format_amount($myconfig, $linetotal, 2));

      @taxaccounts = split / /, $form->{"taxaccounts_$i"};
      $taxrate     = 0;
      $taxdiff     = 0;

      map { $taxrate += $form->{"${_}_rate"} } @taxaccounts;

      if ($form->{taxincluded}) {

        # calculate tax
        $taxamount = $linetotal * $taxrate / (1 + $taxrate);
        $taxbase = $linetotal - $taxamount;
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
              qw(runningnumber number serialnumber unit qty bin sellprice listprice netprice discount linetotal);
            $sameitem = ($ref->{partsgroup}) ? $ref->{partsgroup} : "--";
            push(@{ $form->{description} }, $sameitem);
          }

          map { $form->{"a_$_"} = $ref->{$_} } qw(partnumber description);
          $form->format_string("a_partnumber", "a_description");

          push(@{ $form->{description} },
               $form->format_amount($myconfig, $ref->{qty} * $form->{"qty_$i"}
                 )
                 . qq| -- $form->{"a_partnumber"}, $form->{"a_description"}|);
          map { push(@{ $form->{$_} }, "") }
            qw(number unit qty runningnumber serialnumber bin sellprice listprice netprice discount linetotal);

        }
        $sth->finish;
      }
    }
  }

  foreach my $item (sort keys %taxaccounts) {
    if ($form->round_amount($taxaccounts{$item}, 2) != 0) {
      push(@{ $form->{taxbase} },
           $form->format_amount($myconfig, $taxbase{$item}, 2));

      $tax += $taxamount = $form->round_amount($taxaccounts{$item}, 2);

      push(@{ $form->{tax} }, $form->format_amount($myconfig, $taxamount, 2));
      push(@{ $form->{taxdescription} }, $form->{"${item}_description"});
      push(@{ $form->{taxrate} },
           $form->format_amount($myconfig, $form->{"${item}_rate"} * 100));
      push(@{ $form->{taxnumber} }, $form->{"${item}_taxnumber"});
    }
  }

  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"}) {
      push(@{ $form->{payment} }, $form->{"paid_$i"});
      my ($accno, $description) = split /--/, $form->{"AR_paid_$i"};
      push(@{ $form->{paymentaccount} }, $description);
      push(@{ $form->{paymentdate} },    $form->{"datepaid_$i"});
      push(@{ $form->{paymentsource} },  $form->{"source_$i"});

      $form->{paid} += $form->parse_amount($myconfig, $form->{"paid_$i"});
    }
  }

  $form->{subtotal} = $form->format_amount($myconfig, $form->{total}, 2);
  $form->{invtotal} =
    ($form->{taxincluded}) ? $form->{total} : $form->{total} + $tax;
  $form->{total} =
    $form->format_amount($myconfig, $form->{invtotal} - $form->{paid}, 2);
  $form->{invtotal} = $form->format_amount($myconfig, $form->{invtotal}, 2);

  $form->{paid} = $form->format_amount($myconfig, $form->{paid}, 2);

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

sub customer_details {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  # get contact id, set it if nessessary
  ($null, $form->{cp_id}) = split /--/, $form->{contact};

  $contact = "";
  if ($form->{cp_id}) {
    $contact = "and cp.cp_id = $form->{cp_id}";
  }

  # get rest for the customer
  my $query = qq|SELECT ct.*, cp.*, ct.notes as customernotes
                 FROM customer ct
                 LEFT JOIN contacts cp on ct.id = cp.cp_cv_id
		 WHERE ct.id = $form->{customer_id} $contact order by cp.cp_id limit 1|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $ref = $sth->fetchrow_hashref(NAME_lc);

  # remove id and taxincluded before copy back
  delete @$ref{qw(id taxincluded)};
  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub post_invoice {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database, turn off autocommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  my ($query, $sth, $null, $project_id, $deliverydate);
  my $exchangerate = 0;

  ($null, $form->{employee_id}) = split /--/, $form->{employee};
  unless ($form->{employee_id}) {
    $form->get_employee($dbh);
  }

  ($null, $form->{contact_id}) = split /--/, $form->{contact};
  $form->{contact_id} *= 1;

  ($null, $form->{department_id}) = split(/--/, $form->{department});
  $form->{department_id} *= 1;

  if ($form->{id}) {

    &reverse_invoice($dbh, $form);

  } else {
    my $uid = rand() . time;

    $uid .= $form->{login};

    $uid = substr($uid, 2, 75);

    $query = qq|INSERT INTO ar (invnumber, employee_id)
                VALUES ('$uid', $form->{employee_id})|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|SELECT a.id FROM ar a
                WHERE a.invnumber = '$uid'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{id}) = $sth->fetchrow_array;
    $sth->finish;
  }

  map { $form->{$_} =~ s/\'/\'\'/g }
    (qw(invnumber shippingpoint shipvia notes intnotes message));

  my ($netamount, $invoicediff) = (0, 0);
  my ($amount, $linetotal, $lastincomeaccno);

  if ($form->{currency} eq $form->{defaultcurrency}) {
    $form->{exchangerate} = 1;
  } else {
    $exchangerate =
      $form->check_exchangerate($myconfig, $form->{currency},
                                $form->{transdate}, 'buy');
  }

  $form->{exchangerate} =
    ($exchangerate)
    ? $exchangerate
    : $form->parse_amount($myconfig, $form->{exchangerate});

  $form->{expense_inventory} = "";

  foreach my $i (1 .. $form->{rowcount}) {
    $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});

    if ($form->{"qty_$i"} != 0) {

      map { $form->{"${_}_$i"} =~ s/\'/\'\'/g }
        (qw(partnumber description unit));

      # undo discount formatting
      $form->{"discount_$i"} =
        $form->parse_amount($myconfig, $form->{"discount_$i"}) / 100;

      my ($allocated, $taxrate) = (0, 0);
      my $taxamount;

      # keep entered selling price
      my $fxsellprice =
        $form->parse_amount($myconfig, $form->{"sellprice_$i"});

      my ($dec) = ($fxsellprice =~ /\.(\d+)/);
      $dec = length $dec;
      my $decimalplaces = ($dec > 2) ? $dec : 2;

      # deduct discount
      my $discount =
        $form->round_amount($fxsellprice * $form->{"discount_$i"},
                            $decimalplaces);
      $form->{"sellprice_$i"} = $fxsellprice - $discount;

      # add tax rates
      map { $taxrate += $form->{"${_}_rate"} } split / /,
        $form->{"taxaccounts_$i"};

      # round linetotal to 2 decimal places
      $linetotal =
        $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"}, 2);

      if ($form->{taxincluded}) {
        $taxamount = $linetotal * ($taxrate / (1 + $taxrate));
        $form->{"sellprice_$i"} =
          $form->{"sellprice_$i"} * (1 / (1 + $taxrate));
      } else {
        $taxamount = $linetotal * $taxrate;
      }

      $netamount += $linetotal;

      if ($taxamount != 0) {
        map {
          $form->{amount}{ $form->{id} }{$_} +=
            $taxamount * $form->{"${_}_rate"} / $taxrate
        } split / /, $form->{"taxaccounts_$i"};
      }

      # add amount to income, $form->{amount}{trans_id}{accno}
      $amount =
        $form->{"sellprice_$i"} * $form->{"qty_$i"} * $form->{exchangerate};

      $linetotal =
        $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"}, 2) *
        $form->{exchangerate};
      $linetotal = $form->round_amount($linetotal, 2);

      # this is the difference from the inventory
      $invoicediff += ($amount - $linetotal);

      $form->{amount}{ $form->{id} }{ $form->{"income_accno_$i"} } +=
        $linetotal;

      $lastincomeaccno = $form->{"income_accno_$i"};

      # adjust and round sellprice
      $form->{"sellprice_$i"} =
        $form->round_amount($form->{"sellprice_$i"} * $form->{exchangerate},
                            $decimalplaces);

      if ($form->{"inventory_accno_$i"} || $form->{"assembly_$i"}) {

        # adjust parts onhand quantity

        if ($form->{"assembly_$i"}) {

          # do not update if assembly consists of all services
          $query = qq|SELECT sum(p.inventory_accno_id)
		      FROM parts p
		      JOIN assembly a ON (a.parts_id = p.id)
		      WHERE a.id = $form->{"id_$i"}|;
          $sth = $dbh->prepare($query);
          $sth->execute || $form->dberror($query);

          if ($sth->fetchrow_array) {
            $form->update_balance($dbh, "parts", "onhand",
                                  qq|id = $form->{"id_$i"}|,
                                  $form->{"qty_$i"} * -1)
              unless $form->{shipped};
          }
          $sth->finish;

          # record assembly item as allocated
          &process_assembly($dbh, $form, $form->{"id_$i"}, $form->{"qty_$i"});
        } else {
          $form->update_balance($dbh, "parts", "onhand",
                                qq|id = $form->{"id_$i"}|,
                                $form->{"qty_$i"} * -1)
            unless $form->{shipped};

          $allocated = &cogs($dbh, $form, $form->{"id_$i"}, $form->{"qty_$i"});
        }
      }

      $project_id = 'NULL';
      if ($form->{"projectnumber_$i"}) {
        $project_id = $form->{"projectnumber_$i"};
      }
      $deliverydate =
        ($form->{"deliverydate_$i"})
        ? qq|'$form->{"deliverydate_$i"}'|
        : "NULL";

      # get pricegroup_id and save ist
      ($null, my $pricegroup_id) = split /--/, $form->{"sellprice_drag_$i"};
      $pricegroup_id *= 1;

      # save detail record in invoice table
      $query = qq|INSERT INTO invoice (trans_id, parts_id, description, qty,
                  sellprice, fxsellprice, discount, allocated, assemblyitem,
		  unit, deliverydate, project_id, serialnumber, pricegroup_id,
		  ordnumber, transdate, cusordnumber)
		  VALUES ($form->{id}, $form->{"id_$i"},
		  '$form->{"description_$i"}', $form->{"qty_$i"},
		  $form->{"sellprice_$i"}, $fxsellprice,
		  $form->{"discount_$i"}, $allocated, 'f',
		  '$form->{"unit_$i"}', $deliverydate, (SELECT id from project where projectnumber = '$project_id'),
		  '$form->{"serialnumber_$i"}', '$pricegroup_id',
		  '$form->{"ordnumber_$i"}', '$form->{"transdate_$i"}', '$form->{"cusordnumber_$i"}')|;
      $dbh->do($query) || $form->dberror($query);

      if ($form->{lizenzen}) {
        if ($form->{"licensenumber_$i"}) {
          $query =
            qq|SELECT i.id FROM invoice i WHERE i.trans_id=$form->{id} ORDER BY i.oid DESC LIMIT 1|;
          $sth = $dbh->prepare($query);
          $sth->execute || $form->dberror($query);

          ($invoice_row_id) = $sth->fetchrow_array;
          $sth->finish;

          $query =
            qq|INSERT INTO licenseinvoice (trans_id, license_id) VALUES ($invoice_row_id, $form->{"licensenumber_$i"})|;
          $dbh->do($query) || $form->dberror($query);
        }
      }

    }
  }

  $form->{datepaid} = $form->{invdate};

  # total payments, don't move we need it here
  for my $i (1 .. $form->{paidaccounts}) {
    $form->{"paid_$i"} = $form->parse_amount($myconfig, $form->{"paid_$i"});
    $form->{paid} += $form->{"paid_$i"};
    $form->{datepaid} = $form->{"datepaid_$i"} if ($form->{"datepaid_$i"});
  }

  my ($tax, $diff) = (0, 0);

  $netamount = $form->round_amount($netamount, 2);

  # figure out rounding errors for total amount vs netamount + taxes
  if ($form->{taxincluded}) {

    $amount = $form->round_amount($netamount * $form->{exchangerate}, 2);
    $diff += $amount - $netamount * $form->{exchangerate};
    $netamount = $amount;

    foreach my $item (split / /, $form->{taxaccounts}) {
      $amount = $form->{amount}{ $form->{id} }{$item} * $form->{exchangerate};
      $form->{amount}{ $form->{id} }{$item} = $form->round_amount($amount, 2);
      $tax += $form->{amount}{ $form->{id} }{$item};
      $netamount -= $form->{amount}{ $form->{id} }{$item};
    }

    $invoicediff += $diff;
    ######## this only applies to tax included
    if ($lastincomeaccno) {
      $form->{amount}{ $form->{id} }{$lastincomeaccno} += $invoicediff;
    }

  } else {
    $amount    = $form->round_amount($netamount * $form->{exchangerate}, 2);
    $diff      = $amount - $netamount * $form->{exchangerate};
    $netamount = $amount;
    foreach my $item (split / /, $form->{taxaccounts}) {
      $form->{amount}{ $form->{id} }{$item} =
        $form->round_amount($form->{amount}{ $form->{id} }{$item}, 2);
      $amount =
        $form->round_amount(
                 $form->{amount}{ $form->{id} }{$item} * $form->{exchangerate},
                 2);
      $diff +=
        $amount - $form->{amount}{ $form->{id} }{$item} *
        $form->{exchangerate};
      $form->{amount}{ $form->{id} }{$item} = $form->round_amount($amount, 2);
      $tax += $form->{amount}{ $form->{id} }{$item};
    }
  }

  $form->{amount}{ $form->{id} }{ $form->{AR} } = $netamount + $tax;
  $form->{paid} =
    $form->round_amount($form->{paid} * $form->{exchangerate} + $diff, 2);

  # reverse AR
  $form->{amount}{ $form->{id} }{ $form->{AR} } *= -1;

  # update exchangerate
  if (($form->{currency} ne $form->{defaultcurrency}) && !$exchangerate) {
    $form->update_exchangerate($dbh, $form->{currency}, $form->{invdate},
                               $form->{exchangerate}, 0);
  }

  foreach my $trans_id (keys %{ $form->{amount} }) {
    foreach my $accno (keys %{ $form->{amount}{$trans_id} }) {
      next unless ($form->{expense_inventory} =~ /$accno/);
      if (
          ($form->{amount}{$trans_id}{$accno} =
           $form->round_amount($form->{amount}{$trans_id}{$accno}, 2)
          ) != 0
        ) {
        $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
	            transdate, taxkey)
		    VALUES ($trans_id, (SELECT c.id FROM chart c
		                        WHERE c.accno = '$accno'),
		    $form->{amount}{$trans_id}{$accno}, '$form->{invdate}',
                    (SELECT taxkey_id  FROM chart WHERE accno = '$accno'))|;
        $dbh->do($query) || $form->dberror($query);
        $form->{amount}{$trans_id}{$accno} = 0;
      }
    }

    foreach my $accno (keys %{ $form->{amount}{$trans_id} }) {
      if (
          ($form->{amount}{$trans_id}{$accno} =
           $form->round_amount($form->{amount}{$trans_id}{$accno}, 2)
          ) != 0
        ) {
        $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
	            transdate, taxkey)
		    VALUES ($trans_id, (SELECT id FROM chart
		                        WHERE accno = '$accno'),
		    $form->{amount}{$trans_id}{$accno}, '$form->{invdate}',
                    (SELECT taxkey_id  FROM chart WHERE accno = '$accno'))|;
        $dbh->do($query) || $form->dberror($query);
      }
    }
  }

  # deduct payment differences from diff
  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"} != 0) {
      $amount =
        $form->round_amount($form->{"paid_$i"} * $form->{exchangerate}, 2);
      $diff -= $amount - $form->{"paid_$i"} * $form->{exchangerate};
    }
  }

  # force AR entry if 0
  #  $form->{amount}{$form->{id}}{$form->{AR}} = 1 if ($form->{amount}{$form->{id}}{$form->{AR}} == 0);

  # record payments and offsetting AR
  for my $i (1 .. $form->{paidaccounts}) {

    if ($form->{"paid_$i"} != 0) {
      my ($accno) = split /--/, $form->{"AR_paid_$i"};
      $form->{"datepaid_$i"} = $form->{invdate}
        unless ($form->{"datepaid_$i"});
      $form->{datepaid} = $form->{"datepaid_$i"};

      $exchangerate = 0;

      if ($form->{currency} eq $form->{defaultcurrency}) {
        $form->{"exchangerate_$i"} = 1;
      } else {
        $exchangerate =
          $form->check_exchangerate($myconfig, $form->{currency},
                                    $form->{"datepaid_$i"}, 'buy');

        $form->{"exchangerate_$i"} =
          ($exchangerate)
          ? $exchangerate
          : $form->parse_amount($myconfig, $form->{"exchangerate_$i"});
      }

      # record AR
      $amount =
        $form->round_amount($form->{"paid_$i"} * $form->{exchangerate} + $diff,
                            2);

      if ($form->{amount}{ $form->{id} }{ $form->{AR} } != 0) {
        $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
	            transdate)
		    VALUES ($form->{id}, (SELECT c.id FROM chart c
					WHERE c.accno = '$form->{AR}'),
		    $amount, '$form->{"datepaid_$i"}')|;
        $dbh->do($query) || $form->dberror($query);
      }

      # record payment
      $form->{"paid_$i"} *= -1;

      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate,
                  source, memo)
                  VALUES ($form->{id}, (SELECT c.id FROM chart c
		                      WHERE c.accno = '$accno'),
		  $form->{"paid_$i"}, '$form->{"datepaid_$i"}',
		  '$form->{"source_$i"}', '$form->{"memo_$i"}')|;
      $dbh->do($query) || $form->dberror($query);

      # exchangerate difference
      $form->{fx}{$accno}{ $form->{"datepaid_$i"} } +=
        $form->{"paid_$i"} * ($form->{"exchangerate_$i"} - 1) + $diff;

      # gain/loss
      $amount =
        $form->{"paid_$i"} * $form->{exchangerate} - $form->{"paid_$i"} *
        $form->{"exchangerate_$i"};
      if ($amount > 0) {
        $form->{fx}{ $form->{fxgain_accno} }{ $form->{"datepaid_$i"} } +=
          $amount;
      } else {
        $form->{fx}{ $form->{fxloss_accno} }{ $form->{"datepaid_$i"} } +=
          $amount;
      }

      $diff = 0;

      # update exchange rate
      if (($form->{currency} ne $form->{defaultcurrency}) && !$exchangerate) {
        $form->update_exchangerate($dbh, $form->{currency},
                                   $form->{"datepaid_$i"},
                                   $form->{"exchangerate_$i"}, 0);
      }
    }
  }

  # record exchange rate differences and gains/losses
  foreach my $accno (keys %{ $form->{fx} }) {
    foreach my $transdate (keys %{ $form->{fx}{$accno} }) {
      if (
          ($form->{fx}{$accno}{$transdate} =
           $form->round_amount($form->{fx}{$accno}{$transdate}, 2)
          ) != 0
        ) {

        $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
	            transdate, cleared, fx_transaction)
		    VALUES ($form->{id},
		           (SELECT c.id FROM chart c
		            WHERE c.accno = '$accno'),
		    $form->{fx}{$accno}{$transdate}, '$transdate', '0', '1')|;
        $dbh->do($query) || $form->dberror($query);
      }
    }
  }

  $amount = $netamount + $tax;

  # set values which could be empty to 0
  $form->{terms}       *= 1;
  $form->{taxincluded} *= 1;
  my $datepaid = ($form->{paid})    ? qq|'$form->{datepaid}'| : "NULL";
  my $duedate  = ($form->{duedate}) ? qq|'$form->{duedate}'|  : "NULL";

  # fill in subject if there is none
  $form->{subject} = qq|$form->{label} $form->{invnumber}|
    unless $form->{subject};

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

  # save AR record
  $query = qq|UPDATE ar set
              invnumber = '$form->{invnumber}',
	      ordnumber = '$form->{ordnumber}',
	      quonumber = '$form->{quonumber}',
	      cusordnumber = '$form->{cusordnumber}',
              transdate = '$form->{invdate}',
              customer_id = $form->{customer_id},
              amount = $amount,
              netamount = $netamount,
              paid = $form->{paid},
	      datepaid = $datepaid,
	      duedate = $duedate,
	      invoice = '1',
	      shippingpoint = '$form->{shippingpoint}',
	      shipvia = '$form->{shipvia}',
	      terms = $form->{terms},
	      notes = '$form->{notes}',
	      intnotes = '$form->{intnotes}',
	      taxincluded = '$form->{taxincluded}',
	      curr = '$form->{currency}',
	      department_id = $form->{department_id},
	      employee_id = $form->{employee_id},
              cp_id = $form->{contact_id}
              WHERE id = $form->{id}
             |;
  $dbh->do($query) || $form->dberror($query);

  $form->{pago_total} = $amount;

  # add shipto
  $form->{name} = $form->{customer};
  $form->{name} =~ s/--$form->{customer_id}//;
  $form->add_shipto($dbh, $form->{id});

  # save printed, emailed and queued
  $form->save_status($dbh);

  if ($form->{webdav}) {
    &webdav_folder($myconfig, $form);
  }

  my $rc = $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $rc;
}

sub process_assembly {
  $main::lxdebug->enter_sub();

  my ($dbh, $form, $id, $totalqty) = @_;

  my $query = qq|SELECT a.parts_id, a.qty, p.assembly,
                 p.partnumber, p.description, p.unit,
                 p.inventory_accno_id, p.income_accno_id,
		 p.expense_accno_id
                 FROM assembly a
		 JOIN parts p ON (a.parts_id = p.id)
		 WHERE a.id = $id|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {

    my $allocated = 0;

    $ref->{inventory_accno_id} *= 1;
    $ref->{expense_accno_id}   *= 1;

    map { $ref->{$_} =~ s/\'/\'\'/g } (qw(partnumber description unit));

    # multiply by number of assemblies
    $ref->{qty} *= $totalqty;

    if ($ref->{assembly}) {
      &process_assembly($dbh, $form, $ref->{parts_id}, $ref->{qty});
      next;
    } else {
      if ($ref->{inventory_accno_id}) {
        $allocated = &cogs($dbh, $form, $ref->{parts_id}, $ref->{qty});
      }
    }

    # save detail record for individual assembly item in invoice table
    $query = qq|INSERT INTO invoice (trans_id, description, parts_id, qty,
                sellprice, fxsellprice, allocated, assemblyitem, unit)
		VALUES
		($form->{id}, '$ref->{description}',
		$ref->{parts_id}, $ref->{qty}, 0, 0, $allocated, 't',
		'$ref->{unit}')|;
    $dbh->do($query) || $form->dberror($query);

  }

  $sth->finish;

  $main::lxdebug->leave_sub();
}

sub cogs {
  $main::lxdebug->enter_sub();

  my ($dbh, $form, $id, $totalqty) = @_;

  my $query = qq|SELECT i.id, i.trans_id, i.qty, i.allocated, i.sellprice,
                   (SELECT c.accno FROM chart c
		    WHERE p.inventory_accno_id = c.id) AS inventory_accno,
		   (SELECT c.accno FROM chart c
		    WHERE p.expense_accno_id = c.id) AS expense_accno
		  FROM invoice i, parts p
		  WHERE i.parts_id = p.id
		  AND i.parts_id = $id
		  AND (i.qty + i.allocated) < 0
		  ORDER BY trans_id|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $allocated = 0;
  my $qty;

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    if (($qty = (($ref->{qty} * -1) - $ref->{allocated})) > $totalqty) {
      $qty = $totalqty;
    }

    $form->update_balance($dbh, "invoice", "allocated", qq|id = $ref->{id}|,
                          $qty);

    # total expenses and inventory
    # sellprice is the cost of the item
    $linetotal = $form->round_amount($ref->{sellprice} * $qty, 2);

    if (!$eur) {

      # add to expense
      $form->{amount}{ $form->{id} }{ $ref->{expense_accno} } += -$linetotal;
      $form->{expense_inventory} .= " " . $ref->{expense_accno};

      # deduct inventory
      $form->{amount}{ $form->{id} }{ $ref->{inventory_accno} } -= -$linetotal;
      $form->{expense_inventory} .= " " . $ref->{inventory_accno};
    }

    # add allocated
    $allocated += -$qty;

    last if (($totalqty -= $qty) <= 0);
  }

  $sth->finish;

  $main::lxdebug->leave_sub();

  return $allocated;
}

sub reverse_invoice {
  $main::lxdebug->enter_sub();

  my ($dbh, $form) = @_;

  # reverse inventory items
  my $query = qq|SELECT i.id, i.parts_id, i.qty, i.assemblyitem, p.assembly,
		 p.inventory_accno_id
                 FROM invoice i
		 JOIN parts p ON (i.parts_id = p.id)
		 WHERE i.trans_id = $form->{id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {

    if ($ref->{inventory_accno_id} || $ref->{assembly}) {

      # if the invoice item is not an assemblyitem adjust parts onhand
      if (!$ref->{assemblyitem}) {

        # adjust onhand in parts table
        $form->update_balance($dbh, "parts", "onhand",
                              qq|id = $ref->{parts_id}|,
                              $ref->{qty});
      }

      # loop if it is an assembly
      next if ($ref->{assembly});

      # de-allocated purchases
      $query = qq|SELECT i.id, i.trans_id, i.allocated
                  FROM invoice i
		  WHERE i.parts_id = $ref->{parts_id}
		  AND i.allocated > 0
		  ORDER BY i.trans_id DESC|;
      my $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);

      while (my $inhref = $sth->fetchrow_hashref(NAME_lc)) {
        $qty = $ref->{qty};
        if (($ref->{qty} - $inhref->{allocated}) > 0) {
          $qty = $inhref->{allocated};
        }

        # update invoice
        $form->update_balance($dbh, "invoice", "allocated",
                              qq|id = $inhref->{id}|,
                              $qty * -1);

        last if (($ref->{qty} -= $qty) <= 0);
      }
      $sth->finish;
    }
  }

  $sth->finish;

  # delete acc_trans
  $query = qq|DELETE FROM acc_trans
              WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # delete invoice entries
  $query = qq|DELETE FROM invoice
              WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  if ($form->{lizenzen}) {
    $query = qq|DELETE FROM licenseinvoice
              WHERE trans_id in (SELECT id FROM invoice WHERE trans_id = $form->{id})|;
    $dbh->do($query) || $form->dberror($query);
  }

  $query = qq|DELETE FROM shipto
              WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $main::lxdebug->leave_sub();
}

sub delete_invoice {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $spool) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  &reverse_invoice($dbh, $form);

  # delete AR record
  my $query = qq|DELETE FROM ar
                 WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # delete spool files
  $query = qq|SELECT s.spoolfile FROM status s
              WHERE s.trans_id = $form->{id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  my $spoolfile;
  my @spoolfiles = ();

  while (($spoolfile) = $sth->fetchrow_array) {
    push @spoolfiles, $spoolfile;
  }
  $sth->finish;

  # delete status entries
  $query = qq|DELETE FROM status
              WHERE trans_id = $form->{id}|;
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

sub retrieve_invoice {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query;

  if ($form->{id}) {

    # get default accounts and last invoice number
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
                d.curr AS currencies, current_date AS invdate
                FROM defaults d|;
  }
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);
  map { $form->{$_} = $ref->{$_} } keys %$ref;
  $sth->finish;

  if ($form->{id}) {

    # retrieve invoice
    $query = qq|SELECT a.invnumber, a.ordnumber, a.quonumber, a.cusordnumber,
                a.transdate AS invdate, a.paid,
                a.shippingpoint, a.shipvia, a.terms, a.notes, a.intnotes,
		a.duedate, a.taxincluded, a.curr AS currency,
		a.employee_id, e.name AS employee
		FROM ar a
	        LEFT JOIN employee e ON (e.id = a.employee_id)
		WHERE a.id = $form->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    map { $form->{$_} = $ref->{$_} } keys %$ref;
    $sth->finish;

    $form->{exchangerate} =
      $form->get_exchangerate($dbh, $form->{currency}, $form->{invdate},
                              "buy");

    # get shipto
    $query = qq|SELECT s.* FROM shipto s
                WHERE s.trans_id = $form->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    map { $form->{$_} = $ref->{$_} } keys %$ref;
    $sth->finish;

    # get printed, emailed
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

    # retrieve individual items
    $query = qq|SELECT (SELECT c.accno FROM chart c
                       WHERE p.inventory_accno_id = c.id)
                       AS inventory_accno,
		       (SELECT c.accno FROM chart c
		       WHERE p.income_accno_id = c.id)
		       AS income_accno,
		       (SELECT c.accno FROM chart c
		       WHERE p.expense_accno_id = c.id)
		       AS expense_accno,
                i.description, i.qty, i.fxsellprice AS sellprice,
		i.discount, i.parts_id AS id, i.unit, i.deliverydate,
		i.project_id, pr.projectnumber, i.serialnumber,
		p.partnumber, p.assembly, p.bin, p.notes AS partnotes, i.id AS invoice_pos,
		pg.partsgroup, i.pricegroup_id, (SELECT pricegroup FROM pricegroup WHERE id=i.pricegroup_id) as pricegroup,
		i.ordnumber, i.transdate, i.cusordnumber
		FROM invoice i
	        JOIN parts p ON (i.parts_id = p.id)
	        LEFT JOIN project pr ON (i.project_id = pr.id)
	        LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		WHERE i.trans_id = $form->{id}
		AND NOT i.assemblyitem = '1'
		ORDER BY i.id|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {

      #set expense_accno=inventory_accno if they are different => bilanz
      $vendor_accno =
        ($ref->{expense_accno} != $ref->{inventory_accno})
        ? $ref->{inventory_accno}
        : $ref->{expense_accno};

      # get tax rates and description
      $accno_id =
        ($form->{vc} eq "customer") ? $ref->{income_accno} : $vendor_accno;
      $query = qq|SELECT c.accno, c.description, t.rate, t.taxnumber
	         FROM chart c, tax t
	         WHERE c.id=t.chart_id AND t.taxkey in (SELECT taxkey_id from chart where accno = '$accno_id')
	         ORDER BY accno|;
      $stw = $dbh->prepare($query);
      $stw->execute || $form->dberror($query);
      $ref->{taxaccounts} = "";
      while ($ptr = $stw->fetchrow_hashref(NAME_lc)) {

        #    if ($customertax{$ref->{accno}}) {
        $ref->{taxaccounts} .= "$ptr->{accno} ";
        if (!($form->{taxaccounts} =~ /$ptr->{accno}/)) {
          $form->{"$ptr->{accno}_rate"}        = $ptr->{rate};
          $form->{"$ptr->{accno}_description"} = $ptr->{description};
          $form->{"$ptr->{accno}_taxnumber"}   = $ptr->{taxnumber};
          $form->{taxaccounts} .= "$ptr->{accno} ";
        }

      }

      if ($form->{lizenzen}) {
        $query = qq|SELECT l.licensenumber, l.id AS licenseid
	         FROM license l, licenseinvoice li
	         WHERE l.id = li.license_id AND li.trans_id = $ref->{invoice_pos}|;
        $stg = $dbh->prepare($query);
        $stg->execute || $form->dberror($query);
        ($licensenumber, $licenseid) = $stg->fetchrow_array();
        $ref->{lizenzen} =
          "<option value=\"$licenseid\">$licensenumber</option>";
        $stg->finish();
      }

      chop $ref->{taxaccounts};
      push @{ $form->{invoice_details} }, $ref;
      $stw->finish;
    }
    $sth->finish;

    if ($form->{webdav}) {
      &webdav_folder($myconfig, $form);
    }
  }

  my $rc = $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $rc;
}

sub get_customer {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $dateformat = $myconfig->{dateformat};
  $dateformat .= "yy" if $myconfig->{dateformat} !~ /^y/;

  my $duedate =
    ($form->{invdate})
    ? "to_date('$form->{invdate}', '$dateformat')"
    : "current_date";

  $form->{customer_id} *= 1;

  # get customer
  my $query = qq|SELECT c.name AS customer, c.discount, c.creditlimit, c.terms,
                 c.email, c.cc, c.bcc, c.language,
		 c.street, c.zipcode, c.city, c.country,
	         $duedate + c.terms AS duedate, c.notes AS intnotes,
		 b.discount AS tradediscount, b.description AS business, c.klass as customer_klass
                 FROM customer c
		 LEFT JOIN business b ON (b.id = c.business_id)
	         WHERE c.id = $form->{customer_id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $ref = $sth->fetchrow_hashref(NAME_lc);

  map { $form->{$_} = $ref->{$_} } keys %$ref;
  $sth->finish;

  $form->{creditremaining} = $form->{creditlimit};
  $query = qq|SELECT SUM(a.amount - a.paid)
	      FROM ar a
	      WHERE a.customer_id = $form->{customer_id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  ($form->{creditremaining}) -= $sth->fetchrow_array;

  $sth->finish;

  $query = qq|SELECT o.amount,
                (SELECT e.buy FROM exchangerate e
		 WHERE e.curr = o.curr
		 AND e.transdate = o.transdate)
	      FROM oe o
	      WHERE o.customer_id = $form->{customer_id}
	      AND o.quotation = '0'
	      AND o.closed = '0'|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my ($amount, $exch) = $sth->fetchrow_array) {
    $exch = 1 unless $exch;
    $form->{creditremaining} -= $amount * $exch;
  }
  $sth->finish;

  $form->get_contacts($dbh, $form->{customer_id});
  ($null, $form->{cp_id}) = split /--/, $form->{contact};

  # get contact if selected
  if ($form->{contact} ne "--" && $form->{contact} ne "") {
    $form->get_contact($dbh, $form->{cp_id});
  }

  # get shipto if we did not converted an order or invoice
  if (!$form->{shipto}) {
    map { delete $form->{$_} }
      qw(shiptoname shiptodepartment_1 shiptodepartment_2 shiptostreet shiptozipcode shiptocity shiptocountry shiptocontact shiptophone shiptofax shiptoemail);

    $query = qq|SELECT s.* FROM shipto s
                WHERE s.trans_id = $form->{customer_id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    map { $form->{$_} = $ref->{$_} } keys %$ref;
    $sth->finish;
  }

  # get taxes we charge for this customer
  $query = qq|SELECT c.accno
              FROM chart c
	      JOIN customertax ct ON (ct.chart_id = c.id)
	      WHERE ct.customer_id = $form->{customer_id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $customertax = ();
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $customertax{ $ref->{accno} } = 1;
  }
  $sth->finish;

  # setup last accounts used for this customer
  if (!$form->{id} && $form->{type} !~ /_(order|quotation)/) {
    $query = qq|SELECT c.accno, c.description, c.link, c.category
                FROM chart c
		JOIN acc_trans ac ON (ac.chart_id = c.id)
		JOIN ar a ON (a.id = ac.trans_id)
		WHERE a.customer_id = $form->{customer_id}
		AND NOT (c.link LIKE '%_tax%' OR c.link LIKE '%_paid%')
		AND a.id IN (SELECT max(a2.id) FROM ar a2
		             WHERE a2.customer_id = $form->{customer_id})|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    my $i = 0;
    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      if ($ref->{category} eq 'I') {
        $i++;
        $form->{"AR_amount_$i"} = "$ref->{accno}--$ref->{description}";
      }
      if ($ref->{category} eq 'A') {
        $form->{ARselected} = $form->{AR_1} =
          "$ref->{accno}--$ref->{description}";
      }
    }
    $sth->finish;
    $form->{rowcount} = $i if ($i && !$form->{type});
  }

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub retrieve_item {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $i = $form->{rowcount};

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
    $where .= " ORDER BY p.description";
  } else {
    $where .= " ORDER BY p.partnumber";
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

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {

    #set expense_accno=inventory_accno if they are different => bilanz
    $vendor_accno =
      ($ref->{expense_accno} != $ref->{inventory_accno})
      ? $ref->{inventory_accno}
      : $ref->{expense_accno};

    # get tax rates and description
    $accno_id =
      ($form->{vc} eq "customer") ? $ref->{income_accno} : $vendor_accno;
    $query = qq|SELECT c.accno, c.description, t.rate, t.taxnumber
	      FROM chart c, tax t
	      WHERE c.id=t.chart_id AND t.taxkey in (SELECT c2.taxkey_id from chart c2 where c2.accno = '$accno_id')
	      ORDER BY c.accno|;
    $stw = $dbh->prepare($query);
    $stw->execute || $form->dberror($query);

    $ref->{taxaccounts} = "";
    while ($ptr = $stw->fetchrow_hashref(NAME_lc)) {

      #    if ($customertax{$ref->{accno}}) {
      $ref->{taxaccounts} .= "$ptr->{accno} ";
      if (!($form->{taxaccounts} =~ /$ptr->{accno}/)) {
        $form->{"$ptr->{accno}_rate"}        = $ptr->{rate};
        $form->{"$ptr->{accno}_description"} = $ptr->{description};
        $form->{"$ptr->{accno}_taxnumber"}   = $ptr->{taxnumber};
        $form->{taxaccounts} .= "$ptr->{accno} ";
      }

    }

    $stw->finish;
    chop $ref->{taxaccounts};

    push @{ $form->{item_list} }, $ref;

    if ($form->{lizenzen}) {
      if ($ref->{inventory_accno} > 0) {
        $query =
          qq| SELECT l.* FROM license l WHERE l.parts_id = $ref->{id} AND NOT l.id IN (SELECT li.license_id FROM licenseinvoice li)|;
        $stw = $dbh->prepare($query);
        $stw->execute || $form->dberror($query);
        while ($ptr = $stw->fetchrow_hashref(NAME_lc)) {
          push @{ $form->{LIZENZEN}{ $ref->{id} } }, $ptr;
        }
        $stw->finish;
      }
    }
  }
  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

##########################
# get pricegroups from database
# build up selected pricegroup
# if an exchange rate - change price
# for each part
#
sub get_pricegroups_for_parts {

  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my $i  = 1;
  my $id = 0;

  while (($form->{"id_$i"}) or ($form->{"new_id_$i"})) {

    $id = $form->{"id_$i"};

    if (!($form->{"id_$i"}) and $form->{"new_id_$i"}) {

      $id = $form->{"new_id_$i"};
    }

    ($price, $selectedpricegroup_id) = split /--/,
      $form->{"sellprice_drag_$i"};

    $pricegroup_old = $form->{"pricegroup_old_$i"};

    $price_new = $form->{"price_new_$i"};

    $price_old = $form->{"price_old_$i"};

    $query =
      qq|SELECT pricegroup_id, (SELECT p.sellprice from parts p where p.id = $id) as default_sellprice,(SELECT pg.pricegroup FROM pricegroup pg WHERE id=pricegroup_id) AS pricegroup, price, '' AS selected FROM prices WHERE parts_id = $id UNION SELECT 0 as pricegroup_id,(SELECT sellprice FROM parts WHERE id=$id) as default_sellprice,'' as pricegroup, (SELECT DISTINCT sellprice from parts where id=$id) as price, 'selected' AS selected from prices ORDER BY pricegroup|;

    $pkq = $dbh->prepare($query);
    $pkq->execute || $form->dberror($query);
    while ($pkr = $pkq->fetchrow_hashref(NAME_lc)) {

      #       push @{ $form->{PRICES}{$id} }, $pkr;
      push @{ $form->{PRICES}{$i} }, $pkr;
      $pkr->{id}       = $id;
      $pkr->{selected} = '';

      # if there is an exchange rate change price
      if (($form->{exchangerate} * 1) != 0) {

        $pkr->{price} /= $form->{exchangerate};
      }
      $pkr->{price} = $form->format_amount($myconfig, $pkr->{price}, 5);

      if ($selectedpricegroup_id eq undef) {
        if ($pkr->{pricegroup_id} eq $form->{customer_klass}) {

          $pkr->{selected}  = ' selected';
          $last->{selected} = '';

          # no customer pricesgroup set
          if ($pkr->{price} == $pkr->{default_sellprice}) {

            $pkr->{price} = $form->{"sellprice_$i"};

          } else {

            $form->{"sellprice_$i"} = $pkr->{price};
          }

        } else {
          if ($pkr->{price} == $pkr->{default_sellprice}) {

            $pkr->{price}    = $form->{"sellprice_$i"};
            $pkr->{selected} = ' selected';
          }
        }
      }
      if ($selectedpricegroup_id or $selectedpricegroup_id == 0) {
        if ($selectedpricegroup_id ne $pricegroup_old) {
          if ($pkr->{pricegroup_id} eq $selectedpricegroup_id) {
            if ($price_new != $form->{"sellprice_$i"}) {
            } else {
              $pkr->{selected}  = ' selected';
              $last->{selected} = '';
            }
          }
        } else {
          if (($price_new != $form->{"sellprice_$i"}) and ($price_new ne 0)) {
            if ($pkr->{pricegroup_id} == 0) {
              $pkr->{price}     = $form->{"sellprice_$i"};
              $pkr->{selected}  = ' selected';
              $last->{selected} = '';
            }
          } else {
            if ($pkr->{pricegroup_id} eq $selectedpricegroup_id) {
              $pkr->{selected}  = ' selected';
              $last->{selected} = '';
              if (    ($pkr->{pricegroup_id} == 0)
                  and ($pkr->{price} == $form->{"sellprice_$i"})) {

                # $pkr->{price}                         = $form->{"sellprice_$i"};
                  } else {
                $pkr->{price} = $form->{"sellprice_$i"};
              }
            }
          }
        }
      }
    }
    $i++;

    $pkq->finish;
  }

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub webdav_folder {
  $main::lxdebug->enter_sub();

  my ($myconfig, $form) = @_;

SWITCH: {
    $path = "webdav/rechnungen/" . $form->{invnumber}, last SWITCH
      if ($form->{vc} eq "customer");
    $path = "webdav/einkaufsrechnungen/" . $form->{invnumber}, last SWITCH
      if ($form->{vc} eq "vendor");
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

