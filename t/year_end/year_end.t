use strict;
use warnings;

use Test::More tests => 18;
use lib 't';
use utf8;

use Carp;
use Data::Dumper;
use Support::TestSetup;
use Test::Exception;
use SL::DBUtils qw(selectall_hashref_query);

use SL::DB::BankAccount;
use SL::DB::Chart;
use SL::DB::Invoice;
use SL::DB::PurchaseInvoice;

use SL::Dev::Record qw(create_ar_transaction create_ap_transaction create_gl_transaction);

use SL::Controller::YearEndTransactions;
  
Support::TestSetup::login();

clear_up();

# comments:

# * in the default test client the tax accounts are configured as I/E rather than A/L
# * also the default test client has the accounting method "cash" rather than "accrual"
#   (Ist-versteuerung, rather than Soll-versteuerung)

# use 2019 instead of 2020 because of tax changes in Germany (19/16 and 7/5) because we check for account sums
my $year = 2019;
my $start_of_year = DateTime->new(year => $year, month => 01, day => 01);
my $booking_date  = DateTime->new(year => $year, month => 12, day => 22);

note('configuring accounts');
my $bank_account = SL::DB::BankAccount->new(
  account_number  => '123',
  bank_code       => '123',
  iban            => '123',
  bic             => '123',
  bank            => '123',
  chart_id        => SL::DB::Manager::Chart->find_by(description => 'Bank')->id,
  name            => SL::DB::Manager::Chart->find_by(description => 'Bank')->description,
)->save;

my $profit_account = SL::DB::Manager::Chart->find_by(accno => '0890') //
                     SL::DB::Chart->new(
                       accno          => '0890',
                       description    => 'Gewinnvortrag vor Verwendung',
                       charttype      => 'A',
                       category       => 'Q',
                       link           => '',
                       taxkey_id      => '0',
                       datevautomatik => 'f',
                     )->save;

my $loss_account = SL::DB::Manager::Chart->find_by(accno => '0868') //
                   SL::DB::Chart->new(
                     accno          => '0868',
                     description    => 'Verlustvortrag vor Verwendung',
                     charttype      => 'A',
                     category       => 'Q',
                     link           => '',
                     taxkey_id      => '0',
                     datevautomatik => 'f',
                   )->save;

my $carry_over_chart = SL::DB::Manager::Chart->find_by(accno => 9000); 
my $income_chart     = SL::DB::Manager::Chart->find_by(accno => '8400'); # income 19%, taxkey 3
my $bank             = SL::DB::Manager::Chart->find_by(description => 'Bank');
my $cash             = SL::DB::Manager::Chart->find_by(description => 'Kasse');
my $privateinlagen   = SL::DB::Manager::Chart->find_by(description => 'Privateinlagen');
my $betriebsbedarf   = SL::DB::Manager::Chart->find_by(description => 'Betriebsbedarf'); 

my $dbh = SL::DB->client->dbh;
$dbh->do('UPDATE defaults SET carry_over_account_chart_id     = ' . $carry_over_chart->id);
$dbh->do('UPDATE defaults SET profit_carried_forward_chart_id = ' . $profit_account->id);
$dbh->do('UPDATE defaults SET loss_carried_forward_chart_id   = ' . $loss_account->id);


note('creating transactions');
my $ar_transaction = create_ar_transaction(
  taxincluded => 0,
  transdate   => $booking_date,
  bookings    => [
                   {
                     chart  => $income_chart, # income 19%, taxkey 3
                     amount => 140,
                   }
                 ],
);
  
$ar_transaction->pay_invoice(
                              chart_id     => $bank_account->chart_id,
                              amount       => $ar_transaction->amount,
                              transdate    => $booking_date,
                              payment_type => 'without_skonto',
                            );

my $ar_transaction2 = create_ar_transaction(
  taxincluded => 1,
  transdate   => $booking_date,
  bookings    => [
                   {
                     chart  => $income_chart, # income 19%, taxkey 3
                     amount => 166.60,
                   }
                 ],
);

my $ap_transaction = create_ap_transaction(
  taxincluded => 0,
  transdate   => $booking_date,
  bookings    => [
                   {
                     chart  => SL::DB::Manager::Chart->find_by( accno => '3400' ), # Wareneingang 19%, taxkey 9
                     amount => 100,
                   }
                 ],
);

