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

sub set_headings {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  check_oe_access();

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

  $main::lxdebug->leave_sub();
}

sub add {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  check_oe_access();

  set_headings("add");

  $form->{callback} =
    "$form->{script}?action=add&type=$form->{type}&vc=$form->{vc}"
    unless $form->{callback};

  $form->{show_details} = $::myconfig{show_form_details};

  order_links(is_new => 1);
  &prepare_order;
  &display_form;

  $main::lxdebug->leave_sub();
}

sub edit {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  check_oe_access();

  $form->{show_details}                = $::myconfig{show_form_details};
  $form->{taxincluded_changed_by_user} = 1;

  # show history button
  $form->{javascript} = qq|<script type="text/javascript" src="js/show_history.js"></script>|;
  #/show hhistory button

  $form->{simple_save} = 0;

  set_headings("edit");

  # editing without stuff to edit? try adding it first
  if ($form->{rowcount} && !$form->{print_and_save}) {
    if ($::instance_conf->get_feature_experimental_order) {
      my $c = SL::Controller::Order->new;
      $c->action_edit_collective();

      $main::lxdebug->leave_sub();
      $::dispatcher->end_request;
    }

    my $id;
    map { $id++ if $form->{"multi_id_$_"} } (1 .. $form->{rowcount});
    if (!$id) {

      # reset rowcount
      undef $form->{rowcount};
      &add;
      $main::lxdebug->leave_sub();
      return;
    }
  } elsif (!$form->{id}) {
    &add;
    $main::lxdebug->leave_sub();
    return;
  }

  my ($language_id, $printer_id);
  if ($form->{print_and_save}) {
    $form->{action}   = "dispatcher";
    $form->{action_print}   = "1";
    $form->{resubmit} = 1;
    $language_id = $form->{language_id};
    $printer_id = $form->{printer_id};
  }

  set_headings("edit");

  &order_links;

  $form->{rowcount} = 0;
  foreach my $ref (@{ $form->{form_details} }) {
    $form->{rowcount}++;
    map { $form->{"${_}_$form->{rowcount}"} = $ref->{$_} } keys %{$ref};
  }

  &prepare_order;

  if ($form->{print_and_save}) {
    $form->{language_id} = $language_id;
    $form->{printer_id} = $printer_id;
  }

  &display_form;

  $main::lxdebug->leave_sub();
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

sub setup_oe_action_bar {
  my %params = @_;
  my $form   = $::form;

  my $has_active_periodic_invoice;
  if ($params{oe_obj}) {
    $has_active_periodic_invoice =
         $params{oe_obj}->is_type('sales_order')
      && $params{oe_obj}->periodic_invoices_config
      && $params{oe_obj}->periodic_invoices_config->active
      && (   !$params{oe_obj}->periodic_invoices_config->end_date
          || ($params{oe_obj}->periodic_invoices_config->end_date > DateTime->today_local))
      && $params{oe_obj}->periodic_invoices_config->get_previous_billed_period_start_date;
  }

  my $allow_invoice      = $params{is_req_quo}
                        || $params{is_pur_ord}
                        || ($params{is_sales_quo} && $::instance_conf->get_allow_sales_invoice_from_sales_quotation)
                        || ($params{is_sales_ord} && $::instance_conf->get_allow_sales_invoice_from_sales_order);
  my @req_trans_cost_art = qw(kivi.SalesPurchase.check_transport_cost_article_presence) x!!$::instance_conf->get_transport_cost_reminder_article_number_id;
  my @warn_p_invoice     = qw(kivi.SalesPurchase.oe_warn_save_active_periodic_invoice)  x!!$has_active_periodic_invoice;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Update'),
        submit    => [ '#form', { action => "update" } ],
        id        => 'update_button',
        accesskey => 'enter',
      ],

      combobox => [
        action => [
          t8('Save'),
          submit  => [ '#form', { action => "save" } ],
          checks  => [ 'kivi.validate_form', @req_trans_cost_art, @warn_p_invoice ],
        ],
        action => [
          t8('Save as new'),
          submit   => [ '#form', { action => "save_as_new" } ],
          checks   => [ 'kivi.validate_form', @req_trans_cost_art ],
          disabled => !$form->{id} ? t8('This record has not been saved yet.') : undef,
        ],
        action => [
          t8('Save and Close'),
          submit  => [ '#form', { action => "save_and_close" } ],
          checks  => [ 'kivi.validate_form', @req_trans_cost_art, @warn_p_invoice ],
        ],
        action => [
          t8('Delete'),
          submit   => [ '#form', { action => "delete" } ],
          confirm  => t8('Do you really want to delete this object?'),
          disabled => !$form->{id}                                                                      ? t8('This record has not been saved yet.')
                    : (   ($params{is_sales_ord} && !$::instance_conf->get_sales_order_show_delete)
                       || ($params{is_pur_ord}   && !$::instance_conf->get_purchase_order_show_delete)) ? t8('Deleting this type of record has been disabled in the configuration.')
                    :                                                                                     undef,
        ],
      ], # end of combobox "Save"

      'separator',

      combobox => [
        action => [ t8('Workflow') ],
        action => [
          t8('Sales Order'),
          submit   => [ '#form', { action => "sales_order" } ],
          disabled => !$form->{id} ? t8('This record has not been saved yet.') : undef,
          checks   => [ 'kivi.validate_form' ],
          only_if  => $params{is_sales_quo} || $params{is_pur_ord},
        ],
        action => [
          t8('Purchase Order'),
          submit   => [ '#form', { action => "purchase_order" } ],
          disabled => !$form->{id} ? t8('This record has not been saved yet.') : undef,
          checks   => [ 'kivi.validate_form' ],
          only_if  => $params{is_sales_ord} || $params{is_req_quo},
        ],
        action => [
          t8('Delivery Order'),
          submit   => [ '#form', { action => "delivery_order" } ],
          disabled => !$form->{id} ? t8('This record has not been saved yet.') : undef,
          checks   => [ 'kivi.validate_form' ],
          only_if  => $params{is_sales_ord} || $params{is_pur_ord},
        ],
        action => [
          t8('Invoice'),
          submit   => [ '#form', { action => "invoice" } ],
          disabled => !$form->{id} ? t8('This record has not been saved yet.') : undef,
          checks   => [ 'kivi.validate_form' ],
          only_if  => $allow_invoice,
        ],
        action => [
          t8('Quotation'),
          submit   => [ '#form', { action => "quotation" } ],
          disabled => !$form->{id} ? t8('This record has not been saved yet.') : undef,
          checks   => [ 'kivi.validate_form' ],
          only_if  => $params{is_sales_ord},
        ],
        action => [
          t8('Request for Quotation'),
          submit   => [ '#form', { action => "request_for_quotation" } ],
          disabled => !$form->{id} ? t8('This record has not been saved yet.') : undef,
          checks   => [ 'kivi.validate_form' ],
          only_if  => $params{is_pur_ord},
        ],
      ], # end of combobox "Workflow"

      combobox => [
        action => [ t8('Export') ],
        action => [
          t8('Print'),
          call   => [ 'kivi.SalesPurchase.show_print_dialog' ],
          checks => [ 'kivi.validate_form' ],
        ],
        action => [
          t8('E Mail'),
          call     => [ 'kivi.SalesPurchase.show_email_dialog' ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$form->{id} ? t8('This record has not been saved yet.') : undef,
        ],
        action => [
          t8('Download attachments of all parts'),
          call     => [ 'kivi.File.downloadOrderitemsFiles', $::form->{type}, $::form->{id} ],
          disabled => !$form->{id} ? t8('This record has not been saved yet.') : undef,
          only_if  => $::instance_conf->get_doc_storage,
        ],
      ], #end of combobox "Export"

      combobox => [
        action => [ t8('more') ],
        action => [
          t8('History'),
          call     => [ 'set_history_window', $form->{id} * 1, 'id' ],
          disabled => !$form->{id} ? t8('This record has not been saved yet.') : undef,
        ],
        action => [
          t8('Follow-Up'),
          call     => [ 'follow_up_window' ],
          disabled => !$form->{id} ? t8('This record has not been saved yet.') : undef,
        ],
      ], # end of combobox "more"
    );
  }
  $::request->layout->add_javascripts('kivi.Validator.js');
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
          submit    => [ '#form', { action => 'edit' } ],
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

