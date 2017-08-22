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

use Test::More tests => 43;

use lib 't';
use strict;
use utf8;

use Carp;
use Support::TestSetup;
use SL::Dev::Record qw(create_sales_order create_order_item);
use SL::Dev::CustomerVendor qw(new_customer);
use SL::Dev::Part qw(new_part);

use_ok 'SL::BackgroundJob::CreatePeriodicInvoices';
use_ok 'SL::Controller::FinancialOverview';
use_ok 'SL::DB::Chart';
use_ok 'SL::DB::Customer';
use_ok 'SL::DB::Default';
use_ok 'SL::DB::Invoice';
use_ok 'SL::DB::Order';
use_ok 'SL::DB::Part';

Support::TestSetup::login();

our ($ar_chart, $ctrl, $customer, $order, $part, $unit, @invoices);

sub clear_up {
  "SL::DB::Manager::${_}"->delete_all(all => 1) for qw(InvoiceItem Invoice OrderItem Order Customer Part);
};

sub init_common_state {
  $ar_chart       = SL::DB::Manager::Chart->find_by(accno => '1400') || croak "No AR chart";
  $unit           = SL::DB::Manager::Unit->find_by(name => 'psch')   || croak "No unit";
}

sub make_sales_order {
  my %params = @_;

  $params{$_} ||= {} for qw(customer part order orderitem);

  # Clean up: remove invoices, orders, parts and customers
  clear_up();

  $customer     = new_customer(
    name        => 'Test Customer',
    %{ $params{customer} }
  )->save;

  $part = new_part(
    partnumber         => 'T4254',
    description        => 'Fourty-two fifty-four',
    lastcost           => 222.22,
    sellprice          => 333.33,
    %{ $params{part} }
  )->save;
  $part->load;

  $order                     = create_sales_order(
    save                     => 1,
    customer                 => $customer,
    transaction_description  => '<%period_start_date%>',
    transdate                => DateTime->from_kivitendo('01.03.2014'),
    orderitems => [ create_order_item(part => $part, qty =>  1, %{ $params{orderitem} }) ],
    periodic_invoices_config => $params{periodic_invoices_config} ? {
      active                 => 1,
      ar_chart_id            => $ar_chart->id,
      %{ $params{periodic_invoices_config} },
    } : undef,
    %{ $params{order} },
  );

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
make_sales_order();

is_deeply($ctrl->data->{$_}, { months => [ (0) x 12 ], quarters => [ 0, 0, 0, 0 ], year => 0 }, "no periodic invoices, data for $_")
  for qw(purchase_invoices purchase_orders requests_for_quotation sales_invoices sales_quotations);

is_deeply($ctrl->data->{$_}, { months => [ 0, 0, 333.33, 0, 0, 0, 0, 0, 0, 0, 0, 0 ], quarters => [ 333.33, 0, 0, 0 ], year => 333.33 }, "no periodic invoices, data for $_")
  for qw(sales_orders sales_orders_per_inv);

# ----------------------------------------------------------------------
# order_value_periodicity=y, periodicity=q
make_sales_order(
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
make_sales_order(
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
make_sales_order(
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
make_sales_order(
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
