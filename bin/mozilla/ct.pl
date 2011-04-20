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
# $locale->text('Edit Customer')
# $locale->text('Edit Vendor')
# $locale->text('Customer saved!')
# $locale->text('Vendor saved!')
# $locale->text('Customer deleted!')
# $locale->text('Cannot delete customer!')
# $locale->text('Vendor deleted!')
# $locale->text('Cannot delete vendor!')

use CGI::Ajax;
use POSIX qw(strftime);

use SL::CT;
use SL::CVar;
use SL::DB::Business;
use SL::ReportGenerator;

require "bin/mozilla/common.pl";
require "bin/mozilla/reportgenerator.pl";

use strict;
1;

# end of main

sub add {
  $main::lxdebug->enter_sub();

  $main::auth->assert('customer_vendor_edit');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $form->{title}    = "Add";
  $form->{callback} = "$form->{script}?action=add&db=$form->{db}" unless $form->{callback};

  CT->populate_drop_down_boxes(\%myconfig, \%$form);

  &form_header;
  &form_footer;

  $main::lxdebug->leave_sub();
}

sub search {
  $main::lxdebug->enter_sub();

  $main::auth->assert('customer_vendor_edit');

  my $form     = $main::form;
  my $locale   = $main::locale;

  $form->{IS_CUSTOMER} = $form->{db} eq 'customer';

  $form->get_lists("business_types" => "ALL_BUSINESS_TYPES");
  $form->{SHOW_BUSINESS_TYPES} = scalar @{ $form->{ALL_BUSINESS_TYPES} } > 0;

  $form->{CUSTOM_VARIABLES}                  = CVar->get_configs('module' => 'CT');
  ($form->{CUSTOM_VARIABLES_FILTER_CODE},
   $form->{CUSTOM_VARIABLES_INCLUSION_CODE}) = CVar->render_search_options('variables'      => $form->{CUSTOM_VARIABLES},
                                                                           'include_prefix' => 'l_',
                                                                           'include_value'  => 'Y');

  $form->{jsscript} = 1;
  $form->{title}    = $form->{IS_CUSTOMER} ? $locale->text('Customers') : $locale->text('Vendors');
  $form->{fokus}    = 'Form.name';

  $form->header();
  print $form->parse_html_template('ct/search');

  $main::lxdebug->leave_sub();
}

