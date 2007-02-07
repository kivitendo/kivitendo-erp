#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (c) 1998-2002
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
#  Contributors: Reed White <alta@alta-research.com>
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
# customer/vendor module
#
#======================================================================

# $locale->text('Customers')
# $locale->text('Vendors')
# $locale->text('Add Customer')
# $locale->text('Add Vendor')

use SL::CT;
use CGI::Ajax;
use CGI;
use Data::Dumper;

1;

# end of main

sub add {
  $lxdebug->enter_sub();

  $form->{title} = "Add";

  $form->{callback} =
    "$form->{script}?action=add&db=$form->{db}&path=$form->{path}&login=$form->{login}&password=$form->{password}"
    unless $form->{callback};

  CT->taxaccounts(\%myconfig, \%$form);

  &form_header;
  &form_footer;

  $lxdebug->leave_sub();
}

sub search {
  $lxdebug->enter_sub();

  $label = ucfirst $form->{db};
  $form->{title} = $locale->text($label . "s");

  if ($form->{db} eq 'vendor') {
    $gifi = qq|
		<td><input name="l_gifi_accno" type=checkbox class=checkbox value=Y> |
      . $locale->text('GIFI') . qq|</td>
|;
  }

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=db value=$form->{db}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr valign=top>
    <td>
      <table>
	<tr>
	  <th align=right nowrap>| . $locale->text($label . ' Number') . qq|</th>
	  <td><input name=$form->{db}number size=35></td>
	</tr>
	<tr>
	  <th align=right nowrap>| . $locale->text('Company Name') . qq|</th>
	  <td><input name=name size=35></td>
	</tr>
	<tr>
	  <th align=right nowrap>| . $locale->text('Contact') . qq|</th>
	  <td><input name=contact size=35></td>
	</tr>
	<tr>
	  <th align=right nowrap>| . $locale->text('E-mail') . qq|</th>
	  <td><input name=email size=35></td>
	</tr>
	<tr>
	  <td></td>
	  <td><input name=status class=radio type=radio value=all checked>&nbsp;|
    . $locale->text('All') . qq|
	  <input name=status class=radio type=radio value=orphaned>&nbsp;|
    . $locale->text('Orphaned') . qq|</td>
	</tr>
	<tr>
	  <th align=right nowrap>| . $locale->text('Include in Report') . qq|</th>
	  <td>
	    <table>
	      <tr>
	        <td><input name="l_id" type=checkbox class=checkbox value=Y> |
    . $locale->text('ID') . qq|</td>
		<td><input name="l_$form->{db}number" type=checkbox class=checkbox value=Y> |
    . $locale->text($label . ' Number') . qq|</td>
		<td><input name="l_name" type=checkbox class=checkbox value=Y checked> |
    . $locale->text('Company Name') . qq|</td>
		<td><input name="l_address" type=checkbox class=checkbox value=Y> |
    . $locale->text('Address') . qq|</td>
	      </tr>
	      <tr>
		<td><input name="l_contact" type=checkbox class=checkbox value=Y checked> |
    . $locale->text('Contact') . qq|</td>
		<td><input name="l_phone" type=checkbox class=checkbox value=Y checked> |
    . $locale->text('Phone') . qq|</td>
		<td><input name="l_fax" type=checkbox class=checkbox value=Y> |
    . $locale->text('Fax') . qq|</td>
		<td><input name="l_email" type=checkbox class=checkbox value=Y checked> |
    . $locale->text('E-mail') . qq|</td>
	      </tr>
	      <tr>
		<td><input name="l_taxnumber" type=checkbox class=checkbox value=Y> |
    . $locale->text('Tax Number') . qq|</td>
		$gifi
		<td><input name="l_sic_code" type=checkbox class=checkbox value=Y> |
    . $locale->text('SIC') . qq|</td>
		<td><input name="l_business" type=checkbox class=checkbox value=Y> |
    . $locale->text('Type of Business') . qq|</td>
	      </tr>
	      <tr>
		<td><input name="l_invnumber" type=checkbox class=checkbox value=Y> |
    . $locale->text('Invoices') . qq|</td>
		<td><input name="l_ordnumber" type=checkbox class=checkbox value=Y> |
    . $locale->text('Orders') . qq|</td>
		<td><input name="l_quonumber" type=checkbox class=checkbox value=Y> |
    . $locale->text('Quotations') . qq|</td>
	      </tr>
	    </table>
	  </td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<input type=hidden name=nextsub value=list_names>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<br>
<input type=submit class=submit name=action value="|
    . $locale->text('Continue') . qq|">
</form>

</body>
</html>
|;
  $lxdebug->leave_sub();
}

sub search_delivery {
  $lxdebug->enter_sub();

  $label = ucfirst $form->{db};
  $form->{title} = $locale->text($label . "s");

  if ($form->{db} eq 'vendor') {
    $gifi = qq|
		<td><input name="l_gifi_accno" type=checkbox class=checkbox value=Y> |
      . $locale->text('GIFI') . qq|</td>
|;
  }

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=db value=$form->{db}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr valign=top>
    <td>
      <table>
	<tr>
	  <th align=right nowrap>| . $locale->text($label . ' Number') . qq|</th>
	  <td><input name=$form->{db}number size=35></td>
	</tr>
	<tr>
	  <th align=right nowrap>| . $locale->text('Company Name') . qq|</th>
	  <td><input name=name size=35></td>
	</tr>
	<tr>
	  <th align=right nowrap>| . $locale->text('Contact') . qq|</th>
	  <td><input name=contact size=35></td>
	</tr>
	<tr>
	  <th align=right nowrap>| . $locale->text('E-mail') . qq|</th>
	  <td><input name=email size=35></td>
	</tr>
	<tr>
	  <td></td>
	  <td><input name=status class=radio type=radio value=all checked>&nbsp;|
    . $locale->text('All') . qq|
	  <input name=status class=radio type=radio value=orphaned>&nbsp;|
    . $locale->text('Orphaned') . qq|</td>
	</tr>
	<tr>
	  <th align=right nowrap>| . $locale->text('Include in Report') . qq|</th>
	  <td>
	    <table>
	      <tr>
	        <td><input name="l_id" type=checkbox class=checkbox value=Y> |
    . $locale->text('ID') . qq|</td>
		<td><input name="l_$form->{db}number" type=checkbox class=checkbox value=Y> |
    . $locale->text($label . ' Number') . qq|</td>
		<td><input name="l_name" type=checkbox class=checkbox value=Y checked> |
    . $locale->text('Company Name') . qq|</td>
		<td><input name="l_address" type=checkbox class=checkbox value=Y> |
    . $locale->text('Address') . qq|</td>
	      </tr>
	      <tr>
		<td><input name="l_contact" type=checkbox class=checkbox value=Y checked> |
    . $locale->text('Contact') . qq|</td>
		<td><input name="l_phone" type=checkbox class=checkbox value=Y checked> |
    . $locale->text('Phone') . qq|</td>
		<td><input name="l_fax" type=checkbox class=checkbox value=Y> |
    . $locale->text('Fax') . qq|</td>
		<td><input name="l_email" type=checkbox class=checkbox value=Y checked> |
    . $locale->text('E-mail') . qq|</td>
	      </tr>
	      <tr>
		<td><input name="l_taxnumber" type=checkbox class=checkbox value=Y> |
    . $locale->text('Tax Number') . qq|</td>
		$gifi
		<td><input name="l_sic_code" type=checkbox class=checkbox value=Y> |
    . $locale->text('SIC') . qq|</td>
		<td><input name="l_business" type=checkbox class=checkbox value=Y> |
    . $locale->text('Type of Business') . qq|</td>
	      </tr>
	      <tr>
		<td><input name="l_invnumber" type=checkbox class=checkbox value=Y> |
    . $locale->text('Invoices') . qq|</td>
		<td><input name="l_ordnumber" type=checkbox class=checkbox value=Y> |
    . $locale->text('Orders') . qq|</td>
		<td><input name="l_quonumber" type=checkbox class=checkbox value=Y> |
    . $locale->text('Quotations') . qq|</td>
	      </tr>
	    </table>
	  </td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<input type=hidden name=nextsub value=list_names>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<br>
<input type=submit class=submit name=action value="|
    . $locale->text('Continue') . qq|">
</form>

</body>
</html>
|;
  $lxdebug->leave_sub();
}

