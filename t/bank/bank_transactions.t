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
use SL::DB::Customer;
use SL::DB::Vendor;
use SL::DB::Invoice;
use SL::DB::Unit;
use SL::DB::Part;
use SL::DB::TaxZone;
use SL::DB::BankAccount;
use SL::DB::PaymentTerm;
use SL::DB::PurchaseInvoice;
use SL::DB::BankTransaction;
use SL::Controller::BankTransaction;
use SL::Dev::ALL;
use Data::Dumper;

my ($customer, $vendor, $currency_id, $unit, $tax, $tax7, $tax_9, $payment_terms, $bank_account);
my ($transdate1, $transdate2, $currency);
my ($ar_chart,$bank,$ar_amount_chart, $ap_chart, $ap_amount_chart);
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
  SL::DB::Manager::PaymentTerm->delete_all(all => 1);
  SL::DB::Manager::Currency->delete_all(where => [ name => 'CUR' ]);
};


# starting test:
Support::TestSetup::login();

reset_state(); # initialise customers/vendors/bank/currency/...

test1();
test_overpayment_with_partialpayment();
test_overpayment();
test_skonto_exact();
test_two_invoices();
test_partial_payment();
test_credit_note();

# remove all created data at end of test
clear_up();

done_testing();

###### functions for setting up data

sub reset_state {
  my %params = @_;

  $params{$_} ||= {} for qw(unit customer tax vendor);

  clear_up();

  $transdate1 = DateTime->today;
  $transdate2 = DateTime->today->add(days => 5);

  $tax             = SL::DB::Manager::Tax->find_by(taxkey => 3, rate => 0.19, %{ $params{tax} }) || croak "No tax";
  $tax7            = SL::DB::Manager::Tax->find_by(taxkey => 2, rate => 0.07)                    || croak "No tax for 7\%";
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

  $customer = SL::Dev::CustomerVendor::create_customer(
    name                      => 'Test Customer',
    iban                      => 'DE12500105170648489890',
    bic                       => 'TESTBIC',
    account_number            => '648489890',
    mandate_date_of_signature => $transdate1,
    mandator_id               => 'foobar',
    bank                      => 'Geizkasse',
    bank_code                 => 'G1235',
    depositor                 => 'Test Customer',
  )->save;

  $payment_terms = SL::Dev::Payment::create_payment_terms;

  $vendor = SL::Dev::CustomerVendor::create_vendor(
    name           => 'Test Vendor',
    payment_id     => $payment_terms->id,
    iban           => 'DE12500105170648489890',
    bic            => 'TESTBIC',
    account_number => '648489890',
    bank           => 'Geizkasse',
    bank_code      => 'G1235',
    depositor      => 'Test Vendor',
  )->save;

  $ar_chart        = SL::DB::Manager::Chart->find_by( accno => '1400' ); # Forderungen
  $ap_chart        = SL::DB::Manager::Chart->find_by( accno => '1600' ); # Verbindlichkeiten
  $bank            = SL::DB::Manager::Chart->find_by( accno => '1200' ); # Bank
  $ar_amount_chart = SL::DB::Manager::Chart->find_by( accno => '8400' ); # Erlöse
  $ap_amount_chart = SL::DB::Manager::Chart->find_by( accno => '3400' ); # Wareneingang 19%

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

  my $bt = SL::Dev::Payment::create_bank_transaction(record => $ar_transaction) or die "Couldn't create bank_transaction";

  $::form->{invoice_ids} = {
          $bt->id => [ $ar_transaction->id ]
        };

  my $bt_controller = SL::Controller::BankTransaction->new;
  $bt_controller->action_save_invoices;

  $ar_transaction->load;
  $bt->load;
  is($ar_transaction->paid   , '119.00000' , "$testname: salesinv1 was paid");
  is($ar_transaction->closed , 1           , "$testname: salesinv1 is closed");
  is($bt->invoice_amount     , '119.00000' , "$testname: bt invoice amount was assigned");

};