sub list_names {
  $main::lxdebug->enter_sub();

  $main::auth->assert('customer_vendor_edit');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $form->{IS_CUSTOMER} = $form->{db} eq 'customer';

  report_generator_set_default_sort('name', 1);

  CT->search(\%myconfig, \%$form);

  my $cvar_configs = CVar->get_configs('module' => 'CT');

  my @options;
  if ($form->{status} eq 'all') {
    push @options, $locale->text('All');
  } elsif ($form->{status} eq 'orphaned') {
    push @options, $locale->text('Orphaned');
  }

  push @options, $locale->text('Name') . " : $form->{name}"                                    if $form->{name};
  push @options, $locale->text('Contact') . " : $form->{contact}"                              if $form->{contact};
  push @options, $locale->text('Number') . qq| : $form->{"$form->{db}number"}|                 if $form->{"$form->{db}number"};
  push @options, $locale->text('E-mail') . " : $form->{email}"                                 if $form->{email};
  push @options, $locale->text('Contact person (surname)')           . " : $form->{cp_name}"   if $form->{cp_name};
  push @options, $locale->text('Billing/shipping address (city)')    . " : $form->{addr_city}" if $form->{addr_city};
  push @options, $locale->text('Billing/shipping address (zipcode)') . " : $form->{zipcode}"   if $form->{addr_zipcode};
  push @options, $locale->text('Billing/shipping address (street)')  . " : $form->{street}"    if $form->{addr_street};

  if ($form->{business_id}) {
    my $business = SL::DB::Manager::Business->find_by(id => $form->{business_id});
    if ($business) {
      my $label = $form->{IS_CUSTOMER} ? $::locale->text('Customer type') : $::locale->text('Vendor type');
      push @options, $label . " : " . $business->description;
    }
  }

  my @columns = (
    'id',        'name',      "$form->{db}number",   'contact',  'phone',
    'fax',       'email',     'taxnumber',           'street',   'zipcode' , 'city',
    'business',  'invnumber', 'ordnumber',           'quonumber'
  );

  my @includeable_custom_variables = grep { $_->{includeable} } @{ $cvar_configs };
  my @searchable_custom_variables  = grep { $_->{searchable} }  @{ $cvar_configs };
  my %column_defs_cvars            = map { +"cvar_$_->{name}" => { 'text' => $_->{description} } } @includeable_custom_variables;

  push @columns, map { "cvar_$_->{name}" } @includeable_custom_variables;

  my %column_defs = (
    'id'                => { 'text' => $locale->text('ID'), },
    "$form->{db}number" => { 'text' => $locale->text('Number'), },
    'name'              => { 'text' => $form->{IS_CUSTOMER} ? $::locale->text('Customer Name') : $::locale->text('Vendor Name'), },
    'contact'           => { 'text' => $locale->text('Contact'), },
    'phone'             => { 'text' => $locale->text('Phone'), },
    'fax'               => { 'text' => $locale->text('Fax'), },
    'email'             => { 'text' => $locale->text('E-mail'), },
    'cc'                => { 'text' => $locale->text('Cc'), },
    'taxnumber'         => { 'text' => $locale->text('Tax Number'), },
    'business'          => { 'text' => $locale->text('Type of Business'), },
    'invnumber'         => { 'text' => $locale->text('Invoice'), },
    'ordnumber'         => { 'text' => $form->{IS_CUSTOMER} ? $locale->text('Sales Order') : $locale->text('Purchase Order'), },
    'quonumber'         => { 'text' => $form->{IS_CUSTOMER} ? $locale->text('Quotation')   : $locale->text('Request for Quotation'), },
    'street'            => { 'text' => $locale->text('Street'), },
    'zipcode'           => { 'text' => $locale->text('Zipcode'), },
    'city'              => { 'text' => $locale->text('City'), },
    %column_defs_cvars,
  );

  map { $column_defs{$_}->{visible} = $form->{"l_$_"} eq 'Y' } @columns;

  my @hidden_variables  = ( qw(
      db status obsolete name contact email cp_name addr_street addr_zipcode
      addr_city business_id
    ), "$form->{db}number",
    map({ "cvar_$_->{name}" } @searchable_custom_variables),
    map({ "l_$_" } @columns),
  );

  my @hidden_nondefault = grep({ $form->{$_} } @hidden_variables);
  my $callback          = build_std_url('action=list_names', grep { $form->{$_} } @hidden_nondefault);
  $form->{callback}     = "$callback&sort=" . E($form->{sort}) . "&sortdir=" . E($form->{sortdir});

  foreach (@columns) {
    my $sortdir              = $form->{sort} eq $_ ? 1 - $form->{sortdir} : $form->{sortdir};
    $column_defs{$_}->{link} = "${callback}&sort=${_}&sortdir=${sortdir}";
  }

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
  $locale->set_numberformat_wo_thousands_separator(\%myconfig) if lc($report->{options}->{output_format}) eq 'csv';

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);

  $report->set_export_options('list_names', @hidden_variables, qw(sort sortdir));

  $report->set_sort_indicator($form->{sort}, $form->{sortdir});

  CVar->add_custom_variables_to_report('module'         => 'CT',
                                       'trans_id_field' => 'id',
                                       'configs'        => $cvar_configs,
                                       'column_defs'    => \%column_defs,
                                       'data'           => $form->{CT});

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

  $main::lxdebug->leave_sub();
}

sub edit {
  $main::lxdebug->enter_sub();

  $main::auth->assert('customer_vendor_edit');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  # show history button
  $form->{javascript} = qq|<script type=text/javascript src=js/show_history.js></script>|;
  #/show hhistory button

  CT->get_tuple(\%myconfig, \%$form);
  CT->populate_drop_down_boxes(\%myconfig, \%$form);

  $form->{title} = "Edit";

  # format discount
  $form->{discount} *= 100;

  &form_header;
  &form_footer;

  $main::lxdebug->leave_sub();
}

