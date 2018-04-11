use strict;
use Test::More tests => 197;

use strict;

use lib 't';
use utf8;

use Carp;
use Support::TestSetup;
use Test::Exception;
use List::Util qw(sum);

use SL::Dev::Record qw(create_invoice_item create_sales_invoice create_credit_note);
use SL::Dev::CustomerVendor qw(new_customer new_vendor);
use SL::Dev::Part qw(new_part);
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
use SL::DBUtils qw(selectfirst_array_query);
use Data::Dumper;

my ($customer, $vendor, $currency_id, @parts, $buchungsgruppe, $buchungsgruppe7, $unit, $employee, $tax, $tax7, $tax_9, $taxzone, $payment_terms, $bank_account);
my ($transdate1, $transdate2, $transdate3, $transdate4, $currency, $exchangerate, $exchangerate2, $exchangerate3, $exchangerate4);
my ($ar_chart,$bank,$ar_amount_chart, $ap_chart, $ap_amount_chart, $fxloss_chart, $fxgain_chart);

my $purchase_invoice_counter = 0; # used for generating purchase invnumber

Support::TestSetup::login();

init_state();

# test cases: without_skonto
test_default_invoice_one_item_19_without_skonto();
test_default_invoice_two_items_19_7_tax_with_skonto();
test_default_invoice_two_items_19_7_without_skonto();
test_default_invoice_two_items_19_7_without_skonto_incomplete_payment();
test_default_invoice_two_items_19_7_tax_without_skonto_multiple_payments();
test_default_purchase_invoice_two_charts_19_7_without_skonto();
test_default_purchase_invoice_two_charts_19_7_tax_partial_unrounded_payment_without_skonto();
test_default_invoice_one_item_19_without_skonto_overpaid();
test_credit_note_two_items_19_7_tax_tax_not_included();

# test cases: difference_as_skonto
test_default_invoice_two_items_19_7_tax_without_skonto_multiple_payments_final_difference_as_skonto();
test_default_invoice_two_items_19_7_tax_without_skonto_multiple_payments_final_difference_as_skonto_1cent();
test_default_invoice_two_items_19_7_tax_without_skonto_multiple_payments_final_difference_as_skonto_2cent();
test_default_invoice_one_item_19_multiple_payment_final_difference_as_skonto();
test_default_invoice_one_item_19_multiple_payment_final_difference_as_skonto_1cent();
test_default_purchase_invoice_two_charts_19_7_tax_without_skonto_multiple_payments_final_difference_as_skonto();

# test cases: with_skonto_pt
test_default_invoice_two_items_19_7_tax_with_skonto_50_50();
test_default_invoice_four_items_19_7_tax_with_skonto_4x_25();
test_default_invoice_four_items_19_7_tax_with_skonto_4x_25_multiple();
test_default_purchase_invoice_two_charts_19_7_with_skonto();
test_default_invoice_four_items_19_7_tax_with_skonto_4x_25_tax_included();
test_default_invoice_two_items_19_7_tax_with_skonto_tax_included();

# test payment of ar and ap transactions with currency and tax included/not included
# exchangerate = 1.33333
test_ar_currency_tax_not_included_and_payment();
test_ar_currency_tax_included();
test_ap_currency_tax_not_included_and_payment();
test_ap_currency_tax_included();

test_ar_currency_tax_not_included_and_payment_2();              # exchangerate 0.8
test_ar_currency_tax_not_included_and_payment_2_credit_note();  # exchangerate 0.8

test_ap_currency_tax_not_included_and_payment_2();             # two exchangerates, with fx_gain_loss
test_ap_currency_tax_not_included_and_payment_2_credit_note(); # two exchangerates, with fx_gain_loss

is(SL::DB::Manager::Invoice->get_all_count(), 21,  "number of invoices at end of tests ok");
TODO: {
  local $TODO = "currently this test fails because the code writing the invoice is buggy, the calculation of skonto is correct";
  my ($acc_trans_sum)  = selectfirst_array_query($::form, $currency->db->dbh, 'SELECT SUM(amount) FROM acc_trans');
  is($acc_trans_sum, '0.00000', "sum of all acc_trans at end of all tests is 0");
}

# remove all created data at end of test
clear_up();

done_testing();


sub clear_up {
  SL::DB::Manager::InvoiceItem->delete_all(all => 1);
  SL::DB::Manager::Invoice->delete_all(all => 1);
  SL::DB::Manager::PurchaseInvoice->delete_all(all => 1);
  SL::DB::Manager::Part->delete_all(all => 1);
  SL::DB::Manager::Customer->delete_all(all => 1);
  SL::DB::Manager::Vendor->delete_all(all => 1);
  SL::DB::Manager::BankAccount->delete_all(all => 1);
  SL::DB::Manager::PaymentTerm->delete_all(all => 1);
  SL::DB::Manager::Exchangerate->delete_all(all => 1);
  SL::DB::Manager::Currency->delete_all(where => [ name => 'CUR' ]);
};

sub init_state {
  my %params = @_;

  clear_up();

  $transdate1 = DateTime->today;
  $transdate2 = DateTime->today->add(days => 1);
  $transdate3 = DateTime->today->add(days => 2);
  $transdate4 = DateTime->today->add(days => 3);

  $buchungsgruppe  = SL::DB::Manager::Buchungsgruppe->find_by(description => 'Standard 19%') || croak "No accounting group";
  $buchungsgruppe7 = SL::DB::Manager::Buchungsgruppe->find_by(description => 'Standard 7%')  || croak "No accounting group for 7\%";
  $unit            = SL::DB::Manager::Unit->find_by(name => 'kg')                            || croak "No unit";
  $employee        = SL::DB::Manager::Employee->current                                      || croak "No employee";
  $tax             = SL::DB::Manager::Tax->find_by(taxkey => 3, rate => 0.19)                || croak "No tax";
  $tax7            = SL::DB::Manager::Tax->find_by(taxkey => 2, rate => 0.07)                || croak "No tax for 7\%";
  $taxzone         = SL::DB::Manager::TaxZone->find_by( description => 'Inland')             || croak "No taxzone";
  $tax_9           = SL::DB::Manager::Tax->find_by(taxkey => 9, rate => 0.19)                || croak "No tax";
  # $tax7            = SL::DB::Manager::Tax->find_by(taxkey => 2, rate => 0.07)                || croak "No tax for 7\%";

  $currency_id     = $::instance_conf->get_currency_id;

  $currency = SL::DB::Currency->new(name => 'CUR')->save;

  $fxgain_chart = SL::DB::Manager::Chart->find_by(accno => '2660') or die "Can't find fxgain_chart in test";
  $fxloss_chart = SL::DB::Manager::Chart->find_by(accno => '2150') or die "Can't find fxloss_chart in test";

  $currency->db->dbh->do('UPDATE defaults SET fxgain_accno_id = ' . $fxgain_chart->id);
  $currency->db->dbh->do('UPDATE defaults SET fxloss_accno_id = ' . $fxloss_chart->id);
  $::instance_conf->reload->data;
  is($fxgain_chart->id,  $::instance_conf->get_fxgain_accno_id, "fxgain_chart was updated in defaults");
  is($fxloss_chart->id,  $::instance_conf->get_fxloss_accno_id, "fxloss_chart was updated in defaults");

  $exchangerate  = SL::DB::Exchangerate->new(transdate   => $transdate1,
                                             buy         => '1.33333',
                                             sell        => '1.33333',
                                             currency_id => $currency->id,
                                            )->save;
  $exchangerate2 = SL::DB::Exchangerate->new(transdate   => $transdate2,
                                             buy         => '0.8',
                                             sell        => '0.8',
                                             currency_id => $currency->id,
                                            )->save;
  $exchangerate3 = SL::DB::Exchangerate->new(transdate   => $transdate3,
                                             buy         => '1.55557',
                                             sell        => '1.55557',
                                             currency_id => $currency->id,
                                            )->save;
  $exchangerate4 = SL::DB::Exchangerate->new(transdate   => $transdate4,
                                             buy         => '0.77777',
                                             sell        => '0.77777',
                                             currency_id => $currency->id,
                                            )->save;

  $customer     = new_customer(
    name        => 'Test Customer',
    currency_id => $currency_id,
    taxzone_id  => $taxzone->id,
  )->save;

  $bank_account     =  SL::DB::BankAccount->new(
    account_number  => '123',
    bank_code       => '123',
    iban            => '123',
    bic             => '123',
    bank            => '123',
    chart_id        => SL::DB::Manager::Chart->find_by( description => 'Bank' )->id,
    name            => SL::DB::Manager::Chart->find_by( description => 'Bank' )->description,
  )->save;

  $payment_terms     =  SL::DB::PaymentTerm->new(
    description      => 'payment',
    description_long => 'payment',
    terms_netto      => '30',
    terms_skonto     => '5',
    percent_skonto   => '0.05',
    auto_calculation => 1,
  )->save;

  $vendor       = new_vendor(
    name        => 'Test Vendor',
    currency_id => $currency_id,
    taxzone_id  => $taxzone->id,
    payment_id  => $payment_terms->id,
  )->save;


  @parts = ();
  push @parts, new_part(
    partnumber         => 'T4254',
    description        => 'Fourty-two fifty-four',
    lastcost           => 1.93,
    sellprice          => 2.34,
    buchungsgruppen_id => $buchungsgruppe->id,
    unit               => $unit->name,
    %{ $params{part1} }
  )->save;

  push @parts, new_part(
    partnumber         => 'T0815',
    description        => 'Zero EIGHT fifteeN @ 7%',
    lastcost           => 5.473,
    sellprice          => 9.714,
    buchungsgruppen_id => $buchungsgruppe7->id,
    unit               => $unit->name,
    %{ $params{part2} }
  )->save;
  push @parts, new_part(
    partnumber         => '19%',
    description        => 'Testware 19%',
    lastcost           => 0,
    sellprice          => 50,
    buchungsgruppen_id => $buchungsgruppe->id,
    unit               => $unit->name,
    %{ $params{part3} }
  )->save;
  push @parts, new_part(
    partnumber         => '7%',
    description        => 'Testware 7%',
    lastcost           => 0,
    sellprice          => 50,
    buchungsgruppen_id => $buchungsgruppe7->id,
    unit               => $unit->name,
    %{ $params{part4} }
  )->save;

  $ar_chart        = SL::DB::Manager::Chart->find_by( accno => '1400' ); # Forderungen
  $ap_chart        = SL::DB::Manager::Chart->find_by( accno => '1600' ); # Verbindlichkeiten
  $bank            = SL::DB::Manager::Chart->find_by( accno => '1200' ); # Bank
  $ar_amount_chart = SL::DB::Manager::Chart->find_by( accno => '8400' ); # Erlöse
  $ap_amount_chart = SL::DB::Manager::Chart->find_by( accno => '3400' ); # Wareneingang 19%
}

