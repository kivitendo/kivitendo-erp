use Test::More tests => 210;

use strict;

use lib 't';
use utf8;

use Carp;
use Support::TestSetup;
use Test::Exception;
use List::Util qw(sum);

use SL::DB::AccTransaction;
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
use SL::Dev::ALL qw(:ALL);
use Data::Dumper;

my ($customer, $vendor, $currency_id, $unit, $tax, $tax0, $tax7, $tax_9, $payment_terms, $bank_account);
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
  SL::DB::Manager::SepaExportItem->delete_all(all => 1);
  SL::DB::Manager::SepaExport->delete_all(all => 1);
  SL::DB::Manager::BankAccount->delete_all(all => 1);
  SL::DB::Manager::PaymentTerm->delete_all(all => 1);
  SL::DB::Manager::Currency->delete_all(where => [ name => 'CUR' ]);
};

my $bt_controller;

sub save_btcontroller_to_string {
  my $output;
  open(my $outputFH, '>', \$output) or die;
  my $oldFH = select $outputFH;

  $bt_controller = SL::Controller::BankTransaction->new;
  $bt_controller->action_save_invoices;

  select $oldFH;
  close $outputFH;
  return $output;
}

# starting test:
Support::TestSetup::login();

clear_up();
reset_state(); # initialise customers/vendors/bank/currency/...

test1();

test_overpayment_with_partialpayment();
test_overpayment();
reset_state();
test_skonto_exact();
test_two_invoices();
test_partial_payment();
test_credit_note();
test_ap_transaction();
test_neg_ap_transaction(invoice => 0);
test_neg_ap_transaction(invoice => 1);
test_ap_payment_transaction();
test_ap_payment_part_transaction();
test_neg_sales_invoice();
test_two_neg_ap_transaction();
test_one_inv_and_two_invoices_with_skonto_exact();
test_bt_error();

reset_state();
test_sepa_export();

reset_state();
test_bt_rule1();
reset_state();
test_two_banktransactions();
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
  $tax_9           = SL::DB::Manager::Tax->find_by(taxkey => 9, rate => 0.19, %{ $params{tax} }) || croak "No tax for 19\%";
  $tax0            = SL::DB::Manager::Tax->find_by(taxkey => 0, rate => 0.0)                     || croak "No tax for 0\%";

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

  $customer = new_customer(
    name                      => 'Test Customer OLÉ S.L. Årdbärg AB',
    iban                      => 'DE12500105170648489890',
    bic                       => 'TESTBIC',
    account_number            => '648489890',
    mandate_date_of_signature => $transdate1,
    mandator_id               => 'foobar',
    bank                      => 'Geizkasse',
    bank_code                 => 'G1235',
    depositor                 => 'Test Customer',
    customernumber            => 'CUST1704',
  )->save;

  $payment_terms = create_payment_terms();

  $vendor = new_vendor(
    name           => 'Test Vendor',
    payment_id     => $payment_terms->id,
    iban           => 'DE12500105170648489890',
    bic            => 'TESTBIC',
    account_number => '648489890',
    bank           => 'Geizkasse',
    bank_code      => 'G1235',
    depositor      => 'Test Vendor',
    vendornumber   => 'VEND1704',
  )->save;

  $ar_chart        = SL::DB::Manager::Chart->find_by( accno => '1400' ); # Forderungen
  $ap_chart        = SL::DB::Manager::Chart->find_by( accno => '1600' ); # Verbindlichkeiten
  $bank            = SL::DB::Manager::Chart->find_by( accno => '1200' ); # Bank
  $ar_amount_chart = SL::DB::Manager::Chart->find_by( accno => '8400' ); # Erlöse
  $ap_amount_chart = SL::DB::Manager::Chart->find_by( accno => '3400' ); # Wareneingang 19%

}

sub test_ar_transaction {
  my (%params) = @_;
  my $netamount = $params{amount} || 100;
  my $amount    = $::form->round_amount($netamount * 1.19,2);
  my $invoice   = SL::DB::Invoice->new(
      invoice      => 0,
      invnumber    => $params{invnumber} || undef, # let it use its own invnumber
      amount       => $amount,
      netamount    => $netamount,
      transdate    => $transdate1,
      taxincluded  => $params{taxincluded } || 0,
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
    tax_id => $params{tax_id} || $tax->id,
  );

  $invoice->create_ar_row(chart => $ar_chart);
  $invoice->save;

  is($invoice->currency_id , $currency_id , 'currency_id has been saved');
  is($invoice->netamount   , $netamount   , 'ar amount has been converted');
  is($invoice->amount      , $amount      , 'ar amount has been converted');
  is($invoice->taxincluded , 0            , 'ar transaction doesn\'t have taxincluded');

  if ( $netamount == 100 ) {
    is(SL::DB::Manager::AccTransaction->find_by(chart_id => $ar_amount_chart->id , trans_id => $invoice->id)->amount , '100.00000'  , $ar_amount_chart->accno . ': has been converted for currency');
    is(SL::DB::Manager::AccTransaction->find_by(chart_id => $ar_chart->id        , trans_id => $invoice->id)->amount , '-119.00000' , $ar_chart->accno . ': has been converted for currency');
  }
  return $invoice;
};

