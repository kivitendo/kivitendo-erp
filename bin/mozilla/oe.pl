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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1335, USA.
#======================================================================
#
# Order entry module
# Quotation module
#======================================================================


use Carp;
use POSIX qw(strftime);
use Try::Tiny;

use SL::DB::Order;
use SL::DB::OrderItem;
use SL::DO;
use SL::FU;
use SL::OE;
use SL::IR;
use SL::IS;
use SL::Helper::Flash qw(flash_later);
use SL::Helper::UserPreferences::DisplayPreferences;
use SL::Helper::ShippedQty;
use SL::MoreCommon qw(ary_diff restore_form save_form);
use SL::Presenter::ItemsList;
use SL::ReportGenerator;
use SL::YAML;
use List::MoreUtils qw(uniq any none);
use List::Util qw(min max reduce sum);
use Data::Dumper;

use SL::Controller::Order;
use SL::DB::Customer;
use SL::DB::TaxZone;
use SL::DB::PaymentTerm;
use SL::DB::ValidityToken;
use SL::DB::Vendor;

require "bin/mozilla/common.pl";
require "bin/mozilla/io.pl";
require "bin/mozilla/reportgenerator.pl";

use strict;

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

my $oe_access_map = {
  'sales_order_intake'          => 'sales_order_edit',
  'sales_order'                 => 'sales_order_edit',
  'purchase_order'              => 'purchase_order_edit',
  'purchase_order_confirmation' => 'purchase_order_edit',
  'request_quotation'           => 'request_quotation_edit',
  'sales_quotation'             => 'sales_quotation_edit',
  'purchase_quotation_intake'   => 'request_quotation_edit',
};

my $oe_view_access_map = {
  'sales_order_intake'          => 'sales_order_edit       | sales_order_view',
  'sales_order'                 => 'sales_order_edit       | sales_order_view',
  'purchase_order'              => 'purchase_order_edit    | purchase_order_view',
  'purchase_order_confirmation' => 'purchase_order_edit  | purchase_order_view',
  'request_quotation'           => 'request_quotation_edit | request_quotation_view',
  'sales_quotation'             => 'sales_quotation_edit   | sales_quotation_view',
  'purchase_quotation_intake'   => 'request_quotation_edit | request_quotation_view',
};

sub check_oe_access {
  my (%params) = @_;
  my $form     = $main::form;

  my $right   = ($params{with_view}) ? $oe_view_access_map->{$form->{type}} : $oe_access_map->{$form->{type}};
  $right    ||= 'DOES_NOT_EXIST';

  $main::auth->assert($right);
}

sub check_oe_conversion_to_sales_invoice_allowed {
  return 1 if  $::form->{type} !~ m/^sales/;
  return 1 if ($::form->{type} =~ m/quotation/) && $::instance_conf->get_allow_sales_invoice_from_sales_quotation;
  return 1 if ($::form->{type} =~ m/order/)     && $::instance_conf->get_allow_sales_invoice_from_sales_order;

  $::form->show_generic_error($::locale->text("You do not have the permissions to access this function."));

  return 0;
}

sub new_sales_order {
  $main::lxdebug->enter_sub();

  check_oe_access();

  my $c = SL::Controller::Order->new;
  $c->action_edit_collective();

  $main::lxdebug->leave_sub();
  $::dispatcher->end_request;
}

sub convert_to_delivery_orders {
  # collect order ids
  my @multi_ids = map {
    $_ =~ m{^multi_id_(\d+)$} && $::form->{'multi_id_' . $1} && $::form->{'trans_id_' . $1}
  } grep { $_ =~ m{^multi_id_\d+$} } keys %$::form;

  # make new delivery orders from given orders
  my @orders = map { SL::DB::Order->new(id => $_)->load } @multi_ids;
  my @do_ids;
  my @failed;
  foreach my $order (@orders) {
    # Only consider not delivered quantities.
    SL::Helper::ShippedQty->new->calculate($order)->write_to(\@{$order->items});

    my @items_with_not_delivered_qty =
      grep {$_->qty > 0}
      map  {$_->qty($_->qty - $_->shipped_qty); $_}
      @{$order->items_sorted};

    my $delivery_order;
    try {
      die t8('no undelivered items') if !@items_with_not_delivered_qty;
      $delivery_order = $order->convert_to_delivery_order(items => \@items_with_not_delivered_qty);
    } catch {
      push @failed, {ordnumber => $order->ordnumber, error => $_};
    };
    push @do_ids, $delivery_order->id if $delivery_order;
  }

  require "bin/mozilla/do.pl";
  $::form->{script}        = 'do.pl';
  $::form->{type}          = 'sales_delivery_order';
  $::form->{ids}           = \@do_ids;
  $::form->{"l_$_"}        = 'Y' for qw(donumber ordnumber cusordnumber transdate reqdate name employee);
  $::form->{top_info_text} = $::locale->text('Converted delivery orders');

  flash('info', t8('#1 salses orders were converted to #2 delivery orders', scalar @orders, scalar @do_ids));
  if (@failed) {
    flash('error', t8('The following orders could not be converted to delivery orders:'));
    flash('error', $_->{ordnumber} . ': ' . $_->{error}) for @failed;
  }

  orders();
}

