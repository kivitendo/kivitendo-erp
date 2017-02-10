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

use Test::More; # tests => 49;

use lib 't';
use strict;
use utf8;

use Carp;
use Support::TestSetup;

use_ok 'SL::BackgroundJob::CreatePeriodicInvoices';
use_ok 'SL::Controller::FinancialControllingReport';
use_ok 'SL::DB::Chart';
use_ok 'SL::DB::Customer';
use_ok 'SL::DB::Default';
use_ok 'SL::DB::Invoice';
use_ok 'SL::DB::Order';
use_ok 'SL::DB::Part';
use_ok 'SL::DB::TaxZone';

Support::TestSetup::login();

our ($ar_chart, $buchungsgruppe, $ctrl, $currency_id, $customer, $employee, $order, $part, $tax_zone, $unit, @invoices);

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
  "SL::DB::Manager::${_}"->delete_all(all => 1) for qw(InvoiceItem Invoice OrderItem Order Customer Part);

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

  $::form = Support::TestSetup->create_new_form;
  $ctrl   = SL::Controller::FinancialControllingReport->new;

  $ctrl->orders($ctrl->models->get);
  $ctrl->calculate_data;
}

my @columns = qw(net_amount         other_amount
                 delivered_amount   billed_amount   paid_amount   billable_amount
                 delivered_amount_p billed_amount_p paid_amount_p billable_amount_p);