gl_booking(40, $start_of_year, 'foo', 'bar', $bank, $privateinlagen, 1, 0);

is(SL::DB::Manager::AccTransaction->get_all_count(                                ), 13, 'acc_trans transactions created ok');
is(SL::DB::Manager::AccTransaction->get_all_count(where => [ ob_transaction => 1 ]),  2, 'acc_trans ob_transactions created ok');
is(SL::DB::Manager::AccTransaction->get_all_count(where => [ cb_transaction => 1 ]),  0, 'no cb_transactions created ok');

is_deeply( &get_account_balances, 
           [
             {
               'accno'        => '1200',
               'account_type' => 'asset_account',
               'sum'          => '-206.60000'
             },
             {
               'accno'        => '1400',
               'account_type' => 'asset_account',
               'sum'          => '-166.60000'
             },
             {
               'accno'        => '1600',
               'account_type' => 'asset_account',
               'sum'          => '119.00000'
             },
             {
               'accno'        => '1890',
               'account_type' => 'asset_account',
               'sum'          => '40.00000'
             },
             {
               'accno'        => '1576',
               'account_type' => 'profit_loss_account',
               'sum'          => '-19.00000'
             },
             {
               'accno'        => '1776',
               'account_type' => 'profit_loss_account',
               'sum'          => '53.20000'
             },
             {
               'accno'        => '3400',
               'account_type' => 'profit_loss_account',
               'sum'          => '-100.00000'
             },
             {
               'accno'        => '8400',
               'account_type' => 'profit_loss_account',
               'sum'          => '280.00000'
             }
           ],
           'account balances before year_end bookings ok',
);

#  accno |    account_type     |    sum     
# -------+---------------------+------------
#  1200  | asset_account       | -206.60000
#  1400  | asset_account       | -166.60000
#  1600  | asset_account       |  119.00000
#  1890  | asset_account       |   40.00000
#  1576  | profit_loss_account |  -19.00000
#  1776  | profit_loss_account |   53.20000
#  3400  | profit_loss_account | -100.00000
#  8400  | profit_loss_account |  280.00000


note('running year-end transactions');
my $start_date = DateTime->new(year => $year, month => 1,  day => 1);  
my $cb_date    = DateTime->new(year => $year, month => 12, day => 31);
my $ob_date    = $cb_date->clone->add(days => 1);

SL::Controller::YearEndTransactions::_year_end_bookings( start_date => $start_date,
                                                         cb_date    => $cb_date,
                                                       );

is(SL::DB::Manager::AccTransaction->get_all_count(where => [ cb_transaction => 1 ]), 14, 'acc_trans cb_transactions created ok');
is(SL::DB::Manager::AccTransaction->get_all_count(where => [ ob_transaction => 1 ]), 10, 'acc_trans ob_transactions created ok');
is(SL::DB::Manager::GLTransaction->get_all_count( where => [ cb_transaction => 1 ]),  5, 'GL cb_transactions created ok');
is(SL::DB::Manager::GLTransaction->get_all_count( where => [ ob_transaction => 1 ]),  4, 'GL ob_transactions created ok');

