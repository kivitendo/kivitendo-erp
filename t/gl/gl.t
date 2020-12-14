use strict;
use Test::More tests => 8;

use lib 't';
use Support::TestSetup;
use Carp;
use Test::Exception;
use SL::DB::Chart;
use SL::DB::TaxKey;
use SL::DB::GLTransaction;
use Data::Dumper;
use SL::DBUtils qw(selectall_hashref_query);

Support::TestSetup::login();

clear_up();

my $cash           = SL::DB::Manager::Chart->find_by( description => 'Kasse'          );
my $bank           = SL::DB::Manager::Chart->find_by( description => 'Bank'           );
my $betriebsbedarf = SL::DB::Manager::Chart->find_by( description => 'Betriebsbedarf' );

my $tax_9 = SL::DB::Manager::Tax->find_by(taxkey => 9, rate => 0.19);
my $tax_8 = SL::DB::Manager::Tax->find_by(taxkey => 8, rate => 0.07);
my $tax_0 = SL::DB::Manager::Tax->find_by(taxkey => 0, rate => 0.00);

my $dbh = SL::DB->client->dbh;

# example with chaining of add_chart_booking
my $gl_transaction = SL::DB::GLTransaction->new(
  taxincluded => 1,
  reference   => 'bank/cash',
  description => 'bank/cash',
  transdate   => DateTime->today_local,
)->add_chart_booking(
  chart  => $cash,
  credit => 100,
  tax_id => $tax_0->id,
)->add_chart_booking(
  chart  => $bank,
  debit  => 100,
  tax_id => $tax_0->id,
)->post;

# example where bookings is prepared separately as an arrayref
my $gl_transaction_2 = SL::DB::GLTransaction->new(
  reference   => 'betriebsbedarf several rows',
  description => 'betriebsbedarf',
  taxincluded => 1,
  transdate   => DateTime->today_local,
);

my $bookings = [
                {
                  chart  => $betriebsbedarf,
                  memo   => 'foo 1',
                  source => 'foo 1',
                  debit  => 119,
                  tax_id => $tax_9->id,
                },
                {
                  chart  => $betriebsbedarf,
                  memo   => 'foo 2',
                  source => 'foo 2',
                  debit  => 119,
                  tax_id => $tax_9->id,
                },
                {
                  chart  => $cash,
                  credit => 238,
                  memo   => 'foo 1+2',
                  source => 'foo 1+2',
                  tax_id => $tax_0->id,
                },
               ];
$gl_transaction_2->add_chart_booking(%{$_}) foreach @{ $bookings };
$gl_transaction_2->post;


# example where add_chart_booking is called via a foreach
my $gl_transaction_3 = SL::DB::GLTransaction->new(
  reference   => 'betriebsbedarf tax included',
  description => 'bar',
  taxincluded => 1,
  transdate   => DateTime->today_local,
);
$gl_transaction_3->add_chart_booking(%{$_}) foreach (
    {
      chart  => $betriebsbedarf,
      debit  => 119,
      tax_id => $tax_9->id,
    },
    {
      chart  => $betriebsbedarf,
      debit  => 107,
      tax_id => $tax_8->id,
    },
    {
      chart  => $betriebsbedarf,
      debit  => 100,
      tax_id => $tax_0->id,
    },
    {
      chart  => $cash,
      credit => 326,
      tax_id => $tax_0->id,
    },
);
$gl_transaction_3->post;

my $gl_transaction_4 = SL::DB::GLTransaction->new(
  reference   => 'betriebsbedarf tax not included',
  description => 'bar',
  taxincluded => 0,
  transdate   => DateTime->today_local,
);
$gl_transaction_4->add_chart_booking(%{$_}) foreach (
    {
      chart  => $betriebsbedarf,
      debit  => 100,
      tax_id => $tax_9->id,
    },
    {
      chart  => $betriebsbedarf,
      debit  => 100,
      tax_id => $tax_8->id,
    },
    {
      chart  => $betriebsbedarf,
      debit  => 100,
      tax_id => $tax_0->id,
    },
    {
      chart  => $cash,
      credit => 326,
      tax_id => $tax_0->id,
    },
);
$gl_transaction_4->post;

is(SL::DB::Manager::GLTransaction->get_all_count(), 4, "gl transactions created ok");

is_deeply(&get_account_balances,
          [
            {
              'accno' => '1000',
              'sum' => '990.00000'
            },
            {
              'accno' => '1200',
              'sum' => '-100.00000'
            },
            {
              'accno' => '1571',
              'sum' => '-14.00000'
            },
            {
              'accno' => '1576',
              'sum' => '-76.00000'
            },
            {
              'accno' => '4980',
              'sum' => '-800.00000'
            }
          ],
          "chart balances ok"
         );


note('testing subcent');

my $gl_transaction_5_taxinc = SL::DB::GLTransaction->new(
  taxincluded => 1,
  reference   => 'subcent tax included',
  description => 'subcent tax included',
  transdate   => DateTime->today_local,
)->add_chart_booking(
  chart  => $betriebsbedarf,
  debit  => 0.02,
  tax_id => $tax_9->id,
)->add_chart_booking(
  chart  => $cash,
  credit => 0.02,
  tax_id => $tax_0->id,
)->post;