sub order_links {
  $main::lxdebug->enter_sub();

  my (%params) = @_;

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  check_oe_access();

  # retrieve order/quotation
  my $editing = $form->{id};

  OE->retrieve(\%myconfig, \%$form);

  # if multiple rowcounts (== collective order) then check if the
  # there were more than one customer (in that case OE::retrieve removes
  # the content from the field)
  $form->error($locale->text('Collective Orders only work for orders from one customer!'))
    if          $form->{rowcount}  && $form->{type}     eq 'sales_order'
     && defined $form->{customer}  && $form->{customer} eq '';

  $form->backup_vars(qw(payment_id language_id taxzone_id salesman_id taxincluded cp_id intnotes shipto_id delivery_term_id currency));

  # get customer / vendor
  if ($form->{type} =~ /(purchase_order|request_quotation)/) {
    IR->get_vendor(\%myconfig, \%$form);
  } else {
    IS->get_customer(\%myconfig, \%$form);
    $form->{billing_address_id} = $form->{default_billing_address_id} if $params{is_new};
  }

  $form->restore_vars(qw(payment_id language_id taxzone_id intnotes cp_id shipto_id delivery_term_id));
  $form->restore_vars(qw(currency))    if $form->{id};
  $form->restore_vars(qw(taxincluded)) if $form->{id};
  $form->restore_vars(qw(salesman_id)) if $editing;
  $form->{forex}       = $form->{exchangerate};
  $form->{employee}    = "$form->{employee}--$form->{employee_id}";

  $main::lxdebug->leave_sub();
}

sub prepare_order {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  check_oe_access();

  $form->{formname} ||= $form->{type};

  # format discounts if values come from db. either as single id, or as a collective order
  my $format_discounts = $form->{id} || $form->{convert_from_oe_ids};

  for my $i (1 .. $form->{rowcount}) {
    $form->{"reqdate_$i"} ||= $form->{"deliverydate_$i"};
    $form->{"discount_$i"}  = $form->format_amount(\%myconfig, $form->{"discount_$i"} * ($format_discounts ? 100 : 1));
    $form->{"sellprice_$i"} = $form->format_amount(\%myconfig, $form->{"sellprice_$i"});
    $form->{"lastcost_$i"}  = $form->format_amount(\%myconfig, $form->{"lastcost_$i"});
    $form->{"qty_$i"}       = $form->format_amount(\%myconfig, $form->{"qty_$i"});
  }

  $main::lxdebug->leave_sub();
}

sub setup_oe_search_action_bar {
  my %params = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Search'),
        submit    => [ '#form' ],
        accesskey => 'enter',
        checks    => [ 'kivi.validate_form' ],
      ],
    );
  }
  $::request->layout->add_javascripts('kivi.Validator.js');
}

sub setup_oe_orders_action_bar {
  my %params = @_;

  return unless $::form->{type} eq 'sales_order';

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      combobox => [
        action => [
          t8('Actions'),
        ],
        action => [
          t8('New sales order'),
          submit    => [ '#form', { action => 'new_sales_order' } ],
          checks    => [ [ 'kivi.check_if_entries_selected', '[name^=multi_id_]' ] ],
        ],
        action => [
          t8('Convert to delivery orders'),
          submit => [ '#form', { action => 'convert_to_delivery_orders' } ],
          checks => [ [ 'kivi.check_if_entries_selected', '[name^=multi_id_]' ] ],
        ],
      ],
    );
  }
}

sub search {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  check_oe_access(with_view => 1);

  if ($form->{type} eq 'purchase_order') {
    $form->{vc}        = 'vendor';
    $form->{ordnrname} = 'ordnumber';
    $form->{title}     = $locale->text('Purchase Orders');
    $form->{ordlabel}  = $locale->text('Order Number');

  } elsif ($form->{type} eq 'purchase_order_confirmation') {
    $form->{vc}        = 'vendor';
    $form->{ordnrname} = 'ordnumber';
    $form->{title}     = $locale->text('Purchase Order Confirmations');
    $form->{ordlabel}  = $locale->text('Order Confirmation Number');

  } elsif ($form->{type} eq 'request_quotation') {
    $form->{vc}        = 'vendor';
    $form->{ordnrname} = 'quonumber';
    $form->{title}     = $locale->text('Request for Quotations');
    $form->{ordlabel}  = $locale->text('RFQ Number');

  } elsif ($form->{type} eq 'purchase_quotation_intake') {
    $form->{vc}        = 'vendor';
    $form->{ordnrname} = 'quonumber';
    $form->{title}     = $locale->text('Purchase Quotation Intakes');
    $form->{ordlabel}  = $locale->text('Quotation Number');

  } elsif ($form->{type} eq 'sales_order_intake') {
    $form->{vc}        = 'customer';
    $form->{ordnrname} = 'ordnumber';
    $form->{title}     = $locale->text('Sales Order Intakes');
    $form->{ordlabel}  = $locale->text('Order Number');

  } elsif ($form->{type} eq 'sales_order') {
    $form->{vc}        = 'customer';
    $form->{ordnrname} = 'ordnumber';
    $form->{title}     = $locale->text('Sales Order Confirmations');
    $form->{ordlabel}  = $locale->text('Order Number');

  } elsif ($form->{type} eq 'sales_quotation') {
    $form->{vc}        = 'customer';
    $form->{ordnrname} = 'quonumber';
    $form->{title}     = $locale->text('Quotations');
    $form->{ordlabel}  = $locale->text('Quotation Number');

  } else {
    $form->show_generic_error($locale->text('oe.pl::search called with unknown type'));
  }

  # setup vendor / customer data
  $form->get_lists("projects"     => { "key" => "ALL_PROJECTS", "all" => 1 },
                   "taxzones"     => "ALL_TAXZONES",
                   "business_types" => "ALL_BUSINESS_TYPES",);
  $form->{ALL_EMPLOYEES}      = SL::DB::Manager::Employee->get_all_sorted(query => [ deleted => 0 ]);
  $form->{ALL_DEPARTMENTS}    = SL::DB::Manager::Department->get_all;
  $form->{ALL_ORDER_STATUSES} = SL::DB::Manager::OrderStatus->get_all_sorted;

  $form->{CT_CUSTOM_VARIABLES}                  = CVar->get_configs('module' => 'CT');
  ($form->{CT_CUSTOM_VARIABLES_FILTER_CODE},
   $form->{CT_CUSTOM_VARIABLES_INCLUSION_CODE}) = CVar->render_search_options('variables'      => $form->{CT_CUSTOM_VARIABLES},
                                                                              'include_prefix' => 'l_',
                                                                              'include_value'  => 'Y');

  # constants and subs for template
  $form->{vc_keys}         = sub { "$_[0]->{name}--$_[0]->{id}" };

  $form->{ORDER_PROBABILITIES} = [ map { { title => ($_ * 10) . '%', id => $_ * 10 } } (0..10) ];

  $::request->{layout}->use_javascript(map { "${_}.js" } qw(autocomplete_project));

  setup_oe_search_action_bar();

  $form->header();

  print $form->parse_html_template('oe/search', {
    is_order => scalar($form->{type} =~ /_order/),
  });

  $main::lxdebug->leave_sub();
}

