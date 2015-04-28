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
use SL::DB::Employee;
use SL::DB::Invoice;
use SL::DB::Part;
use SL::DB::Unit;
use SL::DB::TaxZone;
use SL::DB::BankAccount;
use SL::DB::PaymentTerm;

my ($customer, $vendor, $currency_id, @parts, $buchungsgruppe, $buchungsgruppe7, $unit, $employee, $tax, $tax7, $taxzone, $payment_terms, $bank_account);

my $ALWAYS_RESET = 1;

my $reset_state_counter = 0;

my $purchase_invoice_counter = 0; # used for generating purchase invnumber

sub clear_up {
  SL::DB::Manager::InvoiceItem->delete_all(all => 1);
  SL::DB::Manager::Invoice->delete_all(all => 1);
  SL::DB::Manager::PurchaseInvoice->delete_all(all => 1);
  SL::DB::Manager::Part->delete_all(all => 1);
  SL::DB::Manager::Customer->delete_all(all => 1);
  SL::DB::Manager::Vendor->delete_all(all => 1);
  SL::DB::Manager::BankAccount->delete_all(all => 1);
  SL::DB::Manager::PaymentTerm->delete_all(all => 1);
};

sub reset_state {
  my %params = @_;

  return if $reset_state_counter;

  $params{$_} ||= {} for qw(buchungsgruppe unit customer part tax vendor);

  clear_up();


  $buchungsgruppe  = SL::DB::Manager::Buchungsgruppe->find_by(description => 'Standard 19%', %{ $params{buchungsgruppe} }) || croak "No accounting group";
  $buchungsgruppe7 = SL::DB::Manager::Buchungsgruppe->find_by(description => 'Standard 7%')                                || croak "No accounting group for 7\%";
  $unit            = SL::DB::Manager::Unit->find_by(name => 'kg', %{ $params{unit} })                                      || croak "No unit";
  $employee        = SL::DB::Manager::Employee->current                                                                    || croak "No employee";
  $tax             = SL::DB::Manager::Tax->find_by(taxkey => 3, rate => 0.19, %{ $params{tax} })                           || croak "No tax";
  $tax7            = SL::DB::Manager::Tax->find_by(taxkey => 2, rate => 0.07)                                              || croak "No tax for 7\%";
  $taxzone         = SL::DB::Manager::TaxZone->find_by( description => 'Inland')                                           || croak "No taxzone";

  $currency_id     = $::instance_conf->get_currency_id;

  $customer     = SL::DB::Customer->new(
    name        => 'Test Customer',
    currency_id => $currency_id,
    taxzone_id  => $taxzone->id,
    %{ $params{customer} }
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
    percent_skonto   => '0.05'
  )->save;

  $vendor       = SL::DB::Vendor->new(
    name        => 'Test Vendor',
    currency_id => $currency_id,
    taxzone_id  => $taxzone->id,
    payment_id  => $payment_terms->id,
    %{ $params{vendor} }
  )->save;


  @parts = ();
  push @parts, SL::DB::Part->new(
    partnumber         => 'T4254',
    description        => 'Fourty-two fifty-four',
    lastcost           => 1.93,
    sellprice          => 2.34,
    buchungsgruppen_id => $buchungsgruppe->id,
    unit               => $unit->name,
    %{ $params{part1} }
  )->save;

  push @parts, SL::DB::Part->new(
    partnumber         => 'T0815',
    description        => 'Zero EIGHT fifteeN @ 7%',
    lastcost           => 5.473,
    sellprice          => 9.714,
    buchungsgruppen_id => $buchungsgruppe7->id,
    unit               => $unit->name,
    %{ $params{part2} }
  )->save;
  push @parts, SL::DB::Part->new(
    partnumber         => '19%',
    description        => 'Testware 19%',
    lastcost           => 0,
    sellprice          => 50,
    buchungsgruppen_id => $buchungsgruppe->id,
    unit               => $unit->name,
    %{ $params{part3} }
  )->save;
  push @parts, SL::DB::Part->new(
    partnumber         => '7%',
    description        => 'Testware 7%',
    lastcost           => 0,
    sellprice          => 50,
    buchungsgruppen_id => $buchungsgruppe7->id,
    unit               => $unit->name,
    %{ $params{part4} }
  )->save;

  $reset_state_counter++;
}

