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

use CGI;
use CGI::Ajax;
use POSIX qw(strftime);

use SL::CT;
use SL::ReportGenerator;

require "bin/mozilla/common.pl";
require "bin/mozilla/reportgenerator.pl";

1;

# end of main

sub add {
  $lxdebug->enter_sub();

  $form->{title} = "Add";

  $form->{callback} =
    "$form->{script}?action=add&db=$form->{db}&login=$form->{login}&password=$form->{password}"
    unless $form->{callback};

  CT->populate_drop_down_boxes(\%myconfig, \%$form);

  &form_header;
  &form_footer;

  $lxdebug->leave_sub();
}

sub search {
  $lxdebug->enter_sub();

  $form->{IS_CUSTOMER} = $form->{db} eq 'customer';

  $form->get_lists("business_types" => "ALL_BUSINESS_TYPES");
  $form->{SHOW_BUSINESS_TYPES} = scalar @{ $form->{ALL_BUSINESS_TYPES} } > 0;

  $form->{title} = $form->{IS_CUSTOMER} ? $locale->text('Customers') : $locale->text('Vendors');
  $form->{fokus} = 'Form.name';

  $form->header();
  print $form->parse_html_template('ct/search');

  $lxdebug->leave_sub();
}

sub list_names {
  $lxdebug->enter_sub();

  $form->{IS_CUSTOMER} = $form->{db} eq 'customer';

  CT->search(\%myconfig, \%$form);

  my @options;
  if ($form->{status} eq 'all') {
    push @options, $locale->text('All');

  } elsif ($form->{status} eq 'orphaned') {
    push @options, $locale->text('Orphaned');
  }

  if ($form->{name}) {
    push @options, $locale->text('Name') . " : $form->{name}";
  }
  if ($form->{contact}) {
    push @options, $locale->text('Contact') . " : $form->{contact}";
  }
  if ($form->{"$form->{db}number"}) {
    push @options, $locale->text('Number') . qq| : $form->{"$form->{db}number"}|;
  }
  if ($form->{email}) {
    push @options, $locale->text('E-mail') . " : $form->{email}";
  }

  my @columns = (
    'id',        'name',  "$form->{db}number", 'address',  'contact',  'phone',
    'fax',       'email', 'taxnumber',         'sic_code', 'business', 'invnumber',
    'ordnumber', 'quonumber'
  );

  my %column_defs = (
    'id'                => { 'text' => $locale->text('ID'), },
    "$form->{db}number" => { 'text' => $form->{IS_CUSTOMER} ? $locale->text('Customer Number') : $locale->text('Vendor Number'), },
    'name'              => { 'text' => $locale->text('Name'), },
    'address'           => { 'text' => $locale->text('Address'), },
    'contact'           => { 'text' => $locale->text('Contact'), },
    'phone'             => { 'text' => $locale->text('Phone'), },
    'fax'               => { 'text' => $locale->text('Fax'), },
    'email'             => { 'text' => $locale->text('E-mail'), },
    'cc'                => { 'text' => $locale->text('Cc'), },
    'taxnumber'         => { 'text' => $locale->text('Tax Number'), },
    'sic_code'          => { 'text' => $locale->text('SIC'), },
    'business'          => { 'text' => $locale->text('Type of Business'), },
    'invnumber'         => { 'text' => $locale->text('Invoice'), },
    'ordnumber'         => { 'text' => $form->{IS_CUSTOMER} ? $locale->text('Sales Order') : $locale->text('Purchase Order'), },
    'quonumber'         => { 'text' => $form->{IS_CUSTOMER} ? $locale->text('Quotation')   : $locale->text('Request for Quotation'), },
  );

  map { $column_defs{$_}->{visible} = $form->{"l_$_"} eq 'Y' } @columns;

  my @hidden_variables  = (qw(db status obsolete), map { "l_$_" } @columns);
  my @hidden_nondefault = grep({ $form->{$_} } @hidden_variables);
  my $callback          = build_std_url('action=list_names', grep { $form->{$_} } @hidden_variables);
  $form->{callback}     = "$callback&sort=" . E($form->{sort});

  map { $column_defs{$_}->{link} = "${callback}&sort=${_}" } @columns;

  my ($ordertype, $quotationtype, $attachment_basename);
  if ($form->{IS_CUSTOMER}) {
    $form->{title}       = $locale->text('Customers');
    $ordertype           = 'sales_order';
    $quotationtype       = 'sales_quotation';
    $attachment_basename = $locale->text('customer_list');

  } else {
    $form->{title}       = $locale->text('Vendors');
    $ordertype           = 'purchase_order';
    $quotationtype       = 'request_quotation';
    $attachment_basename = $locale->text('vendor_list');
  }

  my $report = SL::ReportGenerator->new(\%myconfig, $form);

  $report->set_options('top_info_text'         => join("\n", @options),
                       'raw_bottom_info_text'  => $form->parse_html_template('ct/list_names_bottom'),
                       'output_format'         => 'HTML',
                       'title'                 => $form->{title},
                       'attachment_basename'   => $attachment_basename . strftime('_%Y%m%d', localtime time),
    );
  $report->set_options_from_form();

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);

  $report->set_export_options('list_names', @hidden_variables);

  $report->set_sort_indicator($form->{sort}, 1);

  my $previous_id;

  foreach my $ref (@{ $form->{CT} }) {
    my $row = { map { $_ => { 'data' => '' } } @columns };

    if ($ref->{id} ne $previous_id) {
      $previous_id = $ref->{id};
      map { $row->{$_}->{data} = $ref->{$_} } @columns;

      $row->{name}->{link}  = build_std_url('action=edit', 'id=' . E($ref->{id}), 'callback', @hidden_nondefault);
      $row->{email}->{link} = 'mailto:' . E($ref->{email});
    }

    my $base_url              = build_std_url("script=$ref->{module}.pl", 'action=edit', 'id=' . E($ref->{invid}), 'callback', @hidden_nondefault);
    $row->{invnumber}->{link} = $base_url;
    $row->{ordnumber}->{link} = $base_url . "&type=${ordertype}";
    $row->{quonumber}->{link} = $base_url . "&type=${quotationtype}";
    my $column                = $ref->{formtype} eq 'invoice' ? 'invnumber' : $ref->{formtype} eq 'order' ? 'ordnumber' : 'quonumber';
    $row->{$column}->{data}   = $ref->{$column};

    $report->add_data($row);
  }

  $report->generate_with_headers();

  $lxdebug->leave_sub();
}

