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
use SL::AM;
use SL::Common;
use SL::DBUtils;

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
      join(", ", map({ "?" } @project_ids)) . ")";
    $sth = $dbh->prepare($query);
    $sth->execute(@project_ids) ||
      $form->dberror($query . " (" . join(", ", @project_ids) . ")");
    while (my $ref = $sth->fetchrow_hashref()) {
      $projectnumbers{$ref->{id}} = $ref->{projectnumber};
    }
    $sth->finish();
  }

  $form->{"globalprojectnumber"} =
    $projectnumbers{$form->{"globalproject_id"}};

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
  my $nodiscount;
  my $yesdiscount;
  my $nodiscount_subtotal = 0;
  my $discount_subtotal = 0;
  my $position = 0;
  my $subtotal_header = 0;
  my $subposition = 0;

  my @arrays =
    qw(runningnumber number description longdescription qty ship unit bin
       deliverydate_oe ordnumber_oe transdate_oe licensenumber validuntil
       partnotes serialnumber reqdate sellprice listprice netprice
       discount p_discount discount_sub nodiscount_sub
       linetotal  nodiscount_linetotal tax_rate projectnumber);

  my @tax_arrays =
    qw(taxbase tax taxdescription taxrate taxnumber);

  foreach $item (sort { $a->[1] cmp $b->[1] } @partsgroup) {
    $i = $item->[0];

    if ($item->[1] ne $sameitem) {
      push(@{ $form->{description} }, qq|$item->[1]|);
      $sameitem = $item->[1];

      map({ push(@{ $form->{$_} }, "") } grep({ $_ ne "description" } @arrays));
    }

    $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});

    if ($form->{"id_$i"} != 0) {

      # add number, description and qty to $form->{number},
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
      push(@{ $form->{runningnumber} }, $position);
      push(@{ $form->{number} },        qq|$form->{"partnumber_$i"}|);
      push(@{ $form->{serialnumber} },  qq|$form->{"serialnumber_$i"}|);
      push(@{ $form->{bin} },           qq|$form->{"bin_$i"}|);
      push(@{ $form->{"partnotes"} },   qq|$form->{"partnotes_$i"}|);
      push(@{ $form->{description} },   qq|$form->{"description_$i"}|);
      push(@{ $form->{longdescription} },   qq|$form->{"longdescription_$i"}|);
      push(@{ $form->{qty} },
           $form->format_amount($myconfig, $form->{"qty_$i"}));
      push(@{ $form->{unit} },            qq|$form->{"unit_$i"}|);
      push(@{ $form->{deliverydate_oe} }, qq|$form->{"deliverydate_$i"}|);

      push(@{ $form->{sellprice} },    $form->{"sellprice_$i"});
      push(@{ $form->{ordnumber_oe} }, qq|$form->{"ordnumber_$i"}|);
      push(@{ $form->{transdate_oe} }, qq|$form->{"transdate_$i"}|);
      push(@{ $form->{invnumber} }, qq|$form->{"invnumber"}|);
      push(@{ $form->{invdate} }, qq|$form->{"invdate"}|);

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

      my $i_discount =
        $form->round_amount(
                            $sellprice * $form->parse_amount($myconfig,
                                                 $form->{"discount_$i"}) / 100,
                            $decimalplaces);

      my $discount =
        $form->round_amount($form->{"qty_$i"} * $i_discount, $decimalplaces);

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

      my $nodiscount_linetotal =
        $form->round_amount($form->{"qty_$i"} * $sellprice, 2);

      $discount =
        ($discount != 0)
        ? $form->format_amount($myconfig, $discount * -1, $decimalplaces)
        : " ";
      $linetotal = ($linetotal != 0) ? $linetotal : " ";

      push(@{ $form->{discount} },   $discount);
      push(@{ $form->{p_discount} }, $form->{"discount_$i"});
      if (($form->{"discount_$i"} ne "") && ($form->{"discount_$i"} != 0)) {
        $form->{discount_p} = $form->{"discount_$i"};
      }
      $form->{total} += $linetotal;
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

      push(@{ $form->{projectnumber} }, $projectnumbers{$form->{"project_id_$i"}});

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
            map({ push(@{ $form->{$_} }, "") } grep({ $_ ne "description" } @arrays));
            $sameitem = ($ref->{partsgroup}) ? $ref->{partsgroup} : "--";
            push(@{ $form->{description} }, $sameitem);
          }

          map { $form->{"a_$_"} = $ref->{$_} } qw(partnumber description);

          push(@{ $form->{description} },
               $form->format_amount($myconfig, $ref->{qty} * $form->{"qty_$i"}
                 )
                 . qq| -- $form->{"a_partnumber"}, $form->{"a_description"}|);
          map({ push(@{ $form->{$_} }, "") } grep({ $_ ne "description" } @arrays));

        }
        $sth->finish;
      }
    }
  }

  foreach my $item (sort keys %taxaccounts) {
    push(@{ $form->{taxbase} },
          $form->format_amount($myconfig, $taxbase{$item}, 2));

    $tax += $taxamount = $form->round_amount($taxaccounts{$item}, 2);

    push(@{ $form->{tax} }, $form->format_amount($myconfig, $taxamount, 2));
    push(@{ $form->{taxdescription} }, $form->{"${item}_description"}  . q{ } . 100 * $form->{"${item}_rate"} . q{%});
    push(@{ $form->{taxrate} },
          $form->format_amount($myconfig, $form->{"${item}_rate"} * 100));
    push(@{ $form->{taxnumber} }, $form->{"${item}_taxnumber"});
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
  if($form->{taxincluded}) {
    $form->{subtotal} = $form->format_amount($myconfig, $form->{total} - $tax, 2);
  }
  else {
    $form->{subtotal} = $form->format_amount($myconfig, $form->{total}, 2);
  }
  $yesdiscount = $form->{nodiscount_total} - $nodiscount;
  $form->{nodiscount_subtotal} = $form->format_amount($myconfig, $form->{nodiscount_total}, 2);
  $form->{discount_total} = $form->format_amount($myconfig, $form->{discount_total}, 2);
  $form->{nodiscount} = $form->format_amount($myconfig, $nodiscount, 2);
  $form->{yesdiscount} = $form->format_amount($myconfig, $yesdiscount, 2);

  $form->{invtotal} =
    ($form->{taxincluded}) ? $form->{total} : $form->{total} + $tax;
  $form->{total} =
    $form->format_amount($myconfig, $form->{invtotal} - $form->{paid}, 2);

  $form->{invtotal} = $form->format_amount($myconfig, $form->{invtotal}, 2);
  $form->{paid} = $form->format_amount($myconfig, $form->{paid}, 2);
  $form->set_payment_options($myconfig, $form->{invdate});

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

  my ($self, $myconfig, $form, @wanted_vars) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  # get contact id, set it if nessessary
  $form->{cp_id} *= 1;

  $contact = "";
  if ($form->{cp_id}) {
    $contact = "and cp.cp_id = $form->{cp_id}";
  }

  # get rest for the customer
  my $query = qq|SELECT ct.*, cp.*, ct.notes as customernotes, ct.phone AS customerphone, ct.fax AS customerfax, ct.email AS customeremail
                 FROM customer ct
                 LEFT JOIN contacts cp on ct.id = cp.cp_cv_id
		 WHERE ct.id = $form->{customer_id} $contact order by cp.cp_id limit 1|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $ref = $sth->fetchrow_hashref(NAME_lc);

  # remove id and taxincluded before copy back
  delete @$ref{qw(id taxincluded)};

  @wanted_vars = grep({ $_ } @wanted_vars);
  if (scalar(@wanted_vars) > 0) {
    my %h_wanted_vars;
    map({ $h_wanted_vars{$_} = 1; } @wanted_vars);
    map({ delete($ref->{$_}) unless ($h_wanted_vars{$_}); } keys(%{$ref}));
  }

  map { $form->{$_} = $ref->{$_} } keys %$ref;
  $sth->finish;

  if ($form->{delivery_customer_id}) {
    my $query = qq|SELECT ct.*, ct.notes as customernotes
                 FROM customer ct
		 WHERE ct.id = $form->{delivery_customer_id} limit 1|;
    my $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);

    $sth->finish;
    map { $form->{"dc_$_"} = $ref->{$_} } keys %$ref;
  }

  if ($form->{delivery_vendor_id}) {
    my $query = qq|SELECT ct.*, ct.notes as customernotes
                 FROM customer ct
		 WHERE ct.id = $form->{delivery_vendor_id} limit 1|;
    my $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);

    $sth->finish;
    map { $form->{"dv_$_"} = $ref->{$_} } keys %$ref;
  }
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

  $form->{payment_id} *= 1;
  $form->{language_id} *= 1;
  $form->{taxzone_id} *= 1;
  $form->{delivery_customer_id} *= 1;
  $form->{delivery_vendor_id} *= 1;
  $form->{storno} *= 1;
  $form->{shipto_id} *= 1;


  ($null, $form->{department_id}) = split(/--/, $form->{department});
  $form->{department_id} *= 1;

  my $service_units = AM->retrieve_units($myconfig,$form,"service");
  my $part_units = AM->retrieve_units($myconfig,$form,"dimension");



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

    if (!$form->{invnumber}) {
      $form->{invnumber} =
        $form->update_defaults($myconfig, $form->{type} eq "credit_note" ?
                               "cnnumber" : "invnumber", $dbh);
    }
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
    if ($form->{type} eq "credit_note") {
      $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"}) * -1;
      $form->{shipped} = 1;   
    } else {
      $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});
    }
    my $basefactor;
    my $basqty;

    if ($form->{storno}) {
      $form->{"qty_$i"} *= -1;
    }

    if ($form->{"id_$i"}) {

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
            $form->update_balance($dbh, "parts", "onhand", qq|id = ?|,
                                  $baseqty * -1, $form->{"id_$i"})
              unless $form->{shipped};
          }
          $sth->finish;

          # record assembly item as allocated
          &process_assembly($dbh, $form, $form->{"id_$i"}, $baseqty);
        } else {
          $form->update_balance($dbh, "parts", "onhand", qq|id = ?|,
                                $baseqty * -1, $form->{"id_$i"})
            unless $form->{shipped};

          $allocated = &cogs($dbh, $form, $form->{"id_$i"}, $baseqty, $basefactor, $i);
        }
      }

      $deliverydate =
        ($form->{"deliverydate_$i"})
        ? qq|'$form->{"deliverydate_$i"}'|
        : "NULL";

      # get pricegroup_id and save it
      ($null, my $pricegroup_id) = split /--/, $form->{"sellprice_pg_$i"};
      $pricegroup_id *= 1;
      my $subtotal = $form->{"subtotal_$i"} * 1;

      # save detail record in invoice table
      $query = qq|INSERT INTO invoice (trans_id, parts_id, description,longdescription, qty,
                  sellprice, fxsellprice, discount, allocated, assemblyitem,
		  unit, deliverydate, project_id, serialnumber, pricegroup_id,
		  ordnumber, transdate, cusordnumber, base_qty, subtotal)
		  VALUES ($form->{id}, $form->{"id_$i"},
		  '$form->{"description_$i"}', '$form->{"longdescription_$i"}', $form->{"qty_$i"},
		  $form->{"sellprice_$i"}, $fxsellprice,
		  $form->{"discount_$i"}, $allocated, 'f',
		  '$form->{"unit_$i"}', $deliverydate, | . conv_i($form->{"project_id_$i"}, 'NULL') . qq|,
		  '$form->{"serialnumber_$i"}', '$pricegroup_id',
		  '$form->{"ordnumber_$i"}', '$form->{"transdate_$i"}', '$form->{"cusordnumber_$i"}', $baseqty, '$subtotal')|;
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
    if ($form->{type} eq "credit_note") {
      $form->{"paid_$i"} = $form->parse_amount($myconfig, $form->{"paid_$i"}) * -1;
    } else {
      $form->{"paid_$i"} = $form->parse_amount($myconfig, $form->{"paid_$i"});
    }
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

  $project_id = conv_i($form->{"globalproject_id"});

  foreach my $trans_id (keys %{ $form->{amount} }) {
    foreach my $accno (keys %{ $form->{amount}{$trans_id} }) {
      next unless ($form->{expense_inventory} =~ /$accno/);
      if (
          ($form->{amount}{$trans_id}{$accno} =
           $form->round_amount($form->{amount}{$trans_id}{$accno}, 2)
          ) != 0
        ) {
        $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
	            transdate, taxkey, project_id)
		    VALUES ($trans_id, (SELECT c.id FROM chart c
		                        WHERE c.accno = '$accno'),
		    $form->{amount}{$trans_id}{$accno}, '$form->{invdate}',
                    (SELECT taxkey_id  FROM chart WHERE accno = '$accno'), ?)|;
        do_query($form, $dbh, $query, $project_id);
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
	            transdate, taxkey, project_id)
		    VALUES ($trans_id, (SELECT id FROM chart
		                        WHERE accno = '$accno'),
		    $form->{amount}{$trans_id}{$accno}, '$form->{invdate}',
                    (SELECT taxkey_id  FROM chart WHERE accno = '$accno'), ?)|;
        do_query($form, $dbh, $query, $project_id);
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
  if (!$form->{storno}) {
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
                      transdate, taxkey, project_id)
                      VALUES ($form->{id}, (SELECT c.id FROM chart c
                                          WHERE c.accno = ?),
                      $amount, '$form->{"datepaid_$i"}',
                      (SELECT taxkey_id FROM chart WHERE accno = ?), ?)|;
          do_query($form, $dbh, $query, $form->{AR}, $form->{AR}, $project_id);
        }
  
        # record payment
        $form->{"paid_$i"} *= -1;
  
        $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate,
                    source, memo, taxkey, project_id)
                    VALUES ($form->{id}, (SELECT c.id FROM chart c
                                        WHERE c.accno = ?),
                    $form->{"paid_$i"}, '$form->{"datepaid_$i"}',
                    '$form->{"source_$i"}', '$form->{"memo_$i"}',
                    (SELECT taxkey_id FROM chart WHERE accno = ?), ?)|;
        do_query($form, $dbh, $query, $accno, $accno, $project_id);
  
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
	            transdate, cleared, fx_transaction, taxkey, project_id)
		    VALUES ($form->{id},
		           (SELECT c.id FROM chart c
		            WHERE c.accno = ?),
		    $form->{fx}{$accno}{$transdate}, '$transdate', '0', '1',
                    (SELECT taxkey_id FROM chart WHERE accno = ?), ?)|;
        do_query($form, $dbh, $query, $accno, $accno, $project_id);
      }
    }
  }

  $amount = $netamount + $tax;

  # set values which could be empty to 0
  $form->{terms}       *= 1;
  $form->{taxincluded} *= 1;
  my $datepaid = ($form->{paid})    ? qq|'$form->{datepaid}'| : "NULL";
  my $duedate  = ($form->{duedate}) ? qq|'$form->{duedate}'|  : "NULL";
  my $deliverydate =
    ($form->{deliverydate}) ? qq|'$form->{deliverydate}'| : "NULL";

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
              orddate = | . conv_dateq($form->{orddate}) . qq|,
              quodate = | . conv_dateq($form->{quodate}) . qq|,
              customer_id = $form->{customer_id},
              amount = $amount,
              netamount = $netamount,
              paid = $form->{paid},
              datepaid = $datepaid,
              duedate = $duedate,
              deliverydate = $deliverydate,
              invoice = '1',
              shippingpoint = '$form->{shippingpoint}',
              shipvia = '$form->{shipvia}',
              terms = $form->{terms},
              notes = '$form->{notes}',
              intnotes = '$form->{intnotes}',
              taxincluded = '$form->{taxincluded}',
              curr = '$form->{currency}',
              department_id = $form->{department_id},
              payment_id = $form->{payment_id},
              type = '$form->{type}',
              language_id = $form->{language_id},
              taxzone_id = $form->{taxzone_id},
              shipto_id = $form->{shipto_id},
              delivery_customer_id = $form->{delivery_customer_id},
              delivery_vendor_id = $form->{delivery_vendor_id},
              employee_id = $form->{employee_id},
              salesman_id = | . conv_i($form->{salesman_id}, 'NULL') . qq|,
              storno = '$form->{storno}',
              globalproject_id = | . conv_i($form->{"globalproject_id"}, 'NULL') . qq|,
              cp_id = | . conv_i($form->{"cp_id"}, 'NULL') . qq|
              WHERE id = $form->{id}
             |;
  $dbh->do($query) || $form->dberror($query);

  if ($form->{storno}) {
    $query = qq| update ar set paid=paid+amount where id=$form->{storno_id}|;
    $dbh->do($query) || $form->dberror($query);
    $query = qq| update ar set storno='$form->{storno}' where id=$form->{storno_id}|;
    $dbh->do($query) || $form->dberror($query);
    $query = qq§ update ar set intnotes='Rechnung storniert am $form->{invdate} ' || intnotes where id=$form->{storno_id}§;
    $dbh->do($query) || $form->dberror($query);

    $query = qq| update ar set paid=amount where id=$form->{id}|;
    $dbh->do($query) || $form->dberror($query);
  }

  $form->{pago_total} = $amount;

  # add shipto
  $form->{name} = $form->{customer};
  $form->{name} =~ s/--$form->{customer_id}//;

  if (!$form->{shipto_id}) {
    $form->add_shipto($dbh, $form->{id}, "AR");
  }

  # save printed, emailed and queued
  $form->save_status($dbh);

  Common::webdav_folder($form) if ($main::webdav);

  my $rc = $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return $rc;
}

