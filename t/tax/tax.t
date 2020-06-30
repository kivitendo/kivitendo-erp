use Test::More tests => 48;
use Test::Deep qw(cmp_deeply);

use strict;

use lib 't';
use utf8;

use Support::TestSetup;
use Test::Exception;

use SL::DB::Customer;
use SL::DB::Vendor;
use SL::DB::Invoice;
use SL::DB::GLTransaction;
use SL::DB::AccTransaction;
use SL::DB::Part;
use SL::DB::PaymentTerm;
use SL::DBUtils qw(selectall_hashref_query);
use SL::Dev::Record qw(:ALL);
use SL::Dev::CustomerVendor qw(new_customer new_vendor);
use SL::Dev::Part qw(new_part);
use SL::Dev::Payment qw(create_payment_terms);
use Data::Dumper;

Support::TestSetup::login();
my $dbh = SL::DB->client->dbh;

clear_up();

# TODOs: Storno muß noch korrekt funktionieren
#  neue Konten für 5% anlegen
#  Leistungszeitraum vs. Datum Zuord. Steuerperiodest

note('checking if all tax entries exist for Konjunkturprogramm');

# create dates to test on
my $date_2006   = DateTime->new(year => 2006, month => 6, day => 15);
my $date_2020_1 = DateTime->new(year => 2020, month => 6, day => 15);
my $date_2020_2 = DateTime->new(year => 2020, month => 7, day => 15);
my $date_2021   = DateTime->new(year => 2021, month => 1, day => 15);

# The only way to discern the pre-2007 16% tax from the 2020 16% tax is by
# their configured automatic tax charts, so look them up here:

my ($chart_vst_19, $chart_vst_16, $chart_vst_5, $chart_vst_7);
my ($chart_ust_19, $chart_ust_16, $chart_ust_5, $chart_ust_7);
my ($income_19_accno, $income_7_accno);
my ($ar_accno, $ap_accno);
my ($chart_reisekosten_accno, $chart_cash_accno, $chart_bank_accno);

my ($skonto_5, $skonto_16, $skonto_7, $skonto_19); # store acc_trans entries during tests

my $test_kontenrahmen = $::instance_conf->get_coa eq 'Germany-DATEV-SKR04EU' ? 'skr04' : 'skr03';

if ( $test_kontenrahmen eq 'skr03' ) {

  is(SL::DB::Default->get->coa, 'Germany-DATEV-SKR03EU', "coa SKR03 ok");

  $chart_ust_19 = '1776';
  $chart_ust_16 = '1775';
  $chart_ust_5  = '1773';
  $chart_ust_7  = '1771';

  $chart_vst_19 = '1576';
  $chart_vst_16 = '1575';
  $chart_vst_5  = '1568';
  $chart_vst_7  = '1571';

  $income_19_accno = '8400';
  $income_7_accno  = '8300';

  $chart_reisekosten_accno = 4660;
  $chart_cash_accno        = 1000;
  $chart_bank_accno        = 1200;

  $ar_accno = 1400;
  $ap_accno = 1600;

} elsif ( $test_kontenrahmen eq 'skr04') { # skr04 - test can be ran manually by running t/000setup_database.t with coa for SKR04
  is(SL::DB::Default->get->coa, 'Germany-DATEV-SKR04EU', "coa SKR04 ok");
  $chart_vst_19 = '1406';
  $chart_vst_16 = '1405';
  $chart_vst_5  = '1403';
  $chart_vst_7  = '1401';

  $chart_ust_19 = '3806';
  $chart_ust_16 = '3805';
  $chart_ust_5  = '3803';
  $chart_ust_7  = '3801';

  $income_19_accno = '4400';
  $income_7_accno  = '4300';

  $chart_reisekosten_accno = 6650;
  $chart_cash_accno        = 1600;
  $chart_bank_accno        = 1800;

  $ar_accno = 1200;
  $ap_accno = 3300;
}

my $tax_vst_19 = SL::DB::Manager::Chart->find_by(accno => $chart_vst_19) or die; # 19%
my $tax_vst_16 = SL::DB::Manager::Chart->find_by(accno => $chart_vst_16) or die; # 16%
my $tax_vst_5  = SL::DB::Manager::Chart->find_by(accno => $chart_vst_5 ) or die; #  5%
my $tax_vst_7  = SL::DB::Manager::Chart->find_by(accno => $chart_vst_7 ) or die; #  7%