sub create_subtotal_row {
  $main::lxdebug->enter_sub();

  my ($totals, $columns, $column_alignment, $subtotal_columns, $class) = @_;

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  my $row = { map { $_ => { 'data' => '', 'class' => $class, 'align' => $column_alignment->{$_}, } } @{ $columns } };

  map { $row->{$_}->{data} = $form->format_amount(\%myconfig, $totals->{$_}, 2) } @{ $subtotal_columns };

  $row->{tax}->{data} = $form->format_amount(\%myconfig, $totals->{amount} - $totals->{netamount}, 2);

  map { $totals->{$_} = 0 } @{ $subtotal_columns };

  $main::lxdebug->leave_sub();

  return $row;
}

sub orders {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;
  my $cgi      = $::request->{cgi};

  my %params   = @_;
  check_oe_access(with_view => 1);

  my $ordnumber = ($form->{type} =~ /_order_intake$|_order$|purchase_order_confirmation/) ? "ordnumber" : "quonumber";

  ($form->{ $form->{vc} }, $form->{"$form->{vc}_id"}) = split(/--/, $form->{ $form->{vc} });
  report_generator_set_default_sort('transdate', 1);
  OE->transactions(\%myconfig, \%$form);

  $form->{rowcount} = scalar @{ $form->{OE} };

  my @columns = (
    "transdate",               "reqdate",
    "id",                      $ordnumber,
    "cusordnumber",            "vendor_confirmation_number",
    "customernumber",
    "name",                    "netamount",
    "tax",                     "amount",
    "remaining_netamount",     "remaining_amount",
    "curr",                    "employee",
    "salesman",
    "shipvia",                 "globalprojectnumber",
    "transaction_description", "department",            "open",
    "delivered",               "periodic_invoices",
    "marge_total",             "marge_percent",
    "vcnumber",                "ustid",
    "country",                 "shippingpoint",
    "taxzone",                 "insertdate",
    "order_probability",       "expected_billing_date", "expected_netamount",
    "payment_terms",           "intnotes",              "order_status",
    "items",
    "shiptoname", "shiptodepartment_1", "shiptodepartment_2", "shiptostreet",
    "shiptozipcode", "shiptocity", "shiptocountry",
  );

  # only show checkboxes if gotten here via sales_order form.
  my $allow_multiple_orders = $form->{type} eq 'sales_order';
  if ($allow_multiple_orders) {
    unshift @columns, "ids";
  }

  $form->{l_open}              = $form->{l_closed} = "Y" if ($form->{open}      && $form->{closed});
  $form->{l_delivered}         = "Y"                     if ($form->{delivered} && $form->{notdelivered});
  $form->{l_periodic_invoices} = "Y"                     if ($form->{periodic_invoices_active} && $form->{periodic_invoices_inactive});
  map { $form->{"l_${_}"} = 'Y' } qw(order_probability expected_billing_date expected_netamount) if $form->{l_order_probability_expected_billing_date};

  my $attachment_basename;
  if ($form->{vc} eq 'vendor') {
    if ($form->{type} eq 'purchase_order') {
      $form->{title}       = $locale->text('Purchase Orders');
      $attachment_basename = $locale->text('purchase_order_list');
    } elsif ($form->{type} eq 'purchase_order_confirmation') {
      $form->{title}       = $locale->text('Purchase Order Confirmations');
      $attachment_basename = $locale->text('purchase_order_confirmation_list');
    } elsif ($form->{type} eq 'purchase_quotation_intake') {
      $form->{title}       = $locale->text('Purchase Quotation Intakes');
      $attachment_basename = $locale->text('purchase_quotation_intake_list');
    } else {
      $form->{title}       = $locale->text('Request for Quotations');
      $attachment_basename = $locale->text('rfq_list');
    }

  } else {
    if ($form->{type} eq 'sales_order_intake') {
      $form->{title}       = $locale->text('Sales Order Intakes');
      $attachment_basename = $locale->text('sales_order_intake_list');
    } elsif ($form->{type} eq 'sales_order') {
      $form->{title}       = $locale->text('Sales Orders');
      $attachment_basename = $locale->text('sales_order_list');
    } else {
      $form->{title}       = $locale->text('Quotations');
      $attachment_basename = $locale->text('quotation_list');
    }
  }

  my $report = SL::ReportGenerator->new(\%myconfig, $form);

  my $ct_cvar_configs = CVar->get_configs('module' => 'CT');
  my @ct_includeable_custom_variables = grep { $_->{includeable} } @{ $ct_cvar_configs };
  my @ct_searchable_custom_variables  = grep { $_->{searchable} }  @{ $ct_cvar_configs };

  my %column_defs_cvars            = map { +"cvar_$_->{name}" => { 'text' => $_->{description} } } @ct_includeable_custom_variables;
  push @columns, map { "cvar_$_->{name}" } @ct_includeable_custom_variables;

  my @hidden_variables = map { "l_${_}" } @columns;
  push @hidden_variables, "l_subtotal", $form->{vc}, qw(
    l_closed l_notdelivered open closed delivered notdelivered ordnumber
    quonumber cusordnumber transaction_description transdatefrom transdateto
    type vc employee_id salesman_id reqdatefrom reqdateto projectnumber
    project_id periodic_invoices_active periodic_invoices_inactive
    business_id shippingpoint taxzone_id reqdate_unset_or_old insertdatefrom
    insertdateto order_probability_op order_probability_value
    expected_billing_date_from expected_billing_date_to parts_partnumber
    parts_description all department_id intnotes phone_notes fulltext
    order_status_id shiptoname shiptodepartment_1 shiptodepartment_2
    shiptostreet shiptozipcode shiptocity shiptocountry
    vendor_confirmation_number
  );
  push @hidden_variables, map { "cvar_$_->{name}" } @ct_searchable_custom_variables;

  my   @keys_for_url = grep { $form->{$_} } @hidden_variables;
  push @keys_for_url, 'taxzone_id' if $form->{taxzone_id} ne ''; # taxzone_id could be 0

  my $href = $params{want_binary_pdf} ? '' : build_std_url('action=orders', @keys_for_url);

  my %column_defs = (
    'ids'                     => { raw_header_data => SL::Presenter::Tag::checkbox_tag("", id => "multi_all", checkall => "[data-checkall=1]"), align => 'center' },
    'transdate'               => { 'text' => $locale->text('Date'), },
    'reqdate'                 => { 'text' => $form->{type} =~ /_order/ ? $locale->text('Required by') : $locale->text('Valid until') },
    'id'                      => { 'text' => $locale->text('ID'), },
    'ordnumber'               => { 'text' => $form->{type} eq "purchase_order_confirmation" ? $locale->text('Confirmation'): $locale->text('Order'), },
    'quonumber'               => { 'text' => $form->{type} eq "request_quotation" ? $locale->text('RFQ') : $locale->text('Quotation'), },
    'cusordnumber'            => { 'text' => $locale->text('Customer Order Number'), },
    'name'                    => { 'text' => $form->{vc} eq 'customer' ? $locale->text('Customer') : $locale->text('Vendor'), },
    'customernumber'          => { 'text' => $locale->text('Customer Number'), },
    'netamount'               => { 'text' => $locale->text('Amount'), },
    'tax'                     => { 'text' => $locale->text('Tax'), },
    'amount'                  => { 'text' => $locale->text('Total'), },
    'remaining_amount'        => { 'text' => $locale->text('Remaining Amount'), },
    'remaining_netamount'     => { 'text' => $locale->text('Remaining Net Amount'), },
    'curr'                    => { 'text' => $locale->text('Curr'), },
    'employee'                => { 'text' => $locale->text('Employee'), },
    'salesman'                => { 'text' => $locale->text('Salesman'), },
    'shipvia'                 => { 'text' => $locale->text('Ship via'), },
    'globalprojectnumber'     => { 'text' => $locale->text('Project Number'), },
    'transaction_description' => { 'text' => $locale->text('Transaction description'), },
    'department'              => { 'text' => $locale->text('Department'), },
    'open'                    => { 'text' => $locale->text('Open'), },
    'delivered'               => { 'text' => $locale->text('Delivery Order created'), },
    'marge_total'             => { 'text' => $locale->text('Ertrag'), },
    'marge_percent'           => { 'text' => $locale->text('Ertrag prozentual'), },
    'vcnumber'                => { 'text' => $form->{vc} eq 'customer' ? $locale->text('Customer Number') : $locale->text('Vendor Number'), },
    'country'                 => { 'text' => $locale->text('Country'), },
    'ustid'                   => { 'text' => $locale->text('USt-IdNr.'), },
    'periodic_invoices'       => { 'text' => $locale->text('Per. Inv.'), },
    'shippingpoint'           => { 'text' => $locale->text('Shipping Point'), },
    'taxzone'                 => { 'text' => $locale->text('Steuersatz'), },
    'insertdate'              => { 'text' => $locale->text('Insert Date'), },
    'order_probability'       => { 'text' => $locale->text('Order probability'), },
    'expected_billing_date'   => { 'text' => $locale->text('Exp. bill. date'), },
    'expected_netamount'      => { 'text' => $locale->text('Exp. netamount'), },
    'payment_terms'           => { 'text' => $locale->text('Payment Terms'), },
    'intnotes'                => { 'text' => $locale->text('Internal Notes'), },
    'order_status'            => { 'text' => $locale->text('Status'), },
    'items'                   => { 'text' => $locale->text('Positions'), },
    shiptoname                => { 'text' => $locale->text('Name (Shipping)'), },
    shiptodepartment_1        => { 'text' => $locale->text('Department 1 (Shipping)'), },
    shiptodepartment_2        => { 'text' => $locale->text('Department 2 (Shipping)'), },
    shiptostreet              => { 'text' => $locale->text('Street (Shipping)'), },
    shiptozipcode             => { 'text' => $locale->text('Zipcode (Shipping)'), },
    shiptocity                => { 'text' => $locale->text('City (Shipping)'), },
    shiptocountry             => { 'text' => $locale->text('Country (Shipping)'), },
    vendor_confirmation_number => { 'text' => $locale->text('Vendor Confirmation Number'), },
    %column_defs_cvars,
  );

  foreach my $name (qw(id transdate reqdate quonumber ordnumber cusordnumber
                       name employee salesman shipvia transaction_description
                       shippingpoint taxzone insertdate payment_terms department
                       intnotes order_status vendor_confirmation_number)) {
    my $sortdir                 = $form->{sort} eq $name ? 1 - $form->{sortdir} : $form->{sortdir};
    $column_defs{$name}->{link} = $href . "&sort=$name&sortdir=$sortdir";
  }

  my %column_alignment =
    map { $_ => 'right' } qw(netamount tax amount curr
                             remaining_amount remaining_netamount
                             order_probability expected_billing_date
                             expected_netamount);

  $form->{"l_type"} = "Y";

  map { $column_defs{$_}->{visible} = $form->{"l_${_}"} ? 1 : 0 } @columns;
  $column_defs{ids}->{visible} = $allow_multiple_orders ? 'HTML' : 0;

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_export_options('orders', @hidden_variables, qw(sort sortdir));
  $report->set_sort_indicator($form->{sort}, $form->{sortdir});

  CVar->add_custom_variables_to_report('module'         => 'CT',
                                       'trans_id_field' => "$form->{vc}_id",
                                       'configs'        => $ct_cvar_configs,
                                       'column_defs'    => \%column_defs,
                                       'data'           => $form->{OE});

  my @options;

  push @options, $locale->text('Customer')                . " : $form->{customer}"                        if $form->{customer};
  push @options, $locale->text('Vendor')                  . " : $form->{vendor}"                          if $form->{vendor};
  push @options, $locale->text('Contact Person')          . " : $form->{cp_name}"                         if $form->{cp_name};
  push @options, $locale->text('Department')              . " : $form->{department}"                      if $form->{department};
  push @options, $locale->text('Order Number')            . " : $form->{ordnumber}"                       if $form->{ordnumber};
  push @options, $locale->text('Vendor Confirmation Number') . " : $form->{vendor_confirmation_number}"   if $form->{vendor_confirmation_number};
  push @options, $locale->text('Customer Order Number')   . " : $form->{cusordnumber}"                    if $form->{cusordnumber};
  push @options, $locale->text('Notes')                   . " : $form->{notes}"                           if $form->{notes};
  push @options, $locale->text('Internal Notes')          . " : $form->{intnotes}"                        if $form->{intnotes};
  push @options, $locale->text('Transaction description') . " : $form->{transaction_description}"         if $form->{transaction_description};
  push @options, $locale->text('Quick Search')            . " : $form->{all}"                             if $form->{all};
  push @options, $locale->text('Shipping Point')          . " : $form->{shippingpoint}"                   if $form->{shippingpoint};
  push @options, $locale->text('Name (Shipping)')         . " : $form->{shiptoname}"
                  if $form->{shiptoname};
  push @options, $locale->text('Department 1 (Shipping)') . " : $form->{shiptodepartment_1}"
                  if $form->{shiptodepartment_1};
  push @options, $locale->text('Department 2 (Shipping)') . " : $form->{shiptodepartment_2}"
                  if $form->{shiptodepartment_2};
  push @options, $locale->text('Street (Shipping)')       . " : $form->{shiptostreet}"
                  if $form->{shiptostreet};
  push @options, $locale->text('Zipcode (Shipping)')      . " : $form->{shiptozipcode}"
                  if $form->{shiptozipcode};
  push @options, $locale->text('City (Shipping)')         . " : $form->{shiptocity}"
                  if $form->{shiptocity};
  push @options, $locale->text('Country (Shipping)')      . " : $form->{shiptocountry}"
                  if $form->{shiptocountry};
  push @options, $locale->text('Part Description')        . " : $form->{parts_description}"               if $form->{parts_description};
  push @options, $locale->text('Part Number')             . " : $form->{parts_partnumber}"                if $form->{parts_partnumber};
  push @options, $locale->text('Phone Notes')             . " : $form->{phone_notes}"                     if $form->{phone_notes};
  push @options, $locale->text('Full Text')               . " : $form->{fulltext}"                        if $form->{fulltext};
  if ( $form->{transdatefrom} or $form->{transdateto} ) {
    push @options, $locale->text('Order Date');
    push @options, $locale->text('From') . " " . $locale->date(\%myconfig, $form->{transdatefrom}, 1)     if $form->{transdatefrom};
    push @options, $locale->text('Bis')  . " " . $locale->date(\%myconfig, $form->{transdateto},   1)     if $form->{transdateto};
  };
  if ( $form->{reqdatefrom} or $form->{reqdateto} ) {
    push @options, $locale->text('Delivery Date');
    push @options, $locale->text('From') . " " . $locale->date(\%myconfig, $form->{reqdatefrom}, 1)       if $form->{reqdatefrom};
    push @options, $locale->text('Bis')  . " " . $locale->date(\%myconfig, $form->{reqdateto},   1)       if $form->{reqdateto};
  };
  if ( $form->{insertdatefrom} or $form->{insertdateto} ) {
    push @options, $locale->text('Insert Date');
    push @options, $locale->text('From') . " " . $locale->date(\%myconfig, $form->{insertdatefrom}, 1)    if $form->{insertdatefrom};
    push @options, $locale->text('Bis')  . " " . $locale->date(\%myconfig, $form->{insertdateto},   1)    if $form->{insertdateto};
  };
  push @options, $locale->text('Open')                                                                    if $form->{open};
  push @options, $locale->text('Closed')                                                                  if $form->{closed};
  push @options, $locale->text('Delivery Order created')                                                               if $form->{delivered};
  push @options, $locale->text('Not delivered')                                                           if $form->{notdelivered};
  push @options, $locale->text('Periodic invoices active')                                                if $form->{periodic_invoices_active};
  push @options, $locale->text('Reqdate not set or before current month')                                 if $form->{reqdate_unset_or_old};

  if ($form->{business_id}) {
    my $vc_type_label = $form->{vc} eq 'customer' ? $locale->text('Customer type') : $locale->text('Vendor type');
    push @options, $vc_type_label . " : " . SL::DB::Business->new(id => $form->{business_id})->load->description;
  }
  if ($form->{taxzone_id} ne '') { # taxzone_id could be 0
    push @options, $locale->text('Steuersatz') . " : " . SL::DB::TaxZone->new(id => $form->{taxzone_id})->load->description;
  }

  if ($form->{department_id}) {
    push @options, $locale->text('Department') . " : " . SL::DB::Department->new(id => $form->{department_id})->load->description;
  }

  if (($form->{order_probability_value} || '') ne '') {
    push @options, $::locale->text('Order probability') . ' ' . ($form->{order_probability_op} eq 'le' ? '<=' : '>=') . ' ' . $form->{order_probability_value} . '%';
  }

  if ($form->{expected_billing_date_from} or $form->{expected_billing_date_to}) {
    push @options, $locale->text('Expected billing date');
    push @options, $locale->text('From') . " " . $locale->date(\%myconfig, $form->{expected_billing_date_from}, 1) if $form->{expected_billing_date_from};
    push @options, $locale->text('Bis')  . " " . $locale->date(\%myconfig, $form->{expected_billing_date_to},   1) if $form->{expected_billing_date_to};
  }

  if ($form->{order_status_id}) {
    push @options, $locale->text('Status') . " : " . SL::DB::OrderStatus->new(id => $form->{order_status_id})->load->name;
  }

  $report->set_options('top_info_text'        => join("\n", @options),
                       'raw_top_info_text'    => $form->parse_html_template('oe/orders_top'),
                       'raw_bottom_info_text' => $form->parse_html_template('oe/orders_bottom'),
                       'output_format'        => 'HTML',
                       'title'                => $form->{title},
                       'attachment_basename'  => $attachment_basename . strftime('_%Y%m%d', localtime time),
    );
  $report->set_options_from_form();
  $locale->set_numberformat_wo_thousands_separator(\%myconfig) if lc($report->{options}->{output_format}) eq 'csv';

  # add sort and escape callback, this one we use for the add sub
  $form->{callback} = $href .= "&sort=$form->{sort}";

  # escape callback for href
  my $callback = $form->escape($href);

  my @subtotal_columns = qw(netamount amount marge_total marge_percent remaining_amount remaining_netamount);
  push @subtotal_columns, 'expected_netamount' if $form->{l_order_probability_expected_billing_date};

  my %totals    = map { $_ => 0 } @subtotal_columns;
  my %subtotals = map { $_ => 0 } @subtotal_columns;

  my $idx = 1;

  my $edit_url = $params{want_binary_pdf}
               ? ''
               : build_std_url('script=controller.pl', 'action=Order/edit', 'type');
  foreach my $oe (@{ $form->{OE} }) {
    map { $oe->{$_} *= $oe->{exchangerate} } @subtotal_columns;

    $oe->{tax}               = $oe->{amount} - $oe->{netamount};
    $oe->{open}              = $oe->{closed}            ? $locale->text('No')  : $locale->text('Yes');
    $oe->{delivered}         = $oe->{delivered}         ? $locale->text('Yes') : $locale->text('No');
    $oe->{periodic_invoices} = $oe->{periodic_invoices} ? $locale->text('On')  : $locale->text('Off');

    map { $subtotals{$_} += $oe->{$_};
          $totals{$_}    += $oe->{$_} } @subtotal_columns;

    $subtotals{marge_percent} = $subtotals{netamount} ? ($subtotals{marge_total} * 100 / $subtotals{netamount}) : 0;
    $totals{marge_percent}    = $totals{netamount}    ? ($totals{marge_total}    * 100 / $totals{netamount}   ) : 0;

    map { $oe->{$_} = $form->format_amount(\%myconfig, $oe->{$_}, 2) } qw(netamount tax amount marge_total marge_percent remaining_amount remaining_netamount expected_netamount);

    $oe->{order_probability} = ($oe->{order_probability} || 0) . '%';

    my $row = { };

    foreach my $column (@columns) {
      next if ($column eq 'ids');
      next if ($column eq 'items');
      $row->{$column} = {
        'data'  => $oe->{$column},
        'align' => $column_alignment{$column},
      };
    }

    $row->{ids} = {
      'raw_data' =>   $cgi->hidden('-name' => "trans_id_${idx}", '-value' => $oe->{id})
                    . $cgi->checkbox('-name' => "multi_id_${idx}", '-value' => 1, 'data-checkall' => 1, '-label' => ''),
      'valign'   => 'center',
      'align'    => 'center',
    };

    if (!$form->{hide_links} || $oe->{is_own}) {
      $row->{$ordnumber}->{link} = $edit_url . "&id=" . E($oe->{id}) . "&callback=${callback}" unless $params{want_binary_pdf};
    }

    if ($form->{l_items}) {
      my $items = SL::DB::Manager::OrderItem->get_all_sorted(where => [id => $oe->{item_ids}]);
      $row->{items}->{raw_data}  = SL::Presenter::ItemsList::items_list($items)               if lc($report->{options}->{output_format}) eq 'html';
      $row->{items}->{data}      = SL::Presenter::ItemsList::items_list($items, as_text => 1) if lc($report->{options}->{output_format}) ne 'html';
    }

    my $row_set = [ $row ];

    if (($form->{l_subtotal} eq 'Y')
        && (($idx == (scalar @{ $form->{OE} }))
            || ($oe->{ $form->{sort} } ne $form->{OE}->[$idx]->{ $form->{sort} }))) {
      push @{ $row_set }, create_subtotal_row(\%subtotals, \@columns, \%column_alignment, \@subtotal_columns, 'listsubtotal');
    }

    $report->add_data($row_set);

    $idx++;
  }

  $report->add_separator();
  $report->add_data(create_subtotal_row(\%totals, \@columns, \%column_alignment, \@subtotal_columns, 'listtotal'));
  if ($params{want_binary_pdf}) {
    $report->generate_with_headers();
    return $report->generate_pdf_content(want_binary_pdf => 1);
  }
  setup_oe_orders_action_bar();
  $report->generate_with_headers();

  $main::lxdebug->leave_sub();
}

