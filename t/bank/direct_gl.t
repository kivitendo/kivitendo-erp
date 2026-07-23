use Test::More tests => 34;

use strict;

use lib 't';
use utf8;

use Carp;
use Support::TestSetup;
use Test::Exception;

# backend classes for reset state

use SL::DB::AccTransaction;
use SL::DB::BankTransactionAccTrans;
use SL::DB::Currency;
use SL::DB::Customer;
use SL::DB::Default;
use SL::DB::GLTransaction;
use SL::DB::Vendor;
use SL::DB::BankAccount;
use SL::DB::BankTransaction;




Support::TestSetup::login();
our $dt              = DateTime->new(year => 2026, month =>  2, day => 22, hour => 0, minute =>  0),
our $ar_chart        = SL::DB::Manager::Chart->find_by( accno => '1400' ); # Forderungen
our $ap_chart        = SL::DB::Manager::Chart->find_by( accno => '1600' ); # Verbindlichkeiten
our $bank            = SL::DB::Manager::Chart->find_by( accno => '1200' ); # Bank
our $ar_amount_chart = SL::DB::Manager::Chart->find_by( accno => '8400' ); # Erlöse
our $ap_amount_chart = SL::DB::Manager::Chart->find_by( accno => '3400' ); # Wareneingang 19%
our $ap_amount_fremd = SL::DB::Manager::Chart->find_by( accno => '3100' ); # Fremdleistung 19%
our $transit_chart   = SL::DB::Manager::Chart->find_by(id => SL::DB::Default->get->transit_items_chart_id);
our $currency_id     = $::instance_conf->get_currency_id;
our $bank_account     =  SL::DB::BankAccount->new(
    account_number  => '123',
    bank_code       => '123',
    iban            => '123IBAN',
    bic             => '123BIC',
    bank            => '123',
    chart_id        => SL::DB::Manager::Chart->find_by(description => 'Bank')->id,
    name            => SL::DB::Manager::Chart->find_by(description => 'Bank')->description,
  )->save;


test_bank_transaction_direct_gl();

clear_up();


sub clear_up {

  SL::DB::Manager::BankTransactionAccTrans->delete_all(all => 1);
  SL::DB::Manager::BankTransaction->delete_all(all => 1);
  SL::DB::Manager::GLTransaction->delete_all(all => 1);
  SL::DB::Manager::BankAccount->delete_all(all => 1);
  SL::DB::Manager::Vendor->delete_all(all => 1);
  SL::DB::Manager::PaymentTerm->delete_all(all => 1);
  SL::DB::Manager::Exchangerate->delete_all(all => 1);
  SL::DB::Manager::Currency->delete_all(where => [ name => 'CUR' ]);
  SL::DB::Manager::Currency->delete_all(where => [ name => 'USD' ]);
}

