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
use SL::DB::Helper::TypeDataProxy;
require "bin/mozilla/common.pl";
require "bin/mozilla/io.pl";
require "bin/mozilla/reportgenerator.pl";

use SL::Helper::Flash qw(flash flash_later);

use strict;

1;

# end of main

sub check_do_access {
  validate_type($::form->{type});

  my $right = type_data()->rights('view');
  $main::auth->assert($right);
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

sub search {
  $main::lxdebug->enter_sub();

  check_do_access();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $form->{vc} = type_data()->properties('customervendor');

  $form->get_lists("projects"       => { "key" => "ALL_PROJECTS",
                                         "all" => 1 },
                   "business_types" => "ALL_BUSINESS_TYPES");
  $form->{ALL_EMPLOYEES}   = SL::DB::Manager::Employee->get_all_sorted(query => [ deleted => 0 ]);
  $form->{ALL_DEPARTMENTS} = SL::DB::Manager::Department->get_all_sorted;
  $form->{title}           = type_data()->text('list');

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

  $form->{title} = type_data()->text('list');

  my $attachment_basename = type_data()->text('attachment');

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
  my $edit_order_url = build_std_url('script=controller.pl', 'action=Order/edit', 'type=' . ($form->{type} eq 'sales_delivery_order' ? 'sales_order' : 'purchase_order'));

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


sub type_data {
  SL::DB::Helper::TypeDataProxy->new('SL::DB::DeliveryOrder', $::form->{type});
}

__END__

=pod

=encoding utf8

=head1 NAME

do.pl - Script for all calls to delivery order

