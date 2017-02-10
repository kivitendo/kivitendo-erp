package DateTime;

use SL::Helper::DateTime;

no warnings 'redefine';

sub now_local {
  return shift->new(time_zone => $::locale->get_local_time_zone, year => 2014, month => 3, day => 15, hour => 12, minute => 23, second => 34);
}

sub today_local {
  return shift->now_local->truncate(to => 'day');
}

package main;

use Test::More tests => 49;

use lib 't';
use strict;
use utf8;

use Carp;
use Support::TestSetup;

use_ok 'SL::BackgroundJob::CreatePeriodicInvoices';
use_ok 'SL::Controller::FinancialOverview';
use_ok 'SL::DB::Chart';
use_ok 'SL::DB::Customer';
use_ok 'SL::DB::Default';
use_ok 'SL::DB::Invoice';
use_ok 'SL::DB::Order';
use_ok 'SL::DB::Part';
use_ok 'SL::DB::TaxZone';

Support::TestSetup::login();

our ($ar_chart, $buchungsgruppe, $ctrl, $currency_id, $customer, $employee, $order, $part, $tax_zone, $unit, @invoices);

sub clear_up {
  "SL::DB::Manager::${_}"->delete_all(all => 1) for qw(InvoiceItem Invoice OrderItem Order Customer Part);
};

sub init_common_state {
  $ar_chart       = SL::DB::Manager::Chart->find_by(accno => '1400')                        || croak "No AR chart";
  $buchungsgruppe = SL::DB::Manager::Buchungsgruppe->find_by(description => 'Standard 19%') || croak "No accounting group";
  $currency_id    = SL::DB::Default->get->currency_id;
  $employee       = SL::DB::Manager::Employee->current                                      || croak "No employee";
  $tax_zone       = SL::DB::Manager::TaxZone->find_by( description => 'Inland')             || croak "No taxzone";
  $unit           = SL::DB::Manager::Unit->find_by(name => 'psch')                          || croak "No unit";
}

sub create_sales_order {
  my %params = @_;

  $params{$_} ||= {} for qw(customer part tax order orderitem);

  # Clean up: remove invoices, orders, parts and customers
  clear_up();

  $customer     = SL::DB::Customer->new(
    name        => 'Test Customer',
    currency_id => $currency_id,
    taxzone_id  => $tax_zone->id,
    %{ $params{customer} }
  )->save;

  $part = SL::DB::Part->new(
    partnumber         => 'T4254',
    description        => 'Fourty-two fifty-four',
    lastcost           => 222.22,
    sellprice          => 333.33,
    part_type          => 'part',
    buchungsgruppen_id => $buchungsgruppe->id,
    unit               => $unit->name,
    %{ $params{part} }
  )->save;
  $part->load;

  $order                     = SL::DB::Order->new(
    customer_id              => $customer->id,
    currency_id              => $currency_id,
    taxzone_id               => $tax_zone->id,
    transaction_description  => '<%period_start_date%>',
    transdate                => DateTime->from_kivitendo('01.03.2014'),
    orderitems               => [
      { parts_id             => $part->id,
        description          => $part->description,
        lastcost             => $part->lastcost,
        sellprice            => $part->sellprice,
        qty                  => 1,
        unit                 => $unit->name,
        %{ $params{orderitem} },
      },
    ],
    periodic_invoices_config => $params{periodic_invoices_config} ? {
      active                 => 1,
      ar_chart_id            => $ar_chart->id,
      %{ $params{periodic_invoices_config} },
    } : undef,
    %{ $params{order} },
  );

  $order->calculate_prices_and_taxes;

  ok($order->save(cascade => 1));

  $::form         = Support::TestSetup->create_new_form;
  $::form->{year} = 2014;
  $ctrl           = SL::Controller::FinancialOverview->new;

  $ctrl->get_objects;
  $ctrl->calculate_one_time_data;
  $ctrl->calculate_periodic_invoices;
}

init_common_state();

# ----------------------------------------------------------------------
# An order without periodic invoices:
create_sales_order();

is_deeply($ctrl->data->{$_}, { months => [ (0) x 12 ], quarters => [ 0, 0, 0, 0 ], year => 0 }, "no periodic invoices, data for $_")
  for qw(purchase_invoices purchase_orders requests_for_quotation sales_invoices sales_quotations);

is_deeply($ctrl->data->{$_}, { months => [ 0, 0, 333.33, 0, 0, 0, 0, 0, 0, 0, 0, 0 ], quarters => [ 333.33, 0, 0, 0 ], year => 333.33 }, "no periodic invoices, data for $_")
  for qw(sales_orders sales_orders_per_inv);

# ----------------------------------------------------------------------
# order_value_periodicity=y, periodicity=q
create_sales_order(
  periodic_invoices_config  => {
    periodicity             => 'm',
    order_value_periodicity => 'y',
    start_date              => DateTime->from_kivitendo('01.05.2014'),
  });

