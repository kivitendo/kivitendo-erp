use Test::More;

use strict;

use lib 't';
use utf8;

use Carp;
use Support::TestSetup;
use Test::Exception;
use List::Util qw(sum);

use SL::DB::Buchungsgruppe;
use SL::DB::Currency;
use SL::DB::Exchangerate;
use SL::DB::Customer;
use SL::DB::Vendor;
use SL::DB::Employee;
use SL::DB::Invoice;
use SL::DB::Part;
use SL::DB::Unit;
use SL::DB::TaxZone;
use SL::DB::BankAccount;
use SL::DB::PaymentTerm;
use SL::DB::PurchaseInvoice;
use SL::DB::BankTransaction;
use SL::DB::AccTransaction;
use SL::Controller::YearEndTransactions;
use Data::Dumper;

my ($customer, $vendor, $currency_id, @parts, $unit, $employee, $tax, $tax7, $tax_9, $taxzone, $payment_terms, $bank_account);
my ($transdate1, $transdate2, $currency);
my ($ar_chart,$bank,$ar_amount_chart, $ap_chart, $ap_amount_chart, $saldo_chart);
my ($ar_transaction, $ap_transaction);

sub clear_up {

  SL::DB::Manager::BankTransaction->delete_all(all => 1);
  SL::DB::Manager::InvoiceItem->delete_all(all => 1);
  SL::DB::Manager::InvoiceItem->delete_all(all => 1);
  SL::DB::Manager::Invoice->delete_all(all => 1);
  SL::DB::Manager::PurchaseInvoice->delete_all(all => 1);
  SL::DB::Manager::Part->delete_all(all => 1);
  SL::DB::Manager::Customer->delete_all(all => 1);
  SL::DB::Manager::Vendor->delete_all(all => 1);
  SL::DB::Manager::BankAccount->delete_all(all => 1);
  SL::DB::Manager::AccTransaction->delete_all(all => 1);
  SL::DB::Manager::PaymentTerm->delete_all(all => 1);
  SL::DB::Manager::Currency->delete_all(where => [ name => 'CUR' ]);
};


# starting test:
Support::TestSetup::login();

reset_state(); # initialise customers/vendors/bank/currency/...

test1();

# remove all created data at end of test
clear_up();

done_testing();

###### functions for setting up data

sub reset_state {
  my %params = @_;

  $params{$_} ||= {} for qw(unit customer part tax vendor);

  clear_up();

  $transdate1 = DateTime->today;
  $transdate2 = DateTime->today->add(days => 5);

  $employee        = SL::DB::Manager::Employee->current                                          || croak "No employee";
  $tax             = SL::DB::Manager::Tax->find_by(taxkey => 3, rate => 0.19, %{ $params{tax} }) || croak "No tax";
  $tax7            = SL::DB::Manager::Tax->find_by(taxkey => 2, rate => 0.07)                    || croak "No tax for 7\%";
  $taxzone         = SL::DB::Manager::TaxZone->find_by( description => 'Inland')                 || croak "No taxzone";
  $tax_9           = SL::DB::Manager::Tax->find_by(taxkey => 9, rate => 0.19, %{ $params{tax} }) || croak "No tax";

  $currency_id     = $::instance_conf->get_currency_id;

  $bank_account     =  SL::DB::BankAccount->new(
    account_number  => '123',
    bank_code       => '123',
    iban            => '123',
    bic             => '123',
    bank            => '123',
    chart_id        => SL::DB::Manager::Chart->find_by(description => 'Bank')->id,
    name            => SL::DB::Manager::Chart->find_by(description => 'Bank')->description,
  )->save;

  $customer     = SL::DB::Customer->new(
    name                      => 'Test Customer',
    currency_id               => $currency_id,
    taxzone_id                => $taxzone->id,
    iban                      => 'DE12500105170648489890',
    bic                       => 'TESTBIC',
    account_number            => '648489890',
    mandate_date_of_signature => $transdate1,
    mandator_id               => 'foobar',
    bank                      => 'Geizkasse',
    depositor                 => 'Test Customer',
    %{ $params{customer} }
  )->save;

  $payment_terms     =  SL::DB::PaymentTerm->new(
    description      => 'payment',
    description_long => 'payment',
    terms_netto      => '30',
    terms_skonto     => '5',
    percent_skonto   => '0.05',
    auto_calculation => 1,
  )->save;

  $vendor       = SL::DB::Vendor->new(
    name        => 'Test Vendor',
    currency_id => $currency_id,
    taxzone_id  => $taxzone->id,
    payment_id  => $payment_terms->id,
    iban                      => 'DE12500105170648489890',
    bic                       => 'TESTBIC',
    account_number            => '648489890',
    bank                      => 'Geizkasse',
    depositor                 => 'Test Vendor',
    %{ $params{vendor} }
  )->save;

  $ar_chart        = SL::DB::Manager::Chart->find_by( accno => '1400' ); # Forderungen
  $ap_chart        = SL::DB::Manager::Chart->find_by( accno => '1600' ); # Verbindlichkeiten
  $bank            = SL::DB::Manager::Chart->find_by( accno => '1200' ); # Bank
  $ar_amount_chart = SL::DB::Manager::Chart->find_by( accno => '8400' ); # Erlöse
  $ap_amount_chart = SL::DB::Manager::Chart->find_by( accno => '3400' ); # Wareneingang 19%
  $saldo_chart     = SL::DB::Manager::Chart->find_by( accno => '9000' ); # Saldenvorträge

}

