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

use Test::More tests => 80;

use lib 't';
use strict;
use utf8;

use Carp;
use Support::TestSetup;

use_ok 'SL::BackgroundJob::CreatePeriodicInvoices';
use_ok 'SL::DB::Chart';
use_ok 'SL::DB::Customer';
use_ok 'SL::DB::Default';
use_ok 'SL::DB::Invoice';
use_ok 'SL::DB::Order';
use_ok 'SL::DB::Part';
use_ok 'SL::DB::TaxZone';

Support::TestSetup::login();

our ($ar_chart, $buchungsgruppe, $currency_id, $customer, $employee, $order, $part, $tax_zone, $unit, @invoices);

sub init_common_state {
  $ar_chart       = SL::DB::Manager::Chart->find_by(accno => '1400')                        || croak "No AR chart";
  $buchungsgruppe = SL::DB::Manager::Buchungsgruppe->find_by(description => 'Standard 19%') || croak "No accounting group";
  $currency_id    = SL::DB::Default->get->currency_id;
  $employee       = SL::DB::Manager::Employee->current                                      || croak "No employee";
  $tax_zone       = SL::DB::Manager::TaxZone->find_by( description => 'Inland')             || croak "No taxzone";
  $unit           = SL::DB::Manager::Unit->find_by(name => 'psch')                          || croak "No unit";
}

sub clear_up {
  "SL::DB::Manager::${_}"->delete_all(all => 1) for qw(InvoiceItem Invoice OrderItem Order Customer Part);
};

sub create_invoices {
  my %params = @_;

  $params{$_} ||= {} for qw(customer part tax order orderitem periodic_invoices_config);

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
    periodic_invoices_config => {
      active                 => 1,
      ar_chart_id            => $ar_chart->id,
      %{ $params{periodic_invoices_config} },
    },
    %{ $params{order} },
  );

  $order->calculate_prices_and_taxes;

  ok($order->save(cascade => 1));

  SL::BackgroundJob::CreatePeriodicInvoices->new->run(SL::DB::BackgroundJob->new);

  @invoices = @{ SL::DB::Manager::Invoice->get_all(sort_by => [ qw(id) ]) };
}

sub are_invoices {
  my ($description, @exp_date_netamount_pairs) = @_;

  is scalar(@invoices), scalar(@exp_date_netamount_pairs), "${description} number of invoices " . scalar(@exp_date_netamount_pairs);

  my @actual_date_netamount_pairs = map { [ $_->transaction_description, $_->netamount * 1 ] } @invoices;
  is_deeply \@actual_date_netamount_pairs, \@exp_date_netamount_pairs, "${description} date/netamount of created invoices";
}

init_common_state();

# order_value_periodicity=y
create_invoices(periodic_invoices_config => { periodicity => 'm', order_value_periodicity => 'y', start_date => DateTime->from_kivitendo('01.01.2013') });
are_invoices 'p=m ovp=y',[ '01.01.2013', 27.78 ], [ '01.02.2013', 27.78 ], [ '01.03.2013', 27.78 ], [ '01.04.2013', 27.78 ],
                         [ '01.05.2013', 27.78 ], [ '01.06.2013', 27.78 ], [ '01.07.2013', 27.78 ], [ '01.08.2013', 27.78 ],
                         [ '01.09.2013', 27.78 ], [ '01.10.2013', 27.78 ], [ '01.11.2013', 27.78 ], [ '01.12.2013', 27.75 ],
                         [ '01.01.2014', 27.78 ], [ '01.02.2014', 27.78 ], [ '01.03.2014', 27.78 ];

create_invoices(periodic_invoices_config => { periodicity => 'q', order_value_periodicity => 'y', start_date => DateTime->from_kivitendo('01.01.2013') });
are_invoices 'p=q ovp=y',[ '01.01.2013', 83.33 ], [ '01.04.2013', 83.33 ], [ '01.07.2013', 83.33 ], [ '01.10.2013', 83.34 ], [ '01.01.2014', 83.33 ];

create_invoices(periodic_invoices_config => { periodicity => 'b', order_value_periodicity => 'y', start_date => DateTime->from_kivitendo('01.01.2013') });
are_invoices 'p=b ovp=y',[ '01.01.2013', 166.67 ], [ '01.07.2013', 166.66 ], [ '01.01.2014', 166.67 ];

create_invoices(periodic_invoices_config => { periodicity => 'y', order_value_periodicity => 'y', start_date => DateTime->from_kivitendo('01.01.2013') });
are_invoices 'p=y ovp=y',[ '01.01.2013', 333.33 ], [ '01.01.2014', 333.33 ];