sub invoice {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  check_oe_access();
  check_oe_conversion_to_sales_invoice_allowed();
  $form->mtime_ischanged('oe');

  $main::auth->assert($form->{type} eq 'purchase_order' || $form->{type} eq 'request_quotation' ? 'vendor_invoice_edit' : 'invoice_edit');

  $form->{old_salesman_id} = $form->{salesman_id};
  $form->get_employee();


  if ($form->{type} =~ /_order$|purchase_order_confirmation/) {

    # these checks only apply if the items don't bring their own ordnumbers/transdates.
    # The if clause ensures that by searching for empty ordnumber_#/transdate_# fields.
    $form->isblank("ordnumber", $locale->text('Order Number missing!'))
      if (+{ map { $form->{"ordnumber_$_"}, 1 } (1 .. $form->{rowcount} - 1) }->{''});
    $form->isblank("transdate", $locale->text('Order Date missing!'))
      if (+{ map { $form->{"transdate_$_"}, 1 } (1 .. $form->{rowcount} - 1) }->{''});

    # also copy deliverydate from the order
    $form->{deliverydate} = $form->{reqdate} if $form->{reqdate};
    $form->{orddate}      = $form->{transdate};
  } else {
    $form->isblank("quonumber", $locale->text('Quotation Number missing!'));
    $form->isblank("transdate", $locale->text('Quotation Date missing!'));
    $form->{ordnumber}    = "";
    $form->{quodate}      = $form->{transdate};
  }

  my $vc = $form->{vc};
  if (($form->{"previous_${vc}_id"} || $form->{"${vc}_id"}) != $form->{"${vc}_id"}) {
    $::form->{salesman_id} = SL::DB::Manager::Employee->current->id if exists $::form->{salesman_id};

    IS->get_customer(\%myconfig, $form) if $vc eq 'customer';
    IR->get_vendor(\%myconfig, $form)   if $vc eq 'vendor';

    update();
    $::dispatcher->end_request;
  }

  _oe_remove_delivered_or_billed_rows(id => $form->{id}, type => 'billed') if $form->{new_invoice_type} ne 'final_invoice';

  $form->{cp_id} *= 1;

  for my $i (1 .. $form->{rowcount}) {
    for (qw(ship qty sellprice basefactor discount)) {
      $form->{"${_}_${i}"} = $form->parse_amount(\%myconfig, $form->{"${_}_${i}"}) if $form->{"${_}_${i}"};
    }
    $form->{"converted_from_orderitems_id_$i"} = delete $form->{"orderitems_id_$i"};
  }

  my ($buysell, $orddate, $exchangerate);
  if (   $form->{type} =~ /_order/
      && $form->{currency} ne $form->{defaultcurrency}) {

    # check if we need a new exchangerate
    $buysell = ($form->{type} eq 'sales_order') ? "buy" : "sell";

    $orddate      = $form->current_date(\%myconfig);
    $exchangerate = $form->check_exchangerate(\%myconfig, $form->{currency}, $orddate, $buysell);

    if (!$exchangerate) {
      $exchangerate = 0;
    }
  }

  $form->{convert_from_oe_ids} = $form->{id};
  $form->{transdate}           = $form->{invdate} = $form->current_date(\%myconfig);
  $form->{duedate}             = $form->current_date(\%myconfig, $form->{invdate}, $form->{terms} * 1);
  $form->{defaultcurrency}     = $form->get_default_currency(\%myconfig);

  delete @{$form}{qw(id closed)};
  $form->{rowcount}--;

  my ($script);
  if (   $form->{type} eq 'purchase_order'
      || $form->{type} eq 'purchase_order_confirmation'
      || $form->{type} eq 'request_quotation') {
    $form->{title}  = $locale->text('Add Vendor Invoice');
    $form->{script} = 'ir.pl';
    $script         = "ir";
    $buysell        = 'sell';
    $form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_PURCHASE_INVOICE_POST())->token;
  }

  if (   $form->{type} eq 'sales_order'
      || $form->{type} eq 'sales_quotation') {
    $form->{title}  = ($form->{new_invoice_type} eq 'invoice_for_advance_payment') ? $locale->text('Add Invoice for Advance Payment')
                    : ($form->{new_invoice_type} eq 'final_invoice')               ? $locale->text('Add Final Invoice')
                    : $locale->text('Add Sales Invoice');
    $form->{script} = 'is.pl';
    $script         = "is";
    $buysell        = 'buy';
    $form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_SALES_INVOICE_POST())->token;
  }

  # bo creates the id, reset it
  map { delete $form->{$_} } qw(id subject message cc bcc printed emailed queued);
  $form->{ $form->{vc} } =~ s/--.*//g;
  $form->{type} = $form->{new_invoice_type} || "invoice";

  # locale messages
  $main::locale = Locale->new("$myconfig{countrycode}", "$script");
  $locale = $main::locale;

  require "bin/mozilla/$form->{script}";

  my $currency = $form->{currency};
  &invoice_links;

  $form->{currency}     = $currency;
  $form->{forex}        = $form->check_exchangerate( \%myconfig, $form->{currency}, $form->{invdate}, $buysell);
  $form->{exchangerate} = $form->{forex} || '';

  $form->{creditremaining} -= ($form->{oldinvtotal} - $form->{ordtotal});

  &prepare_invoice;

  # format amounts
  for my $i (1 .. $form->{rowcount}) {
    $form->{"discount_$i"} =
      $form->format_amount(\%myconfig, $form->{"discount_$i"});

    my ($dec) = ($form->{"sellprice_$i"} =~ /\.(\d+)/);
    $dec           = length $dec;
    my $decimalplaces = ($dec > 2) ? $dec : 2;

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
  }

  &display_form;

  $main::lxdebug->leave_sub();
}