my $gl_transaction_5_taxnoinc = SL::DB::GLTransaction->new(
  taxincluded => 0,
  reference   => 'subcent tax not included',
  description => 'subcent tax not included',
  transdate   => DateTime->today_local,
)->add_chart_booking(
  chart  => $betriebsbedarf,
  debit  => 0.02,
  tax_id => $tax_9->id,
)->add_chart_booking(
  chart  => $cash,
  credit => 0.02,
  tax_id => $tax_0->id,
)->post;

my $gl_transaction_6_taxinc = SL::DB::GLTransaction->new(
  taxincluded => 1,
  reference   => 'cent tax included',
  description => 'cent tax included',
  transdate   => DateTime->today_local,
)->add_chart_booking(
  chart  => $betriebsbedarf,
  debit  => 0.05,
  tax_id => $tax_9->id,
)->add_chart_booking(
  chart  => $cash,
  credit => 0.05,
  tax_id => $tax_0->id,
)->post;

my $gl_transaction_6_taxnoinc = SL::DB::GLTransaction->new(
  taxincluded => 0,
  reference   => 'cent tax included',
  description => 'cent tax included',
  transdate   => DateTime->today_local,
)->add_chart_booking(
  chart  => $betriebsbedarf,
  debit  => 0.04,
  tax_id => $tax_9->id,
)->add_chart_booking(
  chart  => $cash,
  credit => 0.05,
  tax_id => $tax_0->id,
)->post;

is(SL::DB::Manager::GLTransaction->get_all_count(), 8, "gl transactions created ok");


is_deeply(&get_account_balances,
          [
            {
              'accno' => '1000',
              'sum' => '990.14000'
            },
            {
              'accno' => '1200',
              'sum' => '-100.00000'
            },
            {
              'accno' => '1571',
              'sum' => '-14.00000'
            },
            {
              'accno' => '1576',
              'sum' => '-76.02000'
            },
            {
              'accno' => '4980',
              'sum' => '-800.12000'
            }
          ],
          "chart balances ok"
         );

note "testing automatic tax 19%";

my $gl_transaction_7 = SL::DB::GLTransaction->new(
  reference   => 'betriebsbedarf tax not included',
  description => 'bar',
  taxincluded => 0,
  transdate   => DateTime->new(year => 2019, month => 12, day => 30),
);

$gl_transaction_7->add_chart_booking(%{$_}) foreach (
    {
      chart  => $betriebsbedarf,
      debit  => 100,
    },
    {
      chart  => $betriebsbedarf,
      debit  => 100,
    },
    {
      chart  => $betriebsbedarf,
      debit  => 100,
      tax_id => $tax_0->id,
    },
    {
      chart  => $cash,
      credit => 338,
    },
);
$gl_transaction_7->post;

is(SL::DB::Manager::GLTransaction->get_all_count(), 9, "gl transactions created ok");
is_deeply(&get_account_balances,
          [
            {
              'accno' => '1000',
              'sum' => '1328.14000'
            },
            {
              'accno' => '1200',
              'sum' => '-100.00000'
            },
            {
              'accno' => '1571',
              'sum' => '-14.00000'
            },
            {
              'accno' => '1576',
              'sum' => '-114.02000'
            },
            {
              'accno' => '4980',
              'sum' => '-1100.12000'
            }
          ],
          "chart balances ok"
         );

note "testing automatic tax 16%";

my $gl_transaction_8 = SL::DB::GLTransaction->new(
  reference   => 'betriebsbedarf tax not included',
  description => 'bar',
  taxincluded => 0,
  transdate   => DateTime->new(year => 2020, month => 12, day => 31),
);

$gl_transaction_8->add_chart_booking(%{$_}) foreach (
    {
      chart  => $betriebsbedarf,
      debit  => 100,
    },
    {
      chart  => $betriebsbedarf,
      debit  => 100,
    },
    {
      chart  => $betriebsbedarf,
      debit  => 100,
      tax_id => $tax_0->id,
    },
    {
      chart  => $cash,
      credit => 332,
    },
);
$gl_transaction_8->post;

is(SL::DB::Manager::GLTransaction->get_all_count(), 10, "gl transactions created ok");
is_deeply(&get_account_balances,
          [
            {
              'accno' => '1000',
              'sum' => '1660.14000'
            },
            {
              'accno' => '1200',
              'sum' => '-100.00000'
            },
            {
              'accno' => '1571',
              'sum' => '-14.00000'
            },
            {
              'accno' => '1575',
              'sum' => '-32.00000'
            },
            {
              'accno' => '1576',
              'sum' => '-114.02000'
            },
            {
              'accno' => '4980',
              'sum' => '-1400.12000'
            }
          ],
          "chart balances ok"
         );

done_testing;
clear_up();

1;

sub clear_up {
  "SL::DB::Manager::${_}"->delete_all(all => 1) for qw(
                                                       AccTransaction
                                                       GLTransaction
                                                      );
};

sub get_account_balances {
  my $query = <<SQL;
  select c.accno,
         sum(a.amount)
    from acc_trans a
         left join chart c on (c.id = a.chart_id)
group by c.accno
order by c.accno;
SQL

  my $result = selectall_hashref_query($::form, $dbh, $query);
  return $result;
};