sub list_names {
  $lxdebug->enter_sub();

  CT->search(\%myconfig, \%$form);

  $callback =
    "$form->{script}?action=list_names&db=$form->{db}&path=$form->{path}&login=$form->{login}&password=$form->{password}&status=$form->{status}";
  $href = $callback;

  @columns =
    $form->sort_columns(id, name,
                        "$form->{db}number", address,
                        contact,             phone,
                        fax,                 email,
                        taxnumber,           gifi_accno,
                        sic_code,            business,
                        invnumber,           ordnumber,
                        quonumber);

  foreach $item (@columns) {
    if ($form->{"l_$item"} eq "Y") {
      push @column_index, $item;

      # add column to href and callback
      $callback .= "&l_$item=Y";
      $href     .= "&l_$item=Y";
    }
  }
  $number =
    ($form->{db} eq "customer")
    ? $locale->text('Customer Number')
    : $locale->text('Vendor Number');

  if ($form->{status} eq 'all') {
    $option = $locale->text('All');
  }
  if ($form->{status} eq 'orphaned') {
    $option .= $locale->text('Orphaned');
  }
  if ($form->{name}) {
    $callback .= "&name=" . $form->escape($form->{name}, 1);
    $href .= "&name=" . $form->escape($form->{name});
    $option .= "\n<br>" . $locale->text('Name') . " : $form->{name}";
  }
  if ($form->{contact}) {
    $callback .= "&contact=" . $form->escape($form->{contact}, 1);
    $href .= "&contact=" . $form->escape($form->{contact});
    $option .= "\n<br>" . $locale->text('Contact') . " : $form->{contact}";
  }
  if ($form->{"$form->{db}number"}) {
    $callback .=
      qq|&$form->{db}number=| . $form->escape($form->{"$form->{db}number"}, 1);
    $href .=
      "&$form->{db}number=" . $form->escape($form->{"$form->{db}number"});
    $option .=
      "\n<br>" . $locale->text('Number') . qq| : $form->{"$form->{db}number"}|;
  }
  if ($form->{email}) {
    $callback .= "&email=" . $form->escape($form->{email}, 1);
    $href .= "&email=" . $form->escape($form->{email});
    $option .= "\n<br>" . $locale->text('E-mail') . " : $form->{email}";
  }

  $form->{callback} = "$callback&sort=$form->{sort}";
  $callback = $form->escape($form->{callback});

  $column_header{id} =
    qq|<th class=listheading>| . $locale->text('ID') . qq|</th>|;
  $column_header{"$form->{db}number"} =
    qq|<th><a class=listheading href=$href&sort=$form->{db}number>$number</a></th>|;
  $column_header{name} =
      qq|<th><a class=listheading href=$href&sort=name>|
    . $locale->text('Name')
    . qq|</a></th>|;
  $column_header{address} =
      qq|<th><a class=listheading href=$href&sort=address>|
    . $locale->text('Address')
    . qq|</a></th>|;
  $column_header{contact} =
      qq|<th><a class=listheading href=$href&sort=contact>|
    . $locale->text('Contact')
    . qq|</a></th>|;
  $column_header{phone} =
      qq|<th><a class=listheading href=$href&sort=phone>|
    . $locale->text('Phone')
    . qq|</a></th>|;
  $column_header{fax} =
      qq|<th><a class=listheading href=$href&sort=fax>|
    . $locale->text('Fax')
    . qq|</a></th>|;
  $column_header{email} =
      qq|<th><a class=listheading href=$href&sort=email>|
    . $locale->text('E-mail')
    . qq|</a></th>|;
  $column_header{cc} =
      qq|<th><a class=listheading href=$href&sort=cc>|
    . $locale->text('Cc')
    . qq|</a></th>|;

  $column_header{taxnumber} =
      qq|<th><a class=listheading href=$href&sort=taxnumber>|
    . $locale->text('Tax Number')
    . qq|</a></th>|;
  $column_header{gifi_accno} =
      qq|<th><a class=listheading href=$href&sort=gifi_accno>|
    . $locale->text('GIFI')
    . qq|</a></th>|;
  $column_header{sic_code} =
      qq|<th><a class=listheading href=$href&sort=sic_code>|
    . $locale->text('SIC')
    . qq|</a></th>|;
  $column_header{business} =
      qq|<th><a class=listheading href=$href&sort=business>|
    . $locale->text('Type of Business')
    . qq|</a></th>|;

  $column_header{invnumber} =
      qq|<th><a class=listheading href=$href&sort=invnumber>|
    . $locale->text('Invoice')
    . qq|</a></th>|;
  $column_header{ordnumber} =
      qq|<th><a class=listheading href=$href&sort=ordnumber>|
    . $locale->text('Order')
    . qq|</a></th>|;
  $column_header{quonumber} =
      qq|<th><a class=listheading href=$href&sort=quonumber>|
    . $locale->text('Quotation')
    . qq|</a></th>|;

  $label = ucfirst $form->{db} . "s";
  $form->{title} = $locale->text($label);

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
	<tr class=listheading>
|;

  map { print "$column_header{$_}\n" } @column_index;

  print qq|
        </tr>
|;

  $ordertype = ($form->{db} eq 'customer') ? 'sales_order' : 'purchase_order';
  $quotationtype =
    ($form->{db} eq 'customer') ? 'sales_quotation' : 'request_quotation';

  foreach $ref (@{ $form->{CT} }) {

    if ($ref->{id} eq $sameid) {
      map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;
    } else {
      map { $column_data{$_} = "<td>$ref->{$_}&nbsp;</td>" } @column_index;

      map { $column_data{$_} = "<td>$ref->{$_}&nbsp;</td>" }
        (invnumber, ordnumber, quonumber);

      $column_data{name} =
        "<td align=left><a href=$form->{script}?action=edit&id=$ref->{id}&db=$form->{db}&path=$form->{path}&login=$form->{login}&password=$form->{password}&status=$form->{status}&callback=$callback>$ref->{name}&nbsp;</td>";

      if ($ref->{email}) {
        $email = $ref->{email};
        $email =~ s/</\&lt;/;
        $email =~ s/>/\&gt;/;

        $column_data{email} =
          qq|<td><a href="mailto:$ref->{email}">$email</a></td>|;
      }

    }

    if ($ref->{formtype} eq 'invoice') {
      $column_data{invnumber} =
        "<td><a href=$ref->{module}.pl?action=edit&id=$ref->{invid}&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback>$ref->{invnumber}&nbsp;</td>";
    }

    if ($ref->{formtype} eq 'order') {
      $column_data{ordnumber} =
        "<td><a href=$ref->{module}.pl?action=edit&id=$ref->{invid}&type=$ordertype&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback>$ref->{ordnumber}&nbsp;</td>";
    }

    if ($ref->{formtype} eq 'quotation') {
      $column_data{quonumber} =
        "<td><a href=$ref->{module}.pl?action=edit&id=$ref->{invid}&type=$quotationtype&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback>$ref->{quonumber}&nbsp;</td>";
    }

    $i++;
    $i %= 2;
    print "
        <tr class=listrow$i>
";

    map { print "$column_data{$_}\n" } @column_index;

    print qq|
        </tr>
|;

    $sameid = $ref->{id};

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
<form method=post action=$form->{script}>

<input name=callback type=hidden value="$form->{callback}">
<input name=db type=hidden value=$form->{db}>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input class=submit type=submit name=action value="|
    . $locale->text('Add') . qq|">

  </form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub edit {
  $lxdebug->enter_sub();

  # $locale->text('Edit Customer')
  # $locale->text('Edit Vendor')

  CT->get_tuple(\%myconfig, \%$form);

  # format " into &quot;
  map { $form->{$_} =~ s/\"/&quot;/g } keys %$form;

  $form->{title} = "Edit";

  # format discount
  $form->{discount} *= 100;

  &form_header;
  &form_footer;

  $lxdebug->leave_sub();
}

sub form_header {
  $lxdebug->enter_sub();

  $form->{taxincluded} = ($form->{taxincluded}) ? "checked" : "";
  $form->{creditlimit} =
    $form->format_amount(\%myconfig, $form->{creditlimit}, 0);
  $form->{discount} = $form->format_amount(\%myconfig, $form->{discount});

  if ($myconfig{role} eq 'admin') {
    $bcc = qq|
        <tr>
	  <th align=right nowrap>| . $locale->text('Bcc') . qq|</th>
	  <td><input name=bcc size=35 value="$form->{bcc}"></td>
	</tr>
|;
  }
  $form->{obsolete} = "checked" if $form->{obsolete};

  $lang = qq|<option value=""></option>|;
  foreach $item (@{ $form->{languages} }) {
    if ($form->{language_id} eq $item->{id}) {
      $lang .= qq|<option value="$item->{id}" selected>$item->{description}</option>|;
    } else {
      $lang .= qq|<option value="$item->{id}">$item->{description}</option>|;
    }
  }

  $payment = qq|<option value=""></option>|;
  foreach $item (@{ $form->{payment_terms} }) {
    if ($form->{payment_id} eq $item->{id}) {
      $payment .= qq|<option value="$item->{id}" selected>$item->{description}</option>|;
    } else {
      $payment .= qq|<option value="$item->{id}">$item->{description}</option>|;
    }
  }

  if (!$form->{id}) {
    if ($form->{db} eq "customer") {
      $form->{taxzone_id} = 0;
    } else {
      $form->{taxzone_id} = 0;
    }
  }

  if (@{ $form->{TAXZONE} }) {
    foreach $item (@{ $form->{TAXZONE} }) {
      if ($item->{id} == $form->{taxzone_id}) {
        $form->{selecttaxzone} .=
          "<option value=$item->{id} selected>$item->{description}\n";
      } else {
        $form->{selecttaxzone} .=
          "<option value=$item->{id}>$item->{description}\n";
      }

    }
  }

  $taxzone = qq|
	      <tr>
		<th align=right>| . $locale->text('Steuersatz') . qq|</th>
		<td><select name=taxzone_id>$form->{selecttaxzone}</select></td>
		<input type=hidden name=selecttaxzone value="$form->{selecttaxzone}">
	      </tr>|;

  $get_contact_url =
    "$form->{script}?login=$form->{login}&path=$form->{path}&password=$form->{password}&action=get_contact";

  my $pjx = new CGI::Ajax( 'get_contact' => $get_contact_url );
  $form->{selectcontact} = "<option value=0></option>";
  if (@{ $form->{CONTACTS} }) {
    foreach $item (@{ $form->{CONTACTS} }) {
      if ($item->{cp_id} == $form->{cp_id}) {
        $form->{selectcontact} .=
          qq|<option value=$item->{cp_id} selected>$item->{cp_name}</option>\n|;
      } else {
        $form->{selectcontact} .=
          qq|<option value=$item->{cp_id}>$item->{cp_name}</option>\n|;
      }

    }
  }
  push(@ { $form->{AJAX} }, $pjx);
  $ansprechpartner = qq|
	      <tr>
		<th align=right>| . $locale->text('Ansprechpartner') . qq|</th>
		<td><select id=cp_id name=cp_id onChange="get_contact(['cp_id__' + this.value], ['cp_name', 'cp_greeting', 'cp_title', 'cp_givenname', 'cp_phone1', 'cp_phone2', 'cp_email', 'cp_abteilung', 'cp_fax', 'cp_mobile1', 'cp_mobile2', 'cp_satphone', 'cp_satfax', 'cp_project', 'cp_privatphone', 'cp_privatemail', 'cp_birthday'])">$form->{selectcontact}</select></td>
		<input type=hidden name=selectcontact value="$form->{selectcontact}">
	      </tr>|;
  $get_shipto_url =
    "$form->{script}?login=$form->{login}&path=$form->{path}&password=$form->{password}&action=get_shipto";

  my $pjy = new CGI::Ajax( 'get_shipto' => $get_shipto_url );
  $form->{selectshipto} = "<option value=0></option>";
  $form->{selectshipto} .= "<option value=0>Alle</option>";
  if (@{ $form->{SHIPTO} }) {
    foreach $item (@{ $form->{SHIPTO} }) {
      if ($item->{shipto_id} == $form->{shipto_id}) {
        $form->{selectshipto} .=
          "<option value=$item->{shipto_id} selected>$item->{shiptoname} $item->{shiptodepartment_1}\n";
      } else {
        $form->{selectshipto} .=
          "<option value=$item->{shipto_id}>$item->{shiptoname} $item->{shiptodepartment_1}\n";
      }

    }
  }
  push(@ { $form->{AJAX} }, $pjy);

  $shipto = qq|
	      <tr>
		<th align=right>| . $locale->text('Shipping Address') . qq|</th>
		<td><select id=shipto_id name=shipto_id onChange="get_shipto(['shipto_id__' + this.value], ['shiptoname','shiptodepartment_1', 'shiptodepartment_2','shiptostreet','shiptozipcode','shiptocity','shiptocountry','shiptocontact','shiptophone','shiptofax','shiptoemail'])">$form->{selectshipto}</select></td>
		<input type=hidden name=selectshipto value="$form->{selectshipto}">
	      </tr>|;


  $get_delivery_url =
    "$form->{script}?login=$form->{login}&path=$form->{path}&password=$form->{password}&action=get_delivery";

  my $pjz = new CGI::Ajax( 'get_delivery' => $get_delivery_url );

  push(@ { $form->{AJAX} }, $pjz);

  $delivery = qq|
	      <tr>
		<th align=right>| . $locale->text('Shipping Address') . qq|</th>
		<td><select id=delivery_id name=delivery_id onChange="get_delivery(['shipto_id__' + this.value, 'from__' + from.value, 'to__' + to.value, 'id__' + cvid.value, 'db__' + db.value], ['delivery'])">$form->{selectshipto}</select></td>
	      </tr>|;

  foreach $item (split / /, $form->{taxaccounts}) {
    if (($form->{tax}{$item}{taxable}) || !($form->{id})) {
      $taxable .=
        qq| <input name="tax_$item" value=1 class=checkbox type=checkbox checked>&nbsp;<b>$form->{tax}{$item}{description}</b>|;
    } else {
      $taxable .=
        qq| <input name="tax_$item" value=1 class=checkbox type=checkbox>&nbsp;<b>$form->{tax}{$item}{description}</b>|;
    }
  }

##LINET
  $taxable = "";

  if ($taxable) {
    $tax = qq|
  <tr>
    <th align=right>| . $locale->text('Taxable') . qq|</th>
    <td colspan=2>
      <table>
        <tr>
	  <td>$taxable</td>
  	  <td><input name=taxincluded class=checkbox type=checkbox value=1 $form->{taxincluded}></td>
	  <th align=left>| . $locale->text('Tax Included') . qq|</th>
	</tr>
      </table>
    </td>
  </tr>
|;
  }
  $form->{selectbusiness} = qq|<option>\n|;
  map {
    $form->{selectbusiness} .=
      qq|<option value=$_->{id}>$_->{description}\n|
  } @{ $form->{all_business} };
  if ($form->{business_save}) {
    $form->{selectbusiness} = $form->{business_save};
  }
  $form->{selectbusiness} =~
    s/<option value=$form->{business}>/<option value=$form->{business} selected>/;

  $label = ucfirst $form->{db};
  if ($form->{title} eq "Edit") {
    $form->{title} = $locale->text("$form->{title} $label") . " $form->{name}";
  } else  {
    $form->{title} = $locale->text("$form->{title} $label");
  }
  if ($form->{title_save}) {
    $form->{title} = $form->{title_save};
  }
  if ($form->{db} eq 'vendor') {
    $customer = qq|
           <th align=right>| . $locale->text('Kundennummer') . qq|</th>
           <td><input name=v_customer_id size=10 tabindex=18 maxlength=35 value="$form->{v_customer_id}"></td>
|;
  }

  if ($form->{db} eq 'customer') {

    $customer = qq|
           <th align=right>| . $locale->text('KNr. beim Kunden') . qq|</th>
           <td><input name=c_vendor_id size=10 tabindex=18 maxlength=35 value="$form->{c_vendor_id}"></td>
|;
  }
  $business_salesman = "";
  $business          = "<th></th><td></td>";
  if ($vertreter) {
    $business_salesman = qq|
	<tr>
          <td colspan=3>
            <table>
	     <th align=right>| . $locale->text('Type of Business') . qq|</th>
	     <td><select name=business tabindex=1>$form->{selectbusiness}</select></td>
	     <th align=right>| . $locale->text('Salesman') . qq|</th>
	     <td><input name=salesman tabindex=2 value="$form->{salesman}"></td>
             <input type=hidden name=salesman_id value="$form->{salesman_id}">
             <input type=hidden name=oldsalesman value="$form->{oldsalesman}">
            </table>
          </td>
       <tr>|;
    $business = qq|
	     <th align=right>| . $locale->text('Username') . qq|</th>
	     <td><input name=username maxlength=50 tabindex=22 value="$form->{username}"></td>
 	     <th align=right>| . $locale->text('Password') . qq|</th>
	     <td><input name=user_password maxlength=12 tabindex=23 value="$form->{user_password}"></td>|;
  } else {
    $business = qq|
 	  <th align=right>| . $locale->text('Type of Business') . qq|</th>
	  <td><select name=business tabindex=22>$form->{selectbusiness}</select></td>
      |;
  }

## LINET: Create a drop-down box with all prior titles and greetings.
  CT->query_titles_and_greetings(\%myconfig, \%$form);

  $select_title = qq|&nbsp;<select name=selected_cp_title><option></option>|;
  map({ $select_title .= qq|<option>$_</option>|; } @{ $form->{TITLES} });
  $select_title .= qq|</select>|;

  $select_greeting =
    qq|&nbsp;<select name=selected_cp_greeting><option></option>|;
  map(
     { $select_greeting .= qq|<option>$_</option>|; } @{ $form->{GREETINGS} });
  $select_greeting .= qq|</select>|;

  $select_company_greeting =
    qq|&nbsp;<select name=selected_company_greeting><option></option>|;
  map(
     { $select_company_greeting .= qq|<option>$_</option>|; } @{ $form->{COMPANY_GREETINGS} });
  $select_company_greeting .= qq|</select>|;

  $select_department =
    qq|&nbsp;<select name=selected_cp_abteilung><option></option>|;
  map(
     { $select_department .= qq|<option>$_</option>|; } @{ $form->{DEPARTMENT} });
  $select_department .= qq|</select>|;
## /LINET

  if ($form->{db} eq 'customer') {

    #get pricegroup and form it
    $form->get_pricegroup(\%myconfig, { all => 1 });

    $form->{pricegroup}    = "$form->{klass}";
    $form->{pricegroup_id} = "$form->{klass}";

    if (@{ $form->{all_pricegroup} }) {

      $form->{selectpricegroup} = qq|<option>\n|;
      map {
        $form->{selectpricegroup} .=
          qq|<option value="$_->{id}">$_->{pricegroup}\n|
      } @{ $form->{all_pricegroup} };
    }

    if ($form->{selectpricegroup}) {
      $form->{selectpricegroup} = $form->unescape($form->{selectpricegroup});

      $pricegroup =
        qq|<input type=hidden name=selectpricegroup value="|
        . $form->escape($form->{selectpricegroup}, 1) . qq|">|;

      $form->{selectpricegroup} =~
        s/(<option value="\Q$form->{klass}\E")/$1 selected/;

      $pricegroup .=
        qq|<select name=klass tabindex=24>$form->{selectpricegroup}</select>|;

    }
  }

  # $locale->text('Customer Number')
  # $locale->text('Vendor Number')
  $form->{fokus} = "ct.greeting";
  $form->{jsscript} = 1;
  $form->header;

  print qq|
<body onLoad="fokus()">
<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
</table>


<form method=post name="ct" action=$form->{script} onKeyUp="highlight(event)" onClick="highlight(event)">



<ul id="maintab" class="shadetabs">
<li class="selected"><a href="#" rel="billing">|
    . $locale->text('Billing Address') . qq|</a></li>
<li><a href="#" rel="shipto">|
    . $locale->text('Shipping Address') . qq|</a></li>
<li><a href="#" rel="contacts">Ansprechpartner</a></li>
<li><a href="#" rel="deliveries">|
    . $locale->text('Lieferungen') . qq|</a></li>

</ul>

<div class="tabcontentstyle">

<div id="billing" class="tabcontent">

      <table width=100%>
	<tr height="5"></tr>
        $business_salesman
	<tr>
	  <th align=right nowrap>| . $locale->text($label . ' Number') . qq|</th>
	  <td><input name="$form->{db}number" size=35 maxlength=35 value="$form->{"$form->{db}number"}"></td>
	</tr>
        <tr>
          <th align=right nowrap>| . $locale->text('Greeting') . qq|</th>
          <td><input id=greeting name=greeting size=30 maxlength=30 value="$form->{greeting}">&nbsp;
          $select_company_greeting</td>
        </tr>
	<tr>
	  <th align=right nowrap>| . $locale->text('Company Name') . qq|</th>
	  <td><input name=name size=35 maxlength=75 value="$form->{name}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>| . $locale->text('Abteilung') . qq|</th>
	  <td><input name=department_1 size=16 maxlength=75 value="$form->{department_1}">
	  <input name=department_2 size=16 maxlength=75 value="$form->{department_2}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>| . $locale->text('Street') . qq|</th>
	  <td><input name=street size=35 maxlength=75 value="$form->{street}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|
    . $locale->text('Zipcode') . "/" . $locale->text('City') . qq|</th>
	  <td><input name=zipcode size=5 maxlength=10 value="$form->{zipcode}">
          <input name=city size=30 maxlength=75 value="$form->{city}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>| . $locale->text('Country') . qq|</th>
	  <td><input name=country size=35 maxlength=75 value="$form->{country}"></td>
	</tr>
	<tr>
          <th align=right nowrap>| . $locale->text('Contact') . qq|</th>
          <td><input name=contact size=28 maxlength=75 value="$form->{contact}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>| . $locale->text('Phone') . qq|</th>
	  <td><input name=phone size=30 maxlength=30 value="$form->{phone}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>| . $locale->text('Fax') . qq|</th>
	  <td><input name=fax size=30 maxlength=30 value="$form->{fax}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>| . $locale->text('E-mail') . qq|</th>
	  <td><input name=email size=45 value="$form->{email}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>| . $locale->text('Homepage') . qq|</th>
	  <td><input name=homepage size=45 value="$form->{homepage}"></td>
	</tr>
</table>
<table>
	<tr>
	  <th align=right>| . $locale->text('Credit Limit') . qq|</th>
	  <td><input name=creditlimit size=9 value="$form->{creditlimit}"></td>
	  <input type="hidden" name="terms" value="$form->{terms}">
	  <th align=right>| . $locale->text('Payment Terms') . qq|</th>
	  <td><select name=payment_id>$payment</select></td>
	  <th align=right>| . $locale->text('Discount') . qq|</th>
	  <td><input name=discount size=4 value="$form->{discount}">
	  %</td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Tax Number / SSN') . qq|</th>
	  <td><input name=taxnumber size=20 value="$form->{taxnumber}"></td>
          <th align=right>| . $locale->text('USt-IdNr.') . qq|</th>
	  <td><input name="ustid" maxlength="14" size="20" value="$form->{ustid}"></td>
          $customer
	</tr>
        <tr>
          <th align=right>| . $locale->text('Account Number') . qq|</th>
          <td><input name=account_number size=10 value="$form->{account_number}"></td>
          <th align=right>| . $locale->text('Bank Code Number') . qq|</th>
          <td><input name=bank_code size=10 value="$form->{bank_code}"></td>
          <th align=right>| . $locale->text('Bank') . qq|</th>
          <td><input name=bank size=30 value="$form->{bank}"></td>
        </tr>
	<tr>
          $business
	  <th align=right>| . $locale->text('Language') . qq|</th>
	  <td><select name=language_id tabindex=23>$lang
                          </select></td>|;

  if ($form->{db} eq 'customer') {

    print qq|
          <th align=right>| . $locale->text('Preisklasse') . qq|</th>
          <td>$pricegroup</td>|;
  }
  print qq|        </tr>
        <tr>
          <td align=right>| . $locale->text('Obsolete') . qq|</td>
          <td><input name=obsolete class=checkbox type=checkbox value=1 $form->{obsolete}></td>
	</tr>
        $taxzone
      </table>
  <table>
  <tr>
    <th align=left nowrap>| . $locale->text('Notes') . qq|</th>
  </tr>
  <tr>
    <td><textarea name=notes rows=3 cols=60 wrap=soft>$form->{notes}</textarea></td>
  </tr>

            </table>
          </td>
        </tr>
</table>
<br style="clear: left" /></div>|;

print qq|
      <div id="shipto" class="tabcontent">

      <table width=100%>
$shipto
	<tr>
	  <th align=right nowrap>| . $locale->text('Company Name') . qq|</th>
	  <td><input id=shiptoname name=shiptoname size=35 maxlength=75 value="$form->{shiptoname}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>| . $locale->text('Abteilung') . qq|</th>
          <td><input id=shiptodepartment_1 name=shiptodepartment_1 size=16 maxlength=75 value="$form->{shiptodepartment_1}">
	  <input id=shiptodepartment_2 name=shiptodepartment_2 size=16 maxlength=75 value="$form->{shiptodepartment_2}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>| . $locale->text('Street') . qq|</th>
	  <td><input id=shiptostreet name=shiptostreet size=35 maxlength=75 value="$form->{shiptostreet}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>|
    . $locale->text('Zipcode') . "/" . $locale->text('City') . qq|</th>
	  <td><input id=shiptozipcode name=shiptozipcode size=5 maxlength=10 value="$form->{shiptozipcode}">
          <input id=shiptocity name=shiptocity size=30 maxlength=75 value="$form->{shiptocity}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>| . $locale->text('Country') . qq|</th>
	  <td><input id=shiptocountry name=shiptocountry size=35 maxlength=35 value="$form->{shiptocountry}"></td>
	</tr>
	<tr>
          <th align=right nowrap>| . $locale->text('Contact') . qq|</th>
	  <td><input id=shiptocontact name=shiptocontact size=30 maxlength=75 value="$form->{shiptocontact}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>| . $locale->text('Phone') . qq|</th>
	  <td><input id=shiptophone name=shiptophone size=30 maxlength=30 value="$form->{shiptophone}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>| . $locale->text('Fax') . qq|</th>
	  <td><input id=shiptofax name=shiptofax size=30 maxlength=30 value="$form->{shiptofax}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>| . $locale->text('E-mail') . qq|</th>
	  <td><input id=shiptoemail name=shiptoemail size=45 value="$form->{shiptoemail}"></td>
	</tr>
        <tr>
          <td>&nbsp;</td>
        </tr>
        <tr>
           <td>&nbsp;</td>
       </tr>

    </table>
<br style="clear: left" /></div>|;


##LINET - added fields for contact person
  print qq|   
<div id="contacts" class="tabcontent">
<table>
    <tr>
         <td colspan=3>
	 	<input type=hidden name=cp_id value=$form->{cp_id}>
                <table>
                $ansprechpartner
                <tr>
	          <th align=left nowrap>| . $locale->text('Greeting') . qq|</th>
                  <td><input id=cp_greeting name=cp_greeting size=30 maxlength=30 value="$form->{cp_greeting}">&nbsp;
                  $select_greeting</td>
                </tr>
                <tr>
                  <th align=left nowrap>| . $locale->text('Title') . qq|</th>
                  <td><input id=cp_title name=cp_title size=30 maxlength=30 value="$form->{cp_title}">&nbsp;
                  $select_title</td>
                </tr>
                <tr>
                  <th align=left nowrap>| . $locale->text('Department') . qq|</th>
                  <td><input id=cp_abteilung name=cp_abteilung size=30 maxlength=40 value="$form->{cp_abteilung}">&nbsp;
                  $select_department</td>
                </tr>
                <tr>
                  <th align=left nowrap>|
    . $locale->text('Given Name') . qq|</th>
                  <td><input id=cp_givenname name=cp_givenname size=30 maxlength=40 value="$form->{cp_givenname}"></td>
                </tr>
                <tr>
	          <th align=left nowrap>| . $locale->text('Name') . qq|</th>
                  <td><input id=cp_name name=cp_name size=30 maxlength=40 value="$form->{cp_name}"></td>
                </tr>
                <tr>
	          <th align=left nowrap>| . $locale->text('Phone1') . qq|</th>
                  <td><input id=cp_phone1 name=cp_phone1 size=30 maxlength=30 value="$form->{cp_phone1}"></td>
                </tr>
                <tr>
                  <th align=left nowrap>| . $locale->text('Phone2') . qq|</th>
                  <td><input id=cp_phone2 name=cp_phone2 size=30 maxlength=30 value="$form->{cp_phone2}"></td>
                </tr>
                <tr>
                  <th align=left nowrap>| . $locale->text('Fax') . qq|</th>
                  <td><input id=cp_fax name=cp_fax size=30 maxlength=30 value="$form->{cp_fax}"></td>
                </tr>
                <tr>
                  <th align=left nowrap>| . $locale->text('Mobile1') . qq|</th>
                  <td><input id=cp_mobile1 name=cp_mobile1 size=30 maxlength=30 value="$form->{cp_mobile1}"></td>
                </tr>
                <tr>
                  <th align=left nowrap>| . $locale->text('Mobile2') . qq|</th>
                  <td><input id=cp_mobile2 name=cp_mobile2 size=30 maxlength=30 value="$form->{cp_mobile2}"></td>
                </tr>
                <tr>
                  <th align=left nowrap>| . $locale->text('Sat. Phone') . qq|</th>
                  <td><input id=cp_satphone name=cp_satphone size=30 maxlength=30 value="$form->{cp_satphone}"></td>
                </tr>
                <tr>
                  <th align=left nowrap>| . $locale->text('Sat. Fax') . qq|</th>
                  <td><input id=cp_satfax name=cp_satfax size=30 maxlength=30 value="$form->{cp_satfax}"></td>
                </tr>
                <tr>
	          <th align=left nowrap>| . $locale->text('Project') . qq|</th>
                  <td><input id=cp_project name=cp_project size=30 maxlength=40 value="$form->{cp_project}"></td>
                </tr>
                <tr>
	          <th align=left nowrap>| . $locale->text('E-mail') . qq|</th>
                  <td><input id=cp_email name=cp_email size=30 maxlength=40 value="$form->{cp_email}"></td>
                </tr>
                <tr>
	          <th align=left nowrap>| . $locale->text('Private Phone') . qq|</th>
                  <td><input id=cp_privatphone name=cp_privatphone size=30 maxlength=40 value="$form->{cp_privatphone}"></td>
                </tr>
                <tr>
	          <th align=left nowrap>| . $locale->text('Private E-mail') . qq|</th>
                  <td><input id=cp_privatemail name=cp_privatemail size=30 maxlength=40 value="$form->{cp_privatemail}"></td>
                </tr>
                <tr>
	          <th align=left nowrap>| . $locale->text('Birthday') . qq|</th>
                  <td><input id=cp_birthday name=cp_birthday size=30 maxlength=40 value="$form->{cp_birthday}"></td>
                </tr>
                
          </table>
        </td>
        </tr>
        <tr height="5"></tr>|;
##/LINET
  print qq|        $bcc
	$tax
      </table>
    </td>
  </tr>
  <tr>
    <td>
      
<br style="clear: left" /></div>
<div id="deliveries" class="tabcontent">
  <table>
    $delivery
    <tr>
      <th align=left nowrap>| . $locale->text('From') . qq|</th>
      <td><input id=from name=from size=10 maxlength=10 value="$form->{from}">
        <input type="button" name="fromB" id="trigger_from" value="?"></td>
      <th align=left nowrap>| . $locale->text('To (time)') . qq|</th>
      <td><input id=to name=to size=10 maxlength=10 value="$form->{to}">
        <input type="button" name="toB" id="trigger_to" value="?"></td>
    </tr>       
    <tr>
     <td colspan=4>
      <div id=delivery>
      </div>
      </td>
    </tr>
  </table>
<br style="clear: left" /></div>

</div>

| . $form->write_trigger(\%myconfig, 2, "fromB", "BL", "trigger_from",
                         "toB", "BL", "trigger_to");

  $lxdebug->leave_sub();
}

sub form_footer {
  $lxdebug->enter_sub();

  $label     = ucfirst $form->{db};
  $quotation =
    ($form->{db} eq 'customer')
    ? $locale->text('Save and Quotation')
    : $locale->text('Save and RFQ');
  $arap =
    ($form->{db} eq 'customer')
    ? $locale->text('Save and AR Transaction')
    : $locale->text('Save and AP Transaction');
  if ($vertreter) {
    $update_button =
      qq|<input class=submit type=submit name=action accesskey="u" value="|
      . $locale->text("Update") . qq|">|;
  } else {
    $update_button = "";
  }

##<input class=submit type=submit name=action value="|.$locale->text("Save and Quotation").qq|">
##<input class=submit type=submit name=action value="|.$locale->text("Save and RFQ").qq|">
##<input class=submit type=submit name=action value="|.$locale->text("Save and AR Transaction").qq|">
##<input class=submit type=submit name=action value="|.$locale->text("Save and AP Transaction").qq|">

  print qq|
<input name=id type=hidden id=cvid value=$form->{id}>
<input name=taxaccounts type=hidden value="$form->{taxaccounts}">
<input name=business_save type=hidden value="$form->{selectbusiness}">
<input name=title_save type=hidden value="$form->{title}">

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input type=hidden name=callback value="$form->{callback}">
<input type=hidden name=db id=db value=$form->{db}>



<br>
$update_button
<input class=submit type=submit name=action accesskey="s" value="|
    . $locale->text("Save") . qq|">
<input class=submit type=submit name=action accesskey="s" value="|
    . $locale->text("Save and Close") . qq|">
<input class=submit type=submit name=action value="$arap">
<input class=submit type=submit name=action value="|
    . $locale->text("Save and Invoice") . qq|">
<input class=submit type=submit name=action value="|
    . $locale->text("Save and Order") . qq|">
<input class=submit type=submit name=action value="$quotation">
|;

  if ($form->{id} && $form->{status} eq 'orphaned') {
    print qq|<input class=submit type=submit name=action value="|
      . $locale->text('Delete')
      . qq|">\n|;
  }

  print qq|

  </form>
<script type="text/javascript">
//Start Tab Content script for UL with id="maintab" Separate multiple ids each with a comma.
initializetabcontent("maintab")
</script>
</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub add_transaction {
  $lxdebug->enter_sub();

  $form->isblank("name", $locale->text("Name missing!"));
  if ($vertreter && $form->{db} eq "customer") {
    $form->isblank("salesman_id", $locale->text("Salesman missing!"));
  }
  &{"CT::save_$form->{db}"}("", \%myconfig, \%$form);

  $form->{callback} = $form->escape($form->{callback}, 1);
  $name = $form->escape("$form->{name}", 1);

  $form->{callback} =
    "$form->{script}?login=$form->{login}&path=$form->{path}&password=$form->{password}&action=add&vc=$form->{db}&$form->{db}_id=$form->{id}&$form->{db}=$name&type=$form->{type}&callback=$form->{callback}";

  $form->redirect;

  $lxdebug->leave_sub();
}

sub save_and_ap_transaction {
  $lxdebug->enter_sub();

  $form->{script} = "ap.pl";
  &add_transaction;

  $lxdebug->leave_sub();
}

sub save_and_ar_transaction {
  $lxdebug->enter_sub();

  $form->{script} = "ar.pl";
  &add_transaction;

  $lxdebug->leave_sub();
}

sub save_and_invoice {
  $lxdebug->enter_sub();

  $form->{script} = ($form->{db} eq 'customer') ? "is.pl" : "ir.pl";
  $form->{type} = "invoice";
  &add_transaction;

  $lxdebug->leave_sub();
}

sub save_and_rfq {
  $lxdebug->enter_sub();

  $form->{script} = "oe.pl";
  $form->{type}   = "request_quotation";
  &add_transaction;

  $lxdebug->leave_sub();
}

sub save_and_quotation {
  $lxdebug->enter_sub();

  $form->{script} = "oe.pl";
  $form->{type}   = "sales_quotation";
  &add_transaction;

  $lxdebug->leave_sub();
}

sub save_and_order {
  $lxdebug->enter_sub();

  $form->{script} = "oe.pl";
  $form->{type}   =
    ($form->{db} eq 'customer') ? "sales_order" : "purchase_order";
  &add_transaction;

  $lxdebug->leave_sub();
}

sub save_and_close {
  $lxdebug->enter_sub();

  # $locale->text('Customer saved!')
  # $locale->text('Vendor saved!')

  $msg = ucfirst $form->{db};
  $imsg .= " saved!";

  $form->isblank("name", $locale->text("Name missing!"));
  if ($vertreter && $form->{db} eq "customer") {
    $form->isblank("salesman_id", $locale->text("Salesman missing!"));
  }
  $rc = &{"CT::save_$form->{db}"}("", \%myconfig, \%$form);
  if ($rc == 3) {
    $form->error($locale->text('customernumber not unique!'));
  }
  $form->redirect($locale->text($msg));

  $lxdebug->leave_sub();
}

sub save {
  $lxdebug->enter_sub();

  # $locale->text('Customer saved!')
  # $locale->text('Vendor saved!')

  $msg = ucfirst $form->{db};
  $imsg .= " saved!";

  $form->isblank("name", $locale->text("Name missing!"));
  if ($vertreter && $form->{db} eq "customer") {
    $form->isblank("salesman_id", $locale->text("Salesman missing!"));
  }
  print(STDERR "SHIPTO in sub save $form->{shipto_id}\n");
  my $res = &{"CT::save_$form->{db}"}("", \%myconfig, \%$form);

  if (3 == $res) {
    if ($form->{"db"} eq "customer") {
      $form->error($locale->text('This customer number is already in use.'));
    } else {
      $form->error($locale->text('This vendor number is already in use.'));
    }
  }

  &edit;
  exit;
  $lxdebug->leave_sub();
}

sub delete {
  $lxdebug->enter_sub();

  # $locale->text('Customer deleted!')
  # $locale->text('Cannot delete customer!')
  # $locale->text('Vendor deleted!')
  # $locale->text('Cannot delete vendor!')

  CT->delete(\%myconfig, \%$form);

  $msg = ucfirst $form->{db};
  $msg .= " deleted!";
  $form->redirect($locale->text($msg));

  $msg = "Cannot delete $form->{db}";
  $form->error($locale->text($msg));

  $lxdebug->leave_sub();
}

sub display {
  $lxdebug->enter_sub();

  &form_header();
  &form_footer();

  $lxdebug->leave_sub();
}

sub update {
  $lxdebug->enter_sub();

  &check_salesman($form->{salesman});

  #  $form->get_salesman(\%myconfig, $form->{salesman});
  &display();
  $lxdebug->leave_sub();
}

sub check_salesman {
  $lxdebug->enter_sub();

  my ($name) = @_;

  my ($new_name, $new_id) = split /--/, $form->{$name};
  my $i = 0;

  # check name, combine name and id
  if ($form->{"oldsalesman"} ne $form->{"salesman"}) {

    # return one name or a list of names in $form->{name_list}
    if (($i = $form->get_salesman(\%myconfig, $name)) > 1) {
      &select_salesman($name);
      exit;
    }

    if ($i == 1) {

      # we got one name
      $form->{"salesman_id"} = $form->{salesman_list}[0]->{id};
      $form->{salesman}      = $form->{salesman_list}[0]->{name};
      $form->{"oldsalesman"} = $form->{salesman};

    } else {

      # name is not on file
      # $locale->text('Customer not on file!')
      # $locale->text('Vendor not on file!')
      $msg = ucfirst $name . " not on file or locked!";
      $form->error($locale->text($msg));
    }
  }

  $lxdebug->leave_sub();

  return $i;
}

sub select_salesman {
  $lxdebug->enter_sub();

  my ($table) = @_;

  @column_index = qw(ndx name);

  $label             = ucfirst $table;
  $column_data{ndx}  = qq|<th>&nbsp;</th>|;
  $column_data{name} =
    qq|<th class=listheading>| . $locale->text($label) . qq|</th>|;

  # list items with radio button on a form
  $form->header;

  $title = $locale->text('Select from one of the names below');

  print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <th class=listtop>$title</th>
  </tr>
  <tr space=5></tr>
  <tr>
    <td>
      <table width=100%>
	<tr class=listheading>|;

  map { print "\n$column_data{$_}" } @column_index;

  print qq|
	</tr>
|;

  my $i = 0;
  foreach $ref (@{ $form->{salesman_list} }) {
    $checked = ($i++) ? "" : "checked";

    $ref->{name} =~ s/\"/&quot;/g;

    $column_data{ndx} =
      qq|<td><input name=ndx class=radio type=radio value=$i $checked></td>|;
    $column_data{name} =
      qq|<td><input name="new_name_$i" type=hidden value="$ref->{name}">$ref->{name}</td>|;

    $j++;
    $j %= 2;
    print qq|
	<tr class=listrow$j>|;

    map { print "\n$column_data{$_}" } @column_index;

    print qq|
	</tr>

<input name="new_id_$i" type=hidden value=$ref->{id}>

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

<input name=lastndx type=hidden value=$i>

|;

  # delete variables
  map { delete $form->{$_} } qw(action name_list header);

  # save all other form variables
  foreach $key (keys %${form}) {
    $form->{$key} =~ s/\"/&quot;/g;
    print qq|<input name=$key type=hidden value="$form->{$key}">\n|;
  }

  print qq|
<input type=hidden name=nextsub value=salesman_selected>

<input type=hidden name=vc value=$table>
<br>
<input class=submit type=submit name=action value="|
    . $locale->text('Continue') . qq|">
</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub salesman_selected {
  $lxdebug->enter_sub();

  # replace the variable with the one checked

  # index for new item
  $i = $form->{ndx};

  $form->{salesman}      = $form->{"new_name_$i"};
  $form->{"salesman_id"} = $form->{"new_id_$i"};
  $form->{"oldsalesman"} = $form->{salesman};

  # delete all the new_ variables
  for $i (1 .. $form->{lastndx}) {
    map { delete $form->{"new_${_}_$i"} } (id, name);
  }

  map { delete $form->{$_} } qw(ndx lastndx nextsub);

  &update(1);

  $lxdebug->leave_sub();
}

sub get_contact {
  $lxdebug->enter_sub();

  CT->get_contact(\%myconfig, \%$form);

  my $q = new CGI;
  $result = "$form->{cp_name}";
  map { $result .= "__pjx__" . $form->{$_} } qw(cp_greeting cp_title cp_givenname cp_phone1 cp_phone2 cp_email cp_abteilung cp_fax cp_mobile1 cp_mobile2 cp_satphone cp_satfax cp_project cp_privatphone cp_privatemail cp_birthday);
  print $q->header();
  print $result;
  $lxdebug->leave_sub();

}


sub get_shipto {
  $lxdebug->enter_sub();

  CT->get_shipto(\%myconfig, \%$form);

  my $q = new CGI;
  $result = "$form->{shiptoname}";
  map { $result .= "__pjx__" . $form->{$_} } qw(shiptodepartment_1 shiptodepartment_2 shiptostreet shiptozipcode shiptocity shiptocountry shiptocontact shiptophone shiptofax shiptoemail);
  print $q->header();
  print $result;
  $lxdebug->leave_sub();

}

sub get_delivery {
  $lxdebug->enter_sub();

  CT->get_delivery(\%myconfig, \%$form );

  @column_index =
    $form->sort_columns(shiptoname,
                        invnumber,
                        ordnumber,
                        transdate,
                        description,
                        qty,
                        unit);



  $column_header{shiptoname} =
    qq|<th class=listheading>| . $locale->text('Shipping Address') . qq|</th>|;
  $column_header{invnumber} =
      qq|<th class=listheading>|. $locale->text('Invoice'). qq|</th>|;
  $column_header{ordnumber} =
      qq|<th class=listheading>|. $locale->text('Order'). qq|</th>|;
  $column_header{transdate} =
    qq|<th class=listheading>| . $locale->text('Invdate') . qq|</th>|;
  $column_header{description} =
    qq|<th class=listheading>| . $locale->text('Description') . qq|</th>|;
  $column_header{qty} =
    qq|<th class=listheading>| . $locale->text('Qty') . qq|</th>|;
  $column_header{unit} =
    qq|<th class=listheading>| . $locale->text('Unit') . qq|</th>|;
  $result .= qq|

<table width=100%>
  <tr>
    <td>
      <table width=100%>
	<tr class=listheading>
|;

  map { $result .= "$column_header{$_}\n" } @column_index;

  $result .= qq|
        </tr>
|;


  foreach $ref (@{ $form->{DELIVERY} }) {

    if ($ref->{shiptoname} eq $sameshiptoname) {
      map { $column_data{$_} = "<td>$ref->{$_}&nbsp;</td>" } @column_index;
      $column_data{shiptoname} = "<td>&nbsp;</td>";
    } else {
      map { $column_data{$_} = "<td>$ref->{$_}&nbsp;</td>" } @column_index;
    }

    $i++;
    $i %= 2;
    $result .= "
        <tr class=listrow$i>
";

    map { $result .= "$column_data{$_}\n" } @column_index;

    $result .= qq|
        </tr>
|;

    $sameshiptoname = $ref->{shiptoname};

  }

  $result .= qq|
      </table>
|;


  my $q = new CGI;
  print $q->header();
  print $result;
  $lxdebug->leave_sub();

}

sub continue { &{ $form->{nextsub} } }