sub form_header {
  $main::lxdebug->enter_sub();

  $main::auth->assert('customer_vendor_edit');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $form->get_lists(employees => "ALL_EMPLOYEES",
                   taxzones  => "ALL_TAXZONES");
  $form->get_pricegroup(\%myconfig, { all => 1 });

  $form->get_lists(customers => { key => "ALL_SALESMAN_CUSTOMERS", business_is_salesman => 1 }) if $::lx_office_conf{features}->{vertreter};

  $form->{ALL_SALESMEN}   = $form->{ALL_EMPLOYEES};
  $form->{taxincluded}    = ($form->{taxincluded}) ? "checked" : "";
  $form->{is_admin}       = $myconfig{role} eq 'admin';
  $form->{is_customer}    = $form->{db}     eq 'customer';
  $form->{salesman_label} = sub { $_[0]->{name} ne "" ? $_[0]->{name} : $_[0]->{login} };
  $form->{shipto_label}   = sub { my $s = shift(@_); join('; ', grep { $_ } map { $s->{"shipto$_"} } qw(name department_1 street city)) || ' ' };
  $form->{contacts_label} = sub { join ", ", grep { $_ } $_[0]->{cp_name}, $_[0]->{cp_givenname} };
  $form->{taxzone_id}     = 0                                                               if !$form->{id};
  $form->{jsscript}       = 1;
  $form->{fokus}          = "ct.greeting";
  $form->{AJAX}           = [ new CGI::Ajax( map {; "get_$_" => "$form->{script}?action=get_$_" } qw(shipto contact delivery) ) ];

  unshift @{ $form->{SHIPTO} },   +{ shipto_id => '0', shiptoname => '' }, +{ shipto_id => '0', shiptoname => 'Alle' };
  unshift @{ $form->{CONTACTS} }, +{ cp_id     => '0', cp_name => $locale->text('New contact') };

  $form->{title} = $form->{title_save}
                || $locale->text("$form->{title} " . ucfirst $form->{db}) . ($form->{title} eq "Edit" ? " $form->{name}" : '');

  CT->query_titles_and_greetings(\%myconfig, \%$form);
  map { $form->{"MB_$_"} = [ map +{ id => $_, description => $_ }, @{ $form->{$_} } ] } qw(TITLES GREETINGS COMPANY_GREETINGS DEPARTMENT);

  $form->{NOTES} ||= [ ];

  $form->{CUSTOM_VARIABLES} = CVar->get_custom_variables('module' => 'CT', 'trans_id' => $form->{id});

  CVar->render_inputs('variables' => $form->{CUSTOM_VARIABLES}) if (scalar @{ $form->{CUSTOM_VARIABLES} });

  $form->header;
  print $form->parse_html_template('ct/form_header');

  $main::lxdebug->leave_sub();
}

sub form_footer {
  $main::lxdebug->enter_sub();

  $main::auth->assert('customer_vendor_edit');

  my $form     = $main::form;

  print $form->parse_html_template('ct/form_footer', { is_orphaned => $form->{status} eq 'orphaned',
                                                       is_customer => $form->{db}     eq 'customer' });
  $main::lxdebug->leave_sub();
}

sub _do_save {
  $main::auth->assert('customer_vendor_edit & ' .
                      '(general_ledger         | invoice_edit         | vendor_invoice_edit | ' .
                      ' request_quotation_edit | sales_quotation_edit | sales_order_edit    | purchase_order_edit)');

  $::form->isblank("name", $::locale->text("Name missing!"));

  if ($::form->{new_salesman_id} && $::lx_office_conf{features}->{vertreter}) {
    $::form->{salesman_id} = $::form->{new_salesman_id};
    delete $::form->{new_salesman_id};
  }

  my $res = $::form->{db} eq 'customer' ? CT->save_customer(\%::myconfig, $::form) : CT->save_vendor(\%::myconfig, $::form);

  if (3 == $res) {
    if ($::form->{"db"} eq "customer") {
      $::form->error($::locale->text('This customer number is already in use.'));
    } else {
      $::form->error($::locale->text('This vendor number is already in use.'));
    }
  }
}

