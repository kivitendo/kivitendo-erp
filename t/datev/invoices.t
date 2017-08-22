use strict;
use Test::More;
use Test::Deep qw(cmp_bag);

use lib 't';

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

my $part1 = new_part(partnumber => '19', description => 'Part 19%')->save;
my $part2 = new_part(
  partnumber         => '7',
  description        => 'Part 7%',
  buchungsgruppen_id => $buchungsgruppe7->id,
)->save;

my $invoice = create_sales_invoice(
  invnumber    => "1 sales invoice",
  itime        => $gldate,
  gldate       => $gldate,
  intnotes     => 'booked in February',
  taxincluded  => 0,
  transdate    => $date,
  invoiceitems => [ create_invoice_item(part => $part1, qty =>  3, sellprice => 70),
                    create_invoice_item(part => $part2, qty => 10, sellprice => 50),
                  ]
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
my $kne_lines1 = $datev1->generate_datev_lines;
cmp_bag $datev1->generate_datev_lines, [
                                         {
                                           'belegfeld1'   => '1 sales invoice',
                                           'buchungstext' => 'Testcustomer',
                                           'datum'        => '01.01.2017',
                                           'gegenkonto'   => '8400',
                                           'konto'        => '1400',
                                           'umsatz'       => '249.9',
                                           'waehrung'     => 'EUR'
                                         },
                                         {
                                           'belegfeld1'   => '1 sales invoice',
                                           'buchungstext' => 'Testcustomer',
                                           'datum'        => '01.01.2017',
                                           'gegenkonto'   => '8300',
                                           'konto'        => '1400',
                                           'umsatz'       => 535,
                                           'waehrung'     => 'EUR'
                                         },
                                         {
                                           'belegfeld1'   => '1 sales invoice',
                                           'buchungstext' => 'Testcustomer',
                                           'datum'        => '05.01.2017',
                                           'gegenkonto'   => '1400',
                                           'konto'        => '1200',
                                           'umsatz'       => '784.9',
                                           'waehrung'     => 'EUR'
                                         },
                                       ], "trans_id datev check ok";

my $march_9 = DateTime->new(year => 2017, month =>  3, day => 9);
my $invoice2 = create_sales_invoice(
  invnumber    => "2 sales invoice",
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
  itime        => $gldate,
  gldate       => $gldate,
  intnotes     => 'booked in February',
  taxincluded  => 0,
  transdate    => $date,
  invoiceitems => [ create_invoice_item(part => $part1, qty =>  3, sellprice => 70),
                    create_invoice_item(part => $part2, qty => 10, sellprice => 50),
                  ]
);

my $startdate = DateTime->new(year => 2017, month =>  1, day =>  1);
my $enddate   = DateTime->new(year => 2017, month => 12, day => 31);

my $datev = SL::DATEV->new(
  dbh        => $dbh,
  from       => $startdate,
  to         => $enddate,
);
$datev->generate_datev_data(from_to => $datev->fromto);
my $datev_lines = $datev->generate_datev_lines;
my $umsatzsumme = sum map { $_->{umsatz} } @{ $datev_lines };
cmp_ok($::form->round_amount($umsatzsumme,2), '==', 3924.5, "Sum of all bookings ok");

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
cmp_bag $datev->generate_datev_lines, [], "no bookings for January made after May 1st: ok";

done_testing();
clear_up();

sub clear_up {
  SL::DB::Manager::AccTransaction->delete_all(all => 1);
  SL::DB::Manager::InvoiceItem->delete_all(   all => 1);
  SL::DB::Manager::Invoice->delete_all(       all => 1);
  SL::DB::Manager::Customer->delete_all(      all => 1);
  SL::DB::Manager::Part->delete_all(          all => 1);
};

1;