my $tax_ust_19 = SL::DB::Manager::Chart->find_by(accno => $chart_ust_19) or die; # 19%
my $tax_ust_16 = SL::DB::Manager::Chart->find_by(accno => $chart_ust_16) or die; # 16%
my $tax_ust_5  = SL::DB::Manager::Chart->find_by(accno => $chart_ust_5)  or die; #  5%
my $tax_ust_7  = SL::DB::Manager::Chart->find_by(accno => $chart_ust_7)  or die; #  7%

my $chart_income_19  = SL::DB::Manager::Chart->find_by(accno => $income_19_accno) or die;
my $chart_income_7   = SL::DB::Manager::Chart->find_by(accno => $income_7_accno) or die;

my $chart_reisekosten = SL::DB::Manager::Chart->find_by(accno => $chart_reisekosten_accno) or die;
my $chart_cash        = SL::DB::Manager::Chart->find_by(accno => $chart_cash_accno) or die;
my $chart_bank        = SL::DB::Manager::Chart->find_by(accno => $chart_bank_accno) or die;

my $payment_terms = create_payment_terms();

is(defined SL::DB::Manager::Tax->find_by(taxkey => 2, rate => 0.05), 1, "tax for taxkey 2 with 5% was created ok");
is(defined SL::DB::Manager::Tax->find_by(taxkey => 3, rate => 0.16, chart_id => $tax_ust_16->id), 1, "new sales tax for taxkey 3 with 16% exists ok");
is(defined SL::DB::Manager::Tax->find_by(taxkey => 3, rate => 0.19, chart_id => $tax_ust_19->id), 1, "old sales tax for taxkey 3 with 19% exists ok");
# is(defined SL::DB::Manager::Tax->find_by(taxkey => 5, rate => 0.16, chart_id => $tax_ust_16->id), 1, "new sales tax for taxkey 5 with 16% exists ok");

# is(defined SL::DB::Manager::Tax->find_by(taxkey => 7, rate => 0.16, chart_id => $tax_ust_16->id), 1, "old purchase tax for taxkey 7 with 16% exists ok");
is(defined SL::DB::Manager::Tax->find_by(taxkey => 8, rate => 0.07, chart_id => $tax_vst_7->id ), 1, "purchase tax for taxkey 8 with 7% exists ok");
is(defined SL::DB::Manager::Tax->find_by(taxkey => 9, rate => 0.19, chart_id => $tax_vst_19->id), 1, "old purchase tax for taxkey 9 with 19% exists ok");
is(defined SL::DB::Manager::Tax->find_by(taxkey => 9, rate => 0.16, chart_id => $tax_vst_16->id), 1, "new purchase tax for taxkey 9 with 16% exists ok");

my $vendor   = new_vendor(  name => 'Testvendor',   payment_id => $payment_terms->id)->save;
my $customer = new_customer(name => 'Testcustomer', payment_id => $payment_terms->id)->save;

cmp_ok($chart_income_7->get_active_taxkey($date_2020_1)->tax->rate, '==', 0.07, "get_active_taxkey rate for 8300 in 2020_1 ok");
cmp_ok($chart_income_7->get_active_taxkey($date_2020_2)->tax->rate, '==', 0.05, "get_active_taxkey rate for 8300 in 2020_2 ok");
cmp_ok($chart_income_7->get_active_taxkey($date_2021  )->tax->rate, '==', 0.07, "get_active_taxkey rate for 8300 in 2021   ok");
cmp_ok($chart_income_7->get_active_taxkey($date_2020_1)->tax->rate, '==', 0.07, "get_active_taxkey rate for $income_7_accno in 2020_1 ok");
cmp_ok($chart_income_7->get_active_taxkey($date_2020_2)->tax->rate, '==', 0.05, "get_active_taxkey rate for $income_7_accno in 2020_2 ok");
cmp_ok($chart_income_7->get_active_taxkey($date_2021  )->tax->rate, '==', 0.07, "get_active_taxkey rate for $income_7_accno in 2021   ok");
cmp_ok($chart_income_7->get_active_taxkey($date_2006  )->tax->rate, '==', 0.07, "get_active_taxkey rate for $income_7_accno in 2016   ok");

