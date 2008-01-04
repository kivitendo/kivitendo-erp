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
                   "taxzones"  => "ALL_TAXZONES");
  $form->get_pricegroup(\%myconfig, { all => 1 });

  $form->{taxincluded}    = ($form->{taxincluded}) ? "checked" : "";
  $form->{is_admin}       = $myconfig{role} eq 'admin';
  $form->{is_customer}    = $form->{db}     eq 'customer';
  $form->{salesman_label} = sub { $_[0]->{name} ne "" ? $_[0]->{name} : $_[0]->{login} };
  $form->{shipto_label}   = sub { "$_[0]->{shiptoname} $_[0]->{shiptodepartment_1}" };
  $form->{taxzone_id}     = 0                                                               if !$form->{id};
  $form->{jsscript}       = 1;
  $form->{fokus}          = "ct.greeting";

  unshift @{ $form->{SHIPTO} },   +{ shipto_id => '0', shiptoname => '' }, +{ shipto_id => '0', shiptoname => 'Alle' };
  unshift @{ $form->{CONTACTS} }, +{ cp_id     => '0', cp_name => $locale->text('New contact') };

  push @{ $form->{AJAX} }, map { 
    new CGI::Ajax( "get_$_" => "$form->{script}?login=$form->{login}&password=$form->{password}&action=get_$_" ) 
  } qw(shipto contact delivery);

  $form->{title} = $form->{title_save} 
                || $locale->text("$form->{title} " . ucfirst $form->{db}) . ($form->{title} eq "Edit" ? " $form->{name}" : '');

## LINET: Create a drop-down box with all prior titles and greetings.
  CT->query_titles_and_greetings(\%myconfig, \%$form);
  map { $form->{"MB_$_"} = [ map +{ id => $_, description => $_ }, @{ $form->{$_} } ] } qw(TITLES GREETINGS COMPANY_GREETINGS DEPARTMENT);
## /LINET

  $form->header;
  print $form->parse_html_template('ct/form_header');

  $lxdebug->leave_sub();
}

sub form_footer {
  $lxdebug->enter_sub();

  print $form->parse_html_template('ct/form_footer', { is_orphaned => $form->{status} eq 'orphaned',
                                                       is_customer => $form->{db}     eq 'customer' });
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
