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
# Delivery orders
#======================================================================

use Carp;
use List::MoreUtils qw(uniq);
use List::Util qw(max sum);
use POSIX qw(strftime);

use SL::Controller::DeliveryOrder;
use SL::DB::DeliveryOrder;
use SL::DB::DeliveryOrderItem;
use SL::DB::DeliveryOrder::TypeData qw(:types validate_type);
use SL::DB::ValidityToken;
use SL::Helper::UserPreferences::DisplayPreferences;
use SL::DO;
use SL::IR;
use SL::IS;
use SL::MoreCommon qw(ary_diff restore_form save_form);
use SL::Presenter::ItemsList;
use SL::ReportGenerator;
use SL::WH;
use SL::YAML;
use Sort::Naturally ();
require "bin/mozilla/common.pl";
require "bin/mozilla/io.pl";
require "bin/mozilla/reportgenerator.pl";

use SL::Helper::Flash qw(flash flash_later render_flash);

use strict;

1;

# end of main

sub check_do_access_for_edit {
  validate_type($::form->{type});

  my $right = SL::DB::DeliveryOrder::TypeData::get3($::form->{type}, "rights", "edit");
  $main::auth->assert($right);
}

sub check_do_access {
  validate_type($::form->{type});

  my $right = SL::DB::DeliveryOrder::TypeData::get3($::form->{type}, "rights", "view");
  $main::auth->assert($right);
}

sub set_headings {
  $main::lxdebug->enter_sub();

  check_do_access();

  my ($action) = @_;

  my $form     = $main::form;
  my $locale   = $main::locale;

  if ($form->{type} eq 'purchase_delivery_order') {
    $form->{vc}    = 'vendor';
    $form->{title} = $action eq "edit" ? $locale->text('Edit Purchase Delivery Order') : $locale->text('Add Purchase Delivery Order');
  } else {
    $form->{vc}    = 'customer';
    $form->{title} = $action eq "edit" ? $locale->text('Edit Sales Delivery Order') : $locale->text('Add Sales Delivery Order');
  }

  $form->{heading} = $locale->text('Delivery Order');

  $main::lxdebug->leave_sub();
}

sub add {
  $main::lxdebug->enter_sub();

  check_do_access_for_edit();

  if (($::form->{type} =~ /purchase/) && !$::instance_conf->get_allow_new_purchase_invoice) {
    $::form->show_generic_error($::locale->text("You do not have the permissions to access this function."));
  }

  my $form     = $main::form;

  set_headings("add");

  $form->{show_details} = $::myconfig{show_form_details};
  $form->{callback} = build_std_url('action=add', 'type', 'vc') unless ($form->{callback});

  if (!$form->{form_validity_token}) {
    $form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_DELIVERY_ORDER_SAVE())->token;
  }

  order_links(is_new => 1);
  prepare_order();
  display_form();

  $main::lxdebug->leave_sub();
}

sub add_from_reclamation {

  require SL::DB::Reclamation;
  my $reclamation = SL::DB::Reclamation->new(id => $::form->{from_id})->load;
  my ($delivery_order, $error) = $reclamation->convert_to_delivery_order();
  if($error) {
    croak("Error while converting: " . $error);
  }

  # edit new saved delivery order
  $::form->{id} = $delivery_order->id;
  edit();
}

sub edit {
  $main::lxdebug->enter_sub();

  check_do_access();

  my $form     = $main::form;

  $form->{show_details} = $::myconfig{show_form_details};

  # show history button
  $form->{javascript} = qq|<script type="text/javascript" src="js/show_history.js"></script>|;
  #/show hhistory button

  $form->{simple_save} = 0;

  set_headings("edit");

  # editing without stuff to edit? try adding it first
  if ($form->{rowcount} && !$form->{print_and_save}) {
#     map { $id++ if $form->{"multi_id_$_"} } (1 .. $form->{rowcount});
#     if (!$id) {

      # reset rowcount
      undef $form->{rowcount};
      add();
      $main::lxdebug->leave_sub();
      return;
#     }
  } elsif (!$form->{id}) {
    add();
    $main::lxdebug->leave_sub();
    return;
  }

  my ($language_id, $printer_id);
  if ($form->{print_and_save}) {
    $form->{action}   = "dispatcher";
    $form->{action_print} = "1";
    $form->{resubmit} = 1;
    $language_id      = $form->{language_id};
    $printer_id       = $form->{printer_id};
  }

  set_headings("edit");

  order_links();
  prepare_order();

  if ($form->{print_and_save}) {
    $form->{language_id} = $language_id;
    $form->{printer_id}  = $printer_id;
  }

  display_form();

  $main::lxdebug->leave_sub();
}

sub order_links {
  $main::lxdebug->enter_sub();

  check_do_access();

  my %params   = @_;
  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  # retrieve order/quotation
  my $editing = $form->{id};

  DO->retrieve('vc'  => $form->{vc},
               'ids' => $form->{id});

  $form->backup_vars(qw(payment_id language_id taxzone_id salesman_id taxincluded cp_id intnotes delivery_term_id currency));

  # get customer / vendor
  if ($form->{vc} eq 'vendor') {
    IR->get_vendor(\%myconfig, \%$form);
    $form->{discount} = $form->{vendor_discount};
  } else {
    IS->get_customer(\%myconfig, \%$form);
    $form->{discount} = $form->{customer_discount};
    $form->{billing_address_id} = $form->{default_billing_address_id} if $params{is_new};
  }

  $form->restore_vars(qw(payment_id language_id taxzone_id intnotes cp_id delivery_term_id));
  $form->restore_vars(qw(currency)) if ($form->{id} || $form->{convert_from_oe_ids});
  $form->restore_vars(qw(taxincluded)) if $form->{id};
  $form->restore_vars(qw(salesman_id)) if $editing;

  $main::lxdebug->leave_sub();
}

sub prepare_order {
  $main::lxdebug->enter_sub();

  check_do_access();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $form->{formname} = $form->{type} unless $form->{formname};

  my $i = 0;
  foreach my $ref (@{ $form->{form_details} }) {
    $form->{rowcount} = ++$i;

    map { $form->{"${_}_$i"} = $ref->{$_} } keys %{$ref};
  }
  for my $i (1 .. $form->{rowcount}) {
    if ($form->{id}) {
      $form->{"discount_$i"} = $form->format_amount(\%myconfig, $form->{"discount_$i"} * 100);
    } else {
      $form->{"discount_$i"} = $form->format_amount(\%myconfig, $form->{"discount_$i"});
    }
    my ($dec) = ($form->{"sellprice_$i"} =~ /\.(\d+)/);
    $dec           = length $dec;
    my $decimalplaces = ($dec > 2) ? $dec : 2;

    # copy reqdate from deliverydate for invoice -> order conversion
    $form->{"reqdate_$i"} = $form->{"deliverydate_$i"} unless $form->{"reqdate_$i"};

    $form->{"sellprice_$i"} = $form->format_amount(\%myconfig, $form->{"sellprice_$i"}, $decimalplaces);
    $form->{"lastcost_$i"} = $form->format_amount(\%myconfig, $form->{"lastcost_$i"}, $decimalplaces);

    (my $dec_qty) = ($form->{"qty_$i"} =~ /\.(\d+)/);
    $dec_qty = length $dec_qty;
    $form->{"qty_$i"} = $form->format_amount(\%myconfig, $form->{"qty_$i"}, $dec_qty);
  }

  $main::lxdebug->leave_sub();
}