sub add_transaction {
  $main::lxdebug->enter_sub();

  $main::auth->assert('customer_vendor_edit & ' .
                '(general_ledger         | invoice_edit         | vendor_invoice_edit | ' .
                ' request_quotation_edit | sales_quotation_edit | sales_order_edit    | purchase_order_edit)');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

#  # saving the history
#  if(!exists $form->{addition}) {
#    $form->{addition} = "ADD TRANSACTION";
#    $form->save_history;
#  }
#  # /saving the history

  _do_save();

  $form->{callback} = $form->escape($form->{callback}, 1);
  my $name = $form->escape("$form->{name}", 1);

  $form->{callback} =
    "$form->{script}?action=add&vc=$form->{db}&$form->{db}_id=$form->{id}&$form->{db}=$name&type=$form->{type}&callback=$form->{callback}";
  $form->redirect;

  $main::lxdebug->leave_sub();
}

sub save_and_ap_transaction {
  $main::lxdebug->enter_sub();

  $main::auth->assert('customer_vendor_edit & general_ledger');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $form->{script} = "ap.pl";
  # saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers} = qq|invnumber_| . $form->{invnumber};
    $form->{addition} = "SAVED";
    $form->save_history;
  }
  # /saving the history
  &add_transaction;
  $main::lxdebug->leave_sub();
}

sub save_and_ar_transaction {
  $main::lxdebug->enter_sub();

  $main::auth->assert('customer_vendor_edit & general_ledger');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $form->{script} = "ar.pl";
  # saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers} = qq|invnumber_| . $form->{invnumber};
    $form->{addition} = "SAVED";
    $form->save_history;
  }
  # /saving the history
  &add_transaction;
  $main::lxdebug->leave_sub();
}

sub save_and_invoice {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  if ($form->{db} eq 'customer') {
    $main::auth->assert('customer_vendor_edit & invoice_edit');
  } else {
    $main::auth->assert('customer_vendor_edit & vendor_invoice_edit');
  }

  $form->{script} = ($form->{db} eq 'customer') ? "is.pl" : "ir.pl";
  $form->{type} = "invoice";
  # saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers} = qq|invnumber_| . $form->{invnumber};
    $form->{addition} = "SAVED";
    $form->save_history;
  }
  # /saving the history
  &add_transaction;
  $main::lxdebug->leave_sub();
}

sub save_and_rfq {
  $main::lxdebug->enter_sub();

  $main::auth->assert('customer_vendor_edit & request_quotation_edit');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $form->{script} = "oe.pl";
  $form->{type}   = "request_quotation";
  # saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers} = qq|ordnumber_| . $form->{ordnumber};
    $form->{addition} = "SAVED";
    $form->save_history;
  }
  # /saving the history
  &add_transaction;
  $main::lxdebug->leave_sub();
}

sub save_and_quotation {
  $main::lxdebug->enter_sub();

  $main::auth->assert('customer_vendor_edit & sales_quotation_edit');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $form->{script} = "oe.pl";
  $form->{type}   = "sales_quotation";
  # saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers} = qq|ordnumber_| . $form->{ordnumber};
    $form->{addition} = "SAVED";
    $form->save_history;
  }
  # /saving the history
  &add_transaction;
  $main::lxdebug->leave_sub();
}

sub save_and_order {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  if ($form->{db} eq 'customer') {
    $main::auth->assert('customer_vendor_edit & sales_order_edit');
  } else {
    $main::auth->assert('customer_vendor_edit & purchase_order_edit');
  }

  $form->{script} = "oe.pl";
  $form->{type}   =
    ($form->{db} eq 'customer') ? "sales_order" : "purchase_order";
  # saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers} = qq|ordnumber_| . $form->{ordnumber};
    $form->{addition} = "SAVED";
    $form->save_history;
  }
  # /saving the history
  &add_transaction;
  $main::lxdebug->leave_sub();
}

sub save_and_close {
  $main::lxdebug->enter_sub();

  $main::auth->assert('customer_vendor_edit');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  my $msg = ucfirst $form->{db};
  $msg .= " saved!";

  _do_save();

  # saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers} = ($form->{"db"} eq "customer" ? qq|customernumber_| . $form->{customernumber} : qq|vendornumber_| . $form->{vendornumber});
    $form->{addition} = "SAVED";
    $form->save_history;
  }
  # /saving the history
  $form->redirect($locale->text($msg));

  $main::lxdebug->leave_sub();
}