my $final_account_balances = [
                               {
                                 'accno' => '0890',
                                 'amount' => undef,
                                 'amount_with_cb' => '0.00000',
                                 'cat' => 'Q',
                                 'cb_amount' => '0.00000',
                                 'ob_amount' => undef,
                                 'ob_next_year' => '214.20000',
                                 'type' => 'asset',
                                 'year_end_amount' => undef
                               },
                               {
                                 'accno' => '1200',
                                 'amount' => '-166.60000',
                                 'amount_with_cb' => '0.00000',
                                 'cat' => 'A',
                                 'cb_amount' => '-206.60000',
                                 'ob_amount' => '-40.00000',
                                 'ob_next_year' => '-206.60000',
                                 'type' => 'asset',
                                 'year_end_amount' => '-206.60000'
                               },
                               {
                                 'accno' => '1400',
                                 'amount' => '-166.60000',
                                 'amount_with_cb' => '0.00000',
                                 'cat' => 'A',
                                 'cb_amount' => '-166.60000',
                                 'ob_amount' => undef,
                                 'ob_next_year' => '-166.60000',
                                 'type' => 'asset',
                                 'year_end_amount' => '-166.60000'
                               },
                               {
                                 'accno' => '1600',
                                 'amount' => '119.00000',
                                 'amount_with_cb' => '0.00000',
                                 'cat' => 'L',
                                 'cb_amount' => '119.00000',
                                 'ob_amount' => undef,
                                 'ob_next_year' => '119.00000',
                                 'type' => 'asset',
                                 'year_end_amount' => '119.00000'
                               },
                               {
                                 'accno' => '1890',
                                 'amount' => undef,
                                 'amount_with_cb' => '0.00000',
                                 'cat' => 'Q',
                                 'cb_amount' => '40.00000',
                                 'ob_amount' => '40.00000',
                                 'ob_next_year' => '40.00000',
                                 'type' => 'asset',
                                 'year_end_amount' => '40.00000'
                               },
                               {
                                 'accno' => '9000',
                                 'amount' => undef,
                                 'amount_with_cb' => '0.00000',
                                 'cat' => 'A',
                                 'cb_amount' => '0.00000',
                                 'ob_amount' => undef,
                                 'ob_next_year' => '0.00000',
                                 'type' => 'asset',
                                 'year_end_amount' => undef
                               },
                               {
                                 'accno' => '1576',
                                 'amount' => '-19.00000',
                                 'amount_with_cb' => '0.00000',
                                 'cat' => 'E',
                                 'cb_amount' => '-19.00000',
                                 'ob_amount' => undef,
                                 'ob_next_year' => undef,
                                 'type' => 'pl',
                                 'year_end_amount' => '-19.00000'
                               },
                               {
                                 'accno' => '1776',
                                 'amount' => '53.20000',
                                 'amount_with_cb' => '0.00000',
                                 'cat' => 'I',
                                 'cb_amount' => '53.20000',
                                 'ob_amount' => undef,
                                 'ob_next_year' => undef,
                                 'type' => 'pl',
                                 'year_end_amount' => '53.20000'
                               },
                               {
                                 'accno' => '3400',
                                 'amount' => '-100.00000',
                                 'amount_with_cb' => '0.00000',
                                 'cat' => 'E',
                                 'cb_amount' => '-100.00000',
                                 'ob_amount' => undef,
                                 'ob_next_year' => undef,
                                 'type' => 'pl',
                                 'year_end_amount' => '-100.00000'
                               },
                               {
                                 'accno' => '8400',
                                 'amount' => '280.00000',
                                 'amount_with_cb' => '0.00000',
                                 'cat' => 'I',
                                 'cb_amount' => '280.00000',
                                 'ob_amount' => undef,
                                 'ob_next_year' => undef,
                                 'type' => 'pl',
                                 'year_end_amount' => '280.00000'
                               }
                             ];

# running _year_end_bookings several times shouldn't change the anything, the
# second and third run should be no-ops, at least while no further bookings where
# made

SL::Controller::YearEndTransactions::_year_end_bookings( start_date => $start_date,
                                                         cb_date    => $cb_date,
                                                       );

is(SL::DB::Manager::AccTransaction->get_all_count(where => [ cb_transaction => 1 ]), 14, 'acc_trans cb_transactions created ok');
is(SL::DB::Manager::AccTransaction->get_all_count(where => [ ob_transaction => 1 ]), 10, 'acc_trans ob_transactions created ok');
is(SL::DB::Manager::GLTransaction->get_all_count( where => [ cb_transaction => 1 ]),  5, 'GL cb_transactions created ok');
is(SL::DB::Manager::GLTransaction->get_all_count( where => [ ob_transaction => 1 ]),  4, 'GL ob_transactions created ok');


# all asset accounts should be the same, except 0890, which should be the sum of p/l-accounts
# all p/l account should be 0