sub post_payment {
  $main::lxdebug->enter_sub() and my ($self, $myconfig, $form, $locale) = @_;

  # connect to database, turn off autocommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  $form->{datepaid} = $form->{invdate};

  # total payments, don't move we need it here
  for my $i (1 .. $form->{paidaccounts}) {
    $form->{"paid_$i"}  = $form->parse_amount($myconfig, $form->{"paid_$i"});
    $form->{"paid_$i"} *= -1                                 if ($form->{type} eq "credit_note");
    $form->{"paid"}    += $form->{"paid_$i"};
    $form->{"datepaid"} = $form->{"datepaid_$i"}             if ($form->{"datepaid_$i"});
  }

  $form->{exchangerate} = $form->get_exchangerate($dbh, $form->{currency}, $form->{invdate}, "buy");

  # record payments and offsetting AR
  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"}) {

      my ($accno) = split /--/, $form->{"AR_paid_$i"};
      $form->{"datepaid_$i"} = $form->{invdate} unless ($form->{"datepaid_$i"});
      $form->{datepaid} = $form->{"datepaid_$i"};

      $exchangerate = 0;
      if (($form->{currency} eq $form->{defaultcurrency}) || ($form->{defaultcurrency} eq "")) {
        $form->{"exchangerate_$i"} = 1;
      } else {
        $exchangerate = $form->check_exchangerate($myconfig, $form->{currency}, $form->{"datepaid_$i"}, 'buy');
        $form->{"exchangerate_$i"} = ($exchangerate) ? $exchangerate : $form->parse_amount($myconfig, $form->{"exchangerate_$i"});
      }

      # record AR
      $amount = $form->round_amount($form->{"paid_$i"} * $form->{"exchangerate"}, 2);

      $query = qq|DELETE FROM acc_trans WHERE trans_id = ? AND chart_id = (SELECT c.id FROM chart c WHERE c.accno = ?) AND amount = ? AND transdate = ?|;
      do_query($form, $dbh, $query, $form->{id}, $form->{AR}, $amount, $form->{"datepaid_$i"});
      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, project_id, taxkey) 
                  VALUES (?, (SELECT id FROM chart WHERE accno = ?), ?, ?, ?, (SELECT taxkey_id FROM chart WHERE accno = ?))|;
      do_query($form, $dbh, $query, $form->{id}, $form->{AR}, $amount, $form->{"datepaid_$i"}, conv_i($form->{"globalproject_id"}), $accno);

      # record payment
      $form->{"paid_$i"} *= -1;

      $query = qq|DELETE FROM acc_trans WHERE trans_id = ? AND chart_id = (SELECT c.id FROM chart c WHERE c.accno = ?) AND amount = ? AND transdate = ? AND source = ? AND memo = ?|;
      do_query($form, $dbh, $query, $form->{id}, $accno, $form->{"paid_$i"}, $form->{"datepaid_$i"}, $form->{"source_$i"}, $form->{"memo_$i"});
      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, source, memo, project_id, taxkey) 
                  VALUES (?, (SELECT c.id FROM chart c WHERE c.accno = ?), ?, ?, ?, ?, ?, (SELECT taxkey_id FROM chart WHERE accno = ?))|;
      do_query($form, $dbh, $query, $form->{id}, $accno, $form->{"paid_$i"}, $form->{"datepaid_$i"}, $form->{"source_$i"}, $form->{"memo_$i"}, 
               conv_i($form->{"globalproject_id"}), $accno);

      # gain/loss
      $amount = $form->{"paid_$i"} * $form->{exchangerate} - $form->{"paid_$i"} * $form->{"exchangerate_$i"};
      $form->{fx}{ $form->{($amount > 0 ? 'fxgain_accno' : 'fxloss_accno')} }{ $form->{"datepaid_$i"} } += $amount;

      $diff = 0;

      # update exchange rate
      if (($form->{currency} ne $form->{defaultcurrency}) && !$exchangerate) {
        $form->update_exchangerate($dbh, $form->{currency}, $form->{"datepaid_$i"}, $form->{"exchangerate_$i"}, 0);
      }

    }
  }

  # record exchange rate differences and gains/losses
  foreach my $accno (keys %{ $form->{fx} }) {
    foreach my $transdate (keys %{ $form->{fx}{$accno} }) {

      if ($form->{fx}{$accno}{$transdate} = $form->round_amount($form->{fx}{$accno}{$transdate}, 2)) { # '=' is no typo, it's an assignment
        $query = qq|DELETE FROM acc_trans WHERE trans_id = ? AND chart_id = (SELECT c.id FROM chart c WHERE c.accno = ?) 
                                                AND amount = ? AND transdate = ? AND cleared = ? AND fx_transaction = ?|;
        do_query($form, $dbh, $query, $form->{id}, $accno, $form->{fx}{$accno}{$transdate}, $transdate, 0, 1);
        $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, cleared, fx_transaction, project_id, taxkey)
		                   VALUES (?, (SELECT c.id FROM chart c WHERE c.accno = ?), ?, ?, ?, ?, ?, (SELECT taxkey_id FROM chart WHERE accno = ?))|;
        do_query($form, $dbh, $query, $form->{id}, $accno, $form->{fx}{$accno}{$transdate}, $transdate, 0, 1, conv_i($form->{"globalproject_id"}), $accno);
      }

    }
  }

  # save AR record
  delete $form->{datepaid} unless $form->{paid};

  my $query = qq|UPDATE ar set paid = ?, datepaid = ? WHERE id = ?|;
  do_query($form, $dbh, $query, $form->{paid}, $form->{datepaid}, $form->{id});

  my $rc = $dbh->commit;
  $dbh->disconnect;

  $main::lxdebug->leave_sub() and return $rc;
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

  my ($dbh, $form, $id, $totalqty, $basefactor, $row) = @_;
  $form->{taxzone_id} *=1;
  my $transdate = ($form->{invdate}) ? "'$form->{invdate}'" : "current_date";
  my $query = qq|SELECT i.id, i.trans_id, i.base_qty, i.allocated, i.sellprice,
                        c1.accno AS inventory_accno, c1.new_chart_id AS inventory_new_chart, date($transdate) - c1.valid_from as inventory_valid,
			c2.accno AS income_accno, c2.new_chart_id AS income_new_chart, date($transdate)  - c2.valid_from as income_valid,
			c3.accno AS expense_accno, c3.new_chart_id AS expense_new_chart, date($transdate) - c3.valid_from as expense_valid
		  FROM invoice i, parts p
                  LEFT JOIN chart c1 ON ((select inventory_accno_id from buchungsgruppen where id=p.buchungsgruppen_id) = c1.id)
                  LEFT JOIN chart c2 ON ((select income_accno_id_$form->{taxzone_id} from buchungsgruppen where id=p.buchungsgruppen_id) = c2.id)
                  LEFT JOIN chart c3 ON ((select expense_accno_id_$form->{taxzone_id} from buchungsgruppen where id=p.buchungsgruppen_id) = c3.id)
		  WHERE i.parts_id = p.id
		  AND i.parts_id = $id
		  AND (i.base_qty + i.allocated) < 0
		  ORDER BY trans_id|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $allocated = 0;
  my $qty;

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    if (($qty = (($ref->{base_qty} * -1) - $ref->{allocated})) > $totalqty) {
      $qty = $totalqty;
    }

    $form->update_balance($dbh, "invoice", "allocated", qq|id = $ref->{id}|,
                          $qty);

    # total expenses and inventory
    # sellprice is the cost of the item
    $linetotal = $form->round_amount(($ref->{sellprice} * $qty) / $basefactor, 2);

    if (!$main::eur) {
      $ref->{expense_accno} = ($form->{"expense_accno_$row"}) ? $form->{"expense_accno_$row"} : $ref->{expense_accno};
      # add to expense
      $form->{amount}{ $form->{id} }{ $ref->{expense_accno} } += -$linetotal;
      $form->{expense_inventory} .= " " . $ref->{expense_accno};
      $ref->{inventory_accno} = ($form->{"inventory_accno_$row"}) ? $form->{"inventory_accno_$row"} : $ref->{inventory_accno};
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
              WHERE trans_id = $form->{id} AND module = 'AR'|;
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
                a.orddate, a.quodate, a.globalproject_id,
                a.transdate AS invdate, a.deliverydate, a.paid, a.storno, a.gldate,
                a.shippingpoint, a.shipvia, a.terms, a.notes, a.intnotes, a.taxzone_id,
		a.duedate, a.taxincluded, a.curr AS currency, a.shipto_id, a.cp_id,
		a.employee_id, e.name AS employee, a.salesman_id, a.payment_id, a.language_id, a.delivery_customer_id, a.delivery_vendor_id, a.type
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
                WHERE s.trans_id = $form->{id} AND s.module = 'AR'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    delete($ref->{id});
    map { $form->{$_} = $ref->{$_} } keys %$ref;
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

    my $transdate =
      $form->{deliverydate} ? $dbh->quote($form->{deliverydate}) :
      $form->{invdate} ? $dbh->quote($form->{invdate}) :
      "current_date";

    if (!$form->{taxzone_id}) {
      $form->{taxzone_id} = 0;
    }
    # retrieve individual items
    $query = qq|SELECT  
                c1.accno AS inventory_accno, c1.new_chart_id AS inventory_new_chart, date($transdate) - c1.valid_from as inventory_valid,
	        c2.accno AS income_accno, c2.new_chart_id AS income_new_chart, date($transdate)  - c2.valid_from as income_valid,
		c3.accno AS expense_accno, c3.new_chart_id AS expense_new_chart, date($transdate) - c3.valid_from as expense_valid,
                i.description, i.longdescription, i.qty, i.fxsellprice AS sellprice,
		i.discount, i.parts_id AS id, i.unit, i.deliverydate,
		i.project_id, pr.projectnumber, i.serialnumber,
		p.partnumber, p.assembly, p.bin, p.notes AS partnotes, p.inventory_accno_id AS part_inventory_accno_id, i.id AS invoice_pos,
		pg.partsgroup, i.pricegroup_id, (SELECT pricegroup FROM pricegroup WHERE id=i.pricegroup_id) as pricegroup,
		i.ordnumber, i.transdate, i.cusordnumber, p.formel, i.subtotal
		FROM invoice i
	        JOIN parts p ON (i.parts_id = p.id)
	        LEFT JOIN project pr ON (i.project_id = pr.id)
	        LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		LEFT JOIN chart c1 ON ((select inventory_accno_id from buchungsgruppen where id=p.buchungsgruppen_id) = c1.id)
		LEFT JOIN chart c2 ON ((select income_accno_id_$form->{taxzone_id} from buchungsgruppen where id=p.buchungsgruppen_id) = c2.id)
		LEFT JOIN chart c3 ON ((select expense_accno_id_$form->{taxzone_id} from buchungsgruppen where id=p.buchungsgruppen_id) = c3.id)
        	WHERE i.trans_id = $form->{id}
		AND NOT i.assemblyitem = '1'
		ORDER BY i.id|;
    $sth = $dbh->prepare($query);

    $sth->execute || $form->dberror($query);
    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
      if (!$ref->{"part_inventory_accno_id"}) {
        map({ delete($ref->{$_}); } qw(inventory_accno inventory_new_chart inventory_valid));
      }
      delete($ref->{"part_inventory_accno_id"});

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
      my $i=0;
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
      if ($form->{type} eq "credit_note") {
        $ref->{qty} *= -1;
      }

      chop $ref->{taxaccounts};
      push @{ $form->{invoice_details} }, $ref;
      $stw->finish;
    }
    $sth->finish;

    Common::webdav_folder($form) if ($main::webdav);
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
                 c.email, c.cc, c.bcc, c.language_id, c.payment_id AS customer_payment_id,
		 c.street, c.zipcode, c.city, c.country,
	         $duedate + COALESCE(pt.terms_netto, 0) AS duedate, c.notes AS intnotes,
		 b.discount AS tradediscount, b.description AS business, c.klass as customer_klass, c.taxzone_id,
                 c.salesman_id
                 FROM customer c
		 LEFT JOIN business b ON (b.id = c.business_id)
                 LEFT JOIN payment_terms pt ON c.payment_id = pt.id
	         WHERE c.id = ?|;
  $ref = selectfirst_hashref_query($form, $dbh, $query, $form->{customer_id});
  map { $form->{$_} = $ref->{$_} } keys %$ref;

  my $query = qq|SELECT sum(a.amount - a.paid) AS dunning_amount FROM ar a 
                 WHERE a.paid < a.amount AND a.customer_id = ? AND a.dunning_config_id IS NOT NULL|;
  $ref = selectfirst_hashref_query($form, $dbh, $query, $form->{customer_id});
  map { $form->{$_} = $ref->{$_} } keys %$ref;

  my $query = qq|SELECT dnn.dunning_description AS max_dunning_level FROM dunning_config dnn 
                 WHERE id in (SELECT dunning_config_id from ar WHERE paid < amount AND customer_id = ? AND dunning_config_id IS NOT NULL)
                 ORDER BY dunning_level DESC LIMIT 1|;
  $ref = selectfirst_hashref_query($form, $dbh, $query, $form->{customer_id});
  map { $form->{$_} = $ref->{$_} } keys %$ref;

  #check whether payment_terms are better than old payment_terms
  if (($form->{payment_id} ne "") && ($form->{customer_payment_id} ne "")) {
    my $query = qq|SELECT (SELECT ranking from payment_terms WHERE id = $form->{payment_id}), (SELECT ranking FROM payment_terms WHERE id = $form->{customer_payment_id})|;
    my $stw = $dbh->prepare($query);
    $stw->execute || $form->dberror($query);
    ($old_ranking, $new_ranking) = $stw->fetchrow_array;
    $stw->finish;
    if ($new_ranking > $old_ranking) {
      $form->{payment_id} =$form->{customer_payment_id};
    }
  }
  if ($form->{payment_id} eq "") {
    $form->{payment_id} =$form->{customer_payment_id};
  }

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

  # get shipto if we did not converted an order or invoice
  if (!$form->{shipto}) {
    map { delete $form->{$_} }
      qw(shiptoname shiptodepartment_1 shiptodepartment_2 shiptostreet shiptozipcode shiptocity shiptocountry shiptocontact shiptophone shiptofax shiptoemail);

    $query = qq|SELECT s.* FROM shipto s
                WHERE s.trans_id = $form->{customer_id} AND s.module = 'CT'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    undef($ref->{id});
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
    $query = qq|SELECT c.id, c.accno, c.description, c.link, c.category
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

        if ($form->{initial_transdate}) {
          my $tax_query =
            qq|SELECT tk.tax_id, t.rate FROM taxkeys tk | .
            qq|LEFT JOIN tax t ON tk.tax_id = t.id | .
            qq|WHERE tk.chart_id = ? AND startdate <= ? | .
            qq|ORDER BY tk.startdate DESC LIMIT 1|;
          my ($tax_id, $rate) =
            selectrow_query($form, $dbh, $tax_query, $ref->{id},
                            $form->{initial_transdate});
          $form->{"taxchart_$i"} = "${tax_id}--${rate}";
        }
      }
      if ($ref->{category} eq 'A') {
        $form->{ARselected} = $form->{AR_1} = $ref->{accno};
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

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

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

  my $transdate;
  if ($form->{type} eq "invoice") {
    $transdate =
      $form->{deliverydate} ? $dbh->quote($form->{deliverydate}) :
      $form->{invdate} ? $dbh->quote($form->{invdate}) :
      "current_date";
  } else {
    $transdate =
      $form->{transdate} ? $dbh->quote($form->{transdate}) :
      "current_date";
  }

  my $query = qq|SELECT p.id, p.partnumber, p.description, p.sellprice,
                        p.listprice, p.inventory_accno_id,
                        c1.accno AS inventory_accno, c1.new_chart_id AS inventory_new_chart, date($transdate) - c1.valid_from as inventory_valid,
			c2.accno AS income_accno, c2.new_chart_id AS income_new_chart, date($transdate)  - c2.valid_from as income_valid,
			c3.accno AS expense_accno, c3.new_chart_id AS expense_new_chart, date($transdate) - c3.valid_from as expense_valid,
		 p.unit, p.assembly, p.bin, p.onhand, p.notes AS partnotes, p.notes AS longdescription, p.not_discountable,
		 pg.partsgroup, p.formel, p.payment_id AS part_payment_id
                 FROM parts p
		 LEFT JOIN chart c1 ON ((select inventory_accno_id from buchungsgruppen where id=p.buchungsgruppen_id) = c1.id)
		 LEFT JOIN chart c2 ON ((select income_accno_id_$form->{taxzone_id} from buchungsgruppen where id=p.buchungsgruppen_id) = c2.id)
		 LEFT JOIN chart c3 ON ((select expense_accno_id_$form->{taxzone_id} from buchungsgruppen where id=p.buchungsgruppen_id) = c3.id)
		 LEFT JOIN partsgroup pg ON (pg.id = p.partsgroup_id)
	         WHERE $where|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {

    # In der Buchungsgruppe ist immer ein Bestandskonto verknuepft, auch wenn
    # es sich um eine Dienstleistung handelt. Bei Dienstleistungen muss das
    # Buchungskonto also aus dem Ergebnis rausgenommen werden.
    if (!$ref->{inventory_accno_id}) {
      map({ delete($ref->{"inventory_${_}"}); } qw(accno new_chart valid));
    }
    delete($ref->{inventory_accno_id});

    #set expense_accno=inventory_accno if they are different => bilanz


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

    #check whether payment_terms are better than old payment_terms
    if (($form->{payment_id} ne "") && ($ref->{part_payment_id} ne "")) {
      my $query = qq|select (select ranking from payment_terms WHERE id = $form->{payment_id}), (select ranking from payment_terms WHERE id = $ref->{part_payment_id})|;
      my $stw = $dbh->prepare($query);
      $stw->execute || $form->dberror($query);
      ($old_ranking, $new_ranking) = $stw->fetchrow_array;
      $stw->finish;
      if ($new_ranking <= $old_ranking) {
        $ref->{part_payment_id} = "";
      }
    }

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

    $stw->finish;
    chop $ref->{taxaccounts};
    if ($form->{language_id}) {
      $query = qq|SELECT tr.translation, tr.longdescription
                FROM translation tr
                WHERE tr.language_id=$form->{language_id} AND tr.parts_id=$ref->{id}|;
      $stw = $dbh->prepare($query);
      $stw->execute || $form->dberror($query);
      my ($translation, $longdescription) = $stw->fetchrow_array();
      if ($translation ne "") {
        $ref->{description} = $translation;
        $ref->{longdescription} = $longdescription;

      } else {
        $query = qq|SELECT tr.translation, tr.longdescription
                FROM translation tr
                WHERE tr.language_id in (select id from language where article_code=(select article_code from language where id = $form->{language_id})) AND tr.parts_id=$ref->{id} LIMIT 1|;
        $stg = $dbh->prepare($query);
        $stg->execute || $form->dberror($query);
        my ($translation) = $stg->fetchrow_array();
        if ($translation ne "") {
          $ref->{description} = $translation;
          $ref->{longdescription} = $longdescription;
        }
        $stg->finish;
      }
      $stw->finish;
    }

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

  $form->{"PRICES"} = {};

  my $i  = 1;
  my $id = 0;
  my $dimension_units = AM->retrieve_units($myconfig, $form, "dimension");
  my $service_units = AM->retrieve_units($myconfig, $form, "service");
  my $all_units = AM->retrieve_units($myconfig, $form);
  while (($form->{"id_$i"}) or ($form->{"new_id_$i"})) {
    $form->{"PRICES"}{$i} = [];

    $id = $form->{"id_$i"};

    if (!($form->{"id_$i"}) and $form->{"new_id_$i"}) {

      $id = $form->{"new_id_$i"};
    }

    ($price, $selectedpricegroup_id) = split /--/,
      $form->{"sellprice_pg_$i"};

    $pricegroup_old = $form->{"pricegroup_old_$i"};
    $form->{"new_pricegroup_$i"} = $selectedpricegroup_id;
    $form->{"old_pricegroup_$i"} = $pricegroup_old;
    $price_new = $form->{"price_new_$i"};

    $price_old = $form->{"price_old_$i"};
    $query =
      qq|SELECT pricegroup_id, (SELECT p.sellprice from parts p where p.id = $id) as default_sellprice,(SELECT pg.pricegroup FROM pricegroup pg WHERE id=pricegroup_id) AS pricegroup, price, '' AS selected FROM prices WHERE parts_id = $id UNION SELECT 0 as pricegroup_id,(SELECT sellprice FROM parts WHERE id=$id) as default_sellprice,'' as pricegroup, (SELECT DISTINCT sellprice from parts where id=$id) as price, 'selected' AS selected from prices ORDER BY pricegroup|;

    $pkq = $dbh->prepare($query);
    $pkq->execute || $form->dberror($query);
    if (!$form->{"unit_old_$i"}) {
      # Neue Ware aus der Datenbank. In diesem Fall ist unit_$i die
      # Einheit, wie sie in den Stammdaten hinterlegt wurde.
      # Es sollte also angenommen werden, dass diese ausgewaehlt war.
      $form->{"unit_old_$i"} = $form->{"unit_$i"};
    }
 
    # Die zuletzt ausgewaehlte mit der aktuell ausgewaehlten Einheit
    # vergleichen und bei Unterschied den Preis entsprechend umrechnen.
    $form->{"selected_unit_$i"} = $form->{"unit_$i"} unless ($form->{"selected_unit_$i"});

    my $check_units = $form->{"inventory_accno_$i"} ? $dimension_units : $service_units;
    if (!$check_units->{$form->{"selected_unit_$i"}} ||
        ($check_units->{$form->{"selected_unit_$i"}}->{"base_unit"} ne
         $all_units->{$form->{"unit_old_$i"}}->{"base_unit"})) {
      # Die ausgewaehlte Einheit ist fuer diesen Artikel nicht gueltig
      # (z.B. Dimensionseinheit war ausgewaehlt, es handelt sich aber
      # um eine Dienstleistung). Dann keinerlei Umrechnung vornehmen.
      $form->{"unit_old_$i"} = $form->{"selected_unit_$i"} = $form->{"unit_$i"};
    }
    my $basefactor = 1;
    
    if ($form->{"unit_old_$i"} ne $form->{"selected_unit_$i"}) {
      if (defined($all_units->{$form->{"unit_old_$i"}}->{"factor"}) &&
          $all_units->{$form->{"unit_old_$i"}}->{"factor"}) {
        $basefactor = $all_units->{$form->{"selected_unit_$i"}}->{"factor"} /
          $all_units->{$form->{"unit_old_$i"}}->{"factor"};
      }
    }
    if (!$form->{"basefactor_$i"}) {
      $form->{"basefactor_$i"} = 1;
    }
    while ($pkr = $pkq->fetchrow_hashref(NAME_lc)) {

      #       push @{ $form->{PRICES}{$id} }, $pkr;
      #push @{ $form->{PRICES}{$i} }, $pkr;
      $pkr->{id}       = $id;
      $pkr->{selected} = '';

      # if there is an exchange rate change price
      if (($form->{exchangerate} * 1) != 0) {

        $pkr->{price} /= $form->{exchangerate};
      }

      $pkr->{price} *= $form->{"basefactor_$i"};
      
      $pkr->{price} *= $basefactor;
 
      $pkr->{price} = $form->format_amount($myconfig, $pkr->{price}, 5);

      if ($selectedpricegroup_id eq undef) {
        if ($pkr->{pricegroup_id} eq $form->{customer_klass}) {

          $pkr->{selected}  = ' selected';

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
            $pkr->{selected}  = ' selected';
          }
        } else {
          if (($price_new != $form->{"sellprice_$i"}) and ($price_new ne 0)) {
            if ($pkr->{pricegroup_id} == 0) {
              $pkr->{price}     = $form->{"sellprice_$i"};
              $pkr->{selected}  = ' selected';
            }
          } else {
            if ($pkr->{pricegroup_id} eq $selectedpricegroup_id) {
              $pkr->{selected}  = ' selected';
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
      push @{ $form->{PRICES}{$i} }, $pkr;

    }
    $form->{"basefactor_$i"} *= $basefactor;

    $i++;

    $pkq->finish;
  }

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub has_storno {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $table) = @_;

  $main::lxdebug->leave_sub() and return 0 unless ($form->{id});

  # make sure there's no funny stuff in $table
  # ToDO: die when this happens and throw an error
  $main::lxdebug->leave_sub() and return 0 if ($table =~ /\W/);

  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT storno FROM $table WHERE id = ?|;
  my ($result) = selectrow_query($form, $dbh, $query, $form->{id});

  $dbh->disconnect();

  $main::lxdebug->leave_sub();

  return $result;
}

1;

