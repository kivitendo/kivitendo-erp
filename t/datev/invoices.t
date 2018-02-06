use strict;
use Test::More;
use Test::Deep qw(cmp_deeply cmp_bag);

use lib 't';
use utf8;

use_ok 'Support::TestSetup';
use SL::DATEV qw(:CONSTANTS);
use SL::Dev::ALL qw(:ALL);
use List::Util qw(sum);
use SL::DB::Buchungsgruppe;
use SL::DB::Chart;
use DateTime;

Support::TestSetup::login();

clear_up();

my $dbh = SL::DB->client->dbh;

my $buchungsgruppe7 = SL::DB::Manager::Buchungsgruppe->find_by(description => 'Standard 7%') || die "No accounting group for 7\%";
my $bank            = SL::DB::Manager::Chart->find_by(description => 'Bank')                 || die 'Can\'t find chart "Bank"';
my $date            = DateTime->new(year => 2017, month =>  1, day => 1);
my $payment_date    = DateTime->new(year => 2017, month =>  1, day => 5);
my $gldate          = DateTime->new(year => 2017, month =>  2, day => 9); # simulate bookings for Jan being made in Feb
my $department      = create_department(description => 'Kostenstelle DATEV-Schnittstelle 2018');
my $project         = create_project(projectnumber => 2017, description => 'Crowd-Funding September 2017');
my $customer        = new_customer(customernumber => '10001', name => 'Testcustomer')->save;
my $vendor          = new_vendor(vendornumber => '70001', name => 'Testvendor')->save;

my $part1 = new_part(partnumber => '19', description => 'Part 19%')->save;
my $part2 = new_part(
  partnumber         => '7',
  description        => 'Part 7%',
  buchungsgruppen_id => $buchungsgruppe7->id,
)->save;

my $invoice = create_sales_invoice(
  invnumber    => "Þ sales ¥& invöice",
  customer     => $customer,
  itime        => $gldate,
  gldate       => $gldate,
  intnotes     => 'booked in February',
  taxincluded  => 0,
  transdate    => $date,
  invoiceitems => [ create_invoice_item(part => $part1, qty =>  3, sellprice => 70),
                    create_invoice_item(part => $part2, qty => 10, sellprice => 50),
                  ],
  department_id    => $department->id,
  globalproject_id => $project->id,
);
$invoice->pay_invoice(chart_id      => $bank->id,
                      amount        => $invoice->open_amount,
                      transdate     => $payment_date->to_kivitendo,
                      memo          => 'foobar',
                      source        => 'barfoo',
                     );
my $datev1 = SL::DATEV->new(
  dbh        => $invoice->db->dbh,
  trans_id   => $invoice->id,
);

$datev1->generate_datev_data;

my @data_datev   = sort { $a->{umsatz} <=> $b->{umsatz} } @{ $datev1->generate_datev_lines() };
cmp_deeply \@data_datev, [
                                         {
                                           'belegfeld1'   => "\x{de} sales \x{a5}& inv\x{f6}ice",
                                           'buchungstext' => 'Testcustomer',
                                           'datum'        => '01.01.2017',
                                           'gegenkonto'   => '8400',
                                           'konto'        => '1400',
                                           'kost1'        => 'Kostenstelle DATEV-Schnittstelle 2018',
                                           'kost2'        => 'Crowd-Funding September 2017',
                                           'umsatz'       => '249.9',
                                           'waehrung'     => 'EUR',
                                         },
                                         {
                                           'belegfeld1'   => "\x{de} sales \x{a5}& inv\x{f6}ice",
                                           'buchungstext' => 'Testcustomer',
                                           'datum'        => '01.01.2017',
                                           'gegenkonto'   => '8300',
                                           'konto'        => '1400',
                                           'kost1'        => 'Kostenstelle DATEV-Schnittstelle 2018',
                                           'kost2'        => 'Crowd-Funding September 2017',
                                           'umsatz'       => 535,
                                           'waehrung'     => 'EUR',
                                         },
                                         {
                                           'belegfeld1'   => "\x{de} sales \x{a5}& inv\x{f6}ice",


'buchungstext' => 'Testcustomer',
                                           'buchungstext' => 'Testcustomer',
                                           'datum'        => '05.01.2017',
                                           'gegenkonto'   => '1400',
                                           'konto'        => '1200',
                                           'kost1'        => 'Kostenstelle DATEV-Schnittstelle 2018',
                                           'kost2'        => 'Crowd-Funding September 2017',
                                           'umsatz'       => '784.9',
                                           'waehrung'     => 'EUR',
                                         },
                                       ], "trans_id datev check ok";