sub edit {
  $lxdebug->enter_sub();

  # show history button
  $form->{javascript} = qq|<script type=text/javascript src=js/show_history.js></script>|;
  #/show hhistory button
  
  # $locale->text('Edit Customer')
  # $locale->text('Edit Vendor')

  CT->get_tuple(\%myconfig, \%$form);
  CT->populate_drop_down_boxes(\%myconfig, \%$form);

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

  $form->get_lists("employees" => "ALL_SALESMEN",
                   "taxzones" => "ALL_TAXZONES");

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

  %labels = ();
  @values = ();
  foreach my $item (@{ $form->{"ALL_TAXZONES"} }) {
    push(@values, $item->{"id"});
    $labels{$item->{"id"}} = $item->{"description"};
  }

  $taxzone = qq|
		<th align=right>| . $locale->text('Steuersatz') . qq|</th>
      <td>| .
        NTI($cgi->popup_menu('-name' => 'taxzone_id', '-default' => $form->{"taxzone_id"},
                             '-values' => \@values, '-labels' => \%labels)) . qq|
      </td>
|;

  $get_contact_url =
    "$form->{script}?login=$form->{login}&password=$form->{password}&action=get_contact";

  my $pjx = new CGI::Ajax( 'get_contact' => $get_contact_url );
  $form->{selectcontact} = "<option value=0>" . $locale->text('New contact') . "</option>";
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
    "$form->{script}?login=$form->{login}&password=$form->{password}&action=get_shipto";

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
    "$form->{script}?login=$form->{login}&password=$form->{password}&action=get_delivery";

  my $pjz = new CGI::Ajax( 'get_delivery' => $get_delivery_url );

  push(@ { $form->{AJAX} }, $pjz);

  $delivery = qq|
	      <tr>
		<th align=right>| . $locale->text('Shipping Address') . qq|</th>
		<td><select id=delivery_id name=delivery_id onChange="get_delivery(['shipto_id__' + this.value, 'from__' + from.value, 'to__' + to.value, 'id__' + cvid.value, 'db__' + db.value], ['delivery'])">$form->{selectshipto}</select></td>
	      </tr>|;

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
           <td><input name=v_customer_id size=10 value="$form->{v_customer_id}"></td>
|;
  }

  if ($form->{db} eq 'customer') {

    $customer = qq|
           <th align=right>| . $locale->text('KNr. beim Kunden') . qq|</th>
           <td><input name=c_vendor_id size=10 value="$form->{c_vendor_id}"></td>
|;
  }

  $business = qq|
 	  <th align=right>| . $locale->text('Type of Business') . qq|</th>
	  <td><select name=business>$form->{selectbusiness}</select></td>
      |;

  $salesman = "";

  if ($form->{db} eq "customer") {
    my (@salesman_values, %salesman_labels);
    push(@salesman_values, undef);
    foreach my $item (@{ $form->{ALL_SALESMEN} }) {
      push(@salesman_values, $item->{id});
      $salesman_labels{$item->{id}} = $item->{name} ne "" ? $item->{name} : $item->{login};
    }

    $salesman =
      qq| <th align="right">| . $locale->text('Salesman') . qq|</th>
          <td>| .
      NTI($cgi->popup_menu('-name' => 'salesman_id', '-default' => $form->{salesman_id},
                           '-values' => \@salesman_values, '-labels' => \%salesman_labels))
      . qq|</td>|;
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
        qq|<select name=klass>$form->{selectpricegroup}</select>|;

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
	<tr>
	  <th align=right nowrap>| . $locale->text($label . ' Number') . qq|</th>
	  <td><input name="$form->{db}number" size=35 value="$form->{"$form->{db}number"}"></td>
	</tr>
        <tr>
          <th align=right nowrap>| . $locale->text('Greeting') . qq|</th>
          <td><input id=greeting name=greeting size=30 value="$form->{greeting}">&nbsp;
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
          <td><input name="account_number" size="10" maxlength="15" value="$form->{account_number}"></td>
          <th align=right>| . $locale->text('Bank Code Number') . qq|</th>
          <td><input name="bank_code" size="10" maxlength="10" value="$form->{bank_code}"></td>
          <th align=right>| . $locale->text('Bank') . qq|</th>
          <td><input name=bank size=30 value="$form->{bank}"></td>
        </tr>
	<tr>
          $business
	  <th align=right>| . $locale->text('Language') . qq|</th>
	  <td><select name=language_id>$lang
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
        <tr>
          $taxzone
          $salesman
        </tr>
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
	  <td><input id=shiptozipcode name=shiptozipcode size=5 maxlength=75 value="$form->{shiptozipcode}">
          <input id=shiptocity name=shiptocity size=30 maxlength=75 value="$form->{shiptocity}"></td>
	</tr>
	<tr>
	  <th align=right nowrap>| . $locale->text('Country') . qq|</th>
	  <td><input id=shiptocountry name=shiptocountry size=35 maxlength=75 value="$form->{shiptocountry}"></td>
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
                  <td><input id=cp_greeting name=cp_greeting size=40 maxlength=75 value="$form->{cp_greeting}">&nbsp;
                  $select_greeting</td>
                </tr>
                <tr>
                  <th align=left nowrap>| . $locale->text('Title') . qq|</th>
                  <td><input id=cp_title name=cp_title size=40 maxlength=75 value="$form->{cp_title}">&nbsp;
                  $select_title</td>
                </tr>
                <tr>
                  <th align=left nowrap>| . $locale->text('Department') . qq|</th>
                  <td><input id=cp_abteilung name=cp_abteilung size=40 value="$form->{cp_abteilung}">&nbsp;
                  $select_department</td>
                </tr>
                <tr>
                  <th align=left nowrap>|
    . $locale->text('Given Name') . qq|</th>
                  <td><input id="cp_givenname" name="cp_givenname" size="40" maxlength="75" value="$form->{cp_givenname}"></td>
                </tr>
                <tr>
	          <th align=left nowrap>| . $locale->text('Name') . qq|</th>
                  <td><input id="cp_name" name="cp_name" size="40" maxlength="75" value="$form->{cp_name}"></td>
                </tr>
                <tr>
	          <th align=left nowrap>| . $locale->text('Phone1') . qq|</th>
                  <td><input id="cp_phone1" name="cp_phone1" size="40" maxlength="75" value="$form->{cp_phone1}"></td>
                </tr>
                <tr>
                  <th align=left nowrap>| . $locale->text('Phone2') . qq|</th>
                  <td><input id="cp_phone2" name="cp_phone2" size="40" maxlength="75" value="$form->{cp_phone2}"></td>
                </tr>
                <tr>
                  <th align=left nowrap>| . $locale->text('Fax') . qq|</th>
                  <td><input id=cp_fax name=cp_fax size=40 value="$form->{cp_fax}"></td>
                </tr>
                <tr>
                  <th align=left nowrap>| . $locale->text('Mobile1') . qq|</th>
                  <td><input id=cp_mobile1 name=cp_mobile1 size=40 value="$form->{cp_mobile1}"></td>
                </tr>
                <tr>
                  <th align=left nowrap>| . $locale->text('Mobile2') . qq|</th>
                  <td><input id=cp_mobile2 name=cp_mobile2 size=40 value="$form->{cp_mobile2}"></td>
                </tr>
                <tr>
                  <th align=left nowrap>| . $locale->text('Sat. Phone') . qq|</th>
                  <td><input id=cp_satphone name=cp_satphone size=40 value="$form->{cp_satphone}"></td>
                </tr>
                <tr>
                  <th align=left nowrap>| . $locale->text('Sat. Fax') . qq|</th>
                  <td><input id=cp_satfax name=cp_satfax size=40 value="$form->{cp_satfax}"></td>
                </tr>
                <tr>
	          <th align=left nowrap>| . $locale->text('Project') . qq|</th>
                  <td><input id=cp_project name=cp_project size=40 value="$form->{cp_project}"></td>
                </tr>
                <tr>
	          <th align=left nowrap>| . $locale->text('E-mail') . qq|</th>
                  <td><input id=cp_email name=cp_email size=40 value="$form->{cp_email}"></td>
                </tr>
                <tr>
	          <th align=left nowrap>| . $locale->text('Private Phone') . qq|</th>
                  <td><input id=cp_privatphone name=cp_privatphone size=40 value="$form->{cp_privatphone}"></td>
                </tr>
                <tr>
	          <th align=left nowrap>| . $locale->text('Private E-mail') . qq|</th>
                  <td><input id=cp_privatemail name=cp_privatemail size=40 value="$form->{cp_privatemail}"></td>
                </tr>
                <tr>
	          <th align=left nowrap>| . $locale->text('Birthday') . qq|</th>
                  <td><input id=cp_birthday name=cp_birthday size=40 value="$form->{cp_birthday}"></td>
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

##<input class=submit type=submit name=action value="|.$locale->text("Save and Quotation").qq|">
##<input class=submit type=submit name=action value="|.$locale->text("Save and RFQ").qq|">
##<input class=submit type=submit name=action value="|.$locale->text("Save and AR Transaction").qq|">
##<input class=submit type=submit name=action value="|.$locale->text("Save and AP Transaction").qq|">

  print qq|
<input name=id type=hidden id=cvid value=$form->{id}>
<input name=business_save type=hidden value="$form->{selectbusiness}">
<input name=title_save type=hidden value="$form->{title}">

<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input type=hidden name=callback value="$form->{callback}">
<input type=hidden name=db id=db value=$form->{db}>



<br>
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

  # button for saving history
  if($form->{id} ne "") {
    print qq|
  	  <input type=button class=submit onclick=set_history_window(|
  	  . $form->{id} 
  	  . qq|); name=history id=history value=|
  	  . $locale->text('history') 
  	  . qq|>|;
  }
  # /button for saving history

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

#  # saving the history
#  if(!exists $form->{addition}) {
#  	$form->{addition} = "ADD TRANSACTION";
#  	$form->save_history($form->dbconnect(\%myconfig));
#  }
#  # /saving the history
  
  $form->isblank("name", $locale->text("Name missing!"));
  if ($form->{"db"} eq "customer") {
    CT->save_customer(\%myconfig, \%$form);
  } else {
    CT->save_vendor(\%myconfig, \%$form);
  }

  $form->{callback} = $form->escape($form->{callback}, 1);
  $name = $form->escape("$form->{name}", 1);

  $form->{callback} =
    "$form->{script}?login=$form->{login}&password=$form->{password}&action=add&vc=$form->{db}&$form->{db}_id=$form->{id}&$form->{db}=$name&type=$form->{type}&callback=$form->{callback}";
  $form->redirect;

  $lxdebug->leave_sub();
}