sub setup_do_action_bar {
  my @transfer_qty   = qw(kivi.SalesPurchase.delivery_order_check_transfer_qty);
  my @req_trans_desc = qw(kivi.SalesPurchase.check_transaction_description) x!!$::instance_conf->get_require_transaction_description_ps;
  my $is_customer    = $::form->{vc} eq 'customer';

  my $undo_date  = DateTime->today->subtract(days => $::instance_conf->get_undo_transfer_interval);
  my $insertdate = DateTime->from_kivitendo($::form->{insertdate});
  my $undo_transfer  = 0;
  if (ref $undo_date eq 'DateTime' && ref $insertdate eq 'DateTime') {
    $undo_transfer = $insertdate > $undo_date;
  }

  my $may_edit_create = $::auth->assert(SL::DB::DeliveryOrder::TypeData::get3($::form->{type}, "rights", "edit"), 1);

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action =>
        [ t8('Update'),
          submit    => [ '#form', { action => "update" } ],
          disabled  => !$may_edit_create ? t8('You do not have the permissions to access this function.') : undef,
          id        => 'update_button',
          accesskey => 'enter',
        ],

      combobox => [
        action => [
          t8('Save'),
          submit   => [ '#form', { action => "save" } ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create    ? t8('You do not have the permissions to access this function.')
                    : $::form->{delivered} ? t8('This record has already been delivered.')
                    :                        undef,
        ],
        action => [
          t8('Save as new'),
          submit   => [ '#form', { action => "save_as_new" } ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create ? t8('You do not have the permissions to access this function.')
                    : !$::form->{id},
        ],
        action => [
          t8('Mark as closed'),
          submit   => [ '#form', { action => "mark_closed" } ],
          checks   => [ 'kivi.validate_form' ],
          confirm  => t8('This will remove the delivery order from showing as open even if contents are not delivered. Proceed?'),
          disabled => !$may_edit_create ? t8('You do not have the permissions to access this function.')
                    : !$::form->{id}    ? t8('This record has not been saved yet.')
                    : $::form->{closed} ? t8('This record has already been closed.')
                    :                     undef,
        ],
      ], # end of combobox "Save"

      action => [
        t8('Delete'),
        submit   => [ '#form', { action => "delete" } ],
        confirm  => t8('Do you really want to delete this object?'),
        disabled => !$may_edit_create                                                                           ? t8('You do not have the permissions to access this function.')
                  : !$::form->{id}                                                                              ? t8('This record has not been saved yet.')
                  : $::form->{delivered}                                                                        ? t8('This record has already been delivered.')
                  : ($::form->{vc} eq 'customer' && !$::instance_conf->get_sales_delivery_order_show_delete)    ? t8('Deleting this type of record has been disabled in the configuration.')
                  : ($::form->{vc} eq 'vendor'   && !$::instance_conf->get_purchase_delivery_order_show_delete) ? t8('Deleting this type of record has been disabled in the configuration.')
                  :                                                                                               undef,
      ],

      combobox => [
        action => [
          t8('Transfer out'),
          submit   => [ '#form', { action => "transfer_out" } ],
          checks   => [ 'kivi.validate_form', @transfer_qty ],
          disabled => !$may_edit_create    ? t8('You do not have the permissions to access this function.')
                    : $::form->{delivered} ? t8('This record has already been delivered.')
                    :                        undef,
          only_if  => $is_customer,
        ],
        action => [
          t8('Transfer out via default'),
          submit   => [ '#form', { action => "transfer_out_default" } ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create    ? t8('You do not have the permissions to access this function.')
                    : $::form->{delivered} ? t8('This record has already been delivered.')
                    :                        undef,
          only_if  => $is_customer && $::instance_conf->get_transfer_default,
        ],
        action => [
          t8('Transfer in'),
          submit   => [ '#form', { action => "transfer_in" } ],
          checks   => [ 'kivi.validate_form', @transfer_qty ],
          disabled => !$may_edit_create    ? t8('You do not have the permissions to access this function.')
                    : $::form->{delivered} ? t8('This record has already been delivered.')
                    :                        undef,
          only_if  => !$is_customer,
        ],
        action => [
          t8('Transfer in via default'),
          submit   => [ '#form', { action => "transfer_in_default" } ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create    ? t8('You do not have the permissions to access this function.')
                    : $::form->{delivered} ? t8('This record has already been delivered.')
                    :                        undef,
          only_if  => !$is_customer && $::instance_conf->get_transfer_default,
        ],
        action => [
          t8('Undo Transfer'),
          submit   => [ '#form', { action => "delete_transfers" } ],
          checks   => [ 'kivi.validate_form' ],
          only_if  => $::form->{delivered},
          disabled => !$may_edit_create ? t8('You do not have the permissions to access this function.')
                    : !$undo_transfer   ? t8('Transfer date exceeds the maximum allowed interval.')
                    :                     undef,
        ],
      ], # end of combobox "Transfer out"


      'separator',

      combobox => [
        action => [ t8('Workflow') ],
        action => [
          t8('Invoice'),
          submit => [ '#form', { action => "invoice" } ],
          disabled => !$::form->{id} ? t8('This record has not been saved yet.') : undef,
          confirm  => $::form->{delivered}                                                                         ? undef
                    : ($::form->{vc} eq 'customer' && $::instance_conf->get_sales_delivery_order_check_stocked)    ? t8('This record has not been stocked out. Proceed?')
                    : ($::form->{vc} eq 'vendor'   && $::instance_conf->get_purchase_delivery_order_check_stocked) ? t8('This record has not been stocked in. Proceed?')
                    :                                                                                                undef,
        ],
        action => [
          t8('Save and Reclamation'),
          submit => [ '#form', { action => "save_and_reclamation" } ],
          disabled => !$::form->{id} ? t8('This record has not been saved yet.') : undef,
        ],
      ],

      combobox => [
        action => [ t8('Export') ],
        action => [
          t8('Print'),
          call     => [ 'kivi.SalesPurchase.show_print_dialog' ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create ? t8('You do not have the permissions to access this function.') : undef,
        ],
        action => [
          t8('E Mail'),
          call   => [ 'kivi.SalesPurchase.show_email_dialog' ],
          checks => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create ? t8('You do not have the permissions to access this function.')
                    : !$::form->{id} ?    t8('This record has not been saved yet.')
                    :                     undef,
        ],
      ], # end of combobox "Export"

      combobox =>  [
        action => [ t8('more') ],
        action => [
          t8('History'),
          call     => [ 'set_history_window', $::form->{id} * 1, 'id' ],
          disabled => !$::form->{id} ? t8('This record has not been saved yet.') : undef,
        ],
        action => [
          t8('Follow-Up'),
          call     => [ 'follow_up_window' ],
          disabled => !$::form->{id} ? t8('This record has not been saved yet.') : undef,
        ],
      ], # end if combobox "more"
    );
  }
  $::request->layout->add_javascripts('kivi.Validator.js');
}

sub setup_do_search_action_bar {
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

sub setup_do_orders_action_bar {
  my %params = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('New invoice'),
        submit    => [ '#form', { action => 'invoice_multi' } ],
        checks    => [ [ 'kivi.check_if_entries_selected', '#form tbody input[type=checkbox]' ] ],
        accesskey => 'enter',
      ],
      action => [
        t8('Print'),
        call   => [ 'kivi.SalesPurchase.show_print_dialog', 'js:kivi.MassDeliveryOrderPrint.submitMultiOrders' ],
        checks => [ [ 'kivi.check_if_entries_selected', '#form tbody input[type=checkbox]' ] ],
      ],
    );
  }
}

sub form_header {
  $main::lxdebug->enter_sub();

  check_do_access();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  my $class       = "SL::DB::" . ($form->{vc} eq 'customer' ? 'Customer' : 'Vendor');
  $form->{VC_OBJ} = $class->load_cached($form->{ $form->{vc} . '_id' });

  $form->{CONTACT_OBJ}   = $form->{cp_id} ? SL::DB::Contact->load_cached($form->{cp_id}) : undef;
  my $current_employee   = SL::DB::Manager::Employee->current;
  $form->{employee_id}   = $form->{old_employee_id} if $form->{old_employee_id};
  $form->{salesman_id}   = $form->{old_salesman_id} if $form->{old_salesman_id};
  $form->{employee_id} ||= $current_employee->id;
  $form->{salesman_id} ||= $current_employee->id;

  my $vc = $form->{vc} eq "customer" ? "customers" : "vendors";
  $form->get_lists("price_factors"  => "ALL_PRICE_FACTORS",
                   "business_types" => "ALL_BUSINESS_TYPES",
    );
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

  $::form->{ALL_PROJECTS}          = SL::DB::Manager::Project->get_all_sorted(query => \@conditions);
  $::form->{ALL_DELIVERY_TERMS}    = SL::DB::Manager::DeliveryTerm->get_valid($::form->{delivery_term_id});
  $::form->{ALL_EMPLOYEES}         = SL::DB::Manager::Employee->get_all_sorted(query => [ or => [ id => $::form->{employee_id},  deleted => 0 ] ]);
  $::form->{ALL_SALESMEN}          = SL::DB::Manager::Employee->get_all_sorted(query => [ or => [ id => $::form->{salesman_id},  deleted => 0 ] ]);
  $::form->{ALL_SHIPTO}            = SL::DB::Manager::Shipto->get_all_sorted(query => [
    or => [ and => [ trans_id  => $::form->{"$::form->{vc}_id"} * 1, module => 'CT' ], and => [ shipto_id => $::form->{shipto_id} * 1, trans_id => undef ] ]
  ]);
  $::form->{ALL_CONTACTS}          = SL::DB::Manager::Contact->get_all_sorted(query => [
    or => [
      cp_cv_id => $::form->{"$::form->{vc}_id"} * 1,
      and      => [
        cp_cv_id => undef,
        cp_id    => $::form->{cp_id} * 1
      ]
    ]
  ]);

  my $dispatch_to_popup = '';
  if ($form->{resubmit} && ($form->{format} eq "html")) {
    $dispatch_to_popup  = "window.open('about:blank','Beleg'); document.do.target = 'Beleg';";
    $dispatch_to_popup .= "document.do.submit();";
  } elsif ($form->{resubmit} && $form->{action_print}) {
    # emulate click for resubmitting actions
    $dispatch_to_popup  = "kivi.SalesPurchase.show_print_dialog(); kivi.SalesPurchase.print_record();";
  }
  $::request->{layout}->add_javascripts_inline("\$(function(){$dispatch_to_popup});");


  $form->{follow_up_trans_info} = $form->{donumber} .'('. $form->{VC_OBJ}->name .')' if $form->{VC_OBJ};
  $form->{longdescription_dialog_size_percentage} = SL::Helper::UserPreferences::DisplayPreferences->new()->get_longdescription_dialog_size_percentage();

  $::request->{layout}->use_javascript(map { "${_}.js" } qw(kivi.File kivi.MassDeliveryOrderPrint kivi.SalesPurchase kivi.Part kivi.CustomerVendor kivi.Validator ckeditor5/ckeditor ckeditor5/translations/de kivi.io));

  setup_do_action_bar();

  $form->header();
  # Fix für Bug 1082 Erwartet wird: 'abteilungsNAME--abteilungsID'
  # und Erweiterung für Bug 1760:
  # Das war leider nur ein Teil-Fix, da das Verhalten den 'Erneuern'-Knopf
  # nicht überlebt. Konsequent jetzt auf L umgestellt
  #   $ perldoc SL::Template::Plugin::L
  # Daher entsprechend nur die Anpassung in form_header
  # und in DO.pm gemacht. 4 Testfälle:
  # department_id speichern                 | i.O.
  # department_id lesen                     | i.O.
  # department leer überlebt erneuern       | i.O.
  # department nicht leer überlebt erneuern | i.O.
  # $main::lxdebug->message(0, 'ABTEILUNGS ID in form?' . $form->{department_id});
  print $form->parse_html_template('do/form_header');

  $main::lxdebug->leave_sub();
}

sub form_footer {
  $main::lxdebug->enter_sub();

  check_do_access();

  my $form     = $main::form;

  $form->{PRINT_OPTIONS}      = setup_sales_purchase_print_options();

  my $shipto_cvars       = SL::DB::Shipto->new->cvars_by_config;
  foreach my $var (@{ $shipto_cvars }) {
    my $name = "shiptocvar_" . $var->config->name;
    $var->value($form->{$name}) if exists $form->{$name};
  }

  print $form->parse_html_template('do/form_footer',
    {transfer_default => ($::instance_conf->get_transfer_default),
     shipto_cvars     => $shipto_cvars});

  $main::lxdebug->leave_sub();
}

sub update_delivery_order {
  $main::lxdebug->enter_sub();

  check_do_access();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  set_headings($form->{"id"} ? "edit" : "add");

  $form->{insertdate} = SL::DB::DeliveryOrder->new(id => $form->{id})->load->itime_as_date if $form->{id};

  $form->{update} = 1;

  my $payment_id;
  $payment_id = $form->{payment_id} if $form->{payment_id};

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

  $form->{discount} =  $form->{"$form->{vc}_discount"} if defined $form->{"$form->{vc}_discount"};
  # Problem: Wenn man ohne Erneuern einen Kunden/Lieferanten
  # wechselt, wird der entsprechende Kunden/ Lieferantenrabatt
  # nicht übernommen. Grundproblem: In Commit 82574e78
  # hab ich aus discount customer_discount und vendor_discount
  # gemacht und entsprechend an den Oberflächen richtig hin-
  # geschoben. Die damals bessere Lösung wäre gewesen:
  # In den Templates nur die hidden für form-discount wieder ein-
  # setzen dann wäre die Verrenkung jetzt nicht notwendig.
  # TODO: Ggf. Bugfix 1284, 1575 und 817 wieder zusammenführen
  # Testfälle: Kunden mit Rabatt 0 -> Rabatt 20 i.O.
  #            Kunde mit Rabatt 20 -> Rabatt 0  i.O.
  #            Kunde mit Rabatt 20 -> Rabatt 5,5 i.O.
  $form->{payment_id} = $payment_id if $form->{payment_id} eq "";

  my $i = $form->{rowcount};

  if (   ($form->{"partnumber_$i"} eq "")
      && ($form->{"description_$i"} eq "")
      && ($form->{"partsgroup_$i"}  eq "")) {

    check_form();

  } else {

    my $mode;
    if ($form->{type} eq 'purchase_delivery_order') {
      IR->retrieve_item(\%myconfig, $form);
      $mode = 'IR';
    } else {
      IS->retrieve_item(\%myconfig, $form);
      $mode = 'IS';
    }

    my $rows = scalar @{ $form->{item_list} };

    if ($rows) {
      $form->{"qty_$i"} = $form->parse_amount(\%myconfig, $form->{"qty_$i"});
      if( !$form->{"qty_$i"} ) {
        $form->{"qty_$i"} = 1;
      }

      if ($rows > 1) {

        select_item(mode => $mode, pre_entered_qty => $form->{"qty_$i"});
        $::dispatcher->end_request;

      } else {

        my $sellprice = $form->parse_amount(\%myconfig, $form->{"sellprice_$i"});

        map { $form->{"${_}_$i"} = $form->{item_list}[0]{$_} } keys %{ $form->{item_list}[0] };

        $form->{"marge_price_factor_$i"} = $form->{item_list}->[0]->{price_factor};

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
        }

        $form->{"sellprice_$i"}          = $form->format_amount(\%myconfig, $form->{"sellprice_$i"});
        $form->{"lastcost_$i"}           = $form->format_amount(\%myconfig, $form->{"lastcost_$i"});
        $form->{"qty_$i"}                = $form->format_amount(\%myconfig, $form->{"qty_$i"});
        $form->{"discount_$i"}           = $form->format_amount(\%myconfig, $form->{"discount_$i"} * 100.0);
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
        $form->{"not_discountable_$i"} = "";
        display_form();

      } else {
        $form->{"id_$i"}   = 0;
        new_item();
      }
    }
  }

  $main::lxdebug->leave_sub();
}

