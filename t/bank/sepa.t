use Test::More tests => 28;

use strict;

use lib 't';
use utf8;

use Carp;
use Support::TestSetup;
use Test::Exception;

use SL::SEPA;
use SL::Dev::CustomerVendor qw(new_customer new_vendor);
use SL::Dev::Part qw(new_part);
use SL::Dev::Payment qw(create_payment_terms);
use SL::Dev::Record qw(create_ar_transaction create_ap_transaction create_gl_transaction);

# backend classes for reset state

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




Support::TestSetup::login();
our $payment_skonto2 = create_payment_terms(description => '2 % Skonto 7 Tage', percent_skonto => '0.02', terms_skonto => 7, terms_netto => 30);
our $payment_skonto4 = create_payment_terms(description => '4 % Skonto 20 Tage', percent_skonto => '0.04', terms_skonto => 20, terms_netto => 90);
our $vendor          = new_vendor(  name => 'Skonto Lieferant',   payment_id => $payment_skonto2->id, bic => '123', iban => '123' )->save;
our $tax_9           = SL::DB::Manager::Tax->find_by(taxkey => 9, rate => 0.19) || croak "No tax for 19\%";
our $dt              = DateTime->new(year => 2025, month =>  4, day => 7, hour => 10, minute =>  0),
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
    iban            => '123',
    bic             => '123',
    bank            => '123',
    chart_id        => SL::DB::Manager::Chart->find_by(description => 'Bank')->id,
    name            => SL::DB::Manager::Chart->find_by(description => 'Bank')->description,
  )->save;


our $VISUAL_TEST  = 0;

test_sepa_combined_skonto_and_credit_note();
clear_up();

sub clear_up {

  SL::DB::Manager::BankTransactionAccTrans->delete_all(all => 1);
  SL::DB::Manager::BankTransaction->delete_all(all => 1);
  SL::DB::Manager::SepaExportsAccTrans->delete_all(all => 1);
  SL::DB::Manager::GLTransaction->delete_all(all => 1);
  SL::DB::Manager::InvoiceItem->delete_all(all => 1);
  SL::DB::Manager::InvoiceItem->delete_all(all => 1);
  SL::DB::Manager::Invoice->delete_all(all => 1);
  SL::DB::Manager::PurchaseInvoice->delete_all(all => 1);
  SL::DB::Manager::Part->delete_all(all => 1);
  SL::DB::Manager::Customer->delete_all(all => 1);
  SL::DB::Manager::SepaExportItem->delete_all(all => 1);
  SL::DB::Manager::SepaExport->delete_all(all => 1);
  SL::DB::Manager::BankAccount->delete_all(all => 1);
  SL::DB::Manager::Vendor->delete_all(all => 1);
  SL::DB::Manager::PaymentTerm->delete_all(all => 1);
  SL::DB::Manager::Exchangerate->delete_all(all => 1);
  SL::DB::Manager::Currency->delete_all(where => [ name => 'CUR' ]);
  SL::DB::Manager::Currency->delete_all(where => [ name => 'USD' ]);
}