sub run_tests {
  my ($msg, $num_orders, $values, %order_params) = @_;

  create_sales_order(%order_params);

  is($num_orders, scalar @{ $ctrl->orders }, "${msg}, #orders");
  is_deeply([ map { ($ctrl->orders->[0]->{$_} // 0) * 1 } @columns ],
            $values,
            "${msg}, values");
}

init_common_state();

# ----------------------------------------------------------------------
# An order without periodic invoices:
run_tests("no periodic conf", 1, [ 333.33, 0, 0, 0, 0, 0, 0, 0, 0, 0 ]);

# ----------------------------------------------------------------------
# order_value_periodicity=y, periodicity=q

run_tests(
  "periodic conf p=q ovp=y, starting in previous year", 1,
  [ 333.33, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'q',
    order_value_periodicity => 'y',
    start_date              => DateTime->from_kivitendo('01.05.2013'),
  });

run_tests(
  "periodic conf p=q ovp=y, starting and ending in previous year", 1,
  [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'q',
    order_value_periodicity => 'y',
    terminated              => 1,
    start_date              => DateTime->from_kivitendo('01.05.2013'),
    end_date                => DateTime->from_kivitendo('01.12.2013'),
  });

run_tests(
  "periodic conf p=q ovp=y, starting in next year", 1,
  [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'q',
    order_value_periodicity => 'y',
    start_date              => DateTime->from_kivitendo('01.01.2015'),
  });

run_tests(
  "periodic conf p=q ovp=y, starting January 1st of current year", 1,
  [ 333.33, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'q',
    order_value_periodicity => 'y',
    start_date              => DateTime->from_kivitendo('01.01.2014'),
  });

run_tests(
  "periodic conf p=q ovp=y, starting July 1st of current year", 1,
  [ 166.665, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'q',
    order_value_periodicity => 'y',
    start_date              => DateTime->from_kivitendo('01.07.2014'),
  });

run_tests(
  "periodic conf p=q ovp=y, starting May 1st of current year", 1,
  [ 249.9975, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'q',
    order_value_periodicity => 'y',
    start_date              => DateTime->from_kivitendo('01.05.2014'),
  });

run_tests(
  "periodic conf p=q ovp=y, starting January 1st of current year, ending June 30", 1,
  [ 166.665, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'q',
    order_value_periodicity => 'y',
    start_date              => DateTime->from_kivitendo('01.01.2014'),
    end_date                => DateTime->from_kivitendo('30.06.2014'),
    terminated              => 1,
  });

run_tests(
  "periodic conf p=q ovp=y, starting July 1st of current year, ending November 30", 1,
  [ 166.665, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'q',
    order_value_periodicity => 'y',
    start_date              => DateTime->from_kivitendo('01.07.2014'),
    end_date                => DateTime->from_kivitendo('30.11.2014'),
    terminated              => 1,
  });

run_tests(
  "periodic conf p=q ovp=y, starting May 1st of current year, ending next year", 1,
  [ 249.9975, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'q',
    order_value_periodicity => 'y',
    start_date              => DateTime->from_kivitendo('01.05.2014'),
    end_date                => DateTime->from_kivitendo('30.06.2015'),
    terminated              => 1,
  });

run_tests(
  "periodic conf p=q ovp=y, starting November 1 in previous year, ending April 30", 1,
  [ 83.3325, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'q',
    order_value_periodicity => 'y',
    terminated              => 1,
    start_date              => DateTime->from_kivitendo('01.11.2013'),
    end_date                => DateTime->from_kivitendo('30.04.2014'),
  });


# ----------------------------------------------------------------------
# order_value_periodicity=y, periodicity=m

run_tests(
  "periodic conf p=m ovp=y, starting in previous year", 1,
  [ 333.33, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'm',
    order_value_periodicity => 'y',
    start_date              => DateTime->from_kivitendo('01.05.2013'),
  });

run_tests(
  "periodic conf p=m ovp=y, starting and ending in previous year", 1,
  [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'm',
    order_value_periodicity => 'y',
    terminated              => 1,
    start_date              => DateTime->from_kivitendo('01.05.2013'),
    end_date                => DateTime->from_kivitendo('01.12.2013'),
  });

run_tests(
  "periodic conf p=m ovp=y, starting in next year", 1,
  [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'm',
    order_value_periodicity => 'y',
    start_date              => DateTime->from_kivitendo('01.01.2015'),
  });

run_tests(
  "periodic conf p=m ovp=y, starting January 1st of current year", 1,
  [ 333.33, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'm',
    order_value_periodicity => 'y',
    start_date              => DateTime->from_kivitendo('01.01.2014'),
  });

run_tests(
  "periodic conf p=m ovp=y, starting July 1st of current year", 1,
  [ 166.665, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'm',
    order_value_periodicity => 'y',
    start_date              => DateTime->from_kivitendo('01.07.2014'),
  });

run_tests(
  "periodic conf p=m ovp=y, starting May 1st of current year", 1,
  [ 222.22, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'm',
    order_value_periodicity => 'y',
    start_date              => DateTime->from_kivitendo('01.05.2014'),
  });

run_tests(
  "periodic conf p=m ovp=y, starting January 1st of current year, ending June 30", 1,
  [ 166.665, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'm',
    order_value_periodicity => 'y',
    start_date              => DateTime->from_kivitendo('01.01.2014'),
    end_date                => DateTime->from_kivitendo('30.06.2014'),
    terminated              => 1,
  });

run_tests(
  "periodic conf p=m ovp=y, starting July 1st of current year, ending November 30", 1,
  [ 138.8875, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'm',
    order_value_periodicity => 'y',
    start_date              => DateTime->from_kivitendo('01.07.2014'),
    end_date                => DateTime->from_kivitendo('30.11.2014'),
    terminated              => 1,
  });

run_tests(
  "periodic conf p=m ovp=y, starting May 1st of current year, ending next year", 1,
  [ 222.22, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'm',
    order_value_periodicity => 'y',
    start_date              => DateTime->from_kivitendo('01.05.2014'),
    end_date                => DateTime->from_kivitendo('30.06.2015'),
    terminated              => 1,
  });

run_tests(
  "periodic conf p=m ovp=y, starting November 1 in previous year, ending April 30", 1,
  [ 111.11, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'm',
    order_value_periodicity => 'y',
    terminated              => 1,
    start_date              => DateTime->from_kivitendo('01.11.2013'),
    end_date                => DateTime->from_kivitendo('30.04.2014'),
  });


# ----------------------------------------------------------------------
# order_value_periodicity=y, periodicity=q

run_tests(
  "periodic conf p=q ovp=2, starting in previous year", 1,
  [ 166.665, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'q',
    order_value_periodicity => '2',
    start_date              => DateTime->from_kivitendo('01.05.2013'),
  });

run_tests(
  "periodic conf p=q ovp=2, starting and ending in previous year", 1,
  [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'q',
    order_value_periodicity => '2',
    terminated              => 1,
    start_date              => DateTime->from_kivitendo('01.05.2013'),
    end_date                => DateTime->from_kivitendo('01.12.2013'),
  });

run_tests(
  "periodic conf p=q ovp=2, starting in next year", 1,
  [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'q',
    order_value_periodicity => '2',
    start_date              => DateTime->from_kivitendo('01.01.2015'),
  });

run_tests(
  "periodic conf p=q ovp=2, starting January 1st of current year", 1,
  [ 166.665, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'q',
    order_value_periodicity => '2',
    start_date              => DateTime->from_kivitendo('01.01.2014'),
  });

run_tests(
  "periodic conf p=q ovp=2, starting July 1st of current year", 1,
  [ 83.3325, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'q',
    order_value_periodicity => '2',
    start_date              => DateTime->from_kivitendo('01.07.2014'),
  });

run_tests(
  "periodic conf p=q ovp=2, starting May 1st of current year", 1,
  [ 124.99875, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'q',
    order_value_periodicity => '2',
    start_date              => DateTime->from_kivitendo('01.05.2014'),
  });

run_tests(
  "periodic conf p=q ovp=2, starting January 1st of current year, ending June 30", 1,
  [ 83.3325, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'q',
    order_value_periodicity => '2',
    start_date              => DateTime->from_kivitendo('01.01.2014'),
    end_date                => DateTime->from_kivitendo('30.06.2014'),
    terminated              => 1,
  });

run_tests(
  "periodic conf p=q ovp=2, starting July 1st of current year, ending November 30", 1,
  [ 83.3325, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'q',
    order_value_periodicity => '2',
    start_date              => DateTime->from_kivitendo('01.07.2014'),
    end_date                => DateTime->from_kivitendo('30.11.2014'),
    terminated              => 1,
  });

run_tests(
  "periodic conf p=q ovp=2, starting May 1st of current year, ending next year", 1,
  [ 124.99875, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'q',
    order_value_periodicity => '2',
    start_date              => DateTime->from_kivitendo('01.05.2014'),
    end_date                => DateTime->from_kivitendo('30.06.2015'),
    terminated              => 1,
  });

run_tests(
  "periodic conf p=q ovp=2, starting November 1 in previous year, ending April 30", 1,
  [ 41.66625, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'q',
    order_value_periodicity => '2',
    terminated              => 1,
    start_date              => DateTime->from_kivitendo('01.11.2013'),
    end_date                => DateTime->from_kivitendo('30.04.2014'),
  });



# ----------------------------------------------------------------------
# order_value_periodicity=m, periodicity=b

run_tests(
  "periodic conf p=b ovp=m, starting in previous year", 1,
  [ 3999.96, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'b',
    order_value_periodicity => 'm',
    start_date              => DateTime->from_kivitendo('01.05.2013'),
  });

run_tests(
  "periodic conf p=b ovp=m, starting and ending in previous year", 1,
  [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'b',
    order_value_periodicity => 'm',
    terminated              => 1,
    start_date              => DateTime->from_kivitendo('01.05.2013'),
    end_date                => DateTime->from_kivitendo('01.12.2013'),
  });

run_tests(
  "periodic conf p=b ovp=m, starting in next year", 1,
  [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'b',
    order_value_periodicity => 'm',
    start_date              => DateTime->from_kivitendo('01.01.2015'),
  });

run_tests(
  "periodic conf p=b ovp=m, starting January 1st of current year", 1,
  [ 3999.96, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'b',
    order_value_periodicity => 'm',
    start_date              => DateTime->from_kivitendo('01.01.2014'),
  });

run_tests(
  "periodic conf p=b ovp=m, starting July 1st of current year", 1,
  [ 1999.98, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'b',
    order_value_periodicity => 'm',
    start_date              => DateTime->from_kivitendo('01.07.2014'),
  });

run_tests(
  "periodic conf p=b ovp=m, starting May 1st of current year", 1,
  [ 3999.96, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'b',
    order_value_periodicity => 'm',
    start_date              => DateTime->from_kivitendo('01.05.2014'),
  });

run_tests(
  "periodic conf p=b ovp=m, starting January 1st of current year, ending June 30", 1,
  [ 1999.98, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'b',
    order_value_periodicity => 'm',
    start_date              => DateTime->from_kivitendo('01.01.2014'),
    end_date                => DateTime->from_kivitendo('30.06.2014'),
    terminated              => 1,
  });

run_tests(
  "periodic conf p=b ovp=m, starting July 1st of current year, ending November 30", 1,
  [ 1999.98, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'b',
    order_value_periodicity => 'm',
    start_date              => DateTime->from_kivitendo('01.07.2014'),
    end_date                => DateTime->from_kivitendo('30.11.2014'),
    terminated              => 1,
  });

run_tests(
  "periodic conf p=b ovp=m, starting May 1st of current year, ending next year", 1,
  [ 3999.96, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'b',
    order_value_periodicity => 'm',
    start_date              => DateTime->from_kivitendo('01.05.2014'),
    end_date                => DateTime->from_kivitendo('30.06.2015'),
    terminated              => 1,
  });

run_tests(
  "periodic conf p=b ovp=m, starting November 1 in previous year, ending April 30", 1,
  [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
  periodic_invoices_config  => {
    periodicity             => 'b',
    order_value_periodicity => 'm',
    terminated              => 1,
    start_date              => DateTime->from_kivitendo('01.11.2013'),
    end_date                => DateTime->from_kivitendo('30.04.2014'),
  });


done_testing();