sub search {
  $main::lxdebug->enter_sub();

  check_do_access();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $form->{vc} = $form->{type} eq 'purchase_delivery_order' ? 'vendor' : 'customer';

  $form->get_lists("projects"       => { "key" => "ALL_PROJECTS",
                                         "all" => 1 },
                   "business_types" => "ALL_BUSINESS_TYPES");
  $form->{ALL_EMPLOYEES} = SL::DB::Manager::Employee->get_all_sorted(query => [ deleted => 0 ]);
  $form->{ALL_DEPARTMENTS} = SL::DB::Manager::Department->get_all_sorted;
  $form->{title}             = $locale->text('Delivery Orders');

  setup_do_search_action_bar();

  $form->header();

  print $form->parse_html_template('do/search');

  $main::lxdebug->leave_sub();
}

sub orders {
  $main::lxdebug->enter_sub();

  check_do_access();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;
  my $cgi      = $::request->{cgi};

  $::request->{layout}->use_javascript(map { "${_}.js" } qw(kivi.MassDeliveryOrderPrint kivi.SalesPurchase));
  ($form->{ $form->{vc} }, $form->{"$form->{vc}_id"}) = split(/--/, $form->{ $form->{vc} });

  report_generator_set_default_sort('transdate', 1);

  DO->transactions();

  $form->{rowcount} = scalar @{ $form->{DO} };

  my @columns = qw(
    ids                     transdate               reqdate
    id                      donumber
    ordnumber               order_confirmation_number
    customernumber          vendor_confirmation_number
    cusordnumber
    name                    employee  salesman
    shipvia                 globalprojectnumber
    transaction_description department
    open                    delivered
    insertdate              items
  );

  $form->{l_open}      = $form->{l_closed} = "Y" if ($form->{open}      && $form->{closed});
  $form->{l_delivered} = "Y"                     if ($form->{delivered} && $form->{notdelivered});

  $form->{title}       = $locale->text('Delivery Orders');

  my $attachment_basename = SL::DB::DeliveryOrder::TypeData::get3($form->{type}, "text", "attachment");

  my $report = SL::ReportGenerator->new(\%myconfig, $form);

  my @hidden_variables = map { "l_${_}" } @columns;
  push @hidden_variables, $form->{vc}, qw(l_closed l_notdelivered open closed delivered notdelivered donumber ordnumber serialnumber cusordnumber
                                          transaction_description transdatefrom transdateto reqdatefrom reqdateto
                                          type vc employee_id salesman_id project_id parts_partnumber parts_description
                                          insertdatefrom insertdateto business_id all department_id chargenumber full_text
                                          vendor_confirmation_number order_confirmation_number ids top_info_text);

  my $href = build_std_url('action=orders', grep { $form->{$_} } @hidden_variables);

  my %column_defs = (
    'ids'                     => { raw_header_data => SL::Presenter::Tag::checkbox_tag("", id => "multi_all", checkall => "[data-checkall=1]"), align => 'center' },
    'transdate'               => { 'text' => $locale->text('Delivery Order Date'), },
    'reqdate'                 => { 'text' => $locale->text('Reqdate'), },
    'id'                      => { 'text' => $locale->text('ID'), },
    'donumber'                => { 'text' => $locale->text('Delivery Order'), },
    'ordnumber'               => { 'text' => $locale->text('Order'), },
    'customernumber'          => { 'text' => $locale->text('Customer Number'), },
    'cusordnumber'            => { 'text' => $locale->text('Customer Order Number'), },
    'name'                    => { 'text' => $form->{vc} eq 'customer' ? $locale->text('Customer') : $locale->text('Vendor'), },
    'employee'                => { 'text' => $locale->text('Employee'), },
    'salesman'                => { 'text' => $locale->text('Salesman'), },
    'shipvia'                 => { 'text' => $locale->text('Ship via'), },
    'globalprojectnumber'     => { 'text' => $locale->text('Project Number'), },
    'transaction_description' => { 'text' => $locale->text('Transaction description'), },
    'open'                    => { 'text' => $locale->text('Open'), },
    'delivered'               => { 'text' => $locale->text('Delivered'), },
    'department'              => { 'text' => $locale->text('Department'), },
    'insertdate'              => { 'text' => $locale->text('Insert Date'), },
    'items'                   => { 'text' => $locale->text('Positions'), },
    'vendor_confirmation_number' => { 'text' => $locale->text('Vendor Confirmation Number'), },
    'order_confirmation_number'  => { 'text' => $locale->text('Order Confirmation Number'), },
  );

  foreach my $name (qw(id transdate reqdate donumber ordnumber name employee salesman shipvia transaction_description department insertdate vendor_confirmation_number)) {
    my $sortdir                 = $form->{sort} eq $name ? 1 - $form->{sortdir} : $form->{sortdir};
    $column_defs{$name}->{link} = $href . "&sort=$name&sortdir=$sortdir";
  }

  $form->{"l_type"} = "Y";
  map { $column_defs{$_}->{visible} = $form->{"l_${_}"} ? 1 : 0 } @columns;

  $column_defs{ids}->{visible} = 'HTML';

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);

  $report->set_export_options('orders', @hidden_variables, qw(sort sortdir));

  $report->set_sort_indicator($form->{sort}, $form->{sortdir});

  my @options;
  if ($form->{customer}) {
    push @options, $locale->text('Customer') . " : $form->{customer}";
  }
  if ($form->{vendor}) {
    push @options, $locale->text('Vendor') . " : $form->{vendor}";
  }
  if ($form->{cp_name}) {
    push @options, $locale->text('Contact Person') . " : $form->{cp_name}";
  }
  if ($form->{department_id}) {
    push @options, $locale->text('Department') . " : " . SL::DB::Department->new(id => $form->{department_id})->load->description;
  }
  if ($form->{donumber}) {
    push @options, $locale->text('Delivery Order Number') . " : $form->{donumber}";
  }
  if ($form->{ordnumber}) {
    push @options, $locale->text('Order Number') . " : $form->{ordnumber}";
  }
  if ($form->{order_confirmation_number}) {
    push @options, $locale->text('Order Confirmation Number') . " : $form->{order_confirmation_number}";
  }
  if ($form->{vendor_confirmation_number}) {
    push @options, $locale->text('Vendor Confirmation Number') . " : $form->{vendor_confirmation_number}";
  }
  push @options, $locale->text('Serial Number') . " : $form->{serialnumber}" if $form->{serialnumber};
  if ($form->{business_id}) {
    my $vc_type_label = $form->{vc} eq 'customer' ? $locale->text('Customer type') : $locale->text('Vendor type');
    push @options, $vc_type_label . " : " . SL::DB::Business->new(id => $form->{business_id})->load->description;
  }
  if ($form->{transaction_description}) {
    push @options, $locale->text('Transaction description') . " : $form->{transaction_description}";
  }
  if ($form->{fulltext}) {
    push @options, $locale->text('Full Text') . " : $form->{fulltext}";
  }
  if ($form->{parts_description}) {
    push @options, $locale->text('Part Description') . " : $form->{parts_description}";
  }
  if ($form->{parts_partnumber}) {
    push @options, $locale->text('Part Number') . " : $form->{parts_partnumber}";
  }
  if ($form->{chargenumber}) {
    push @options, $locale->text('Charge Number') . " : $form->{chargenumber}";
  }
  if ( $form->{transdatefrom} or $form->{transdateto} ) {
    push @options, $locale->text('Delivery Order Date');
    push @options, $locale->text('From') . " " . $locale->date(\%myconfig, $form->{transdatefrom}, 1)     if $form->{transdatefrom};
    push @options, $locale->text('Bis')  . " " . $locale->date(\%myconfig, $form->{transdateto},   1)     if $form->{transdateto};
  };
  if ( $form->{reqdatefrom} or $form->{reqdateto} ) {
    push @options, $locale->text('Reqdate');
    push @options, $locale->text('From') . " " . $locale->date(\%myconfig, $form->{reqdatefrom}, 1)       if $form->{reqdatefrom};
    push @options, $locale->text('Bis')  . " " . $locale->date(\%myconfig, $form->{reqdateto},   1)       if $form->{reqdateto};
  };
  if ( $form->{insertdatefrom} or $form->{insertdateto} ) {
    push @options, $locale->text('Insert Date');
    push @options, $locale->text('From') . " " . $locale->date(\%myconfig, $form->{insertdatefrom}, 1)    if $form->{insertdatefrom};
    push @options, $locale->text('Bis')  . " " . $locale->date(\%myconfig, $form->{insertdateto},   1)    if $form->{insertdateto};
  };
  if ($form->{open}) {
    push @options, $locale->text('Open');
  }
  if ($form->{closed}) {
    push @options, $locale->text('Closed');
  }
  if ($form->{delivered}) {
    push @options, $locale->text('Delivered');
  }
  if ($form->{notdelivered}) {
    push @options, $locale->text('Not delivered');
  }
  push @options, $locale->text('Quick Search') . " : $form->{all}" if $form->{all};

  my $pr = SL::DB::Manager::Printer->find_by(
      printer_description => $::locale->text("sales_delivery_order_printer"));
  if ($pr ) {
      $form->{printer_id} = $pr->id;
  }

  my $print_options = SL::Helper::PrintOptions->get_print_options(
    options => {
      hide_language_id => 1,
      show_bothsided   => 1,
      show_headers     => 1,
    },
  );

  $report->set_options('top_info_text'        => $::form->{top_info_text} || join("\n", @options),
                       'raw_top_info_text'    => $form->parse_html_template('do/orders_top'),
                       'raw_bottom_info_text' => $form->parse_html_template('do/orders_bottom', { print_options => $print_options }),
                       'output_format'        => 'HTML',
                       'title'                => $form->{title},
                       'attachment_basename'  => $attachment_basename . strftime('_%Y%m%d', localtime time),
    );
  $report->set_options_from_form();
  $locale->set_numberformat_wo_thousands_separator(\%myconfig) if lc($report->{options}->{output_format}) eq 'csv';

  # add sort and escape callback, this one we use for the add sub
  $form->{callback} = $href .= "&sort=$form->{sort}";

  # hide links to oe if no right
  $form->{hide_oe_links} = !(   ($form->{vc} eq 'customer' && $::auth->assert('sales_order_reports_amounts',    1))
                             || ($form->{vc} eq 'vendor'   && $::auth->assert('purchase_order_reports_amounts', 1)) );

  # escape callback for href
  my $callback = $form->escape($href);

  my $edit_url       = build_std_url('action=edit', 'type', 'vc');
  my $edit_order_url = ($::instance_conf->get_feature_experimental_order)
                     ? build_std_url('script=controller.pl', 'action=Order/edit', 'type=' . ($form->{type} eq 'sales_delivery_order' ? 'sales_order' : 'purchase_order'))
                     : build_std_url('script=oe.pl',         'action=edit',       'type=' . ($form->{type} eq 'sales_delivery_order' ? 'sales_order' : 'purchase_order'));

  my $idx            = 1;

  foreach my $dord (@{ $form->{DO} }) {
    $dord->{open}      = $dord->{closed}    ? $locale->text('No')  : $locale->text('Yes');
    $dord->{delivered} = $dord->{delivered} ? $locale->text('Yes') : $locale->text('No');

    my $row = { map { $_ => { 'data' => $dord->{$_} } } grep {$_ ne 'items' || $_ ne 'order_confirmation_numbers'} @columns };

    my $ord_id = $dord->{id};
    $row->{ids}  = {
      'raw_data' =>   $cgi->hidden('-name' => "trans_id_${idx}", '-value' => $ord_id)
                    . $cgi->checkbox('-name' => "multi_id_${idx}",' id' => "multi_id_id_".$ord_id, '-value' => 1, 'data-checkall' => 1, '-label' => ''),
      'valign'   => 'center',
      'align'    => 'center',
    };
    $row->{donumber}->{link}  = SL::Controller::DeliveryOrder->url_for(action => "edit", id => $dord->{id}, type => $dord->{record_type}, callback => $form->{callback});

    if (!$form->{hide_oe_links}) {
      $row->{ordnumber}->{link} = $edit_order_url . "&id=" . E($dord->{oe_id})   . "&callback=${callback}" if $dord->{oe_id};
    }

    foreach my $order_confirmation (@{ $dord->{order_confirmation_numbers} }) {
      if (lc($report->{options}->{output_format}) eq 'html') {
        $row->{order_confirmation_number}->{raw_data} .= SL::Presenter::Tag::link_tag(build_std_url('script=controller.pl', 'action=Order/edit', 'id=' . $order_confirmation->{id}, 'type=' . 'purchase_order_confirmation'), $order_confirmation->{number} . '<br>');
      } elsif (lc($report->{options}->{output_format}) ne 'html') {
        my $sep = $row->{order_confirmation_number}->{data} ? ' ' : '';
        $row->{order_confirmation_number}->{data}     .= $sep . $order_confirmation->{number};
      }
    }

    if ($form->{l_items}) {
      my $items = SL::DB::Manager::DeliveryOrderItem->get_all_sorted(where => [id => $dord->{item_ids}]);
      $row->{items}->{raw_data}  = SL::Presenter::ItemsList::items_list($items)               if lc($report->{options}->{output_format}) eq 'html';
      $row->{items}->{data}      = SL::Presenter::ItemsList::items_list($items, as_text => 1) if lc($report->{options}->{output_format}) ne 'html';
    }

    $report->add_data($row);

    $idx++;
  }

  setup_do_orders_action_bar();

  $report->generate_with_headers();

  $main::lxdebug->leave_sub();
}