sub save_and_ap_transaction {
  $lxdebug->enter_sub();

  $form->{script} = "ap.pl";
  # saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers} = qq|invnumber_| . $form->{invnumber};
  	$form->{addition} = "SAVED";
  	$form->save_history($form->dbconnect(\%myconfig));
  }
  # /saving the history
  &add_transaction;
  $lxdebug->leave_sub();
}

sub save_and_ar_transaction {
  $lxdebug->enter_sub();

  $form->{script} = "ar.pl";
  # saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers} = qq|invnumber_| . $form->{invnumber};
  	$form->{addition} = "SAVED";
  	$form->save_history($form->dbconnect(\%myconfig));
  }
  # /saving the history
  &add_transaction;
  $lxdebug->leave_sub();
}

sub save_and_invoice {
  $lxdebug->enter_sub();

  $form->{script} = ($form->{db} eq 'customer') ? "is.pl" : "ir.pl";
  $form->{type} = "invoice";
  # saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers} = qq|invnumber_| . $form->{invnumber};
  	$form->{addition} = "SAVED";
  	$form->save_history($form->dbconnect(\%myconfig));
  }
  # /saving the history
  &add_transaction;
  $lxdebug->leave_sub();
}

sub save_and_rfq {
  $lxdebug->enter_sub();

  $form->{script} = "oe.pl";
  $form->{type}   = "request_quotation";
  # saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers} = qq|ordnumber_| . $form->{ordnumber};
  	$form->{addition} = "SAVED";
  	$form->save_history($form->dbconnect(\%myconfig));
  }
  # /saving the history
  &add_transaction;
  $lxdebug->leave_sub();
}