sub form_header {
  $main::lxdebug->enter_sub();
  my @custom_hiddens;

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;
  my $cgi      = $::request->{cgi};

  check_oe_access();

  # Container for template variables. Unfortunately this has to be
  # visible in form_footer too, so package local level and not my here.
  my $TMPL_VAR = $::request->cache('tmpl_var', {});
  if ($form->{id}) {
    $TMPL_VAR->{oe_obj} = SL::DB::Order->new(id => $form->{id})->load;
  }
  $TMPL_VAR->{vc_obj} = SL::DB::Customer->new(id => $form->{customer_id})->load if $form->{customer_id};
  $TMPL_VAR->{vc_obj} = SL::DB::Vendor->new(id => $form->{vendor_id})->load     if $form->{vendor_id};

  $form->{defaultcurrency} = $form->get_default_currency(\%myconfig);

  my $current_employee   = SL::DB::Manager::Employee->current;
  $form->{employee_id}   = $form->{old_employee_id} if $form->{old_employee_id};
  $form->{salesman_id}   = $form->{old_salesman_id} if $form->{old_salesman_id};
  $form->{employee_id} ||= $current_employee->id;
  $form->{salesman_id} ||= $current_employee->id;

  # openclosed checkboxes
  my @tmp;
  push @tmp, sprintf qq|<input name="delivered" id="delivered" type="checkbox" class="checkbox" value="1" %s><label for="delivered">%s</label>|,
                        $form->{"delivered"} ? "checked" : "",  $locale->text('Delivery Order(s) for full qty created') if $form->{"type"} =~ /_order$/;
  push @tmp, sprintf qq|<input name="closed" id="closed" type="checkbox" class="checkbox" value="1" %s><label for="closed">%s</label>|,
                        $form->{"closed"}    ? "checked" : "",  $locale->text('Closed')    if $form->{id};
  $TMPL_VAR->{openclosed} = sprintf qq|<tr><td colspan=%d align=center>%s</td></tr>\n|, 2 * scalar @tmp, join "\n", @tmp if @tmp;

  my $vc = $form->{vc} eq "customer" ? "customers" : "vendors";

  $form->get_lists("taxzones"      => ($form->{id} ? "ALL_TAXZONES" : "ALL_ACTIVE_TAXZONES"),
                   "currencies"    => "ALL_CURRENCIES",
                   "price_factors" => "ALL_PRICE_FACTORS");
  $form->{ALL_PAYMENTS} = SL::DB::Manager::PaymentTerm->get_all( where => [ or => [ obsolete => 0, id => $form->{payment_id} || undef ] ]);

  $form->{ALL_DEPARTMENTS} = SL::DB::Manager::Department->get_all_sorted;
  $form->{ALL_LANGUAGES}   = SL::DB::Manager::Language->get_all_sorted;

  # Projects
  my @old_project_ids = uniq grep { $_ } map { $_ * 1 } ($form->{"globalproject_id"}, map { $form->{"project_id_$_"} } 1..$form->{"rowcount"});
  my @old_ids_cond    = @old_project_ids ? (id => \@old_project_ids) : ();
  my @customer_cond;
  if (($vc eq 'customers') && $::instance_conf->get_customer_projects_only_in_sales) {
    @customer_cond = (
      or => [
        customer_id          => $::form->{customer_id},
        billable_customer_id => $::form->{customer_id},
      ]);
  }
  my @conditions = (
    or => [
      and => [ active => 1, @customer_cond ],
      @old_ids_cond,
    ]);

  $TMPL_VAR->{ALL_PROJECTS}          = SL::DB::Manager::Project->get_all_sorted(query => \@conditions);
  $TMPL_VAR->{ALL_DELIVERY_TERMS}    = SL::DB::Manager::DeliveryTerm->get_valid($form->{delivery_term_id});
  $form->{ALL_PROJECTS}            = $TMPL_VAR->{ALL_PROJECTS}; # make projects available for second row drop-down in io.pl

  # label subs
  my $employee_list_query_gen      = sub { $::form->{$_[0]} ? [ or => [ id => $::form->{$_[0]}, deleted => 0 ] ] : [ deleted => 0 ] };
  $TMPL_VAR->{ALL_EMPLOYEES}         = SL::DB::Manager::Employee->get_all_sorted(query => $employee_list_query_gen->('employee_id'));
  $TMPL_VAR->{ALL_SALESMEN}          = SL::DB::Manager::Employee->get_all_sorted(query => $employee_list_query_gen->('salesman_id'));
  $TMPL_VAR->{ALL_SHIPTO}            = SL::DB::Manager::Shipto->get_all_sorted(query => [
    or => [ and => [ trans_id  => $::form->{"$::form->{vc}_id"} * 1, module => 'CT' ], and => [ shipto_id => $::form->{shipto_id} * 1, trans_id => undef ] ]
  ]);
  $TMPL_VAR->{ALL_CONTACTS}          = SL::DB::Manager::Contact->get_all_sorted(query => [
    or => [
      cp_cv_id => $::form->{"$::form->{vc}_id"} * 1,
      and      => [
        cp_cv_id => undef,
        cp_id    => $::form->{cp_id} * 1
      ]
    ]
  ]);
  $TMPL_VAR->{sales_employee_labels} = sub { $_[0]->{name} || $_[0]->{login} };

  # currencies and exchangerate
  $form->{currency}            = $form->{defaultcurrency} unless $form->{currency};
  $TMPL_VAR->{show_exchangerate} = $form->{currency} ne $form->{defaultcurrency};
  push @custom_hiddens, "forex";
  push @custom_hiddens, "exchangerate" if $form->{forex};

  # credit remaining
  my $creditwarning = (($form->{creditlimit} != 0) && ($form->{creditremaining} < 0) && !$form->{update}) ? 1 : 0;
  $TMPL_VAR->{is_credit_remaining_negativ} = ($form->{creditremaining} =~ /-/) ? "0" : "1";

  # business
  $TMPL_VAR->{business_label} = ($form->{vc} eq "customer" ? $locale->text('Customer type') : $locale->text('Vendor type'));

  push @custom_hiddens, "customer_pricegroup_id" if $form->{vc} eq 'customer';

  my $credittext = $locale->text('Credit Limit exceeded!!!');

  my $follow_up_vc                =  $form->{ $form->{vc} eq 'customer' ? 'customer' : 'vendor' };
  $follow_up_vc                   =~ s/--\d*\s*$//;
  $TMPL_VAR->{follow_up_trans_info} =  ($form->{type} =~ /_quotation$/ ? $form->{quonumber} : $form->{ordnumber}) . " ($follow_up_vc)";

  if ($form->{id}) {
    my $follow_ups = FU->follow_ups('trans_id' => $form->{id}, 'not_done' => 1);

    if (scalar @{ $follow_ups }) {
      $TMPL_VAR->{num_follow_ups}     = scalar                    @{ $follow_ups };
      $TMPL_VAR->{num_due_follow_ups} = sum map { $_->{due} * 1 } @{ $follow_ups };
    }
  }

  my $dispatch_to_popup = '';
  if ($form->{resubmit} && ($form->{format} eq "html")) {
      $dispatch_to_popup  = "window.open('about:blank','Beleg'); document.oe.target = 'Beleg';";
      $dispatch_to_popup .= "document.do.submit();";
  } elsif ($form->{resubmit}  && $form->{action_print}) {
    # emulate click for resubmitting actions
    $dispatch_to_popup  = "kivi.SalesPurchase.show_print_dialog(); kivi.SalesPurchase.print_record();";
  } elsif ($creditwarning) {
    $::request->{layout}->add_javascripts_inline("alert('$credittext');");
  }

  $::request->{layout}->add_javascripts_inline("\$(function(){$dispatch_to_popup});");
  $TMPL_VAR->{dateformat}                             = $myconfig{dateformat};
  $TMPL_VAR->{numberformat}                           = $myconfig{numberformat};
  $TMPL_VAR->{longdescription_dialog_size_percentage} = SL::Helper::UserPreferences::DisplayPreferences->new()->get_longdescription_dialog_size_percentage();

  if ($form->{type} eq 'sales_order') {
    if (!$form->{periodic_invoices_config}) {
      $form->{periodic_invoices_status} = $locale->text('not configured');

    } else {
      my $config                        = SL::YAML::Load($form->{periodic_invoices_config});
      $form->{periodic_invoices_status} = $config->{active} ? $locale->text('active') : $locale->text('inactive');
    }
  }

  $::request->{layout}->use_javascript(map { "${_}.js" } qw(kivi.SalesPurchase kivi.File kivi.Part kivi.CustomerVendor kivi.Validator show_form_details show_history show_vc_details ckeditor5/ckeditor ckeditor5/translations/de kivi.io));


  # original snippets:
  my %type_check_vars = (
    is_sales     => scalar($form->{type} =~ /^sales_/),
    is_order     => scalar($form->{type} =~ /_order$/),
    is_sales_quo => scalar($form->{type} =~ /sales_quotation$/),
    is_req_quo   => scalar($form->{type} =~ /request_quotation$/),
    is_sales_ord => scalar($form->{type} =~ /sales_order$/),
    is_pur_ord   => scalar($form->{type} =~ /purchase_order$/),
  );

  setup_oe_action_bar(
    %type_check_vars,
    oe_obj => $TMPL_VAR->{oe_obj},
    vc_obj => $TMPL_VAR->{vc_obj},
  );

  $form->header;
  if ($form->{CFDD_shipto} && $form->{CFDD_shipto_id} ) {
      $form->{shipto_id} = $form->{CFDD_shipto_id};
  }

  $TMPL_VAR->{HIDDENS} = [ map { name => $_, value => $form->{$_} },
     qw(id type vc proforma queued printed emailed
        title creditlimit creditremaining tradediscount business
        max_dunning_level dunning_amount
        CFDD_shipto CFDD_shipto_id
        taxpart taxservice taxaccounts cursor_fokus
        show_details useasnew),
        @custom_hiddens,
        map { $_.'_rate', $_.'_description', $_.'_taxnumber', $_.'_tax_id' } split / /, $form->{taxaccounts} ];  # deleted: discount

  $TMPL_VAR->{$_} = $type_check_vars{$_} for keys %type_check_vars;

  $TMPL_VAR->{ORDER_PROBABILITIES} = [ map { { title => ($_ * 10) . '%', id => $_ * 10 } } (0..10) ];

  if ($type_check_vars{is_sales} && $::instance_conf->get_transport_cost_reminder_article_number_id) {
    $TMPL_VAR->{transport_cost_reminder_article} = SL::DB::Part->new(id => $::instance_conf->get_transport_cost_reminder_article_number_id)->load;
  }

  print $form->parse_html_template("oe/form_header", {
    %$TMPL_VAR,
    %type_check_vars,
  });

  $main::lxdebug->leave_sub();
}

