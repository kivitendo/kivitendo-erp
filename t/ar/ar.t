use strict;
use Test::More;

use lib 't';
use Support::TestSetup;
use Carp;
use Test::Exception;
use SL::DB::TaxZone;
use SL::DB::Buchungsgruppe;
use SL::DB::Currency;
use SL::DB::Customer;
use SL::DB::Employee;
use SL::DB::Invoice;
use SL::DATEV qw(:CONSTANTS);
use Data::Dumper;


my ($i, $customer, $vendor, $currency_id, @parts, $buchungsgruppe, $buchungsgruppe7, $unit, $employee, $ar_tax_19, $ar_tax_7,$ar_tax_0, $taxzone);
my ($ar_chart,$bank,$ar_amount_chart);
my $config = {};
$config->{numberformat} = '1.000,00';

sub reset_state {
  my %params = @_;

  $params{$_} ||= {} for qw(buchungsgruppe vendor customer ar_tax_19 ar_tax_7 ar_tax_0 );

  clear_up();

  $employee        = SL::DB::Manager::Employee->current                                                || croak "No employee";
  $taxzone         = SL::DB::Manager::TaxZone->find_by( description => 'Inland')                       || croak "No taxzone"; # only needed for setting customer/vendor
  $ar_tax_19       = SL::DB::Manager::Tax->find_by(taxkey => 3, rate => 0.19, %{ $params{ar_tax_19} }) || croak "No 19% tax";
  $ar_tax_7        = SL::DB::Manager::Tax->find_by(taxkey => 2, rate => 0.07, %{ $params{ar_tax_7} })  || croak "No 7% tax";
  $ar_tax_0        = SL::DB::Manager::Tax->find_by(taxkey => 0, rate => 0.00, %{ $params{ar_tax_0} })  || croak "No 0% tax";
  $currency_id     = $::instance_conf->get_currency_id;

  $customer   = SL::DB::Customer->new(
    name        => 'Test Customer foo',
    currency_id => $currency_id,
    taxzone_id  => $taxzone->id,
  )->save;

  $ar_chart        = SL::DB::Manager::Chart->find_by( accno => '1400' ); # Forderungen
  $bank            = SL::DB::Manager::Chart->find_by( accno => '1200' ); # Bank
  $ar_amount_chart = SL::DB::Manager::Chart->find_by( accno => '8590' ); # verrechn., eigentlich Anzahlungen

};

sub ar {
  reset_state;
  my %params = @_;

  my $amount = $params{amount};
  my $customer = $params{customer};
  my $date = $params{date} || DateTime->today;
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

  my $tax = SL::DB::Manager::Tax->find_by(taxkey => 0, rate => 0);

  $invoice->add_ar_amount_row(
    amount     => $amount / 2,
    chart      => $ar_amount_chart,
    tax_id     => $tax->id,
  );
  $invoice->add_ar_amount_row(
    amount     => $amount / 2,
    chart      => $ar_amount_chart,
    tax_id     => $tax->id,
  );

  $invoice->create_ar_row( chart => $ar_chart );

  _save_and_pay_and_check(invoice => $invoice, bank => $bank, pay => 1, check => 1);

  1;

  }) || die "something went wrong: " . $db->error;
  return $invoice->invnumber;
};

sub ar_with_tax {
  my %params = @_;

  my $amount       = $params{amount};
  my $customer     = $params{customer};
  my $date         = $params{date} || DateTime->today;
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

  my $tax = SL::DB::Manager::Tax->find_by(taxkey => 3, rate => 0.19 );
  my $tax_id = $tax->id or die "can't find tax";

  $invoice->add_ar_amount_row(
    amount     => $amount / 2,
    chart      => $ar_amount_chart,
    tax_id     => $tax_id,
  );
  $invoice->add_ar_amount_row(
    amount     => $amount / 2,
    chart      => $ar_amount_chart,
    tax_id     => $tax_id,
  );

  $invoice->create_ar_row( chart => $ar_chart );
  _save_and_pay_and_check(invoice => $invoice, bank => $bank, pay => 1, check => 1);

  1;
  }) || die "something went wrong: " . $db->error;
  return $invoice->invnumber;
};

Support::TestSetup::login();

reset_state();

# check ar without tax
my $invnumber  = ar(customer => $customer, amount => 100, with_payment => 0 , notes => 'ar without tax');
my $inv = SL::DB::Manager::Invoice->find_by(invnumber => $invnumber);
my $number_of_acc_trans = scalar @{ $inv->transactions };
is($::form->round_amount($inv->amount), 100,  "invoice_amount = 100");
is($number_of_acc_trans, 5,  "number of transactions");
is($inv->datepaid->to_kivitendo, DateTime->today->to_kivitendo,  "datepaid");
is($inv->amount - $inv->paid, 0 ,  "paid = amount ");

# check ar with tax
my $invnumber2 = ar_with_tax(customer => $customer, amount => 200, with_payment => 0, notes => 'ar with taxincluded');
my $inv_with_tax = SL::DB::Manager::Invoice->find_by(invnumber => $invnumber2);
die unless $inv_with_tax;
is(scalar @{ $inv_with_tax->transactions } , 7,  "number of transactions for inv_with_tax");

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

sub _save_and_pay_and_check {
  my %params = @_;
  my $invoice = $params{invoice};
  my $datev_check = 1;

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

    if ($datev->errors) {
      $invoice->db->dbh->rollback;
      die join "\n", $::locale->text('DATEV check returned errors:'), $datev->errors;
    }
  };
};