sub save {
  $main::lxdebug->enter_sub();

  my (%params) = @_;

  check_do_access_for_edit();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $form->mtime_ischanged('delivery_orders');

  $form->{defaultcurrency} = $form->get_default_currency(\%myconfig);

  $form->isblank("transdate", $locale->text('Delivery Order Date missing!'));

  $form->{donumber} =~ s/^\s*//g;
  $form->{donumber} =~ s/\s*$//g;

  my $msg = ucfirst $form->{vc};
  $form->isblank($form->{vc} . "_id", $locale->text($msg . " missing!"));

  # $locale->text('Customer missing!');
  # $locale->text('Vendor missing!');

  remove_emptied_rows();
  validate_items();

  # check for serial number if part needs one
  my $missing_serialnr = '';
  for my $i (1 .. $form->{rowcount} - 1) {
    next if !$form->{"has_sernumber_$i"} || $form->{"serialnumber_$i"} ne '';
    $missing_serialnr .= $missing_serialnr ? ", $i" : " $i";
  }
  if ($missing_serialnr ne '') {
    flash('error', $locale->text('Serial Number missing in Row') . $missing_serialnr);
    render_flash();
    &update;
    $::dispatcher->end_request;
    return;
  }

  # if the name changed get new values
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

  if ($form->{saveasnew}) {
    $form->{id}                  = 0;
    $form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_DELIVERY_ORDER_SAVE())->token;
  }

  # we rely on converted_from_orderitems, if the workflow is used
  # be sure that at least one position is linked to the original orderitem
  if ($form->{convert_from_oe_ids}) {
    my $has_linked_pos;
    for my $i (1 .. $form->{rowcount}) {
      if ($form->{"converted_from_orderitems_id_$i"}) {
        $has_linked_pos = 1;
        last;
      }
    }
    if (!$has_linked_pos) {
      $form->error($locale->text('Need at least one original position for the workflow Order to Delivery Order!'));
    }
  }
  DO->save();

  # saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers} = qq|donumber_| . $form->{donumber};
    $form->{addition} = "SAVED";
    $form->save_history;
  }
  # /saving the history

  $form->{simple_save} = 1;
  if (!$params{no_redirect} && !$form->{print_and_save}) {
    delete @{$form}{ary_diff([keys %{ $form }], [qw(login id script type cursor_fokus)])};
    edit();
    $::dispatcher->end_request;
  }
  $main::lxdebug->leave_sub();
}

sub delete {
  $main::lxdebug->enter_sub();

  check_do_access_for_edit();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;
  my $ret;
  if ($ret = DO->delete()) {
    # saving the history
    if(!exists $form->{addition}) {
      $form->{snumbers} = qq|donumber_| . $form->{donumber};
      $form->{addition} = "DELETED";
      $form->save_history;
    }
    # /saving the history

    $form->info($locale->text('Delivery Order deleted!'));
    $::dispatcher->end_request;
  }

  $form->error($locale->text('Cannot delete delivery order!') . $ret);

  $main::lxdebug->leave_sub();
}
sub delete_transfers {
  $main::lxdebug->enter_sub();

  check_do_access_for_edit();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;
  my $ret;

  die "Invalid form type" unless $form->{type} =~ m/^(sales|purchase)_delivery_order$/;

  if ($ret = DO->delete_transfers()) {
    # saving the history
    if(!exists $form->{addition}) {
      $form->{snumbers} = qq|donumber_| . $form->{donumber};
      $form->{addition} = "UNDO TRANSFER";
      $form->save_history;
    }
    # /saving the history

    flash_later('info', $locale->text("Transfer undone."));

    $form->{callback} = 'do.pl?action=edit&type=' . $form->{type} . '&id=' . $form->escape($form->{id});
    $form->redirect;
  }

  $form->error($locale->text('Cannot undo delivery order transfer!') . $ret);

  $main::lxdebug->leave_sub();
}