cmp_ok($chart_income_19->get_active_taxkey($date_2020_1)->tax->rate, '==', 0.19, "get_active_taxkey rate for $income_19_accno in 2020_1 ok");
cmp_ok($chart_income_19->get_active_taxkey($date_2020_2)->tax->rate, '==', 0.16, "get_active_taxkey rate for $income_19_accno in 2020_2 ok");
cmp_ok($chart_income_19->get_active_taxkey($date_2021  )->tax->rate, '==', 0.19, "get_active_taxkey rate for $income_19_accno in 2021   ok");
cmp_ok($chart_income_19->get_active_taxkey($date_2006  )->tax->rate, '==', 0.16, "get_active_taxkey rate for $income_19_accno in 2016   ok");

my $bugru19 = SL::DB::Manager::Buchungsgruppe->find_by(description => 'Standard 19%') or die "Can't find bugru19";
my $bugru7  = SL::DB::Manager::Buchungsgruppe->find_by(description => 'Standard 7%' ) or die "Can't find bugru7";

my $part1 = new_part(partnumber => '1', description => 'part19', buchungsgruppen_id => $bugru19->id)->save;
my $part2 = new_part(partnumber => '2', description => 'part7',  buchungsgruppen_id => $bugru7->id )->save;

note('sales invoices');
my $sales_invoice_2006   = create_invoice_for_date('2006',   $date_2006);
my $sales_invoice_2020_1 = create_invoice_for_date('2020_1', $date_2020_1);
my $sales_invoice_2020_2 = create_invoice_for_date('2020_2', $date_2020_2);
my $sales_invoice_2021   = create_invoice_for_date('2021',   $date_2021);

is($sales_invoice_2006->amount,   223, '2006 sales invoice has 16% and 7% tax ok'   ); # 116 + 7
is($sales_invoice_2020_1->amount, 226, '2020_01 sales invoice has 19% and 7% tax ok'); # 119 + 7
is($sales_invoice_2020_2->amount, 221, '2020_02 sales invoice has 16% and 5% tax ok'); # 116 + 5
is($sales_invoice_2021->amount,   226, '2021 sales invoice has 19% and 7% tax ok'   ); # 119 + 7

&datev_test($sales_invoice_2020_2,
           [
             {
               'belegfeld1' => 'test is 2020_2',
               'buchungstext' => 'Testcustomer',
               'datum' => '15.07.2020',
               'leistungsdatum' => '15.07.2020', # should leistungsdatum be empty if it doesn't exist?
               'gegenkonto' => $income_7_accno,
               'konto' => $ar_accno,
               'kost1' => undef,
               'kost2' => undef,
               'locked' => undef,
               'umsatz' => 105,
               'waehrung' => 'EUR'
             },
             {
               'belegfeld1' => 'test is 2020_2',
               'buchungstext' => 'Testcustomer',
               'datum' => '15.07.2020',
               'leistungsdatum' => '15.07.2020',
               'gegenkonto' => $income_19_accno,
               'konto' => $ar_accno,
               'kost1' => undef,
               'kost2' => undef,
               'locked' => undef,
               'umsatz' => 116,
               'waehrung' => 'EUR'
             }
          ],
          "datev check for 16/5 ok, no taxkey"
);

note('sales invoice with differing delivery dates');
my $sales_invoice_2020_1_with_delivery_date_2020_2 = create_invoice_for_date('deliverydate 2020_1', $date_2020_1, $date_2020_2);
is($sales_invoice_2020_1_with_delivery_date_2020_2->amount, 221, "sales_invoice from 2020_1 with future delivery_date 2020_2 tax ok");

my $sales_invoice_2020_2_with_delivery_date_2020_1 = create_invoice_for_date('deliverydate 2020_2', $date_2020_2, $date_2020_1);
is($sales_invoice_2020_2_with_delivery_date_2020_1->amount, 226, "sales_invoice from 2020_2 with   past delivery_date 2020_1 tax ok");