$datev1->use_pk(1);
$datev1->generate_datev_data;
# TODO for cmp_deeply we need to sort the incoming data structure (see below)
cmp_bag $datev1->generate_datev_lines, [
                                         {
                                           'belegfeld1'   => "\x{de} sales \x{a5}& inv\x{f6}ice",
                                           'buchungstext' => 'Testcustomer',
                                           'datum'        => '01.01.2017',
                                           'gegenkonto'   => '8400',
                                           'konto'        => $customer->customernumber,
                                           'kost1'        => 'Kostenstelle DATEV-Schnittstelle 2018',
                                           'kost2'        => 'Crowd-Funding September 2017',
                                           'umsatz'       => '249.9',
                                           'waehrung'     => 'EUR',
                                         },
                                         {
                                           'belegfeld1'   => "\x{de} sales \x{a5}& inv\x{f6}ice",
                                           'buchungstext' => 'Testcustomer',
                                           'datum'        => '01.01.2017',
                                           'gegenkonto'   => '8300',
                                           'konto'        => $customer->customernumber,
                                           'kost1'        => 'Kostenstelle DATEV-Schnittstelle 2018',
                                           'kost2'        => 'Crowd-Funding September 2017',
                                           'umsatz'       => 535,
                                           'waehrung'     => 'EUR',
                                         },
                                         {
                                           'belegfeld1'   => "\x{de} sales \x{a5}& inv\x{f6}ice",
                                           'buchungstext' => 'Testcustomer',
                                           'datum'        => '05.01.2017',
                                           'gegenkonto'   => $customer->customernumber,
                                           'konto'        => '1200',
                                           'kost1'        => 'Kostenstelle DATEV-Schnittstelle 2018',
                                           'kost2'        => 'Crowd-Funding September 2017',
                                           'umsatz'       => '784.9',
                                           'waehrung'     => 'EUR',
                                         },
                                       ], "trans_id datev check use_pk ok";


my $startdate = DateTime->new(year => 2017, month =>  1, day =>  1);
my $enddate   = DateTime->new(year => 2017, month => 12, day => 31);

# check conversion to csv
$datev1->from($startdate);
$datev1->to($enddate);
# reset use_pk for csv_buchungsexport
$datev1->use_pk(0);
$datev1->generate_datev_data;


my $datev_csv = SL::DATEV::CSV->new(datev_lines  => $datev1->generate_datev_lines,
                                    from         => $startdate,
                                    to           => $enddate,
                                    locked       => $datev1->locked,
                                   );
$datev_csv->lines;


# we need sort, because pay_invoice is not acc_trans_id order safe
my @data_csv    = sort { $a->[0] cmp $b->[0] } @{ $datev_csv->lines };
# warnings should be undef -> no array elements at all
is(scalar @{ $datev_csv->warnings }, 0);