# order_value_periodicity=b
create_invoices(periodic_invoices_config => { periodicity => 'm', order_value_periodicity => 'b', start_date => DateTime->from_kivitendo('01.01.2013') });
are_invoices 'p=m ovp=b',[ '01.01.2013', 55.56 ], [ '01.02.2013', 55.56 ], [ '01.03.2013', 55.56 ], [ '01.04.2013', 55.56 ],
                         [ '01.05.2013', 55.56 ], [ '01.06.2013', 55.53 ], [ '01.07.2013', 55.56 ], [ '01.08.2013', 55.56 ],
                         [ '01.09.2013', 55.56 ], [ '01.10.2013', 55.56 ], [ '01.11.2013', 55.56 ], [ '01.12.2013', 55.53 ],
                         [ '01.01.2014', 55.56 ], [ '01.02.2014', 55.56 ], [ '01.03.2014', 55.56 ];

create_invoices(periodic_invoices_config => { periodicity => 'q', order_value_periodicity => 'b', start_date => DateTime->from_kivitendo('01.01.2013') });
are_invoices 'p=q ovp=b',[ '01.01.2013', 166.67 ], [ '01.04.2013', 166.66 ], [ '01.07.2013', 166.67 ], [ '01.10.2013', 166.66 ], [ '01.01.2014', 166.67 ];

create_invoices(periodic_invoices_config => { periodicity => 'b', order_value_periodicity => 'b', start_date => DateTime->from_kivitendo('01.01.2013') });
are_invoices 'p=b ovp=b',[ '01.01.2013', 333.33 ], [ '01.07.2013', 333.33 ], [ '01.01.2014', 333.33 ];

create_invoices(periodic_invoices_config => { periodicity => 'y', order_value_periodicity => 'b', start_date => DateTime->from_kivitendo('01.01.2013') });
are_invoices 'p=y ovp=b',[ '01.01.2013', 666.66 ], [ '01.01.2014', 666.66 ];

# order_value_periodicity=q
create_invoices(periodic_invoices_config => { periodicity => 'm', order_value_periodicity => 'q', start_date => DateTime->from_kivitendo('01.01.2013') });
are_invoices 'p=m ovp=q',[ '01.01.2013', 111.11 ], [ '01.02.2013', 111.11 ], [ '01.03.2013', 111.11 ], [ '01.04.2013', 111.11 ],
                         [ '01.05.2013', 111.11 ], [ '01.06.2013', 111.11 ], [ '01.07.2013', 111.11 ], [ '01.08.2013', 111.11 ],
                         [ '01.09.2013', 111.11 ], [ '01.10.2013', 111.11 ], [ '01.11.2013', 111.11 ], [ '01.12.2013', 111.11 ],
                         [ '01.01.2014', 111.11 ], [ '01.02.2014', 111.11 ], [ '01.03.2014', 111.11 ];

create_invoices(periodic_invoices_config => { periodicity => 'q', order_value_periodicity => 'q', start_date => DateTime->from_kivitendo('01.01.2013') });
are_invoices 'p=q ovp=q',[ '01.01.2013', 333.33 ], [ '01.04.2013', 333.33 ], [ '01.07.2013', 333.33 ], [ '01.10.2013', 333.33 ], [ '01.01.2014', 333.33 ];

create_invoices(periodic_invoices_config => { periodicity => 'b', order_value_periodicity => 'q', start_date => DateTime->from_kivitendo('01.01.2013') });
are_invoices 'p=b ovp=q',[ '01.01.2013', 666.66 ], [ '01.07.2013', 666.66 ], [ '01.01.2014', 666.66 ];

create_invoices(periodic_invoices_config => { periodicity => 'y', order_value_periodicity => 'q', start_date => DateTime->from_kivitendo('01.01.2013') });
are_invoices 'p=y ovp=q',[ '01.01.2013', 1333.32 ], [ '01.01.2014', 1333.32 ];

# order_value_periodicity=m
create_invoices(periodic_invoices_config => { periodicity => 'm', order_value_periodicity => 'm', start_date => DateTime->from_kivitendo('01.01.2013') });
are_invoices 'p=m ovp=m',[ '01.01.2013', 333.33 ], [ '01.02.2013', 333.33 ], [ '01.03.2013', 333.33 ], [ '01.04.2013', 333.33 ],
                         [ '01.05.2013', 333.33 ], [ '01.06.2013', 333.33 ], [ '01.07.2013', 333.33 ], [ '01.08.2013', 333.33 ],
                         [ '01.09.2013', 333.33 ], [ '01.10.2013', 333.33 ], [ '01.11.2013', 333.33 ], [ '01.12.2013', 333.33 ],
                         [ '01.01.2014', 333.33 ], [ '01.02.2014', 333.33 ], [ '01.03.2014', 333.33 ];