sub new_purchase_invoice {
  # my %params  = @_;
  # manually create a Kreditorenbuchung from scratch, ap + acc_trans bookings, as no helper exists yet, like $invoice->post.
  # arap-Booking must come last in the acc_trans order
  $purchase_invoice_counter++;

  my $purchase_invoice = SL::DB::PurchaseInvoice->new(
    vendor_id   => $vendor->id,
    invnumber   => 'newap ' . $purchase_invoice_counter ,
    currency_id => $currency_id,
    employee_id => $employee->id,
    gldate      => $transdate1,
    taxzone_id  => $taxzone->id,
    transdate   => $transdate1,
    invoice     => 0,
    type        => 'invoice',
    taxincluded => 0,
    amount      => '226',
    netamount   => '200',
    paid        => '0',
    # %params,
  )->save;

  my $expense_chart  = SL::DB::Manager::Chart->find_by(accno => '3400');
  my $expense_chart_booking= SL::DB::AccTransaction->new(
                                        trans_id   => $purchase_invoice->id,
                                        chart_id   => $expense_chart->id,
                                        chart_link => $expense_chart->link,
                                        amount     => '-100',
                                        transdate  => $transdate1,
                                        source     => '',
                                        taxkey     => 9,
                                        tax_id     => SL::DB::Manager::Tax->find_by(taxkey => 9)->id);
  $expense_chart_booking->save;

  my $tax_chart  = SL::DB::Manager::Chart->find_by(accno => '1576');
  my $tax_chart_booking= SL::DB::AccTransaction->new(
                                        trans_id   => $purchase_invoice->id,
                                        chart_id   => $tax_chart->id,
                                        chart_link => $tax_chart->link,
                                        amount     => '-19',
                                        transdate  => $transdate1,
                                        source     => '',
                                        taxkey     => 0,
                                        tax_id     => SL::DB::Manager::Tax->find_by(taxkey => 9)->id);
  $tax_chart_booking->save;
  $expense_chart  = SL::DB::Manager::Chart->find_by(accno => '3300');
  $expense_chart_booking= SL::DB::AccTransaction->new(
                                        trans_id   => $purchase_invoice->id,
                                        chart_id   => $expense_chart->id,
                                        chart_link => $expense_chart->link,
                                        amount     => '-100',
                                        transdate  => $transdate1,
                                        source     => '',
                                        taxkey     => 8,
                                        tax_id     => SL::DB::Manager::Tax->find_by(taxkey => 8)->id);
  $expense_chart_booking->save;


  $tax_chart  = SL::DB::Manager::Chart->find_by(accno => '1571');
  $tax_chart_booking= SL::DB::AccTransaction->new(
                                         trans_id   => $purchase_invoice->id,
                                         chart_id   => $tax_chart->id,
                                         chart_link => $tax_chart->link,
                                         amount     => '-7',
                                         transdate  => $transdate1,
                                         source     => '',
                                         taxkey     => 0,
                                         tax_id     => SL::DB::Manager::Tax->find_by(taxkey => 8)->id);
  $tax_chart_booking->save;
  my $arap_chart  = SL::DB::Manager::Chart->find_by(accno => '1600');
  my $arap_booking= SL::DB::AccTransaction->new(trans_id   => $purchase_invoice->id,
                                                chart_id   => $arap_chart->id,
                                                chart_link => $arap_chart->link,
                                                amount     => '226',
                                                transdate  => $transdate1,
                                                source     => '',
                                                taxkey     => 0,
                                                tax_id     => SL::DB::Manager::Tax->find_by(taxkey => 0)->id);
  $arap_booking->save;

  return $purchase_invoice;
}

sub number_of_payments {
  my $invoice = shift;

  my $number_of_payments;
  my $paid_amount;
  foreach my $transaction ( @{ $invoice->transactions } ) {
    if ( $transaction->chart_link =~ /(AR_paid|AP_paid)/ ) {
      $paid_amount += $transaction->amount ;
      $number_of_payments++;
    };
  };
  return ($number_of_payments, $paid_amount);
};

sub total_amount {
  my $invoice = shift;

  my $total = sum map { $_->amount } @{ $invoice->transactions };

  return $::form->round_amount($total, 5);

};


# test 1
sub test_default_invoice_one_item_19_without_skonto() {
  my $title = 'default invoice, one item, 19% tax, without_skonto';
  my $item    = create_invoice_item(part => $parts[0], qty => 2.5);
  my $invoice = create_sales_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item ],
    payment_id   => $payment_terms->id,
  );

  my $purchase_invoice = new_purchase_invoice();

  # default values
  my %params = ( chart_id => $bank_account->chart_id,
                 transdate => DateTime->today_local->to_kivitendo
               );

  $params{amount} = '6.96';
  $params{payment_type} = 'without_skonto';

  $invoice->pay_invoice( %params );

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice);
  my $total = total_amount($invoice);

  is($invoice->netamount,   5.85,      "${title}: netamount");
  is($invoice->amount,      6.96,      "${title}: amount");
  is($paid_amount,         -6.96,      "${title}: paid amount");
  is($number_of_payments,      1,      "${title}: 1 AR_paid booking");
  is($invoice->paid,        6.96,      "${title}: paid");
  is($total,                   0,      "${title}: even balance");

}