sub test_sepa_combined_skonto_and_credit_note {

  my $invoice12skonto_1   = create_ap_transaction_local(netamount => -10.08, invnumber => '12skonto-1', pt_id => $payment_skonto2->id);

  is(ref $invoice12skonto_1     , 'SL::DB::PurchaseInvoice', "Purchase Invoice has been created");
  is($invoice12skonto_1->amount , -12                      , "ap amount has been converted");

  my $currency_usd = SL::DB::Currency->new(name => 'USD')->save;

  my $invoice1234_2   = create_ap_transaction_local(netamount => 154000, invnumber => '1234-2', currency_id => $currency_usd->id, exchangerate => 2.2);
  is($invoice1234_2->amount     , 183260 , "ap amount has been converted");

  my $invoice12a44f_2 = create_ap_transaction_local(netamount => 840.34, invnumber => '12a44f-2', pt_id => $payment_skonto4->id);
  is($invoice12a44f_2->amount   , 1000   , "ap amount has been converted");


  # create SEPA combined export

  my (@bank_transfers, @collective_bank_transfers);

  @bank_transfers = (
          {
            'chart_id' => 12,
            'collected_payment' => '1',
            'skonto_amount' => undef,
            'recommended_execution_date' => undef,
            'vcname' => 'Skonto Lieferant',
            'amount_less_skonto' => undef,
            'vc_id' => '1121',
            'our_bic' => '123',
            'vc_iban' => '123',
            'open_amount' => '183260.00000',
            'pt_description' => undef,
            'invoice' => 0,
            'our_iban' => '123',
            'direct_debit' => 0,
            'vc_bank_info_ok' => 1,
            'amount' => 183260,
            'vc_vc_id' => undef,
            'invnumber' => '1234-2',
            'is_sepa_blocked' => 0,
            'skonto_date' => undef,
            'ap_id' => '2',
            'transfer_amount' => '0',
            'duedate' => undef,
            'payment_type' => 'without_skonto',
            'language_id' => undef,
            'invoice_amount' => '183260.00000',
            'percent_skonto' => undef,
            'transdate' => '07.04.2025',
            'within_skonto_period' => undef,
            'id' => 2,
            'vc_bic' => '123',
            'selected' => '1',
            'reference' => 'Rechnung 1234-2',
            'payment_select_options' => [
                                          {
                                            'payment_type' => 'without_skonto',
                                            'display' => bless( {
                                                                  'args' => [],
                                                                  'untranslated' => 'without skonto'
                                                                }, 'SL::Locale::String' ),
                                            'selected' => 1
                                          }
                                        ]
          },
          {
            'amount' => 960,
            'invnumber' => '12a44f-2',
            'vc_vc_id' => undef,
            'skonto_date' => '27.04.2025',
            'ap_id' => '3',
            'is_sepa_blocked' => 0,
            'transfer_amount' => '0',
            'duedate' => undef,
            'invoice_amount' => '1000.00000',
            'payment_type' => 'with_skonto_pt',
            'language_id' => undef,
            'percent_skonto' => '3.99999991059303',
            'within_skonto_period' => 1,
            'transdate' => '07.04.2025',
            'open_amount_less_skonto' => '960',
            'reference' => 'Rechnung 12a44f-2',
            'vc_bic' => '123',
            'payment_select_options' => [
                                          {
                                            'payment_type' => 'without_skonto',
                                            'display' => bless( {
                                                                  'args' => [],
                                                                  'untranslated' => 'without skonto'
                                                                }, 'SL::Locale::String' ),
                                            'selected' => 0
                                          },
                                          {
                                            'display' => bless( {
                                                                  'untranslated' => 'with skonto acc. to pt',
                                                                  'args' => []
                                                                }, 'SL::Locale::String' ),
                                            'payment_type' => 'with_skonto_pt',
                                            'selected' => 1
                                          }
                                        ],
            'selected' => '1',
            'id' => 3,
            'collected_payment' => '1',
            'chart_id' => 12,
            'skonto_amount' => '39.9999991059303',
            'recommended_execution_date' => undef,
            'amount_less_skonto' => '960.00000089407',
            'vcname' => 'Skonto Lieferant',
            'our_iban' => '123',
            'direct_debit' => 0,
            'invoice' => 0,
            'our_bic' => '123',
            'pt_description' => '4 % Skonto 20 Tage',
            'vc_iban' => '123',
            'vc_id' => '1121',
            'open_amount' => '1000.00000',
            'vc_bank_info_ok' => 1
          },
          {
            'skonto_amount' => '-0.239999994635582',
            'collected_payment' => '1',
            'chart_id' => 12,
            'vc_bank_info_ok' => 1,
            'our_iban' => '123',
            'direct_debit' => 0,
            'invoice' => 0,
            'vc_iban' => '123',
            'our_bic' => '123',
            'vc_id' => '1121',
            'pt_description' => '2 % Skonto 7 Tage',
            'open_amount' => '-12.00000',
            'amount_less_skonto' => '-11.7600000053644',
            'vcname' => 'Skonto Lieferant',
            'recommended_execution_date' => undef,
            'duedate' => undef,
            'transfer_amount' => '0',
            'skonto_date' => '14.04.2025',
            'ap_id' => '1',
            'is_sepa_blocked' => 0,
            'invnumber' => '12skonto-1',
            'vc_vc_id' => undef,
            'amount' => '-11.76',
            'reference' => 'Gutschrift 12skonto-1',
            'vc_bic' => '123',
            'payment_select_options' => [
                                          {
                                            'payment_type' => 'without_skonto',
                                            'display' => bless( {
                                                                  'untranslated' => 'without skonto',
                                                                  'args' => []
                                                                }, 'SL::Locale::String' ),
                                            'selected' => 0
                                          },
                                          {
                                            'display' => bless( {
                                                                  'args' => [],
                                                                  'untranslated' => 'with skonto acc. to pt'
                                                                }, 'SL::Locale::String' ),
                                            'payment_type' => 'with_skonto_pt',
                                            'selected' => 1
                                          }
                                        ],
            'selected' => '1',
            'id' => 1,
            'within_skonto_period' => 1,
            'transdate' => '07.04.2025',
            'open_amount_less_skonto' => '-11.76',
            'percent_skonto' => '1.99999995529652',
            'credit_note' => 1,
            'invoice_amount' => '-12.00000',
            'language_id' => undef,
            'payment_type' => 'with_skonto_pt'
          }
        );

  @collective_bank_transfers = ({
          'vc_iban' => '123',
          'requested_execution_date' => '',
          'chart_id' => 12,
          'vc_bic' => '123',
          'amount' => '184208.24',
          'our_iban' => '123',
          'our_bic' => '123',
          'vc_id' => '1121',
          'reference' => '1234-2 / 12a44f-2 / 12skonto-1',
          'payment_type' => 'mixed',
        });

  my $sepa_id = SL::SEPA->create_export('employee'       => $::myconfig{login},
                                        'bank_transfers' => \@bank_transfers,
                                        'collective_bank_transfers' => \@collective_bank_transfers,
                                        'vc'             => 'vendor');

  # 1. automagic credit note subtracted
  # 1.1  credit_note is already paid
  $invoice12skonto_1->load();
  is($invoice12skonto_1->paid      , '-12.00000'       , "credit note is paid");
  # 1.2 and witht skonto amount 2%
  is($invoice12skonto_1->booked_skonto_amount , -0.24  , "skonto is deducted");

  # 1.3 tax corrected check for record link and skonto corrections
  my $rl_skonto = SL::DB::Manager::RecordLink->get_all(where => [ from_id => $invoice12skonto_1->id, from_table => 'ap', to_table => 'gl' ]);
  is (ref $rl_skonto->[0], 'SL::DB::RecordLink', "record link skonto gl created");
  my $acc_trans_skonto = SL::DB::Manager::AccTransaction->get_all(where => [trans_id => $rl_skonto->[0]->to_id]);
  foreach my $entry (@{ $acc_trans_skonto }) {
    if ($entry->chart_link =~ m/tax/) {
      is($entry->amount, '-0.04000');
    } elsif ($entry->chart_link =~ m/AP_paid/) {
      is($entry->amount, '0.04000');
    } else {
      fail("invalid chart link state");
    }
  }

  # 2. and subtracted from one purchase invoice
  $invoice1234_2->load();
  is($invoice1234_2->paid      , '11.76000' , "is partial paid");

  my $acc_trans_transit = [ grep { $_->chart_id == SL::DB::Default->get->transit_items_chart_id } $invoice1234_2->transactions ];
  is($acc_trans_transit->[0]->amount, '11.76000', "booked correct on transit_chart");

  # 3. check sepa export items - different attributes

  my $sepa_export_item_mixed = SL::DB::Manager::SepaExportItem->get_all(where => [sepa_export_id => 1, payment_type => 'mixed', amount => 184208.24,is_combined_payment => 't']);
  is (ref $sepa_export_item_mixed->[0], 'SL::DB::SepaExportItem', 'mixed SEPA Export Item created');
  is (scalar @$sepa_export_item_mixed, 1, 'One exact match');

  my $sepa_export_item_c1 = SL::DB::Manager::SepaExportItem->get_all(where => [sepa_export_id => 1, payment_type => 'with_skonto_pt', amount => 960 , is_combined_payment => 'f', collected_payment => 't']);
  is (ref $sepa_export_item_c1->[0], 'SL::DB::SepaExportItem', 'c1 SEPA Export Item created');
  is (scalar @$sepa_export_item_c1, 1, 'One exact match');

  my $sepa_export_item_c2 = SL::DB::Manager::SepaExportItem->get_all(where => [sepa_export_id => 1, payment_type => 'with_skonto_pt', amount => -11.76 , is_combined_payment => 'f', collected_payment => 't']);
  is (ref $sepa_export_item_c2->[0], 'SL::DB::SepaExportItem', 'c2 SEPA Export Item created');
  is (scalar @$sepa_export_item_c2, 1, 'One exact match');

  my $sepa_export_item_c3 = SL::DB::Manager::SepaExportItem->get_all(where => [sepa_export_id => 1, payment_type => 'without_skonto', amount => 183260 , is_combined_payment => 'f', collected_payment => 't']);
  is (ref $sepa_export_item_c3->[0], 'SL::DB::SepaExportItem', 'c3 SEPA Export Item created');
  is (scalar @$sepa_export_item_c3, 1, 'One exact match');


  # 4. check import MT940 routines

  use SL::Controller::BankImport;
  my $transaction;
  $transaction->{amount}        = -184208.24;
  $transaction->{end_to_end_id} = $sepa_export_item_mixed->[0]->end_to_end_id;

  my $sei = SL::Controller::BankImport->_check_sepa_automatic(transaction => $transaction);
  is(ref $sei , 'SL::DB::SepaExportItem', '_check_sepa_automatic ok');

  my $bt = create_bt_local(amount => $transaction->{amount}, end_to_end_id => $transaction->{end_to_end_id}, purpose => $sepa_export_item_mixed->[0]->reference);


  is(SL::Controller::BankImport->_book_sepa(sei => $sei, bt => $bt),undef ,'_book_sepa ok');

  $bt->load;

  is($bt->invoice_amount, '-184208.24000', 'BankTransaction Amount assigned');
  is(scalar @{ $bt->linked_invoices }, 2, 'Two linked Invoices for this Bank Transaction');


  $invoice1234_2->load();
  is($invoice1234_2->paid      , $invoice1234_2->amount , "invoice1234_2 is fully paid");

  $invoice12a44f_2->load();
  is($invoice12a44f_2->paid    , $invoice12a44f_2->amount , "invoice12a44f_2 is fully paid");

  my $bt_links = SL::DB::Manager::BankTransactionAccTrans->get_all(where => [ bank_transaction_id => $bt->id ]);
  is (scalar @{ $bt_links }, 4, 'all acc_trans entries for this Bank Transaction created');

  # state of sepa export (items)

  $sei->load;

  is($sei->executed, 1, 'state of sepa export item executed');
  is($sei->sepa_export->load()->closed, 1, 'state of sepa export is closed');

  sleep(500) if $VISUAL_TEST;
}