create_invoices(periodic_invoices_config => { periodicity => 'q', order_value_periodicity => 'm', start_date => DateTime->from_kivitendo('01.01.2013') });
are_invoices 'p=q ovp=m',[ '01.01.2013', 999.99 ], [ '01.04.2013', 999.99 ], [ '01.07.2013', 999.99 ], [ '01.10.2013', 999.99 ], [ '01.01.2014', 999.99 ];

create_invoices(periodic_invoices_config => { periodicity => 'b', order_value_periodicity => 'm', start_date => DateTime->from_kivitendo('01.01.2013') });
are_invoices 'p=b ovp=m',[ '01.01.2013', 1999.98 ], [ '01.07.2013', 1999.98 ], [ '01.01.2014', 1999.98 ];

create_invoices(periodic_invoices_config => { periodicity => 'y', order_value_periodicity => 'm', start_date => DateTime->from_kivitendo('01.01.2013') });
are_invoices 'p=y ovp=m',[ '01.01.2013', 3999.96 ], [ '01.01.2014', 3999.96 ];

# order_value_periodicity=2
create_invoices(periodic_invoices_config => { periodicity => 'm', order_value_periodicity => '2', start_date => DateTime->from_kivitendo('01.01.2012') });
are_invoices 'p=m ovp=2',[ '01.01.2012', 13.89 ], [ '01.02.2012', 13.89 ], [ '01.03.2012', 13.89 ], [ '01.04.2012', 13.89 ],
                         [ '01.05.2012', 13.89 ], [ '01.06.2012', 13.89 ], [ '01.07.2012', 13.89 ], [ '01.08.2012', 13.89 ],
                         [ '01.09.2012', 13.89 ], [ '01.10.2012', 13.89 ], [ '01.11.2012', 13.89 ], [ '01.12.2012', 13.89 ],
                         [ '01.01.2013', 13.89 ], [ '01.02.2013', 13.89 ], [ '01.03.2013', 13.89 ], [ '01.04.2013', 13.89 ],
                         [ '01.05.2013', 13.89 ], [ '01.06.2013', 13.89 ], [ '01.07.2013', 13.89 ], [ '01.08.2013', 13.89 ],
                         [ '01.09.2013', 13.89 ], [ '01.10.2013', 13.89 ], [ '01.11.2013', 13.89 ], [ '01.12.2013', 13.86 ],
                         [ '01.01.2014', 13.89 ], [ '01.02.2014', 13.89 ], [ '01.03.2014', 13.89 ];

create_invoices(periodic_invoices_config => { periodicity => 'q', order_value_periodicity => '2', start_date => DateTime->from_kivitendo('01.01.2012') });
are_invoices 'p=q ovp=2',[ '01.01.2012', 41.67 ], [ '01.04.2012', 41.67 ], [ '01.07.2012', 41.67 ], [ '01.10.2012', 41.67 ],
                         [ '01.01.2013', 41.67 ], [ '01.04.2013', 41.67 ], [ '01.07.2013', 41.67 ], [ '01.10.2013', 41.64 ],
                         [ '01.01.2014', 41.67 ];

create_invoices(periodic_invoices_config => { periodicity => 'b', order_value_periodicity => '2', start_date => DateTime->from_kivitendo('01.01.2012') });
are_invoices 'p=b ovp=2',[ '01.01.2012', 83.33 ], [ '01.07.2012', 83.33 ], [ '01.01.2013', 83.33 ], [ '01.07.2013', 83.34 ], [ '01.01.2014', 83.33 ];

create_invoices(periodic_invoices_config => { periodicity => 'y', order_value_periodicity => '2', start_date => DateTime->from_kivitendo('01.01.2012') });
are_invoices 'p=y ovp=2',[ '01.01.2012', 166.67 ], [ '01.01.2013', 166.66 ], [ '01.01.2014', 166.67 ];