sub test_default_invoice_one_item_19_without_skonto_overpaid() {
  my $title = 'default invoice, one item, 19% tax, without_skonto';

  my $item    = create_invoice_item(part => $parts[0], qty => 2.5);
  my $invoice = create_sales_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item ],
    payment_id   => $payment_terms->id,
  );

  my $purchase_invoice = new_purchase_invoice();


  # default values
  my %params = ( chart_id => $bank_account->chart_id,
                 transdate => DateTime->today_local->to_kivitendo
               );

  $params{amount} = '16.96';
  $params{payment_type} = 'without_skonto';
  $invoice->pay_invoice( %params );

  $params{amount} = '-10.00';
  $invoice->pay_invoice( %params );

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice);
  my $total = total_amount($invoice);

  is($invoice->netamount,   5.85,      "${title}: netamount");
  is($invoice->amount,      6.96,      "${title}: amount");
  is($paid_amount,         -6.96,      "${title}: paid amount");
  is($number_of_payments,      2,      "${title}: 1 AR_paid booking");
  is($invoice->paid,        6.96,      "${title}: paid");
  is($total,                   0,      "${title}: even balance");

}


# test 2
sub test_default_invoice_two_items_19_7_tax_with_skonto() {
  my $title = 'default invoice, two items, 19/7% tax with_skonto_pt';

  my $item1   = create_invoice_item(part => $parts[0], qty => 2.5);
  my $item2   = create_invoice_item(part => $parts[1], qty => 1.2);
  my $invoice = create_sales_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item1, $item2 ],
    payment_id   => $payment_terms->id,
  );

  # default values
  my %params = ( chart_id => $bank_account->chart_id,
                 transdate => DateTime->today_local->to_kivitendo
               );

  $params{payment_type} = 'with_skonto_pt';
  $params{amount}       = $invoice->amount_less_skonto;

  $invoice->pay_invoice( %params );

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice);
  my $total = total_amount($invoice);

  is($invoice->netamount,  5.85 + 11.66,   "${title}: netamount");
  is($invoice->amount,     6.96 + 12.48,   "${title}: amount");
  is($paid_amount,               -19.44,   "${title}: paid amount");
  is($invoice->paid,              19.44,   "${title}: paid");
  is($number_of_payments,             3,   "${title}: 3 AR_paid bookings");
  is($total,                          0,   "${title}: even balance");
}

sub test_default_invoice_two_items_19_7_tax_with_skonto_tax_included() {
  my $title = 'default invoice, two items, 19/7% tax with_skonto_pt';

  my $item1   = create_invoice_item(part => $parts[0], qty => 2.5);
  my $item2   = create_invoice_item(part => $parts[1], qty => 1.2);
  my $invoice = create_sales_invoice(
    taxincluded  => 1,
    invoiceitems => [ $item1, $item2 ],
    payment_id   => $payment_terms->id,
  );

  # default values
  my %params = ( chart_id => $bank_account->chart_id,
                 transdate => DateTime->today_local->to_kivitendo
               );

  $params{payment_type} = 'with_skonto_pt';
  $params{amount}       = $invoice->amount_less_skonto;

  $invoice->pay_invoice( %params );

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice);
  my $total = total_amount($invoice);

  is($invoice->netamount,         15.82,   "${title}: netamount");
  is($invoice->amount,            17.51,   "${title}: amount");
  is($paid_amount,               -17.51,   "${title}: paid amount");
  is($invoice->paid,              17.51,   "${title}: paid");
  is($number_of_payments,             3,   "${title}: 3 AR_paid bookings");

TODO: {
  local $TODO = "currently this test fails because the code writing the invoice is buggy, the calculation of skonto is correct";
  is($total,                          0,   "${title}: even balance");
  }
}

# test 3 : two items, without skonto
sub test_default_invoice_two_items_19_7_without_skonto() {
  my $title = 'default invoice, two items, 19/7% tax without skonto';

  my $item1   = create_invoice_item(part => $parts[0], qty => 2.5);
  my $item2   = create_invoice_item(part => $parts[1], qty => 1.2);
  my $invoice = create_sales_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item1, $item2 ],
    payment_id   => $payment_terms->id,
  );

  # default values
  my %params = ( chart_id => $bank_account->chart_id,
                 transdate => DateTime->today_local->to_kivitendo
               );

  $params{amount} = '19.44'; # pass full amount
  $params{payment_type} = 'without_skonto';

  $invoice->pay_invoice( %params );

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice);
  my $total = total_amount($invoice);

  is($invoice->netamount,     5.85 + 11.66,     "${title}: netamount");
  is($invoice->amount,        6.96 + 12.48,     "${title}: amount");
  is($paid_amount,                  -19.44,     "${title}: paid amount");
  is($invoice->paid,                 19.44,     "${title}: paid");
  is($number_of_payments,                1,     "${title}: 1 AR_paid bookings");
  is($total,                             0,     "${title}: even balance");
}

# test 4
sub test_default_invoice_two_items_19_7_without_skonto_incomplete_payment() {
  my $title = 'default invoice, two items, 19/7% tax without skonto incomplete payment';

  my $item1   = create_invoice_item(part => $parts[0], qty => 2.5);
  my $item2   = create_invoice_item(part => $parts[1], qty => 1.2);
  my $invoice = create_sales_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item1, $item2 ],
    payment_id   => $payment_terms->id,
  );

  $invoice->pay_invoice( amount       => '9.44',
                         payment_type => 'without_skonto',
                         chart_id     => $bank_account->chart_id,
                         transdate    => DateTime->today_local->to_kivitendo,
                       );

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice);
  my $total = total_amount($invoice);

  is($invoice->netamount,        5.85 + 11.66,     "${title}: netamount");
  is($invoice->amount,           6.96 + 12.48,     "${title}: amount");
  is($paid_amount,              -9.44,             "${title}: paid amount");
  is($invoice->paid,             9.44,            "${title}: paid");
  is($number_of_payments,   1,                "${title}: 1 AR_paid bookings");
  is($total,                    0,                "${title}: even balance");
}

# test 5
sub test_default_invoice_two_items_19_7_tax_without_skonto_multiple_payments() {
  my $title = 'default invoice, two items, 19/7% tax not included';

  my $item1   = create_invoice_item(part => $parts[0], qty => 2.5);
  my $item2   = create_invoice_item(part => $parts[1], qty => 1.2);
  my $invoice = create_sales_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item1, $item2 ],
    payment_id   => $payment_terms->id,
  );

  $invoice->pay_invoice( amount       => '9.44',
                         payment_type => 'without_skonto',
                         chart_id     => $bank_account->chart_id,
                         transdate    => DateTime->today_local->to_kivitendo
                       );
  $invoice->pay_invoice( amount       => '10.00',
                         chart_id     => $bank_account->chart_id,
                         transdate    => DateTime->today_local->to_kivitendo
                       );

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice);
  my $total = total_amount($invoice);

  is($invoice->netamount,        5.85 + 11.66,     "${title}: netamount");
  is($invoice->amount,           6.96 + 12.48,     "${title}: amount");
  is($paid_amount,                     -19.44,     "${title}: paid amount");
  is($invoice->paid,                    19.44,     "${title}: paid");
  is($number_of_payments,                   2,     "${title}: 2 AR_paid bookings");
  is($total,                                0,     "${title}: even balance");

}

# test 6
sub test_default_invoice_two_items_19_7_tax_without_skonto_multiple_payments_final_difference_as_skonto() {
  my $title = 'default invoice, two items, 19/7% tax not included';

  my $item1   = create_invoice_item(part => $parts[0], qty => 2.5);
  my $item2   = create_invoice_item(part => $parts[1], qty => 1.2);
  my $invoice = create_sales_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item1, $item2 ],
    payment_id   => $payment_terms->id,
  );

  $invoice->pay_invoice( amount       => '9.44',
                         payment_type => 'without_skonto',
                         chart_id     => $bank_account->chart_id,
                         transdate    => DateTime->today_local->to_kivitendo
                       );
  $invoice->pay_invoice( amount       => '8.73',
                         payment_type => 'without_skonto',
                         chart_id     => $bank_account->chart_id,
                         transdate    => DateTime->today_local->to_kivitendo
                       );
  $invoice->pay_invoice( amount       => $invoice->open_amount,
                         payment_type => 'difference_as_skonto',
                         chart_id     => $bank_account->chart_id,
                         transdate    => DateTime->today_local->to_kivitendo
                       );

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice);
  my $total = total_amount($invoice);

  is($invoice->netamount,        5.85 + 11.66,     "${title}: netamount");
  is($invoice->amount,           6.96 + 12.48,     "${title}: amount");
  is($paid_amount,                     -19.44,     "${title}: paid amount");
  is($invoice->paid,                    19.44,     "${title}: paid");
  is($number_of_payments,                   4,     "${title}: 4 AR_paid bookings");
  is($total,                                0,     "${title}: even balance");

}