sub test_ar_transaction {
  my (%params) = @_;
  my $netamount = 100;
  my $amount    = $params{amount} || $::form->round_amount(100 * 1.19,2);
  my $invoice   = SL::DB::Invoice->new(
      invoice      => 0,
      invnumber    => $params{invnumber} || undef, # let it use its own invnumber
      amount       => $amount,
      netamount    => $netamount,
      transdate    => $transdate1,
      taxincluded  => 0,
      customer_id  => $customer->id,
      taxzone_id   => $customer->taxzone_id,
      currency_id  => $currency_id,
      transactions => [],
      payment_id   => $params{payment_id} || undef,
      notes        => 'test_ar_transaction',
  );
  $invoice->add_ar_amount_row(
    amount => $invoice->netamount,
    chart  => $ar_amount_chart,
    tax_id => $tax->id,
  );

  $invoice->create_ar_row(chart => $ar_chart);
  $invoice->save;

  is($invoice->currency_id , $currency_id , 'currency_id has been saved');
  is($invoice->netamount   , 100          , 'ar amount has been converted');
  is($invoice->amount      , 119          , 'ar amount has been converted');
  is($invoice->taxincluded , 0            , 'ar transaction doesn\'t have taxincluded');

  is(SL::DB::Manager::AccTransaction->find_by(chart_id => $ar_amount_chart->id , trans_id => $invoice->id)->amount , '100.00000'  , $ar_amount_chart->accno . ': has been converted for currency');
  is(SL::DB::Manager::AccTransaction->find_by(chart_id => $ar_chart->id        , trans_id => $invoice->id)->amount , '-119.00000' , $ar_chart->accno . ': has been converted for currency');

  return $invoice;
};

sub test_ap_transaction {
  my (%params) = @_;
  my $netamount = 100;
  my $amount    = $::form->round_amount($netamount * 1.19,2);
  my $invoice   = SL::DB::PurchaseInvoice->new(
      invoice      => 0,
      invnumber    => $params{invnumber} || 'test_ap_transaction',
      amount       => $amount,
      netamount    => $netamount,
      transdate    => $transdate1,
      taxincluded  => 0,
      vendor_id    => $vendor->id,
      taxzone_id   => $vendor->taxzone_id,
      currency_id  => $currency_id,
      transactions => [],
      notes        => 'test_ap_transaction',
  );
  $invoice->add_ap_amount_row(
    amount     => $invoice->netamount,
    chart      => $ap_amount_chart,
    tax_id     => $tax_9->id,
  );

  $invoice->create_ap_row(chart => $ap_chart);
  $invoice->save;

  is($invoice->currency_id , $currency_id , 'currency_id has been saved');
  is($invoice->netamount   , 100          , 'ap amount has been converted');
  is($invoice->amount      , 119          , 'ap amount has been converted');
  is($invoice->taxincluded , 0            , 'ap transaction doesn\'t have taxincluded');

  is(SL::DB::Manager::AccTransaction->find_by(chart_id => $ap_amount_chart->id , trans_id => $invoice->id)->amount , '-100.00000' , $ap_amount_chart->accno . ': has been converted for currency');
  is(SL::DB::Manager::AccTransaction->find_by(chart_id => $ap_chart->id        , trans_id => $invoice->id)->amount , '119.00000'  , $ap_chart->accno . ': has been converted for currency');

  return $invoice;
};