sub test_ap_transaction {
  my (%params) = @_;
  my $testname = 'test_ap_transaction';

  my $netamount = 100;
  my $amount    = $::form->round_amount($netamount * 1.19,2);
  my $invoice   = SL::DB::PurchaseInvoice->new(
    invoice      => 0,
    invnumber    => $params{invnumber} || $testname,
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
    tax_id     => $params{tax_id} || $tax_9->id,
  );

  $invoice->create_ap_row(chart => $ap_chart);
  $invoice->save;

  is($invoice->currency_id , $currency_id , "$testname: currency_id has been saved");
  is($invoice->netamount   , 100          , "$testname: ap amount has been converted");
  is($invoice->amount      , 119          , "$testname: ap amount has been converted");
  is($invoice->taxincluded , 0            , "$testname: ap transaction doesn\'t have taxincluded");

  is(SL::DB::Manager::AccTransaction->find_by(chart_id => $ap_amount_chart->id , trans_id => $invoice->id)->amount , '-100.00000' , $ap_amount_chart->accno . ': has been converted for currency');
  is(SL::DB::Manager::AccTransaction->find_by(chart_id => $ap_chart->id        , trans_id => $invoice->id)->amount , '119.00000'  , $ap_chart->accno . ': has been converted for currency');

  return $invoice;
};

###### test cases

sub test1 {

  my $testname = 'test1';

  $ar_transaction = test_ar_transaction(invnumber => 'salesinv1');

  my $bt = create_bank_transaction(record => $ar_transaction) or die "Couldn't create bank_transaction";

  $::form->{invoice_ids} = {
    $bt->id => [ $ar_transaction->id ]
  };

  save_btcontroller_to_string();

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

  my $bt = create_bank_transaction(record        => $ar_transaction,
                                   bank_chart_id => $bank->id,
                                   amount        => $ar_transaction->amount_less_skonto
                                  ) or die "Couldn't create bank_transaction";

  $::form->{invoice_ids} = {
    $bt->id => [ $ar_transaction->id ]
  };
  $::form->{invoice_skontos} = {
    $bt->id => [ 'with_skonto_pt' ]
  };

  save_btcontroller_to_string();

  $ar_transaction->load;
  $bt->load;
  is($ar_transaction->paid   , '119.00000' , "$testname: salesinv skonto was paid");
  is($ar_transaction->closed , 1           , "$testname: salesinv skonto is closed");
  is($bt->invoice_amount     , '113.05000' , "$testname: bt invoice amount was assigned");

};

sub test_bt_error {

  my $testname = 'test_rollback_error';
  # without type with_free_skonto the helper function (Payment.pm) looks ugly but not
  # breakable

  $ar_transaction = test_ar_transaction(invnumber   => 'salesinv skonto',
                                        payment_id  => $payment_terms->id,
                                        taxincluded => 0,
                                        amount      => 168.58 / 1.19,
                                       );

  my $bt = create_bank_transaction(record        => $ar_transaction,
                                   bank_chart_id => $bank->id,
                                   amount        => 160.15,
                                  ) or die "Couldn't create bank_transaction";
  $::form->{invoice_ids} = {
    $bt->id => [ $ar_transaction->id ]
  };
  $::form->{invoice_skontos} = {
    $bt->id => [ 'with_skonto_pt' ]
  };

  is($ar_transaction->paid   , '0' , "$testname: salesinv is not paid");

  # generate an error for testing rollback mechanism
  my $saved_skonto_sales_chart_id = $tax->skonto_sales_chart_id;
  $tax->skonto_sales_chart_id(undef);
  $tax->save;

  save_btcontroller_to_string();
  my @bt_errors = @{ $bt_controller->problems };
  is(substr($bt_errors[0]->{message},0,38), 'Kein Skontokonto für Steuerschlüssel 3', "$testname: Fehlermeldung ok");
  # set original value
  $tax->skonto_sales_chart_id($saved_skonto_sales_chart_id);
  $tax->save;

  $ar_transaction->load;
  $bt->load;
  is($ar_transaction->paid   , '0.00000' , "$testname: salesinv was not paid");
  is($bt->invoice_amount     , '0.00000' , "$testname: bt invoice amount was not assigned");

};