sub  test_default_invoice_two_items_19_7_tax_without_skonto_multiple_payments_final_difference_as_skonto_1cent() {
  my $title = 'default invoice, two items, 19/7% tax not included';

  # if there is only one cent left there can only be one skonto booking, the
  # error handling should choose the highest amount, which is the 7% account
  # (11.66) rather than the 19% account (5.85).  The actual tax amount is
  # higher for the 19% case, though (1.11 compared to 0.82)

  my $item1   = create_invoice_item(part => $parts[0], qty => 2.5);
  my $item2   = create_invoice_item(part => $parts[1], qty => 1.2);
  my $invoice = create_sales_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item1, $item2 ],
    payment_id   => $payment_terms->id,
  );

  $invoice->pay_invoice( amount       => '19.42',
                         payment_type => 'without_skonto',
                         chart_id     => $bank_account->chart_id,
                         transdate    => DateTime->today_local->to_kivitendo
                       );
  $invoice->pay_invoice( amount       => $invoice->open_amount,
                         payment_type => 'difference_as_skonto',
                         chart_id     => $bank_account->chart_id,
                         transdate    => DateTime->today_local->to_kivitendo
                       );

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice);
  my $total = total_amount($invoice);

  is($invoice->netamount,        5.85 + 11.66,     "${title}: netamount");
  is($invoice->amount,           6.96 + 12.48,     "${title}: amount");
  is($paid_amount,                     -19.44,     "${title}: paid amount");
  is($invoice->paid,                    19.44,     "${title}: paid");
  is($number_of_payments,                   3,     "${title}: 2 AR_paid bookings");
  is($total,                                0,     "${title}: even balance");

}

sub test_default_invoice_two_items_19_7_tax_without_skonto_multiple_payments_final_difference_as_skonto_2cent() {
  my $title = 'default invoice, two items, 19/7% tax not included';

  # if there are two cents left there will be two skonto bookings, 1 cent each
  my $item1   = create_invoice_item(part => $parts[0], qty => 2.5);
  my $item2   = create_invoice_item(part => $parts[1], qty => 1.2);
  my $invoice = create_sales_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item1, $item2 ],
    payment_id   => $payment_terms->id,
  );

  $invoice->pay_invoice( amount       => '19.42',
                         payment_type => 'without_skonto',
                         chart_id     => $bank_account->chart_id,
                         transdate    => DateTime->today_local->to_kivitendo
                       );
  $invoice->pay_invoice( amount       => $invoice->open_amount,
                         payment_type => 'difference_as_skonto',
                         chart_id     => $bank_account->chart_id,
                         transdate    => DateTime->today_local->to_kivitendo
                       );

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice);
  my $total = total_amount($invoice);

  is($invoice->netamount,        5.85 + 11.66,     "${title}: netamount");
  is($invoice->amount,           6.96 + 12.48,     "${title}: amount");
  is($paid_amount,                     -19.44,     "${title}: paid amount");
  is($invoice->paid,                    19.44,     "${title}: paid");
  is($number_of_payments,                   3,     "${title}: 3 AR_paid bookings");
  is($total,                                0,     "${title}: even balance");

}

sub test_default_invoice_one_item_19_multiple_payment_final_difference_as_skonto() {
  my $title = 'default invoice, one item, 19% tax, without_skonto';

  my $item    = create_invoice_item(part => $parts[0], qty => 2.5);
  my $invoice = create_sales_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item ],
    payment_id   => $payment_terms->id,
  );

  # default values
  my %params = ( chart_id  => $bank_account->chart_id,
                 transdate => DateTime->today_local->to_kivitendo
               );

  $params{amount}       = '2.32';
  $params{payment_type} = 'without_skonto';
  $invoice->pay_invoice( %params );

  $params{amount}       = '3.81';
  $params{payment_type} = 'without_skonto';
  $invoice->pay_invoice( %params );

  $params{amount}       = $invoice->open_amount; # set amount, otherwise previous 3.81 is used
  $params{payment_type} = 'difference_as_skonto';
  $invoice->pay_invoice( %params );

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice);
  my $total = total_amount($invoice);

  is($invoice->netamount,       5.85,     "${title}: netamount");
  is($invoice->amount,          6.96,     "${title}: amount");
  is($paid_amount,             -6.96,     "${title}: paid amount");
  is($number_of_payments,          3,     "${title}: 3 AR_paid booking");
  is($invoice->paid,            6.96,     "${title}: paid");
  is($total,                       0,     "${title}: even balance");

}

sub test_default_invoice_one_item_19_multiple_payment_final_difference_as_skonto_1cent() {
  my $title = 'default invoice, one item, 19% tax, without_skonto';

  my $item    = create_invoice_item(part => $parts[0], qty => 2.5);
  my $invoice = create_sales_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item ],
    payment_id   => $payment_terms->id,
  );

  # default values
  my %params = ( chart_id  => $bank_account->chart_id,
                 transdate => DateTime->today_local->to_kivitendo
               );

  $params{amount}       = '6.95';
  $params{payment_type} = 'without_skonto';
  $invoice->pay_invoice( %params );

  $params{amount}       = $invoice->open_amount; # set amount, otherwise previous value 6.95 is used
  $params{payment_type} = 'difference_as_skonto';
  $invoice->pay_invoice( %params );

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice);
  my $total = total_amount($invoice);

  is($invoice->netamount,       5.85,     "${title}: netamount");
  is($invoice->amount,          6.96,     "${title}: amount");
  is($paid_amount,             -6.96,     "${title}: paid amount");
  is($number_of_payments,          2,     "${title}: 3 AR_paid booking");
  is($invoice->paid,            6.96,     "${title}: paid");
  is($total,                       0,     "${title}: even balance");

}

# test 3 : two items, without skonto
sub test_default_purchase_invoice_two_charts_19_7_without_skonto() {
  my $title = 'default invoice, two items, 19/7% tax without skonto';

  my $purchase_invoice = new_purchase_invoice();

  my %params = ( chart_id => $bank_account->chart_id,
                 transdate => DateTime->today_local->to_kivitendo
               );

  $params{amount} = '226'; # pass full amount
  $params{payment_type} = 'without_skonto';

  $purchase_invoice->pay_invoice( %params );

  my ($number_of_payments, $paid_amount) = number_of_payments($purchase_invoice);
  my $total = total_amount($purchase_invoice);

  is($paid_amount,         226,     "${title}: paid amount");
  is($number_of_payments,    1,     "${title}: 1 AP_paid bookings");
  is($total,                 0,     "${title}: even balance");

}

sub test_default_purchase_invoice_two_charts_19_7_with_skonto() {
  my $title = 'default invoice, two items, 19/7% tax without skonto';

  my $purchase_invoice = new_purchase_invoice();

  my %params = ( chart_id => $bank_account->chart_id,
                 transdate => DateTime->today_local->to_kivitendo
               );

  # $params{amount} = '226'; # pass full amount
  $params{payment_type} = 'with_skonto_pt';

  $purchase_invoice->pay_invoice( %params );

  my ($number_of_payments, $paid_amount) = number_of_payments($purchase_invoice);
  my $total = total_amount($purchase_invoice);

  is($paid_amount,         226,     "${title}: paid amount");
  is($number_of_payments,    3,     "${title}: 1 AP_paid bookings");
  is($total,                 0,     "${title}: even balance");

}

