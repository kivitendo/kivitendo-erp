use Test::More tests => 449;

use strict;

use lib 't';
use utf8;

use Carp;
use Support::TestSetup;
use Test::Exception;
use List::Util qw(sum);

use SL::DB::AccTransaction;
use SL::DB::BankTransactionAccTrans;
use SL::DB::Buchungsgruppe;
use SL::DB::Currency;
use SL::DB::Customer;
use SL::DB::Default;
use SL::DB::Exchangerate;
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
use SL::Controller::Reconciliation;
use SL::Dev::ALL qw(:ALL);
use Data::Dumper;

my ($customer, $vendor, $currency_id, $unit, $tax, $tax0, $tax7, $tax_9, $payment_terms, $bank_account);
my ($currency, $currency_usd, $fxgain_chart, $fxloss_chart);
my ($ar_chart,$bank,$ar_amount_chart, $ap_chart, $ap_amount_chart);
my ($ar_transaction, $ap_transaction);
my ($dt, $dt_5, $dt_10, $year);

sub clear_up {

  SL::DB::Manager::BankTransactionAccTrans->delete_all(all => 1);
  SL::DB::Manager::BankTransaction->delete_all(all => 1);
  SL::DB::Manager::GLTransaction->delete_all(all => 1);
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
  SL::DB::Manager::Exchangerate->delete_all(all => 1);
  SL::DB::Manager::Currency->delete_all(where => [ name => 'CUR' ]);
  SL::DB::Manager::Currency->delete_all(where => [ name => 'USD' ]);
  # SL::DB::Manager::Default->delete_all(all => 1);
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

negative_ap_transaction_fx_gain_fees();
test_negative_ar_transaction_fx_loss();
test_ar_transaction_fx_loss();
test_ar_transaction_fx_gain();
test_ar_transaction_fx_partial_payment();
#test_neg_sales_invoice_fx();
negative_ap_transaction_fx_gain_fees_error();

ap_transaction_fx_gain_fees();
ap_transaction_fx_gain_fees_two_payments();
ap_transaction_fx_loss_fees();

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
test_full_workflow_ar_multiple_inv_skonto_reconciliate_and_undo();
reset_state();
test_sepa_export();
reset_state();
test_bt_rule1();
reset_state();
test_two_banktransactions();
test_closedto();
test_fuzzy_skonto_pt();
test_fuzzy_skonto_pt_not_in_range();
reset_state();
test_sepa_export_endtoend();
# remove all created data at end of test
clear_up();

done_testing();

###### functions for setting up data

sub reset_state {
  my %params = @_;

  $params{$_} ||= {} for qw(unit customer tax vendor);

  clear_up();

  $year  = DateTime->today_local->year;
  $year  = 2019 if $year == 2020; # use year 2019 in 2020, because of tax rate change in Germany
  $dt    = DateTime->new(year => $year, month => 1, day => 12);
  $dt_5  = $dt->clone->add(days => 5);
  $dt_10 = $dt->clone->add(days => 10);

  $tax             = SL::DB::Manager::Tax->find_by(taxkey => 3, rate => 0.19, %{ $params{tax} }) || croak "No tax";
  $tax7            = SL::DB::Manager::Tax->find_by(taxkey => 2, rate => 0.07)                    || croak "No tax for 7\%";
  $tax_9           = SL::DB::Manager::Tax->find_by(taxkey => 9, rate => 0.19, %{ $params{tax} }) || croak "No tax for 19\%";
  $tax0            = SL::DB::Manager::Tax->find_by(taxkey => 0, rate => 0.0)                     || croak "No tax for 0\%";

  $currency_id     = $::instance_conf->get_currency_id;

  $currency_usd    = SL::DB::Currency->new(name => 'USD')->save;
  $fxgain_chart = SL::DB::Manager::Chart->find_by(accno => '2660') or die "Can't find fxgain_chart in test";
  $fxloss_chart = SL::DB::Manager::Chart->find_by(accno => '2150') or die "Can't find fxloss_chart in test";
  $currency_usd->db->dbh->do('UPDATE defaults SET fxgain_accno_id = ' . $fxgain_chart->id);
  $currency_usd->db->dbh->do('UPDATE defaults SET fxloss_accno_id = ' . $fxloss_chart->id);
  $::instance_conf->reload->data;
  is($fxgain_chart->id,  $::instance_conf->get_fxgain_accno_id, "fxgain_chart was updated in defaults");
  is($fxloss_chart->id,  $::instance_conf->get_fxloss_accno_id, "fxloss_chart was updated in defaults");



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
    mandate_date_of_signature => $dt,
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
  my $netamount = $::form->round_amount($params{amount}, 2) || 100;
  my $amount    = $::form->round_amount($netamount * 1.19,2);
  my $invoice   = SL::DB::Invoice->new(
      invoice      => 0,
      invnumber    => $params{invnumber} || undef, # let it use its own invnumber
      amount       => $amount,
      netamount    => $netamount,
      transdate    => $dt,
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
    transdate    => $dt,
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

  my $bt = create_bank_transaction(record      => $ar_transaction,
                                   transdate   => $dt,
                                   valutadate  => $dt) or die "Couldn't create bank_transaction";

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
                                   transdate     => $dt,
                                   valutadate    => $dt,
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
                                   transdate   => $dt,
                                   valutadate  => $dt,
                                   amount        => 160.15,
                                  ) or die "Couldn't create bank_transaction";
  $::form->{invoice_ids} = {
    $bt->id => [ $ar_transaction->id ]
  };
  $::form->{invoice_skontos} = {
    $bt->id => [ 'with_skonto_pt' ]
  };
  is($ar_transaction->netamount, $::form->round_amount(168.58/1.19, 2), "$testname: Net Amount assigned");
  is($ar_transaction->amount, 168.58, "$testname: Amount assigned");
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
                                   transdate     => $dt,
                                   valutadate    => $dt,
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
                                   transdate     => $dt,
                                   valutadate    => $dt,
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
                                   transdate   => $dt,
                                   valutadate  => $dt,
                                   amount        => 135
                                  ) or die "Couldn't create bank_transaction";

  $::form->{invoice_ids} = {
    $bt->id => [ $ar_transaction->id ]
  };

  save_btcontroller_to_string();

  $ar_transaction->load;
  $bt->load;

  is($ar_transaction->paid                     , '119.00000' , "$testname: 'salesinv overpaid' was not overpaid");
  is($bt->invoice_amount                       , '119.00000' , "$testname: bt invoice amount was not fully assigned with the overpaid amount");
{ local $TODO = 'this currently fails because closed ignores over-payments, see commit d90966c7';
  is($ar_transaction->closed                   , 0           , "$testname: 'salesinv overpaid' is open (via 'closed' method')");
}
  is($ar_transaction->open_amount == 0 ? 1 : 0 , 1           , "$testname: 'salesinv overpaid is closed (via amount-paid)");

};

sub test_overpayment_with_partialpayment {

  # two payments on different days, 10 and 119. If there is only one invoice we
  # don't want it to be overpaid.
  my $testname = 'test_overpayment_with_partialpayment';

  $ar_transaction = test_ar_transaction(invnumber => 'salesinv overpaid partial');

  my $bt_1 = create_bank_transaction(record        => $ar_transaction,
                                     bank_chart_id => $bank->id,
                                     transdate   => $dt,
                                     valutadate  => $dt,
                                     amount        =>  10
                                    ) or die "Couldn't create bank_transaction";
  my $bt_2 = create_bank_transaction(record        => $ar_transaction,
                                     amount        => 119,
                                     transdate     => $dt_5,
                                     valutadate    => $dt_5,
                                     bank_chart_id => $bank->id,
                                    ) or die "Couldn't create bank_transaction";

  $::form->{invoice_ids} = {
    $bt_1->id => [ $ar_transaction->id ]
  };
  save_btcontroller_to_string();

  $bt_1->load;
  is($bt_1->invoice_amount ,  '10.00000' , "$testname: bt_1 invoice amount was fully assigned");
  $::form->{invoice_ids} = {
    $bt_2->id => [ $ar_transaction->id ]
  };
  save_btcontroller_to_string();

  $ar_transaction->load;
  $bt_2->load;

  is($bt_1->invoice_amount ,  '10.00000' , "$testname: bt_1 invoice amount was fully assigned");
  is($ar_transaction->paid , '119.00000' , "$testname: 'salesinv overpaid partial' was not overpaid");
  is($bt_2->invoice_amount , '109.00000' , "$testname: bt_2 invoice amount was partly assigned");

};