sub form_footer {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  check_oe_access();

  $form->{invtotal} = $form->{invsubtotal};

  my $TMPL_VAR = $::request->cache('tmpl_var', {});

  if( $form->{customer_id} && !$form->{taxincluded_changed_by_user} ) {
    my $customer = SL::DB::Customer->new(id => $form->{customer_id})->load();
    $form->{taxincluded} = defined($customer->taxincluded_checked) ? $customer->taxincluded_checked : $myconfig{taxincluded_checked};
  }

  if (!$form->{taxincluded}) {

    foreach my $item (split / /, $form->{taxaccounts}) {
      if ($form->{"${item}_base"}) {
        $form->{invtotal} += $form->{"${item}_total"} = $form->round_amount( $form->{"${item}_base"} * $form->{"${item}_rate"}, 2);
        $form->{"${item}_total"} = $form->format_amount(\%myconfig, $form->{"${item}_total"}, 2);

        $TMPL_VAR->{tax} .= qq|
              <tr>
                <th align=right>$form->{"${item}_description"}&nbsp;| . $form->{"${item}_rate"} * 100 .qq|%</th>
                <td align=right>$form->{"${item}_total"}</td>
              </tr> |;
      }
    }
  } else {
    foreach my $item (split / /, $form->{taxaccounts}) {
      if ($form->{"${item}_base"}) {
        $form->{"${item}_total"} = $form->round_amount( ($form->{"${item}_base"} * $form->{"${item}_rate"} / (1 + $form->{"${item}_rate"})), 2);
        $form->{"${item}_netto"} = $form->round_amount( ($form->{"${item}_base"} - $form->{"${item}_total"}), 2);
        $form->{"${item}_total"} = $form->format_amount(\%myconfig, $form->{"${item}_total"}, 2);
        $form->{"${item}_netto"} = $form->format_amount(\%myconfig, $form->{"${item}_netto"}, 2);

        $TMPL_VAR->{tax} .= qq|
              <tr>
                <th align=right>Enthaltene $form->{"${item}_description"}&nbsp;| . $form->{"${item}_rate"} * 100 .qq|%</th>
                <td align=right>$form->{"${item}_total"}</td>
              </tr>
              <tr>
                <th align=right>Nettobetrag</th>
                <td align=right>$form->{"${item}_netto"}</td>
              </tr> |;
      }
    }
  }

  my $grossamount = $form->{invtotal};
  $form->{invtotal} = $form->round_amount( $form->{invtotal}, 2, 1);
  $form->{rounding} = $form->round_amount(
    $form->{invtotal} - $form->round_amount($grossamount, 2),
    2
  );
  $form->{oldinvtotal} = $form->{invtotal};

  my $print_options_html = setup_sales_purchase_print_options();

  my $shipto_cvars       = SL::DB::Shipto->new->cvars_by_config;
  foreach my $var (@{ $shipto_cvars }) {
    my $name = "shiptocvar_" . $var->config->name;
    $var->value($form->{$name}) if exists $form->{$name};
  }

  print $form->parse_html_template("oe/form_footer", {
     %$TMPL_VAR,
     print_options   => $print_options_html,
     is_sales        => scalar ($form->{type} =~ /^sales_/),              # these vars are exported, so that the template
     is_order        => scalar ($form->{type} =~ /_order$/),              # may determine what to show
     is_sales_quo    => scalar ($form->{type} =~ /sales_quotation$/),
     is_req_quo      => scalar ($form->{type} =~ /request_quotation$/),
     is_sales_ord    => scalar ($form->{type} =~ /sales_order$/),
     is_pur_ord      => scalar ($form->{type} =~ /purchase_order$/),
     shipto_cvars    => $shipto_cvars,
  });

  $main::lxdebug->leave_sub();
}