is_deeply($ctrl->data->{$_}, { months => [ (0) x 12 ], quarters => [ 0, 0, 0, 0 ], year => 0 }, "periodic conf p=m ovp=y, no invoices, data for $_")
  for qw(purchase_invoices purchase_orders requests_for_quotation sales_invoices sales_quotations);

is_deeply($ctrl->data->{sales_orders},
          { months => [ 0, 0, 0, 0, 27.7775, 27.7775, 27.7775, 27.7775, 27.7775, 27.7775, 27.7775, 27.7775 ], quarters => [ 0, 55.555, 83.3325, 83.3325 ], year => 222.22 },
          "periodic conf p=m ovp=y, no invoices, data for sales_orders");
is_deeply($ctrl->data->{sales_orders_per_inv},
          { months => [ 0, 0, 333.33, 0, 0, 0, 0, 0, 0, 0, 0, 0 ], quarters => [ 333.33, 0, 0, 0 ], year => 333.33 },
          "periodic conf p=m ovp=y, no invoices, data for sales_orders_per_inv");

# ----------------------------------------------------------------------
# order_value_periodicity=y, periodicity=q, starting in previous year
create_sales_order(
  order                     => {
    transdate               => DateTime->from_kivitendo('01.03.2013'),
  },
  periodic_invoices_config  => {
    periodicity             => 'q',
    order_value_periodicity => 'y',
    start_date              => DateTime->from_kivitendo('01.05.2013'),
  });

is_deeply($ctrl->data->{$_}, { months => [ (0) x 12 ], quarters => [ 0, 0, 0, 0 ], year => 0 }, "periodic conf p=q ovp=y, no invoices, starting previous year, data for $_")
  for qw(purchase_invoices purchase_orders requests_for_quotation sales_invoices sales_quotations);

is_deeply($ctrl->data->{sales_orders},
          { months => [ 0, 83.3325, 0, 0, 83.3325, 0, 0, 83.3325, 0, 0, 83.3325, 0 ], quarters => [ 83.3325, 83.3325, 83.3325, 83.3325 ], year => 333.33 },
          "periodic conf p=q ovp=y, no invoices, starting previous year, data for sales_orders");
is_deeply($ctrl->data->{sales_orders_per_inv},
          { months => [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ], quarters => [ 0, 0, 0, 0 ], year => 0 },
          "periodic conf p=q ovp=y, no invoices, starting previous year, data for sales_orders_per_inv");

# ----------------------------------------------------------------------
# order_value_periodicity=y, periodicity=q, starting in previous year, ending middle of year
create_sales_order(
  order                     => {
    transdate               => DateTime->from_kivitendo('01.03.2013'),
  },
  periodic_invoices_config  => {
    periodicity             => 'q',
    order_value_periodicity => 'y',
    start_date              => DateTime->from_kivitendo('01.05.2013'),
    end_date                => DateTime->from_kivitendo('01.09.2014'),
    terminated              => 1,
  });

is_deeply($ctrl->data->{$_}, { months => [ (0) x 12 ], quarters => [ 0, 0, 0, 0 ], year => 0 }, "periodic conf p=q ovp=y, no invoices, starting previous year, ending middle of year, data for $_")
  for qw(purchase_invoices purchase_orders requests_for_quotation sales_invoices sales_quotations);

is_deeply($ctrl->data->{sales_orders},
          { months => [ 0, 83.3325, 0, 0, 83.3325, 0, 0, 83.3325, 0, 0, 0, 0 ], quarters => [ 83.3325, 83.3325, 83.3325, 0 ], year => 249.9975 },
          "periodic conf p=q ovp=y, no invoices, starting previous year, ending middle of year, data for sales_orders");
is_deeply($ctrl->data->{sales_orders_per_inv},
          { months => [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ], quarters => [ 0, 0, 0, 0 ], year => 0 },
          "periodic conf p=q ovp=y, no invoices, starting previous year, ending middle of year, data for sales_orders_per_inv");

# ----------------------------------------------------------------------
# order_value_periodicity=y, periodicity=q, starting and ending before current
create_sales_order(
  order                     => {
    transdate               => DateTime->from_kivitendo('01.03.2012'),
  },
  periodic_invoices_config  => {
    periodicity             => 'q',
    order_value_periodicity => 'y',
    start_date              => DateTime->from_kivitendo('01.05.2012'),
    end_date                => DateTime->from_kivitendo('01.09.2013'),
    terminated              => 1,
  });

is_deeply($ctrl->data->{$_}, { months => [ (0) x 12 ], quarters => [ 0, 0, 0, 0 ], year => 0 }, "periodic conf p=q ovp=y, no invoices, starting and ending before current year, data for $_")
  for qw(purchase_invoices purchase_orders requests_for_quotation sales_invoices sales_orders sales_orders_per_inv sales_quotations);

clear_up();

done_testing();
