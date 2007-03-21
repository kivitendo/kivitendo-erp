# #=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger, Accounting
# Copyright (c) 1998-2003
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
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
# Quotation module
#======================================================================
use Data::Dumper;

use SL::OE;
use SL::IR;
use SL::IS;
use SL::PE;

require "$form->{path}/io.pl";
require "$form->{path}/arap.pl";

1;

# end of main

# For locales.pl:
# $locale->text('Edit the purchase_order');
# $locale->text('Edit the sales_order');
# $locale->text('Edit the request_quotation');
# $locale->text('Edit the sales_quotation');

# $locale->text('Workflow purchase_order');
# $locale->text('Workflow sales_order');
# $locale->text('Workflow request_quotation');
# $locale->text('Workflow sales_quotation');

sub set_headings {
  $lxdebug->enter_sub();

  my ($action) = @_;

  if ($form->{type} eq 'purchase_order') {
    $form->{title}   = $action eq "edit" ?
      $locale->text('Edit Purchase Order') :
      $locale->text('Add Purchase Order');
    $form->{heading} = $locale->text('Purchase Order');
    $form->{vc}      = 'vendor';
  }
  if ($form->{type} eq 'sales_order') {
    $form->{title}   = $action eq "edit" ?
      $locale->text('Edit Sales Order') :
      $locale->text('Add Sales Order');
    $form->{heading} = $locale->text('Sales Order');
    $form->{vc}      = 'customer';
  }
  if ($form->{type} eq 'request_quotation') {
    $form->{title}   = $action eq "edit" ?
      $locale->text('Edit Request for Quotation') :
      $locale->text('Add Request for Quotation');
    $form->{heading} = $locale->text('Request for Quotation');
    $form->{vc}      = 'vendor';
  }
  if ($form->{type} eq 'sales_quotation') {
    $form->{title}   = $action eq "edit" ?
      $locale->text('Edit Quotation') :
      $locale->text('Add Quotation');
    $form->{heading} = $locale->text('Quotation');
    $form->{vc}      = 'customer';
  }

  $lxdebug->leave_sub();
}

sub add {
  $lxdebug->enter_sub();

  set_headings("add");

  $form->{callback} =
    "$form->{script}?action=add&type=$form->{type}&vc=$form->{vc}&login=$form->{login}&path=$form->{path}&password=$form->{password}"
    unless $form->{callback};

  &order_links;
  &prepare_order;
  &display_form;

  $lxdebug->leave_sub();
}

sub edit {
  $lxdebug->enter_sub();
  # show history button
  $form->{javascript} = qq|<script type="text/javascript" src="js/show_history.js"></script>|;
  #/show hhistory button

  $form->{simple_save} = 0;

  set_headings("edit");

  # editing without stuff to edit? try adding it first
  if ($form->{rowcount}) {
    map { $id++ if $form->{"id_$_"} } (1 .. $form->{rowcount});
    if (!$id) {

      # reset rowcount
      undef $form->{rowcount};
      &add;
      return;
    }
  } else {
    if (!$form->{id}) {
      &add;
      return;
    }
  }

  if ($form->{print_and_save}) {
    $form->{action}   = "print";
    $form->{resubmit} = 1;
    $language_id = $form->{language_id};
    $printer_id = $form->{printer_id};
  }

  set_headings("edit");

  &order_links;
  &prepare_order;
  if ($form->{print_and_save}) {
    $form->{language_id} = $language_id;
    $form->{printer_id} = $printer_id;
  }
  &display_form;

  $lxdebug->leave_sub();
}

sub order_links {
  $lxdebug->enter_sub();

  # get customer/vendor
  $form->all_vc(\%myconfig, $form->{vc},
                ($form->{vc} eq 'customer') ? "AR" : "AP");

  # retrieve order/quotation
  $form->{webdav} = $webdav;
  # set jscalendar
  $form->{jscalendar} = $jscalendar;

  OE->retrieve(\%myconfig, \%$form);

  if ($form->{payment_id}) {
    $payment_id = $form->{payment_id};
  }
  if ($form->{language_id}) {
    $language_id = $form->{language_id};
  }
  if ($form->{taxzone_id}) {
    $taxzone_id = $form->{taxzone_id};
  }


  # if multiple rowcounts (== collective order) then check if the
  # there were more than one customer (in that case OE::retrieve removes
  # the content from the field)
  if (   $form->{rowcount}
      && $form->{type} eq 'sales_order'
      && defined $form->{customer}
      && $form->{customer} eq '') {

    #    $main::lxdebug->message(0, "Detected Edit order with concurrent customers");
    $form->error(
                 $locale->text(
                   'Collective Orders only work for orders from one customer!')
    );
  }

  $taxincluded = $form->{taxincluded};
  $form->{shipto} = 1 if $form->{id};

  if ($form->{"all_$form->{vc}"}) {
    unless ($form->{"$form->{vc}_id"}) {
      $form->{"$form->{vc}_id"} = $form->{"all_$form->{vc}"}->[0]->{id};
    }
  }

  $cp_id    = $form->{cp_id};
  $intnotes = $form->{intnotes};

  # get customer / vendor
  if ($form->{type} =~ /(purchase_order|request_quotation)/) {
    IR->get_vendor(\%myconfig, \%$form);

    #quote all_vendor Bug 133
    foreach $ref (@{ $form->{all_vendor} }) {
      $ref->{name} = $form->quote($ref->{name});
    }

  }
  if ($form->{type} =~ /sales_(order|quotation)/) {
    IS->get_customer(\%myconfig, \%$form);

    #quote all_vendor Bug 133
    foreach $ref (@{ $form->{all_customer} }) {
      $ref->{name} = $form->quote($ref->{name});
    }

  }
  $form->{cp_id} = $cp_id;
  if ($payment_id) {
    $form->{payment_id} = $payment_id;
  }
  if ($language_id) {
    $form->{language_id} = $language_id;
  }
  if ($taxzone_id) {
    $form->{taxzone_id} = $taxzone_id;
  }
  $form->{intnotes} = $intnotes;
  ($form->{ $form->{vc} }) = split /--/, $form->{ $form->{vc} };
  $form->{"old$form->{vc}"} =
    qq|$form->{$form->{vc}}--$form->{"$form->{vc}_id"}|;

  # build the popup menus
  if (@{ $form->{"all_$form->{vc}"} }) {
    $form->{ $form->{vc} } =
      qq|$form->{$form->{vc}}--$form->{"$form->{vc}_id"}|;
    map { $form->{"select$form->{vc}"} .= "<option>$_->{name}--$_->{id}\n" }
      (@{ $form->{"all_$form->{vc}"} });
  }

  # currencies
  @curr = split(/:/, $form->{currencies});
  chomp $curr[0];
  $form->{defaultcurrency} = $curr[0];
  $form->{currency}        = $form->{defaultcurrency} unless $form->{currency};

  map { $form->{selectcurrency} .= "<option>$_\n" } @curr;

  $form->{taxincluded} = $taxincluded if ($form->{id});

  # departments
  if (@{ $form->{all_departments} }) {
    $form->{selectdepartment} = "<option>\n";
    $form->{department}       = "$form->{department}--$form->{department_id}";

    map {
      $form->{selectdepartment} .=
        "<option>$_->{description}--$_->{id}\n"
    } (@{ $form->{all_departments} });
  }

  $form->{employee} = "$form->{employee}--$form->{employee_id}";

  # sales staff
  if (@{ $form->{all_employees} }) {
    $form->{selectemployee} = "";
    map { $form->{selectemployee} .= "<option>$_->{name}--$_->{id}\n" }
      (@{ $form->{all_employees} });
  }

  # forex
  $form->{forex} = $form->{exchangerate};

  $lxdebug->leave_sub();
}