sub update {
  $main::lxdebug->enter_sub();

  my ($recursive_call) = @_;

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  check_oe_access();

  set_headings($form->{"id"} ? "edit" : "add");

  $form->{update} = 1;

  my $vc = $form->{vc};
  if (($form->{"previous_${vc}_id"} || $form->{"${vc}_id"}) != $form->{"${vc}_id"}) {
    $::form->{salesman_id} = SL::DB::Manager::Employee->current->id if exists $::form->{salesman_id};

    if ($vc eq 'customer') {
      IS->get_customer(\%myconfig, $form);
      $::form->{billing_address_id} = $::form->{default_billing_address_id};
    } else {
      IR->get_vendor(\%myconfig, $form);
    }
  }

  if (!$form->{forex}) {        # read exchangerate from input field (not hidden)
    map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) } qw(exchangerate) unless $recursive_call;
  }
  my $buysell           = 'buy';
  $buysell              = 'sell' if ($form->{vc} eq 'vendor');
  $form->{forex}        = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{transdate}, $buysell);
  $form->{exchangerate} = $form->{forex} if $form->{forex};

  my $exchangerate = $form->{exchangerate} || 1;

##################### process items ######################################
  # for pricegroups
  my $i = $form->{rowcount};
  if (   ($form->{"partnumber_$i"} eq "")
      && ($form->{"description_$i"} eq "")
      && ($form->{"partsgroup_$i"}  eq "")) {

    $form->{creditremaining} += ($form->{oldinvtotal} - $form->{oldtotalpaid});

    &check_form;
  } else {

    my $mode;
    if ($form->{type} =~ /^sales/) {
      IS->retrieve_item(\%myconfig, \%$form);
      $mode = 'IS';
    } else {
      IR->retrieve_item(\%myconfig, \%$form);
      $mode = 'IR';
    }

    my $rows = scalar @{ $form->{item_list} };

    $form->{"discount_$i"}   = $form->parse_amount(\%myconfig, $form->{"discount_$i"}) / 100.0;
    $form->{"discount_$i"} ||= $form->{"$form->{vc}_discount"};

    $form->{"lastcost_$i"} = $form->parse_amount(\%myconfig, $form->{"lastcost_$i"});

    if ($rows) {

      $form->{"qty_$i"} = $form->parse_amount(\%myconfig, $form->{"qty_$i"});
      if( !$form->{"qty_$i"} ) {
        $form->{"qty_$i"} = 1;
      }

      if ($rows > 1) {

        select_item(mode => $mode, pre_entered_qty => $form->{"qty_$i"});
        $::dispatcher->end_request;

      } else {

        my $sellprice             = $form->parse_amount(\%myconfig, $form->{"sellprice_$i"});
        # hier werden parts (Artikeleigenschaften) aus item_list (retrieve_item aus IS.pm)
        # (item wahrscheinlich synonym für parts) entsprechend in die form geschrieben ...

        # Wäre dieses Mapping nicht besser in retrieve_items aufgehoben?
        #(Eine Funktion bekommt Daten -> ARBEIT -> Rückgabe DATEN)
        #  Das quot sieht doch auch nach Überarbeitung aus ... (hmm retrieve_items gibt es in IS und IR)
        map { $form->{item_list}[$i]{$_} =~ s/\"/&quot;/g }    qw(partnumber description unit);
        map { $form->{"${_}_$i"} = $form->{item_list}[0]{$_} } keys %{ $form->{item_list}[0] };

        # ... deswegen muss die prüfung, ob es sich um einen nicht rabattierfähigen artikel handelt später erfolgen (Bug 1136)
        $form->{"discount_$i"} = 0 if $form->{"not_discountable_$i"};
        $form->{payment_id} = $form->{"part_payment_id_$i"} if $form->{"part_payment_id_$i"} ne "";

        $form->{"marge_price_factor_$i"} = $form->{item_list}->[0]->{price_factor};

        ($sellprice || $form->{"sellprice_$i"}) =~ /\.(\d+)/;
        my $dec_qty       = length $1;
        my $decimalplaces = max 2, $dec_qty;

        if ($sellprice) {
          $form->{"sellprice_$i"} = $sellprice;
        } else {
          my $record        = _make_record();
          my $price_source  = SL::PriceSource->new(record_item => $record->items->[$i-1], record => $record);
          my $best_price    = $price_source->best_price;
          my $best_discount = $price_source->best_discount;

          if ($best_price) {
            $::form->{"sellprice_$i"}           = $best_price->price;
            $::form->{"active_price_source_$i"} = $best_price->source;
          }
          if ($best_discount) {
            $::form->{"discount_$i"}               = $best_discount->discount;
            $::form->{"active_discount_source_$i"} = $best_discount->source;
          }

          $form->{"sellprice_$i"} /= $exchangerate;   # if there is an exchange rate adjust sellprice
        }

        my $amount = $form->{"sellprice_$i"} * $form->{"qty_$i"} * (1 - $form->{"discount_$i"});
        map { $form->{"${_}_base"} = 0 }                                 split / /, $form->{taxaccounts};
        map { $form->{"${_}_base"} += $amount }                          split / /, $form->{"taxaccounts_$i"};
        map { $amount += ($form->{"${_}_base"} * $form->{"${_}_rate"}) } split / /, $form->{taxaccounts} if !$form->{taxincluded};

        $form->{creditremaining} -= $amount;

        $form->{"sellprice_$i"} = $form->format_amount(\%myconfig, $form->{"sellprice_$i"}, $decimalplaces);
        $form->{"lastcost_$i"}  = $form->format_amount(\%myconfig, $form->{"lastcost_$i"}, $decimalplaces);
        $form->{"qty_$i"}       = $form->format_amount(\%myconfig, $form->{"qty_$i"}, $dec_qty);
        $form->{"discount_$i"}  = $form->format_amount(\%myconfig, $form->{"discount_$i"} * 100.0);
      }

      display_form();
    } else {

      # ok, so this is a new part
      # ask if it is a part or service item

      if (   $form->{"partsgroup_$i"}
          && ($form->{"partsnumber_$i"} eq "")
          && ($form->{"description_$i"} eq "")) {
        $form->{rowcount}--;
        $form->{"discount_$i"} = "";

        display_form();
      } else {
        $form->{"id_$i"}   = 0;
        new_item();
      }
    }
  }
##################### process items ######################################


  $main::lxdebug->leave_sub();
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
               : ($::instance_conf->get_feature_experimental_order)
               ? build_std_url('script=controller.pl', 'action=Order/edit', 'type')
               : build_std_url('action=edit', 'type', 'vc');
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

sub check_delivered_flag {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  check_oe_access();

  if (($form->{type} ne 'sales_order') && ($form->{type} ne 'purchase_order')) {
    return $main::lxdebug->leave_sub();
  }

  my $all_delivered = 0;

  foreach my $i (1 .. $form->{rowcount}) {
    next if (!$form->{"id_$i"});

    $form->{"ship_$i"} = 0 if $form->{saveasnew};

    if ($form->parse_amount(\%myconfig, $form->{"qty_$i"}) == $form->parse_amount(\%myconfig, $form->{"ship_$i"})) {
      $all_delivered = 1;
      next;
    }

    $all_delivered = 0;
    last;
  }

  $form->{delivered} = 1 if $all_delivered;
  $form->{delivered} = 0 if $form->{saveasnew};

  $main::lxdebug->leave_sub();
}

sub save_and_close {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  check_oe_access();
  $form->mtime_ischanged('oe');

  $form->{defaultcurrency} = $form->get_default_currency(\%myconfig);

  if ($form->{type} =~ /_order$/) {
    $form->isblank("transdate", $locale->text('Order Date missing!'));
  } else {
    $form->isblank("transdate", $locale->text('Quotation Date missing!'));
  }

  my $idx = $form->{type} =~ /_quotation$/ ? "quonumber" : "ordnumber";
  $form->{$idx} =~ s/^\s*//g;
  $form->{$idx} =~ s/\s*$//g;

  my $msg = ucfirst $form->{vc};
  $form->isblank($form->{vc} . '_id', $locale->text($msg . " missing!"));

  # $locale->text('Customer missing!');
  # $locale->text('Vendor missing!');

  $form->isblank("exchangerate", $locale->text('Exchangerate missing!'))
    if ($form->{currency} ne $form->{defaultcurrency});

  &validate_items;

  my $vc = $form->{vc};
  if (($form->{"previous_${vc}_id"} || $form->{"${vc}_id"}) != $form->{"${vc}_id"}) {
    $::form->{salesman_id} = SL::DB::Manager::Employee->current->id if exists $::form->{salesman_id};

    IS->get_customer(\%myconfig, $form) if $vc eq 'customer';
    IR->get_vendor(\%myconfig, $form)   if $vc eq 'vendor';

    $::form->{billing_address_id} = $::form->{default_billing_address_id};

    update();
    $::dispatcher->end_request;
  }

  $form->{id} = 0 if $form->{saveasnew};

  my ($numberfld, $ordnumber, $err);
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

    check_delivered_flag();

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

  # get new number in sequence if saveasnew was requested
  delete $form->{$ordnumber} if $form->{saveasnew};

  relink_accounts();

  $form->error($err) if (!OE->save(\%myconfig, \%$form));

  # saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers} = qq|ordnumber_| . $form->{ordnumber};
    $form->{addition} = "SAVED";
    $form->save_history;
  }
  # /saving the history

  $form->redirect($form->{label} . " $form->{$ordnumber} " .
                  $locale->text('saved!'));

  $main::lxdebug->leave_sub();
}