cmp_deeply($data_csv[1], [ '535', 'S', 'EUR', '', '', '', '1400', '8300', '', '0101', "\x{de} sales \x{a5}& i",
                     '', '', 'Testcustomer', '', '', '', '', '', '', '', '',
                     '', '', '', '', '', '', '', '', '', '', '', '', '',
                     '', 'Kostenst', 'Crowd-Fu', '', '', '', '', '', '', '', '',
                     '', '', '', '', '', '', '', '', '', '', '', '', '',
                     '', '', '', '', '', '', '', '', '', '', '', '', '',
                     '', '', '', '', '', '', '', '', '', '', '', '', '',
                     '', '', '', '', '', '', '', '', '', '', '', '', '',
                     '', '', '', '', '', '', '', '', '', '', '', '', '',
                     '', '', '', '', '' ]
       );

cmp_deeply($data_csv[0], [ '249,9', 'S', 'EUR', '', '', '', '1400', '8400', '', '0101', "\x{de} sales \x{a5}& i",
                     '', '', 'Testcustomer', '', '', '', '', '', '', '', '',
                     '', '', '', '', '', '', '', '', '', '', '', '', '',
                     '', 'Kostenst', 'Crowd-Fu', '', '', '', '', '', '', '', '',
                     '', '', '', '', '', '', '', '', '', '', '', '', '',
                     '', '', '', '', '', '', '', '', '', '', '', '', '',
                     '', '', '', '', '', '', '', '', '', '', '', '', '',
                     '', '', '', '', '', '', '', '', '', '', '', '', '',
                     '', '', '', '', '', '', '', '', '', '', '', '', '',
                     '', '', '', '', '' ]
       );
cmp_deeply($data_csv[2], [ '784,9', 'S', 'EUR', '', '', '', '1200', '1400', '', '0501', "\x{de} sales \x{a5}& i",
                     '', '', 'Testcustomer', '', '', '', '', '', '', '', '',
                     '', '', '', '', '', '', '', '', '', '', '', '', '',
                     '', 'Kostenst', 'Crowd-Fu', '', '', '', '', '', '', '', '',
                     '', '', '', '', '', '', '', '', '', '', '', '', '',
                     '', '', '', '', '', '', '', '', '', '', '', '', '',
                     '', '', '', '', '', '', '', '', '', '', '', '', '',
                     '', '', '', '', '', '', '', '', '', '', '', '', '',
                     '', '', '', '', '', '', '', '', '', '', '', '', '',
                     '', '', '', '', '' ]
        );
my $march_9 = DateTime->new(year => 2017, month =>  3, day => 9);
my $invoice2 = create_sales_invoice(
  invnumber    => "2 sales invoice",
  customer     => $customer,
  itime        => $march_9,
  gldate       => $march_9,
  intnotes     => 'booked in March',
  taxincluded  => 0,
  transdate    => $date,
  invoiceitems => [ create_invoice_item(part => $part1, qty =>  6, sellprice => 70),
                    create_invoice_item(part => $part2, qty => 20, sellprice => 50),
                  ]
);

my $credit_note = create_credit_note(
  invnumber    => 'Gutschrift 34',
  customer     => $customer,
  itime        => $gldate,
  gldate       => $gldate,
  intnotes     => 'booked in February',
  taxincluded  => 0,
  transdate    => $date,
  invoiceitems => [ create_invoice_item(part => $part1, qty =>  3, sellprice => 70),
                    create_invoice_item(part => $part2, qty => 10, sellprice => 50),
                  ]
);

my $datev = SL::DATEV->new(
  dbh        => $dbh,
  from       => $startdate,
  to         => $enddate,
);
$datev->generate_datev_data(from_to => $datev->fromto);
my $datev_lines = $datev->generate_datev_lines;
my $umsatzsumme = sum map { $_->{umsatz} } @{ $datev_lines };
cmp_ok($::form->round_amount($umsatzsumme,2), '==', 3924.5, "Sum of all bookings ok");

$datev->generate_datev_data(use_pk => 1, from_to => $datev->fromto);
$datev_lines = $datev->generate_datev_lines;

note('testing purchase invoice');
my $purchase_invoice = new_purchase_invoice();
$datev1 = SL::DATEV->new(
  dbh        => $purchase_invoice->db->dbh,
  trans_id   => $purchase_invoice->id,
);