sub invoice_from_delivery_order_controller {
  $main::lxdebug->enter_sub();
  my $form     = $main::form;

  my $from_id = delete $form->{from_id};
  my $delivery_order = SL::DB::DeliveryOrder->new(id => $from_id)->load;

  $delivery_order->flatten_to_form($form, format_amounts => 1);
  $form->{rowcount}++;

  &invoice;
  $main::lxdebug->leave_sub();
}

sub invoice {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  check_do_access();
  $form->mtime_ischanged('delivery_orders');

  $main::auth->assert($form->{type} eq 'purchase_delivery_order' ? 'vendor_invoice_edit' : 'invoice_edit');

  $form->get_employee();

  $form->{convert_from_do_ids} = $form->{id};
  # if we have a reqdate (Liefertermin), this is definetely the preferred
  # deliverydate for invoices
  $form->{deliverydate}        = $form->{reqdate} || $form->{transdate};
  $form->{transdate}           = $form->{invdate} = $form->current_date(\%myconfig);
  $form->{duedate}             = $form->current_date(\%myconfig, $form->{invdate}, $form->{terms} * 1);
  $form->{defaultcurrency}     = $form->get_default_currency(\%myconfig);

  $form->{rowcount}--;

  delete @{$form}{qw(id closed delivered)};

  my ($script, $buysell);
  if ($form->{type} eq 'purchase_delivery_order') {
    $form->{title}  = $locale->text('Add Vendor Invoice');
    $form->{script} = 'ir.pl';
    $script         = "ir";
    $buysell        = 'sell';
    $form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_PURCHASE_INVOICE_POST())->token;

  } else {
    $form->{title}  = $locale->text('Add Sales Invoice');
    $form->{script} = 'is.pl';
    $script         = "is";
    $buysell        = 'buy';
    $form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_SALES_INVOICE_POST())->token;
  }

  for my $i (1 .. $form->{rowcount}) {
    map { $form->{"${_}_${i}"} = $form->parse_amount(\%myconfig, $form->{"${_}_${i}"}) if $form->{"${_}_${i}"} } qw(ship qty sellprice lastcost basefactor discount);
    # für bug 1284
    # adds a customer/vendor discount, unless we have a workflow case
    # CAVEAT: has to be done, after the above parse_amount
    unless ($form->{"ordnumber"}) {
      if ($form->{discount}) { # Falls wir einen Lieferanten-/Kundenrabatt haben
        # und rabattfähig sind, dann
        unless ($form->{"not_discountable_$i"}) {
          $form->{"discount_$i"} = $form->{discount}*100; # ... nehmen wir diesen Rabatt
        }
      }
    }
    $form->{"donumber_$i"} = $form->{donumber};
    $form->{"converted_from_delivery_order_items_id_$i"} = delete $form->{"delivery_order_items_id_$i"};
  }

  $form->{type} = "invoice";

  # locale messages
  $main::locale = Locale->new("$myconfig{countrycode}", "$script");
  $locale = $main::locale;

  require "bin/mozilla/$form->{script}";

  my $currency = $form->{currency};
  invoice_links();

  if ($form->{ordnumber}) {
    require SL::DB::Order;
    my $vc_id  = $form->{type} =~ /^sales/ ? 'customer_id' : 'vendor_id';
    if (my $order = SL::DB::Manager::Order->find_by(ordnumber => $form->{ordnumber}, $vc_id => $form->{"$vc_id"})) {
      $order->load;
      $form->{orddate} = $order->transdate_as_date;
      $form->{$_}      = $order->$_ for qw(payment_id salesman_id taxzone_id quonumber taxincluded);
      $form->{taxincluded_changed_by_user} = 1;
    }
  }

  $form->{currency}     = $currency;
  $form->{exchangerate} = "";
  $form->{forex}        = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{invdate}, $buysell);
  $form->{exchangerate} = $form->{forex} if ($form->{forex});

  prepare_invoice();

  # format amounts
  for my $i (1 .. $form->{rowcount}) {
    $form->{"discount_$i"} = $form->format_amount(\%myconfig, $form->{"discount_$i"});

    my ($dec) = ($form->{"sellprice_$i"} =~ /\.(\d+)/);
    $dec           = length $dec;
    my $decimalplaces = ($dec > 2) ? $dec : 2;

    # copy delivery date from reqdate for order -> invoice conversion
    $form->{"deliverydate_$i"} = $form->{"reqdate_$i"}
      unless $form->{"deliverydate_$i"};


    $form->{"sellprice_$i"} =
      $form->format_amount(\%myconfig, $form->{"sellprice_$i"},
                           $decimalplaces);

    $form->{"lastcost_$i"} =
      $form->format_amount(\%myconfig, $form->{"lastcost_$i"},
                           $decimalplaces);

    (my $dec_qty) = ($form->{"qty_$i"} =~ /\.(\d+)/);
    $dec_qty = length $dec_qty;
    $form->{"qty_$i"} =
      $form->format_amount(\%myconfig, $form->{"qty_$i"}, $dec_qty);

  }

  display_form();

  $main::lxdebug->leave_sub();
}

sub invoice_multi {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  check_do_access();
  $main::auth->assert($form->{type} eq 'sales_delivery_order' ? 'invoice_edit' : 'vendor_invoice_edit');

  my @do_ids = map { $form->{"trans_id_$_"} } grep { $form->{"multi_id_$_"} } (1..$form->{rowcount});

  if (!scalar @do_ids) {
    $form->show_generic_error($locale->text('You have not selected any delivery order.'));
  }

  map { delete $form->{$_} } grep { m/^(?:trans|multi)_id_\d+/ } keys %{ $form };

  if (!DO->retrieve('vc' => $form->{vc}, 'ids' => \@do_ids)) {
    $form->show_generic_error($form->{vc} eq 'customer' ?
                              $locale->text('You cannot create an invoice for delivery orders for different customers.') :
                              $locale->text('You cannot create an invoice for delivery orders from different vendors.'),
                              'back_button' => 1);
  }

  my $source_type              = $form->{type};
  $form->{convert_from_do_ids} = join ' ', @do_ids;
  # bei der auswahl von mehreren Lieferscheinen fuer eine Rechnung, die einfach in donumber_array
  # zwischenspeichern (DO.pm) und als ' '-separierte Liste wieder zurueckschreiben
  # Hinweis: delete gibt den wert zurueck und loescht danach das element (nett und einfach)
  # $shell: perldoc perlunc; /delete EXPR
  $form->{donumber}            = delete $form->{donumber_array};
  $form->{ordnumber}           = delete $form->{ordnumber_array};
  $form->{cusordnumber}        = delete $form->{cusordnumber_array};
  $form->{deliverydate}        = $form->{transdate};
  $form->{transdate}           = $form->current_date(\%myconfig);
  $form->{duedate}             = $form->current_date(\%myconfig, $form->{invdate}, $form->{terms} * 1);
  $form->{type}                = "invoice";
  $form->{closed}              = 0;
  $form->{defaultcurrency}     = $form->get_default_currency(\%myconfig);

  my ($script, $buysell);
  if ($source_type eq 'purchase_delivery_order') {
    $form->{title}  = $locale->text('Add Vendor Invoice');
    $form->{script} = 'ir.pl';
    $script         = "ir";
    $buysell        = 'sell';
    $form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_PURCHASE_INVOICE_POST())->token;

  } else {
    $form->{title}  = $locale->text('Add Sales Invoice');
    $form->{script} = 'is.pl';
    $script         = "is";
    $buysell        = 'buy';
    $form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_SALES_INVOICE_POST())->token;
  }

  map { delete $form->{$_} } qw(id subject message cc bcc printed emailed queued);

  # get vendor or customer discount
  my $vc_discount;
  my $saved_form = save_form();
  if ($form->{vc} eq 'vendor') {
    IR->get_vendor(\%myconfig, \%$form);
    $vc_discount = $form->{vendor_discount};
  } else {
    IS->get_customer(\%myconfig, \%$form);
    $vc_discount = $form->{customer_discount};
  }
  # use payment terms from customer or vendor
  restore_form($saved_form,0,qw(payment_id));

  $form->{rowcount} = 0;
  foreach my $ref (@{ $form->{form_details} }) {
    $form->{rowcount}++;
    $ref->{reqdate} ||= $ref->{dord_transdate}; # copy transdates into each invoice row
    map { $form->{"${_}_$form->{rowcount}"} = $ref->{$_} } keys %{ $ref };
    map { $form->{"${_}_$form->{rowcount}"} = $form->format_amount(\%myconfig, $ref->{$_}) } qw(qty sellprice lastcost);
    $form->{"converted_from_delivery_order_items_id_$form->{rowcount}"} = delete $form->{"delivery_order_items_id_$form->{rowcount}"};

    if ($vc_discount){ # falls wir einen Lieferanten/Kundenrabatt haben
      # und keinen anderen discount wert an $i ...
      $form->{"discount_$form->{rowcount}"} ||= $vc_discount; # ... nehmen wir diesen Rabatt
    }

    $form->{"discount_$form->{rowcount}"}   = $form->{"discount_$form->{rowcount}"}  * 100; #s.a. Bug 1151
    # Anm.: Eine Änderung des discounts in der SL/DO.pm->retrieve (select (doi.discount * 100) as discount) ergibt in psql einen
    # Wert von 10.0000001490116. Ferner ist der Rabatt in der Rechnung dann bei 1.0 (?). Deswegen lasse ich das hier. jb 10.10.09

    $form->{"discount_$form->{rowcount}"} = $form->format_amount(\%myconfig, $form->{"discount_$form->{rowcount}"});
  }
  delete $form->{form_details};

  $locale = Locale->new("$myconfig{countrycode}", "$script");

  require "bin/mozilla/$form->{script}";

  invoice_links();
  prepare_invoice();

  display_form();

  $main::lxdebug->leave_sub();
}

sub save_and_reclamation {
  my $form     = $main::form;
  my $id       = $form->{id};
  my $type     = $form->{type};

  # save the delivery order
  save(no_redirect => 1);

  my $to_reclamation_type =
    $type eq 'sales_delivery_order' ? 'sales_reclamation'
                                    : 'purchase_reclamation';
  $form->{callback} =
    'controller.pl?action=Reclamation/add_from_record'
    . '&type='      . $to_reclamation_type
    . '&from_id='   . $form->escape($id)
    . '&from_type=' . $form->escape($type)
    ;
  $form->redirect;
}

