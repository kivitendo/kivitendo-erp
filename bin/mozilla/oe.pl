#=====================================================================
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

use SL::OE;
use SL::IR;
use SL::IS;
use SL::PE;

require "$form->{path}/io.pl";
require "$form->{path}/arap.pl";

1;

# end of main

sub add {
  $lxdebug->enter_sub();

  if ($form->{type} eq 'purchase_order') {
    $form->{title} = $locale->text('Add Purchase Order');
    $form->{vc}    = 'vendor';
  }
  if ($form->{type} eq 'sales_order') {
    $form->{title} = $locale->text('Add Sales Order');
    $form->{vc}    = 'customer';
  }
  if ($form->{type} eq 'request_quotation') {
    $form->{title} = $locale->text('Add Request for Quotation');
    $form->{vc}    = 'vendor';
  }
  if ($form->{type} eq 'sales_quotation') {
    $form->{title} = $locale->text('Add Quotation');
    $form->{vc}    = 'customer';
  }

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

  if ($form->{type} eq 'purchase_order') {
    $form->{title}   = $locale->text('Edit Purchase Order');
    $form->{heading} = $locale->text('Purchase Order');
    $form->{vc}      = 'vendor';
  }
  if ($form->{type} eq 'sales_order') {
    $form->{title}   = $locale->text('Edit Sales Order');
    $form->{heading} = $locale->text('Sales Order');
    $form->{vc}      = 'customer';
  }
  if ($form->{type} eq 'request_quotation') {
    $form->{title}   = $locale->text('Edit Request for Quotation');
    $form->{heading} = $locale->text('Request for Quotation');
    $form->{vc}      = 'vendor';
  }
  if ($form->{type} eq 'sales_quotation') {
    $form->{title}   = $locale->text('Edit Quotation');
    $form->{heading} = $locale->text('Quotation');
    $form->{vc}      = 'customer';
  }

  &order_links;
  &prepare_order;
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
  if ($form->{type} =~ /(purchase_order|request_quotation|receive_order)/) {
    IR->get_vendor(\%myconfig, \%$form);
  }
  if ($form->{type} =~ /(sales|ship)_(order|quotation)/) {
    IS->get_customer(\%myconfig, \%$form);
  }
  $form->{cp_id} = $cp_id;

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
  @curr = split /:/, $form->{currencies};
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
  $form->{format}   = "html";
  $form->{media}    = "screen";
  $form->{formname} = $form->{type};

  if ($form->{id}) {

    map { $form->{$_} =~ s/\"/&quot;/g }
      qw(ordnumber quonumber shippingpoint shipvia notes intnotes shiptoname shiptostreet shiptozipcode shiptocity shiptocountry shiptocontact);

    foreach $ref (@{ $form->{form_details} }) {
      $i++;
      map { $form->{"${_}_$i"} = $ref->{$_} } keys %{$ref};
      $form->{"discount_$i"} =
        $form->format_amount(\%myconfig, $form->{"discount_$i"} * 100);

      ($dec) = ($form->{"sellprice_$i"} =~ /\.(\d+)/);
      $dec           = length $dec;
      $decimalplaces = ($dec > 2) ? $dec : 2;

      $form->{"sellprice_$i"} =
        $form->format_amount(\%myconfig, $form->{"sellprice_$i"},
                             $decimalplaces);
      $form->{"qty_$i"} = $form->format_amount(\%myconfig, $form->{"qty_$i"});

      map { $form->{"${_}_$i"} =~ s/\"/&quot;/g }
        qw(partnumber description unit);
      $form->{rowcount} = $i;
    }
  } elsif ($form->{rowcount}) {
    for my $i (1 .. $form->{rowcount}) {
       $form->{"discount_$i"} =
        $form->format_amount(\%myconfig, $form->{"discount_$i"} * 100);

      ($dec) = ($form->{"sellprice_$i"} =~ /\.(\d+)/);
      $dec           = length $dec;
      $decimalplaces = ($dec > 2) ? $dec : 2;

      $form->{"sellprice_$i"} =
        $form->format_amount(\%myconfig, $form->{"sellprice_$i"},
                             $decimalplaces);
      $form->{"qty_$i"} = $form->format_amount(\%myconfig, $form->{"qty_$i"});

      map { $form->{"${_}_$i"} =~ s/\"/&quot;/g }
        qw(partnumber description unit);
    }
  }

  $lxdebug->leave_sub();
}

sub form_header {
  $lxdebug->enter_sub();

  $checkedopen   = ($form->{closed}) ? ""        : "checked";
  $checkedclosed = ($form->{closed}) ? "checked" : "";

  # use JavaScript Calendar or not
  $form->{jsscript} = $form->{jscalendar};
  $jsscript = "";

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
	  <table>
	    <tr>
	      <th nowrap><input name=closed type=radio class=radio value=0 $checkedopen> |
      . $locale->text('Open') . qq|</th>
	      <th nowrap><input name=closed type=radio class=radio value=1 $checkedclosed> |
      . $locale->text('Closed') . qq|</th>
	    </tr>
	  </table>
	</td>
      </tr>
|;
  }

  # set option selected
  foreach $item ($form->{vc}, currency, department, employee, contact) {
    $form->{"select$item"} =~ s/ selected//;
    $form->{"select$item"} =~
      s/option>\Q$form->{$item}\E/option selected>$form->{$item}/;
  }

  #build contacts
  if ($form->{all_contacts}) {

    $form->{selectcontact} = "";
    foreach $item (@{ $form->{all_contacts} }) {
      if ($form->{cp_id} == $item->{cp_id}) {
        $form->{selectcontact} .=
          "<option selected>$item->{cp_name}--$item->{cp_id}";
      } else {
        $form->{selectcontact} .= "<option>$item->{cp_name}--$item->{cp_id}";
      }
    }
  }

  $form->{exchangerate} =
    $form->format_amount(\%myconfig, $form->{exchangerate});

  $form->{creditlimit} =
    $form->format_amount(\%myconfig, $form->{creditlimit}, 0, "0");
  $form->{creditremaining} =
    $form->format_amount(\%myconfig, $form->{creditremaining}, 0, "0");

  $contact =
    ($form->{selectcontact})
    ? qq|<select name=contact>$form->{selectcontact}</select>\n<input type=hidden name="selectcontact" value="$form->{selectcontact}">|
    : qq|<input name=contact value="$form->{contact}" size=35>|;

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

  $terms = qq|
                    <tr>
		      <th align=right nowrap>| . $locale->text('Terms: Net') . qq|</th>
		      <td nowrap><input name=terms size="3" maxlength="3" value=$form->{terms}> |
    . $locale->text('days') . qq|</td>
                    </tr>
|;

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
		      <td class="plus$n">$form->{creditremaining}</td>
		    </tr>
		  </table>
		</td>
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

      $terms = "";
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

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{id}>

<input type=hidden name=type value=$form->{type}>
<input type=hidden name=formname value=$form->{formname}>
<input type=hidden name=media value=$form->{media}>
<input type=hidden name=format value=$form->{format}>

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
	      </tr>
	    </table>
	  </td>
	  <td align=right>
	    <table>
	      $openclosed
	      $employee
	      $ordnumber
	      $terms
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
		<th align=right>$form->{"${item}_description"}</th>
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
		<th align=right>Enthaltene $form->{"${item}_description"}</th>
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

Bearbeiten des $form->{heading}<br>
<input class=submit type=submit name=action value="|
    . $locale->text('Update') . qq|">
<input class=submit type=submit name=action value="|
    . $locale->text('Ship to') . qq|">
<input class=submit type=submit name=action value="|
    . $locale->text('Print') . qq|">
<input class=submit type=submit name=action value="|
    . $locale->text('E-mail') . qq|">
<input class=submit type=submit name=action value="|
    . $locale->text('Save') . qq|">
|;

  if ($form->{id}) {
    print qq|
<br>Workflow  $form->{heading}<br>
<input class=submit type=submit name=action value="|
      . $locale->text('Save as new') . qq|">
<input class=submit type=submit name=action value="|
      . $locale->text('Delete') . qq|">|;
    if ($form->{type} =~ /quotation$/) {
      print qq|
<input class=submit type=submit name=action value="|
        . $locale->text('Order') . qq|">|;
    }
    print qq|
<input class=submit type=submit name=action value="|
      . $locale->text('Invoice') . qq|">
|;

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
        . $locale->text('Quotation') . qq|">
|;

    } else {
      print qq|
<br>$form->{heading} als neue Vorlage verwenden f&uuml;r<br>
<input class=submit type=submit name=action value="|
        . $locale->text('Order') . qq|">
|;
    }
  }

  if ($form->{menubar}) {
    require "$form->{path}/menu.pl";
    &menubar;
  }

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

  map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) }
    qw(exchangerate creditlimit creditremaining);

  &check_name($form->{vc});

  &check_project;

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

        map { $form->{item_list}[$i]{$_} =~ s/\"/&quot;/g }
          qw(partnumber description unit);
        map { $form->{"${_}_$i"} = $form->{item_list}[0]{$_} }
          keys %{ $form->{item_list}[0] };

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
          $form->format_amount(\%myconfig, $form->{"qty_$i"});

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
  if ($form->{type} eq 'receive_order') {
    $form->{title} = $locale->text('Receive Merchandise');
    $form->{vc}    = 'vendor';
    $ordlabel      = $locale->text('Order Number');
    $ordnumber     = 'ordnumber';
    $employee      = $locale->text('Employee');
  }
  if ($form->{type} eq 'sales_order') {
    $form->{title} = $locale->text('Sales Orders');
    $form->{vc}    = 'customer';
    $ordlabel      = $locale->text('Order Number');
    $ordnumber     = 'ordnumber';
    $employee      = $locale->text('Salesperson');
  }
  if ($form->{type} eq 'ship_order') {
    $form->{title} = $locale->text('Ship Merchandise');
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

  if ($form->{type} =~ /(ship|receive)_order/) {
    OE->get_warehouses(\%myconfig, \%$form);

    # warehouse
    if (@{ $form->{all_warehouses} }) {
      $form->{selectwarehouse} = "<option>\n";
      $form->{warehouse}       = qq|$form->{warehouse}--$form->{warehouse_id}|;

      map {
        $form->{selectwarehouse} .=
          "<option>$_->{description}--$_->{id}\n"
      } (@{ $form->{all_warehouses} });

      $warehouse = qq|
	      <tr>
		<th align=right>| . $locale->text('Warehouse') . qq|</th>
		<td colspan=3><select name=warehouse>$form->{selectwarehouse}</select></td>
		<input type=hidden name=selectwarehouse value="$form->{selectwarehouse}">
	      </tr>
|;

    }
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

  if ($form->{type} !~ /(ship_order|receive_order)/) {
    $openclosed = qq|
	      <tr>
	        <td><input name="open" class=checkbox type=checkbox value=1 checked> |
      . $locale->text('Open') . qq|</td>
	        <td><input name="closed" class=checkbox type=checkbox value=1 $form->{closed}> |
      . $locale->text('Closed') . qq|</td>
	      </tr>
|;
  } else {

    $openclosed = qq|
	        <input type=hidden name="open" value=1>
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
	$warehouse
	$department
        <tr>
          <th align=right>$ordlabel</th>
          <td colspan=3><input name="$ordnumber" size=20></td>
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
	      $openclosed
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
	      </tr>
	      <tr>
		<td><input name="l_netamount" class=checkbox type=checkbox value=Y> |
    . $locale->text('Amount') . qq|</td>
		<td><input name="l_tax" class=checkbox type=checkbox value=Y> |
    . $locale->text('Tax') . qq|</td>
		<td><input name="l_amount" class=checkbox type=checkbox value=Y checked> |
    . $locale->text('Total') . qq|</td>
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
  $warehouse  = $form->escape($form->{warehouse});

  # construct href
  $href =
    "$form->{script}?path=$form->{path}&action=orders&type=$form->{type}&vc=$form->{vc}&login=$form->{login}&password=$form->{password}&transdatefrom=$form->{transdatefrom}&transdateto=$form->{transdateto}&open=$form->{open}&closed=$form->{closed}&$ordnumber=$number&$form->{vc}=$name&department=$department&warehouse=$warehouse";

  # construct callback
  $number     = $form->escape($form->{$ordnumber},    1);
  $name       = $form->escape($form->{ $form->{vc} }, 1);
  $department = $form->escape($form->{department},    1);
  $warehouse  = $form->escape($form->{warehouse},     1);

  $callback =
    "$form->{script}?path=$form->{path}&action=orders&type=$form->{type}&vc=$form->{vc}&login=$form->{login}&password=$form->{password}&transdatefrom=$form->{transdatefrom}&transdateto=$form->{transdateto}&open=$form->{open}&closed=$form->{closed}&$ordnumber=$number&$form->{vc}=$name&department=$department&warehouse=$warehouse";

  @columns =
    $form->sort_columns("transdate", "reqdate",   "id",      "$ordnumber",
                        "name",      "netamount", "tax",     "amount",
                        "curr",      "employee",  "shipvia", "open",
                        "closed");

  $form->{l_open} = $form->{l_closed} = "Y"
    if ($form->{open} && $form->{closed});

  foreach $item (@columns) {
    if ($form->{"l_$item"} eq "Y") {
      push @column_index, $item;

      # add column to href and callback
      $callback .= "&l_$item=Y";
      $href     .= "&l_$item=Y";
    }
  }

  if ($form->{l_subtotal} eq 'Y') {
    $callback .= "&l_subtotal=Y";
    $href     .= "&l_subtotal=Y";
  }

  if ($form->{vc} eq 'vendor') {
    if ($form->{type} eq 'receive_order') {
      $form->{title} = $locale->text('Receive Merchandise');
    } elsif ($form->{type} eq 'purchase_order') {
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
    } elsif ($form->{type} eq 'ship_order') {
      $form->{title} = $locale->text('Ship Merchandise');
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
    . $locale->text('Quotation')
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
  $column_header{open} =
    qq|<th class=listheading>| . $locale->text('O') . qq|</th>|;
  $column_header{closed} =
    qq|<th class=listheading>| . $locale->text('C') . qq|</th>|;

  $column_header{employee} =
    qq|<th><a class=listheading href=$href&sort=employee>$employee</a></th>|;

  if ($form->{ $form->{vc} }) {
    $option = $locale->text(ucfirst $form->{vc});
    $option .= " : $form->{$form->{vc}}";
  }
  if ($form->{warehouse}) {
    ($warehouse) = split /--/, $form->{warehouse};
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('Warehouse');
    $option .= " : $warehouse";
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
  $callback = $form->escape($callback . "&sort=$form->{sort}");

  if (@{ $form->{OE} }) {
    $sameitem = $form->{OE}->[0]->{ $form->{sort} };
  }

  $action = "edit";
  $action = "ship_receive" if ($form->{type} =~ /(ship|receive)_order/);

  $warehouse = $form->escape($form->{warehouse});

  foreach $oe (@{ $form->{OE} }) {

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

    $column_data{id}        = "<td>$oe->{id}</td>";
    $column_data{transdate} = "<td>$oe->{transdate}&nbsp;</td>";
    $column_data{reqdate}   = "<td>$oe->{reqdate}&nbsp;</td>";

    $column_data{$ordnumber} =
      "<td><a href=oe.pl?path=$form->{path}&action=$action&type=$form->{type}&id=$oe->{id}&warehouse=$warehouse&vc=$form->{vc}&login=$form->{login}&password=$form->{password}&callback=$callback>$oe->{$ordnumber}</a></td>";
    $column_data{name} = "<td>$oe->{name}</td>";

    $column_data{employee} = "<td>$oe->{employee}&nbsp;</td>";
    $column_data{shipvia}  = "<td>$oe->{shipvia}&nbsp;</td>";

    if ($oe->{closed}) {
      $column_data{closed} = "<td align=center>X</td>";
      $column_data{open}   = "<td>&nbsp;</td>";
    } else {
      $column_data{closed} = "<td>&nbsp;</td>";
      $column_data{open}   = "<td align=center>X</td>";
    }

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
</table>

<br>
<form method=post action=$form->{script}>

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=type value=$form->{type}>
<input type=hidden name=vc value=$form->{vc}>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>
|;

  if ($form->{type} !~ /(ship|receive)_order/) {
    print qq|
<input class=submit type=submit name=action value="|
      . $locale->text('Add') . qq|">|;
  }

  if ($form->{menubar}) {
    require "$form->{path}/menu.pl";
    &menubar;
  }

  print qq|
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

  $form->redirect(
            $form->{label} . " $form->{$ordnumber} " . $locale->text('saved!'))
    if (OE->save(\%myconfig, \%$form));
  $form->error($err);

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

  $form->redirect($msg) if (OE->delete(\%myconfig, \%$form, $spool));
  $form->error($err);

  $lxdebug->leave_sub();
}

sub invoice {
  $lxdebug->enter_sub();

  if ($form->{type} =~ /_order$/) {
    $form->isblank("ordnumber", $locale->text('Order Number missing!'));
    $form->isblank("transdate", $locale->text('Order Date missing!'));

  } else {
    $form->isblank("quonumber", $locale->text('Quotation Number missing!'));
    $form->isblank("transdate", $locale->text('Quotation Date missing!'));
    $form->{ordnumber} = "";
  }

  # if the name changed get new values
  if (&check_name($form->{vc})) {
    &update;
    exit;
  }

  ($null, $form->{cp_id}) = split /--/, $form->{contact};
  $form->{cp_id} *= 1;

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
  OE->save(\%myconfig, \%$form);

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

    $form->{"sellprice_$i"} =
      $form->format_amount(\%myconfig, $form->{"sellprice_$i"},
                           $decimalplaces);
    $form->{"qty_$i"} = $form->format_amount(\%myconfig, $form->{"qty_$i"});

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

  &save;

  $lxdebug->leave_sub();
}

sub purchase_order {
  $lxdebug->enter_sub();

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
    $form->{closed} = 1;
    OE->save(\%myconfig, \%$form);
  }

  ($null, $form->{cp_id}) = split /--/, $form->{contact};
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

sub ship_receive {
  $lxdebug->enter_sub();

  &order_links;

  &prepare_order;

  OE->get_warehouses(\%myconfig, \%$form);

  # warehouse
  if (@{ $form->{all_warehouses} }) {
    $form->{selectwarehouse} = "<option>\n";

    map { $form->{selectwarehouse} .= "<option>$_->{description}--$_->{id}\n" }
      (@{ $form->{all_warehouses} });

    if ($form->{warehouse}) {
      $form->{selectwarehouse} = "<option>$form->{warehouse}";
    }
  }

  $form->{shippingdate} = $form->current_date(\%myconfig);
  $form->{"$form->{vc}"} =~ s/--.*//;

  @flds  = ();
  @a     = ();
  $count = 0;
  foreach $key (keys %$form) {
    if ($key =~ /_1$/) {
      $key =~ s/_1//;
      push @flds, $key;
    }
  }

  for $i (1 .. $form->{rowcount}) {

    # undo formatting from prepare_order
    map {
      $form->{"${_}_$i"} =
        $form->parse_amount(\%myconfig, $form->{"${_}_$i"})
    } qw(qty ship);
    $n = ($form->{"qty_$i"} -= $form->{"ship_$i"});
    if (abs($n) > 0
        && ($form->{"inventory_accno_$i"} || $form->{"assembly_$i"})) {
      $form->{"ship_$i"}         = "";
      $form->{"serialnumber_$i"} = "";

      push @a, {};
      $j = $#a;

      map { $a[$j]->{$_} = $form->{"${_}_$i"} } @flds;
      $count++;
    }
  }

  $form->redo_rows(\@flds, \@a, $count, $form->{rowcount});
  $form->{rowcount} = $count;

  &display_ship_receive;

  $lxdebug->leave_sub();
}

sub display_ship_receive {
  $lxdebug->enter_sub();

  $vclabel = ucfirst $form->{vc};
  $vclabel = $locale->text($vclabel);

  $form->{rowcount}++;

  if ($form->{vc} eq 'customer') {
    $form->{title} = $locale->text('Ship Merchandise');
    $shipped = $locale->text('Shipping Date');
  } else {
    $form->{title} = $locale->text('Receive Merchandise');
    $shipped = $locale->text('Date Received');
  }

  # set option selected
  foreach $item (warehouse, employee) {
    $form->{"select$item"} =~ s/ selected//;
    $form->{"select$item"} =~
      s/option>\Q$form->{$item}\E/option selected>$form->{$item}/;
  }

  $warehouse = qq|
	      <tr>
		<th align=right>| . $locale->text('Warehouse') . qq|</th>
		<td><select name=warehouse>$form->{selectwarehouse}</select></td>
		<input type=hidden name=selectwarehouse value="$form->{selectwarehouse}">
	      </tr>
| if $form->{selectwarehouse};

  $employee = qq|
 	      <tr>
	        <th align=right nowrap>| . $locale->text('Contact') . qq|</th>
		<td><select name=employee>$form->{selectemployee}</select></td>
		<input type=hidden name=selectemployee value="$form->{selectemployee}">
	      </tr>
|;

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{id}>

<input type=hidden name=display_form value=display_ship_receive>

<input type=hidden name=type value=$form->{type}>
<input type=hidden name=media value=$form->{media}>
<input type=hidden name=format value=$form->{format}>

<input type=hidden name=queued value="$form->{queued}">
<input type=hidden name=printed value="$form->{printed}">
<input type=hidden name=emailed value="$form->{emailed}">

<input type=hidden name=vc value=$form->{vc}>

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
		<td colspan=3>$form->{$form->{vc}}</td>
		<input type=hidden name=$form->{vc} value="$form->{$form->{vc}}">
		<input type=hidden name="$form->{vc}_id" value=$form->{"$form->{vc}_id"}>
	      </tr>
	      $department
	      <tr>
		<th align=right>| . $locale->text('Shipping Point') . qq|</th>
		<td colspan=3>
		<input name=shippingpoint size=35 value="$form->{shippingpoint}">
	      </tr>
	      <tr>
		<th align=right>| . $locale->text('Ship via') . qq|</th>
		<td colspan=3>
		<input name=shipvia size=35 value="$form->{shipvia}">
	      </tr>
	      $warehouse
	    </table>
	  </td>
	  <td align=right>
	    <table>
	      $employee
	      <tr>
		<th align=right nowrap>| . $locale->text('Order Number') . qq|</th>
		<td>$form->{ordnumber}</td>
		<input type=hidden name=ordnumber value="$form->{ordnumber}">
	      </tr>
	      <tr>
		<th align=right nowrap>| . $locale->text('Order Date') . qq|</th>
		<td>$form->{transdate}</td>
		<input type=hidden name=transdate value=$form->{transdate}>
	      </tr>
	      <tr>
		<th align=right nowrap>$shipped</th>
		<td><input name=shippingdate size=11 value=$form->{shippingdate}></td>
	      </tr>
	    </table>
	  </td>
	</tr>
      </table>
    </td>
  </tr>

<!-- shipto are in hidden variables -->

<input type=hidden name=shiptoname value="$form->{shiptoname}">
<input type=hidden name=shiptostreet value="$form->{shiptostreet}">
<input type=hidden name=shiptozipcode value="$form->{shiptozipcode}">
<input type=hidden name=shiptocity value="$form->{shiptocity}">
<input type=hidden name=shiptocountry value="$form->{shiptocountry}">
<input type=hidden name=shiptocontact value="$form->{shiptocontact}">
<input type=hidden name=shiptophone value="$form->{shiptophone}">
<input type=hidden name=shiptofax value="$form->{shiptofax}">
<input type=hidden name=shiptoemail value="$form->{shiptoemail}">

<!-- email variables -->
<input type=hidden name=message value="$form->{message}">
<input type=hidden name=email value="$form->{email}">
<input type=hidden name=subject value="$form->{subject}">
<input type=hidden name=cc value="$form->{cc}">
<input type=hidden name=bcc value="$form->{bcc}">

|;

  @column_index =
    (partnumber, description, qty, ship, unit, bin, serialnumber);

  if ($form->{type} eq "ship_order") {
    $column_data{ship} =
        qq|<th class=listheading align=center width="auto">|
      . $locale->text('Ship')
      . qq|</th>|;
  }
  if ($form->{type} eq "receive_order") {
    $column_data{ship} =
        qq|<th class=listheading align=center width="auto">|
      . $locale->text('Recd')
      . qq|</th>|;
  }

  my $colspan = $#column_index + 1;

  $column_data{partnumber} =
    qq|<th class=listheading nowrap>| . $locale->text('Number') . qq|</th>|;
  $column_data{description} =
      qq|<th class=listheading nowrap>|
    . $locale->text('Description')
    . qq|</th>|;
  $column_data{qty} =
    qq|<th class=listheading nowrap>| . $locale->text('Qty') . qq|</th>|;
  $column_data{unit} =
    qq|<th class=listheading nowrap>| . $locale->text('Unit') . qq|</th>|;
  $column_data{bin} =
    qq|<th class=listheading nowrap>| . $locale->text('Bin') . qq|</th>|;
  $column_data{serialnumber} =
      qq|<th class=listheading nowrap>|
    . $locale->text('Serial No.')
    . qq|</th>|;

  print qq|
  <tr>
    <td>
      <table width=100%>
	<tr class=listheading>|;

  map { print "\n$column_data{$_}" } @column_index;

  print qq|
        </tr>
|;

  for $i (1 .. $form->{rowcount} - 1) {

    # undo formatting
    $form->{"ship_$i"} = $form->parse_amount(\%myconfig, $form->{"ship_$i"});

    # convert " to &quot;
    map { $form->{"${_}_$i"} =~ s/\"/&quot;/g }
      qw(partnumber description unit bin serialnumber);

    $description = $form->{"description_$i"};
    $description =~ s/\n/<br>/g;

    $column_data{partnumber} =
      qq|<td>$form->{"partnumber_$i"}<input type=hidden name="partnumber_$i" value="$form->{"partnumber_$i"}"></td>|;
    $column_data{description} =
      qq|<td>$description<input type=hidden name="description_$i" value="$form->{"description_$i"}"></td>|;
    $column_data{qty} =
        qq|<td align=right>|
      . $form->format_amount(\%myconfig, $form->{"qty_$i"})
      . qq|<input type=hidden name="qty_$i" value="$form->{"qty_$i"}"></td>|;
    $column_data{ship} =
        qq|<td align=right><input name="ship_$i" size=5 value=|
      . $form->format_amount(\%myconfig, $form->{"ship_$i"})
      . qq|></td>|;
    $column_data{unit} =
      qq|<td>$form->{"unit_$i"}<input type=hidden name="unit_$i" value="$form->{"unit_$i"}"></td>|;
    $column_data{bin} =
      qq|<td>$form->{"bin_$i"}<input type=hidden name="bin_$i" value="$form->{"bin_$i"}"></td>|;

    $column_data{serialnumber} =
      qq|<td><input name="serialnumber_$i" size=15 value="$form->{"serialnumber_$i"}"></td>|;

    print qq|
        <tr valign=top>|;

    map { print "\n$column_data{$_}" } @column_index;

    print qq|
        </tr>

<input type=hidden name="orderitems_id_$i" value=$form->{"orderitems_id_$i"}>
<input type=hidden name="id_$i" value=$form->{"id_$i"}>
<input type=hidden name="assembly_$i" value="$form->{"assembly_$i"}">
<input type=hidden name="partsgroup_$i" value="$form->{"partsgroup_$i"}">

|;

  }

  print qq|
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
  <tr>
    <td>
|;

  $form->{copies} = 1;

  &print_options;

  print qq|
    </td>
  </tr>
</table>
<br>
<input class=submit type=submit name=action value="|
    . $locale->text('Update') . qq|">
<input class=submit type=submit name=action value="|
    . $locale->text('Print') . qq|">
|;

  if ($form->{type} eq 'ship_order') {
    print qq|
<input class=submit type=submit name=action value="|
      . $locale->text('Ship to') . qq|">
<input class=submit type=submit name=action value="|
      . $locale->text('E-mail') . qq|">
|;
  }

  print qq|

<input class=submit type=submit name=action value="|
    . $locale->text('Done') . qq|">
|;

  if ($form->{menubar}) {
    require "$form->{path}/menu.pl";
    &menubar;
  }

  print qq|

<input type=hidden name=rowcount value=$form->{rowcount}>

<input name=callback type=hidden value="$callback">

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub done {
  $lxdebug->enter_sub();

  if ($form->{type} eq 'ship_order') {
    $form->isblank("shippingdate", $locale->text('Shipping Date missing!'));
  } else {
    $form->isblank("shippingdate", $locale->text('Date received missing!'));
  }

  $total = 0;
  map {
    $total += $form->{"ship_$_"} =
      $form->parse_amount(\%myconfig, $form->{"ship_$_"})
  } (1 .. $form->{rowcount} - 1);

  $form->error($locale->text('Nothing entered!')) unless $total;

  $form->redirect($locale->text('Inventory saved!'))
    if OE->save_inventory(\%myconfig, \%$form);
  $form->error($locale->text('Could not save!'));

  $lxdebug->leave_sub();
}

sub search_transfer {
  $lxdebug->enter_sub();

  OE->get_warehouses(\%myconfig, \%$form);

  # warehouse
  if (@{ $form->{all_warehouses} }) {
    $form->{selectwarehouse} = "<option>\n";
    $form->{warehouse}       = qq|$form->{warehouse}--$form->{warehouse_id}|;

    map { $form->{selectwarehouse} .= "<option>$_->{description}--$_->{id}\n" }
      (@{ $form->{all_warehouses} });
  } else {
    $form->error($locale->text('Nothing to transfer!'));
  }

  $form->{title} = $locale->text('Transfer Inventory');

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
          <th align=right nowrap>| . $locale->text('Transfer to') . qq|</th>
          <td><select name=warehouse>$form->{selectwarehouse}</select></td>
        </tr>
	<tr>
	  <th align="right" nowrap="true">| . $locale->text('Part Number') . qq|</th>
	  <td><input name=partnumber size=20></td>
	</tr>
	<tr>
	  <th align="right" nowrap="true">| . $locale->text('Description') . qq|</th>
	  <td><input name=description size=40></td>
	</tr>
	<tr>
	  <th align=right nowrap>| . $locale->text('Group') . qq|</th>
	  <td><input name=partsgroup size=20></td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<br>
<input type=hidden name=sort value=partnumber>
<input type=hidden name=nextsub value=list_transfer>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input class=submit type=submit name=action value="|
    . $locale->text('Continue') . qq|">
</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub list_transfer {
  $lxdebug->enter_sub();

  OE->get_inventory(\%myconfig, \%$form);

  $partnumber  = $form->escape($form->{partnumber});
  $warehouse   = $form->escape($form->{warehouse});
  $description = $form->escape($form->{description});
  $partsgroup  = $form->escape($form->{partsgroup});

  # construct href
  $href =
    "$form->{script}?path=$form->{path}&action=list_transfer&partnumber=$partnumber&warehouse=$warehouse&description=$description&partsgroup=$partsgroup&login=$form->{login}&password=$form->{password}";

  # construct callback
  $partnumber  = $form->escape($form->{partnumber},  1);
  $warehouse   = $form->escape($form->{warehouse},   1);
  $description = $form->escape($form->{description}, 1);
  $partsgroup  = $form->escape($form->{partsgroup},  1);

  $callback =
    "$form->{script}?path=$form->{path}&action=list_transfer&partnumber=$partnumber&warehouse=$warehouse&description=$description&partsgroup=$partsgroup&login=$form->{login}&password=$form->{password}";

  @column_index =
    $form->sort_columns(
      qw(partnumber description partsgroup make model warehouse qty transfer));

  $column_header{partnumber} =
      qq|<th><a class=listheading href=$href&sort=partnumber>|
    . $locale->text('Part Number')
    . qq|</a></th>|;
  $column_header{description} =
      qq|<th><a class=listheading href=$href&sort=description>|
    . $locale->text('Description')
    . qq|</a></th>|;
  $column_header{partsgroup} =
      qq|<th><a class=listheading href=$href&sort=partsgroup>|
    . $locale->text('Group')
    . qq|</a></th>|;
  $column_header{warehouse} =
      qq|<th><a class=listheading href=$href&sort=warehouse>|
    . $locale->text('From')
    . qq|</a></th>|;
  $column_header{qty} =
    qq|<th><a class=listheading>| . $locale->text('Qty') . qq|</a></th>|;
  $column_header{transfer} =
    qq|<th><a class=listheading>| . $locale->text('Transfer') . qq|</a></th>|;

  $option = $locale->text('Transfer to');

  ($warehouse, $warehouse_id) = split /--/, $form->{warehouse};

  if ($form->{warehouse}) {
    $option .= " : $warehouse";
  }
  if ($form->{partnumber}) {
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('Part Number') . " : $form->{partnumber}";
  }
  if ($form->{description}) {
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('Description') . " : $form->{description}";
  }
  if ($form->{partsgroup}) {
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('Group') . " : $form->{partsgroup}";
  }

  $form->{title} = $locale->text('Transfer Inventory');

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=warehouse_id value=$warehouse_id>

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

  if (@{ $form->{all_inventory} }) {
    $sameitem = $form->{all_inventory}->[0]->{ $form->{sort} };
  }

  $i = 0;
  foreach $ref (@{ $form->{all_inventory} }) {

    $i++;

    $column_data{partnumber} =
      qq|<td><input type=hidden name="id_$i" value=$ref->{id}>$ref->{partnumber}</td>|;
    $column_data{description} = "<td>$ref->{description}&nbsp;</td>";
    $column_data{partsgroup}  = "<td>$ref->{partsgroup}&nbsp;</td>";
    $column_data{warehouse}   =
      qq|<td><input type=hidden name="warehouse_id_$i" value=$ref->{warehouse_id}>$ref->{warehouse}&nbsp;</td>|;
    $column_data{qty} =
        qq|<td><input type=hidden name="qty_$i" value=$ref->{qty}>|
      . $form->format_amount(\%myconfig, $ref->{qty})
      . qq|</td>|;
    $column_data{transfer} = qq|<td><input name="transfer_$i" size=4></td>|;

    $j++;
    $j %= 2;
    print "
        <tr class=listrow$j>";

    map { print "\n$column_data{$_}" } @column_index;

    print qq|
	</tr>
|;

  }

  print qq|
      </table>
    </td>
  </tr>

  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<br>

<input name=callback type=hidden value="$callback">

<input type=hidden name=rowcount value=$i>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input class=submit type=submit name=action value="|
    . $locale->text('Transfer') . qq|">|;

  if ($form->{menubar}) {
    require "$form->{path}/menu.pl";
    &menubar;
  }

  print qq|
</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub transfer {
  $lxdebug->enter_sub();

  $form->redirect($locale->text('Inventory transferred!'))
    if OE->transfer(\%myconfig, \%$form);
  $form->error($locale->text('Could not transfer Inventory!'));

  $lxdebug->leave_sub();
}
