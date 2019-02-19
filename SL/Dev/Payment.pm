package SL::Dev::Payment;

use strict;
use base qw(Exporter);
our @EXPORT_OK = qw(create_payment_terms create_bank_account create_bank_transaction create_sepa_export create_sepa_export_item);
our %EXPORT_TAGS = (ALL => \@EXPORT_OK);

use SL::DB::PaymentTerm;
use SL::DB::BankAccount;
use SL::DB::Chart;
use DateTime;

sub create_payment_terms {
  my (%params) = @_;

  my $payment_terms =  SL::DB::PaymentTerm->new(
    description      => 'payment',
    description_long => 'payment',
    terms_netto      => '30',
    terms_skonto     => '5',
    percent_skonto   => '0.05',
    auto_calculation => 1,
  );
  $payment_terms->assign_attributes(%params) if %params;
  $payment_terms->save;
}

sub create_bank_account {
  my (%params) = @_;
  my $bank_account = SL::DB::BankAccount->new(
    iban           => 'DE12500105170648489890',
    account_number => '0648489890',
    bank           => 'Testbank',
    chart_id       => delete $params{chart_id} // $::instance_conf->get_ar_paid_accno_id,
    name           => 'Test bank account',
    bic            => 'BANK1234',
    bank_code      => '50010517'
  );
  $bank_account->assign_attributes(%params) if %params;
  $bank_account->save;
}

sub create_sepa_export {
  my (%params) = @_;
  my $sepa_export = SL::DB::SepaExport->new(
    closed       => 0,
    employee_id  => $params{employee_id} // SL::DB::Manager::Employee->current->id,
    executed     => 0,
    vc           => 'customer',
  );
  $sepa_export->assign_attributes(%params) if %params;
  $sepa_export->save;
}

sub create_sepa_export_item {
  my (%params) = @_;
  my $sepa_exportitem = SL::DB::SepaExportItem->new(
    chart_id     => delete $params{chart_id} // $::instance_conf->get_ar_paid_accno_id,
    payment_type => 'without_skonto',
    our_bic      => 'BANK1234',
    our_iban     => 'DE12500105170648489890',
  );
  $sepa_exportitem->assign_attributes(%params) if %params;
  $sepa_exportitem->save;
}

sub create_bank_transaction {
 my (%params) = @_;

 my $record = delete $params{record};
 die "bank_transactions can only be created for invoices" unless ref($record) eq 'SL::DB::Invoice' or ref($record) eq 'SL::DB::PurchaseInvoice';

 my $multiplier = $record->is_sales ? 1 : -1;
 my $amount = (delete $params{amount} || $record->amount) * $multiplier;

 my $bank_chart;
 if ( $params{bank_chart_id} ) {
   $bank_chart = SL::DB::Manager::Chart->find_by(id => delete $params{bank_chart_id}) or die "Can't find bank chart";
 } elsif ( $::instance_conf->get_ar_paid_accno_id ) {
   $bank_chart   = SL::DB::Manager::Chart->find_by(id => $::instance_conf->get_ar_paid_accno_id);
 } else {
   $bank_chart = SL::DB::Manager::Chart->find_by(description => 'Bank') or die "Can't find bank chart";
 }
 my $bank_account = SL::DB::Manager::BankAccount->find_by( chart_id => $bank_chart->id );
 die "bank account missing" unless $bank_account;

 my $bt = SL::DB::BankTransaction->new(
   local_bank_account_id => $bank_account->id,
   remote_bank_code      => $record->customervendor->bank_code,
   remote_account_number => $record->customervendor->account_number,
   transdate             => DateTime->today,
   valutadate            => DateTime->today,
   amount                => $amount,
   currency              => $record->currency->id,
   remote_name           => $record->customervendor->depositor,
   purpose               => $record->invnumber
 );
 $bt->assign_attributes(%params) if %params;
 $bt->save;
}

1;

__END__

=head1 NAME

SL::Dev::Payment - create objects for payment-related testing, with minimal defaults

=head1 FUNCTIONS

=head2 C<create_payment_terms %PARAMS>

Create payment terms.

Minimal example with default values (30days, 5% skonto within 5 days):
  my $payment_terms = SL::Dev::Payment::create_payment_terms;

=head2 C<create_bank_account %PARAMS>

Required params: chart_id

Example:
  my $bank_account = SL::Dev::Payment::create_bank_account(chart_id => SL::DB::Manager::Chart->find_by(description => 'Bank')->id);

=head2 C<create_bank_transaction %PARAMS>

Create a bank transaction that matches an existing invoice record, e.g. to be able to
test the point system.

Required params: record  (an SL::DB::Invoice or SL::DB::PurchaseInvoice object)

Optional params: bank_chart_id : the chart id of a configured bank account
                 amount        : the amount of the bank transaction

If no bank_chart_id is given, it tries to find a chart via defaults
(ar_paid_accno_id) or by searching for the chart named "Bank". The chart must
be connected to an existing BankAccount.

Param amount should always be relative to the absolute amount of the invoice, i.e. use positive
values for sales and purchases.

Example:
  my $payment_terms = SL::Dev::Payment::create_payment_terms;
  my $bank_chart    = SL::DB::Manager::Chart->find_by(description => 'Bank');
  my $bank_account  = SL::Dev::Payment::create_bank_account(chart_id => $bank_chart->id);
  my $customer      = SL::Dev::CustomerVendor::create_customer(iban           => 'DE12500105170648489890',
                                                               bank_code      => 'abc',
                                                               account_number => '44444',
                                                               bank           => 'Testbank',
                                                               bic            => 'foobar',
                                                               depositor      => 'Name')->save;
  my $sales_invoice = SL::Dev::Record::create_sales_invoice(customer      => $customer,
                                                            payment_terms => $payment_terms,
                                                           );
  my $bt            = SL::Dev::Payment::create_bank_transaction(record        => $sales_invoice,
                                                                amount        => $sales_invoice->amount_less_skonto,
                                                                transdate     => DateTime->today->add(days => 10),
                                                                bank_chart_id => $bank_chart->id
                                                               );
  my ($agreement, $rule_matches) = $bt->get_agreement_with_invoice($sales_invoice);
  # 14, 'remote_account_number(3) skonto_exact_amount(5) cust_vend_number_in_purpose(1) depositor_matches(2) payment_within_30_days(1) datebonus14(2)'

To create a payment for 3 invoices that were all paid together, all with skonto:
  my $ar1 = SL::DB::Manager::Invoice->find_by(invnumber=>'20');
  my $ar2 = SL::DB::Manager::Invoice->find_by(invnumber=>'21');
  my $ar3 = SL::DB::Manager::Invoice->find_by(invnumber=>'22');
  SL::Dev::Payment::create_bank_transaction(record  => $ar1
                                            amount  => ($ar1->amount_less_skonto + $ar2->amount_less_skonto + $ar2->amount_less_skonto),
                                            purpose => 'Rechnungen 20, 21, 22',
                                           );

=head1 TODO

Nothing here yet.

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

G. Richardson E<lt>grichardson@kivitendo-premium.deE<gt>

=cut