sub save {
  $main::lxdebug->enter_sub();

  $main::auth->assert('customer_vendor_edit');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  my $msg = ucfirst $form->{db};
  $msg .= " saved!";

  _do_save();

  # saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers} = ($form->{"db"} eq "customer" ? qq|customernumber_| . $form->{customernumber} : qq|vendornumber_| . $form->{vendornumber});
    $form->{addition} = "SAVED";
    $form->save_history;
  }
  # /saving the history
  &edit;

  $main::lxdebug->leave_sub();
  ::end_of_request();
}

sub delete {
  $main::lxdebug->enter_sub();

  $main::auth->assert('customer_vendor_edit');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  CT->delete(\%myconfig, \%$form);

  my $msg = ucfirst $form->{db};
  $msg .= " deleted!";
  # saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers} = ($form->{"db"} eq "customer" ? qq|customernumber_| . $form->{customernumber} : qq|vendornumber_| . $form->{vendornumber});
    $form->{addition} = "DELETED";
    $form->save_history;
  }
  # /saving the history
  $form->redirect($locale->text($msg));

  $main::lxdebug->leave_sub();
}

sub display {
  $main::lxdebug->enter_sub();

  $main::auth->assert('customer_vendor_edit');

  my $form     = $main::form;

  &form_header();
  &form_footer();

  $main::lxdebug->leave_sub();
}

sub update {
  $main::lxdebug->enter_sub();

  $main::auth->assert('customer_vendor_edit');

  my $form     = $main::form;

  &display();
  $main::lxdebug->leave_sub();
}

sub get_contact {
  $main::lxdebug->enter_sub();

  $main::auth->assert('customer_vendor_edit');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  CT->get_contact(\%myconfig, \%$form);
  print $form->ajax_response_header(), join '__pjx__', map $form->{"cp_$_"},
    qw(name title givenname phone1 phone2 email abteilung fax mobile1 mobile2 satphone satfax project privatphone privatemail birthday used gender);
  $main::lxdebug->leave_sub();

}

sub get_shipto {
  $main::lxdebug->enter_sub();

  $main::auth->assert('customer_vendor_edit');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  CT->get_shipto(\%myconfig, \%$form);
  print $form->ajax_response_header(), join('__pjx__', map($form->{"shipto$_"}, qw(name department_1 department_2 street zipcode city country contact phone fax email used)));
  $main::lxdebug->leave_sub();

}

sub get_delivery {
  $::lxdebug->enter_sub;

  $::auth->assert('customer_vendor_edit');
  $::auth->assert('sales_all_edit');

  CT->get_delivery(\%::myconfig, $::form );

  print $::form->ajax_response_header,
        $::form->parse_html_template('ct/get_delivery', {
          is_customer =>  $::form->{db} eq 'customer',
        });

  $::lxdebug->leave_sub;
}

sub delete_shipto {
  $main::lxdebug->enter_sub();

  $main::auth->assert('customer_vendor_edit');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  CT->get_shipto(\%myconfig, \%$form);

  unless ($form->{shiptoused}) {
    CT->delete_shipto($form->{shipto_id});
    @$form{ grep /^shipto/, keys %$form } = undef;
  }

  edit();

  $main::lxdebug->leave_sub();
}

sub delete_contact {
  $main::lxdebug->enter_sub();

  $main::auth->assert('customer_vendor_edit');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  CT->get_contact(\%myconfig, \%$form);

  unless ($form->{cp_used}) {
    CT->delete_shipto($form->{cp_id});
    @$form{ grep /^cp_/, keys %$form } = undef;
  }

  edit();

  $main::lxdebug->leave_sub();
}

sub ajax_autocomplete {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $form->{column}          = 'name'     unless $form->{column} =~ /^name$/;
  $form->{vc}              = 'customer' unless $form->{vc} =~ /^customer|vendor$/;
  $form->{db}              = $form->{vc}; # CT expects this
  $form->{$form->{column}} = $form->{q}           || '';
  $form->{limit}           = ($form->{limit} * 1) || 10;
  $form->{searchitems}   ||= '';

  CT->search(\%myconfig, $form);

  print $form->ajax_response_header(),
        $form->parse_html_template('ct/ajax_autocomplete');

  $main::lxdebug->leave_sub();
}

sub continue { call_sub($main::form->{nextsub}); }