$datev1->generate_datev_data;
cmp_deeply $datev1->generate_datev_lines, [
                                        {
                                          'belegfeld1'             => 'ap1',
                                          'buchungstext'           => 'Testvendor',
                                          'datum'                  => '01.01.2017',
                                          'gegenkonto'             => '1600',
                                          'konto'                  => '3400',
                                          'kost1'                  => undef,
                                          'kost2'                  => undef,
                                          'umsatz'                 => 119,
                                          'waehrung'               => 'EUR'
                                        },
                                        {
                                          'belegfeld1'             => 'ap1',
                                          'buchungstext'           => 'Testvendor',
                                          'datum'                  => '01.01.2017',
                                          'gegenkonto'             => '1600',
                                          'konto'                  => '3300',
                                          'kost1'                  => undef,
                                          'kost2'                  => undef,
                                          'umsatz'                 => 107,
                                          'waehrung'               => 'EUR'
                                        }
                                       ], "trans_id datev check purchase_invoice ok";
$datev1->use_pk(1);
$datev1->generate_datev_data;
cmp_deeply $datev1->generate_datev_lines, [
                                        {
                                          'belegfeld1'             => 'ap1',
                                          'buchungstext'           => 'Testvendor',
                                          'datum'                  => '01.01.2017',
                                          'gegenkonto'             => $vendor->vendornumber,
                                          'konto'                  => '3400',
                                          'kost1'                  => undef,
                                          'kost2'                  => undef,
                                          'umsatz'                 => 119,
                                          'waehrung'               => 'EUR'
                                        },
                                        {
                                          'belegfeld1'             => 'ap1',
                                          'buchungstext'           => 'Testvendor',
                                          'datum'                  => '01.01.2017',
                                          'gegenkonto'             => $vendor->vendornumber,
                                          'konto'                  => '3300',
                                          'kost1'                  => undef,
                                          'kost2'                  => undef,
                                          'umsatz'                 => 107,
                                          'waehrung'               => 'EUR'
                                        }
                                       ], "trans_id datev check purchase_invoice use_pk ok";

note('testing gldatefrom');
$datev = SL::DATEV->new(
  dbh        => $dbh,
  from       => $startdate,
  to         => DateTime->new(year => 2017, month => 01, day => 31),
);

$::form               = Support::TestSetup->create_new_form;
$::form->{gldatefrom} = DateTime->new(year => 2017, month => 3, day => 1)->to_kivitendo;

$datev->generate_datev_data(from_to => $datev->fromto);
$datev_lines = $datev->generate_datev_lines;
$umsatzsumme = sum map { $_->{umsatz} } @{ $datev_lines };
cmp_ok($umsatzsumme, '==', 1569.8, "Sum of bookings made after March 1st (only invoice2) ok");

$::form->{gldatefrom} = DateTime->new(year => 2017, month => 5, day => 1)->to_kivitendo;
$datev->generate_datev_data(from_to => $datev->fromto);
cmp_deeply $datev->generate_datev_lines, [], "no bookings for January made after May 1st: ok";

done_testing();
# clear_up();