sub test_skonto_exact {

  my $testname = 'test_skonto_exact';

  $ar_transaction = test_ar_transaction(invnumber => 'salesinv skonto',
                                        payment_id => $payment_terms->id,
                                       );

  my $bt = SL::Dev::Payment::create_bank_transaction(record        => $ar_transaction,
                                                     bank_chart_id => $bank->id,
                                                     amount        => $ar_transaction->amount_less_skonto
                                                    ) or die "Couldn't create bank_transaction";

  $::form->{invoice_ids} = {
          $bt->id => [ $ar_transaction->id ]
        };
  $::form->{invoice_skontos} = {
          $bt->id => [ 'with_skonto_pt' ]
        };

  my $bt_controller = SL::Controller::BankTransaction->new;
  $bt_controller->action_save_invoices;

  $ar_transaction->load;
  $bt->load;
  is($ar_transaction->paid   , '119.00000' , "$testname: salesinv skonto was paid");
  is($ar_transaction->closed , 1           , "$testname: salesinv skonto is closed");
  is($bt->invoice_amount     , '113.05000' , "$testname: bt invoice amount was assigned");

};

sub test_two_invoices {

  my $testname = 'test_two_invoices';

  my $ar_transaction_1 = test_ar_transaction(invnumber => 'salesinv_1');
  my $ar_transaction_2 = test_ar_transaction(invnumber => 'salesinv_2');

  my $bt = SL::Dev::Payment::create_bank_transaction(record        => $ar_transaction_1,
                                                     amount        => ($ar_transaction_1->amount + $ar_transaction_2->amount),
                                                     purpose       => "Rechnungen " . $ar_transaction_1->invnumber . " und " . $ar_transaction_2->invnumber,
                                                     bank_chart_id => $bank->id,
                                                    ) or die "Couldn't create bank_transaction";

  $::form->{invoice_ids} = {
          $bt->id => [ $ar_transaction_1->id, $ar_transaction_2->id ]
        };

  my $bt_controller = SL::Controller::BankTransaction->new;
  $bt_controller->action_save_invoices;

  $ar_transaction_1->load;
  $ar_transaction_2->load;
  $bt->load;

  is($ar_transaction_1->paid   , '119.00000' , "$testname: salesinv_1 was paid");
  is($ar_transaction_1->closed , 1           , "$testname: salesinv_1 is closed");
  is($ar_transaction_2->paid   , '119.00000' , "$testname: salesinv_2 was paid");
  is($ar_transaction_2->closed , 1           , "$testname: salesinv_2 is closed");
  is($bt->invoice_amount       , '238.00000' , "$testname: bt invoice amount was assigned");

};

sub test_overpayment {

  my $testname = 'test_overpayment';

  $ar_transaction = test_ar_transaction(invnumber => 'salesinv overpaid');

  # amount 135 > 119
  my $bt = SL::Dev::Payment::create_bank_transaction(record        => $ar_transaction,
                                                     bank_chart_id => $bank->id,
                                                     amount        => 135
                                                    ) or die "Couldn't create bank_transaction";

  $::form->{invoice_ids} = {
          $bt->id => [ $ar_transaction->id ]
        };

  my $bt_controller = SL::Controller::BankTransaction->new;
  $bt_controller->action_save_invoices;

  $ar_transaction->load;
  $bt->load;

  is($ar_transaction->paid                     , '135.00000' , "$testname: 'salesinv overpaid' was overpaid");
  is($bt->invoice_amount                       , '135.00000' , "$testname: bt invoice amount was assigned overpaid amount");
{ local $TODO = 'this currently fails because closed ignores over-payments, see commit d90966c7';
  is($ar_transaction->closed                   , 0           , "$testname: 'salesinv overpaid' is open (via 'closed' method')");
}
  is($ar_transaction->open_amount == 0 ? 1 : 0 , 0           , "$testname: 'salesinv overpaid is open (via amount-paid)");

};