sub test_two_invoices {

  my $testname = 'test_two_invoices';

  my $ar_transaction_1 = test_ar_transaction(invnumber => 'salesinv_1');
  my $ar_transaction_2 = test_ar_transaction(invnumber => 'salesinv_2');

  my $bt = create_bank_transaction(record        => $ar_transaction_1,
                                   amount        => ($ar_transaction_1->amount + $ar_transaction_2->amount),
                                   purpose       => "Rechnungen " . $ar_transaction_1->invnumber . " und " . $ar_transaction_2->invnumber,
                                   bank_chart_id => $bank->id,
                                  ) or die "Couldn't create bank_transaction";

  my ($agreement, $rule_matches) = $bt->get_agreement_with_invoice($ar_transaction_1);
  is($agreement, 16, "points for ar_transaction_1 in test_two_invoices ok");

  $::form->{invoice_ids} = {
    $bt->id => [ $ar_transaction_1->id, $ar_transaction_2->id ]
  };

  save_btcontroller_to_string();

  $ar_transaction_1->load;
  $ar_transaction_2->load;
  $bt->load;

  is($ar_transaction_1->paid   , '119.00000' , "$testname: salesinv_1 wcsv_import_reportsas paid");
  is($ar_transaction_1->closed , 1           , "$testname: salesinv_1 is closed");
  is($ar_transaction_2->paid   , '119.00000' , "$testname: salesinv_2 was paid");
  is($ar_transaction_2->closed , 1           , "$testname: salesinv_2 is closed");
  is($bt->invoice_amount       , '238.00000' , "$testname: bt invoice amount was assigned");

}

sub test_one_inv_and_two_invoices_with_skonto_exact {

  my $testname = 'test_two_invoices_with_skonto_exact';

  my $ar_transaction_1 = test_ar_transaction(invnumber => 'salesinv 1 skonto',
                                             payment_id => $payment_terms->id,
                                            );
  my $ar_transaction_2 = test_ar_transaction(invnumber => 'salesinv 2 skonto',
                                             payment_id => $payment_terms->id,
                                            );
  my $ar_transaction_3 = test_ar_transaction(invnumber => 'salesinv 3 no skonto');



  my $bt = create_bank_transaction(record        => $ar_transaction_1,
                                   bank_chart_id => $bank->id,
                                   amount        => $ar_transaction_1->amount_less_skonto * 2 + $ar_transaction_3->amount
                                  ) or die "Couldn't create bank_transaction";

  $::form->{invoice_ids} = {
    $bt->id => [ $ar_transaction_1->id, $ar_transaction_3->id, $ar_transaction_2->id]
  };
  $::form->{invoice_skontos} = {
    $bt->id => [ 'with_skonto_pt', 'without_skonto', 'with_skonto_pt' ]
  };

  save_btcontroller_to_string();

  $ar_transaction_1->load;
  $ar_transaction_2->load;
  $ar_transaction_3->load;
  my $skonto_1 = SL::DB::Manager::AccTransaction->find_by(trans_id => $ar_transaction_1->id, chart_id => 162);
  my $skonto_2 = SL::DB::Manager::AccTransaction->find_by(trans_id => $ar_transaction_2->id, chart_id => 162);
  $bt->load;
  is($skonto_1->amount   , '-5.95000' , "$testname: salesinv 1 skonto was booked");
  is($skonto_2->amount   , '-5.95000' , "$testname: salesinv 2 skonto was booked");
  is($ar_transaction_1->paid   , '119.00000' , "$testname: salesinv 1 was paid");
  is($ar_transaction_2->paid   , '119.00000' , "$testname: salesinv 2 was paid");
  is($ar_transaction_3->paid   , '119.00000' , "$testname: salesinv 3 was paid");
  is($ar_transaction_1->closed , 1           , "$testname: salesinv 1 skonto is closed");
  is($ar_transaction_2->closed , 1           , "$testname: salesinv 2 skonto is closed");
  is($ar_transaction_3->closed , 1           , "$testname: salesinv 2 skonto is closed");
  is($bt->invoice_amount     , '345.10000' , "$testname: bt invoice amount was assigned");

}