sub create_ap_transaction_local {
  my (%params) = @_;

  die "Need netamount and invnumber as params! " unless $params{netamount} && $params{invnumber};

  my $netamount        = $params{netamount};
  my $amount           = $::form->round_amount($netamount * 1.19,2);
  my $vendor_local     = $params{vendor} || $vendor;
  my $payment_terms_id = $params{pt_id} || undef;
  my $currency_id      = $params{currency_id}  || $::instance_conf->get_currency_id;
  my $exchangerate     = $params{exchangerate} || undef;

  my $invoice   = SL::DB::PurchaseInvoice->new(
    invoice      => 0,
    invnumber    => $params{invnumber},
    amount       => $amount,
    netamount    => $netamount,
    transdate    => $dt,
    taxincluded  => 0,
    vendor_id    => $vendor->id,
    taxzone_id   => $vendor->taxzone_id,
    transactions => [],
    currency_id  => $currency_id,
    exchangerate => $exchangerate,
    notes        => '12skonto-1',
    payment_id   => $payment_terms_id,
  );
  $invoice->add_ap_amount_row(
    amount     => $invoice->netamount,
    chart      => $ap_amount_fremd,
    tax_id     => $tax_9->id,
  );

  $invoice->create_ap_row(chart => $ap_chart);
  $invoice->save;

}

sub create_bt_local {
  my (%params) = @_;

  die "Need amount and Purpose" unless $params{amount} && $params{purpose};
  die "Need End To End ID"      unless $params{end_to_end_id};

  my $bt = SL::DB::BankTransaction->new(
    local_bank_account_id => $bank_account->id,
    remote_bank_code      => $vendor->bank_code,
    remote_account_number => $vendor->account_number,
    transdate             => DateTime->today,
    valutadate            => DateTime->today,
    amount                => $params{amount},
    currency              => $currency_id,
    remote_name           => $vendor->depositor,
    purpose               => $params{purpose},
    end_to_end_id         => $params{end_to_end_id},
  );

  $bt->save;

  return $bt;
}

1;
