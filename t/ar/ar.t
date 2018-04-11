use strict;
use Test::More tests => 6;

use lib 't';
use Support::TestSetup;
use Carp;
use Test::Exception;
use SL::DB::Customer;
use SL::DB::Employee;
use SL::DB::Invoice;
use SL::DATEV qw(:CONSTANTS);
use SL::Dev::CustomerVendor qw(new_customer);
use Data::Dumper;

my ($customer, $employee, $ar_tax_19, $ar_tax_7, $ar_tax_0);
my ($ar_chart, $bank, $ar_amount_chart);
my $config = {};
$config->{numberformat} = '1.000,00';

sub reset_state {
  my %params = @_;

  $params{$_} ||= {} for qw(buchungsgruppe customer);

  clear_up();

  $employee        = SL::DB::Manager::Employee->current                       || croak "No employee";
  $ar_tax_19       = SL::DB::Manager::Tax->find_by(taxkey => 3, rate => 0.19) || croak "No 19% tax";
  $ar_tax_7        = SL::DB::Manager::Tax->find_by(taxkey => 2, rate => 0.07) || croak "No 7% tax";
  $ar_tax_0        = SL::DB::Manager::Tax->find_by(taxkey => 0, rate => 0.00) || croak "No 0% tax";

  $customer = new_customer()->save; # new customer with default name "Testkunde"

  $ar_chart        = SL::DB::Manager::Chart->find_by(accno => '1400') || croak "Can't find Forderungen";
  $bank            = SL::DB::Manager::Chart->find_by(accno => '1200') || croak "Can't find Bank";
  $ar_amount_chart = SL::DB::Manager::Chart->find_by(accno => '8590') || croak "Can't find verrechn., eigentlich Anzahlungen";

};

Support::TestSetup::login();

reset_state();

# check ar without tax
my $invoice = _ar(customer     => $customer,
                  amount       => 100,
                  with_payment => 1,
                  notes        => 'ar without tax',
                 );

# for testing load a fresh instance of the invoice from the database
my $inv = SL::DB::Invoice->new(id => $invoice->id)->load;
if ( $inv ) {
  my $number_of_acc_trans = scalar @{ $inv->transactions };
  is($::form->round_amount($inv->amount) , 100                           , "invoice_amount = 100");
  is($number_of_acc_trans                , 5                             , "number of transactions");
  is($inv->datepaid->to_kivitendo        , DateTime->today->to_kivitendo , "datepaid");
  is($inv->amount - $inv->paid           , 0                             , "paid = amount ");
} else {
  ok 0, "couldn't find first invoice";
}

# check ar with tax
my $invoice2 = _ar_with_tax(customer     => $customer,
                            amount       => 200,
                            with_payment => 1,
                            notes        => 'ar with taxincluded',
                           );
my $inv_with_tax = SL::DB::Invoice->new(id => $invoice2->id)->load;
if ( $inv_with_tax ) {
  is(scalar @{ $inv_with_tax->transactions }, 7,  "number of transactions for inv_with_tax");
} else {
  ok 0, "couldn't find second invoice";
}

# general checks
is(SL::DB::Manager::Invoice->get_all_count(), 2,  "total number of invoices created is 2");

done_testing;
clear_up();

1;

sub clear_up {
  SL::DB::Manager::AccTransaction->delete_all(all => 1);
  SL::DB::Manager::Invoice->delete_all(       all => 1);
  SL::DB::Manager::Customer->delete_all(      all => 1);
};

sub _ar {
  my %params = @_;

  my $amount       = $params{amount}       || croak "ar needs param amount";
  my $customer     = $params{customer}     || croak "ar needs param customer";
  my $date         = $params{date}         || DateTime->today;
  my $with_payment = $params{with_payment} || 0;

  # SL::DB::Invoice has a _before_save_set_invnumber hook, so we don't need to pass invnumber
  my $invoice = SL::DB::Invoice->new(
      invoice          => 0,
      amount           => $amount,
      netamount        => $amount,
      transdate        => $date,
      taxincluded      => 'f',
      customer_id      => $customer->id,
      taxzone_id       => $customer->taxzone_id,
      currency_id      => $customer->currency_id,
      globalproject_id => $params{project},
      notes            => $params{notes},
      transactions     => [],
  );

  my $db = $invoice->db;

  $db->with_transaction( sub {

    $invoice->add_ar_amount_row(
      amount     => $amount / 2,
      chart      => $ar_amount_chart,
      tax_id     => $ar_tax_0->id,
    );
    $invoice->add_ar_amount_row(
      amount     => $amount / 2,
      chart      => $ar_amount_chart,
      tax_id     => $ar_tax_0->id,
    );

    $invoice->create_ar_row( chart => $ar_chart );

    _save_and_pay_and_check(invoice     => $invoice,
                            bank        => $bank,
                            pay         => $with_payment,
                            datev_check => 1,
                           );

    1;

  }) || die "something went wrong: " . $db->error;
  return $invoice;
};

sub _ar_with_tax {
  my %params = @_;

  my $amount       = $params{amount}       || croak "ar needs param amount";
  my $customer     = $params{customer}     || croak "ar needs param customer";
  my $date         = $params{date}         || DateTime->today;
  my $with_payment = $params{with_payment} || 0;

  my $invoice = SL::DB::Invoice->new(
    invoice          => 0,
    amount           => $amount,
    netamount        => $amount,
    transdate        => $date,
    taxincluded      => 'f',
    customer_id      => $customer->id,
    taxzone_id       => $customer->taxzone_id,
    currency_id      => $customer->currency_id,
    globalproject_id => $params{project},
    notes            => $params{notes},
    transactions     => [],
  );

  my $db = $invoice->db;

  $db->with_transaction( sub {

    # TODO: check for currency and exchange rate

    $invoice->add_ar_amount_row(
      amount     => $amount / 2,
      chart      => $ar_amount_chart,
      tax_id     => $ar_tax_19->id,
    );
    $invoice->add_ar_amount_row(
      amount     => $amount / 2,
      chart      => $ar_amount_chart,
      tax_id     => $ar_tax_19->id,
    );

    $invoice->create_ar_row( chart => $ar_chart );
    _save_and_pay_and_check(invoice     => $invoice,
                            bank        => $bank,
                            pay         => $with_payment,
                            datev_check => 1,
                           );

    1;
  }) || die "something went wrong: " . $db->error;
  return $invoice;
};

sub _save_and_pay_and_check {
  my %params = @_;
  my $invoice     = $params{invoice} // croak "invoice missing";
  my $datev_check = $params{datev_check} // 1; # do datev check by default
  croak "no bank" unless ref $params{bank} eq 'SL::DB::Chart';

  # make sure invoice is saved before making payments
  my $return = $invoice->save;

  $invoice->pay_invoice(chart_id     => $params{bank}->id,
                        amount       => $invoice->amount,
                        transdate    => $invoice->transdate->to_kivitendo,
                        payment_type => 'without_skonto',  # default if not specified
                       ) if $params{pay};

  if ($datev_check) {
    my $datev = SL::DATEV->new(
      dbh        => $invoice->db->dbh,
      trans_id   => $invoice->id,
    );

    $datev->generate_datev_data;

    # _save_and_pay_and_check should always be called inside a with_transaction block
    if ($datev->errors) {
      $invoice->db->dbh->rollback;
      die join "\n", $::locale->text('DATEV check returned errors:'), $datev->errors;
    }
  };
};