sub test_overpayment {

  my $testname = 'test_overpayment';

  $ar_transaction = test_ar_transaction(invnumber => 'salesinv overpaid');

  # amount 135 > 119
  my $bt = create_bank_transaction(record        => $ar_transaction,
                                   bank_chart_id => $bank->id,
                                   amount        => 135
                                  ) or die "Couldn't create bank_transaction";

  $::form->{invoice_ids} = {
    $bt->id => [ $ar_transaction->id ]
  };

  save_btcontroller_to_string();

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

  my $bt_1 = create_bank_transaction(record        => $ar_transaction,
                                     bank_chart_id => $bank->id,
                                     amount        =>  10
                                    ) or die "Couldn't create bank_transaction";
  my $bt_2 = create_bank_transaction(record        => $ar_transaction,
                                     amount        => 119,
                                     transdate     => DateTime->today->add(days => 5),
                                     bank_chart_id => $bank->id,
                                    ) or die "Couldn't create bank_transaction";

  $::form->{invoice_ids} = {
    $bt_1->id => [ $ar_transaction->id ]
  };
  save_btcontroller_to_string();

  $::form->{invoice_ids} = {
    $bt_2->id => [ $ar_transaction->id ]
  };
  save_btcontroller_to_string();

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
  my $bt = create_bank_transaction(record        => $ar_transaction,
                                   bank_chart_id => $bank->id,
                                   amount        => 100
                                  ) or die "Couldn't create bank_transaction";

  $::form->{invoice_ids} = {
    $bt->id => [ $ar_transaction->id ]
  };

  save_btcontroller_to_string();

  $ar_transaction->load;
  $bt->load;

  is($ar_transaction->paid , '100.00000' , "$testname: 'salesinv partial payment' was partially paid");
  is($bt->invoice_amount   , '100.00000' , "$testname: bt invoice amount was assigned partially paid amount");

};