&datev_test($sales_invoice_2020_2_with_delivery_date_2020_1,
            [
              {
                'belegfeld1' => 'test is deliverydate 2020_2',
                'buchungstext' => 'Testcustomer',
                'datum' => '15.07.2020',
                'gegenkonto' => $income_7_accno,
                'konto' => $ar_accno,
                'kost1' => undef,
                'kost2' => undef,
                'leistungsdatum' => '15.06.2020',
                'locked' => undef,
                'umsatz' => 107,
                'waehrung' => 'EUR'
              },
              {
                'belegfeld1' => 'test is deliverydate 2020_2',
                'buchungstext' => 'Testcustomer',
                'datum' => '15.07.2020',
                'gegenkonto' => $income_19_accno,
                'konto' => $ar_accno,
                'kost1' => undef,
                'kost2' => undef,
                'leistungsdatum' => '15.06.2020',
                'locked' => undef,
                'umsatz' => 119,
                'waehrung' => 'EUR'
              }
            ],
            "datev check for datev export with delivery_date 19/7 ok, no taxkey"
);

my $sales_invoice_2021_with_delivery_date_2020_2   = create_invoice_for_date('deliverydate 2020_2', $date_2021, $date_2020_2);
is($sales_invoice_2021_with_delivery_date_2020_2->amount,   221, "sales_invoice from 2021   with   past delivery_date 2020_2 tax ok");

my $sales_invoice_2020_2_with_delivery_date_2021   = create_invoice_for_date('deliverydate 2021', $date_2020_2, $date_2021);
is($sales_invoice_2020_2_with_delivery_date_2021->amount,   226, "sales_invoice from 2020_2 with future delivery_date 2021   tax ok");


note('ap transactions');
# in the test we want to test for Reisekosten with 19% and 7%. Normally the user
# would select the entries from the dropdown, as they may differ from the
# default, so we have to pass the tax we want to create_ap_transaction

# my $tax_9_16_old = SL::DB::Manager::Tax->find_by(taxkey => 7, rate => 0.16, chart_id => $tax_vst_16->id);
my $tax_9_19     = SL::DB::Manager::Tax->find_by(taxkey => 9, rate => 0.19, chart_id => $tax_vst_19->id) or die "missing 9_19";
my $tax_9_16     = SL::DB::Manager::Tax->find_by(taxkey => 9, rate => 0.16, chart_id => $tax_vst_16->id) or die "missing 9_16";
my $tax_8_7      = SL::DB::Manager::Tax->find_by(taxkey => 8, rate => 0.07, chart_id => $tax_vst_7->id)  or die "missing 8_7";
my $tax_8_5      = SL::DB::Manager::Tax->find_by(taxkey => 8, rate => 0.05, chart_id => $tax_vst_5->id)  or die "missing 8_5";

# simulate user selecting the "correct" taxes in dropdown:
my $ap_transaction_2006   = create_ap_transaction_for_date('2006',   $date_2006,   undef, $tax_9_16, $tax_8_7);
my $ap_transaction_2020_1 = create_ap_transaction_for_date('2020_1', $date_2020_1, undef, $tax_9_19, $tax_8_7);
my $ap_transaction_2020_2 = create_ap_transaction_for_date('2020_2', $date_2020_2, undef, $tax_9_16, $tax_8_5);
my $ap_transaction_2021   = create_ap_transaction_for_date('2021',   $date_2021,   undef, $tax_9_19, $tax_8_7);


is($ap_transaction_2006->amount,   223, '2006    ap transaction has 16% and 7% tax ok'); # 116 + 7
is($ap_transaction_2020_1->amount, 226, '2020_01 ap transaction has 19% and 7% tax ok'); # 119 + 7
is($ap_transaction_2020_2->amount, 221, '2020_02 ap transaction has 16% and 5% tax ok'); # 116 + 5
is($ap_transaction_2021->amount,   226, '2021    ap transaction has 19% and 7% tax ok'); # 119 + 7