sub new_invoice {
  my %params  = @_;

  return SL::DB::Invoice->new(
    customer_id => $customer->id,
    currency_id => $currency_id,
    employee_id => $employee->id,
    salesman_id => $employee->id,
    gldate      => DateTime->today_local->to_kivitendo,
    taxzone_id  => $taxzone->id,
    transdate   => DateTime->today_local->to_kivitendo,
    invoice     => 1,
    type        => 'invoice',
    %params,
  );

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
    gldate      => DateTime->today_local->to_kivitendo,
    taxzone_id  => $taxzone->id,
    transdate   => DateTime->today_local->to_kivitendo,
    invoice     => 0,
    type        => 'invoice',
    taxincluded => 0,
    amount      => '226',
    netamount   => '200',
    paid        => '0',
    # %params,
  )->save;

  my $today = DateTime->today_local->to_kivitendo;
  my $expense_chart  = SL::DB::Manager::Chart->find_by(accno => '3400');
  my $expense_chart_booking= SL::DB::AccTransaction->new(
                                        trans_id   => $purchase_invoice->id,
                                        chart_id   => $expense_chart->id,
                                        chart_link => $expense_chart->link,
                                        amount     => '-100',
                                        transdate  => $today,
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
                                        transdate  => $today,
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
                                        transdate  => $today,
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
                                         transdate  => $today,
                                         source     => '',
                                         taxkey     => 0,
                                         tax_id     => SL::DB::Manager::Tax->find_by(taxkey => 8)->id);
  $tax_chart_booking->save;
  my $arap_chart  = SL::DB::Manager::Chart->find_by(accno => '1600');
  my $arap_booking= SL::DB::AccTransaction->new(trans_id   => $purchase_invoice->id,
                                                chart_id   => $arap_chart->id,
                                                chart_link => $arap_chart->link,
                                                amount     => '226',
                                                transdate  => $today,
                                                source     => '',
                                                taxkey     => 0,
                                                tax_id     => SL::DB::Manager::Tax->find_by(taxkey => 0)->id);
  $arap_booking->save;

  return $purchase_invoice;
}

sub new_item {
  my (%params) = @_;

  my $part = delete($params{part}) || $parts[0];

  return SL::DB::InvoiceItem->new(
    parts_id    => $part->id,
    lastcost    => $part->lastcost,
    sellprice   => $part->sellprice,
    description => $part->description,
    unit        => $part->unit,
    %params,
  );
}

sub number_of_payments {
  my $transactions = shift;

  my $number_of_payments;
  my $paid_amount;
  foreach my $transaction ( @$transactions ) {
    if ( $transaction->chart_link =~ /(AR_paid|AP_paid)/ ) {
      $paid_amount += $transaction->amount ;
      $number_of_payments++;
    };
  };
  return ($number_of_payments, $paid_amount);
};

sub total_amount {
  my $transactions = shift;

  my $total = sum map { $_->amount } @$transactions;

  return $::form->round_amount($total, 5);

};


# test 1
sub test_default_invoice_one_item_19_without_skonto() {
  reset_state() if $ALWAYS_RESET;

  my $item    = new_item(qty => 2.5);
  my $invoice = new_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item ],
    payment_id   => $payment_terms->id,
  );
  $invoice->post;

  my $purchase_invoice = new_purchase_invoice();


  # default values
  my %params = ( chart_id => $bank_account->chart_id,
                 transdate => DateTime->today_local->to_kivitendo
               );

  $params{amount} = '6.96';
  $params{payment_type} = 'without_skonto';

  $invoice->pay_invoice( %params );

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice->transactions);
  my $total = total_amount($invoice->transactions);

  my $title = 'default invoice, one item, 19% tax, without_skonto';

  is($invoice->netamount,   5.85,      "${title}: netamount");
  is($invoice->amount,      6.96,      "${title}: amount");
  is($paid_amount,         -6.96,      "${title}: paid amount");
  is($number_of_payments,      1,      "${title}: 1 AR_paid booking");
  is($invoice->paid,        6.96,      "${title}: paid");
  is($total,                   0,      "${title}: even balance");

}