sub save_as_new {
  $main::lxdebug->enter_sub();

  check_do_access_for_edit();

  my $form     = $main::form;

  $form->{saveasnew} = 1;
  $form->{closed}    = 0;
  $form->{delivered} = 0;
  map { delete $form->{$_} } qw(printed emailed queued);
  delete @{ $form }{ grep { m/^stock_(?:in|out)_\d+/ } keys %{ $form } };
  $form->{"converted_from_delivery_order_items_id_$_"} = delete $form->{"delivery_order_items_id_$_"} for 1 .. $form->{"rowcount"};
  # Let kivitendo assign a new order number if the user hasn't changed the
  # previous one. If it has been changed manually then use it as-is.
  $form->{donumber} =~ s/^\s*//g;
  $form->{donumber} =~ s/\s*$//g;
  if ($form->{saved_donumber} && ($form->{saved_donumber} eq $form->{donumber})) {
    delete($form->{donumber});
  }

  save();

  $main::lxdebug->leave_sub();
}

sub calculate_stock_in_out {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  my $i = shift;

  if (!$form->{"id_${i}"}) {
    $main::lxdebug->leave_sub();
    return '';
  }

  my $all_units = AM->retrieve_all_units();

  my $in_out   = $form->{type} =~ /^sales/ ? 'out' : 'in';
  my $sinfo    = DO->unpack_stock_information('packed' => $form->{"stock_${in_out}_${i}"});

  my $do_qty   = AM->sum_with_unit($::form->{"qty_$i"}, $::form->{"unit_$i"});
  my $sum      = AM->sum_with_unit(map { $_->{qty}, $_->{unit} } @{ $sinfo });
  my $matches  = $do_qty == $sum;

  my $amount_unit = $all_units->{$form->{"partunit_$i"}}->{base_unit};
  my $content     = $form->format_amount(\%::myconfig, AM->convert_unit($amount_unit, $form->{"unit_$i"}) * $sum * 1) . ' ' . $form->{"unit_$i"};

  $content     = qq|<span id="stock_in_out_qty_display_${i}">${content}</span><input type=hidden id='stock_in_out_qty_matches_$i' value='$matches'> <input type="button" onclick="open_stock_in_out_window('${in_out}', $i);" value="?">|;

  $main::lxdebug->leave_sub();

  return $content;
}

sub get_basic_bin_wh_info {
  $main::lxdebug->enter_sub();

  my $stock_info = shift;

  my $form     = $main::form;

  foreach my $sinfo (@{ $stock_info }) {
    next unless ($sinfo->{bin_id});

    my $bin_info = WH->get_basic_bin_info('id' => $sinfo->{bin_id});
    map { $sinfo->{"${_}_description"} = $sinfo->{"${_}description"} = $bin_info->{"${_}_description"} } qw(bin warehouse);
  }

  $main::lxdebug->leave_sub();
}

sub stock_in_out_form {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  if ($form->{in_out} eq 'out') {
    stock_out_form();
  } else {
    stock_in_form();
  }

  $main::lxdebug->leave_sub();
}

sub redo_stock_info {
  $main::lxdebug->enter_sub();

  my %params    = @_;

  my $form     = $main::form;

  my @non_empty = grep { $_->{qty} } @{ $params{stock_info} };

  if ($params{add_empty_row}) {
    push @non_empty, {
      'warehouse_id' => scalar(@non_empty) ? $non_empty[-1]->{warehouse_id} : undef,
      'bin_id'       => scalar(@non_empty) ? $non_empty[-1]->{bin_id}       : undef,
    };
  }

  @{ $params{stock_info} } = @non_empty;

  $main::lxdebug->leave_sub();
}

sub update_stock_in {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  my $stock_info = [];

  foreach my $i (1..$form->{rowcount}) {
    $form->{"qty_$i"} = $form->parse_amount(\%myconfig, $form->{"qty_$i"});
    push @{ $stock_info }, { map { $_ => $form->{"${_}_${i}"} } qw(warehouse_id bin_id chargenumber
                                                                   bestbefore qty unit delivery_order_items_stock_id) };
  }

  display_stock_in_form($stock_info);

  $main::lxdebug->leave_sub();
}

sub stock_in_form {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  my $stock_info = DO->unpack_stock_information('packed' => $form->{stock});

  display_stock_in_form($stock_info);

  $main::lxdebug->leave_sub();
}

sub display_stock_in_form {
  $main::lxdebug->enter_sub();

  my $stock_info = shift;

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $form->{title} = $locale->text('Stock');

  my $part_info  = IC->get_basic_part_info('id' => $form->{parts_id});

  # Standardlagerplatz für Standard-Auslagern verwenden, falls keiner für die Ware explizit definiert wurde
  if ($::instance_conf->get_transfer_default_use_master_default_bin) {
    $part_info->{warehouse_id} ||= $::instance_conf->get_warehouse_id;
    $part_info->{bin_id}       ||= $::instance_conf->get_bin_id;
  }

  my $units      = AM->retrieve_units(\%myconfig, $form);
  # der zweite Parameter von unit_select_data gibt den default-Namen (selected) vor
  my $units_data = AM->unit_select_data($units, $form->{do_unit}, undef, $part_info->{unit});

  $form->get_lists('warehouses' => { 'key'    => 'WAREHOUSES',
                                     'bins'   => 'BINS' });

  redo_stock_info('stock_info' => $stock_info, 'add_empty_row' => !$form->{delivered});

  get_basic_bin_wh_info($stock_info);

  $form->header(no_layout => 1);
  print $form->parse_html_template('do/stock_in_form', { 'UNITS'      => $units_data,
                                                         'STOCK_INFO' => $stock_info,
                                                         'PART_INFO'  => $part_info, });

  $main::lxdebug->leave_sub();
}

sub _stock_in_out_set_qty_display {
  my $stock_info       = shift;
  my $form             = $::form;
  my $all_units        = AM->retrieve_all_units();
  my $sum              = AM->sum_with_unit(map { $_->{qty}, $_->{unit} } @{ $stock_info });
  my $amount_unit      = $all_units->{$form->{"partunit"}}->{base_unit};
  $form->{qty_display} = $form->format_amount(\%::myconfig, AM->convert_unit($amount_unit, $form->{"do_unit"}) * $sum * 1) . ' ' . $form->{"do_unit"};
}

sub set_stock_in {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  my $stock_info = [];

  foreach my $i (1..$form->{rowcount}) {
    $form->{"qty_$i"} = $form->parse_amount(\%myconfig, $form->{"qty_$i"});

    next if ($form->{"qty_$i"} <= 0);

    push @{ $stock_info }, { map { $_ => $form->{"${_}_${i}"} } qw(delivery_order_items_stock_id warehouse_id bin_id chargenumber bestbefore qty unit) };
  }

  $form->{stock} = SL::YAML::Dump($stock_info);

  _stock_in_out_set_qty_display($stock_info);

  my $do_qty       = AM->sum_with_unit($::form->parse_amount(\%::myconfig, $::form->{do_qty}), $::form->{do_unit});
  my $transfer_qty = AM->sum_with_unit(map { $_->{qty}, $_->{unit} } @{ $stock_info });

  $form->header();
  print $form->parse_html_template('do/set_stock_in_out', {
    qty_matches => $do_qty == $transfer_qty,
  });

  $main::lxdebug->leave_sub();
}

sub stock_out_form {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $form->{title} = $locale->text('Release From Stock');

  my $part_info  = IC->get_basic_part_info('id' => $form->{parts_id});

  my $units      = AM->retrieve_units(\%myconfig, $form);
  my $units_data = AM->unit_select_data($units, undef, undef, $part_info->{unit});

  my @contents   = DO->get_item_availability('parts_id' => $form->{parts_id});

  my $stock_info = DO->unpack_stock_information('packed' => $form->{stock});

  if (!$form->{delivered}) {
    foreach my $row (@contents) {
      $row->{available_qty} = $form->format_amount(\%::myconfig, $row->{qty} * 1) . ' ' . $part_info->{unit};

      foreach my $sinfo (@{ $stock_info }) {
        next if (($row->{bin_id}       != $sinfo->{bin_id}) ||
                 ($row->{warehouse_id} != $sinfo->{warehouse_id}) ||
                 ($row->{chargenumber} ne $sinfo->{chargenumber}) ||
                 ($row->{bestbefore}   ne $sinfo->{bestbefore}));

        map { $row->{"stock_$_"} = $sinfo->{$_} } qw(qty unit error delivery_order_items_stock_id);
      }
    }

  } else {
    get_basic_bin_wh_info($stock_info);

    foreach my $sinfo (@{ $stock_info }) {
      map { $sinfo->{"stock_$_"} = $sinfo->{$_} } qw(qty unit);
    }
  }

  $form->header(no_layout => 1);
  print $form->parse_html_template('do/stock_out_form', { 'UNITS'      => $units_data,
                                                          'WHCONTENTS' => $form->{delivered} ? $stock_info : \@contents,
                                                          'PART_INFO'  => $part_info, });

  $main::lxdebug->leave_sub();
}

sub set_stock_out {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  my $stock_info = [];

  foreach my $i (1 .. $form->{rowcount}) {
    $form->{"qty_$i"} = $form->parse_amount(\%myconfig, $form->{"qty_$i"});

    next if ($form->{"qty_$i"} <= 0);

    push @{ $stock_info }, {
      'warehouse_id' => $form->{"warehouse_id_$i"},
      'bin_id'       => $form->{"bin_id_$i"},
      'chargenumber' => $form->{"chargenumber_$i"},
      'bestbefore'   => $form->{"bestbefore_$i"},
      'qty'          => $form->{"qty_$i"},
      'unit'         => $form->{"unit_$i"},
      'row'          => $i,
      'delivery_order_items_stock_id'  => $form->{"delivery_order_items_stock_id_$i"},
    };
  }

  my @errors     = DO->check_stock_availability('requests' => $stock_info,
                                                'parts_id' => $form->{parts_id});

  $form->{stock} = SL::YAML::Dump($stock_info);

  if (@errors) {
    $form->{ERRORS} = [];
    map { push @{ $form->{ERRORS} }, $locale->text('Error in row #1: The quantity you entered is bigger than the stocked quantity.', $_->{row}); } @errors;
    stock_in_out_form();

  } else {
    _stock_in_out_set_qty_display($stock_info);

    my $do_qty       = AM->sum_with_unit($::form->parse_amount(\%::myconfig, $::form->{do_qty}), $::form->{do_unit});
    my $transfer_qty = AM->sum_with_unit(map { $_->{qty}, $_->{unit} } @{ $stock_info });

    $form->header();
    print $form->parse_html_template('do/set_stock_in_out', {
      qty_matches => $do_qty == $transfer_qty,
    });
  }

  $main::lxdebug->leave_sub();
}