# ap transaction in july, but use old tax
my $ap_transaction_2020_2_with_delivery_date_2020_1 = create_ap_transaction_for_date('2020_2 with delivery date 2020_1', $date_2020_2, $date_2020_1, $tax_9_19, $tax_8_7);
is($ap_transaction_2020_2_with_delivery_date_2020_1->amount,   226, 'ap transaction 2020_2 with delivery date 2020_1, 19% and 7% tax ok'); # 119 + 7
&datev_test($ap_transaction_2020_2_with_delivery_date_2020_1,
            [
              {
                'belegfeld1' => 'test ap_transaction 2020_2 with delivery date 2020_1',
                'buchungsschluessel' => 8,
                'buchungstext' => 'Testvendor',
                'datum' => '15.07.2020',
                'gegenkonto' => $ap_accno,
                'konto' => $chart_reisekosten_accno,
                'kost1' => undef,
                'kost2' => undef,
                'leistungsdatum' => '15.06.2020',
                'locked' => undef,
                'umsatz' => 107,
                'waehrung' => 'EUR'
              },
              {
                'belegfeld1' => 'test ap_transaction 2020_2 with delivery date 2020_1',
                'buchungsschluessel' => 9,
                'buchungstext' => 'Testvendor',
                'datum' => '15.07.2020',
                'gegenkonto' => $ap_accno,
                'konto' => $chart_reisekosten_accno,
                'kost1' => undef,
                'kost2' => undef,
                'leistungsdatum' => '15.06.2020',
                'locked' => undef,
                'umsatz' => 119,
                'waehrung' => 'EUR'
              }
            ],
            "datev check for ap transaction 2020_2 with delivery date 2020_1, 19% and 7% tax ok"
);

note('ar transactions');

my $ar_transaction_2006   = create_ar_transaction_for_date('2006',   $date_2006);
my $ar_transaction_2020_1 = create_ar_transaction_for_date('2020_1', $date_2020_1);
my $ar_transaction_2020_2 = create_ar_transaction_for_date('2020_2', $date_2020_2);
my $ar_transaction_2021   = create_ar_transaction_for_date('2021',   $date_2021);

is($ar_transaction_2006->amount,   223, '2006    ar transaction has 16% and 7% tax ok'); # 116 + 7
is($ar_transaction_2020_1->amount, 226, '2020_01 ar transaction has 19% and 7% tax ok'); # 119 + 7
is($ar_transaction_2020_2->amount, 221, '2020_02 ar transaction has 16% and 5% tax ok'); # 116 + 5
is($ar_transaction_2021->amount,   226, '2021    ar transaction has 19% and 7% tax ok'); # 119 + 7

note('gl transactions');

my $gl_2006   = create_gl_transaction_for_date('glincome 2006',   $date_2006,   223);
my $gl_2020_1 = create_gl_transaction_for_date('glincome 2020_1', $date_2020_1, 226);
my $gl_2020_2 = create_gl_transaction_for_date('glincome 2020_2', $date_2020_2, 221);
my $gl_2021   = create_gl_transaction_for_date('glincome 2021',   $date_2021,   226);

is(SL::DB::Manager::GLTransaction->get_all_count(), 4, "4 gltransactions created correctly");

my $result = &get_account_balances;
# print Dumper($result);
is_deeply( &get_account_balances,
        [
          # {
          #   'accno' => '1000',
          #   # 'description' => 'Kasse',
          #   'sum' => '-896.00000'
          # },
          # {
          #   'accno' => '1400',
          #   # 'description' => 'Ford. a.Lieferungen und Leistungen',
          #   'sum' => '-2686.00000'
          # },
          {
            'accno' => '1568',
            # 'description' => 'Abziehbare Vorsteuer 7%',
            'sum' => '-5.00000'
          },
          {
            'accno' => '1571',
            # 'description' => 'Abziehbare Vorsteuer 7%',
            'sum' => '-28.00000'
          },
          {
            'accno' => '1575',
            # 'description' => 'Abziehbare Vorsteuer 16%',
            'sum' => '-32.00000'
          },
          {
            'accno' => '1576',
            # 'description' => 'Abziehbare Vorsteuer 19 %',
            'sum' => '-57.00000'
          },
          # {
          #   'accno' => '1600',
          #   # 'description' => 'Verbindlichkeiten aus Lief.u.Leist.',
          #   'sum' => '896.00000'
          # },
          {
            'accno' => '1771',
            # 'description' => 'Umsatzsteuer 7%',
            'sum' => '77.00000'
          },
          {
            'accno' => '1773',
            # 'description' => 'Umsatzsteuer 5 %',
            'sum' => '25.00000'
          },
          {
            'accno' => '1775',
            # 'description' => 'Umsatzsteuer 16%',
            'sum' => '128.00000'
          },
          {
            'accno' => '1776',
            # 'description' => 'Umsatzsteuer 19 %',
            'sum' => '152.00000'
          },
          # {
          #   'accno' => '4660',
          #   # 'description' => 'Reisekosten Arbeitnehmer',
          #   'sum' => '-800.00000'
          # },
          # {
          #   'accno' => $income_7_accno,
          #   # 'description' => "Erl\x{f6}se 7%USt",
          #   'sum' => '1600.00000'
          # },
          # {
          #   'accno' => $income_19_accno,
          #   # 'description' => "Erl\x{f6}se 16%/19% USt.",
          #   'sum' => '1600.00000'
          # }
        ],
        'account balances after invoices'
);