sub new_purchase_invoice {
  # manually create a Kreditorenbuchung from scratch, ap + acc_trans bookings, as no helper exists yet, like $invoice->post.
  # arap-Booking must come last in the acc_trans order
  # this function was essentially copied from t/db_helper/payment.t, refactor once $purchase_invoice->post exists
  my $currency_id = $::instance_conf->get_currency_id;
  my $employee    = SL::DB::Manager::Employee->current                          || die "No employee";
  my $taxzone     = SL::DB::Manager::TaxZone->find_by( description => 'Inland') || die "No taxzone";

  my $purchase_invoice = SL::DB::PurchaseInvoice->new(
    amount      => '226',
    currency_id => $currency_id,
    employee_id => $employee->id,
    gldate      => $date,
    invnumber   => "ap1",
    invoice     => 0,
    itime       => $date,
    mtime       => $date,
    netamount   => '200',
    paid        => '0',
    taxincluded => 0,
    taxzone_id  => $taxzone->id,
    transdate   => $date,
    type        => 'invoice',
    vendor_id   => $vendor->id,
  )->save;

  my $expense_chart  = SL::DB::Manager::Chart->find_by(accno => '3400');
  my $expense_chart_booking= SL::DB::AccTransaction->new(
    amount     => '-100',
    chart_id   => $expense_chart->id,
    chart_link => $expense_chart->link,
    itime      => $date,
    mtime      => $date,
    source     => '',
    tax_id     => SL::DB::Manager::Tax->find_by(taxkey => 9)->id,
    taxkey     => 9,
    transdate  => $date,
    trans_id   => $purchase_invoice->id,
  );
  $expense_chart_booking->save;

  my $tax_chart  = SL::DB::Manager::Chart->find_by(accno => '1576');
  my $tax_chart_booking= SL::DB::AccTransaction->new(
    amount     => '-19',
    chart_id   => $tax_chart->id,
    chart_link => $tax_chart->link,
    itime      => $date,
    mtime      => $date,
    source     => '',
    tax_id     => SL::DB::Manager::Tax->find_by(taxkey => 9)->id,
    taxkey     => 0,
    transdate  => $date,
    trans_id   => $purchase_invoice->id,
  );
  $tax_chart_booking->save;
  $expense_chart  = SL::DB::Manager::Chart->find_by(accno => '3300');
  $expense_chart_booking= SL::DB::AccTransaction->new(
    amount     => '-100',
    chart_id   => $expense_chart->id,
    chart_link => $expense_chart->link,
    itime      => $date,
    mtime      => $date,
    source     => '',
    tax_id     => SL::DB::Manager::Tax->find_by(taxkey => 8)->id,
    taxkey     => 8,
    transdate  => $date,
    trans_id   => $purchase_invoice->id,
  );
  $expense_chart_booking->save;

  $tax_chart  = SL::DB::Manager::Chart->find_by(accno => '1571');
  $tax_chart_booking= SL::DB::AccTransaction->new(
    trans_id   => $purchase_invoice->id,
    chart_id   => $tax_chart->id,
    chart_link => $tax_chart->link,
    amount     => '-7',
    transdate  => $date,
    itime      => $date,
    mtime      => $date,
    source     => '',
    taxkey     => 0,
    tax_id     => SL::DB::Manager::Tax->find_by(taxkey => 8)->id,
  );
  $tax_chart_booking->save;
  my $arap_chart  = SL::DB::Manager::Chart->find_by(accno => '1600');
  my $arap_booking= SL::DB::AccTransaction->new(
    trans_id   => $purchase_invoice->id,
    chart_id   => $arap_chart->id,
    chart_link => $arap_chart->link,
    amount     => '226',
    transdate  => $date,
    itime      => $date,
    mtime      => $date,
    source     => '',
    taxkey     => 0,
    tax_id     => SL::DB::Manager::Tax->find_by(taxkey => 0)->id,
  );
  $arap_booking->save;

  return $purchase_invoice;
}

sub clear_up {
  SL::DB::Manager::AccTransaction->delete_all(all => 1);
  SL::DB::Manager::InvoiceItem->delete_all(   all => 1);
  SL::DB::Manager::Invoice->delete_all(       all => 1);
  SL::DB::Manager::PurchaseInvoice->delete_all(all => 1);
  SL::DB::Manager::Customer->delete_all(      all => 1);
  SL::DB::Manager::Part->delete_all(          all => 1);
  SL::DB::Manager::Project->delete_all(       all => 1);
  SL::DB::Manager::Department->delete_all(    all => 1);
  SL::DATEV->clean_temporary_directories;
};

1;