#  accno |    account_type     |    sum     
# -------+---------------------+------------
#  0890  | asset_account       |  214.20000
#  1200  | asset_account       | -206.60000
#  1400  | asset_account       | -166.60000
#  1600  | asset_account       |  119.00000
#  1890  | asset_account       |   40.00000
#  9000  | asset_account       |    0.00000
#  1576  | profit_loss_account |    0.00000
#  1776  | profit_loss_account |    0.00000
#  3400  | profit_loss_account |    0.00000
#  8400  | profit_loss_account |    0.00000
# (10 rows)

is_deeply( &get_final_balances, 
           $final_account_balances,
           'balances after second year_end ok (nothing changed)');


# select c.accno,
#        c.description,
#        c.category as cat,
#        sum(a.amount     ) filter (where ob_transaction is true                              and a.transdate  < '2020-01-01') as ob_amount,
#        sum(a.amount     ) filter (where cb_transaction is false and ob_transaction is false and a.transdate  < '2020-01-01') as amount,
#        sum(a.amount     ) filter (where cb_transaction is false                             and a.transdate  < '2020-01-01') as year_end_amount,
#        sum(a.amount     ) filter (where                                                         a.transdate  < '2020-01-01') as amount_with_cb,
#        sum(a.amount * -1) filter (where cb_transaction is true                              and a.transdate  < '2020-01-01') as cb_amount,
#        sum(a.amount     ) filter (where ob_transaction is true                              and a.transdate >= '2020-01-01') as ob_next_year,
#        case when c.category = ANY( '{I,E}'     ) then 'pl'
#             when c.category = ANY( '{A,C,L,Q}' ) then 'asset'
#                                                  else null
#             end                                                                         as type
#   from acc_trans a
#        inner join chart c on (c.id = a.chart_id)
#  where     a.transdate >= '2019-01-01'
#        and a.transdate <= '2020-01-01'
#  group by c.id, c.accno, c.category
#  order by type, c.accno;
#  accno |             description             | cat | ob_amount |   amount   | year_end_amount | amount_with_cb | cb_amount  | ob_next_year | type  
# -------+-------------------------------------+-----+-----------+------------+-----------------+----------------+------------+--------------+-------
#  0890  | Gewinnvortrag vor Verwendung        | Q   |           |            |                 |        0.00000 |    0.00000 |    214.20000 | asset
#  1200  | Bank                                | A   | -40.00000 | -166.60000 |      -206.60000 |        0.00000 | -206.60000 |   -206.60000 | asset
#  1400  | Ford. a.Lieferungen und Leistungen  | A   |           | -166.60000 |      -166.60000 |        0.00000 | -166.60000 |   -166.60000 | asset
#  1600  | Verbindlichkeiten aus Lief.u.Leist. | L   |           |  119.00000 |       119.00000 |        0.00000 |  119.00000 |    119.00000 | asset
#  1890  | Privateinlagen                      | Q   |  40.00000 |            |        40.00000 |        0.00000 |   40.00000 |     40.00000 | asset
#  9000  | Saldenvorträge,Sachkonten           | A   |           |            |                 |        0.00000 |    0.00000 |      0.00000 | asset
#  1576  | Abziehbare Vorsteuer 19 %           | E   |           |  -19.00000 |       -19.00000 |        0.00000 |  -19.00000 |              | pl
#  1776  | Umsatzsteuer 19 %                   | I   |           |   53.20000 |        53.20000 |        0.00000 |   53.20000 |              | pl
#  3400  | Wareneingang 16%/19% Vorsteuer      | E   |           | -100.00000 |      -100.00000 |        0.00000 | -100.00000 |              | pl
#  8400  | Erlöse 16%/19% USt.                 | I   |           |  280.00000 |       280.00000 |        0.00000 |  280.00000 |              | pl
# (10 rows) 

# ob_amount + amount = year_end_amount
# amount_with_cb should be 0 after year-end transactions
# year_end_amount and cb_amount should be the same (will be true with amount_with_cb = 0)
# cb_amount should match ob_next_year for asset accounts, except for profit-carried-forward
# ob_next_year should be empty for profit-loss-accounts

# Oops, we forgot some bookings, lets quickly add them and run
#_year_end_bookings again.

# Just these new bookings by themselves will lead to a loss, so the loss account
# will be booked rather than the profit account.
# It would probably be better to check the total profit/loss so far, and
# adjust that profit-loss-carry-over # chart, rather than creating a new entry
# for the loss.