sub test_default_invoice_one_item_19_without_skonto_overpaid() {
  reset_state() if $ALWAYS_RESET;

  my $item    = new_item(qty => 2.5);
  my $invoice = new_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item ],
    payment_id   => $payment_terms->id,
  );
  $invoice->post;

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

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice->transactions);
  my $total = total_amount($invoice->transactions);

  my $title = 'default invoice, one item, 19% tax, without_skonto';

  is($invoice->netamount,   5.85,      "${title}: netamount");
  is($invoice->amount,      6.96,      "${title}: amount");
  is($paid_amount,         -6.96,      "${title}: paid amount");
  is($number_of_payments,      2,      "${title}: 1 AR_paid booking");
  is($invoice->paid,        6.96,      "${title}: paid");
  is($total,                   0,      "${title}: even balance");

}


# test 2
sub test_default_invoice_two_items_19_7_tax_with_skonto() {
  reset_state() if $ALWAYS_RESET;

  my $item1   = new_item(qty => 2.5);
  my $item2   = new_item(qty => 1.2, part => $parts[1]);
  my $invoice = new_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item1, $item2 ],
    payment_id  => $payment_terms->id,
  );
  $invoice->post;

  # default values
  my %params = ( chart_id => $bank_account->chart_id,
                 transdate => DateTime->today_local->to_kivitendo
               );

  $params{payment_type} = 'with_skonto_pt';
  $params{amount}       = $invoice->amount_less_skonto;

  $invoice->pay_invoice( %params );

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice->transactions);
  my $total = total_amount($invoice->transactions);

  my $title = 'default invoice, two items, 19/7% tax with_skonto_pt';

  is($invoice->netamount,  5.85 + 11.66,   "${title}: netamount");
  is($invoice->amount,     6.96 + 12.48,   "${title}: amount");
  is($paid_amount,               -19.44,   "${title}: paid amount");
  is($invoice->paid,              19.44,   "${title}: paid");
  is($number_of_payments,             3,   "${title}: 3 AR_paid bookings");
  is($total,                          0,   "${title}: even balance");
}

sub test_default_invoice_two_items_19_7_tax_with_skonto_tax_included() {
  reset_state() if $ALWAYS_RESET;

  my $item1   = new_item(qty => 2.5);
  my $item2   = new_item(qty => 1.2, part => $parts[1]);
  my $invoice = new_invoice(
    taxincluded  => 1,
    invoiceitems => [ $item1, $item2 ],
    payment_id  => $payment_terms->id,
  );
  $invoice->post;

  # default values
  my %params = ( chart_id => $bank_account->chart_id,
                 transdate => DateTime->today_local->to_kivitendo
               );

  $params{payment_type} = 'with_skonto_pt';
  $params{amount}       = $invoice->amount_less_skonto;

  $invoice->pay_invoice( %params );

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice->transactions);
  my $total = total_amount($invoice->transactions);

  my $title = 'default invoice, two items, 19/7% tax with_skonto_pt';

  is($invoice->netamount,         15.82,   "${title}: netamount");
  is($invoice->amount,            17.51,   "${title}: amount");
  is($paid_amount,               -17.51,   "${title}: paid amount");
  is($invoice->paid,              17.51,   "${title}: paid");
  is($number_of_payments,             3,   "${title}: 3 AR_paid bookings");
  is($total,                          0,   "${title}: even balance");
}

# test 3 : two items, without skonto
sub test_default_invoice_two_items_19_7_without_skonto() {
  reset_state() if $ALWAYS_RESET;

  my $item1   = new_item(qty => 2.5);
  my $item2   = new_item(qty => 1.2, part => $parts[1]);
  my $invoice = new_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item1, $item2 ],
    payment_id  => $payment_terms->id,
  );
  $invoice->post;

  # default values
  my %params = ( chart_id => $bank_account->chart_id,
                 transdate => DateTime->today_local->to_kivitendo
               );

  $params{amount} = '19.44'; # pass full amount
  $params{payment_type} = 'without_skonto';

  $invoice->pay_invoice( %params );

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice->transactions);
  my $total = total_amount($invoice->transactions);

  my $title = 'default invoice, two items, 19/7% tax without skonto';

  is($invoice->netamount,     5.85 + 11.66,     "${title}: netamount");
  is($invoice->amount,        6.96 + 12.48,     "${title}: amount");
  is($paid_amount,                  -19.44,     "${title}: paid amount");
  is($invoice->paid,                 19.44,     "${title}: paid");
  is($number_of_payments,                1,     "${title}: 1 AR_paid bookings");
  is($total,                             0,     "${title}: even balance");
}