sub save {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  check_oe_access();

  $form->mtime_ischanged('oe');
  $form->{defaultcurrency} = $form->get_default_currency(\%myconfig);


  if ($form->{type} =~ /_order$/) {
    $form->isblank("transdate", $locale->text('Order Date missing!'));
  } else {
    $form->isblank("transdate", $locale->text('Quotation Date missing!'));
  }

  my $idx = $form->{type} =~ /_quotation$/ ? "quonumber" : "ordnumber";
  $form->{$idx} =~ s/^\s*//g;
  $form->{$idx} =~ s/\s*$//g;

  my $msg = ucfirst $form->{vc};
  $form->isblank($form->{vc} . '_id', $locale->text($msg . " missing!"));

  # $locale->text('Customer missing!');
  # $locale->text('Vendor missing!');

  $form->isblank("exchangerate", $locale->text('Exchangerate missing!'))
    if ($form->{currency} ne $form->{defaultcurrency});

  remove_emptied_rows();
  &validate_items;

  my $vc = $form->{vc};
  if (($form->{"previous_${vc}_id"} || $form->{"${vc}_id"}) != $form->{"${vc}_id"}) {
    $::form->{salesman_id} = SL::DB::Manager::Employee->current->id if exists $::form->{salesman_id};

    if ($vc eq 'customer') {
      IS->get_customer(\%myconfig, $form);
      $::form->{billing_address_id} = $::form->{default_billing_address_id};

    } else {
      IR->get_vendor(\%myconfig, $form);
    }

    update();
    $::dispatcher->end_request;
  }

  $form->{id} = 0 if $form->{saveasnew};

  my ($numberfld, $ordnumber, $err);

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

    check_delivered_flag();

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

  relink_accounts();

  OE->save(\%myconfig, \%$form);

  # saving the history
  if(!exists $form->{addition}) {
    if ( $form->{formname} eq 'sales_quotation' or  $form->{formname} eq 'request_quotation' ) {
        $form->{snumbers} = qq|quonumber_| . $form->{quonumber};
    } elsif ( $form->{formname} eq 'sales_order' or $form->{formname} eq 'purchase_order') {
        $form->{snumbers} = qq|ordnumber_| . $form->{ordnumber};
    };
    $form->{what_done} = $form->{formname};
    $form->{addition} = "SAVED";
    $form->save_history;
  }
  # /saving the history

  $form->{simple_save} = 1;
  if(!$form->{print_and_save}) {
    delete @{$form}{ary_diff([keys %{ $form }], [qw(login id script type cursor_fokus)])};
    edit();
    $::dispatcher->end_request;
  }
  $main::lxdebug->leave_sub();
}