sub test_overpayment_with_partialpayment {

  # two payments on different days, 10 and 119. If there is only one invoice we want it be overpaid.
  my $testname = 'test_overpayment_with_partialpayment';

  $ar_transaction = test_ar_transaction(invnumber => 'salesinv overpaid partial');

  my $bt_1 = SL::Dev::Payment::create_bank_transaction(record        => $ar_transaction,
                                                       bank_chart_id => $bank->id,
                                                       amount        =>  10
                                                      ) or die "Couldn't create bank_transaction";
  my $bt_2 = SL::Dev::Payment::create_bank_transaction(record        => $ar_transaction,
                                                       amount        => 119,
                                                       transdate     => DateTime->today->add(days => 5),
                                                       bank_chart_id => $bank->id,
                                                      ) or die "Couldn't create bank_transaction";

  $::form->{invoice_ids} = {
          $bt_1->id => [ $ar_transaction->id ]
        };
  my $bt_controller_1 = SL::Controller::BankTransaction->new;
  $bt_controller_1->action_save_invoices;

  $::form->{invoice_ids} = {
          $bt_2->id => [ $ar_transaction->id ]
        };
  my $bt_controller_2 = SL::Controller::BankTransaction->new;
  $bt_controller_2->action_save_invoices;

  $ar_transaction->load;
  $bt_1->load;
  $bt_2->load;

  is($ar_transaction->paid , '129.00000' , "$testname: 'salesinv overpaid partial' was overpaid");
  is($bt_1->invoice_amount ,  '10.00000' , "$testname: bt_1 invoice amount was assigned overpaid amount");
  is($bt_2->invoice_amount , '119.00000' , "$testname: bt_2 invoice amount was assigned overpaid amount");

};

sub test_partial_payment {

  my $testname = 'test_partial_payment';

  $ar_transaction = test_ar_transaction(invnumber => 'salesinv partial payment');

  # amount 100 < 119
  my $bt = SL::Dev::Payment::create_bank_transaction(record        => $ar_transaction,
                                                     bank_chart_id => $bank->id,
                                                     amount        => 100
                                                    ) or die "Couldn't create bank_transaction";

  $::form->{invoice_ids} = {
          $bt->id => [ $ar_transaction->id ]
        };

  my $bt_controller = SL::Controller::BankTransaction->new;
  $bt_controller->action_save_invoices;

  $ar_transaction->load;
  $bt->load;

  is($ar_transaction->paid , '100.00000' , "$testname: 'salesinv partial payment' was partially paid");
  is($bt->invoice_amount   , '100.00000' , "$testname: bt invoice amount was assigned partially paid amount");

};

sub test_credit_note {

  my $testname = 'test_credit_note';

  my $part1 = SL::Dev::Part::create_part(   partnumber => 'T4254')->save;
  my $part2 = SL::Dev::Part::create_service(partnumber => 'Serv1')->save;
  my $credit_note = SL::Dev::Record::create_credit_note(
    invnumber    => 'cn 1',
    customer     => $customer,
    taxincluded  => 0,
    invoiceitems => [ SL::Dev::Record::create_invoice_item(part => $part1, qty =>  3, sellprice => 70),
                      SL::Dev::Record::create_invoice_item(part => $part2, qty => 10, sellprice => 50),
                    ]
  );
  my $bt            = SL::Dev::Payment::create_bank_transaction(record        => $credit_note,
                                                                amount        => $credit_note->amount,
                                                                bank_chart_id => $bank->id,
                                                                transdate     => DateTime->today->add(days => 10),
                                                               );
  my ($agreement, $rule_matches) = $bt->get_agreement_with_invoice($credit_note);
  is($agreement, 13, "points for credit note ok");
  is($rule_matches, 'remote_account_number(3) exact_amount(4) wrong_sign(-1) depositor_matches(2) remote_name(2) payment_within_30_days(1) datebonus14(2) ', "rules_matches for credit note ok");

  $::form->{invoice_ids} = {
          $bt->id => [ $credit_note->id ]
  };

  my $bt_controller = SL::Controller::BankTransaction->new;
  $bt_controller->action_save_invoices;

  $credit_note->load;
  $bt->load;
  is($credit_note->amount   , '-844.90000', "$testname: amount ok");
  is($credit_note->netamount, '-710.00000', "$testname: netamount ok");
  is($credit_note->paid     , '-844.90000', "$testname: paid ok");
}

1;