sub test_credit_note {

  my $testname = 'test_credit_note';

  my $part1 = new_part(   partnumber => 'T4254')->save;
  my $part2 = new_service(partnumber => 'Serv1')->save;
  my $credit_note = create_credit_note(
    invnumber    => 'cn 1',
    customer     => $customer,
    taxincluded  => 0,
    invoiceitems => [ create_invoice_item(part => $part1, qty =>  3, sellprice => 70),
                      create_invoice_item(part => $part2, qty => 10, sellprice => 50),
                    ]
  );
  my $bt            = create_bank_transaction(record        => $credit_note,
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

  save_btcontroller_to_string();

  $credit_note->load;
  $bt->load;
  is($credit_note->amount   , '-844.90000', "$testname: amount ok");
  is($credit_note->netamount, '-710.00000', "$testname: netamount ok");
  is($credit_note->paid     , '-844.90000', "$testname: paid ok");
}

sub test_neg_ap_transaction {
  my (%params) = @_;
  my $testname = 'test_neg_ap_transaction' . $params{invoice} ? ' invoice booking' : ' credit booking';
  my $netamount = -20;
  my $amount    = $::form->round_amount($netamount * 1.19,2);
  my $invoice   = SL::DB::PurchaseInvoice->new(
    invoice      => $params{invoice} // 0,
    invnumber    => $params{invnumber} || 'test_neg_ap_transaction',
    amount       => $amount,
    netamount    => $netamount,
    transdate    => $transdate1,
    taxincluded  => 0,
    vendor_id    => $vendor->id,
    taxzone_id   => $vendor->taxzone_id,
    currency_id  => $currency_id,
    transactions => [],
    notes        => 'test_neg_ap_transaction',
  );
  $invoice->add_ap_amount_row(
    amount     => $invoice->netamount,
    chart      => $ap_amount_chart,
    tax_id     => $tax_9->id,
  );

  $invoice->create_ap_row(chart => $ap_chart);
  $invoice->save;

  is($invoice->netamount, -20  , "$testname: netamount ok");
  is($invoice->amount   , -23.8, "$testname: amount ok");

  my $bt            = create_bank_transaction(record        => $invoice,
                                              amount        => $invoice->amount,
                                              bank_chart_id => $bank->id,
                                              transdate     => DateTime->today->add(days => 10),
                                                               );
  my ($agreement, $rule_matches) = $bt->get_agreement_with_invoice($invoice);
  is($agreement, 15, "points for negative ap transaction ok");

  $::form->{invoice_ids} = {
    $bt->id => [ $invoice->id ]
  };

  save_btcontroller_to_string();

  $invoice->load;
  $bt->load;

  is($invoice->amount   , '-23.80000', "$testname: amount ok");
  is($invoice->netamount, '-20.00000', "$testname: netamount ok");
  is($invoice->paid     , '-23.80000', "$testname: paid ok");
  is($bt->invoice_amount, '23.80000', "$testname: bt invoice amount for ap was assigned");

  return $invoice;
};
sub test_two_neg_ap_transaction {
  my $testname='test_two_neg_ap_transaction';
  my $netamount = -20;
  my $amount    = $::form->round_amount($netamount * 1.19,2);
  my $invoice   = SL::DB::PurchaseInvoice->new(
    invoice      =>  0,
    invnumber    => 'test_neg_ap_transaction',
    amount       => $amount,
    netamount    => $netamount,
    transdate    => $transdate1,
    taxincluded  => 0,
    vendor_id    => $vendor->id,
    taxzone_id   => $vendor->taxzone_id,
    currency_id  => $currency_id,
    transactions => [],
    notes        => 'test_neg_ap_transaction',
  );
  $invoice->add_ap_amount_row(
    amount     => $invoice->netamount,
    chart      => $ap_amount_chart,
    tax_id     => $tax_9->id,
  );

  $invoice->create_ap_row(chart => $ap_chart);
  $invoice->save;

  is($invoice->netamount, -20  , "$testname: netamount ok");
  is($invoice->amount   , -23.8, "$testname: amount ok");

  my $netamount_two = -1.14;
  my $amount_two    = $::form->round_amount($netamount_two * 1.19,2);
  my $invoice_two   = SL::DB::PurchaseInvoice->new(
    invoice      => 0,
    invnumber    => 'test_neg_ap_transaction_two',
    amount       => $amount_two,
    netamount    => $netamount_two,
    transdate    => $transdate1,
    taxincluded  => 0,
    vendor_id    => $vendor->id,
    taxzone_id   => $vendor->taxzone_id,
    currency_id  => $currency_id,
    transactions => [],
    notes        => 'test_neg_ap_transaction_two',
  );
  $invoice_two->add_ap_amount_row(
    amount     => $invoice_two->netamount,
    chart      => $ap_amount_chart,
    tax_id     => $tax_9->id,
  );

  $invoice_two->create_ap_row(chart => $ap_chart);
  $invoice_two->save;

  is($invoice_two->netamount, -1.14  , "$testname: netamount ok");
  is($invoice_two->amount   , -1.36, "$testname: amount ok");


  my $bt            = create_bank_transaction(record        => $invoice_two,
                                              amount        => $invoice_two->amount + $invoice->amount,
                                              bank_chart_id => $bank->id,
                                              transdate     => DateTime->today->add(days => 10),
                                                               );
  # my ($agreement, $rule_matches) = $bt->get_agreement_with_invoice($invoice_two);
  # is($agreement, 15, "points for negative ap transaction ok");

  $::form->{invoice_ids} = {
    $bt->id => [ $invoice->id, $invoice_two->id ]
  };

  save_btcontroller_to_string();

  $invoice->load;
  $invoice_two->load;
  $bt->load;

  is($invoice->amount   , '-23.80000', "$testname: first inv amount ok");
  is($invoice->netamount, '-20.00000', "$testname: first inv netamount ok");
  is($invoice->paid     , '-23.80000', "$testname: first inv paid ok");
  is($invoice_two->amount   , '-1.36000', "$testname: second inv amount ok");
  is($invoice_two->netamount, '-1.14000', "$testname: second inv netamount ok");
  is($invoice_two->paid     , '-1.36000', "$testname: second inv paid ok");
  is($bt->invoice_amount, '25.16000', "$testname: bt invoice amount for both invoices were assigned");


  return ($invoice, $invoice_two);
};

sub test_ap_payment_transaction {
  my (%params) = @_;
  my $testname = 'test_ap_payment_transaction';
  my $netamount = 115;
  my $amount    = $::form->round_amount($netamount * 1.19,2);
  my $invoice   = SL::DB::PurchaseInvoice->new(
    invoice      => 0,
    invnumber    => $params{invnumber} || $testname,
    amount       => $amount,
    netamount    => $netamount,
    transdate    => $transdate1,
    taxincluded  => 0,
    vendor_id    => $vendor->id,
    taxzone_id   => $vendor->taxzone_id,
    currency_id  => $currency_id,
    transactions => [],
    notes        => $testname,
  );
  $invoice->add_ap_amount_row(
    amount     => $invoice->netamount,
    chart      => $ap_amount_chart,
    tax_id     => $tax_9->id,
  );

  $invoice->create_ap_row(chart => $ap_chart);
  $invoice->save;

  is($invoice->netamount, 115  , "$testname: netamount ok");
  is($invoice->amount   , 136.85, "$testname: amount ok");

  my $bt            = create_bank_transaction(record        => $invoice,
                                              amount        => $invoice->amount,
                                              bank_chart_id => $bank->id,
                                              transdate     => DateTime->today->add(days => 10),
                                             );
  $::form->{invoice_ids} = {
    $bt->id => [ $invoice->id ]
  };

  save_btcontroller_to_string();

  $invoice->load;
  $bt->load;

  is($invoice->amount   , '136.85000', "$testname: amount ok");
  is($invoice->netamount, '115.00000', "$testname: netamount ok");
  is($bt->amount, '-136.85000', "$testname: bt amount ok");
  is($invoice->paid     , '136.85000', "$testname: paid ok");
  is($bt->invoice_amount, '-136.85000', "$testname: bt invoice amount for ap was assigned");

  return $invoice;
};

sub test_ap_payment_part_transaction {
  my (%params) = @_;
  my $testname = 'test_ap_payment_p_transaction';
  my $netamount = 115;
  my $amount    = $::form->round_amount($netamount * 1.19,2);
  my $invoice   = SL::DB::PurchaseInvoice->new(
    invoice      => 0,
    invnumber    => $params{invnumber} || $testname,
    amount       => $amount,
    netamount    => $netamount,
    transdate    => $transdate1,
    taxincluded  => 0,
    vendor_id    => $vendor->id,
    taxzone_id   => $vendor->taxzone_id,
    currency_id  => $currency_id,
    transactions => [],
    notes        => $testname,
  );
  $invoice->add_ap_amount_row(
    amount     => $invoice->netamount,
    chart      => $ap_amount_chart,
    tax_id     => $tax_9->id,
  );

  $invoice->create_ap_row(chart => $ap_chart);
  $invoice->save;

  is($invoice->netamount, 115  , "$testname: netamount ok");
  is($invoice->amount   , 136.85, "$testname: amount ok");

  my $bt            = create_bank_transaction(record        => $invoice,
                                              amount        => $invoice->amount-100,
                                              bank_chart_id => $bank->id,
                                              transdate     => DateTime->today->add(days => 10),
                                             );
  $::form->{invoice_ids} = {
    $bt->id => [ $invoice->id ]
  };

  save_btcontroller_to_string();

  $invoice->load;
  $bt->load;

  is($invoice->amount   , '136.85000', "$testname: amount ok");
  is($invoice->netamount, '115.00000', "$testname: netamount ok");
  is($bt->amount,         '-36.85000', "$testname: bt amount ok");
  is($invoice->paid     ,  '36.85000', "$testname: paid ok");
  is($bt->invoice_amount, '-36.85000', "$testname: bt invoice amount for ap was assigned");

  my $bt2           = create_bank_transaction(record        => $invoice,
                                              amount        => 100,
                                              bank_chart_id => $bank->id,
                                              transdate     => DateTime->today->add(days => 10),
                                             );
  $::form->{invoice_ids} = {
    $bt2->id => [ $invoice->id ]
  };

  save_btcontroller_to_string();
  $invoice->load;
  $bt2->load;

  is($invoice->amount   , '136.85000', "$testname: amount ok");
  is($invoice->netamount, '115.00000', "$testname: netamount ok");
  is($bt2->amount,        '-100.00000',"$testname: bt amount ok");
  is($invoice->paid     , '136.85000', "$testname: paid ok");
  is($bt2->invoice_amount,'-100.00000', "$testname: bt invoice amount for ap was assigned");

  return $invoice;
};

sub test_neg_sales_invoice {

  my $testname = 'test_neg_sales_invoice';

  my $part1 = new_part(   partnumber => 'Funkenhaube öhm')->save;
  my $part2 = new_service(partnumber => 'Service-Pauschale Pasch!')->save;

  my $neg_sales_inv = create_sales_invoice(
    invnumber    => '20172201',
    customer     => $customer,
    taxincluded  => 0,
    invoiceitems => [ create_invoice_item(part => $part1, qty =>  3, sellprice => 70),
                      create_invoice_item(part => $part2, qty => 10, sellprice => -50),
                    ]
  );
  my $bt            = create_bank_transaction(record        => $neg_sales_inv,
                                                                amount        => $neg_sales_inv->amount,
                                                                bank_chart_id => $bank->id,
                                                                transdate     => DateTime->today,
                                                               );
  $::form->{invoice_ids} = {
    $bt->id => [ $neg_sales_inv->id ]
  };

  save_btcontroller_to_string();

  $neg_sales_inv->load;
  $bt->load;
  is($neg_sales_inv->amount   , '-345.10000', "$testname: amount ok");
  is($neg_sales_inv->netamount, '-290.00000', "$testname: netamount ok");
  is($neg_sales_inv->paid     , '-345.10000', "$testname: paid ok");
  is($bt->amount              , '-345.10000', "$testname: bt amount ok");
  is($bt->invoice_amount      , '-345.10000', "$testname: bt invoice_amount ok");
}

sub test_bt_rule1 {

  my $testname = 'test_bt_rule1';

  $ar_transaction = test_ar_transaction(invnumber => 'bt_rule1');

  my $bt = create_bank_transaction(record => $ar_transaction) or die "Couldn't create bank_transaction";

  $ar_transaction->load;
  $bt->load;
  is($ar_transaction->paid   , '0.00000' , "$testname: not paid");
  is($bt->invoice_amount     , '0.00000' , "$testname: bt invoice amount was not assigned");

  my $bt_controller = SL::Controller::BankTransaction->new;
  $::form->{dont_render_for_test} = 1;
  $::form->{filter}{bank_account} = $bank_account->id;
  my ( $bt_transactions, $proposals ) = $bt_controller->action_list;

  is(scalar(@$bt_transactions)         , 1  , "$testname: one bank_transaction");
  is($bt_transactions->[0]->{agreement}, 20 , "$testname: agreement == 20");
  my $match = join ( ' ',@{$bt_transactions->[0]->{rule_matches}});
  #print "rule_matches='".$match."'\n";
  is($match,
     "remote_account_number(3) exact_amount(4) own_invoice_in_purpose(5) depositor_matches(2) remote_name(2) payment_within_30_days(1) datebonus0(3) ",
     "$testname: rule_matches ok");
  $bt->invoice_amount($bt->amount);
  $bt->save;
  is($bt->invoice_amount     , '119.00000' , "$testname: bt invoice amount now set");
};

sub test_sepa_export {

  my $testname = 'test_sepa_export';

  $ar_transaction = test_ar_transaction(invnumber => 'sepa1');

  my $bt  = create_bank_transaction(record => $ar_transaction) or die "Couldn't create bank_transaction";
  my $se  = create_sepa_export();
  my $sei = create_sepa_export_item(
    chart_id       => $bank->id,
    ar_id          => $ar_transaction->id,
    sepa_export_id => $se->id,
    vc_iban        => $customer->iban,
    vc_bic         => $customer->bic,
    vc_mandator_id => $customer->mandator_id,
    vc_depositor   => $customer->depositor,
    amount         => $ar_transaction->amount,
  );
  require SL::SEPA::XML;
  my $sepa_xml   = SL::SEPA::XML->new('company'     => $customer->name,
                                      'creditor_id' => "id",
                                      'src_charset' => 'UTF-8',
                                      'message_id'  => "test",
                                      'grouped'     => 1,
                                      'collection'  => 1,
                                     );
  is($sepa_xml->{company}    , 'Test Customer OLE S.L. Ardbaerg AB');

  $ar_transaction->load;
  $bt->load;
  $sei->load;
  is($ar_transaction->paid   , '0.00000' , "$testname: sepa1 not paid");
  is($bt->invoice_amount     , '0.00000' , "$testname: bt invoice amount was not assigned");
  is($bt->amount             , '119.00000' , "$testname: bt amount ok");
  is($sei->amount            , '119.00000' , "$testname: sepa export amount ok");

  my $bt_controller = SL::Controller::BankTransaction->new;
  $::form->{dont_render_for_test} = 1;
  $::form->{filter}{bank_account} = $bank_account->id;
  my ( $bt_transactions, $proposals ) = $bt_controller->action_list;

  is(scalar(@$bt_transactions)         , 1  , "$testname: one bank_transaction");
  is($bt_transactions->[0]->{agreement}, 25 , "$testname: agreement == 25");
  my $match = join ( ' ',@{$bt_transactions->[0]->{rule_matches}});
  is($match,
     "remote_account_number(3) exact_amount(4) own_invoice_in_purpose(5) depositor_matches(2) remote_name(2) payment_within_30_days(1) datebonus0(3) sepa_export_item(5) ",
     "$testname: rule_matches ok");
};

sub test_two_banktransactions {

  my $testname = 'two_banktransactions';

  my $ar_transaction_1 = test_ar_transaction(invnumber => 'salesinv10000' , amount => 2912.00 );
  my $bt1 = create_bank_transaction(record        => $ar_transaction_1,
                                    amount        => $ar_transaction_1->amount,
                                    purpose       => "Rechnung10000 beinahe",
                                    bank_chart_id => $bank->id,
                                  ) or die "Couldn't create bank_transaction";

  my $bt2 = create_bank_transaction(record        => $ar_transaction_1,
                                    amount        => $ar_transaction_1->amount + 0.01,
                                    purpose       => "sicher salesinv20000 vielleicht",
                                    bank_chart_id => $bank->id,
                                  ) or die "Couldn't create bank_transaction";

  my ($agreement1, $rule_matches1) = $bt1->get_agreement_with_invoice($ar_transaction_1);
  is($agreement1, 19, "bt1 19 points for ar_transaction_1 in $testname ok");
  #print "rule_matches1=".$rule_matches1."\n";
  is($rule_matches1,
     "remote_account_number(3) exact_amount(4) own_invnumber_in_purpose(4) depositor_matches(2) remote_name(2) payment_within_30_days(1) datebonus0(3) ",
     "$testname: rule_matches ok");
  my ($agreement2, $rule_matches2) = $bt2->get_agreement_with_invoice($ar_transaction_1);
  is($agreement2, 11, "bt2 11 points for ar_transaction_1 in $testname ok");
  is($rule_matches2,
     "remote_account_number(3) depositor_matches(2) remote_name(2) payment_within_30_days(1) datebonus0(3) ",
     "$testname: rule_matches ok");

  my $ar_transaction_2 = test_ar_transaction(invnumber => 'salesinv20000' , amount => 2912.01 );
  my $ar_transaction_3 = test_ar_transaction(invnumber => 'zweitemit10000', amount => 2912.00 );
     ($agreement1, $rule_matches1) = $bt1->get_agreement_with_invoice($ar_transaction_2);

  is($agreement1, 11, "bt1 11 points for ar_transaction_2 in $testname ok");

     ($agreement2, $rule_matches2) = $bt2->get_agreement_with_invoice($ar_transaction_2);
  is($agreement2, 20, "bt2 20 points for ar_transaction_2 in $testname ok");

     ($agreement2, $rule_matches2) = $bt2->get_agreement_with_invoice($ar_transaction_1);
  is($agreement2, 11, "bt2 11 points for ar_transaction_1 in $testname ok");

  my $bt3 = create_bank_transaction(record        => $ar_transaction_3,
                                    amount        => $ar_transaction_3->amount,
                                    purpose       => "sicher Rechnung10000 vielleicht",
                                    bank_chart_id => $bank->id,
                                  ) or die "Couldn't create bank_transaction";

  my ($agreement3, $rule_matches3) = $bt3->get_agreement_with_invoice($ar_transaction_3);
  is($agreement3, 19, "bt3 19 points for ar_transaction_3 in $testname ok");

  $bt2->delete;
  $ar_transaction_2->delete;

  #nun sollten zwei gleichwertige Rechnungen $ar_transaction_1 und $ar_transaction_3 für $bt1 gefunden werden
  #aber es darf keine Proposals geben mit mehreren Rechnungen
  my $bt_controller = SL::Controller::BankTransaction->new;
  $::form->{dont_render_for_test} = 1;
  $::form->{filter}{bank_account} = $bank_account->id;
  my ( $bt_transactions, $proposals ) = $bt_controller->action_list;

  is(scalar(@$bt_transactions)   , 2  , "$testname: two bank_transaction");
  is(scalar(@$proposals)         , 0  , "$testname: no proposals");

  $ar_transaction_3->delete;

  # Jetzt gibt es zwei Kontobewegungen mit gleichen Punkten für eine Rechnung.
  # hier darf es auch keine Proposals geben

  ( $bt_transactions, $proposals ) = $bt_controller->action_list;

  is(scalar(@$bt_transactions)   , 2  , "$testname: two bank_transaction");
  is(scalar(@$proposals)         , 0  , "$testname: no proposals");

  # Jetzt gibt es zwei Kontobewegungen für eine Rechnung.
  # eine Bewegung bekommt mehr Punkte
  # hier darf es auch keine Proposals geben
  $bt3->update_attributes( purpose => "fuer Rechnung salesinv10000");

  ( $bt_transactions, $proposals ) = $bt_controller->action_list;

  is(scalar(@$bt_transactions)   , 2  , "$testname: two bank_transaction");
  is(scalar(@$proposals)         , 1  , "$testname: one proposal");

};


1;