sub test_default_purchase_invoice_two_charts_19_7_tax_partial_unrounded_payment_without_skonto() {
  my $title = 'default purchase_invoice, two charts, 19/7% tax multiple payments with final difference as skonto';

  # check whether unrounded amounts passed via $params{amount} are rounded for without_skonto case
  my $purchase_invoice = new_purchase_invoice();
  $purchase_invoice->pay_invoice(
                          amount       => ( $purchase_invoice->amount / 3 * 2),
                          payment_type => 'without_skonto',
                          chart_id     => $bank_account->chart_id,
                          transdate    => DateTime->today_local->to_kivitendo
                         );
  my ($number_of_payments, $paid_amount) = number_of_payments($purchase_invoice);
  my $total = total_amount($purchase_invoice);

  is($paid_amount,         150.67,   "${title}: paid amount");
  is($number_of_payments,       1,   "${title}: 1 AP_paid bookings");
  is($total,                    0,   "${title}: even balance");
};


sub test_default_purchase_invoice_two_charts_19_7_tax_without_skonto_multiple_payments_final_difference_as_skonto() {
  my $title = 'default purchase_invoice, two charts, 19/7% tax multiple payments with final difference as skonto';

  my $purchase_invoice = new_purchase_invoice();

  # pay 2/3 and 1/5, leaves 3.83% to be used as Skonto
  $purchase_invoice->pay_invoice(
                          amount       => ( $purchase_invoice->amount / 3 * 2),
                          payment_type => 'without_skonto',
                          chart_id     => $bank_account->chart_id,
                          transdate    => DateTime->today_local->to_kivitendo
                         );
  $purchase_invoice->pay_invoice(
                          amount       => ( $purchase_invoice->amount / 5 ),
                          payment_type => 'without_skonto',
                          chart_id     => $bank_account->chart_id,
                          transdate    => DateTime->today_local->to_kivitendo
                         );
  $purchase_invoice->pay_invoice(
                          payment_type => 'difference_as_skonto',
                          chart_id     => $bank_account->chart_id,
                          transdate    => DateTime->today_local->to_kivitendo
                         );

  my ($number_of_payments, $paid_amount) = number_of_payments($purchase_invoice);
  my $total = total_amount($purchase_invoice);

  is($paid_amount,         226, "${title}: paid amount");
  is($number_of_payments,    4, "${title}: 1 AP_paid bookings");
  is($total,                 0, "${title}: even balance");

}

# test
sub test_default_invoice_two_items_19_7_tax_with_skonto_50_50() {
  my $title = 'default invoice, two items, 19/7% tax with_skonto_pt 50/50';

  my $item1   = create_invoice_item(part => $parts[2], qty => 1);
  my $item2   = create_invoice_item(part => $parts[3], qty => 1);
  my $invoice = create_sales_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item1, $item2 ],
    payment_id   => $payment_terms->id,
  );

  # default values
  my %params = ( chart_id => $bank_account->chart_id,
                 transdate => DateTime->today_local->to_kivitendo
               );

  $params{amount} = $invoice->amount_less_skonto;
  $params{payment_type} = 'with_skonto_pt';

  $invoice->pay_invoice( %params );

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice);
  my $total = total_amount($invoice);

  is($invoice->netamount,        100,     "${title}: netamount");
  is($invoice->amount,           113,     "${title}: amount");
  is($paid_amount,              -113,     "${title}: paid amount");
  is($invoice->paid,             113,     "${title}: paid");
  is($number_of_payments,          3,     "${title}: 3 AR_paid bookings");
  is($total,                       0,     "${title}: even balance");
}

# test
sub test_default_invoice_four_items_19_7_tax_with_skonto_4x_25() {
  my $title = 'default invoice, four items, 19/7% tax with_skonto_pt 4x25';

  my $item1   = create_invoice_item(part => $parts[2], qty => 0.5);
  my $item2   = create_invoice_item(part => $parts[3], qty => 0.5);
  my $item3   = create_invoice_item(part => $parts[2], qty => 0.5);
  my $item4   = create_invoice_item(part => $parts[3], qty => 0.5);
  my $invoice = create_sales_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item1, $item2, $item3, $item4 ],
    payment_id   => $payment_terms->id,
  );

  # default values
  my %params = ( chart_id => $bank_account->chart_id,
                 transdate => DateTime->today_local->to_kivitendo
               );

  $params{amount} = $invoice->amount_less_skonto;
  $params{payment_type} = 'with_skonto_pt';

  $invoice->pay_invoice( %params );

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice);
  my $total = total_amount($invoice);

  is($invoice->netamount , 100  , "${title}: netamount");
  is($invoice->amount    , 113  , "${title}: amount");
  is($paid_amount        , -113 , "${title}: paid amount");
  is($invoice->paid      , 113  , "${title}: paid");
  is($number_of_payments , 3    , "${title}: 3 AR_paid bookings");
  is($total              , 0    , "${title}: even balance");
}

sub test_default_invoice_four_items_19_7_tax_with_skonto_4x_25_tax_included() {
  my $title = 'default invoice, four items, 19/7% tax with_skonto_pt 4x25';

  my $item1   = create_invoice_item(part => $parts[2], qty => 0.5);
  my $item2   = create_invoice_item(part => $parts[3], qty => 0.5);
  my $item3   = create_invoice_item(part => $parts[2], qty => 0.5);
  my $item4   = create_invoice_item(part => $parts[3], qty => 0.5);
  my $invoice = create_sales_invoice(
    taxincluded  => 1,
    invoiceitems => [ $item1, $item2, $item3, $item4 ],
    payment_id   => $payment_terms->id,
  );

  # default values
  my %params = ( chart_id => $bank_account->chart_id,
                 transdate => DateTime->today_local->to_kivitendo
               );

  $params{amount} = $invoice->amount_less_skonto;
  $params{payment_type} = 'with_skonto_pt';

  $invoice->pay_invoice( %params );

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice);
  my $total = total_amount($invoice);

  is($invoice->netamount,   88.75,    "${title}: netamount");
  is($invoice->amount,        100,    "${title}: amount");
  is($paid_amount,           -100,    "${title}: paid amount");
  is($invoice->paid,          100,    "${title}: paid");
  is($number_of_payments,       3,    "${title}: 3 AR_paid bookings");
TODO: {
  local $TODO = "currently this test fails because the code writing the invoice is buggy, the calculation of skonto is correct";
  is($total,                    0,    "${title}: even balance");
  }
}

sub test_default_invoice_four_items_19_7_tax_with_skonto_4x_25_multiple() {
  my $title = 'default invoice, four items, 19/7% tax with_skonto_pt 4x25';

  my $item1   = create_invoice_item(part => $parts[2], qty => 0.5);
  my $item2   = create_invoice_item(part => $parts[3], qty => 0.5);
  my $item3   = create_invoice_item(part => $parts[2], qty => 0.5);
  my $item4   = create_invoice_item(part => $parts[3], qty => 0.5);
  my $invoice = create_sales_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item1, $item2, $item3, $item4 ],
    payment_id   => $payment_terms->id,
  );

  $invoice->pay_invoice( amount       => '90',
                         payment_type => 'without_skonto',
                         chart_id     => $bank_account->chart_id,
                         transdate => DateTime->today_local->to_kivitendo
                       );
  $invoice->pay_invoice( payment_type => 'difference_as_skonto',
                         chart_id     => $bank_account->chart_id,
                         transdate    => DateTime->today_local->to_kivitendo
                       );

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice);
  my $total = total_amount($invoice);

  is($invoice->netamount,  100,     "${title}: netamount");
  is($invoice->amount,     113,     "${title}: amount");
  is($paid_amount,        -113,     "${title}: paid amount");
  is($invoice->paid,       113,     "${title}: paid");
  is($number_of_payments,    3,     "${title}: 3 AR_paid bookings");
  is($total,                 0,     "${title}: even balance: this will fail due to rounding error in invoice post, not the skonto");
}