note('testing payments with skonto');

my %params = ( chart_id     => $chart_bank->id,
               payment_type => 'with_skonto_pt',
             );

$sales_invoice_2020_2->pay_invoice( %params,
                                    amount    => $sales_invoice_2020_2->amount_less_skonto,
                                    transdate => $date_2020_2->to_kivitendo,
                                  );


$skonto_5 = SL::DB::Manager::AccTransaction->find_by(trans_id => $sales_invoice_2020_2->id, amount => -5.25);
like($skonto_5->chart->description, qr/Skonti.*5/, "sales_invoice 2020_2 paid in 2020_2 - skonto 5% ok");
$skonto_16 = SL::DB::Manager::AccTransaction->find_by(trans_id => $sales_invoice_2020_2->id, amount => -5.80);
like($skonto_16->chart->description, qr/Skonti.*16/, "sales_invoice 2020_2 paid in 2020_2 - skonto 16% ok");

$sales_invoice_2020_1->pay_invoice( %params,
                                    amount    => $sales_invoice_2020_1->amount_less_skonto,
                                    transdate => $date_2020_2->to_kivitendo,
                                  );
$skonto_7 = SL::DB::Manager::AccTransaction->find_by(trans_id => $sales_invoice_2020_1->id, amount => -5.35);
like($skonto_7->chart->description, qr/Skonti.*7/, "sales_invoice 2020_1 paid with skonto in 2020_2 - skonto 7% ok");
$skonto_19 = SL::DB::Manager::AccTransaction->find_by(trans_id => $sales_invoice_2020_1->id, amount => -5.95);
like($skonto_19->chart->description, qr/Skonti.*19/, "sales_invoice 2020_1 paid with skonto in 2020_2 - skonto 19% ok");

$ap_transaction_2020_1->pay_invoice( %params,
                                     amount    => $ap_transaction_2020_1->amount_less_skonto,
                                     transdate => $date_2020_2->to_kivitendo,
                                   );
$skonto_7 = SL::DB::Manager::AccTransaction->find_by(trans_id => $ap_transaction_2020_1->id, amount => 5.35);
like($skonto_7->chart->description, qr/Skonti.*7/, "ap transaction 2020_1 paid with skonto in 2020_2 - skonto 7% ok");
$skonto_19 = SL::DB::Manager::AccTransaction->find_by(trans_id => $ap_transaction_2020_1->id, amount => 5.95);
like($skonto_19->chart->description, qr/Skonti.*19/, "ap transaction 2020_1 paid with skonto in 2020_2 - skonto 19% ok");


$ap_transaction_2020_2->pay_invoice( %params,
                                     amount    => $ap_transaction_2020_2->amount_less_skonto,
                                     transdate => $date_2021->to_kivitendo,
                                   );
$skonto_5 = SL::DB::Manager::AccTransaction->find_by(trans_id => $ap_transaction_2020_2->id, amount => 5.25);
like($skonto_5->chart->description, qr/Skonti.*5/, "ap transaction 2020_2 paid in 2021 - skonto 5% ok");

$skonto_16 = SL::DB::Manager::AccTransaction->find_by(trans_id => $ap_transaction_2020_2->id, amount => 5.80);
like($skonto_16->chart->description, qr/Skonti.*16/, "sales_invoice 2020_2 paid in 2021 - skonto 16% ok");

clear_up();

done_testing();

###### functions for setting up data

sub create_invoice_for_date {
  my ($invnumber, $transdate, $deliverydate) = @_;

  $deliverydate = $transdate unless defined $deliverydate;

  my $sales_invoice = create_sales_invoice(
    invnumber    => 'test is ' . $invnumber,
    transdate    => $transdate,
    customer     => $customer,
    deliverydate => $deliverydate,
    payment_terms => $payment_terms,
    taxincluded  => 0,
    invoiceitems => [ create_invoice_item(part => $part1, qty => 10, sellprice => 10),
                      create_invoice_item(part => $part2, qty => 10, sellprice => 10),
                    ]
  );
  return $sales_invoice;
}