sub test_partial_payment {

  my $testname = 'test_partial_payment';

  $ar_transaction = test_ar_transaction(invnumber => 'salesinv partial payment');

  # amount 100 < 119
  my $bt = create_bank_transaction(record        => $ar_transaction,
                                   bank_chart_id => $bank->id,
                                   transdate     => $dt,
                                   valutadate    => $dt,
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

  # addon test partial payment full point match
  my $bt2 = create_bank_transaction(record        => $ar_transaction,
                                    bank_chart_id => $bank->id,
                                    transdate     => $dt,
                                    valutadate    => $dt,
                                    amount        => 19
                                   ) or die "Couldn't create bank_transaction";

  my ($agreement, $rule_matches) = $bt2->get_agreement_with_invoice($ar_transaction);
  is($agreement, 15, "points for exact partial payment ok");
  is($rule_matches, 'remote_account_number(3) exact_open_amount(4) depositor_matches(2) remote_name(2) payment_within_30_days(1) datebonus0(3) ', "rules_matches for exact partial payment ok");
};

sub test_full_workflow_ar_multiple_inv_skonto_reconciliate_and_undo {

  my $testname = 'test_partial_payment';

  $ar_transaction = test_ar_transaction(invnumber => 'salesinv partial payment two');
  my $ar_transaction_2 = test_ar_transaction(invnumber => 'salesinv 2 22d2', amount => 22);

  # amount 299.29 > 119
  my $bt = create_bank_transaction(record        => $ar_transaction,
                                   bank_chart_id => $bank->id,
                                   amount        => 299.29
                                  ) or die "Couldn't create bank_transaction";

  $::form->{invoice_ids} = {
    $bt->id => [ $ar_transaction->id ]
  };

  save_btcontroller_to_string();

  $ar_transaction->load;
  $bt->load;

  is($ar_transaction->paid , '119.00000' , "$testname: 'salesinv partial payment' was fully paid");
  is($bt->invoice_amount   , '119.00000' , "$testname: bt invoice amount was assigned partially paid amount");
  is($bt->amount           , '299.29000' , "$testname: bt amount is stil there");
  # next invoice, same bank transaction
  $::form->{invoice_ids} = {
    $bt->id => [ $ar_transaction_2->id ]
  };

  save_btcontroller_to_string();

  $ar_transaction_2->load;
  $bt->load;
  is($ar_transaction_2->paid , '26.18000' , "$testname: 'salesinv partial payment' was fully paid");
  is($bt->invoice_amount   , '145.18000' , "$testname: bt invoice amount was assigned partially paid amount");
  is($bt->amount           , '299.29000' , "$testname: bt amount is stil there");
  is(scalar @{ SL::DB::Manager::BankTransactionAccTrans->get_all(where => [bank_transaction_id => $bt->id ] )}, 4, "$testname 4 acc_trans entries created");

  #  now check all 4 entries done so far and save paid acc_trans_ids for later use with reconcile
  foreach my $acc_trans_id_entry (@{ SL::DB::Manager::BankTransactionAccTrans->get_all(where => [bank_transaction_id => $bt->id ] )}) {
    isnt($acc_trans_id_entry->ar_id, undef, "$testname: bt linked with acc_trans and trans_id set");
    my $rl = SL::DB::Manager::RecordLink->get_all(where => [ from_id => $bt->id, from_table => 'bank_transactions', to_id => $acc_trans_id_entry->ar_id ]);
    is (ref $rl->[0], 'SL::DB::RecordLink', "$testname record link created");
    my $acc_trans = SL::DB::Manager::AccTransaction->get_all(where => [acc_trans_id => $acc_trans_id_entry->acc_trans_id]);
    foreach my $entry (@{ $acc_trans }) {
      like(abs($entry->amount), qr/(119|26.18)/, "$testname: abs amount correct");
      like($entry->chart_link, qr/(paid|AR)/, "$testname chart_link correct");
      push @{ $::form->{bb_ids} }, $entry->acc_trans_id if $entry->chart_link =~ m/paid/;
    }
  }
  # great we need one last booking to clear the whole bank transaction - we include skonto
  my $ar_transaction_skonto = test_ar_transaction(invnumber  => 'salesinv skonto last case',
                                                  payment_id => $payment_terms->id,
                                                  amount     => 136.32,
                                                 );

  $::form->{invoice_ids} = {
    $bt->id => [ $ar_transaction_skonto->id ]
  };
  $::form->{invoice_skontos} = {
    $bt->id => [ 'with_skonto_pt' ]
  };

  save_btcontroller_to_string();

  $ar_transaction_skonto->load;
  $bt->load;
  is($ar_transaction_skonto->paid , '162.22000' , "$testname: 'salesinv skonto fully paid");
  is($bt->invoice_amount   , '299.29000' , "$testname: bt invoice amount was assigned partially paid amount");
  is($bt->amount           , '299.29000' , "$testname: bt amount is stil there");
  is(scalar @{ SL::DB::Manager::BankTransactionAccTrans->get_all(where => [bank_transaction_id => $bt->id ] )},
       9, "$testname 9 acc_trans entries created");

  # same loop as above, but only for the 3rd ar_id
  foreach my $acc_trans_id_entry (@{ SL::DB::Manager::BankTransactionAccTrans->get_all(where => [ar_id => $ar_transaction_skonto->id ] )}) {
    isnt($acc_trans_id_entry->ar_id, '', "$testname: bt linked with acc_trans and trans_id set");
    my $rl = SL::DB::Manager::RecordLink->get_all(where => [ from_id => $bt->id, from_table => 'bank_transactions', to_id => $acc_trans_id_entry->ar_id ]);
    is (ref $rl->[0], 'SL::DB::RecordLink', "$testname record link created");
    my $acc_trans = SL::DB::Manager::AccTransaction->get_all(where => [acc_trans_id => $acc_trans_id_entry->acc_trans_id]);
    foreach my $entry (@{ $acc_trans }) {
      like($entry->chart_link, qr/(paid|AR)/, "$testname chart_link correct");
      is ($entry->amount, '162.22000', "$testname full amont") if $entry->chart_link eq 'AR'; # full amount
      like(abs($entry->amount), qr/(154.11|8.11)/, "$testname: abs amount correct") if $entry->chart_link =~ m/paid/;
      push @{ $::form->{bb_ids} }, $entry->acc_trans_id if ($entry->chart_link =~ m/paid/ && $entry->amount == -154.11);
    }
  }
  # done, now reconciliate all bookings
  $::form->{bt_ids} = [ $bt->id ];
  my $rec_controller = SL::Controller::Reconciliation->new;
  my @errors = $rec_controller->_get_elements_and_validate;

  is (scalar @errors, 0, "$testname unsuccesfull reconciliation with error: " . Dumper(@errors));
  $rec_controller->_reconcile;
  $bt->load;

  # and check the cleared state of bt and the acc_transactions
  is($bt->cleared, '1' , "$testname: bt cleared");
  foreach (@{ $::form->{bb_ids} }) {
    my $acc_trans = SL::DB::Manager::AccTransaction->find_by(acc_trans_id => $_);
    is($acc_trans->cleared, '1' , "$testname: acc_trans entry cleared");
  }
  # now, this was a really bad idea and in general a major mistake. better undo and redo the whole bank transactions

  $::form->{ids} = [ $bt->id ];
  $bt_controller = SL::Controller::BankTransaction->new;
  $bt_controller->action_unlink_bank_transaction('testcase' => 1);

  $bt->load;

  # and check the cleared state of bt and the acc_transactions
  is($bt->cleared, '0' , "$testname: bt undo cleared");
  is($bt->invoice_amount, '0.00000' , "$testname: bt undo invoice amount");
  foreach (@{ $::form->{bb_ids} }) {
    my $acc_trans = SL::DB::Manager::AccTransaction->find_by(acc_trans_id => $_);
    is($acc_trans, undef , "$testname: cleared acc_trans entry completely removed");
  }
  # this was for data integrity for reconcile, now all the other options
  is(scalar @{ SL::DB::Manager::BankTransactionAccTrans->get_all(where => [bank_transaction_id => $bt->id ] )},
       0, "$testname 7 acc_trans entries deleted");
  my $rl = SL::DB::Manager::RecordLink->get_all(where => [ from_id => $bt->id, from_table => 'bank_transactions' ]);
  is (ref $rl->[0], '', "$testname record link removed");
  # double safety and check ar.paid
  # load all three invoices and check for paid-link via acc_trans and paid in general
  $ar_transaction->load;
  $ar_transaction_2->load;
  $ar_transaction_skonto->load;

  is(scalar @{ SL::DB::Manager::AccTransaction->get_all(
     where => [ trans_id => $ar_transaction->id, chart_link => { like => '%paid%' } ])},
     0, "$testname no more paid entries in acc_trans for ar_transaction");
  is(scalar @{ SL::DB::Manager::AccTransaction->get_all(
     where => [ trans_id => $ar_transaction_2->id, chart_link => { like => '%paid%' } ])},
     0, "$testname no more paid entries in acc_trans for ar_transaction_2");
  is(scalar @{ SL::DB::Manager::AccTransaction->get_all(
     where => [ trans_id => $ar_transaction_skonto->id, chart_link => { like => '%paid%' } ])},
     0, "$testname no more paid entries in acc_trans for ar_transaction_skonto");

  is($ar_transaction->paid , '0.00000' , "$testname: 'salesinv fully unpaid");
  is($ar_transaction_2->paid , '0.00000' , "$testname: 'salesinv 2 fully unpaid");
  is($ar_transaction_skonto->paid , '0.00000' , "$testname: 'salesinv skonto fully unpaid");

  is($ar_transaction_skonto->datepaid, undef, "$testname: 'salesinv skonto no date paid");
  is($ar_transaction_2->datepaid,      undef, "$testname: 'salesinv 2 no date paid");
  is($ar_transaction->datepaid ,       undef, "$testname: 'salesinv no date paid");

  # whew. w(h)a(n)t a whole lotta test
}


sub test_credit_note {

  my $testname = 'test_credit_note';

  my $part1 = new_part(   partnumber => 'T4254')->save;
  my $part2 = new_service(partnumber => 'Serv1')->save;
  my $credit_note = create_credit_note(
    invnumber    => 'cn 1',
    customer     => $customer,
    transdate    => $dt,
    taxincluded  => 0,
    invoiceitems => [ create_invoice_item(part => $part1, qty =>  3, sellprice => 70),
                      create_invoice_item(part => $part2, qty => 10, sellprice => 50),
                    ]
  );
  is($credit_note->amount ,'-844.9' ,"$testname: amount before booking ok");
  is($credit_note->paid   ,'0'      ,"$testname: paid before booking ok");
  my $bt            = create_bank_transaction(record        => $credit_note,
                                              amount        => abs($credit_note->amount),
                                              bank_chart_id => $bank->id,
                                              transdate     => $dt_10,
                                             );
  my ($agreement, $rule_matches) = $bt->get_agreement_with_invoice($credit_note);
  is($agreement, 14, "points for credit note ok");
  is($rule_matches, 'remote_account_number(3) exact_amount(4) depositor_matches(2) remote_name(2) payment_within_30_days(1) datebonus14(2) ', "rules_matches for credit note ok");

  $::form->{invoice_ids} = {
    $bt->id => [ $credit_note->id ]
  };

  save_btcontroller_to_string();

  $credit_note->load;
  $bt->load;
  is($credit_note->amount   , '-844.90000', "$testname: amount ok");
  is($credit_note->netamount, '-710.00000', "$testname: netamount ok");
  is($credit_note->paid     , '-844.90000', "$testname: paid ok");
  is($bt->invoice_amount    , '-844.90000', "$testname: bt invoice amount for credit note was assigned");
  is($bt->amount            , '-844.90000', "$testname: bt  amount for credit note was assigned");
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
    transdate    => $dt,
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
                                              amount        => abs($invoice->amount),
                                              bank_chart_id => $bank->id,
                                              transdate     => $dt_10,
                                                               );

  my ($agreement, $rule_matches) = $bt->get_agreement_with_invoice($invoice);
  is($agreement, 16, "points for negative ap transaction ok");

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
  is($bt->amount,         '23.80000', "$testname: bt  amount for ap was assigned");

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
    transdate    => $dt,
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
    transdate    => $dt,
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
                                              amount        => abs($invoice_two->amount + $invoice->amount),
                                              bank_chart_id => $bank->id,
                                              transdate     => $dt_10,
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
    transdate    => $dt,
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
                                              transdate     => $dt_10,
                                             );
  $::form->{invoice_ids} = {
    $bt->id => [ $invoice->id ]
  };

  save_btcontroller_to_string();

  $invoice->load;
  $bt->load;

  is($invoice->amount   , '136.85000', "$testname: amount ok");
  is($invoice->netamount, '115.00000', "$testname: netamount ok");
  is($bt->amount,         '-136.85000', "$testname: bt amount ok");
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
    transdate    => $dt,
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
                                              transdate     => $dt_10,
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
                                              transdate     => $dt_10,
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
    transdate     => $dt,
    invoiceitems => [ create_invoice_item(part => $part1, qty =>  3, sellprice => 70),
                      create_invoice_item(part => $part2, qty => 10, sellprice => -50),
                    ]
  );
  my $bt            = create_bank_transaction(record        => $neg_sales_inv,
                                                                amount        => $neg_sales_inv->amount,
                                                                bank_chart_id => $bank->id,
                                                                transdate     => $dt,
                                                                valutadate    => $dt,
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
sub test_fuzzy_skonto_pt {

  my $testname = 'test_fuzzy_skonto_pt';

  $ar_transaction = test_ar_transaction(invnumber => 'salesinv fuzzy skonto',
                                        payment_id => $payment_terms->id,
                                       );
  my $fuzzy_amount_within_threshold = $ar_transaction->amount_less_skonto - 0.57;
  my $bt = create_bank_transaction(record        => $ar_transaction,
                                   bank_chart_id => $bank->id,
                                   transdate     => $dt,
                                   valutadate    => $dt,
                                   amount        => $fuzzy_amount_within_threshold,
                                  ) or die "Couldn't create bank_transaction";

  my ($agreement1, $rule_matches1) = $bt->get_agreement_with_invoice($ar_transaction);
  is($agreement1, 14, "bt1 14 points for ar_transaction_1 in $testname ok");
  is($rule_matches1,
     "remote_account_number(3) skonto_fuzzy_amount(3) depositor_matches(2) remote_name(2) payment_within_30_days(1) datebonus0(3) ",
     "$testname: rule_matches ok");
  my $skonto_type;
  $skonto_type = 'with_fuzzy_skonto_pt' if $rule_matches1 =~ m/skonto_fuzzy_amount/;
  $::form->{invoice_ids} = {
    $bt->id => [ $ar_transaction->id ]
  };
  $::form->{invoice_skontos} = {
    $bt->id => [ $skonto_type ]
  };

  save_btcontroller_to_string();

  $ar_transaction->load;
  $bt->load;
  is($ar_transaction->paid   , '119.00000' , "$testname: salesinv skonto was paid");
  is($ar_transaction->closed , 1           , "$testname: salesinv skonto is closed");
  is($bt->invoice_amount     , '112.48000' , "$testname: bt invoice amount was assigned");

}

sub test_fuzzy_skonto_pt_not_in_range {

  my $testname = 'test_fuzzy_skonto_pt_not_in_range';

  $ar_transaction = test_ar_transaction(invnumber => 'salesinv fuzzy skonto not in range',
                                        payment_id => $payment_terms->id,
                                       );
  my $fuzzy_amount_within_threshold = $ar_transaction->amount_less_skonto - 0.7;
  my $bt = create_bank_transaction(record        => $ar_transaction,
                                   bank_chart_id => $bank->id,
                                   transdate     => $dt,
                                   valutadate    => $dt,
                                   amount        => $fuzzy_amount_within_threshold,
                                  ) or die "Couldn't create bank_transaction";

  my ($agreement1, $rule_matches1) = $bt->get_agreement_with_invoice($ar_transaction);
  is($agreement1, 11, "bt1 14 points for ar_transaction_1 in $testname ok");
  is($rule_matches1,
     "remote_account_number(3) depositor_matches(2) remote_name(2) payment_within_30_days(1) datebonus0(3) ",
     "$testname: rule_matches ok");
  my $skonto_type;
  $skonto_type = 'with_fuzzy_skonto_pt' if $rule_matches1 =~ m/skonto_fuzzy_amount/;
  $::form->{invoice_ids} = {
    $bt->id => [ $ar_transaction->id ]
  };
  $::form->{invoice_skontos} = {
    $bt->id => [ $skonto_type ]
  };

  save_btcontroller_to_string();

  $ar_transaction->load;
  $bt->load;
  is($ar_transaction->paid   , '112.35000' , "$testname: salesinv skonto was not paid");
  is($ar_transaction->closed , ''          , "$testname: salesinv skonto is not closed");
  is($bt->invoice_amount     , '112.35000' , "$testname: bt invoice amount was assigned");

}


sub test_bt_rule1 {

  my $testname = 'test_bt_rule1';

  $ar_transaction = test_ar_transaction(invnumber => 'bt_rule1', transdate => $dt);

  my $bt = create_bank_transaction(record => $ar_transaction, transdate => $dt) or die "Couldn't create bank_transaction";

  $ar_transaction->load;
  $bt->load;
  is($ar_transaction->paid   , '0.00000' , "$testname: not paid");
  is($bt->invoice_amount     , '0.00000' , "$testname: bt invoice amount was not assigned");

  my $bt_controller = SL::Controller::BankTransaction->new;
  my ( $bt_transactions, $proposals ) = $bt_controller->gather_bank_transactions_and_proposals(bank_account => $bank_account);

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

  $ar_transaction = test_ar_transaction(invnumber => 'sepa1', transdate => $dt);

  my $bt  = create_bank_transaction(record => $ar_transaction, transdate => $dt) or die "Couldn't create bank_transaction";
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
  my ( $bt_transactions, $proposals ) = $bt_controller->gather_bank_transactions_and_proposals(bank_account => $bank_account);

  is(scalar(@$bt_transactions)         , 1  , "$testname: one bank_transaction");
  is($bt_transactions->[0]->{agreement}, 25 , "$testname: agreement == 25");
  my $match = join ( ' ',@{$bt_transactions->[0]->{rule_matches}});
  is($match,
     "remote_account_number(3) exact_amount(4) own_invoice_in_purpose(5) depositor_matches(2) remote_name(2) payment_within_30_days(1) datebonus0(3) sepa_export_item(5) ",
     "$testname: rule_matches ok");
};
sub test_sepa_export_endtoend {

  my $testname = 'test_sepa_export_endtoend';

  $ar_transaction = test_ar_transaction(invnumber => 'sepa1', transdate => $dt);

  my $bt  = create_bank_transaction(record => $ar_transaction, transdate => $dt,
                                    end_to_end_id => "KIVITENDO202412101212"     )
    or die "Couldn't create bank_transaction";

  my $se  = create_sepa_export();
  my $sei = create_sepa_export_item(
    chart_id       => $bank->id,
    ar_id          => $ar_transaction->id,
    sepa_export_id => $se->id,
    end_to_end_id  => "KIVITENDO202412101212",
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
  my ( $bt_transactions, $proposals ) = $bt_controller->gather_bank_transactions_and_proposals(bank_account => $bank_account);

  is(scalar(@$bt_transactions)         , 1  , "$testname: one bank_transaction");
  is($bt_transactions->[0]->{agreement}, 33 , "$testname: agreement == 33");
  my $match = join ( ' ',@{$bt_transactions->[0]->{rule_matches}});
  is($match,
     "remote_account_number(3) exact_amount(4) own_invoice_in_purpose(5) depositor_matches(2) remote_name(2) payment_within_30_days(1) datebonus0(3) end_to_end_id(8) sepa_export_item(5) ",
     "$testname: rule_matches ok");
}


sub test_two_banktransactions {

  my $testname = 'two_banktransactions';

  my $ar_transaction_1 = test_ar_transaction(invnumber => 'salesinv10000' , amount => 2912.00 );
  my $bt1 = create_bank_transaction(record        => $ar_transaction_1,
                                    amount        => $ar_transaction_1->amount,
                                    purpose       => "Rechnung10000 beinahe",
                                    transdate     => $dt,
                                    bank_chart_id => $bank->id,
                                  ) or die "Couldn't create bank_transaction";

  my $bt2 = create_bank_transaction(record        => $ar_transaction_1,
                                    amount        => $ar_transaction_1->amount + 0.01,
                                    purpose       => "sicher salesinv20000 vielleicht",
                                    transdate     => $dt,
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
                                    transdate     => $dt,
                                    bank_chart_id => $bank->id,
                                  ) or die "Couldn't create bank_transaction";

  my ($agreement3, $rule_matches3) = $bt3->get_agreement_with_invoice($ar_transaction_3);
  is($agreement3, 19, "bt3 19 points for ar_transaction_3 in $testname ok");

  $bt2->delete;
  $ar_transaction_2->delete;

  #nun sollten zwei gleichwertige Rechnungen $ar_transaction_1 und $ar_transaction_3 für $bt1 gefunden werden
  #aber es darf keine Proposals geben mit mehreren Rechnungen
  my $bt_controller = SL::Controller::BankTransaction->new;
  my ( $bt_transactions, $proposals ) = $bt_controller->gather_bank_transactions_and_proposals(bank_account => $bank_account);

  is(scalar(@$bt_transactions)   , 2  , "$testname: two bank_transaction");
  is(scalar(@$proposals)         , 0  , "$testname: no proposals");

  $ar_transaction_3->delete;

  # Jetzt gibt es zwei Kontobewegungen mit gleichen Punkten für eine Rechnung.
  # hier darf es auch keine Proposals geben

  ( $bt_transactions, $proposals ) = $bt_controller->gather_bank_transactions_and_proposals(bank_account => $bank_account);

  is(scalar(@$bt_transactions)   , 2  , "$testname: two bank_transaction");
  # odyn testfall - anforderungen so (noch) nicht in kivi
  # is(scalar(@$proposals)         , 0  , "$testname: no proposals");

  # Jetzt gibt es zwei Kontobewegungen für eine Rechnung.
  # eine Bewegung bekommt mehr Punkte
  # hier darf es auch keine Proposals geben
  $bt3->update_attributes( purpose => "fuer Rechnung salesinv10000");

  ( $bt_transactions, $proposals ) = $bt_controller->gather_bank_transactions_and_proposals(bank_account => $bank_account);

  is(scalar(@$bt_transactions)   , 2  , "$testname: two bank_transaction");
  # odyn testfall - anforderungen so (noch) nicht in kivi
  # is(scalar(@$proposals)         , 1  , "$testname: one proposal");

};
sub test_closedto {

  my $testname = 'closedto';

  my $ar_transaction_1 = test_ar_transaction(invnumber => 'salesinv10000' , amount => 2912.00 );
  my $bt1 = create_bank_transaction(record        => $ar_transaction_1,
                                    amount        => $ar_transaction_1->amount,
                                    purpose       => "Rechnung10000 beinahe",
                                    bank_chart_id => $bank->id,
                                  ) or die "Couldn't create bank_transaction";

  $bt1->valutadate(DateTime->new(year => 2019, month => 12, day => 30));
  $bt1->save();

  is($bt1->closed_period, 0, "$testname undefined closedto");

  my $defaults = SL::DB::Manager::Default->get_all(limit => 1)->[0];
  $defaults->closedto(DateTime->new(year => 2019, month => 12, day => 31));
  $defaults->save();
  $::instance_conf->reload->data;
  $bt1->load();
  is($bt1->closed_period, 1, "$testname defined and next date closedto");

  $bt1->valutadate(DateTime->new(year => 2020, month => 1, day => 1));
  $bt1->save();
  $bt1->load();

  is($bt1->closed_period, 0, "$testname defined closedto and next date valuta");
  $defaults->closedto(undef);
  $defaults->save();

}

sub test_skonto_exact_ap_transaction {

  my $testname = 'test_skonto_exact_ap_transaction';

  $ap_transaction = test_ap_transaction(invnumber => 'ap transaction skonto',
                                        payment_id => $payment_terms->id,
                                       );

  my $bt = create_bank_transaction(record        => $ap_transaction,
                                   bank_chart_id => $bank->id,
                                   transdate     => $dt,
                                   valutadate    => $dt,
                                   amount        => $ap_transaction->amount_less_skonto
                                  ) or die "Couldn't create bank_transaction";

  $::form->{invoice_ids} = {
    $bt->id => [ $ap_transaction->id ]
  };
  $::form->{invoice_skontos} = {
    $bt->id => [ 'with_skonto_pt' ]
  };

  save_btcontroller_to_string();

  $ap_transaction->load;
  $bt->load;
  is($ap_transaction->paid   , '119.00000' , "$testname: ap transaction skonto was paid");
  is($ap_transaction->closed , 1           , "$testname: ap transaction skonto is closed");
  is($bt->invoice_amount     , '113.05000' , "$testname: bt invoice amount was assigned");

};
sub ap_transaction_fx_gain_fees {

  my $testname     = 'ap_transaction_fx_gain_fees';
  my $usd_amount   = 83300;
  my $fx_rate      = 2;
  my $fx_rate_bank = 1.75;
  my $eur_amount   = $usd_amount * $fx_rate;

  my $ap_transaction_fx = create_ap_fx_transaction (invnumber   => 'ap transaction fx amount',
                                                    payment_id  => $payment_terms->id,
                                                    fx_rate     => $fx_rate,
                                                    netamount   => $eur_amount,
                                                    invoice_set => 1,
                                                    buysell     => 'sell',
                                                   );
  # check exchangerate
  is($ap_transaction_fx->currency->name   , 'USD'     , "$testname: USD currency");
  is($ap_transaction_fx->get_exchangerate , '2.00000' , "$testname: fx rate record");
  my $bt = create_bank_transaction(record        => $ap_transaction_fx,
                                   bank_chart_id => $bank->id,
                                   transdate     => $dt,
                                   valutadate    => $dt,
                                   amount        => 145949.93,
                                   exchangerate  => $fx_rate_bank,
                                  ) or die "Couldn't create bank_transaction";
#          'exchangerates' => [
#                               '1.75'
#                             ],
#          'book_fx_bank_fees' => [
#                                   '1'
#                                 ],
# book_fx_bank_fees   => [  map { $::form->{"book_fx_bank_fees_${bank_transaction_id}_${_}"} } @{ $invoice_ids } ],

  $::form->{invoice_ids} = {
    $bt->id => [ $ap_transaction_fx->id ]
  };
  $::form->{"book_fx_bank_fees_" . $bt->id . "_" . $ap_transaction_fx->id}  = 1;
  $::form->{"exchangerate_"      . $bt->id . "_" . $ap_transaction_fx->id}  = "1,75"; # will be parsed
  $::form->{"currency_id_"       . $bt->id . "_" . $ap_transaction_fx->id}  = $currency_usd->id;


  my $ret = save_btcontroller_to_string();
  $ap_transaction_fx->load;
  $bt->load;
  is(scalar @{ SL::DB::Manager::BankTransactionAccTrans->get_all(where => [bank_transaction_id => $bt->id ] )},
       5, "$testname 5 acc_trans entries created");

  my $gl_fee_booking = SL::DB::Manager::BankTransactionAccTrans->get_all(where => [bank_transaction_id => $bt->id, '!gl_id' => undef ] );
  is(scalar @{ $gl_fee_booking }, 2, 'Two GL acc_trans bookings');

  my $gl = SL::DB::Manager::GLTransaction->get_first(where => [ id => $gl_fee_booking->[0]->gl_id ]);
  is (abs($gl->transactions->[0]->amount), '174.93', 'fee abs amount correct');

  my $fx_gain_transactions = SL::DB::Manager::AccTransaction->get_all(where =>
                                [ trans_id => $ap_transaction_fx->id, chart_id => $fxgain_chart->id ],
                                  sort_by => ('acc_trans_id'));

  is($fx_gain_transactions->[0]->amount,   '20825.00000', "$testname: fx gain amount ok");


  is($ap_transaction_fx->paid   , '166600.00000' , "$testname: ap transaction skonto was paid");
  is($bt->invoice_amount        , '-145949.93000'   , "$testname: bt invoice amount was assigned");

}
sub ap_transaction_fx_gain_fees_two_payments {

  my $testname     = 'ap_transaction_fx_gain_fees_two_payments';
  my $usd_amount   = 11901.19;
  my $fx_rate      = 2;
  my $fx_rate_bank = 1.75;
  my $eur_amount   = $usd_amount * $fx_rate;
  my $ap_transaction_fx = create_ap_fx_transaction (invnumber   => 'ap transaction fx amount',
                                                    payment_id  => $payment_terms->id,
                                                    fx_rate     => $fx_rate,
                                                    netamount   => $eur_amount,
                                                    invoice_set => 0,
                                                    buysell     => 'sell',
                                                   );
  # check exchangerate
  is($ap_transaction_fx->currency->name   , 'USD'     , "$testname: USD currency");
  is($ap_transaction_fx->get_exchangerate , '2.00000' , "$testname: fx rate record");
  is($ap_transaction_fx->amount           , 23802.38  , "$testname: record amount");
  is($ap_transaction_fx->paid             , 0         , "$testname: record amount");
  my $bt = create_bank_transaction(record        => $ap_transaction_fx,
                                   bank_chart_id => $bank->id,
                                   transdate     => $dt,
                                   valutadate    => $dt,
                                   amount        => 18698.25,
                                   exchangerate  => $fx_rate_bank,
                                  ) or die "Couldn't create bank_transaction";

  is($bt->amount        , '-18698.25'   , "$testname: bt amount ok");

  $::form->{invoice_ids} = {
    $bt->id => [ $ap_transaction_fx->id ]
  };
  $::form->{"book_fx_bank_fees_" . $bt->id . "_" . $ap_transaction_fx->id}  = 1;
  $::form->{"exchangerate_"      . $bt->id . "_" . $ap_transaction_fx->id}  = "1,75"; # will be parsed
  $::form->{"currency_id_"       . $bt->id . "_" . $ap_transaction_fx->id}  = $currency_usd->id;


  my $ret = save_btcontroller_to_string();
  $ap_transaction_fx->load;
  $bt->load;
  is($ap_transaction_fx->get_exchangerate , '2.00000' , "$testname: fx rate record");
  is(scalar @{ SL::DB::Manager::BankTransactionAccTrans->get_all(where => [bank_transaction_id => $bt->id ] )},
       3, "$testname 3 acc_trans entries created");

  my $gl_fee_booking = SL::DB::Manager::BankTransactionAccTrans->get_all(where => [bank_transaction_id => $bt->id, '!gl_id' => undef ] );
  is(scalar @{ $gl_fee_booking }, 0, 'Zero GL acc_trans bookings');

  my $fx_gain_transactions = SL::DB::Manager::AccTransaction->get_all(where =>
                                [ trans_id => $ap_transaction_fx->id, chart_id => $fxgain_chart->id ],
                                  sort_by => ('acc_trans_id'));

  is($fx_gain_transactions->[0]->amount,   '2671.18000', "$testname: fx gain amount ok");

  is($ap_transaction_fx->paid, '21369.43000'    , "$testname: ap transaction fx two payment was paid");
  is($bt->invoice_amount     , '-18698.25000'   , "$testname: bt invoice amount was assigned");

  my $bt2 = create_bank_transaction(record        => $ap_transaction_fx,
                                    bank_chart_id => $bank->id,
                                    transdate     => $dt,
                                    valutadate    => $dt,
                                    amount        => 1264.20,
                                    exchangerate  => 0.1,
                                   ) or die "Couldn't create bank_transaction";

  is($bt2->amount        , '-1264.2'   , "$testname: bt amount ok");

  $::form->{invoice_ids} = {
    $bt2->id => [ $ap_transaction_fx->id ]
  };
  $::form->{"book_fx_bank_fees_" . $bt2->id . "_" . $ap_transaction_fx->id}  = 1;
  $::form->{"exchangerate_"      . $bt2->id . "_" . $ap_transaction_fx->id}  = "0,1"; # will be parsed
  $::form->{"currency_id_"       . $bt2->id . "_" . $ap_transaction_fx->id}  = $currency_usd->id;


  $ret = save_btcontroller_to_string();

  $ap_transaction_fx->load;
  $bt2->load;
  is($ap_transaction_fx->get_exchangerate , '2.00000' , "$testname: fx rate record");
  is($ap_transaction_fx->paid             , $ap_transaction_fx->amount , "$testname: paid equals amount");
  is($ap_transaction_fx->get_exchangerate , '2.00000' , "$testname: fx rate record");
  is(scalar @{ SL::DB::Manager::BankTransactionAccTrans->get_all(where => [bank_transaction_id => $bt2->id ] )},
       5, "$testname 5 acc_trans entries created");

  my $gl_fee_booking2 = SL::DB::Manager::BankTransactionAccTrans->get_all(where => [bank_transaction_id => $bt2->id, '!gl_id' => undef ] );
  is(scalar @{ $gl_fee_booking2 }, 2, 'Two GL acc_trans bookings');

  my $gl = SL::DB::Manager::GLTransaction->get_first(where => [ id => $gl_fee_booking2->[0]->gl_id ]);
  is (abs($gl->transactions->[0]->amount), 1142.55, 'fee2 abs amount correct');

  $fx_gain_transactions = SL::DB::Manager::AccTransaction->get_all(where =>
                                [ trans_id => $ap_transaction_fx->id, chart_id => $fxgain_chart->id ],
                                  sort_by => ('acc_trans_id'));

  is($fx_gain_transactions->[0]->amount,   '2671.18000' ,"$testname: fx gain 1 amount ok");
  is($fx_gain_transactions->[1]->amount,   '2311.30000' ,"$testname: fx gain 2 amount ok");


  is($ap_transaction_fx->paid   , $ap_transaction_fx->amount, "$testname: paid equals amount");
  is($bt2->invoice_amount       , '-1264.20000'             , "$testname: bt invoice amount was assigned");

  # unlink bank transaction bt2 and reassign
  $::form->{ids} = [ $bt2->id ];
  my $bt_controller = SL::Controller::BankTransaction->new;
  $bt_controller->action_unlink_bank_transaction('testcase' => 1);

  $bt2->load;
  $ap_transaction_fx->load;

  # and check the cleared state of bt and the acc_transactions
  is($bt2->cleared, '0' , "$testname: bt undo cleared");
  is($bt2->invoice_amount, '0.00000' , "$testname: bt undo invoice amount");

  is(scalar @{ SL::DB::Manager::BankTransactionAccTrans->get_all(where => [bank_transaction_id => $bt2->id ] )},
       0, "$testname 0 acc_trans entries there");

  $gl_fee_booking = SL::DB::Manager::BankTransactionAccTrans->get_all(where => [bank_transaction_id => $bt2->id, '!gl_id' => undef ] );
  is(scalar @{ $gl_fee_booking }, 0, 'Zero GL acc_trans bookings');

  $fx_gain_transactions = SL::DB::Manager::AccTransaction->get_all(where =>
                                [ trans_id => $ap_transaction_fx->id, chart_id => $fxgain_chart->id ],
                                  sort_by => ('acc_trans_id'));

  is($fx_gain_transactions->[0]->amount, '2671.18000' , "$testname: fx gain amount ok");
  is($ap_transaction_fx->paid          , '21369.43000', "$testname: ap transaction fx two payment was paid");


}


sub ap_transaction_fx_loss_fees {

  my $testname     = 'ap_transaction_fx_loss_fees';
  my $usd_amount   = 166600;
  my $fx_rate      = 1.5;
  my $fx_rate_bank = 3;
  my $eur_amount   = $usd_amount * $fx_rate;
  my $ap_transaction_fx = create_ap_fx_transaction (invnumber   => 'ap transaction fx amount',
                                                    payment_id  => $payment_terms->id,
                                                    fx_rate     => $fx_rate,
                                                    netamount   => $eur_amount,
                                                    invoice_set => 1,
                                                    buysell     => 'sell',
                                                   );
  # check exchangerate
  is($ap_transaction_fx->currency->name   , 'USD'     , "$testname: USD currency");
  is($ap_transaction_fx->get_exchangerate , '1.50000' , "$testname: fx rate record");
  my $bt = create_bank_transaction(record        => $ap_transaction_fx,
                                   bank_chart_id => $bank->id,
                                   transdate     => $dt,
                                   valutadate    => $dt,
                                   amount        => 505797.60,
                                   exchangerate  => $fx_rate_bank,
                                  ) or die "Couldn't create bank_transaction";

  $::form->{invoice_ids} = {
    $bt->id => [ $ap_transaction_fx->id ]
  };
  $::form->{"book_fx_bank_fees_" . $bt->id . "_" . $ap_transaction_fx->id}  = 1;
  $::form->{"exchangerate_"      . $bt->id . "_" . $ap_transaction_fx->id}  = "3,00"; # will be parsed
  $::form->{"currency_id_"       . $bt->id . "_" . $ap_transaction_fx->id}  = $currency_usd->id;


  my $ret = save_btcontroller_to_string();
  $ap_transaction_fx->load;
  $bt->load;
  is(scalar @{ SL::DB::Manager::BankTransactionAccTrans->get_all(where => [bank_transaction_id => $bt->id ] )},
       5, "$testname 2 acc_trans entries created");

  my $gl_fee_booking = SL::DB::Manager::BankTransactionAccTrans->get_all(where => [bank_transaction_id => $bt->id, '!gl_id' => undef ] );
  is(scalar @{ $gl_fee_booking }, 2, 'One GL Booking');

  my $gl = SL::DB::Manager::GLTransaction->get_first(where => [ id => $gl_fee_booking->[0]->gl_id ]);
  is (abs($gl->transactions->[0]->amount), '5997.6', 'fee abs amount correct');

  my $fx_loss_transactions = SL::DB::Manager::AccTransaction->get_all(where =>
                                [ trans_id => $ap_transaction_fx->id, chart_id => $fxloss_chart->id ],
                                  sort_by => ('acc_trans_id'));

  is($fx_loss_transactions->[0]->amount,   '-249900.00000', "$testname: fx loss amount ok");


  is($ap_transaction_fx->paid   , $ap_transaction_fx->amount , "$testname: paid equals amount");
  is($ap_transaction_fx->paid   , '249900.00000'             , "$testname: ap transaction was paid");
  is($bt->invoice_amount        , '-505797.60000'            , "$testname: bt invoice amount was assigned");

}
sub negative_ap_transaction_fx_gain_fees_error {

  my $testname     = 'negative_ap_transaction_fx_gain_fees';
  my $usd_amount   = -890.90;
  my $fx_rate      = 0.545;
  my $fx_rate_bank = 0.499;
  my $eur_amount   = $usd_amount * $fx_rate;
  my $ap_transaction_fx = create_ap_fx_transaction (invnumber   => 'ap transaction fx amount',
                                                    payment_id  => $payment_terms->id,
                                                    fx_rate     => $fx_rate,
                                                    netamount   => $eur_amount,
                                                    invoice_set => 0,
                                                    buysell     => 'sell',
                                                   );
  # check exchangerate
  is($ap_transaction_fx->currency->name   , 'USD'       , "$testname: USD currency");
  is($ap_transaction_fx->get_exchangerate , '0.54500'   , "$testname: fx rate record");
  is($ap_transaction_fx->amount           , $eur_amount , "$testname: negative record amount");
  is($ap_transaction_fx->invoice_type     , "purchase_credit_note" , "$testname: negative record amount");

  my $bt = create_bank_transaction(record        => $ap_transaction_fx,
                                   bank_chart_id => $bank->id,
                                   transdate     => $dt,
                                   valutadate    => $dt,
                                   amount        => 4440,
                                   exchangerate  => $fx_rate_bank,
                                  ) or die "Couldn't create bank_transaction";

  is($bt->amount           , '4440' , "$testname: positive bt amount");
  $::form->{invoice_ids} = {
    $bt->id => [ $ap_transaction_fx->id ]
  };
  $::form->{"book_fx_bank_fees_" . $bt->id . "_" . $ap_transaction_fx->id}  = 1;
  $::form->{"exchangerate_"      . $bt->id . "_" . $ap_transaction_fx->id}  = "0,499"; # will be parsed
  $::form->{"currency_id_"       . $bt->id . "_" . $ap_transaction_fx->id}  = $currency_usd->id;


  save_btcontroller_to_string();
  my @bt_errors = @{ $bt_controller->problems };
  is(substr($bt_errors[0]->{message},0,69), 'Bank Fees can only be added for AP transactions or Sales Credit Notes', "$testname: Fehlermeldung ok");
  $bt->load;

  is($bt->invoice_amount        , '0.00000'   , "$testname: bt invoice amount is not yet assigned");

}
sub negative_ap_transaction_fx_gain_fees {

  my $testname     = 'negative_ap_transaction_fx_gain_fees';
  my $usd_amount   = -890.90;
  my $fx_rate      = 0.545;
  my $fx_rate_bank = 0.499;
  my $eur_amount   = $usd_amount * $fx_rate;
  my $ap_transaction_fx = create_ap_fx_transaction (invnumber   => 'ap transaction fx amount',
                                                    payment_id  => $payment_terms->id,
                                                    fx_rate     => $fx_rate,
                                                    netamount   => $eur_amount,
                                                    invoice_set => 0,
                                                    buysell     => 'sell',
                                                   );
  # check exchangerate
  is($ap_transaction_fx->currency->name   , 'USD'       , "$testname: USD currency");
  is($ap_transaction_fx->get_exchangerate , '0.54500'   , "$testname: fx rate record");
  is($ap_transaction_fx->amount           , $eur_amount , "$testname: negative record amount");
  is($ap_transaction_fx->invoice_type     , "purchase_credit_note" , "$testname: negative record amount");

  my $bt = create_bank_transaction(record        => $ap_transaction_fx,
                                   bank_chart_id => $bank->id,
                                   transdate     => $dt,
                                   valutadate    => $dt,
                                   amount        => 4440,
                                   exchangerate  => $fx_rate_bank,
                                  ) or die "Couldn't create bank_transaction";

  is($bt->amount           , '4440' , "$testname: positive bt amount");
  $::form->{invoice_ids} = {
    $bt->id => [ $ap_transaction_fx->id ]
  };
  $::form->{"exchangerate_"      . $bt->id . "_" . $ap_transaction_fx->id}  = "0,499"; # will be parsed
  $::form->{"currency_id_"       . $bt->id . "_" . $ap_transaction_fx->id}  = $currency_usd->id;


  save_btcontroller_to_string();

  $ap_transaction_fx->load;
  $bt->load;

  is(scalar @{ SL::DB::Manager::BankTransactionAccTrans->get_all(where => [bank_transaction_id => $bt->id ] )},
       3, "$testname 5 acc_trans entries created");

  my $gl_fee_booking = SL::DB::Manager::BankTransactionAccTrans->get_all(where => [bank_transaction_id => $bt->id, '!gl_id' => undef ] );
  is(scalar @{ $gl_fee_booking }, 0, 'Zero GL acc_trans bookings');

  my $fx_loss_transactions = SL::DB::Manager::AccTransaction->get_all(where =>
                                [ trans_id => $ap_transaction_fx->id, chart_id => $fxloss_chart->id ],
                                  sort_by => ('acc_trans_id'));

  is($fx_loss_transactions->[0]->amount,   '-40.98000', "$testname: fx loss amount ok");


  is($ap_transaction_fx->paid   , '-485.54000' , "$testname: ap transaction skonto was paid");
  is($bt->invoice_amount        , '444.56000'  , "$testname: bt invoice amount was assigned");

}

sub test_neg_sales_invoice_fx {

  my $testname = 'test_neg_sales_invoice_fx';

  my $part1 = new_part(   partnumber => 'Funkenhaube öhm')->save;
  my $part2 = new_service(partnumber => 'Service-Pauschale Pasch!')->save;

  my $ex = SL::DB::Manager::Exchangerate->find_by(currency_id => $currency_usd->id,
                                                  transdate => $dt)
        ||              SL::DB::Exchangerate->new(currency_id => $currency_usd->id,
                                                  transdate   => $dt);
  $ex->update_attributes(buy => 1.772);

  my $neg_sales_inv = create_sales_invoice(
    invnumber    => '20222201-USD',
    customer     => $customer,
    taxincluded  => 0,
    currency_id  => $currency_usd->id,
    transdate    => $dt,
    invoiceitems => [ create_invoice_item(part => $part1, qty =>  3, sellprice => 70),
                      create_invoice_item(part => $part2, qty => 10, sellprice => -50),
                    ]
  );
  my $bt            = create_bank_transaction(record        => $neg_sales_inv,
                                              amount        => $neg_sales_inv->amount,
                                              bank_chart_id => $bank->id,
                                              transdate     => $dt,
                                              valutadate    => $dt,
                                              exchangerate  => 2.11,
                                             );

  is($neg_sales_inv->amount   , '-611.52000', "$testname: amount ok");
  is($neg_sales_inv->netamount, '-513.88000', "$testname: netamount ok");
  is($neg_sales_inv->currency->name   , 'USD'     , "$testname: USD currency");
  is($neg_sales_inv->get_exchangerate , '1.77200' , "$testname: fx rate record");
  is($bt->exchangerate                , '2.11' , "$testname: bt fx rate record");

  $::form->{invoice_ids} = {
    $bt->id => [ $neg_sales_inv->id ]
  };

  save_btcontroller_to_string();

  $neg_sales_inv->load;
  $bt->load;
  is($neg_sales_inv->paid     , '-611.52000', "$testname: paid ok");
  is($bt->amount              , '-611.52000', "$testname: bt amount ok");
  is($bt->invoice_amount      , '-611.52000', "$testname: bt invoice_amount ok");

  my $fx_loss_transactions = SL::DB::Manager::AccTransaction->get_all(where =>
                                [ trans_id => $neg_sales_inv->id, chart_id => $fxloss_chart->id ],
                                  sort_by => ('acc_trans_id'));

  is($fx_loss_transactions->[0]->amount,   '-116.64000', "$testname: fx loss amount ok");



}
sub test_negative_ar_transaction_fx_loss {
  my (%params) = @_;
  my $netamount = $::form->round_amount($params{amount}, 2) || 100 * 1.772 * -1;
  my $amount    = $::form->round_amount($netamount * 1.19,2);
  # set exchangerate
  my $ex = SL::DB::Manager::Exchangerate->find_by(currency_id => $currency_usd->id,
                                                  transdate => $dt)
        ||              SL::DB::Exchangerate->new(currency_id => $currency_usd->id,
                                                  transdate   => $dt);
  $ex->update_attributes(buy => 1.772);

  my $testname = 'test_negative_ar_transaction_fx_gain';

  my $invoice   = SL::DB::Invoice->new(
      invoice      => 0,
      invnumber    => $params{invnumber} || undef, # let it use its own invnumber
      amount       => $amount,
      netamount    => $netamount,
      transdate    => $dt,
      taxincluded  => $params{taxincluded } || 0,
      customer_id  => $customer->id,
      taxzone_id   => $customer->taxzone_id,
      currency_id  => $currency_usd->id,
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

  is($invoice->currency_id , $currency_usd->id , 'currency_id has been saved');
  is($invoice->netamount   , '-177.2'          , 'fx ar amount has been converted');
  is($invoice->amount      , '-210.87'         , 'fx ar amount has been converted');
  is($invoice->taxincluded , 0                 , 'fx ar transaction doesn\'t have taxincluded');

  my $bt = create_bank_transaction(record        => $invoice,
                                   bank_chart_id => $bank->id,
                                   transdate     => $dt,
                                   valutadate    => $dt,
                                   amount        => (119 + 178.38) * -1,
                                   exchangerate  => 2.499,
                                  ) or die "Couldn't create bank_transaction";

  is($bt->amount           , '-297.38' , "$testname: negative bt amount");
  $::form->{invoice_ids} = {
    $bt->id => [ $invoice->id ]
  };
  $::form->{"exchangerate_"      . $bt->id . "_" . $invoice->id}  = "2,499"; # will be parsed
  $::form->{"currency_id_"       . $bt->id . "_" . $invoice->id}  = $currency_usd->id;


  save_btcontroller_to_string();

  $invoice->load;
  $bt->load;

  is(scalar @{ SL::DB::Manager::BankTransactionAccTrans->get_all(where => [bank_transaction_id => $bt->id ] )},
       3, "$testname 3 acc_trans entries created");

  my $gl_fee_booking = SL::DB::Manager::BankTransactionAccTrans->get_all(where => [bank_transaction_id => $bt->id, '!gl_id' => undef ] );
  is(scalar @{ $gl_fee_booking }, 0, 'Zero GL acc_trans bookings');

  my $fx_loss_transactions = SL::DB::Manager::AccTransaction->get_all(where =>
                                [ trans_id => $invoice->id, chart_id => $fxloss_chart->id ],
                                  sort_by => ('acc_trans_id'));

  is($fx_loss_transactions->[0]->amount,   '-86.51000', "$testname: fx gain amount ok");


  is($invoice->paid       , '-210.87000' , "$testname: ar transaction was paid");
  is($bt->invoice_amount  , '-297.38000' , "$testname: bt invoice amount was assigned");
}

sub test_ar_transaction_fx_partial_payment {
  my (%params) = @_;
  my $netamount = $::form->round_amount($params{amount}, 2) || 3674580*0.08613;
  # set exchangerate
  my $ex = SL::DB::Manager::Exchangerate->find_by(currency_id => $currency_usd->id,
                                                  transdate => $dt)
        ||              SL::DB::Exchangerate->new(currency_id => $currency_usd->id,
                                                  transdate   => $dt);
  $ex->update_attributes(buy => 0.08613);

  my $testname = 'test_ar_transaction_fx_partial_payment';

  my $invoice   = SL::DB::Invoice->new(
      invoice      => 0,
      invnumber    => $params{invnumber} || undef, # let it use its own invnumber
      amount       => $netamount,
      netamount    => $netamount,
      transdate    => $dt,
      taxincluded  => $params{taxincluded } || 0,
      customer_id  => $customer->id,
      taxzone_id   => $customer->taxzone_id,
      currency_id  => $currency_usd->id,
      transactions => [],
      payment_id   => $params{payment_id} || undef,
      notes        => 'test_ar_transaction_fx_partial_payment',
  );
  my $acno_8100 = SL::DB::Manager::Chart->find_by( accno => '8100' );
  $invoice->add_ar_amount_row(
    amount => $invoice->netamount,
    chart  => $acno_8100, # Erlöse steuerfrei
    tax_id => 0,
  );
  $invoice->create_ar_row(chart => $ar_chart);
  $invoice->save;

  is($invoice->currency_id , $currency_usd->id , 'currency_id has been saved');
  is($invoice->netamount   , '316491.5754'           , 'fx ar amount has been converted');
  is($invoice->taxincluded , 0                 , 'fx ar transaction doesn\'t have taxincluded');

  my $bt = create_bank_transaction(record        => $invoice,
                                   bank_chart_id => $bank->id,
                                   transdate     => $dt,
                                   valutadate    => $dt,
                                   amount        => 315636.49,
                                  ) or die "Couldn't create bank_transaction";

  is($bt->amount           , '315636.49' , "$testname: positive bt amount");
  $::form->{invoice_ids} = {
    $bt->id => [ $invoice->id ]
  };
  $::form->{"exchangerate_"      . $bt->id . "_" . $invoice->id}  = "0,08726"; # will be parsed
  $::form->{"currency_id_"       . $bt->id . "_" . $invoice->id}  = $currency_usd->id;


  save_btcontroller_to_string();

  $invoice->load;
  $bt->load;

  is(scalar @{ SL::DB::Manager::BankTransactionAccTrans->get_all(where => [bank_transaction_id => $bt->id ] )},
       3, "$testname 3 acc_trans entries created");

  my $gl_fee_booking = SL::DB::Manager::BankTransactionAccTrans->get_all(where => [bank_transaction_id => $bt->id, '!gl_id' => undef ] );
  is(scalar @{ $gl_fee_booking }, 0, 'Zero GL acc_trans bookings');

  my $fx_gain_transactions = SL::DB::Manager::AccTransaction->get_all(where =>
                                [ trans_id => $invoice->id, chart_id => $fxgain_chart->id ],
                                  sort_by => ('acc_trans_id'));

  is($fx_gain_transactions->[0]->amount,  '4087.43000', "$testname: fx gain amount ok");


  is($invoice->paid       , '311549.06000' , "$testname: ar transaction was paid partially");
  is($bt->invoice_amount  , '315636.49000' , "$testname: bt invoice amount was assigned");
}

sub test_ar_transaction_fx_gain {
  my (%params) = @_;
  my $netamount = $::form->round_amount($params{amount}, 2) || 100 * 1.772;
  my $amount    = $::form->round_amount($netamount * 1.19,2);
  # set exchangerate
  my $ex = SL::DB::Manager::Exchangerate->find_by(currency_id => $currency_usd->id,
                                                  transdate => $dt)
        ||              SL::DB::Exchangerate->new(currency_id => $currency_usd->id,
                                                  transdate   => $dt);
  $ex->update_attributes(buy => 1.772);

  my $testname = 'test_ar_transaction';

  my $invoice   = SL::DB::Invoice->new(
      invoice      => 0,
      invnumber    => $params{invnumber} || undef, # let it use its own invnumber
      amount       => $amount,
      netamount    => $netamount,
      transdate    => $dt,
      taxincluded  => $params{taxincluded } || 0,
      customer_id  => $customer->id,
      taxzone_id   => $customer->taxzone_id,
      currency_id  => $currency_usd->id,
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

  is($invoice->currency_id , $currency_usd->id , 'currency_id has been saved');
  is($invoice->netamount   , '177.2'           , 'fx ar amount has been converted');
  is($invoice->amount      , '210.87'          , 'fx ar amount has been converted');
  is($invoice->taxincluded , 0                 , 'fx ar transaction doesn\'t have taxincluded');

  my $bt = create_bank_transaction(record        => $invoice,
                                   bank_chart_id => $bank->id,
                                   transdate     => $dt,
                                   valutadate    => $dt,
                                   amount        => 119 + 178.38,
                                   exchangerate  => 2.499,
                                  ) or die "Couldn't create bank_transaction";

  is($bt->amount           , '297.38' , "$testname: positive bt amount");
  $::form->{invoice_ids} = {
    $bt->id => [ $invoice->id ]
  };
  $::form->{"exchangerate_"      . $bt->id . "_" . $invoice->id}  = "2,499"; # will be parsed
  $::form->{"currency_id_"       . $bt->id . "_" . $invoice->id}  = $currency_usd->id;


  save_btcontroller_to_string();

  $invoice->load;
  $bt->load;

  is(scalar @{ SL::DB::Manager::BankTransactionAccTrans->get_all(where => [bank_transaction_id => $bt->id ] )},
       3, "$testname 3 acc_trans entries created");

  my $gl_fee_booking = SL::DB::Manager::BankTransactionAccTrans->get_all(where => [bank_transaction_id => $bt->id, '!gl_id' => undef ] );
  is(scalar @{ $gl_fee_booking }, 0, 'Zero GL acc_trans bookings');

  my $fx_gain_transactions = SL::DB::Manager::AccTransaction->get_all(where =>
                                [ trans_id => $invoice->id, chart_id => $fxgain_chart->id ],
                                  sort_by => ('acc_trans_id'));

  is($fx_gain_transactions->[0]->amount,   '86.51000', "$testname: fx gain amount ok");


  is($invoice->paid       , '210.87000' , "$testname: ar transaction was paid");
  is($bt->invoice_amount  , '297.38000' , "$testname: bt invoice amount was assigned");
}

sub test_ar_transaction_fx_loss {
  my (%params) = @_;
  my $netamount = $::form->round_amount($params{amount}, 2) || 100 * 1.772;
  my $amount    = $::form->round_amount($netamount * 1.19,2);
  # set exchangerate
  my $ex = SL::DB::Manager::Exchangerate->find_by(currency_id => $currency_usd->id,
                                                  transdate => $dt)
        ||              SL::DB::Exchangerate->new(currency_id => $currency_usd->id,
                                                  transdate   => $dt);
  $ex->update_attributes(buy => 1.772);

  my $testname = 'test_ar_transaction';

  my $invoice   = SL::DB::Invoice->new(
      invoice      => 0,
      invnumber    => $params{invnumber} || undef, # let it use its own invnumber
      amount       => $amount,
      netamount    => $netamount,
      transdate    => $dt,
      taxincluded  => $params{taxincluded } || 0,
      customer_id  => $customer->id,
      taxzone_id   => $customer->taxzone_id,
      currency_id  => $currency_usd->id,
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

  is($invoice->currency_id , $currency_usd->id , 'currency_id has been saved');
  is($invoice->netamount   , '177.2'           , 'fx ar amount has been converted');
  is($invoice->amount      , '210.87'          , 'fx ar amount has been converted');
  is($invoice->taxincluded , 0                 , 'fx ar transaction doesn\'t have taxincluded');

  my $bt = create_bank_transaction(record        => $invoice,
                                   bank_chart_id => $bank->id,
                                   transdate     => $dt,
                                   valutadate    => $dt,
                                   amount        => 210.87,
                                   exchangerate  => 1.499,
                                  ) or die "Couldn't create bank_transaction";

  is($bt->amount           , '210.87' , "$testname: positive bt amount");
  $::form->{invoice_ids} = {
    $bt->id => [ $invoice->id ]
  };
  $::form->{"exchangerate_"      . $bt->id . "_" . $invoice->id}  = "1,499"; # will be parsed
  $::form->{"currency_id_"       . $bt->id . "_" . $invoice->id}  = $currency_usd->id;


  save_btcontroller_to_string();

  $invoice->load;
  $bt->load;

  is(scalar @{ SL::DB::Manager::BankTransactionAccTrans->get_all(where => [bank_transaction_id => $bt->id ] )},
       3, "$testname 3 acc_trans entries created");

  my $gl_fee_booking = SL::DB::Manager::BankTransactionAccTrans->get_all(where => [bank_transaction_id => $bt->id, '!gl_id' => undef ] );
  is(scalar @{ $gl_fee_booking }, 0, 'Zero GL acc_trans bookings');

  my $fx_loss_transactions = SL::DB::Manager::AccTransaction->get_all(where =>
                                [ trans_id => $invoice->id, chart_id => $fxloss_chart->id ],
                                  sort_by => ('acc_trans_id'));

  is($fx_loss_transactions->[0]->amount,   '-32.49000', "$testname: fx loss amount ok");


  is($invoice->paid       , '210.87000' , "$testname: ar transaction was paid");
  is($bt->invoice_amount  , '178.38000' , "$testname: bt invoice amount was assigned");
}

sub create_ap_fx_transaction {
  my (%params) = @_;

  my $netamount     = $params{netamount};
  my $amount        = $params{netamount};
  my $invoice_set   = $params{invoice};
  my $fx_rate       = $params{fx_rate};
  my $buysell       = $params{buysell};

  my $ex = SL::DB::Manager::Exchangerate->find_by(currency_id => $currency_usd->id,
                                                  transdate => $dt)
        ||              SL::DB::Exchangerate->new(currency_id => $currency_usd->id,
                                                  transdate   => $dt);
  $ex->update_attributes($buysell => $fx_rate);

  my $invoice   = SL::DB::PurchaseInvoice->new(
    invoice      => $invoice_set,
    invnumber    => $params{invnumber} || '27ab',
    amount       => $amount,
    netamount    => $netamount,
    transdate    => $dt,
    taxincluded  => 0,
    vendor_id    => $vendor->id,
    taxzone_id   => $vendor->taxzone_id,
    currency_id  => $currency_usd->id,
    transactions => [],
    notes        => 'ap_transaction_fx',
  );
  $invoice->add_ap_amount_row(
    amount     => $netamount,
    chart      => $ap_amount_chart,
    tax_id     => 0,
  );

  $invoice->create_ap_row(chart => $ap_chart);
  $invoice->save;
  return $invoice;
}

1;