sub transfer_in {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  if ($form->{id} && DO->is_marked_as_delivered(id => $form->{id})) {
    $form->show_generic_error($locale->text('The parts for this delivery order have already been transferred in.'));
  }

  save(no_redirect => 1);

  my @part_ids = map { $form->{"id_${_}"} } grep { $form->{"id_${_}"} && $form->{"stock_in_${_}"} } (1 .. $form->{rowcount});
  my @all_requests;

  if (@part_ids) {
    my $units         = AM->retrieve_units(\%myconfig, $form);
    my %part_info_map = IC->get_basic_part_info('id' => \@part_ids);
    my %request_map;

    $form->{ERRORS}   = [];

    foreach my $i (1 .. $form->{rowcount}) {
      next unless ($form->{"id_$i"} && $form->{"stock_in_$i"});

      my $row_sum_base_qty = 0;
      my $base_unit_factor = $units->{ $part_info_map{$form->{"id_$i"}}->{unit} }->{factor} || 1;

      foreach my $request (@{ DO->unpack_stock_information('packed' => $form->{"stock_in_$i"}) }) {
        $request->{parts_id}  = $form->{"id_$i"};
        $row_sum_base_qty    += $request->{qty} * $units->{$request->{unit}}->{factor} / $base_unit_factor;

        $request->{project_id} = $form->{"project_id_$i"} || $form->{globalproject_id};

        push @all_requests, $request;
      }

      next if (0 == $row_sum_base_qty);

      my $do_base_qty = $form->parse_amount(\%myconfig, $form->{"qty_$i"}) * $units->{$form->{"unit_$i"}}->{factor} / $base_unit_factor;

#      if ($do_base_qty != $row_sum_base_qty) {
#        push @{ $form->{ERRORS} }, $locale->text('Error in position #1: You must either assign no stock at all or the full quantity of #2 #3.',
#                                                 $i, $form->{"qty_$i"}, $form->{"unit_$i"});
#      }
    }

    if (@{ $form->{ERRORS} }) {
      push @{ $form->{ERRORS} }, $locale->text('The delivery order has not been marked as delivered. The warehouse contents have not changed.');

      set_headings('edit');
      update();
      $main::lxdebug->leave_sub();

      $::dispatcher->end_request;
    }
  }

  DO->transfer_in_out('direction' => 'in',
                      'requests'  => \@all_requests);

  SL::DB::DeliveryOrder->new(id => $form->{id})->load->update_attributes(delivered => 1);

  flash_later('info', $locale->text("Transfer successful"));
  $form->{callback} = 'do.pl?action=edit&type=purchase_delivery_order&id=' . $form->escape($form->{id});
  $form->redirect;

  $main::lxdebug->leave_sub();
}

sub transfer_out {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  if ($form->{id} && DO->is_marked_as_delivered(id => $form->{id})) {
    $form->show_generic_error($locale->text('The parts for this delivery order have already been transferred out.'));
  }

  save(no_redirect => 1);

  my @part_ids = map { $form->{"id_${_}"} } grep { $form->{"id_${_}"} && $form->{"stock_out_${_}"} } (1 .. $form->{rowcount});
  my @all_requests;

  if (@part_ids) {
    my $units         = AM->retrieve_units(\%myconfig, $form);
    my %part_info_map = IC->get_basic_part_info('id' => \@part_ids);
    my %request_map;

    $form->{ERRORS}   = [];

    foreach my $i (1 .. $form->{rowcount}) {
      next unless ($form->{"id_$i"} && $form->{"stock_out_$i"});

      my $row_sum_base_qty = 0;
      my $base_unit_factor = $units->{ $part_info_map{$form->{"id_$i"}}->{unit} }->{factor} || 1;

      foreach my $request (@{ DO->unpack_stock_information('packed' => $form->{"stock_out_$i"}) }) {
        $request->{parts_id} = $form->{"id_$i"};
        $request->{base_qty} = $request->{qty} * $units->{$request->{unit}}->{factor} / $base_unit_factor;
        $request->{project_id} = $form->{"project_id_$i"} ? $form->{"project_id_$i"} : $form->{globalproject_id};

        my $map_key          = join '--', ($form->{"id_$i"}, @{$request}{qw(warehouse_id bin_id chargenumber bestbefore)});

        $request_map{$map_key}                 ||= $request;
        $request_map{$map_key}->{sum_base_qty} ||= 0;
        $request_map{$map_key}->{sum_base_qty}  += $request->{base_qty};
        $row_sum_base_qty                       += $request->{base_qty};

        push @all_requests, $request;
      }

      next if (0 == $row_sum_base_qty);

      my $do_base_qty = $form->{"qty_$i"} * $units->{$form->{"unit_$i"}}->{factor} / $base_unit_factor;

#      if ($do_base_qty != $row_sum_base_qty) {
#        push @{ $form->{ERRORS} }, $locale->text('Error in position #1: You must either assign no transfer at all or the full quantity of #2 #3.',
#                                                 $i, $form->{"qty_$i"}, $form->{"unit_$i"});
#      }
    }

    if (%request_map) {
      my @bin_ids      = map { $_->{bin_id} } values %request_map;
      my %bin_info_map = WH->get_basic_bin_info('id' => \@bin_ids);
      my @contents     = DO->get_item_availability('parts_id' => \@part_ids);

      foreach my $inv (@contents) {
        my $map_key = join '--', @{$inv}{qw(parts_id warehouse_id bin_id chargenumber bestbefore)};

        next unless ($request_map{$map_key});

        my $request    = $request_map{$map_key};
        $request->{ok} = $request->{sum_base_qty} <= $inv->{qty};
      }

      foreach my $request (values %request_map) {
        next if ($request->{ok});

        my $pinfo = $part_info_map{$request->{parts_id}};
        my $binfo = $bin_info_map{$request->{bin_id}};

        if ($::instance_conf->get_show_bestbefore) {
            push @{ $form->{ERRORS} }, $locale->text("There is not enough available of '#1' at warehouse '#2', bin '#3', #4, #5, for the transfer of #6.",
                                                     $pinfo->{description},
                                                     $binfo->{warehouse_description},
                                                     $binfo->{bin_description},
                                                     $request->{chargenumber} ? $locale->text('chargenumber #1', $request->{chargenumber}) : $locale->text('no chargenumber'),
                                                     $request->{bestbefore} ? $locale->text('bestbefore #1', $request->{bestbefore}) : $locale->text('no bestbefore'),
                                                     $form->format_amount(\%::myconfig, $request->{sum_base_qty}) . ' ' . $pinfo->{unit});
        } else {
            push @{ $form->{ERRORS} }, $locale->text("There is not enough available of '#1' at warehouse '#2', bin '#3', #4, for the transfer of #5.",
                                                     $pinfo->{description},
                                                     $binfo->{warehouse_description},
                                                     $binfo->{bin_description},
                                                     $request->{chargenumber} ? $locale->text('chargenumber #1', $request->{chargenumber}) : $locale->text('no chargenumber'),
                                                     $form->format_amount(\%::myconfig, $request->{sum_base_qty}) . ' ' . $pinfo->{unit});
        }
      }
    }

    if (@{ $form->{ERRORS} }) {
      push @{ $form->{ERRORS} }, $locale->text('The delivery order has not been marked as delivered. The warehouse contents have not changed.');

      set_headings('edit');
      update();
      $main::lxdebug->leave_sub();

      $::dispatcher->end_request;
    }
  }
  DO->transfer_in_out('direction' => 'out',
                      'requests'  => \@all_requests);

  SL::DB::DeliveryOrder->new(id => $form->{id})->load->update_attributes(delivered => 1);

  flash_later('info', $locale->text("Transfer successful"));
  $form->{callback} = 'do.pl?action=edit&type=sales_delivery_order&id=' . $form->escape($form->{id});
  $form->redirect;

  $main::lxdebug->leave_sub();
}

sub mark_closed {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  DO->close_orders('ids' => [ $form->{id} ]);

  $form->{closed} = 1;

  update();

  $main::lxdebug->leave_sub();
}

sub display_form {
  $::lxdebug->enter_sub;

  check_do_access();

  relink_accounts();
  retrieve_partunits();

  my $new_rowcount = $::form->{"rowcount"} * 1 + 1;
  $::form->{"project_id_${new_rowcount}"} = $::form->{"globalproject_id"};

  $::form->language_payment(\%::myconfig);

  Common::webdav_folder($::form);

  form_header();
  display_row(++$::form->{rowcount});
  form_footer();

  $::lxdebug->leave_sub;
}

sub yes {
  call_sub($main::form->{yes_nextsub});
}

sub no {
  call_sub($main::form->{no_nextsub});
}

sub update {
  call_sub($main::form->{update_nextsub} || $main::form->{nextsub} || 'update_delivery_order');
}

sub dispatcher {
  my $form     = $main::form;
  my $locale   = $main::locale;

  foreach my $action (qw(update print save transfer_out transfer_out_default sort
                         transfer_in transfer_in_default mark_closed save_as_new invoice delete)) {
    if ($form->{"action_${action}"}) {
      call_sub($action);
      return;
    }
  }

  $form->error($locale->text('No action defined.'));
}

sub transfer_out_default {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  transfer_in_out_default('direction' => 'out');

  $main::lxdebug->leave_sub();
}

sub transfer_in_default {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  transfer_in_out_default('direction' => 'in');

  $main::lxdebug->leave_sub();
}