###### test cases

sub test1 {

  my $testname = 'test1';

  $ar_transaction = test_ar_transaction(invnumber => 'salesinv1');
  $ap_transaction = test_ap_transaction(invnumber => 'purchaseinv1');
  my $ar_transaction_2 = test_ar_transaction(invnumber => 'salesinv_2');

  my $yt_controller = SL::Controller::YearEndTransactions->new;
  my $report     = SL::ReportGenerator->new(\%::myconfig, $::form);

  $::form->{"ob_date"} = DateTime->today->truncate(to => 'year')->add(years => 1)->to_kivitendo;
  $::form->{"cb_date"} = DateTime->today->truncate(to => 'year')->add(years => 1)->add(days => -1)->to_kivitendo;
  #print "ob_date=".$::form->{"ob_date"}." cb_date=".$::form->{"cb_date"}."\n";
  $::form->{"cb_reference"} = 'SB-Buchung';
  $::form->{"ob_reference"} = 'EB-Buchung';
  $::form->{"cb_description"} = 'SB-Buchung Beschreibung';
  $::form->{"ob_description"} = 'EB-Buchung Beschreibung';
  $::form->{"cbob_chart"} = $saldo_chart->id;

  $yt_controller->prepare_report($report);

  ## check balance of charts

  my $idx = 1;
  foreach my $chart (@{ $yt_controller->charts }) {
    my $balance = $yt_controller->get_balance($chart);
    if ( $balance != 0 ) {
      #print "chart_id=".$chart->id."balance=".$balance."\n";
      is($balance , '-238.00000' , $chart->accno.' has right balance') if $chart->accno eq '1400';
      is($balance ,  '-19.00000' , $chart->accno.' has right balance') if $chart->accno eq '1576';
      is($balance ,  '119.00000' , $chart->accno.' has right balance') if $chart->accno eq '1600';
      is($balance ,   '38.00000' , $chart->accno.' has right balance') if $chart->accno eq '1776';
      is($balance , '-100.00000' , $chart->accno.' has right balance') if $chart->accno eq '3400';
      is($balance ,  '200.00000' , $chart->accno.' has right balance') if $chart->accno eq '8400';
      $::form->{"multi_id_${idx}"} = $chart->id;
      $idx++ ;
    }
  }
  $::form->{"rowcount"} = $idx-1;
  #print "rowcount=". $::form->{"rowcount"}."\n";
  $::form->{"login"}="unittests";

  $yt_controller->make_booking;

  ## no check cb ob booking :

  my $sum_cb_p = 0;
  my $sum_cb_m = 0;
  foreach my $acc ( @{ SL::DB::Manager::AccTransaction->get_all(where => [ chart_id => $saldo_chart->id, cb_transaction => 't' ]) }) {
    #print "cb amount=".$acc->amount."\n";
    $sum_cb_p +=  $acc->amount if $acc->amount > 0;
    $sum_cb_m += -$acc->amount if $acc->amount < 0;
  }
  #print "chart_id=".$saldo_chart->id." sum_cb_p=".$sum_cb_p." sum_cb_m=".$sum_cb_m."\n";
  is($sum_cb_p ,  '357' , 'chart '.$saldo_chart->accno.' has right positive close saldo');
  is($sum_cb_m ,  '357' , 'chart '.$saldo_chart->accno.' has right negative close saldo');
  my $sum_ob_p = 0;
  my $sum_ob_m = 0;
  foreach my $acc ( @{ SL::DB::Manager::AccTransaction->get_all(where => [ chart_id => $saldo_chart->id, ob_transaction => 't' ]) }) {
    #print "ob amount=".$acc->amount."\n";
    $sum_ob_p +=  $acc->amount if $acc->amount > 0;
    $sum_ob_m += -$acc->amount if $acc->amount < 0;
  }
  #print "chart_id=".$saldo_chart->id." sum_ob_p=".$sum_ob_p." sum_ob_m=".$sum_ob_m."\n";
  is($sum_ob_p ,  '357' , 'chart '.$saldo_chart->accno.' has right positive open saldo');
  is($sum_ob_m ,  '357' , 'chart '.$saldo_chart->accno.' has right negative open saldo');
}



1;