# test 4
sub test_default_invoice_two_items_19_7_without_skonto_incomplete_payment() {
  reset_state() if $ALWAYS_RESET;

  my $item1   = new_item(qty => 2.5);
  my $item2   = new_item(qty => 1.2, part => $parts[1]);
  my $invoice = new_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item1, $item2 ],
    payment_id  => $payment_terms->id,
  );
  $invoice->post;

  $invoice->pay_invoice( amount       => '9.44',
                         payment_type => 'without_skonto',
                         chart_id     => $bank_account->chart_id,
                         transdate    => DateTime->today_local->to_kivitendo,
                       );

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice->transactions);
  my $total = total_amount($invoice->transactions);

  my $title = 'default invoice, two items, 19/7% tax without skonto incomplete payment';

  is($invoice->netamount,        5.85 + 11.66,     "${title}: netamount");
  is($invoice->amount,           6.96 + 12.48,     "${title}: amount");
  is($paid_amount,              -9.44,             "${title}: paid amount");
  is($invoice->paid,             9.44,            "${title}: paid");
  is($number_of_payments,   1,                "${title}: 1 AR_paid bookings");
  is($total,                    0,                "${title}: even balance");
}

# test 5
sub test_default_invoice_two_items_19_7_tax_without_skonto_multiple_payments() {
  reset_state() if $ALWAYS_RESET;

  my $item1   = new_item(qty => 2.5);
  my $item2   = new_item(qty => 1.2, part => $parts[1]);
  my $invoice = new_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item1, $item2 ],
    payment_id  => $payment_terms->id,
  );
  $invoice->post;

  $invoice->pay_invoice( amount       => '9.44',
                         payment_type => 'without_skonto',
                         chart_id     => $bank_account->chart_id,
                         transdate    => DateTime->today_local->to_kivitendo
                       );
  $invoice->pay_invoice( amount       => '10.00',
                         chart_id     => $bank_account->chart_id,
                         transdate    => DateTime->today_local->to_kivitendo
                       );

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice->transactions);
  my $total = total_amount($invoice->transactions);

  my $title = 'default invoice, two items, 19/7% tax not included';

  is($invoice->netamount,        5.85 + 11.66,     "${title}: netamount");
  is($invoice->amount,           6.96 + 12.48,     "${title}: amount");
  is($paid_amount,                     -19.44,     "${title}: paid amount");
  is($invoice->paid,                    19.44,     "${title}: paid");
  is($number_of_payments,                   2,     "${title}: 2 AR_paid bookings");
  is($total,                                0,     "${title}: even balance");

}

# test 6
sub test_default_invoice_two_items_19_7_tax_without_skonto_multiple_payments_final_difference_as_skonto() {
  reset_state() if $ALWAYS_RESET;

  my $item1   = new_item(qty => 2.5);
  my $item2   = new_item(qty => 1.2, part => $parts[1]);
  my $invoice = new_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item1, $item2 ],
    payment_id  => $payment_terms->id,
  );
  $invoice->post;

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

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice->transactions);
  my $total = total_amount($invoice->transactions);

  my $title = 'default invoice, two items, 19/7% tax not included';

  is($invoice->netamount,        5.85 + 11.66,     "${title}: netamount");
  is($invoice->amount,           6.96 + 12.48,     "${title}: amount");
  is($paid_amount,                     -19.44,     "${title}: paid amount");
  is($invoice->paid,                    19.44,     "${title}: paid");
  is($number_of_payments,                   4,     "${title}: 4 AR_paid bookings");
  is($total,                                0,     "${title}: even balance");

}

sub  test_default_invoice_two_items_19_7_tax_without_skonto_multiple_payments_final_difference_as_skonto_1cent() {
  reset_state() if $ALWAYS_RESET;

  # if there is only one cent left there can only be one skonto booking, the
  # error handling should choose the highest amount, which is the 7% account
  # (11.66) rather than the 19% account (5.85).  The actual tax amount is
  # higher for the 19% case, though (1.11 compared to 0.82)

  my $item1   = new_item(qty => 2.5);
  my $item2   = new_item(qty => 1.2, part => $parts[1]);
  my $invoice = new_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item1, $item2 ],
    payment_id  => $payment_terms->id,
  );
  $invoice->post;

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

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice->transactions);
  my $total = total_amount($invoice->transactions);

  my $title = 'default invoice, two items, 19/7% tax not included';

  is($invoice->netamount,        5.85 + 11.66,     "${title}: netamount");
  is($invoice->amount,           6.96 + 12.48,     "${title}: amount");
  is($paid_amount,                     -19.44,     "${title}: paid amount");
  is($invoice->paid,                    19.44,     "${title}: paid");
  is($number_of_payments,                   3,     "${title}: 2 AR_paid bookings");
  is($total,                                0,     "${title}: even balance");

}