# Falls das Standardlagerverfahren aktiv ist, wird
# geprüft, ob alle Standardlagerplätze für die Auslager-
# artikel vorhanden sind UND ob die Warenmenge ausreicht zum
# Auslagern. Falls nicht wird entsprechend eine Fehlermeldung
# generiert. Offen Chargennummer / bestbefore wird nicht berücksichtigt
sub transfer_in_out_default {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;
  my %params   = @_;

  my (%missing_default_bins, %qty_parts, @all_requests, %part_info_map, $default_warehouse_id, $default_bin_id);

  Common::check_params(\%params, qw(direction));

  # entsprechende defaults holen, falls standardlagerplatz verwendet werden soll
  if ($::instance_conf->get_transfer_default_use_master_default_bin) {
    $default_warehouse_id = $::instance_conf->get_warehouse_id;
    $default_bin_id       = $::instance_conf->get_bin_id;
  }


  my @part_ids = map { $form->{"id_${_}"} } (1 .. $form->{rowcount});
  if (@part_ids) {
    my $units         = AM->retrieve_units(\%myconfig, $form);
    %part_info_map = IC->get_basic_part_info('id' => \@part_ids);
    foreach my $i (1 .. $form->{rowcount}) {
      next unless ($form->{"id_$i"});
      my $base_unit_factor = $units->{ $part_info_map{$form->{"id_$i"}}->{unit} }->{factor} || 1;
      my $qty =   $form->parse_amount(\%myconfig, $form->{"qty_$i"}) * $units->{$form->{"unit_$i"}}->{factor} / $base_unit_factor;

      $form->show_generic_error($locale->text("Cannot transfer negative entries." )) if ($qty < 0);
      # if we do not want to transfer services and this part is a service, set qty to zero
      # ... and do not create a hash entry in %qty_parts below (will skip check for bins for the transfer == out case)
      # ... and push only a empty (undef) element to @all_requests (will skip check for bin_id and warehouse_id and will not alter the row)

      $qty = 0 if (!$::instance_conf->get_transfer_default_services && $part_info_map{$form->{"id_$i"}}->{part_type} eq 'service');
      $qty_parts{$form->{"id_$i"}} += $qty;
      if ($qty == 0) {
        delete $qty_parts{$form->{"id_$i"}} unless $qty_parts{$form->{"id_$i"}};
        undef $form->{"stock_in_$i"};
      }

      $part_info_map{$form->{"id_$i"}}{bin_id}       ||= $default_bin_id;
      $part_info_map{$form->{"id_$i"}}{warehouse_id} ||= $default_warehouse_id;

      push @all_requests, ($qty == 0) ? { } : {
                        'chargenumber' => '',  #?? die müsste entsprechend geholt werden
                        #'bestbefore' => undef, # TODO wird nicht berücksichtigt
                        'bin_id' => $part_info_map{$form->{"id_$i"}}{bin_id},
                        'qty' => $qty,
                        'parts_id' => $form->{"id_$i"},
                        'comment' => $locale->text("Default transfer delivery order"),
                        'unit' => $part_info_map{$form->{"id_$i"}}{unit},
                        'warehouse_id' => $part_info_map{$form->{"id_$i"}}{warehouse_id},
                        'oe_id' => $form->{id},
                        'project_id' => $form->{"project_id_$i"} ? $form->{"project_id_$i"} : $form->{globalproject_id}
                      };
    }

    # jetzt wird erst überprüft, ob die Stückzahl entsprechend stimmt.
    # check if bin (transfer in and transfer out and qty (transfer out) is correct
    foreach my $key (keys %qty_parts) {

      $missing_default_bins{$key}{missing_bin} = 1 unless ($part_info_map{$key}{bin_id});
      next unless ($part_info_map{$key}{bin_id}); # abbruch

      if ($params{direction} eq 'out') {  # wird nur für ausgehende Mengen benötigt
        my ($max_qty, $error) = WH->get_max_qty_parts_bin(parts_id => $key, bin_id => $part_info_map{$key}{bin_id});
        if ($error == 1) {
          # wir können nicht entscheiden, welche charge oder mhd (bestbefore) ausgewählt sein soll
          # deshalb rückmeldung nach oben geben, manuell auszulagern
          # TODO Bei nur einem Treffer mit Charge oder bestbefore wäre das noch möglich
          $missing_default_bins{$key}{chargenumber} = 1;
        }
        if ($max_qty < $qty_parts{$key}){
          $missing_default_bins{$key}{missing_qty} = $max_qty - $qty_parts{$key};
        }
      }
    }
  } # if @parts_id

  # Abfrage für Fehlerbehandlung (nur bei direction == out)
  if (scalar (keys %missing_default_bins)) {
    my $fehlertext;
    foreach my $fehler (keys %missing_default_bins) {

      my $ware = WH->get_part_description(parts_id => $fehler);
      if ($missing_default_bins{$fehler}{missing_bin}){
        $fehlertext .= "Kein Standardlagerplatz definiert bei $ware <br>";
      }
      if ($missing_default_bins{$fehler}{missing_qty}) {  # missing_qty
        $fehlertext .= "Es fehlen " . $missing_default_bins{$fehler}{missing_qty}*-1 .
                       " von $ware auf dem Standard-Lagerplatz " . $part_info_map{$fehler}{bin} .   " zum Auslagern<br>";
      }
      if ($missing_default_bins{$fehler}{chargenumber}){
        $fehlertext .= "Die Ware hat eine Chargennummer oder eine Mindesthaltbarkeit definiert.
                        Hier kann man nicht automatisch entscheiden.
                        Bitte diesen Lieferschein manuell auslagern.
                        Bei: $ware";
      }
      # auslagern soll immer gehen, auch wenn nicht genügend auf lager ist.
      # der lagerplatz ist hier extra konfigurierbar, bspw. Lager-Korrektur mit
      # Lagerplatz Lagerplatz-Korrektur
      my $default_warehouse_id_ignore_onhand = $::instance_conf->get_warehouse_id_ignore_onhand;
      my $default_bin_id_ignore_onhand       = $::instance_conf->get_bin_id_ignore_onhand;
      if ($::instance_conf->get_transfer_default_ignore_onhand && $default_bin_id_ignore_onhand) {
        # entsprechende defaults holen
        # falls chargenumber, bestbefore oder anzahl nicht stimmt, auf automatischen
        # lagerplatz wegbuchen!
        foreach (@all_requests) {
          if ($_->{parts_id} eq $fehler){
          $_->{bin_id}        = $default_bin_id_ignore_onhand;
          $_->{warehouse_id}  = $default_warehouse_id_ignore_onhand;
          }
        }
      } else {
        #$main::lxdebug->message(0, 'Fehlertext: ' . $fehlertext);
        $form->show_generic_error($locale->text("Cannot transfer. <br> Reason:<br>#1", $fehlertext ));
      }
    }
  }


  # hier der eigentliche fallunterschied für in oder out
  my $prefix   = $params{direction} eq 'in' ? 'in' : 'out';

  # dieser array_ref ist für DO->save da:
  # einmal die all_requests in YAML verwandeln, damit delivery_order_items_stock
  # gefüllt werden kann.
  # could be dumped to the form in the first loop,
  # but maybe bin_id and warehouse_id has changed to the "korrekturlager" with
  # allowed negative qty ($::instance_conf->get_warehouse_id_ignore_onhand) ...
  my $i = 0;
  foreach (@all_requests){
    $i++;
    next unless scalar(%{ $_ });
    $form->{"stock_${prefix}_$i"} = SL::YAML::Dump([$_]);
  }

  save(no_redirect => 1); # Wir können auslagern, deshalb beleg speichern
                          # und in delivery_order_items_stock speichern

  # ... and fill back the persistent dois_id for inventory fk
  undef (@all_requests);
  foreach my $i (1 .. $form->{rowcount}) {
    next unless ($form->{"id_$i"} && $form->{"stock_${prefix}_$i"});
    push @all_requests, @{ DO->unpack_stock_information('packed' => $form->{"stock_${prefix}_$i"}) };
  }
  DO->transfer_in_out('direction' => $prefix,
                      'requests'  => \@all_requests);

  SL::DB::DeliveryOrder->new(id => $form->{id})->load->update_attributes(delivered => 1);

  $form->{callback} = 'do.pl?action=edit&type=sales_delivery_order&id=' . $form->escape($form->{id}) if $params{direction} eq 'out';
  $form->{callback} = 'do.pl?action=edit&type=purchase_delivery_order&id=' . $form->escape($form->{id}) if $params{direction} eq 'in';
  $form->redirect;

}

sub sort {
  $main::lxdebug->enter_sub();

  check_do_access();

  my $form     = $main::form;
  my %temp_hash;

  save(no_redirect => 1); # has to be done, at least for newly added positions

  # hashify partnumbers, positions. key is delivery_order_items_id
  for my $i (1 .. ($form->{rowcount}) ) {
    $temp_hash{$form->{"delivery_order_items_id_$i"}} = { runningnumber => $form->{"runningnumber_$i"}, partnumber => $form->{"partnumber_$i"} };
    if ($form->{id} && $form->{"discount_$i"}) {
      # prepare_order assumes a db value if there is a form->id and multiplies *100
      # We hope for new controller code (no more format_amount/parse_amount distinction)
      $form->{"discount_$i"} /=100;
    }
  }
  # naturally sort partnumbers and get a sorted array of doi_ids
  my @sorted_doi_ids =  sort { Sort::Naturally::ncmp($temp_hash{$a}->{"partnumber"}, $temp_hash{$b}->{"partnumber"}) }  keys %temp_hash;


  my $new_number = 1;

  for (@sorted_doi_ids) {
    $form->{"runningnumber_$temp_hash{$_}->{runningnumber}"} = $new_number;
    $new_number++;
  }
  # all parse_amounts changes are in form (i.e. , to .) therefore we need
  # another format_amount to change it back, for the next save ;-(
  # works great except for row discounts (see above comment)
  prepare_order();


    $main::lxdebug->leave_sub();
    save();
}

__END__

=pod

=encoding utf8

=head1 NAME

do.pl - Script for all calls to delivery order

=head1 FUNCTIONS

=over 2

=item C<sort>

Sorts all position with Natural Sort. Can be activated in form_footer.html like this
C<E<lt>input class="submit" type="submit" name="action_sort" id="sort_button" value="[% 'Sort and Save' | $T8 %]"E<gt>>

=back

=head1 TODO

Sort and Save can be implemented as an optional button if configuration ca be set by client config.
Example coding for database scripts and templates in (git show af2f24b8), check also
autogeneration for rose (scripts/rose_auto_create_model.pl --h)