sub test_bank_transaction_direct_gl {

  use SL::Controller::BankImport;
  my $bank_import =  SL::Controller::BankImport->new();

  # 1. create one transaction manually (MT940 or CAMT.053)
  my @transactions = SL::Camt053->parse_file('t/bank/direct-booking-camt053');

  is scalar(@transactions), 1;

  is $transactions[0]{line_number},           1;
  is $transactions[0]{currency},              'EUR';
  is $transactions[0]{transdate},             $dt;
  is $transactions[0]{valutadate},            $dt;
  is $transactions[0]{amount},                '-184208.24';
  is $transactions[0]{reference},             'INNDNL2U20141231000142300002844';
  is $transactions[0]{local_bank_code},       '123';
  is $transactions[0]{local_account_number},  '123';
  is $transactions[0]{end_to_end_id},         'KIVITENDO2711';
  is $transactions[0]{purpose},               "EREF: SEPA 49 foo Ab rechnung 20 a Kassenzeichen: 27IV3a+SVWMx b";
  is $transactions[0]{remote_name},           'INSURANCE COMPANY TESTX';
  is $transactions[0]{remote_bank_code},      '456BIC';
  is $transactions[0]{remote_account_number}, '789IBAN';

  $bank_import->file_name('t/bank/direct-booking-camt053');

  $bank_import->parse_and_analyze_transactions(mode => 'camt053');

  # now we parse this transaction without a configured template
  is($bank_import->statistics->{gl_bookings}, 0);
  is($bank_import->statistics->{to_import}  , 1);

  # 2. create a gl record which can be used for automatic booking
  my $record_template = create_record_template_gl(template_name  => "Gewerbesteuer-Vorauszahlung",
                                                  items => [
                                                             { amount1 => 1, amount2 => 0, chart_id => $transit_chart->id, tax_id => 0 },
                                                             { amount1 => 0, amount2 => 1, chart_id => $bank->id, tax_id => 0          },
                                                           ],
                                                  reference                => "<%reference_date FORMAT=%m im Jahr %Y %> Gewerbesteuer-Vorauszahlung",
                                                  transaction_description  => "<%current_month_long%> <%current_year%> Gewerbesteuer",
                                                  description              => "27IV3a",
                                                  bank_import_template     => 1,
                                                 );

  is (ref $record_template, 'SL::DB::RecordTemplate', "Record Template ref ok");
  is ($record_template->bank_import_template, 1, 'Record Template can be used for Bank Import');

  # 3. now there should be a hit for a automatic booking
  $bank_import->parse_and_analyze_transactions(mode => 'camt053');

  # 3.1 check preview html template
  my $html_preview = $bank_import->render('bank_import/import_camt053', { layout => 0, output => 0 }, title => $::locale->text('Camt.053 import preview'), preview => 1);
  ok ($html_preview =~ /gl\.pl\?action=load_record_template&id=1">.*Gewerbesteuer-Voraus/, "CAMT.053 Preview shows direct booking hit");

  is($bank_import->statistics->{gl_bookings}, 1);
  is($bank_import->statistics->{to_import}  , 1);
  is(ref $bank_import->transactions->[0]->{direct_gl}, 'SL::DB::RecordTemplate');

  # 4. now we do the real import and we expect a gl booking
  $bank_import->import_transactions();

  my $bt = SL::DB::Manager::BankTransaction->get_first;
  my $bt_links = SL::DB::Manager::BankTransactionAccTrans->get_all(where => [ bank_transaction_id => $bt->id ]);
  my $gl_booking = SL::DB::Manager::GLTransaction->find_by(id => $bt_links->[0]->gl_id);
  my $gl_transaction_id = $gl_booking->id;

  # 4.1 check ok html template
  my $html_ok = $bank_import->render('bank_import/import_camt053', { layout => 0, output => 0 }, title => $::locale->text('Camt.053 import result'));
  ok($html_ok =~ />Dialogbuchung i.O./, "Return direct booking ok");
  ok($html_ok =~ /<a href="gl\.pl\?action=edit&id=$gl_transaction_id">&lt;%reference_date FORMAT=%m im Jahr %Y %&gt; Gewerbesteuer-Vorauszahlu/, "Link to booking ok");

  is($bt->amount, '-184208.24000' , 'BankTransaction Created');
  is($bt->invoice_amount, '-184208.24000', 'BankTransaction Amount assigned');


  # 5. check gl booking
  is(scalar @{ $bt->linked_invoices }, 1, 'One linked GL Booking for this Bank Transaction');


  is (scalar @{ $bt_links }, 2, 'all acc_trans entries for this Bank Transaction created');

  is (ref $gl_booking, 'SL::DB::GLTransaction', 'GL Transaction created');
  is($gl_booking->reference, '02 im Jahr 2026 Gewerbesteuer-Vorauszahlung', 'Variable reference date for reference replaced');
  is($gl_booking->transaction_description, 'Februar 2026 Gewerbesteuer', 'Variable transaction_description replaced');
  is($gl_booking->description, $bt->purpose,  'bank transaction purpose in gl booking description');
  is($gl_booking->transactions->[0]->source, 'Automatische Dialogbuchung', 'Booking amount correct');
  my ($bank_booking) = grep { $_->chart->accno eq '1200' } @{ $gl_booking->transactions };
  is ($bank_booking->amount, '184208.24000', 'Bank booking is debit');
}

sub create_record_template_gl {
  my (%params) = @_;

  die "Need Template Name"      unless $params{template_name};
  die "Need at least two items" unless scalar @{ $params{items} } > 1;

  my $template = SL::DB::RecordTemplate->new;

  $template->assign_attributes(
    template_type  => 'gl_transaction',
    template_name  => $params{template_name},

    currency_id             => $currency_id,
    department_id           => $params{department_id}    || undef,
    project_id              => $params{globalproject_id} || undef,
    taxincluded             => $params{taxincluded}     ? 1 : 0,
    ob_transaction          => $params{ob_transaction}  ? 1 : 0,
    cb_transaction          => $params{cb_transaction}  ? 1 : 0,
    reference               => $params{reference},
    description             => $params{description},
    show_details            => $params{show_details},
    transaction_description => $params{transaction_description},
    bank_import_template    => $params{bank_import_template},

    items          => $params{items},
  );

  $template->save;

  return $template;
}

1;