sub  test_default_invoice_two_items_19_7_tax_without_skonto_multiple_payments_final_difference_as_skonto_2cent() {
  reset_state() if $ALWAYS_RESET;

  # if there are two cents left there will be two skonto bookings, 1 cent each
  my $item1   = new_item(qty => 2.5);
  my $item2   = new_item(qty => 1.2, part => $parts[1]);
  my $invoice = new_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item1, $item2 ],
    payment_id  => $payment_terms->id,
  );
  $invoice->post;

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

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice->transactions);
  my $total = total_amount($invoice->transactions);

  my $title = 'default invoice, two items, 19/7% tax not included';

  is($invoice->netamount,        5.85 + 11.66,     "${title}: netamount");
  is($invoice->amount,           6.96 + 12.48,     "${title}: amount");
  is($paid_amount,                     -19.44,     "${title}: paid amount");
  is($invoice->paid,                    19.44,     "${title}: paid");
  is($number_of_payments,                   3,     "${title}: 3 AR_paid bookings");
  is($total,                                0,     "${title}: even balance");

}

sub test_default_invoice_one_item_19_multiple_payment_final_difference_as_skonto() {
  reset_state() if $ALWAYS_RESET;

  my $item    = new_item(qty => 2.5);
  my $invoice = new_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item ],
    payment_id   => $payment_terms->id,
  );
  $invoice->post;

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

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice->transactions);
  my $total = total_amount($invoice->transactions);

  my $title = 'default invoice, one item, 19% tax, without_skonto';

  is($invoice->netamount,       5.85,     "${title}: netamount");
  is($invoice->amount,          6.96,     "${title}: amount");
  is($paid_amount,             -6.96,     "${title}: paid amount");
  is($number_of_payments,          3,     "${title}: 3 AR_paid booking");
  is($invoice->paid,            6.96,     "${title}: paid");
  is($total,                       0,     "${title}: even balance");

}

sub test_default_invoice_one_item_19_multiple_payment_final_difference_as_skonto_1cent() {
  reset_state() if $ALWAYS_RESET;

  my $item    = new_item(qty => 2.5);
  my $invoice = new_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item ],
    payment_id   => $payment_terms->id,
  );
  $invoice->post;

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

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice->transactions);
  my $total = total_amount($invoice->transactions);

  my $title = 'default invoice, one item, 19% tax, without_skonto';

  is($invoice->netamount,       5.85,     "${title}: netamount");
  is($invoice->amount,          6.96,     "${title}: amount");
  is($paid_amount,             -6.96,     "${title}: paid amount");
  is($number_of_payments,          2,     "${title}: 3 AR_paid booking");
  is($invoice->paid,            6.96,     "${title}: paid");
  is($total,                       0,     "${title}: even balance");

}

# test 3 : two items, without skonto
sub test_default_purchase_invoice_two_charts_19_7_without_skonto() {
  reset_state() if $ALWAYS_RESET;

  my $purchase_invoice = new_purchase_invoice();

  my %params = ( chart_id => $bank_account->chart_id,
                 transdate => DateTime->today_local->to_kivitendo
               );

  $params{amount} = '226'; # pass full amount
  $params{payment_type} = 'without_skonto';

  $purchase_invoice->pay_invoice( %params );

  my ($number_of_payments, $paid_amount) = number_of_payments($purchase_invoice->transactions);
  my $total = total_amount($purchase_invoice->transactions);

  my $title = 'default invoice, two items, 19/7% tax without skonto';

  is($paid_amount,         226,     "${title}: paid amount");
  is($number_of_payments,    1,     "${title}: 1 AP_paid bookings");
  is($total,                 0,     "${title}: even balance");

}