# order_value_periodicity=5
create_invoices(periodic_invoices_config => { periodicity => 'm', order_value_periodicity => '5', start_date => DateTime->from_kivitendo('01.01.2009') });
are_invoices 'p=m ovp=5',[ '01.01.2009',  5.56 ], [ '01.02.2009',  5.56 ], [ '01.03.2009',  5.56 ], [ '01.04.2009',  5.56 ],
                         [ '01.05.2009',  5.56 ], [ '01.06.2009',  5.56 ], [ '01.07.2009',  5.56 ], [ '01.08.2009',  5.56 ],
                         [ '01.09.2009',  5.56 ], [ '01.10.2009',  5.56 ], [ '01.11.2009',  5.56 ], [ '01.12.2009',  5.56 ],
                         [ '01.01.2010',  5.56 ], [ '01.02.2010',  5.56 ], [ '01.03.2010',  5.56 ], [ '01.04.2010',  5.56 ],
                         [ '01.05.2010',  5.56 ], [ '01.06.2010',  5.56 ], [ '01.07.2010',  5.56 ], [ '01.08.2010',  5.56 ],
                         [ '01.09.2010',  5.56 ], [ '01.10.2010',  5.56 ], [ '01.11.2010',  5.56 ], [ '01.12.2010',  5.56 ],
                         [ '01.01.2011',  5.56 ], [ '01.02.2011',  5.56 ], [ '01.03.2011',  5.56 ], [ '01.04.2011',  5.56 ],
                         [ '01.05.2011',  5.56 ], [ '01.06.2011',  5.56 ], [ '01.07.2011',  5.56 ], [ '01.08.2011',  5.56 ],
                         [ '01.09.2011',  5.56 ], [ '01.10.2011',  5.56 ], [ '01.11.2011',  5.56 ], [ '01.12.2011',  5.56 ],
                         [ '01.01.2012',  5.56 ], [ '01.02.2012',  5.56 ], [ '01.03.2012',  5.56 ], [ '01.04.2012',  5.56 ],
                         [ '01.05.2012',  5.56 ], [ '01.06.2012',  5.56 ], [ '01.07.2012',  5.56 ], [ '01.08.2012',  5.56 ],
                         [ '01.09.2012',  5.56 ], [ '01.10.2012',  5.56 ], [ '01.11.2012',  5.56 ], [ '01.12.2012',  5.56 ],
                         [ '01.01.2013',  5.56 ], [ '01.02.2013',  5.56 ], [ '01.03.2013',  5.56 ], [ '01.04.2013',  5.56 ],
                         [ '01.05.2013',  5.56 ], [ '01.06.2013',  5.56 ], [ '01.07.2013',  5.56 ], [ '01.08.2013',  5.56 ],
                         [ '01.09.2013',  5.56 ], [ '01.10.2013',  5.56 ], [ '01.11.2013',  5.56 ], [ '01.12.2013',  5.29 ],
                         [ '01.01.2014',  5.56 ], [ '01.02.2014',  5.56 ], [ '01.03.2014',  5.56 ];

create_invoices(periodic_invoices_config => { periodicity => 'q', order_value_periodicity => '5', start_date => DateTime->from_kivitendo('01.01.2009') });
are_invoices 'p=q ovp=5',[ '01.01.2009', 16.67 ], [ '01.04.2009', 16.67 ], [ '01.07.2009', 16.67 ], [ '01.10.2009', 16.67 ],
                         [ '01.01.2010', 16.67 ], [ '01.04.2010', 16.67 ], [ '01.07.2010', 16.67 ], [ '01.10.2010', 16.67 ],
                         [ '01.01.2011', 16.67 ], [ '01.04.2011', 16.67 ], [ '01.07.2011', 16.67 ], [ '01.10.2011', 16.67 ],
                         [ '01.01.2012', 16.67 ], [ '01.04.2012', 16.67 ], [ '01.07.2012', 16.67 ], [ '01.10.2012', 16.67 ],
                         [ '01.01.2013', 16.67 ], [ '01.04.2013', 16.67 ], [ '01.07.2013', 16.67 ], [ '01.10.2013', 16.60 ],
                         [ '01.01.2014', 16.67 ];

create_invoices(periodic_invoices_config => { periodicity => 'b', order_value_periodicity => '5', start_date => DateTime->from_kivitendo('01.01.2009') });
are_invoices 'p=b ovp=5',[ '01.01.2009', 33.33 ], [ '01.07.2009', 33.33 ],
                         [ '01.01.2010', 33.33 ], [ '01.07.2010', 33.33 ],
                         [ '01.01.2011', 33.33 ], [ '01.07.2011', 33.33 ],
                         [ '01.01.2012', 33.33 ], [ '01.07.2012', 33.33 ],
                         [ '01.01.2013', 33.33 ], [ '01.07.2013', 33.36 ],
                         [ '01.01.2014', 33.33 ];

create_invoices(periodic_invoices_config => { periodicity => 'y', order_value_periodicity => '5', start_date => DateTime->from_kivitendo('01.01.2009') });
are_invoices 'p=y ovp=5',[ '01.01.2009', 66.67 ], [ '01.01.2010', 66.67 ], [ '01.01.2011', 66.67 ], [ '01.01.2012', 66.67 ], [ '01.01.2013', 66.65 ], [ '01.01.2014', 66.67 ];

clear_up();

done_testing();