gl_booking(10, $booking_date, 'foo', 'bar', $cash, $bank, 0, 0);
gl_booking(5,  $booking_date, 'foo', 'bar', $betriebsbedarf, $cash, 0, 0);

SL::Controller::YearEndTransactions::_year_end_bookings( start_date => $start_date,
                                                         cb_date    => $cb_date,
                                                       );

is(SL::DB::Manager::AccTransaction->get_all_count(where => [ cb_transaction => 1 ]), 23, 'acc_trans cb_transactions created ok');
is(SL::DB::Manager::AccTransaction->get_all_count(where => [ ob_transaction => 1 ]), 16, 'acc_trans ob_transactions created ok');
is(SL::DB::Manager::GLTransaction->get_all_count( where => [ cb_transaction => 1 ]),  9, 'GL cb_transactions created ok');
is(SL::DB::Manager::GLTransaction->get_all_count( where => [ ob_transaction => 1 ]),  7, 'GL ob_transactions created ok');

is_deeply( &get_final_balances, 
           [
             {
               'accno' => '0868',
               'amount' => undef,
               'amount_with_cb' => '0.00000',
               'cat' => 'Q',
               'cb_amount' => '0.00000',
               'ob_amount' => undef,
               'ob_next_year' => '-5.00000',
               'type' => 'asset',
               'year_end_amount' => undef
             },
             {
               'accno' => '0890',
               'amount' => undef,
               'amount_with_cb' => '0.00000',
               'cat' => 'Q',
               'cb_amount' => '0.00000',
               'ob_amount' => undef,
               'ob_next_year' => '214.20000',
               'type' => 'asset',
               'year_end_amount' => undef
             },
             {
               'accno' => '1000',
               'amount' => '-5.00000',
               'amount_with_cb' => '0.00000',
               'cat' => 'A',
               'cb_amount' => '-5.00000',
               'ob_amount' => undef,
               'ob_next_year' => '-5.00000',
               'type' => 'asset',
               'year_end_amount' => '-5.00000'
             },
             {
               'accno' => '1200',
               'amount' => '-156.60000',
               'amount_with_cb' => '0.00000',
               'cat' => 'A',
               'cb_amount' => '-196.60000',
               'ob_amount' => '-40.00000',
               'ob_next_year' => '-196.60000',
               'type' => 'asset',
               'year_end_amount' => '-196.60000'
             },
             {
               'accno' => '1400',
               'amount' => '-166.60000',
               'amount_with_cb' => '0.00000',
               'cat' => 'A',
               'cb_amount' => '-166.60000',
               'ob_amount' => undef,
               'ob_next_year' => '-166.60000',
               'type' => 'asset',
               'year_end_amount' => '-166.60000'
             },
             {
               'accno' => '1600',
               'amount' => '119.00000',
               'amount_with_cb' => '0.00000',
               'cat' => 'L',
               'cb_amount' => '119.00000',
               'ob_amount' => undef,
               'ob_next_year' => '119.00000',
               'type' => 'asset',
               'year_end_amount' => '119.00000'
             },
             {
               'accno' => '1890',
               'amount' => undef,
               'amount_with_cb' => '0.00000',
               'cat' => 'Q',
               'cb_amount' => '40.00000',
               'ob_amount' => '40.00000',
               'ob_next_year' => '40.00000',
               'type' => 'asset',
               'year_end_amount' => '40.00000'
             },
             {
               'accno' => '9000',
               'amount' => undef,
               'amount_with_cb' => '0.00000',
               'cat' => 'A',
               'cb_amount' => '0.00000',
               'ob_amount' => undef,
               'ob_next_year' => '0.00000',
               'type' => 'asset',
               'year_end_amount' => undef
             },
             {
               'accno' => '1576',
               'amount' => '-19.80000',
               'amount_with_cb' => '0.00000',
               'cat' => 'E',
               'cb_amount' => '-19.80000',
               'ob_amount' => undef,
               'ob_next_year' => undef,
               'type' => 'pl',
               'year_end_amount' => '-19.80000'
             },
             {
               'accno' => '1776',
               'amount' => '53.20000',
               'amount_with_cb' => '0.00000',
               'cat' => 'I',
               'cb_amount' => '53.20000',
               'ob_amount' => undef,
               'ob_next_year' => undef,
               'type' => 'pl',
               'year_end_amount' => '53.20000'
             },
             {
               'accno' => '3400',
               'amount' => '-100.00000',
               'amount_with_cb' => '0.00000',
               'cat' => 'E',
               'cb_amount' => '-100.00000',
               'ob_amount' => undef,
               'ob_next_year' => undef,
               'type' => 'pl',
               'year_end_amount' => '-100.00000'
             },
             {
               'accno' => '4980',
               'amount' => '-4.20000',
               'amount_with_cb' => '0.00000',
               'cat' => 'E',
               'cb_amount' => '-4.20000',
               'ob_amount' => undef,
               'ob_next_year' => undef,
               'type' => 'pl',
               'year_end_amount' => '-4.20000'
             },
             {
               'accno' => '8400',
               'amount' => '280.00000',
               'amount_with_cb' => '0.00000',
               'cat' => 'I',
               'cb_amount' => '280.00000',
               'ob_amount' => undef,
               'ob_next_year' => undef,
               'type' => 'pl',
               'year_end_amount' => '280.00000'
             },
           ],
           'balances after third year_end ok');