sub test_default_purchase_invoice_two_charts_19_7_with_skonto() {
  reset_state() if $ALWAYS_RESET;

  my $purchase_invoice = new_purchase_invoice();

  my %params = ( chart_id => $bank_account->chart_id,
                 transdate => DateTime->today_local->to_kivitendo
               );

  # $params{amount} = '226'; # pass full amount
  $params{payment_type} = 'with_skonto_pt';

  $purchase_invoice->pay_invoice( %params );

  my ($number_of_payments, $paid_amount) = number_of_payments($purchase_invoice->transactions);
  my $total = total_amount($purchase_invoice->transactions);

  my $title = 'default invoice, two items, 19/7% tax without skonto';

  is($paid_amount,         226,     "${title}: paid amount");
  is($number_of_payments,    3,     "${title}: 1 AP_paid bookings");
  is($total,                 0,     "${title}: even balance");

}

sub test_default_purchase_invoice_two_charts_19_7_tax_partial_unrounded_payment_without_skonto() {
  # check whether unrounded amounts passed via $params{amount} are rounded for without_skonto case
  reset_state() if $ALWAYS_RESET;
  my $purchase_invoice = new_purchase_invoice();
  $purchase_invoice->pay_invoice(
                          amount       => ( $purchase_invoice->amount / 3 * 2),
                          payment_type => 'without_skonto',
                          chart_id     => $bank_account->chart_id,
                          transdate    => DateTime->today_local->to_kivitendo
                         );
  my ($number_of_payments, $paid_amount) = number_of_payments($purchase_invoice->transactions);
  my $total = total_amount($purchase_invoice->transactions);

  my $title = 'default purchase_invoice, two charts, 19/7% tax multiple payments with final difference as skonto';

  is($paid_amount,         150.67,   "${title}: paid amount");
  is($number_of_payments,       1,   "${title}: 1 AP_paid bookings");
  is($total,                    0,   "${title}: even balance");
};


sub test_default_purchase_invoice_two_charts_19_7_tax_without_skonto_multiple_payments_final_difference_as_skonto() {
  reset_state() if $ALWAYS_RESET;

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

  my ($number_of_payments, $paid_amount) = number_of_payments($purchase_invoice->transactions);
  my $total = total_amount($purchase_invoice->transactions);

  my $title = 'default purchase_invoice, two charts, 19/7% tax multiple payments with final difference as skonto';

  is($paid_amount,         226, "${title}: paid amount");
  is($number_of_payments,    4, "${title}: 1 AP_paid bookings");
  is($total,                 0, "${title}: even balance");

}

# test
sub test_default_invoice_two_items_19_7_tax_with_skonto_50_50() {
  reset_state() if $ALWAYS_RESET;

  my $item1   = new_item(qty => 1, part => $parts[2]);
  my $item2   = new_item(qty => 1, part => $parts[3]);
  my $invoice = new_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item1, $item2 ],
    payment_id  => $payment_terms->id,
  );
  $invoice->post;

  # default values
  my %params = ( chart_id => $bank_account->chart_id,
                 transdate => DateTime->today_local->to_kivitendo
               );

  $params{amount} = $invoice->amount_less_skonto;
  $params{payment_type} = 'with_skonto_pt';

  $invoice->pay_invoice( %params );

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice->transactions);
  my $total = total_amount($invoice->transactions);

  my $title = 'default invoice, two items, 19/7% tax with_skonto_pt 50/50';

  is($invoice->netamount,        100,     "${title}: netamount");
  is($invoice->amount,           113,     "${title}: amount");
  is($paid_amount,              -113,     "${title}: paid amount");
  is($invoice->paid,             113,     "${title}: paid");
  is($number_of_payments,          3,     "${title}: 3 AR_paid bookings");
  is($total,                       0,     "${title}: even balance");
}

# test
sub test_default_invoice_four_items_19_7_tax_with_skonto_4x_25() {
  reset_state() if $ALWAYS_RESET;

  my $item1   = new_item(qty => 0.5, part => $parts[2]);
  my $item2   = new_item(qty => 0.5, part => $parts[3]);
  my $item3   = new_item(qty => 0.5, part => $parts[2]);
  my $item4   = new_item(qty => 0.5, part => $parts[3]);
  my $invoice = new_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item1, $item2, $item3, $item4 ],
    payment_id  => $payment_terms->id,
  );
  $invoice->post;

  # default values
  my %params = ( chart_id => $bank_account->chart_id,
                 transdate => DateTime->today_local->to_kivitendo
               );

  $params{amount} = $invoice->amount_less_skonto;
  $params{payment_type} = 'with_skonto_pt';

  $invoice->pay_invoice( %params );

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice->transactions);
  my $total = total_amount($invoice->transactions);

  my $title = 'default invoice, four items, 19/7% tax with_skonto_pt 4x25';

  is($invoice->netamount , 100  , "${title}: netamount");
  is($invoice->amount    , 113  , "${title}: amount");
  is($paid_amount        , -113 , "${title}: paid amount");
  is($invoice->paid      , 113  , "${title}: paid");
  is($number_of_payments , 3    , "${title}: 3 AR_paid bookings");
  is($total              , 0    , "${title}: even balance");
}