sub oe_prepare_xyz_from_order {
  return if !$::form->{id};

  my $order = SL::DB::Order->new(id => $::form->{id})->load;

  if (exists $::form->{only_items}) {
    my @wanted_indexes = sort { $a <=> $b } map { $_ - 1 } split(",", $::form->{only_items} // "");
    my @items          = @{ $order->items_sorted };
    @items             = @items[@wanted_indexes];
    $order->items(\@items);
  }

  $order->flatten_to_form($::form, format_amounts => 1);
  $::form->{taxincluded_changed_by_user} = 1;

  # hack: add partsgroup for first row if it does not exists,
  # because _remove_billed_or_delivered_rows and _remove_full_delivered_rows
  # determine fields to handled by existing fields for the first row. If partsgroup
  # is missing there, for deleted rows the partsgroup_field is not emptied and in
  # update_delivery_order it will not considered an empty row ...
  $::form->{partsgroup_1} = '' if !exists $::form->{partsgroup_1};

  # fake last empty row
  $::form->{rowcount}++;

  _update_ship();
}

sub oe_invoice_from_order {
  oe_prepare_xyz_from_order();
  invoice();
}

sub report_for_todo_list {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  my $is_for_sales    = $::auth->assert($oe_view_access_map->{'sales_quotation'},   'may fail');
  my $is_for_purchase = $::auth->assert($oe_view_access_map->{'request_quotation'}, 'may fail');
  my $quotations      = OE->transactions_for_todo_list(sales => $is_for_sales, purchase => $is_for_purchase);
  my $content;

  if (@{ $quotations }) {
    my $callback = build_std_url('action');
    my $edit_url = build_std_url('script=controller.pl', 'action=Order/edit', 'callback=' . E($callback));

    $content     = $form->parse_html_template('oe/report_for_todo_list', { 'QUOTATIONS' => $quotations,
                                                                           'edit_url'   => $edit_url,
                                                                           'callback'   => $callback });
  }

  $main::lxdebug->leave_sub();

  return $content;
}

sub _remove_full_delivered_rows {

  my @fields = map { s/_1$//; $_ } grep { m/_1$/ } keys %{ $::form };
  my @new_rows;

  my $removed_rows = 0;
  my $row          = 0;
  while ($row < $::form->{rowcount}) {
    $row++;
    next unless $::form->{"id_$row"};
    my $base_factor = SL::DB::Manager::Unit->find_by(name => $::form->{"unit_$row"})->base_factor;
    my $base_qty = $::form->parse_amount(\%::myconfig, $::form->{"qty_$row"}) *  $base_factor;
    my $ship_qty = $::form->{"ship_$row"} *  $base_factor;
    #$main::lxdebug->message(LXDebug->DEBUG2(),"shipto=".$ship_qty." qty=".$base_qty);

    if (!$ship_qty || ($ship_qty < $base_qty)) {
      $::form->{"qty_$row"}  = $::form->format_amount(\%::myconfig, ($base_qty - $ship_qty) / $base_factor );
      $::form->{"ship_$row"} = 0;
      push @new_rows, { map { $_ => $::form->{"${_}_${row}"} } @fields };

    } else {
      $removed_rows++;
    }
  }
  $::form->redo_rows(\@fields, \@new_rows, scalar(@new_rows), $::form->{rowcount});
  $::form->{rowcount} -= $removed_rows;
}

sub _oe_remove_delivered_or_billed_rows {
  my (%params) = @_;

  return if !$params{id} || !$params{type};

  my $ord_quot = SL::DB::Order->new(id => $params{id})->load;
  return if !$ord_quot;

  # Prüfung ob itemlinks existieren, falls ja dann neue Implementierung

  if (  $params{type} eq 'delivered' ) {
      my $orderitem = SL::DB::Manager::OrderItem->get_first( where => [trans_id => $ord_quot->id]);
      if ( $orderitem) {
          my @links = $orderitem->linked_records(to => 'SL::DB::DeliveryOrderItem');
          if ( scalar(@links ) > 0 ) {
              #$main::lxdebug->message(LXDebug->DEBUG2(),"item recordlinks vorhanden");
              return _remove_full_delivered_rows();
          }
      }
  }
  my %args    = (
    direction => 'to',
    to        =>   $params{type} eq 'delivered' ? 'DeliveryOrder' : 'Invoice',
    via       => [ $params{type} eq 'delivered' ? qw(Order)       : qw(Order DeliveryOrder) ],
  );

  my %handled_base_qtys;
  foreach my $record (@{ $ord_quot->linked_records(%args) }) {
    next if $ord_quot->is_sales != $record->is_sales;
    next if $record->type eq 'invoice' && $record->storno;

    foreach my $item (@{ $record->items }) {
      my $key  = $item->parts_id;
      $key    .= ':' . $item->serialnumber if $item->serialnumber;
      $handled_base_qtys{$key} += $item->qty * $item->unit_obj->base_factor;
    }
  }

  _remove_billed_or_delivered_rows(quantities => \%handled_base_qtys);
}