clear_up();
done_testing;

1;

sub clear_up {
  foreach (qw(BankAccount
              GLTransaction
              AccTransaction
              InvoiceItem
              Invoice
              PurchaseInvoice
              Part
              Customer
             )
           ) {
    "SL::DB::Manager::${_}"->delete_all(all => 1);
  }
};
 
sub get_account_balances {
  my $query = <<SQL;
  select c.accno,
         case when c.category = ANY( '{I,E}'   )   then 'profit_loss_account'
              when c.category = ANY( '{A,C,L,Q}' ) then 'asset_account'
                                                   else null
              end as account_type,
         sum(a.amount)
    from acc_trans a
         left join chart c on (c.id = a.chart_id)
group by c.accno, account_type
order by account_type, c.accno;
SQL

  my $result = selectall_hashref_query($::form, $dbh, $query);
  return $result;
};

sub get_final_balances {
  my $query = <<SQL;
 select c.accno,
        c.category as cat,
        sum(a.amount     ) filter (where ob_transaction is true                              and a.transdate  < ?) as ob_amount,
        sum(a.amount     ) filter (where cb_transaction is false and ob_transaction is false and a.transdate  < ?) as amount,
        sum(a.amount     ) filter (where cb_transaction is false                             and a.transdate  < ?) as year_end_amount,
        sum(a.amount     ) filter (where                                                         a.transdate  < ?) as amount_with_cb,
        sum(a.amount * -1) filter (where cb_transaction is true                              and a.transdate  < ?) as cb_amount,
        sum(a.amount     ) filter (where ob_transaction is true                              and a.transdate  = ?) as ob_next_year,
        case when c.category = ANY( '{I,E}'     ) then 'pl'
             when c.category = ANY( '{A,C,L,Q}' ) then 'asset'
                                                  else null
             end as type
   from acc_trans a
        inner join chart c on (c.id = a.chart_id)
  where     a.transdate >= ?
        and a.transdate <= ?
  group by c.id, c.accno, c.category
  order by type, c.accno
SQL

  my $result = selectall_hashref_query($::form, $dbh, $query, $ob_date, $ob_date, $ob_date, $ob_date, $ob_date, $ob_date, $start_date, $ob_date);
  return $result;
}

sub gl_booking {
  # wrapper around SL::Dev::Record::create_gl_transaction for quickly creating transactions
  my ($amount, $date, $reference, $description, $gegenkonto, $konto, $ob, $cb) = @_;

  # my $transdate = $::locale->parse_date_to_object($date);

  return create_gl_transaction(
    ob_transaction => $ob,
    cb_transaction => $cb,
    transdate      => $date,
    reference      => $reference,
    description    => $description,
    bookings       => [
                        {
                          chart  => $konto,
                          credit => $amount,
                        },
                        {
                          chart => $gegenkonto,
                          debit => $amount,
                        },
                      ],
  );
};