sub test_ar_currency_tax_not_included_and_payment {
  my $title = 'test_ar_currency_tax_not_included_and_payment_2';

  my $netamount = $::form->round_amount(75 * $exchangerate->sell,2); #  75 in CUR, 100.00 in EUR
  my $amount    = $::form->round_amount($netamount * 1.19,2);        # 100 in CUR, 119.00 in EUR
  my $invoice   = SL::DB::Invoice->new(
      invoice      => 0,
      amount       => $amount,
      netamount    => $netamount,
      transdate    => $transdate1,
      taxincluded  => 0,
      customer_id  => $customer->id,
      taxzone_id   => $customer->taxzone_id,
      currency_id  => $currency->id,
      transactions => [],
      notes        => 'test_ar_currency_tax_not_included_and_payment',
  );
  $invoice->add_ar_amount_row(
    amount     => $invoice->netamount,
    chart      => $ar_amount_chart,
    tax_id     => $tax->id,
  );

  $invoice->create_ar_row(chart => $ar_chart);
  $invoice->save;

  is(SL::DB::Manager::Invoice->get_all_count(where => [ invoice => 0 ]), 1, 'there is one ar transaction');
  is($invoice->currency_id , $currency->id , 'currency_id has been saved');
  is($invoice->netamount   , 100           , 'ar amount has been converted');
  is($invoice->amount      , 119           , 'ar amount has been converted');
  is($invoice->taxincluded ,   0           , 'ar transaction doesn\'t have taxincluded');
  is(SL::DB::Manager::AccTransaction->find_by(chart_id => $ar_amount_chart->id, trans_id => $invoice->id)->amount, '100.00000', $ar_amount_chart->accno . ': has been converted for currency');
  is(SL::DB::Manager::AccTransaction->find_by(chart_id => $ar_chart->id, trans_id => $invoice->id)->amount, '-119.00000', $ar_chart->accno . ': has been converted for currency');

  $invoice->pay_invoice(chart_id   => $bank->id,
                        amount     => 50,
                        currency   => 'CUR',
                        transdate  => $transdate1->to_kivitendo,
                       );
  $invoice->pay_invoice(chart_id   => $bank->id,
                        amount     => 39.25,
                        currency   => 'CUR',
                        transdate  => $transdate1->to_kivitendo,
                       );
  # $invoice->pay_invoice(chart_id   => $bank->id,
  #                       amount     => 30,
  #                       transdate  => $transdate2->to_kivitendo,
  #                      );
  is(scalar @{$invoice->transactions}, 9, 'ar transaction has 9 transactions (incl. fxtransactions)');
  is($invoice->paid, $invoice->amount, 'ar transaction paid = amount in default currency');
};

sub test_ar_currency_tax_included {
  my $title = 'test_ar_currency_tax_included';

  # we want the acc_trans amount to be 100
  my $amount    = $::form->round_amount(75 * $exchangerate->sell * 1.19);
  my $netamount = $::form->round_amount($amount / 1.19,2);
  my $invoice = SL::DB::Invoice->new(
      invoice      => 0,
      amount       => 119,
      netamount    => 100,
      transdate    => $transdate1,
      taxincluded  => 1,
      customer_id  => $customer->id,
      taxzone_id   => $customer->taxzone_id,
      currency_id  => $currency->id,
      notes        => 'test_ar_currency_tax_included',
      transactions => [],
  );
  $invoice->add_ar_amount_row( # should take care of taxincluded
    amount     => $invoice->amount, # tax included in local currency
    chart      => $ar_amount_chart,
    tax_id     => $tax->id,
  );

  $invoice->create_ar_row( chart => $ar_chart );
  $invoice->save;
  is(SL::DB::Manager::Invoice->get_all_count(where => [ invoice => 0 ]), 2, 'there are now two ar transactions');
  is($invoice->currency_id , $currency->id , 'currency_id has been saved');
  is($invoice->amount      , $amount       , 'amount ok');
  is($invoice->netamount   , $netamount    , 'netamount ok');
  is($invoice->taxincluded , 1             , 'ar transaction has taxincluded');
  is(SL::DB::Manager::AccTransaction->find_by(chart_id => $ar_amount_chart->id, trans_id => $invoice->id)->amount, '100.00000', $ar_amount_chart->accno . ': has been converted for currency');
  is(SL::DB::Manager::AccTransaction->find_by(chart_id => $ar_chart->id, trans_id => $invoice->id)->amount, '-119.00000', $ar_chart->accno . ': has been converted for currency');
  $invoice->pay_invoice(chart_id   => $bank->id,
                        amount     => 89.25,
                        currency   => 'CUR',
                        transdate  => $transdate1->to_kivitendo,
                       );

};

sub test_ap_currency_tax_not_included_and_payment {
  my $title = 'test_ap_currency_tax_not_included_and_payment';

  my $netamount = $::form->round_amount(75 * $exchangerate->buy,2); #  75 in CUR, 100.00 in EUR
  my $amount    = $::form->round_amount($netamount * 1.19,2);        # 100 in CUR, 119.00 in EUR
  my $invoice   = SL::DB::PurchaseInvoice->new(
      invoice      => 0,
      invnumber    => 'test_ap_currency_tax_not_included_and_payment',
      amount       => $amount,
      netamount    => $netamount,
      transdate    => $transdate1,
      taxincluded  => 0,
      vendor_id    => $vendor->id,
      taxzone_id   => $vendor->taxzone_id,
      currency_id  => $currency->id,
      transactions => [],
      notes        => 'test_ap_currency_tax_not_included_and_payment',
  );
  $invoice->add_ap_amount_row(
    amount     => $invoice->netamount,
    chart      => $ap_amount_chart,
    tax_id     => $tax_9->id,
  );

  $invoice->create_ap_row(chart => $ap_chart);
  $invoice->save;

  is($invoice->currency_id, $currency->id, 'currency_id has been saved');
  is($invoice->netamount, 100, 'ap amount has been converted');
  is($invoice->amount, 119, 'ap amount has been converted');
  is($invoice->taxincluded, 0, 'ap transaction doesn\'t have taxincluded');
  is(SL::DB::Manager::AccTransaction->find_by(chart_id => $ap_amount_chart->id, trans_id => $invoice->id)->amount, '-100.00000', $ap_amount_chart->accno . ': has been converted for currency');
  is(SL::DB::Manager::AccTransaction->find_by(chart_id => $ap_chart->id, trans_id => $invoice->id)->amount, '119.00000', $ap_chart->accno . ': has been converted for currency');

  $invoice->pay_invoice(chart_id   => $bank->id,
                        amount     => 50,
                        currency   => 'CUR',
                        transdate  => $transdate1->to_kivitendo,
                       );
  $invoice->pay_invoice(chart_id   => $bank->id,
                        amount     => 39.25,
                        currency   => 'CUR',
                        transdate  => $transdate1->to_kivitendo,
                       );
  is(scalar @{$invoice->transactions}, 9, 'ap transaction has 9 transactions (incl. fxtransactions)');
  is($invoice->paid, $invoice->amount, 'ap transaction paid = amount in default currency');
};

sub test_ap_currency_tax_included {
  my $title = 'test_ap_currency_tax_included';

  # we want the acc_trans amount to be 100
  my $amount    = $::form->round_amount(75 * $exchangerate->buy * 1.19);
  my $netamount = $::form->round_amount($amount / 1.19,2);
  my $invoice = SL::DB::PurchaseInvoice->new(
      invoice      => 0,
      amount       => 119, #$amount,
      netamount    => 100, #$netamount,
      transdate    => $transdate1,
      taxincluded  => 1,
      vendor_id    => $vendor->id,
      taxzone_id   => $vendor->taxzone_id,
      currency_id  => $currency->id,
      notes        => 'test_ap_currency_tax_included',
      invnumber    => 'test_ap_currency_tax_included',
      transactions => [],
  );
  $invoice->add_ap_amount_row( # should take care of taxincluded
    amount     => $invoice->amount, # tax included in local currency
    chart      => $ap_amount_chart,
    tax_id     => $tax_9->id,
  );

  $invoice->create_ap_row( chart => $ap_chart );
  $invoice->save;
  is($invoice->currency_id , $currency->id , 'currency_id has been saved');
  is($invoice->amount      , $amount       , 'amount ok');
  is($invoice->netamount   , $netamount    , 'netamount ok');
  is($invoice->taxincluded , 1             , 'ap transaction has taxincluded');
  is(SL::DB::Manager::AccTransaction->find_by(chart_id => $ap_amount_chart->id, trans_id => $invoice->id)->amount, '-100.00000', $ap_amount_chart->accno . ': has been converted for currency');
  is(SL::DB::Manager::AccTransaction->find_by(chart_id => $ap_chart->id, trans_id => $invoice->id)->amount, '119.00000', $ap_chart->accno . ': has been converted for currency');

  $invoice->pay_invoice(chart_id   => $bank->id,
                        amount     => 89.25,
                        currency   => 'CUR',
                        transdate  => $transdate1->to_kivitendo,
                       );

};