sub test_default_invoice_four_items_19_7_tax_with_skonto_4x_25_tax_included() {
  reset_state() if $ALWAYS_RESET;

  my $item1   = new_item(qty => 0.5, part => $parts[2]);
  my $item2   = new_item(qty => 0.5, part => $parts[3]);
  my $item3   = new_item(qty => 0.5, part => $parts[2]);
  my $item4   = new_item(qty => 0.5, part => $parts[3]);
  my $invoice = new_invoice(
    taxincluded  => 1,
    invoiceitems => [ $item1, $item2, $item3, $item4 ],
    payment_id  => $payment_terms->id,
  );
  $invoice->post;

  # default values
  my %params = ( chart_id => $bank_account->chart_id,
                 transdate => DateTime->today_local->to_kivitendo
               );

  $params{amount} = $invoice->amount_less_skonto;
  $params{payment_type} = 'with_skonto_pt';

  $invoice->pay_invoice( %params );

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice->transactions);
  my $total = total_amount($invoice->transactions);

  my $title = 'default invoice, four items, 19/7% tax with_skonto_pt 4x25';

  is($invoice->netamount,   88.75,    "${title}: netamount");
  is($invoice->amount,        100,    "${title}: amount");
  is($paid_amount,           -100,    "${title}: paid amount");
  is($invoice->paid,          100,    "${title}: paid");
  is($number_of_payments,       3,    "${title}: 3 AR_paid bookings");
# currently this test fails because the code writing the invoice is buggy, the calculation of skonto is correct
  is($total,                    0,    "${title}: even balance: this will fail due to rounding error in invoice post, not the skonto");
}

sub test_default_invoice_four_items_19_7_tax_with_skonto_4x_25_multiple() {
  reset_state() if $ALWAYS_RESET;

  my $item1   = new_item(qty => 0.5, part => $parts[2]);
  my $item2   = new_item(qty => 0.5, part => $parts[3]);
  my $item3   = new_item(qty => 0.5, part => $parts[2]);
  my $item4   = new_item(qty => 0.5, part => $parts[3]);
  my $invoice = new_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item1, $item2, $item3, $item4 ],
    payment_id  => $payment_terms->id,
  );
  $invoice->post;

  $invoice->pay_invoice( amount       => '90',
                         payment_type => 'without_skonto',
                         chart_id     => $bank_account->chart_id,
                         transdate => DateTime->today_local->to_kivitendo
                       );
  $invoice->pay_invoice( payment_type => 'difference_as_skonto',
                         chart_id     => $bank_account->chart_id,
                         transdate    => DateTime->today_local->to_kivitendo
                       );

  my ($number_of_payments, $paid_amount) = number_of_payments($invoice->transactions);
  my $total = total_amount($invoice->transactions);

  my $title = 'default invoice, four items, 19/7% tax with_skonto_pt 4x25';

  is($invoice->netamount,  100,     "${title}: netamount");
  is($invoice->amount,     113,     "${title}: amount");
  is($paid_amount,        -113,     "${title}: paid amount");
  is($invoice->paid,       113,     "${title}: paid");
  is($number_of_payments,    3,     "${title}: 3 AR_paid bookings");
  is($total,                 0,     "${title}: even balance: this will fail due to rounding error in invoice post, not the skonto");
}

Support::TestSetup::login();
 # die;

# test cases: without_skonto
 test_default_invoice_one_item_19_without_skonto();
 test_default_invoice_two_items_19_7_tax_with_skonto();
 test_default_invoice_two_items_19_7_without_skonto();
 test_default_invoice_two_items_19_7_without_skonto_incomplete_payment();
 test_default_invoice_two_items_19_7_tax_without_skonto_multiple_payments();
 test_default_purchase_invoice_two_charts_19_7_without_skonto();
 test_default_purchase_invoice_two_charts_19_7_tax_partial_unrounded_payment_without_skonto();
 test_default_invoice_one_item_19_without_skonto_overpaid();

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

# remove all created data at end of test
clear_up();

done_testing();

1;