sub prepare_order {
  $lxdebug->enter_sub();
  $form->{formname} = $form->{type} unless $form->{formname};

  my $i = 0;
  foreach $ref (@{ $form->{form_details} }) {
    $form->{rowcount} = ++$i;

    map { $form->{"${_}_$i"} = $ref->{$_} } keys %{$ref};
  }
  for my $i (1 .. $form->{rowcount}) {
    if ($form->{id}) {
      $form->{"discount_$i"} =
        $form->format_amount(\%myconfig, $form->{"discount_$i"} * 100);
    } else {
      $form->{"discount_$i"} =
        $form->format_amount(\%myconfig, $form->{"discount_$i"});
    }
    ($dec) = ($form->{"sellprice_$i"} =~ /\.(\d+)/);
    $dec           = length $dec;
    $decimalplaces = ($dec > 2) ? $dec : 2;

    # copy reqdate from deliverydate for invoice -> order conversion
    $form->{"reqdate_$i"} = $form->{"deliverydate_$i"}
      unless $form->{"reqdate_$i"};

    $form->{"sellprice_$i"} =
      $form->format_amount(\%myconfig, $form->{"sellprice_$i"},
                           $decimalplaces);

    (my $dec_qty) = ($form->{"qty_$i"} =~ /\.(\d+)/);
    $dec_qty = length $dec_qty;
    $form->{"qty_$i"} =
      $form->format_amount(\%myconfig, $form->{"qty_$i"}, $dec_qty);

    map { $form->{"${_}_$i"} =~ s/\"/&quot;/g }
      qw(partnumber description unit);
  }

  $lxdebug->leave_sub();
}

sub form_header {
  $lxdebug->enter_sub();

  my $checkedclosed = $form->{"closed"} ? "checked" : "";
  my $checkeddelivered = $form->{"delivered"} ? "checked" : "";

  map { $form->{$_} =~ s/\"/&quot;/g }
    qw(ordnumber quonumber shippingpoint shipvia notes intnotes shiptoname
       shiptostreet shiptozipcode shiptocity shiptocountry shiptocontact
       shiptophone shiptofax shiptodepartment_1 shiptodepartment_2);

  # use JavaScript Calendar or not
  $form->{jsscript} = $form->{jscalendar};
  $jsscript = "";

  $payment = qq|<option value=""></option>|;
  foreach $item (@{ $form->{payment_terms} }) {
    if ($form->{payment_id} eq $item->{id}) {
      $payment .= qq|<option value="$item->{id}" selected>$item->{description}</option>|;
    } else {
      $payment .= qq|<option value="$item->{id}">$item->{description}</option>|;
    }
  }
  if ($form->{jsscript}) {

    # with JavaScript Calendar
    $button1 = qq|
       <td><input name=transdate id=transdate size=11 title="$myconfig{dateformat}" value=$form->{transdate}></td>
       <td><input type=button name=transdate id="trigger1" value=|
      . $locale->text('button') . qq|></td>
      |;
    $button2 = qq|
       <td width="13"><input name=reqdate id=reqdate size=11 title="$myconfig{dateformat}" value=$form->{reqdate}></td>
       <td width="4"><input type=button name=reqdate name=reqdate id="trigger2" value=|
      . $locale->text('button') . qq|></td>
     |;

    #write Trigger
    $jsscript =
      Form->write_trigger(\%myconfig, "2", "transdate", "BL", "trigger1",
                          "reqdate", "BL", "trigger2");

  } else {

    # without JavaScript Calendar
    $button1 = qq|
                              <td><input name=transdate id=transdate size=11 title="$myconfig{dateformat}" value=$form->{transdate}></td>|;
    $button2 = qq|
                              <td width="13"><input name=reqdate id=reqdate size=11 title="$myconfig{dateformat}" value=$form->{reqdate}></td>|;
  }

  if ($form->{id}) {
    $openclosed = qq|
      <tr>
        <td colspan=2 align=center>
          <input name="closed" id="closed" type="checkbox" class="checkbox" value="1" $checkedclosed>
          <label for="closed">| . $locale->text('Closed') . qq|</label>
|;

    if (($form->{"type"} eq "sales_order") ||
        ($form->{"type"} eq "purchase_order")) {
      $openclosed .= qq|
          <input name="delivered" id="delivered" type="checkbox" class="checkbox" value="1" $checkeddelivered>
          <label for="delivered">| . $locale->text('Delivered') . qq|</label>
|;
    }

    $openclosed .= qq|
        </td>
      </tr>
|;
  }

  # set option selected
  foreach $item ($form->{vc}, currency, department, employee) {
    $form->{"select$item"} =~ s/ selected//;
    $form->{"select$item"} =~
      s/option>\Q$form->{$item}\E/option selected>$form->{$item}/;
  }

  #quote select[customer|vendor] Bug 133
  $form->{"select$form->{vc}"} = $form->quote($form->{"select$form->{vc}"});

  my @old_project_ids = ($form->{"globalproject_id"});
  map({ push(@old_project_ids, $form->{"project_id_$_"})
          if ($form->{"project_id_$_"}); } (1..$form->{"rowcount"}));

  $form->get_lists("contacts" => "ALL_CONTACTS",
                   "shipto" => "ALL_SHIPTO",
                   "projects" => { "key" => "ALL_PROJECTS",
                                   "all" => 0,
                                   "old_id" => \@old_project_ids });

  my (%labels, @values);
  foreach my $item (@{ $form->{"ALL_CONTACTS"} }) {
    push(@values, $item->{"cp_id"});
    $labels{$item->{"cp_id"}} = $item->{"cp_name"} .
      ($item->{"cp_abteilung"} ? " ($item->{cp_abteilung})" : "");
  }
  my $contact =
    NTI($cgi->popup_menu('-name' => 'cp_id', '-values' => \@values,
                         '-labels' => \%labels, '-default' => $form->{"cp_id"}));

  %labels = ();
  @values = ("");
  foreach my $item (@{ $form->{"ALL_SHIPTO"} }) {
    push(@values, $item->{"shipto_id"});
    $labels{$item->{"shipto_id"}} =
      $item->{"shiptoname"} . " " . $item->{"shiptodepartment_1"};
  }

  my $shipto = qq|
		<th align=right>| . $locale->text('Shipping Address') . qq|</th>
		<td>| .
    NTI($cgi->popup_menu('-name' => 'shipto_id', '-values' => \@values,
                         '-labels' => \%labels, '-default' => $form->{"shipto_id"}))
    . qq|</td>|;

  %labels = ();
  @values = ("");
  foreach my $item (@{ $form->{"ALL_PROJECTS"} }) {
    push(@values, $item->{"id"});
    $labels{$item->{"id"}} = $item->{"projectnumber"};
  }
  my $globalprojectnumber =
    NTI($cgi->popup_menu('-name' => 'globalproject_id', '-values' => \@values,
                         '-labels' => \%labels,
                         '-default' => $form->{"globalproject_id"}));

  $form->{exchangerate} =
    $form->format_amount(\%myconfig, $form->{exchangerate});

  if (($form->{creditlimit} != 0) && ($form->{creditremaining} < 0) && !$form->{update}) {
    $creditwarning = 1;
  } else {
    $creditwarning = 0;
  }

  $form->{creditlimit} =
    $form->format_amount(\%myconfig, $form->{creditlimit}, 0, "0");
  $form->{creditremaining} =
    $form->format_amount(\%myconfig, $form->{creditremaining}, 0, "0");

  $exchangerate = qq|
<input type=hidden name=forex value=$form->{forex}>
|;

  if ($form->{currency} ne $form->{defaultcurrency}) {
    if ($form->{forex}) {
      $exchangerate .=
          qq|<th align=right>|
        . $locale->text('Exchangerate')
        . qq|</th><td>$form->{exchangerate}</td>
      <input type=hidden name=exchangerate value=$form->{exchangerate}>
|;
    } else {
      $exchangerate .=
          qq|<th align=right>|
        . $locale->text('Exchangerate')
        . qq|</th><td><input name=exchangerate size=10 value=$form->{exchangerate}></td>|;
    }
  }

  $vclabel = ucfirst $form->{vc};
  $vclabel = $locale->text($vclabel);



  if ($form->{business}) {
    $business = qq|
	      <tr>
		<th align=right>| . $locale->text('Business') . qq|</th>
		<td>$form->{business}</td>
		<th align=right>| . $locale->text('Trade Discount') . qq|</th>
		<td>|
      . $form->format_amount(\%myconfig, $form->{tradediscount} * 100)
      . qq| %</td>
	      </tr>
|;
  }

  if ($form->{max_dunning_level}) {
    $dunning = qq|
	      <tr>
                <td colspan=4>
                <table>
                  <tr>
		<th align=right>| . $locale->text('Max. Dunning Level') . qq|:</th>
		<td><b>$form->{max_dunning_level}</b></td>
		<th align=right>| . $locale->text('Dunning Amount') . qq|:</th>
		<td><b>|
      . $form->format_amount(\%myconfig, $form->{dunning_amount},2)
      . qq|</b></td>
	      </tr>
              </table>
             </td>
            </tr>
|;
  }

  if (@{ $form->{TAXZONE} }) {
    $form->{selecttaxzone} = "";
    foreach $item (@{ $form->{TAXZONE} }) {
      if ($item->{id} == $form->{taxzone_id}) {
        $form->{selecttaxzone} .=
          "<option value=$item->{id} selected>" . H($item->{description}) .
          "</option>";
      } else {
        $form->{selecttaxzone} .=
          "<option value=$item->{id}>" . H($item->{description}) . "</option>";
      }

    }
  } else {
    $form->{selecttaxzone} =~ s/ selected//g;
    if ($form->{taxzone_id} ne "") {
      $form->{selecttaxzone} =~ s/value=$form->{taxzone_id}>/value=$form->{taxzone_id} selected>/;
    }
  }

  $taxzone = qq|
	      <tr>
		<th align=right>| . $locale->text('Steuersatz') . qq|</th>
		<td><select name=taxzone_id>$form->{selecttaxzone}</select></td>
		<input type=hidden name=selecttaxzone value="$form->{selecttaxzone}">
	      </tr>|;


  if ($form->{type} !~ /_quotation$/) {
    $ordnumber = qq|
	      <tr>
		<th width=70% align=right nowrap>| . $locale->text('Order Number') . qq|</th>
                <td><input name=ordnumber size=11 value="$form->{ordnumber}"></td>
	      </tr>
	      <tr>
		<th width=70% align=right nowrap>|
      . $locale->text('Quotation Number') . qq|</th>
                <td><input name=quonumber size=11 value="$form->{quonumber}"></td>
	      </tr>
              <tr>
		<th width=70% align=right nowrap>|
      . $locale->text('Customer Order Number') . qq|</th>
                <td><input name=cusordnumber size=11 value="$form->{cusordnumber}"></td>
	      </tr>
	      <tr>
		<th align=right nowrap>| . $locale->text('Order Date') . qq|</th>
                $button1

	      </tr>
	      <tr>
		<th align=right nowrap=true>| . $locale->text('Required by') . qq|</th>
                $button2
	      </tr>
|;

    $n = ($form->{creditremaining} =~ /-/) ? "0" : "1";

    $creditremaining = qq|
	      <tr>
		<td></td>
		<td colspan=3>
		  <table>
		    <tr>
		      <th nowrap>| . $locale->text('Credit Limit') . qq|</th>
		      <td>$form->{creditlimit}</td>
		      <td width=20%></td>
		      <th nowrap>| . $locale->text('Remaining') . qq|</th>
		      <td class="plus$n" nowrap>$form->{creditremaining}</td>
		    </tr>
		  </table>
		</td>
                $shipto
	      </tr>
|;
  } else {
    $reqlabel =
      ($form->{type} eq 'sales_quotation')
      ? $locale->text('Valid until')
      : $locale->text('Required by');
    if ($form->{type} eq 'sales_quotation') {
      $ordnumber = qq|
	      <tr>
		<th width=70% align=right nowrap>|
        . $locale->text('Quotation Number') . qq|</th>
		<td><input name=quonumber size=11 value="$form->{quonumber}"></td>
		<input type=hidden name=ordnumber value="$form->{ordnumber}">
	      </tr>
|;
    } else {
      $ordnumber = qq|
	      <tr>
		<th width=70% align=right nowrap>| . $locale->text('RFQ Number') . qq|</th>
		<td><input name=quonumber size=11 value="$form->{quonumber}"></td>
		<input type=hidden name=ordnumber value="$form->{ordnumber}">
	      </tr>
|;

    }

    $ordnumber .= qq|
	      <tr>
		<th align=right nowrap>| . $locale->text('Quotation Date') . qq|</th>
                $button1
              </tr>
	      <tr>
		<th align=right nowrap=true>$reqlabel</th>
                $button2
	      </tr>
|;
    $creditremaining = qq| <tr>
                            <td colspan=4></td>
                            $shipto
                          </tr>|;
  }

  $vc =
    ($form->{"select$form->{vc}"})
    ? qq|<select name=$form->{vc}>$form->{"select$form->{vc}"}</select>\n<input type=hidden name="select$form->{vc}" value="$form->{"select$form->{vc}"}">|
    : qq|<input name=$form->{vc} value="$form->{$form->{vc}}" size=35>|;

  $department = qq|
              <tr>
	        <th align="right" nowrap>| . $locale->text('Department') . qq|</th>
		<td colspan=3><select name=department>$form->{selectdepartment}</select>
		<input type=hidden name=selectdepartment value="$form->{selectdepartment}">
		</td>
	      </tr>
| if $form->{selectdepartment};

  $employee = qq|
              <input type=hidden name=employee value="$form->{employee}">
|;

  if ($form->{type} eq 'sales_order') {
    if ($form->{selectemployee}) {
      $employee = qq|
    <input type=hidden name=customer_klass value=$form->{customer_klass}>
 	      <tr>
	        <th align=right nowrap>| . $locale->text('Salesperson') . qq|</th>
		<td colspan=2><select name=employee>$form->{selectemployee}</select></td>
		<input type=hidden name=selectemployee value="$form->{selectemployee}">
                <td></td>
	      </tr>
|;
    }
  } else {
    $employee = qq|
    <input type=hidden name=customer_klass value=$form->{customer_klass}>
 	      <tr>
	        <th align=right nowrap>| . $locale->text('Employee') . qq|</th>
		<td colspan=2><select name=employee>$form->{selectemployee}</select></td>
		<input type=hidden name=selectemployee value="$form->{selectemployee}">
                <td></td>
	      </tr>
|;
  }
  if ($form->{resubmit} && ($form->{format} eq "html")) {
    $onload =
      qq|window.open('about:blank','Beleg'); document.oe.target = 'Beleg';document.oe.submit()|;
  } elsif ($form->{resubmit}) {
    $onload = qq|document.oe.submit()|;
  } else {
    $onload = "fokus()";
  }

  $credittext = $locale->text('Credit Limit exceeded!!!');
  if ($creditwarning) {
    $onload = qq|alert('$credittext')|;
  }

  $form->{"javascript"} .= qq|<script type="text/javascript" src="js/show_form_details.js"></script>|;
  # show history button js
  $form->{javascript} .= qq|<script type="text/javascript" src="js/show_history.js"></script>|;
  #/show history button js
  $form->header;

  print qq|
<body onLoad="$onload">

<form method=post name=oe action=$form->{script}>
 <script type="text/javascript" src="js/common.js"></script>
 <script type="text/javascript" src="js/delivery_customer_selection.js"></script>
 <script type="text/javascript" src="js/vendor_selection.js"></script>
 <script type="text/javascript" src="js/calculate_qty.js"></script>

<input type=hidden name=id value=$form->{id}>
<input type=hidden name=action value=$form->{action}>

<input type=hidden name=type value=$form->{type}>
<input type=hidden name=formname value=$form->{formname}>
<input type=hidden name=media value=$form->{media}>
<input type=hidden name=format value=$form->{format}>
<input type=hidden name=proforma value=$form->{proforma}>

<input type=hidden name=queued value="$form->{queued}">
<input type=hidden name=printed value="$form->{printed}">
<input type=hidden name=emailed value="$form->{emailed}">

<input type=hidden name=vc value=$form->{vc}>

<input type=hidden name=title value="$form->{title}">

<input type=hidden name=discount value=$form->{discount}>
<input type=hidden name=creditlimit value=$form->{creditlimit}>
<input type=hidden name=creditremaining value=$form->{creditremaining}>

<input type=hidden name=tradediscount value=$form->{tradediscount}>
<input type=hidden name=business value=$form->{business}>
<input type=hidden name=webdav value=$webdav>

<table width=100%>
  <tr class=listtop>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width="100%">
        <tr valign=top>
	  <td>
	    <table width=100%>
	      <tr>
		<th align=right>$vclabel</th>
		<td colspan=3>$vc</td>
		<input type=hidden name=$form->{vc}_id value=$form->{"$form->{vc}_id"}>
		<input type=hidden name="old$form->{vc}" value="$form->{"old$form->{vc}"}">
                <th align=richt nowrap>|
    . $locale->text('Contact Person') . qq|</th>
                <td colspan=3>$contact</td>
	      </tr>
	      $creditremaining
	      $business
              $dunning
              $taxzone
	      $department
	      <tr>
		<th align=right>| . $locale->text('Currency') . qq|</th>
		<td><select name=currency>$form->{selectcurrency}</select></td>
		<input type=hidden name=selectcurrency value="$form->{selectcurrency}">
		<input type=hidden name=defaultcurrency value=$form->{defaultcurrency}>
		$exchangerate
	      </tr>
	      <tr>
		<th align=right>| . $locale->text('Shipping Point') . qq|</th>
		<td colspan=3><input name=shippingpoint size=35 value="$form->{shippingpoint}"></td>
	      </tr>
	      <tr>
		<th align=right>| . $locale->text('Ship via') . qq|</th>
		<td colspan=3><input name=shipvia size=35 value="$form->{shipvia}"></td>
	      </tr>|;
#              <tr>
#                 <td colspan=4>
#                   <table>
#                     <tr>
#                       <td colspan=2>
#                         <button type="button" onclick="delivery_customer_selection_window('delivery_customer_string','delivery_customer_id')">| . $locale->text('Choose Customer') . qq|</button>
#                       </td>
#                       <td colspan=2><input type=hidden name=delivery_customer_id value="$form->{delivery_customer_id}">
#                       <input size=45 id=delivery_customer_string name=delivery_customer_string value="$form->{delivery_customer_string}"></td>
#                     </tr>
#                     <tr>
#                       <td colspan=2>
#                         <button type="button" onclick="vendor_selection_window('delivery_vendor_string','delivery_vendor_id')">| . $locale->text('Choose Vendor') . qq|</button>
#                       </td>
#                       <td colspan=2><input type=hidden name=delivery_vendor_id value="$form->{delivery_vendor_id}">
#                       <input size=45 id=vendor_string name=delivery_vendor_string value="$form->{delivery_vendor_string}"></td>
#                     </tr>
#                   </table>
#                 </td>
#               </tr>
print qq|	    </table>
	  </td>
	  <td align=right>
	    <table>
	      $openclosed
	      $employee
	      $ordnumber
	      <tr>
          <th width="70%" align="right" nowrap>| . $locale->text('Project Number') . qq|</th>
          <td>$globalprojectnumber</td>
	      </tr>
	    </table>
	  </td>
	</tr>
      </table>
    </td>
  </tr>

$jsscript

<!-- shipto are in hidden variables -->

<input type=hidden name=shiptoname value="$form->{shiptoname}">
<input type=hidden name=shiptostreet value="$form->{shiptostreet}">
<input type=hidden name=shiptozipcode value="$form->{shiptozipcode}">
<input type=hidden name=shiptocity value="$form->{shiptocity}">
<input type=hidden name=shiptocountry value="$form->{shiptocountry}">
<input type=hidden name=shiptocontact value="$form->{shiptocontact}">
<input type=hidden name=shiptophone value="$form->{shiptophone}">
<input type=hidden name=shiptofax value="$form->{shiptofax}">
<input type=hidden name=shiptodepartment_1 value="$form->{shiptodepartment_1}">
<input type=hidden name=shiptodepartment_2 value="$form->{shiptodepartment_2}">
<input type=hidden name=shiptoemail value="$form->{shiptoemail}">

<!-- email variables -->
<input type=hidden name=message value="$form->{message}">
<input type=hidden name=email value="$form->{email}">
<input type=hidden name=subject value="$form->{subject}">
<input type=hidden name=cc value="$form->{cc}">
<input type=hidden name=bcc value="$form->{bcc}">

<input type=hidden name=taxpart value="$form->{taxpart}">
<input type=hidden name=taxservice value="$form->{taxservice}">

<input type=hidden name=taxaccounts value="$form->{taxaccounts}">
|;

  foreach $item (split / /, $form->{taxaccounts}) {
    print qq|
<input type=hidden name="${item}_rate" value=$form->{"${item}_rate"}>
<input type=hidden name="${item}_description" value="$form->{"${item}_description"}">
|;
  }
  $lxdebug->leave_sub();
}

sub form_footer {
  $lxdebug->enter_sub();

  $form->{invtotal} = $form->{invsubtotal};

  if (($rows = $form->numtextrows($form->{notes}, 25, 8)) < 2) {
    $rows = 2;
  }
  if (($introws = $form->numtextrows($form->{intnotes}, 35, 8)) < 2) {
    $introws = 2;
  }
  $rows = ($rows > $introws) ? $rows : $introws;
  $notes =
    qq|<textarea name=notes rows=$rows cols=25 wrap=soft>$form->{notes}</textarea>|;
  $intnotes =
    qq|<textarea name=intnotes rows=$rows cols=35 wrap=soft>$form->{intnotes}</textarea>|;

  $form->{taxincluded} = ($form->{taxincluded}) ? "checked" : "";

  $taxincluded = "";
  if ($form->{taxaccounts}) {
    $taxincluded = qq|
	      <input name=taxincluded class=checkbox type=checkbox value=1 $form->{taxincluded}> <b>|
      . $locale->text('Tax Included') . qq|</b><br><br>
|;
  }

  if (!$form->{taxincluded}) {

    foreach $item (split / /, $form->{taxaccounts}) {
      if ($form->{"${item}_base"}) {
        $form->{invtotal} += $form->{"${item}_total"} =
          $form->round_amount(
                             $form->{"${item}_base"} * $form->{"${item}_rate"},
                             2);
        $form->{"${item}_total"} =
          $form->format_amount(\%myconfig, $form->{"${item}_total"}, 2);

        $tax .= qq|
	      <tr>
		<th align=right>$form->{"${item}_description"}&nbsp;|
		                    . $form->{"${item}_rate"} * 100 .qq|%</th>
		<td align=right>$form->{"${item}_total"}</td>
	      </tr>
|;
      }
    }

    $form->{invsubtotal} =
      $form->format_amount(\%myconfig, $form->{invsubtotal}, 2, 0);

    $subtotal = qq|
	      <tr>
		<th align=right>| . $locale->text('Subtotal') . qq|</th>
		<td align=right>$form->{invsubtotal}</td>
	      </tr>
|;

  }

  if ($form->{taxincluded}) {
    foreach $item (split / /, $form->{taxaccounts}) {
      if ($form->{"${item}_base"}) {
        $form->{"${item}_total"} =
          $form->round_amount(
                           ($form->{"${item}_base"} * $form->{"${item}_rate"} /
                              (1 + $form->{"${item}_rate"})
                           ),
                           2);
        $form->{"${item}_netto"} =
          $form->round_amount(
                          ($form->{"${item}_base"} - $form->{"${item}_total"}),
                          2);
        $form->{"${item}_total"} =
          $form->format_amount(\%myconfig, $form->{"${item}_total"}, 2);
        $form->{"${item}_netto"} =
          $form->format_amount(\%myconfig, $form->{"${item}_netto"}, 2);

        $tax .= qq|
	      <tr>
		<th align=right>Enthaltene $form->{"${item}_description"}&nbsp;|
		                    . $form->{"${item}_rate"} * 100 .qq|%</th>
		<td align=right>$form->{"${item}_total"}</td>
	      </tr>
	      <tr>
	        <th align=right>Nettobetrag</th>
		<td align=right>$form->{"${item}_netto"}</td>
	      </tr>
|;
      }
    }

  }

  $form->{oldinvtotal} = $form->{invtotal};
  $form->{invtotal}    =
    $form->format_amount(\%myconfig, $form->{invtotal}, 2, 0);

  print qq|
  <tr>
    <td>
      <table width=100%>
	<tr valign=bottom>
	  <td>
	    <table>
	      <tr>
		<th align=left>| . $locale->text('Notes') . qq|</th>
		<th align=left>| . $locale->text('Internal Notes') . qq|</th>
	      </tr>
	      <tr valign=top>
		<td>$notes</td>
		<td>$intnotes</td>
	      </tr>
	  <th align=right>| . $locale->text('Payment Terms') . qq|</th>
	  <td><select name=payment_id tabindex=24>$payment
                          </select></td>
	    </table>
	  </td>
	  <td align=right width=100%>
	    $taxincluded
	    <table width=100%>
	      $subtotal
	      $tax
	      <tr>
		<th align=right>| . $locale->text('Total') . qq|</th>
		<td align=right>$form->{invtotal}</td>
	      </tr>
	    </table>
	  </td>
	</tr>
      </table>
    </td>
  </tr>
<input type=hidden name=oldinvtotal value=$form->{oldinvtotal}>
<input type=hidden name=oldtotalpaid value=$totalpaid>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
|;

  if ($webdav) {
    $webdav_list = qq|

  <tr>
    <th class=listtop align=left>Dokumente im Webdav-Repository</th>
  </tr>
    <table width=100%>
      <td align=left width=30%><b>Dateiname</b></td>
      <td align=left width=70%><b>Webdavlink</b></td>
|;
    foreach $file (keys %{ $form->{WEBDAV} }) {
      $webdav_list .= qq|
      <tr>
        <td align=left>$file</td>
        <td align=left><a href="$form->{WEBDAV}{$file}">$form->{WEBDAV}{$file}</a></td>
      </tr>
|;
    }
    $webdav_list .= qq|
    </table>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
|;

    print $webdav_list;
  }
  print qq|
<input type=hidden name=jscalendar value=$form->{jscalendar}>
|;
  print qq|
  <tr>
    <td>
|;
  &print_options;

  print qq|
    </td>
  </tr>
</table>

| . $locale->text("Edit the $form->{type}") . qq|<br>
<input class=submit type=submit name=action id=update_button value="|
    . $locale->text('Update') . qq|">
<input class=submit type=submit name=action value="|
    . $locale->text('Ship to') . qq|">
<input class=submit type=submit name=action value="|
    . $locale->text('Print') . qq|">
<input class=submit type=submit name=action value="|
    . $locale->text('E-mail') . qq|">
<input class=submit type=submit name=action value="|
    . $locale->text('Save') . qq|">
<input class=submit type=submit name=action value="|
    . $locale->text('Save and Close') . qq|">
|;

  if (($form->{id})) {
    print qq|
  	<input type="button" class="submit" onclick="set_history_window(|
  	. Q($form->{id})
  	. qq|);" name="history" id="history" value="|
  	. $locale->text('history')
  	. qq|">

<br>| . $locale->text("Workflow $form->{type}") . qq|<br>
<input class=submit type=submit name=action value="|
      . $locale->text('Save as new') . qq|">
<input class=submit type=submit name=action value="|
      . $locale->text('Delete') . qq|">|;
    if (($form->{type} =~ /sales_quotation$/)) {
      print qq|
<input class=submit type=submit name=action value="|
        . $locale->text('Sales Order') . qq|">|;
    }
    if ($form->{type} =~ /request_quotation$/) {
      print qq|
<input class=submit type=submit name=action value="|
        . $locale->text('Purchase Order') . qq|">|;
    }
    if (1) {
    print qq|
<input class=submit type=submit name=action value="|
      . $locale->text('Invoice') . qq|">
|;
}

    if ($form->{type} =~ /sales_order$/) {
      print qq|
<br>$form->{heading} als neue Vorlage verwenden f&uuml;r<br>
<input class=submit type=submit name=action value="|
        . $locale->text('Purchase Order') . qq|">
<input class=submit type=submit name=action value="|
        . $locale->text('Quotation') . qq|">
|;

    } elsif ($form->{type} =~ /purchase_order$/) {
      print qq|
<br>$form->{heading} als neue Vorlage verwenden f&uuml;r<br>
<input class=submit type=submit name=action value="|
        . $locale->text('Sales Order') . qq|">
<input class=submit type=submit name=action value="|
        . $locale->text('Request for Quotation') . qq|">
|;

    } else {
      print qq|
<br>$form->{heading} als neue Vorlage verwenden f&uuml;r<br>
<input class=submit type=submit name=action value="|
        . $locale->text('Order') . qq|">
|;
    }
  } elsif ($form->{type} =~ /sales_order$/ && $form->{rowcount} && !$form->{proforma}) {
    print qq|
<br>Workflow  $form->{heading}<br>
<input class=submit type=submit name=action value="|
      . $locale->text('Save as new') . qq|">
<input class=submit type=submit name=action value="|
      . $locale->text('Invoice') . qq|">
|;
  }

  $form->hide_form("saved_xyznumber");

  print qq|

<input type=hidden name=rowcount value=$form->{rowcount}>

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

</form>

</body>
</html>
|;
  $lxdebug->leave_sub();
}

sub update {
  $lxdebug->enter_sub();

  set_headings($form->{"id"} ? "edit" : "add");

  map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) }
    qw(exchangerate creditlimit creditremaining);
  $form->{update} = 1;

  &check_name($form->{vc});

  $buysell              = 'buy';
  $buysell              = 'sell' if ($form->{vc} eq 'vendor');
  $form->{exchangerate} = $exchangerate
    if (
        $form->{forex} = (
                  $exchangerate =
                    $form->check_exchangerate(
                    \%myconfig, $form->{currency}, $form->{transdate}, $buysell
                    )));

  # for pricegroups
  $i = $form->{rowcount};

  $exchangerate = ($form->{exchangerate}) ? $form->{exchangerate} : 1;

  if (   ($form->{"partnumber_$i"} eq "")
      && ($form->{"description_$i"} eq "")
      && ($form->{"partsgroup_$i"}  eq "")) {

    $form->{creditremaining} += ($form->{oldinvtotal} - $form->{oldtotalpaid});
    &check_form;

  } else {

    if (   $form->{type} eq 'purchase_order'
        || $form->{type} eq 'request_quotation') {
      IR->retrieve_item(\%myconfig, \%$form);
    }
    if ($form->{type} eq 'sales_order' || $form->{type} eq 'sales_quotation') {
      IS->retrieve_item(\%myconfig, \%$form);
    }

    my $rows = scalar @{ $form->{item_list} };

    $form->{"discount_$i"} =
      $form->format_amount(\%myconfig, $form->{discount} * 100);

    if ($rows) {
      $form->{"qty_$i"} = 1 unless ($form->{"qty_$i"});

      if ($rows > 1) {

        &select_item;
        exit;

      } else {

        $sellprice = $form->parse_amount(\%myconfig, $form->{"sellprice_$i"});
        if ($form->{"not_discountable_$i"}) {
          $form->{"discount_$i"} = 0;
        }
        map { $form->{item_list}[$i]{$_} =~ s/\"/&quot;/g }
          qw(partnumber description unit);
        map { $form->{"${_}_$i"} = $form->{item_list}[0]{$_} }
          keys %{ $form->{item_list}[0] };
        if ($form->{"part_payment_id_$i"} ne "") {
          $form->{payment_id} = $form->{"part_payment_id_$i"};
        }

        $s = ($sellprice) ? $sellprice : $form->{"sellprice_$i"};

        ($dec) = ($s =~ /\.(\d+)/);
        $dec           = length $dec;
        $decimalplaces = ($dec > 2) ? $dec : 2;

        if ($sellprice) {
          $form->{"sellprice_$i"} = $sellprice;
        } else {

          $form->{"sellprice_$i"} *= (1 - $form->{tradediscount});

          # if there is an exchange rate adjust sellprice
          $form->{"sellprice_$i"} /= $exchangerate;
        }

        $amount =
          $form->{"sellprice_$i"} * $form->{"qty_$i"} *
          (1 - $form->{"discount_$i"} / 100);
        map { $form->{"${_}_base"} = 0 } (split / /, $form->{taxaccounts});
        map { $form->{"${_}_base"} += $amount }
          (split / /, $form->{"taxaccounts_$i"});
        map { $amount += ($form->{"${_}_base"} * $form->{"${_}_rate"}) }
          split / /, $form->{taxaccounts}
          if !$form->{taxincluded};

        $form->{creditremaining} -= $amount;

        $form->{"sellprice_$i"} =
          $form->format_amount(\%myconfig, $form->{"sellprice_$i"},
                               $decimalplaces);
        $form->{"qty_$i"} =
          $form->format_amount(\%myconfig, $form->{"qty_$i"}, $dec_qty);

        # get pricegroups for parts
        IS->get_pricegroups_for_parts(\%myconfig, \%$form);

        # build up html code for prices_$i
        &set_pricegroup($i);
      }

      &display_form;

    } else {

      # ok, so this is a new part
      # ask if it is a part or service item

      if (   $form->{"partsgroup_$i"}
          && ($form->{"partsnumber_$i"} eq "")
          && ($form->{"description_$i"} eq "")) {
        $form->{rowcount}--;
        $form->{"discount_$i"} = "";
        &display_form;
      } else {

        $form->{"id_$i"}   = 0;
        $form->{"unit_$i"} = $locale->text('ea');

        &new_item;

      }
    }
  }

  $lxdebug->leave_sub();
}