sub test_ar_currency_tax_not_included_and_payment_2 {
  my $title = 'test_ar_currency_tax_not_included_and_payment_2';

  my $netamount = $::form->round_amount(125 * $exchangerate2->sell,2); # 125.00 in CUR, 100.00 in EUR
  my $amount    = $::form->round_amount($netamount * 1.19,2);          # 148.75 in CUR, 119.00 in EUR
  my $invoice   = SL::DB::Invoice->new(
      invoice      => 0,
      amount       => $amount,
      netamount    => $netamount,
      transdate    => $transdate2,
      taxincluded  => 0,
      customer_id  => $customer->id,
      taxzone_id   => $customer->taxzone_id,
      currency_id  => $currency->id,
      transactions => [],
      notes        => 'test_ar_currency_tax_not_included_and_payment 0.8',
      invnumber    => 'test_ar_currency_tax_not_included_and_payment 0.8',
  );
  $invoice->add_ar_amount_row(
    amount     => $invoice->netamount,
    chart      => $ar_amount_chart,
    tax_id     => $tax->id,
  );

  $invoice->create_ar_row(chart => $ar_chart);
  $invoice->save;

  is($invoice->currency_id , $currency->id , "$title: currency_id has been saved");
  is($invoice->netamount   , 100           , "$title: ar amount has been converted");
  is($invoice->amount      , 119           , "$title: ar amount has been converted");
  is($invoice->taxincluded ,   0           , "$title: ar transaction doesn\"t have taxincluded");
  is(SL::DB::Manager::AccTransaction->find_by(chart_id => $ar_amount_chart->id, trans_id => $invoice->id)->amount, '100.00000', $title . " " . $ar_amount_chart->accno . ": has been converted for currency");
  is(SL::DB::Manager::AccTransaction->find_by(chart_id => $ar_chart->id, trans_id => $invoice->id)->amount, '-119.00000', $title  . " " . $ar_chart->accno . ': has been converted for currency');

  $invoice->pay_invoice(chart_id   => $bank->id,
                        amount     => 123.45,
                        currency   => 'CUR',
                        transdate  => $transdate2->to_kivitendo,
                       );
  $invoice->pay_invoice(chart_id   => $bank->id,
                        amount     => 15.30,
                        currency   => 'CUR',
                        transdate  => $transdate3->to_kivitendo,
                       );
  $invoice->pay_invoice(chart_id   => $bank->id,
                        amount     => 10.00,
                        currency   => 'CUR',
                        transdate  => $transdate4->to_kivitendo,
                       );
  # $invoice->pay_invoice(chart_id   => $bank->id,
  #                       amount     => 30,
  #                       transdate  => $transdate2->to_kivitendo,
  #                      );
  my $fx_transactions = SL::DB::Manager::AccTransaction->get_all(where => [ trans_id => $invoice->id, fx_transaction => 1 ], sort_by => ('acc_trans_id'));
  is(scalar @{$fx_transactions}, 3, "$title: ar transaction has 3 fx transactions");
  is($fx_transactions->[0]->amount, '24.69000', "$title fx transactions 1: 123.45-(123.45*0.8) = 24.69");

  is(scalar @{$invoice->transactions}, 14, "$title ar transaction has 14 transactions (incl. fxtransactions and fx_gain)");
  is($invoice->paid, $invoice->amount, "$title ar transaction paid = amount in default currency");
};

sub test_ar_currency_tax_not_included_and_payment_2_credit_note {
  my $title = 'test_ar_currency_tax_not_included_and_payment_2_credit_note';

  my $netamount = $::form->round_amount(-125 * $exchangerate2->sell,2); # 125.00 in CUR, 100.00 in EUR
  my $amount    = $::form->round_amount($netamount * 1.19,2);          # 148.75 in CUR, 119.00 in EUR
  my $invoice   = SL::DB::Invoice->new(
      invoice      => 0,
      amount       => $amount,
      netamount    => $netamount,
      transdate    => $transdate2,
      taxincluded  => 0,
      customer_id  => $customer->id,
      taxzone_id   => $customer->taxzone_id,
      currency_id  => $currency->id,
      transactions => [],
      notes        => 'test_ar_currency_tax_not_included_and_payment credit note 0.8',
      invnumber    => 'test_ar_currency_tax_not_included_and_payment credit note 0.8',
  );
  $invoice->add_ar_amount_row(
    amount     => $invoice->netamount,
    chart      => $ar_amount_chart,
    tax_id     => $tax->id,
  );

  $invoice->create_ar_row(chart => $ar_chart);
  $invoice->save;

  is($invoice->currency_id , $currency->id , 'currency_id has been saved');
  is($invoice->netamount   , -100          , 'ar amount has been converted');
  is($invoice->amount      , -119          , 'ar amount has been converted');
  is($invoice->taxincluded ,   0           , 'ar transaction doesn\'t have taxincluded');
  is(SL::DB::Manager::AccTransaction->find_by(chart_id => $ar_amount_chart->id, trans_id => $invoice->id)->amount, '-100.00000', $ar_amount_chart->accno . ': has been converted for currency');
  is(SL::DB::Manager::AccTransaction->find_by(chart_id => $ar_chart->id, trans_id => $invoice->id)->amount, '119.00000', $ar_chart->accno . ': has been converted for currency');

  $invoice->pay_invoice(chart_id   => $bank->id,
                        amount     => -123.45,
                        currency   => 'CUR',
                        transdate  => $transdate2->to_kivitendo,
                       );
  $invoice->pay_invoice(chart_id   => $bank->id,
                        amount     => -25.30,
                        currency   => 'CUR',
                        transdate  => $transdate2->to_kivitendo,
                       );
  my $fx_transactions = SL::DB::Manager::AccTransaction->get_all(where => [ trans_id => $invoice->id, fx_transaction => 1 ], sort_by => ('acc_trans_id'));
  is(scalar @{$fx_transactions}, 2, 'ar transaction has 2 fx transactions');
  is($fx_transactions->[0]->amount, '-24.69000', 'fx transactions 1: 123.45-(123.45*0.8) = 24.69');

  is(scalar @{$invoice->transactions}, 9, 'ar transaction has 9 transactions (incl. fxtransactions)');
  is($invoice->paid, $invoice->amount, 'ar transaction paid = amount in default currency');
};