sub create_ar_transaction_for_date {
  my ($invnumber, $transdate) = @_;

  my $ar_transaction = create_ar_transaction(
    customer      => $customer,
    invnumber   => 'test ar' . $invnumber,
    taxincluded => 0,
    transdate   => $transdate,
    ar_chart     => SL::DB::Manager::Chart->find_by(accno => $ar_accno), # pass ar_chart, as it is hardcoded for SKR03 in SL::Dev::Record
    bookings    => [
                     {
                       chart  => $chart_income_19,
                       amount => 100,
                     },
                     {
                       chart  => $chart_income_7,
                       amount => 100,
                     },
                   ]
  );
  return $ar_transaction;
}

sub create_ap_transaction_for_date {
  my ($invnumber, $transdate, $deliverydate, $tax_high, $tax_low) = @_;

  # printf("invnumber = %s  tax_high = %s   tax_low = %s\n", $invnumber, $tax_high->accno , $tax_low->accno);
  my $taxkey_ = $chart_reisekosten->get_active_taxkey($transdate);

  my $ap_transaction = create_ap_transaction(
    vendor       => $vendor,
    invnumber    => 'test ap_transaction ' . $invnumber,
    taxincluded  => 0,
    transdate    => $transdate,
    deliverydate => $deliverydate,
    payment_id   => $payment_terms->id,
    ap_chart     => SL::DB::Manager::Chart->find_by(accno => $ap_accno), # pass ap_chart, as it is hardcoded for SKR03 in SL::Dev::Record
    bookings     => [
                     {
                       chart  => $chart_reisekosten,
                       amount => 100,
                       tax_id => $tax_high->id,
                     },
                     {
                       chart  => $chart_reisekosten,
                       amount => 100,
                       tax_id => $tax_low->id,
                     },
                   ]
  );
  return $ap_transaction;
}

sub create_gl_transaction_for_date {
  my ($reference, $transdate, $debitamount) = @_;

  my $gl_transaction = create_gl_transaction(
    reference   => $reference,
    taxincluded => 0,
    transdate   => $transdate,
    bookings    => [
                     {
                       chart  => $chart_income_19,
                       memo   => 'gl 19',
                       source => 'gl 19',
                       credit => 100,
                     },
                     {
                       chart  => $chart_income_7,
                       memo   => 'gl 7',
                       source => 'gl 7',
                       credit => 100,
                     },
                     {
                       chart  => $chart_cash,
                       debit  => $debitamount,
                       memo   => 'gl 19+7',
                       source => 'gl 19+7',
                     },
                   ],
  );
  return $gl_transaction;
}

sub get_account_balances {
  my $query = <<SQL;
  select c.accno, sum(a.amount)
    from acc_trans a
         left join chart c on (c.id = a.chart_id)
   where c.accno ~ '^17' or c.accno ~ '^15'
group by c.accno, c.description
order by c.accno
SQL

  my $result = selectall_hashref_query($::form, $dbh, $query);
  return $result;
};

sub datev_test {
  my ($invoice, $expected_data, $msg) = @_;

  my $datev = SL::DATEV->new(
    dbh        => $invoice->db->dbh,
    trans_id   => $invoice->id,
  );

  $datev->generate_datev_data;
  my @data_datev   = sort { $a->{umsatz} <=> $b->{umsatz} } @{ $datev->generate_datev_lines() };

  # print Dumper(\@data_datev);

  cmp_deeply(\@data_datev, $expected_data, $msg);
}

sub clear_up {
  SL::DB::Manager::OrderItem->delete_all(all => 1);
  SL::DB::Manager::Order->delete_all(all => 1);
  SL::DB::Manager::InvoiceItem->delete_all(all => 1);
  SL::DB::Manager::Invoice->delete_all(all => 1);
  SL::DB::Manager::PurchaseInvoice->delete_all(all => 1);
  SL::DB::Manager::GLTransaction->delete_all(all => 1);
  SL::DB::Manager::Part->delete_all(all => 1);
  SL::DB::Manager::Customer->delete_all(all => 1);
  SL::DB::Manager::Vendor->delete_all(all => 1);
  SL::DB::Manager::PaymentTerm->delete_all(all => 1);
};

1;