sub save_and_quotation {
  $lxdebug->enter_sub();

  $form->{script} = "oe.pl";
  $form->{type}   = "sales_quotation";
  # saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers} = qq|ordnumber_| . $form->{ordnumber};
  	$form->{addition} = "SAVED";
  	$form->save_history($form->dbconnect(\%myconfig));
  }
  # /saving the history
  &add_transaction;
  $lxdebug->leave_sub();
}

sub save_and_order {
  $lxdebug->enter_sub();

  $form->{script} = "oe.pl";
  $form->{type}   =
    ($form->{db} eq 'customer') ? "sales_order" : "purchase_order";
  # saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers} = qq|ordnumber_| . $form->{ordnumber};
  	$form->{addition} = "SAVED";
  	$form->save_history($form->dbconnect(\%myconfig));
  }
  # /saving the history
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
  if ($form->{"db"} eq "customer") {
    $rc = CT->save_customer(\%myconfig, \%$form);
  } else {
    $rc = CT->save_vendor(\%myconfig, \%$form);
  }
  if ($rc == 3) {
    $form->error($locale->text('customernumber not unique!'));
  }
  # saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers} = ($form->{"db"} eq "customer" ? qq|customernumber_| . $form->{customernumber} : qq|vendornumber_| . $form->{vendornumber});
    $form->{addition} = "SAVED";
  	$form->save_history($form->dbconnect(\%myconfig));
  }
  # /saving the history
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

  my $res;
  if ($form->{"db"} eq "customer") {
    $res = CT->save_customer(\%myconfig, \%$form);
  } else {
    $res = CT->save_vendor(\%myconfig, \%$form);
  }

  if (3 == $res) {
    if ($form->{"db"} eq "customer") {
      $form->error($locale->text('This customer number is already in use.'));
    } else {
      $form->error($locale->text('This vendor number is already in use.'));
    }
  }
  # saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers} = ($form->{"db"} eq "customer" ? qq|customernumber_| . $form->{customernumber} : qq|vendornumber_| . $form->{vendornumber});
  	$form->{addition} = "SAVED";
  	$form->save_history($form->dbconnect(\%myconfig));
  }
  # /saving the history
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
  # saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers} = ($form->{"db"} eq "customer" ? qq|customernumber_| . $form->{customernumber} : qq|vendornumber_| . $form->{vendornumber});
  	$form->{addition} = "DELETED";
  	$form->save_history($form->dbconnect(\%myconfig));
  }
  # /saving the history 
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

  &display();
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
                        unit,
                        sellprice);



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
  $column_header{sellprice} =
    qq|<th class=listheading>| . $locale->text('Sell Price') . qq|</th>|;
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
    $column_data{sellprice} = "<td>". $form->format_amount(\%myconfig,$ref->{sellprice},2)."&nbsp;</td>";
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

sub continue { call_sub($form->{nextsub}); }