sub test_ap_currency_tax_not_included_and_payment_2 {
  my $title = 'test_ap_currency_tax_not_included_and_payment_2';

  my $netamount = $::form->round_amount(125 * $exchangerate2->sell,2); # 125.00 in CUR, 100.00 in EUR
  my $amount    = $::form->round_amount($netamount * 1.19,2);          # 148.75 in CUR, 119.00 in EUR
  my $invoice   = SL::DB::PurchaseInvoice->new(
      invoice      => 0,
      amount       => $amount,
      netamount    => $netamount,
      transdate    => $transdate2,
      taxincluded  => 0,
      vendor_id    => $vendor->id,
      taxzone_id   => $vendor->taxzone_id,
      currency_id  => $currency->id,
      transactions => [],
      notes        => 'test_ap_currency_tax_not_included_and_payment_2 0.8 + 1.33333',
      invnumber    => 'test_ap_currency_tax_not_included_and_payment_2 0.8 + 1.33333',
  );
  $invoice->add_ap_amount_row(
    amount     => $invoice->netamount,
    chart      => $ap_amount_chart,
    tax_id     => $tax_9->id,
  );

  $invoice->create_ap_row(chart => $ap_chart);
  $invoice->save;

  is($invoice->currency_id , $currency->id , "$title: currency_id has been saved");
  is($invoice->netamount   ,  100          , "$title: ap amount has been converted");
  is($invoice->amount      ,  119          , "$title: ap amount has been converted");
  is($invoice->taxincluded ,    0          , "$title: ap transaction doesn\'t have taxincluded");
  is(SL::DB::Manager::AccTransaction->find_by(chart_id => $ap_amount_chart->id, trans_id => $invoice->id)->amount, '-100.00000', $ap_amount_chart->accno . ': has been converted for currency');
  is(SL::DB::Manager::AccTransaction->find_by(chart_id => $ap_chart->id, trans_id => $invoice->id)->amount, '119.00000', $ap_chart->accno . ': has been converted for currency');

  $invoice->pay_invoice(chart_id   => $bank->id,
                        amount     => 10,
                        currency   => 'CUR',
                        transdate  => $transdate2->to_kivitendo,
                       );
  $invoice->pay_invoice(chart_id   => $bank->id,
                        amount     => 123.45,
                        currency   => 'CUR',
                        transdate  => $transdate3->to_kivitendo,
                       );
  $invoice->pay_invoice(chart_id   => $bank->id,
                        amount     => 15.30,
                        currency   => 'CUR',
                        transdate  => $transdate4->to_kivitendo,
                       );
  my $fx_transactions = SL::DB::Manager::AccTransaction->get_all(where => [ trans_id => $invoice->id, fx_transaction => 1 ], sort_by => ('acc_trans_id'));
  is(scalar @{$fx_transactions}, 3, "$title: ap transaction has 3 fx transactions");
  is($fx_transactions->[0]->amount,  '-2.00000', "$title: fx transaction 1:  10.00-( 10.00*0.80000) =   2.00000");
  is($fx_transactions->[1]->amount,  '68.59000', "$title: fx transaction 2: 123.45-(123.45*1.55557) = -68.58511");
  is($fx_transactions->[2]->amount,  '-3.40000', "$title: fx transaction 3:  15.30-(15.30 *0.77777) =   3.40012");

  my $fx_loss_transactions = SL::DB::Manager::AccTransaction->get_all(where => [ trans_id => $invoice->id, chart_id => $fxloss_chart->id ], sort_by => ('acc_trans_id'));
  my $fx_gain_transactions = SL::DB::Manager::AccTransaction->get_all(where => [ trans_id => $invoice->id, chart_id => $fxgain_chart->id ], sort_by => ('acc_trans_id'));
  is($fx_gain_transactions->[0]->amount,   '0.34000', "$title: fx gain amount ok");
  is($fx_loss_transactions->[0]->amount, '-93.28000', "$title: fx loss amount ok");

  is(scalar @{$invoice->transactions}, 14, "$title: ap transaction has 14 transactions (incl. fxtransactions and gain_loss)");
  is($invoice->paid, $invoice->amount, "$title: ap transaction paid = amount in default currency");
  is(total_amount($invoice), 0,   "$title: even balance");
};

sub test_ap_currency_tax_not_included_and_payment_2_credit_note {
  my $title = 'test_ap_currency_tax_not_included_and_payment_2_credit_note';

  my $netamount = $::form->round_amount(-125 * $exchangerate2->sell,2); # 125.00 in CUR, 100.00 in EUR
  my $amount    = $::form->round_amount($netamount * 1.19,2);          # 148.75 in CUR, 119.00 in EUR
  my $invoice   = SL::DB::PurchaseInvoice->new(
      invoice      => 0,
      amount       => $amount,
      netamount    => $netamount,
      transdate    => $transdate2,
      taxincluded  => 0,
      vendor_id    => $vendor->id,
      taxzone_id   => $vendor->taxzone_id,
      currency_id  => $currency->id,
      transactions => [],
      notes        => 'test_ap_currency_tax_not_included_and_payment credit note 0.8 + 1.33333',
      invnumber    => 'test_ap_currency_tax_not_included_and_payment credit note 0.8 + 1.33333',
  );
  $invoice->add_ap_amount_row(
    amount     => $invoice->netamount,
    chart      => $ap_amount_chart,
    tax_id     => $tax_9->id,
  );

  $invoice->create_ap_row(chart => $ap_chart);
  $invoice->save;

  is($invoice->currency_id , $currency->id , "$title: currency_id has been saved");
  is($invoice->netamount   , -100          , "$title: ap amount has been converted");
  is($invoice->amount      , -119          , "$title: ap amount has been converted");
  is($invoice->taxincluded ,   0           , "$title: ap transaction doesn\'t have taxincluded");
  is(SL::DB::Manager::AccTransaction->find_by(chart_id => $ap_amount_chart->id, trans_id => $invoice->id)->amount, '100.00000', $ap_amount_chart->accno . ': has been converted for currency');
  is(SL::DB::Manager::AccTransaction->find_by(chart_id => $ap_chart->id, trans_id => $invoice->id)->amount, '-119.00000', $ap_chart->accno . ': has been converted for currency');

  $invoice->pay_invoice(chart_id   => $bank->id,
                        amount     => -10,
                        currency   => 'CUR',
                        transdate  => $transdate2->to_kivitendo,
                       );
  $invoice->pay_invoice(chart_id   => $bank->id,
                        amount     => -123.45,
                        currency   => 'CUR',
                        transdate  => $transdate3->to_kivitendo,
                       );
  $invoice->pay_invoice(chart_id   => $bank->id,
                        amount     => -15.30,
                        currency   => 'CUR',
                        transdate  => $transdate4->to_kivitendo,
                       );
  my $fx_transactions = SL::DB::Manager::AccTransaction->get_all(where => [ trans_id => $invoice->id, fx_transaction => 1 ], sort_by => ('acc_trans_id'));
  is(scalar @{$fx_transactions}, 3, "$title: ap transaction has 3 fx transactions");
  is($fx_transactions->[0]->amount,   '2.00000', "$title: fx transaction 1:  10.00-( 10.00*0.80000) =   2.00000");
  is($fx_transactions->[1]->amount, '-68.59000', "$title: fx transaction 2: 123.45-(123.45*1.55557) = -68.58511");
  is($fx_transactions->[2]->amount,   '3.40000', "$title: fx transaction 3:  15.30-(15.30 *0.77777) =   3.40012");

  my $fx_gain_loss_transactions = SL::DB::Manager::AccTransaction->get_all(where => [ trans_id => $invoice->id, chart_id => $fxgain_chart->id ], sort_by => ('acc_trans_id'));
  is($fx_gain_loss_transactions->[0]->amount, '93.28000', "$title: fx gain loss amount ok");

  is(scalar @{$invoice->transactions}, 14, "$title: ap transaction has 14 transactions (incl. fxtransactions and gain_loss)");
  is($invoice->paid, $invoice->amount, "$title: ap transaction paid = amount in default currency");
  is(total_amount($invoice), 0,   "$title: even balance");
};

sub test_credit_note_two_items_19_7_tax_tax_not_included {
  my $title = 'test_credit_note_two_items_19_7_tax_tax_not_included';

  my $item1   = create_invoice_item(part => $parts[0], qty => 5);
  my $item2   = create_invoice_item(part => $parts[1], qty => 3);
  my $invoice = create_credit_note(
    invnumber    => 'cn1',
    taxincluded  => 0,
    invoiceitems => [ $item1, $item2 ],
  );

  # default values
  my %params = ( chart_id => $bank_account->chart_id,
                 transdate => DateTime->today_local->to_kivitendo,
               );

  $params{amount}       = $invoice->amount,

  $invoice->pay_invoice( %params );

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice);
  my $total = total_amount($invoice);

  is($invoice->netamount,        -40.84,   "${title}: netamount");
  is($invoice->amount,           -45.10,   "${title}: amount");
  is($paid_amount,                45.10,   "${title}: paid amount according to acc_trans is positive (Haben)");
  is($invoice->paid,             -45.10,   "${title}: paid");
  is($number_of_payments,             1,   "${title}: 1 AR_paid bookings");
  is($total,                          0,   "${title}: even balance");
}

1;