sub search {
  $lxdebug->enter_sub();

  if ($form->{type} eq 'purchase_order') {
    $form->{title} = $locale->text('Purchase Orders');
    $form->{vc}    = 'vendor';
    $ordlabel      = $locale->text('Order Number');
    $ordnumber     = 'ordnumber';
    $employee      = $locale->text('Employee');
  }

  if ($form->{type} eq 'request_quotation') {
    $form->{title} = $locale->text('Request for Quotations');
    $form->{vc}    = 'vendor';
    $ordlabel      = $locale->text('RFQ Number');
    $ordnumber     = 'quonumber';
    $employee      = $locale->text('Employee');
  }

  if ($form->{type} eq 'sales_order') {
    $form->{title} = $locale->text('Sales Orders');
    $form->{vc}    = 'customer';
    $ordlabel      = $locale->text('Order Number');
    $ordnumber     = 'ordnumber';
    $employee      = $locale->text('Salesperson');
  }

  if ($form->{type} eq 'sales_quotation') {
    $form->{title} = $locale->text('Quotations');
    $form->{vc}    = 'customer';
    $ordlabel      = $locale->text('Quotation Number');
    $ordnumber     = 'quonumber';
    $employee      = $locale->text('Employee');
  }

  # setup vendor / customer selection
  $form->all_vc(\%myconfig, $form->{vc},
                ($form->{vc} eq 'customer') ? "AR" : "AP");

  map { $vc .= "<option>$_->{name}--$_->{id}\n" }
    @{ $form->{"all_$form->{vc}"} };

  $vclabel = ucfirst $form->{vc};
  $vclabel = $locale->text($vclabel);

  # $locale->text('Vendor')
  # $locale->text('Customer')

  $vc =
    ($vc)
    ? qq|<select name=$form->{vc}><option>\n$vc</select>|
    : qq|<input name=$form->{vc} size=35>|;

  # departments
  if (@{ $form->{all_departments} }) {
    $form->{selectdepartment} = "<option>\n";

    map {
      $form->{selectdepartment} .=
        "<option>$_->{description}--$_->{id}\n"
    } (@{ $form->{all_departments} });
  }

  $department = qq|
        <tr>
	  <th align=right nowrap>| . $locale->text('Department') . qq|</th>
	  <td colspan=3><select name=department>$form->{selectdepartment}</select></td>
	</tr>
| if $form->{selectdepartment};

  my $delivered;
  if (($form->{"type"} eq "sales_order") ||
      ($form->{"type"} eq "purchase_order")) {
    $delivered = qq|
        <tr>
          <td><input name="notdelivered" id="notdelivered" class="checkbox" type="checkbox" value="1" checked>
            <label for="notdelivered">|. $locale->text('Not delivered') . qq|</label></td>
          <td><input name="delivered" id="delivered" class="checkbox" type="checkbox" value="1" checked>
            <label for="delivered">| . $locale->text('Delivered') . qq|</label></td>
        </tr>
|;
  }

  # use JavaScript Calendar or not
  $form->{jsscript} = $jscalendar;
  $jsscript = "";
  if ($form->{jsscript}) {

    # with JavaScript Calendar
    $button1 = qq|
       <td><input name=transdatefrom id=transdatefrom size=11 title="$myconfig{dateformat}">
       <input type=button name=transdatefrom id="trigger3" value=|
      . $locale->text('button') . qq|></td>
      |;
    $button2 = qq|
       <td><input name=transdateto id=transdateto size=11 title="$myconfig{dateformat}">
       <input type=button name=transdateto name=transdateto id="trigger4" value=|
      . $locale->text('button') . qq|></td>
     |;

    #write Trigger
    $jsscript =
      Form->write_trigger(\%myconfig, "2", "transdatefrom", "BR", "trigger3",
                          "transdateto", "BL", "trigger4");
  } else {

    # without JavaScript Calendar
    $button1 = qq|
                              <td><input name=transdatefrom id=transdatefrom size=11 title="$myconfig{dateformat}"></td>|;
    $button2 = qq|
                              <td><input name=transdateto id=transdateto size=11 title="$myconfig{dateformat}"></td>|;
  }

  $form->get_lists("projects" => { "key" => "ALL_PROJECTS",
                                   "all" => 1 });

  my %labels = ();
  my @values = ("");
  foreach my $item (@{ $form->{"ALL_PROJECTS"} }) {
    push(@values, $item->{"id"});
    $labels{$item->{"id"}} = $item->{"projectnumber"};
  }
  my $projectnumber =
    NTI($cgi->popup_menu('-name' => 'project_id', '-values' => \@values,
                         '-labels' => \%labels));

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
        <tr>
          <th align=right>$vclabel</th>
          <td colspan=3>$vc</td>
        </tr>
	$department
        <tr>
          <th align=right>$ordlabel</th>
          <td colspan=3><input name="$ordnumber" size=20></td>
        </tr>
        <tr>
          <th align="right">| . $locale->text("Project Number") . qq|</th>
          <td colspan="3">$projectnumber</td>
        </tr>
        <tr>
          <th align=right>| . $locale->text('From') . qq|</th>
          $button1
          <th align=right>| . $locale->text('Bis') . qq|</th>
          $button2
        </tr>
        <input type=hidden name=sort value=transdate>
        <tr>
          <th align=right>| . $locale->text('Include in Report') . qq|</th>
          <td colspan=5>
	    <table>
        <tr>
          <td><input type="checkbox" name="open" value="1" id="open" checked>
            <label for="open">| . $locale->text("Open") . qq|</td>
          <td><input type="checkbox" name="closed" value="1" id="closed">
            <label for="closed">| . $locale->text("Closed") . qq|</td>
        </tr>
        $delivered
	      <tr>
		<td><input name="l_id" class=checkbox type=checkbox value=Y>
		| . $locale->text('ID') . qq|</td>
		<td><input name="l_$ordnumber" class=checkbox type=checkbox value=Y checked> $ordlabel</td>
		<td><input name="l_transdate" class=checkbox type=checkbox value=Y checked> |
    . $locale->text('Date') . qq|</td>
		<td><input name="l_reqdate" class=checkbox type=checkbox value=Y checked> |
    . $locale->text('Required by') . qq|</td>
	      </tr>
	      <tr>
	        <td><input name="l_name" class=checkbox type=checkbox value=Y checked> $vclabel</td>
	        <td><input name="l_employee" class=checkbox type=checkbox value=Y checked> $employee</td>
		<td><input name="l_shipvia" class=checkbox type=checkbox value=Y> |
    . $locale->text('Ship via') . qq|</td>
	        <td><input name="l_employee" class=checkbox type=checkbox value=Y checked> $employee</td>
	      </tr>
	      <tr>
		<td><input name="l_netamount" class=checkbox type=checkbox value=Y> |
    . $locale->text('Amount') . qq|</td>
		<td><input name="l_tax" class=checkbox type=checkbox value=Y> |
    . $locale->text('Tax') . qq|</td>
		<td><input name="l_amount" class=checkbox type=checkbox value=Y checked> |
    . $locale->text('Total') . qq|</td>
          <td><input name="l_globalprojectnumber" class=checkbox type=checkbox value=Y> |
          . $locale->text('Project Number') . qq|</td>
	      </tr>
	      <tr>
	        <td><input name="l_subtotal" class=checkbox type=checkbox value=Y> |
    . $locale->text('Subtotal') . qq|</td>
	      </tr>
	    </table>
          </td>
        </tr>
      </table>
    </td>
  </tr>
  <tr><td colspan=4><hr size=3 noshade></td></tr>
</table>

$jsscript

<br>
<input type=hidden name=nextsub value=orders>
<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>
<input type=hidden name=vc value=$form->{vc}>
<input type=hidden name=type value=$form->{type}>

<input class=submit type=submit name=action value="|
    . $locale->text('Continue') . qq|">
</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub orders {
  $lxdebug->enter_sub();

  # split vendor / customer
  ($form->{ $form->{vc} }, $form->{"$form->{vc}_id"}) =
    split(/--/, $form->{ $form->{vc} });

  OE->transactions(\%myconfig, \%$form);

  $ordnumber = ($form->{type} =~ /_order$/) ? "ordnumber" : "quonumber";

  $number     = $form->escape($form->{$ordnumber});
  $name       = $form->escape($form->{ $form->{vc} });
  $department = $form->escape($form->{department});

  # construct href
  $href =
    "$form->{script}?path=$form->{path}&action=orders&type=$form->{type}&vc=$form->{vc}&login=$form->{login}&password=$form->{password}&transdatefrom=$form->{transdatefrom}&transdateto=$form->{transdateto}&open=$form->{open}&closed=$form->{closed}&notdelivered=$form->{notdelivered}&delivered=$form->{delivered}&$ordnumber=$number&$form->{vc}=$name&department=$department";

  # construct callback
  $number     = $form->escape($form->{$ordnumber},    1);
  $name       = $form->escape($form->{ $form->{vc} }, 1);
  $department = $form->escape($form->{department},    1);

  $callback =
    "$form->{script}?path=$form->{path}&action=orders&type=$form->{type}&vc=$form->{vc}&login=$form->{login}&password=$form->{password}&transdatefrom=$form->{transdatefrom}&transdateto=$form->{transdateto}&open=$form->{open}&closed=$form->{closed}&notdelivered=$form->{notdelivered}&delivered=$form->{delivered}&$ordnumber=$number&$form->{vc}=$name&department=$department";

  @columns =
    $form->sort_columns("transdate", "reqdate",   "id",      "$ordnumber",
                        "name",      "netamount", "tax",     "amount",
                        "curr",      "employee",  "shipvia", "globalprojectnumber",
                        "open",      "closed",    "delivered");

  $form->{l_open} = $form->{l_closed} = "Y"
    if ($form->{open} && $form->{closed});

  $form->{"l_delivered"} = "Y"
    if ($form->{"delivered"} && $form->{"notdelivered"});

  foreach $item (@columns) {
    if ($form->{"l_$item"} eq "Y") {
      push @column_index, $item;

      # add column to href and callback
      $callback .= "&l_$item=Y";
      $href     .= "&l_$item=Y";
    }
  }

  # only show checkboxes if gotten here via sales_order form.
  if ($form->{type} =~ /sales_order/) {
    unshift @column_index, "ids";
  }

  if ($form->{l_subtotal} eq 'Y') {
    $callback .= "&l_subtotal=Y";
    $href     .= "&l_subtotal=Y";
  }

  if ($form->{vc} eq 'vendor') {
    if ($form->{type} eq 'purchase_order') {
      $form->{title} = $locale->text('Purchase Orders');
    } else {
      $form->{title} = $locale->text('Request for Quotations');
    }
    $name     = $locale->text('Vendor');
    $employee = $locale->text('Employee');
  }
  if ($form->{vc} eq 'customer') {
    if ($form->{type} eq 'sales_order') {
      $form->{title} = $locale->text('Sales Orders');
      $employee = $locale->text('Salesperson');
    } else {
      $form->{title} = $locale->text('Quotations');
      $employee = $locale->text('Employee');
    }
    $name = $locale->text('Customer');
  }

  $column_header{id} =
      qq|<th><a class=listheading href=$href&sort=id>|
    . $locale->text('ID')
    . qq|</a></th>|;
  $column_header{transdate} =
      qq|<th><a class=listheading href=$href&sort=transdate>|
    . $locale->text('Date')
    . qq|</a></th>|;
  $column_header{reqdate} =
      qq|<th><a class=listheading href=$href&sort=reqdate>|
    . $locale->text('Required by')
    . qq|</a></th>|;
  $column_header{ordnumber} =
      qq|<th><a class=listheading href=$href&sort=ordnumber>|
    . $locale->text('Order')
    . qq|</a></th>|;
  $column_header{quonumber} =
      qq|<th><a class=listheading href=$href&sort=quonumber>|
    . ($form->{"type"} eq "request_quotation" ?
       $locale->text('RFQ') :
       $locale->text('Quotation'))
    . qq|</a></th>|;
  $column_header{name} =
    qq|<th><a class=listheading href=$href&sort=name>$name</a></th>|;
  $column_header{netamount} =
    qq|<th class=listheading>| . $locale->text('Amount') . qq|</th>|;
  $column_header{tax} =
    qq|<th class=listheading>| . $locale->text('Tax') . qq|</th>|;
  $column_header{amount} =
    qq|<th class=listheading>| . $locale->text('Total') . qq|</th>|;
  $column_header{curr} =
    qq|<th class=listheading>| . $locale->text('Curr') . qq|</th>|;
  $column_header{shipvia} =
      qq|<th><a class=listheading href=$href&sort=shipvia>|
    . $locale->text('Ship via')
    . qq|</a></th>|;
  $column_header{globalprojectnumber} =
    qq|<th class="listheading">| . $locale->text('Project Number') . qq|</th>|;
  $column_header{open} =
    qq|<th class=listheading>| . $locale->text('O') . qq|</th>|;
  $column_header{closed} =
    qq|<th class=listheading>| . $locale->text('C') . qq|</th>|;
  $column_header{"delivered"} =
    qq|<th class="listheading">| . $locale->text("Delivered") . qq|</th>|;

  $column_header{employee} =
    qq|<th><a class=listheading href=$href&sort=employee>$employee</a></th>|;

  $column_header{ids} = qq|<th></th>|;

  if ($form->{ $form->{vc} }) {
    $option = $locale->text(ucfirst $form->{vc});
    $option .= " : $form->{$form->{vc}}";
  }
  if ($form->{department}) {
    $option .= "\n<br>" if ($option);
    ($department) = split /--/, $form->{department};
    $option .= $locale->text('Department') . " : $department";
  }
  if ($form->{transdatefrom}) {
    $option .= "\n<br>"
      . $locale->text('From') . " "
      . $locale->date(\%myconfig, $form->{transdatefrom}, 1);
  }
  if ($form->{transdateto}) {
    $option .= "\n<br>"
      . $locale->text('Bis') . " "
      . $locale->date(\%myconfig, $form->{transdateto}, 1);
  }
  if ($form->{open}) {
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('Open');
  }
  if ($form->{closed}) {
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('Closed');
  }

  $form->header;

  print qq|
<body>

<form method="post" action="oe.pl">
<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>$option</td>
  </tr>
  <tr>
    <td>
      <table width=100%>
	<tr class=listheading>|;

  map { print "\n$column_header{$_}" } @column_index;

  print qq|
	</tr>
|;

  # add sort and escape callback
  $callback_escaped = $form->escape($callback . "&sort=$form->{sort}");

  if (@{ $form->{OE} }) {
    $sameitem = $form->{OE}->[0]->{ $form->{sort} };
  }

  $action = "edit";

  foreach $oe (@{ $form->{OE} }) {
    $form->{rowcount} = ++$j;

    if ($form->{l_subtotal} eq 'Y') {
      if ($sameitem ne $oe->{ $form->{sort} }) {
        &subtotal;
        $sameitem = $oe->{ $form->{sort} };
      }
    }

    map { $oe->{$_} *= $oe->{exchangerate} } (qw(netamount amount));

    $column_data{netamount} =
        "<td align=right>"
      . $form->format_amount(\%myconfig, $oe->{netamount}, 2, "&nbsp;")
      . "</td>";
    $column_data{tax} = "<td align=right>"
      . $form->format_amount(\%myconfig, $oe->{amount} - $oe->{netamount},
                             2, "&nbsp;")
      . "</td>";
    $column_data{amount} =
      "<td align=right>"
      . $form->format_amount(\%myconfig, $oe->{amount}, 2, "&nbsp;") . "</td>";

    $totalnetamount += $oe->{netamount};
    $totalamount    += $oe->{amount};

    $subtotalnetamount += $oe->{netamount};
    $subtotalamount    += $oe->{amount};

    $column_data{ids} =
      qq|<td><input name="id_$j" class=checkbox type=checkbox><input type="hidden" name="trans_id_$j" value="$oe->{id}"></td>|;
    $column_data{id}        = "<td>$oe->{id}</td>";
    $column_data{transdate} = "<td>$oe->{transdate}&nbsp;</td>";
    $column_data{reqdate}   = "<td>$oe->{reqdate}&nbsp;</td>";

    $column_data{$ordnumber} =
      "<td><a href=oe.pl?path=$form->{path}&action=$action&type=$form->{type}&id=$oe->{id}&vc=$form->{vc}&login=$form->{login}&password=$form->{password}&callback=$callback_escaped>$oe->{$ordnumber}</a></td>";
    $column_data{name} = "<td>$oe->{name}</td>";

    $column_data{employee} = "<td>$oe->{employee}&nbsp;</td>";
    $column_data{shipvia}  = "<td>$oe->{shipvia}&nbsp;</td>";
    $column_data{globalprojectnumber}  = "<td>" . H($oe->{globalprojectnumber}) . "</td>";

    if ($oe->{closed}) {
      $column_data{closed} = "<td align=center>X</td>";
      $column_data{open}   = "<td>&nbsp;</td>";
    } else {
      $column_data{closed} = "<td>&nbsp;</td>";
      $column_data{open}   = "<td align=center>X</td>";
    }
    $column_data{"delivered"} = "<td>" .
      ($oe->{"delivered"} ? $locale->text("Yes") : $locale->text("No")) .
      "</td>";

    $i++;
    $i %= 2;
    print "
        <tr class=listrow$i>";

    map { print "\n$column_data{$_}" } @column_index;

    print qq|
	</tr>
|;

  }

  if ($form->{l_subtotal} eq 'Y') {
    &subtotal;
  }

  # print totals
  print qq|
        <tr class=listtotal>|;

  map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;

  $column_data{netamount} =
    "<th class=listtotal align=right>"
    . $form->format_amount(\%myconfig, $totalnetamount, 2, "&nbsp;") . "</th>";
  $column_data{tax} = "<th class=listtotal align=right>"
    . $form->format_amount(\%myconfig, $totalamount - $totalnetamount,
                           2, "&nbsp;")
    . "</th>";
  $column_data{amount} =
    "<th class=listtotal align=right>"
    . $form->format_amount(\%myconfig, $totalamount, 2, "&nbsp;") . "</th>";

  map { print "\n$column_data{$_}" } @column_index;

  print qq|
        </tr>
      </td>
    </table>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>|;

  # multiple invoice edit button only if gotten there via sales_order form.

  if ($form->{type} =~ /sales_order/) {
    print qq|
  <input type="hidden" name="path" value="$form->{path}">
  <input class"submit" type="submit" name="action" value="|
      . $locale->text('Continue') . qq|">
  <input type="hidden" name="nextsub" value="edit">
  <input type="hidden" name="type" value="$form->{type}">
  <input type="hidden" name="vc" value="$form->{vc}">
  <input type="hidden" name="login" value="$form->{login}">
  <input type="hidden" name="password" value="$form->{password}">
  <input type="hidden" name="callback" value="$callback">
  <input type="hidden" name="rowcount" value="$form->{rowcount}">|;
  }

  print qq|
</form>

<br>
<form method=post action=$form->{script}>

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=type value=$form->{type}>
<input type=hidden name=vc value=$form->{vc}>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub subtotal {
  $lxdebug->enter_sub();

  map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;

  $column_data{netamount} =
      "<th class=listsubtotal align=right>"
    . $form->format_amount(\%myconfig, $subtotalnetamount, 2, "&nbsp;")
    . "</th>";
  $column_data{tax} = "<td class=listsubtotal align=right>"
    . $form->format_amount(\%myconfig, $subtotalamount - $subtotalnetamount,
                           2, "&nbsp;")
    . "</th>";
  $column_data{amount} =
    "<th class=listsubtotal align=right>"
    . $form->format_amount(\%myconfig, $subtotalamount, 2, "&nbsp;") . "</th>";

  $subtotalnetamount = 0;
  $subtotalamount    = 0;

  print "
        <tr class=listsubtotal>
";

  map { print "\n$column_data{$_}" } @column_index;

  print qq|
        </tr>
|;

  $lxdebug->leave_sub();
}

sub save_and_close {
  $lxdebug->enter_sub();

  if ($form->{type} =~ /_order$/) {
    $form->isblank("transdate", $locale->text('Order Date missing!'));
  } else {
    $form->isblank("transdate", $locale->text('Quotation Date missing!'));
  }

  $msg = ucfirst $form->{vc};
  $form->isblank($form->{vc}, $locale->text($msg . " missing!"));

  # $locale->text('Customer missing!');
  # $locale->text('Vendor missing!');

  $form->isblank("exchangerate", $locale->text('Exchangerate missing!'))
    if ($form->{currency} ne $form->{defaultcurrency});

  &validate_items;

  # if the name changed get new values
  if (&check_name($form->{vc})) {
    &update;
    exit;
  }

  $form->{id} = 0 if $form->{saveasnew};

  # this is for the internal notes section for the [email] Subject
  if ($form->{type} =~ /_order$/) {
    if ($form->{type} eq 'sales_order') {
      $form->{label} = $locale->text('Sales Order');

      $numberfld = "sonumber";
      $ordnumber = "ordnumber";
    } else {
      $form->{label} = $locale->text('Purchase Order');

      $numberfld = "ponumber";
      $ordnumber = "ordnumber";
    }

    $err = $locale->text('Cannot save order!');

  } else {
    if ($form->{type} eq 'sales_quotation') {
      $form->{label} = $locale->text('Quotation');

      $numberfld = "sqnumber";
      $ordnumber = "quonumber";
    } else {
      $form->{label} = $locale->text('Request for Quotation');

      $numberfld = "rfqnumber";
      $ordnumber = "quonumber";
    }

    $err = $locale->text('Cannot save quotation!');

  }

  # get new number in sequence if no number is given or if saveasnew was requested
  if (!$form->{$ordnumber} || $form->{saveasnew}) {
    $form->{$ordnumber} = $form->update_defaults(\%myconfig, $numberfld);
  }

  relink_accounts();

  $form->error($err) if (!OE->save(\%myconfig, \%$form));

  # saving the history
  if(!exists $form->{addition}) {
  	$form->{addition} = "SAVED";
  	$form->save_history($form->dbconnect(\%myconfig));
  }
  # /saving the history

  $form->redirect($form->{label} . " $form->{$ordnumber} " .
                  $locale->text('saved!'));

  $lxdebug->leave_sub();
}

sub save {
  $lxdebug->enter_sub();

  if ($form->{type} =~ /_order$/) {
    $form->isblank("transdate", $locale->text('Order Date missing!'));
  } else {
    $form->isblank("transdate", $locale->text('Quotation Date missing!'));
  }

  $msg = ucfirst $form->{vc};
  $form->isblank($form->{vc}, $locale->text($msg . " missing!"));

  # $locale->text('Customer missing!');
  # $locale->text('Vendor missing!');

  $form->isblank("exchangerate", $locale->text('Exchangerate missing!'))
    if ($form->{currency} ne $form->{defaultcurrency});

  &validate_items;

  # if the name changed get new values
  if (&check_name($form->{vc})) {
    &update;
    exit;
  }

  $form->{id} = 0 if $form->{saveasnew};

  # this is for the internal notes section for the [email] Subject
  if ($form->{type} =~ /_order$/) {
    if ($form->{type} eq 'sales_order') {
      $form->{label} = $locale->text('Sales Order');

      $numberfld = "sonumber";
      $ordnumber = "ordnumber";
    } else {
      $form->{label} = $locale->text('Purchase Order');

      $numberfld = "ponumber";
      $ordnumber = "ordnumber";
    }

    $err = $locale->text('Cannot save order!');

  } else {
    if ($form->{type} eq 'sales_quotation') {
      $form->{label} = $locale->text('Quotation');

      $numberfld = "sqnumber";
      $ordnumber = "quonumber";
    } else {
      $form->{label} = $locale->text('Request for Quotation');

      $numberfld = "rfqnumber";
      $ordnumber = "quonumber";
    }

    $err = $locale->text('Cannot save quotation!');

  }

  $form->{$ordnumber} = $form->update_defaults(\%myconfig, $numberfld)
    unless $form->{$ordnumber};

  relink_accounts();

  OE->save(\%myconfig, \%$form);

  # saving the history
  if(!exists $form->{addition}) {
  	$form->{addition} = "SAVED";
  	$form->save_history($form->dbconnect(\%myconfig));
  }
  # /saving the history 

  $form->{simple_save} = 1;
  if(!$form->{print_and_save}) {
    set_headings("edit");
    &update;
    exit;
  }
  $lxdebug->leave_sub();
}

sub delete {
  $lxdebug->enter_sub();

  $form->header;

  if ($form->{type} =~ /_order$/) {
    $msg       = $locale->text('Are you sure you want to delete Order Number');
    $ordnumber = 'ordnumber';
  } else {
    $msg = $locale->text('Are you sure you want to delete Quotation Number');
    $ordnumber = 'quonumber';
  }

  print qq|
<body>

<form method=post action=$form->{script}>
|;

  # delete action variable
  map { delete $form->{$_} } qw(action header);

  foreach $key (keys %$form) {
    $form->{$key} =~ s/\"/&quot;/g;
    print qq|<input type=hidden name=$key value="$form->{$key}">\n|;
  }

  print qq|
<h2 class=confirm>| . $locale->text('Confirm!') . qq|</h2>

<h4>$msg $form->{$ordnumber}</h4>
<p>
<input name=action class=submit type=submit value="|
    . $locale->text('Yes') . qq|">
</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub yes {
  $lxdebug->enter_sub();

  if ($form->{type} =~ /_order$/) {
    $msg = $locale->text('Order deleted!');
    $err = $locale->text('Cannot delete order!');
  } else {
    $msg = $locale->text('Quotation deleted!');
    $err = $locale->text('Cannot delete quotation!');
  }
  if (OE->delete(\%myconfig, \%$form, $spool)){
    $form->redirect($msg);
    # saving the history
    if(!exists $form->{addition}) {
  	  $form->{addition} = "DELETED";
  	  $form->save_history($form->dbconnect(\%myconfig));
    }
    # /saving the history 
  }
  $form->error($err);

  $lxdebug->leave_sub();
}

sub invoice {
  $lxdebug->enter_sub();

  if ($form->{type} =~ /_order$/) {

    # these checks only apply if the items don't bring their own ordnumbers/transdates.
    # The if clause ensures that by searching for empty ordnumber_#/transdate_# fields.
    $form->isblank("ordnumber", $locale->text('Order Number missing!'))
      if (+{ map { $form->{"ordnumber_$_"}, 1 } (1 .. $form->{rowcount} - 1) }
          ->{''});
    $form->isblank("transdate", $locale->text('Order Date missing!'))
      if (+{ map { $form->{"transdate_$_"}, 1 } (1 .. $form->{rowcount} - 1) }
          ->{''});

    # also copy deliverydate from the order
    $form->{deliverydate} = $form->{reqdate} if $form->{reqdate};
    $form->{orddate} = $form->{transdate};
  } else {
    $form->isblank("quonumber", $locale->text('Quotation Number missing!'));
    $form->isblank("transdate", $locale->text('Quotation Date missing!'));
    $form->{ordnumber} = "";
    $form->{quodate} = $form->{transdate};
  }

  # if the name changed get new values
  if (&check_name($form->{vc})) {
    &update;
    exit;
  }

  $form->{cp_id} *= 1;

  for $i (1 .. $form->{rowcount}) {
    map({ $form->{"${_}_${i}"} = $form->parse_amount(\%myconfig,
                                                     $form->{"${_}_${i}"})
            if ($form->{"${_}_${i}"}) }
        qw(ship qty sellprice listprice basefactor));
  }

  if (   $form->{type} =~ /_order/
      && $form->{currency} ne $form->{defaultcurrency}) {

    # check if we need a new exchangerate
    $buysell = ($form->{type} eq 'sales_order') ? "buy" : "sell";

    $orddate      = $form->current_date(\%myconfig);
    $exchangerate =
      $form->check_exchangerate(\%myconfig, $form->{currency}, $orddate,
                                $buysell);

    if (!$exchangerate) {
      &backorder_exchangerate($orddate, $buysell);
      exit;
    }
  }

  # close orders/quotations
  $form->{closed} = 1;

  # save order if one ordnumber has been given
  # if not it's most likely a collective order, which can't be saved back
  # so they just have to be closed
  if (($form->{ordnumber} ne '') || ($form->{quonumber} ne '')) {
    OE->close_order(\%myconfig, \%$form);
  } else {
    OE->close_orders(\%myconfig, \%$form);
  }

  $form->{transdate} = $form->{invdate} = $form->current_date(\%myconfig);
  $form->{duedate} =
    $form->current_date(\%myconfig, $form->{invdate}, $form->{terms} * 1);

  $form->{id}     = '';
  $form->{closed} = 0;
  $form->{rowcount}--;
  $form->{shipto} = 1;

  if ($form->{type} =~ /_order$/) {
    $form->{exchangerate} = $exchangerate;
    &create_backorder;
  }

  if (   $form->{type} eq 'purchase_order'
      || $form->{type} eq 'request_quotation') {
    $form->{title}  = $locale->text('Add Vendor Invoice');
    $form->{script} = 'ir.pl';
    $script         = "ir";
    $buysell        = 'sell';
  }
  if ($form->{type} eq 'sales_order' || $form->{type} eq 'sales_quotation') {
    $form->{title}  = $locale->text('Add Sales Invoice');
    $form->{script} = 'is.pl';
    $script         = "is";
    $buysell        = 'buy';
  }

  # bo creates the id, reset it
  map { delete $form->{$_} }
    qw(id subject message cc bcc printed emailed queued);
  $form->{ $form->{vc} } =~ s/--.*//g;
  $form->{type} = "invoice";

  # locale messages
  $locale = new Locale "$myconfig{countrycode}", "$script";

  require "$form->{path}/$form->{script}";

  map { $form->{"select$_"} = "" } ($form->{vc}, currency);

  map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) }
    qw(creditlimit creditremaining);

  $currency = $form->{currency};
  &invoice_links;

  $form->{currency}     = $currency;
  $form->{exchangerate} = "";
  $form->{forex}        = "";
  $form->{exchangerate} = $exchangerate
    if (
        $form->{forex} = (
                    $exchangerate =
                      $form->check_exchangerate(
                      \%myconfig, $form->{currency}, $form->{invdate}, $buysell
                      )));

  $form->{creditremaining} -= ($form->{oldinvtotal} - $form->{ordtotal});

  &prepare_invoice;

  # format amounts
  for $i (1 .. $form->{rowcount}) {
    $form->{"discount_$i"} =
      $form->format_amount(\%myconfig, $form->{"discount_$i"});

    ($dec) = ($form->{"sellprice_$i"} =~ /\.(\d+)/);
    $dec           = length $dec;
    $decimalplaces = ($dec > 2) ? $dec : 2;

    # copy delivery date from reqdate for order -> invoice conversion
    $form->{"deliverydate_$i"} = $form->{"reqdate_$i"}
      unless $form->{"deliverydate_$i"};

    $form->{"sellprice_$i"} =
      $form->format_amount(\%myconfig, $form->{"sellprice_$i"},
                           $decimalplaces);

    (my $dec_qty) = ($form->{"qty_$i"} =~ /\.(\d+)/);
    $dec_qty = length $dec_qty;
    $form->{"qty_$i"} =
      $form->format_amount(\%myconfig, $form->{"qty_$i"}, $dec_qty);

    map { $form->{"${_}_$i"} =~ s/\"/&quot;/g }
      qw(partnumber description unit);

  }

  &display_form;

  $lxdebug->leave_sub();
}

sub backorder_exchangerate {
  $lxdebug->enter_sub();
  my ($orddate, $buysell) = @_;

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>
|;

  # delete action variable
  map { delete $form->{$_} } qw(action header exchangerate);

  foreach $key (keys %$form) {
    $form->{$key} =~ s/\"/&quot;/g;
    print qq|<input type=hidden name=$key value="$form->{$key}">\n|;
  }

  $form->{title} = $locale->text('Add Exchangerate');

  print qq|

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input type=hidden name=exchangeratedate value=$orddate>
<input type=hidden name=buysell value=$buysell>

<table width=100%>
  <tr><th class=listtop>$form->{title}</th></tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
        <tr>
	  <th align=right>| . $locale->text('Currency') . qq|</th>
	  <td>$form->{currency}</td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Date') . qq|</th>
	  <td>$orddate</td>
	</tr>
        <tr>
	  <th align=right>| . $locale->text('Exchangerate') . qq|</th>
	  <td><input name=exchangerate size=11></td>
        </tr>
      </table>
    </td>
  </tr>
</table>

<hr size=3 noshade>

<br>
<input type=hidden name=nextsub value=save_exchangerate>

<input name=action class=submit type=submit value="|
    . $locale->text('Continue') . qq|">

</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub save_exchangerate {
  $lxdebug->enter_sub();

  $form->isblank("exchangerate", $locale->text('Exchangerate missing!'));
  $form->{exchangerate} =
    $form->parse_amount(\%myconfig, $form->{exchangerate});
  $form->save_exchangerate(\%myconfig, $form->{currency},
                           $form->{exchangeratedate},
                           $form->{exchangerate}, $form->{buysell});

  &invoice;

  $lxdebug->leave_sub();
}

sub create_backorder {
  $lxdebug->enter_sub();

  $form->{shipped} = 1;

  # figure out if we need to create a backorder
  # items aren't saved if qty != 0

  for $i (1 .. $form->{rowcount}) {
    $totalqty  += $qty  = $form->{"qty_$i"};
    $totalship += $ship = $form->{"ship_$i"};

    $form->{"qty_$i"} = $qty - $ship;
  }

  if ($totalship == 0) {
    map { $form->{"ship_$_"} = $form->{"qty_$_"} } (1 .. $form->{rowcount});
    $form->{ordtotal} = 0;
    $form->{shipped}  = 0;
    return;
  }

  if ($totalqty == $totalship) {
    map { $form->{"qty_$_"} = $form->{"ship_$_"} } (1 .. $form->{rowcount});
    $form->{ordtotal} = 0;
    return;
  }

  @flds = (
    qw(partnumber description qty ship unit sellprice discount id inventory_accno bin income_accno expense_accno listprice assembly taxaccounts partsgroup)
  );

  for $i (1 .. $form->{rowcount}) {
    map {
      $form->{"${_}_$i"} =
        $form->format_amount(\%myconfig, $form->{"${_}_$i"})
    } qw(sellprice discount);
  }

  relink_accounts();

  OE->save(\%myconfig, \%$form);

  # rebuild rows for invoice
  @a     = ();
  $count = 0;

  for $i (1 .. $form->{rowcount}) {
    $form->{"qty_$i"} = $form->{"ship_$i"};

    if ($form->{"qty_$i"}) {
      push @a, {};
      $j = $#a;
      map { $a[$j]->{$_} = $form->{"${_}_$i"} } @flds;
      $count++;
    }
  }

  $form->redo_rows(\@flds, \@a, $count, $form->{rowcount});
  $form->{rowcount} = $count;

  $lxdebug->leave_sub();
}

sub save_as_new {
  $lxdebug->enter_sub();

  $form->{saveasnew} = 1;
  $form->{closed}    = 0;
  map { delete $form->{$_} } qw(printed emailed queued);

  # Let Lx-Office assign a new order number if the user hasn't changed the
  # previous one. If it has been changed manually then use it as-is.
  my $idx = $form->{type} =~ /_quotation$/ ? "quonumber" : "ordnumber";
  if ($form->{saved_xyznumber} &&
      ($form->{saved_xyznumber} eq $form->{$idx})) {
    delete($form->{$idx});
  }

  &save;

  $lxdebug->leave_sub();
}

sub purchase_order {
  $lxdebug->enter_sub();

  if (   $form->{type} eq 'sales_quotation'
      || $form->{type} eq 'request_quotation') {
    OE->close_order(\%myconfig, \%$form);
  }

  $form->{cp_id} *= 1;

  $form->{title} = $locale->text('Add Purchase Order');
  $form->{vc}    = "vendor";
  $form->{type}  = "purchase_order";

  &poso;

  $lxdebug->leave_sub();
}

sub sales_order {
  $lxdebug->enter_sub();

  if (   $form->{type} eq 'sales_quotation'
      || $form->{type} eq 'request_quotation') {
    OE->close_order(\%myconfig, $form);
  }

  $form->{cp_id} *= 1;

  $form->{title} = $locale->text('Add Sales Order');
  $form->{vc}    = "customer";
  $form->{type}  = "sales_order";

  &poso;

  $lxdebug->leave_sub();
}

sub poso {
  $lxdebug->enter_sub();

  $form->{transdate} = $form->current_date(\%myconfig);
  delete $form->{duedate};

  $form->{closed} = 0;

  # reset
  map { delete $form->{$_} }
    qw(id subject message cc bcc printed emailed queued customer vendor creditlimit creditremaining discount tradediscount oldinvtotal);

  for $i (1 .. $form->{rowcount}) {
    map({ $form->{"${_}_${i}"} = $form->parse_amount(\%myconfig,
                                                     $form->{"${_}_${i}"})
            if ($form->{"${_}_${i}"}) }
        qw(ship qty sellprice listprice basefactor));
  }

  &order_links;

  &prepare_order;

  # format amounts
  for $i (1 .. $form->{rowcount} - 1) {
    map { $form->{"${_}_$i"} =~ s/\"/&quot;/g }
      qw(partnumber description unit);
  }

  map { $form->{$_} = $form->format_amount(\%myconfig, $form->{$_}, 0, "0") }
    qw(creditlimit creditremaining);

  &update;

  $lxdebug->leave_sub();
}