sub delete {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  check_oe_access();

  my ($msg, $err);
  if ($form->{type} =~ /_order$/) {
    $msg = $locale->text('Order deleted!');
    $err = $locale->text('Cannot delete order!');
  } else {
    $msg = $locale->text('Quotation deleted!');
    $err = $locale->text('Cannot delete quotation!');
  }
  if (OE->delete(\%myconfig, \%$form)){
    # saving the history
    if(!exists $form->{addition}) {
      if ( $form->{formname} eq 'sales_quotation' or  $form->{formname} eq 'request_quotation' ) {
          $form->{snumbers} = qq|quonumber_| . $form->{quonumber};
      } elsif ( $form->{formname} eq 'sales_order' or $form->{formname} eq 'purchase_order') {
          $form->{snumbers} = qq|ordnumber_| . $form->{ordnumber};
      };
        $form->{what_done} = $form->{formname};
        $form->{addition} = "DELETED";
        $form->save_history;
    }
    # /saving the history
    $form->info($msg);
    $::dispatcher->end_request;
  }
  $form->error($err);

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

sub save_as_new {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  check_oe_access();

  $form->{saveasnew} = 1;
  map { delete $form->{$_} } qw(printed emailed queued delivered closed);
  $form->{"converted_from_orderitems_id_$_"} = delete $form->{"orderitems_id_$_"} for 1 .. $form->{"rowcount"};

  # Let kivitendo assign a new order number if the user hasn't changed the
  # previous one. If it has been changed manually then use it as-is.
  my $idx = $form->{type} =~ /_quotation$/ ? "quonumber" : "ordnumber";
  $form->{$idx} =~ s/^\s*//g;
  $form->{$idx} =~ s/\s*$//g;
  if ($form->{saved_xyznumber} &&
      ($form->{saved_xyznumber} eq $form->{$idx})) {
    delete($form->{$idx});
  }

  # clear reqdate and transdate unless changed
  if ( $form->{reqdate} && $form->{id} ) {
    my $saved_order = OE->retrieve_simple(id => $form->{id});
    if ( $saved_order && $saved_order->{reqdate} eq $form->{reqdate} && $saved_order->{transdate} eq $form->{transdate} ) {
      my $extra_days = $form->{type} eq 'sales_quotation' ? $::instance_conf->get_reqdate_interval       :
                       $form->{type} eq 'sales_order'     ? $::instance_conf->get_delivery_date_interval : 1;

    if (   ($form->{type} eq 'sales_order'     &&  !$::instance_conf->get_deliverydate_on)
        || ($form->{type} eq 'sales_quotation' &&  !$::instance_conf->get_reqdate_on)) {
      $form->{reqdate}   = '';
    } else {
      $form->{reqdate}   = DateTime->today_local->next_workday(extra_days => $extra_days)->to_kivitendo;
    }
      $form->{transdate} = DateTime->today_local->to_kivitendo;
    }
  }
  # update employee
  $form->get_employee();

  &save;

  $main::lxdebug->leave_sub();
}

sub check_for_direct_delivery_yes {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  check_oe_access();

  $form->{direct_delivery_checked} = 1;
  delete @{$form}{grep /^shipto/, keys %{ $form }};
  map { s/^CFDD_//; $form->{$_} = $form->{"CFDD_${_}"} } grep /^CFDD_/, keys %{ $form };
  $form->{CFDD_shipto} = 1;
  purchase_order();
  $main::lxdebug->leave_sub();
}

sub check_for_direct_delivery_no {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  check_oe_access();

  $form->{direct_delivery_checked} = 1;
  delete @{$form}{grep /^shipto/, keys %{ $form }};
  $form->{CFDD_shipto} = 0;
  purchase_order();

  $main::lxdebug->leave_sub();
}

sub check_for_direct_delivery {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  check_oe_access();

  if ($form->{direct_delivery_checked}
      || (!$form->{shiptoname} && !$form->{shiptostreet} && !$form->{shipto_id})) {
    $main::lxdebug->leave_sub();
    return;
  }

  my $cvars = SL::DB::Shipto->new->cvars_by_config;

  if ($form->{shipto_id}) {
    Common->get_shipto_by_id(\%myconfig, $form, $form->{shipto_id}, "CFDD_");

  } else {
    map { $form->{"CFDD_${_}"} = $form->{$_ } } grep /^shipto/, keys %{ $form };
  }

  $_->value($::form->{"CFDD_shiptocvar_" . $_->config->name}) for @{ $cvars };

  delete $form->{action};
  $form->{VARIABLES} = [ map { { "key" => $_, "value" => $form->{$_} } } grep { ($_ ne 'login') && ($_ ne 'password') && (ref $_ eq "") } keys %{ $form } ];

  $form->header();
  print $form->parse_html_template("oe/check_for_direct_delivery", { cvars => $cvars });

  $main::lxdebug->leave_sub();

  $::dispatcher->end_request;
}

sub purchase_order {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  check_oe_access();
  $form->mtime_ischanged('oe');

  $main::auth->assert('purchase_order_edit');

  $form->{sales_order_to_purchase_order} = 0;
  if ($form->{type} eq 'sales_order') {
    $form->{sales_order_to_purchase_order} = 1;
    check_for_direct_delivery();
  }

  if ($form->{type} =~ /^sales_/) {
    delete($form->{ordnumber});
    delete($form->{payment_id});
    delete($form->{delivery_term_id});
  }

  $form->{cp_id} *= 1;

  my $source_type = $form->{type};
  $form->{title} = $locale->text('Add Purchase Order');
  $form->{vc}    = "vendor";
  $form->{type}  = "purchase_order";

  $form->get_employee();

  poso(source_type => $form->{type});

  delete $form->{sales_order_to_purchase_order};

  $main::lxdebug->leave_sub();
}

sub sales_order {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  check_oe_access();
  $main::auth->assert('sales_order_edit');
  $form->mtime_ischanged('oe');

  if ($form->{type} eq "purchase_order") {
    delete($form->{ordnumber});
    $form->{"lastcost_$_"} = $form->{"sellprice_$_"} for (1..$form->{rowcount});
  }

  $form->{cp_id} *= 1;

  my $source_type = $form->{type};
  $form->{title}  = $locale->text('Add Sales Order');
  $form->{vc}     = "customer";
  $form->{type}   = "sales_order";

  $form->get_employee();

  poso(source_type => $source_type);

  $main::lxdebug->leave_sub();
}

sub poso {
  $main::lxdebug->enter_sub();

  my %param    = @_;
  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  check_oe_access();
  $main::auth->assert('purchase_order_edit | sales_order_edit');

  $form->{transdate} = $form->current_date(\%myconfig);
  delete $form->{duedate};

  # "reqdate" is the validity date for a quotation and the delivery
  # date for an order. Therefore it makes no sense to keep the value
  # when converting from one into the other.
  delete $form->{reqdate} if ($param{source_type} =~ /_quotation$/) == ($form->{type} =~ /_quotation$/);

  $form->{convert_from_oe_ids} = $form->{id};
  $form->{closed}              = 0;

  $form->{old_employee_id}     = $form->{employee_id};
  $form->{old_salesman_id}     = $form->{salesman_id};

  # reset
  map { delete $form->{$_} } qw(id subject message cc bcc printed emailed queued customer vendor creditlimit creditremaining discount tradediscount oldinvtotal delivered ordnumber
                                taxzone_id currency);
  # this converted variable is also used for sales_order to purchase order and vice versa
  $form->{"converted_from_orderitems_id_$_"} = delete $form->{"orderitems_id_$_"} for 1 .. $form->{"rowcount"};

  # if purchase_order was generated from sales_order, use  lastcost_$i as sellprice_$i
  # also reset discounts
  if ( $form->{sales_order_to_purchase_order} ) {
    for my $i (1 .. $form->{rowcount}) {
      $form->{"sellprice_${i}"} = $form->{"lastcost_${i}"};
      $form->{"discount_${i}"}  = 0;
    };
  };

  for my $i (1 .. $form->{rowcount}) {
    map { $form->{"${_}_${i}"} = $form->parse_amount(\%myconfig, $form->{"${_}_${i}"}) if ($form->{"${_}_${i}"}) } qw(ship qty sellprice basefactor discount lastcost);
  }

  my %saved_vars = map { $_ => $form->{$_} } grep { $form->{$_} } qw(currency);

  &order_links;

  map { $form->{$_} = $saved_vars{$_} } keys %saved_vars;

  # prepare_order assumes that the discount is in db-notation (0.05) and not user-notation (5)
  # and therefore multiplies the values by 100 in the case of reading from db or making an order
  # from several quotation, so we convert this back into percent-notation for the user interface by multiplying with 0.01
  # ergänzung 03.10.2010 muss vor prepare_order passieren (s.a. Svens Kommentar zu Bug 1017)
  # das parse_amount wird oben schon ausgeführt, deswegen an dieser stelle raus (wichtig: kommawerte bei discount testen)
  for my $i (1 .. $form->{rowcount}) {
    $form->{"discount_$i"} /=100;
  };

  &prepare_order;
  &update;

  $main::lxdebug->leave_sub();
}

sub delivery_order {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $form->mtime_ischanged('oe');

  if ($form->{type} =~ /^sales/) {
    $main::auth->assert('sales_delivery_order_edit');

    $form->{vc}    = 'customer';
    $form->{type}  = 'sales_delivery_order';

  } else {
    $main::auth->assert('purchase_delivery_order_edit');

    $form->{vc}    = 'vendor';
    $form->{type}  = 'purchase_delivery_order';
  }

  $form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_DELIVERY_ORDER_SAVE())->token;

  $form->get_employee();

  require "bin/mozilla/do.pl";

  $form->{script}               = 'do.pl';
  $form->{cp_id}               *= 1;
  $form->{convert_from_oe_ids}  = $form->{id};
  $form->{transdate}            = $form->current_date(\%myconfig);
  delete $form->{duedate};

  $form->{old_employee_id}  = $form->{employee_id};
  $form->{old_salesman_id}  = $form->{salesman_id};

  _oe_remove_delivered_or_billed_rows(id => $form->{id}, type => 'delivered');

  # reset
  delete @{$form}{qw(id subject message cc bcc printed emailed queued creditlimit creditremaining discount tradediscount oldinvtotal closed delivered)};

  for my $i (1 .. $form->{rowcount}) {
    map { $form->{"${_}_${i}"} = $form->parse_amount(\%myconfig, $form->{"${_}_${i}"}) if ($form->{"${_}_${i}"}) } qw(ship qty sellprice lastcost basefactor discount);
    $form->{"converted_from_orderitems_id_$i"} = delete $form->{"orderitems_id_$i"};
  }

  my %old_values = map { $_ => $form->{$_} } qw(customer_id oldcustomer customer vendor_id oldvendor vendor shipto_id);

  order_links();

  prepare_order();

  map { $form->{$_} = $old_values{$_} if ($old_values{$_}) } keys %old_values;

  for my $i (1 .. $form->{rowcount}) {
    (my $dummy, $form->{"pricegroup_id_$i"}) = split /--/, $form->{"sellprice_pg_$i"};
  }
  update();

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

sub oe_delivery_order_from_order {
  oe_prepare_xyz_from_order();
  delivery_order();
}

sub oe_invoice_from_order {
  oe_prepare_xyz_from_order();
  invoice();
}

sub yes {
  call_sub($main::form->{yes_nextsub});
}

sub no {
  call_sub($main::form->{no_nextsub});
}

######################################################################################################
# IO ENTKOPPLUNG
# ###############################################################################################
sub display_form {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  check_oe_access();

  retrieve_partunits() if ($form->{type} =~ /_delivery_order$/);

  $form->{"taxaccounts"} =~ s/\s*$//;
  $form->{"taxaccounts"} =~ s/^\s*//;
  foreach my $accno (split(/\s*/, $form->{"taxaccounts"})) {
    map({ delete($form->{"${accno}_${_}"}); } qw(rate description taxnumber));
  }
  $form->{"taxaccounts"} = "";

  IC->retrieve_accounts(\%myconfig, $form, map { $_ => $form->{"id_$_"} } 1 .. $form->{rowcount});

  $form->{rowcount}++;
  $form->{"project_id_$form->{rowcount}"} = $form->{globalproject_id};

  $form->language_payment(\%myconfig);

  Common::webdav_folder($form);

  &form_header;

  # create rows
  display_row($form->{rowcount}) if $form->{rowcount};

  &form_footer;

  $main::lxdebug->leave_sub();
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
    my $edit_url = ($::instance_conf->get_feature_experimental_order)
                 ? build_std_url('script=controller.pl', 'action=Order/edit', 'callback=' . E($callback))
                 : build_std_url('script=oe.pl', 'action=edit', 'callback=' . E($callback));

    $content     = $form->parse_html_template('oe/report_for_todo_list', { 'QUOTATIONS' => $quotations,
                                                                           'edit_url'   => $edit_url,
                                                                           'callback'   => $callback });
  }

  $main::lxdebug->leave_sub();

  return $content;
}

sub edit_periodic_invoices_config {
  $::lxdebug->enter_sub();

  $::form->{type} = 'sales_order';

  check_oe_access();

  my $config;
  $config = SL::YAML::Load($::form->{periodic_invoices_config}) if $::form->{periodic_invoices_config};

  if ('HASH' ne ref $config) {
    $config =  { periodicity             => 'm',
                 order_value_periodicity => 'p', # = same as periodicity
                 start_date_as_date      => $::form->{transdate} || $::form->current_date,
                 extend_automatically_by => 12,
                 active                  => 1,
               };
  }
  # for older configs, replace email preset text if not yet set.
  $config->{email_subject} ||= GenericTranslations->get(language_id => $::form->{lanuage_id}, translation_type => "preset_text_periodic_invoices_email_subject");
  $config->{email_body}    ||= GenericTranslations->get(language_id => $::form->{lanuage_id}, translation_type => "salutation_general")
                             . GenericTranslations->get(language_id => $::form->{lanuage_id}, translation_type => "salutation_punctuation_mark")
                             . "\n\n"
                             . GenericTranslations->get(language_id => $::form->{lanuage_id}, translation_type => "preset_text_periodic_invoices_email_body");
  $config->{email_body}      =~ s{\A[ \n\r]+|[ \n\r]+\Z}{}g;

  $config->{periodicity}             = 'm' if none { $_ eq $config->{periodicity}             }       @SL::DB::PeriodicInvoicesConfig::PERIODICITIES;
  $config->{order_value_periodicity} = 'p' if none { $_ eq $config->{order_value_periodicity} } ('p', @SL::DB::PeriodicInvoicesConfig::ORDER_VALUE_PERIODICITIES);

  $::form->get_lists(printers => "ALL_PRINTERS",
                     charts   => { key       => 'ALL_CHARTS',
                                   transdate => 'current_date' });

  $::form->{AR}    = [ grep { $_->{link} =~ m/(?:^|:)AR(?::|$)/ } @{ $::form->{ALL_CHARTS} } ];
  $::form->{title} = $::locale->text('Edit the configuration for periodic invoices');

  if ($::form->{customer_id}) {
    $::form->{ALL_CONTACTS} = SL::DB::Manager::Contact->get_all_sorted(where => [ cp_cv_id => $::form->{customer_id} ]);
    $::form->{email_recipient_invoice_address} = SL::DB::Manager::Customer->find_by(id => $::form->{customer_id})->invoice_mail;
  }

  $::form->header(no_layout => 1);
  print $::form->parse_html_template('oe/edit_periodic_invoices_config', {config => $config});

  $::lxdebug->leave_sub();
}

sub save_periodic_invoices_config {
  $::lxdebug->enter_sub();

  $::form->{type} = 'sales_order';

  check_oe_access();

  $::form->isblank('start_date_as_date', $::locale->text('The start date is missing.'));

  my $config = { active                  => $::form->{active}     ? 1 : 0,
                 terminated              => $::form->{terminated} ? 1 : 0,
                 direct_debit            => $::form->{direct_debit} ? 1 : 0,
                 periodicity             => (any { $_ eq $::form->{periodicity}             }       @SL::DB::PeriodicInvoicesConfig::PERIODICITIES)              ? $::form->{periodicity}             : 'm',
                 order_value_periodicity => (any { $_ eq $::form->{order_value_periodicity} } ('p', @SL::DB::PeriodicInvoicesConfig::ORDER_VALUE_PERIODICITIES)) ? $::form->{order_value_periodicity} : 'p',
                 start_date_as_date      => $::form->{start_date_as_date},
                 end_date_as_date        => $::form->{end_date_as_date},
                 first_billing_date_as_date => $::form->{first_billing_date_as_date},
                 print                   => $::form->{print} ? 1 : 0,
                 printer_id              => $::form->{print} ? $::form->{printer_id} * 1 : undef,
                 copies                  => $::form->{copies} * 1 ? $::form->{copies} : 1,
                 extend_automatically_by => $::form->{extend_automatically_by} * 1 || undef,
                 ar_chart_id             => $::form->{ar_chart_id} * 1,
                 send_email                 => $::form->{send_email} ? 1 : 0,
                 email_recipient_contact_id => $::form->{email_recipient_contact_id} * 1 || undef,
                 email_recipient_address    => $::form->{email_recipient_address},
                 email_sender               => $::form->{email_sender},
                 email_subject              => $::form->{email_subject},
                 email_body                 => $::form->{email_body},
               };

  $::form->{periodic_invoices_config} = SL::YAML::Dump($config);

  $::form->{title} = $::locale->text('Edit the configuration for periodic invoices');
  $::form->header;
  print $::form->parse_html_template('oe/save_periodic_invoices_config', $config);

  $::lxdebug->leave_sub();
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

sub dispatcher {
  foreach my $action (qw(delete delivery_order invoice print purchase_order quotation
                         request_for_quotation sales_order save save_and_close save_as_new ship_to update)) {
    if ($::form->{"action_${action}"}) {
      call_sub($action);
      return;
    }
  }

  $::form->error($::locale->text('No action defined.'));
}
