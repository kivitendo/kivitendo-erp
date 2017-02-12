use strict;
use Test::More;
use Test::Deep qw(cmp_bag);

use lib 't';

use_ok 'Support::TestSetup';
use SL::DATEV qw(:CONSTANTS);
use SL::Dev::ALL;
use List::Util qw(sum);
use SL::DB::Buchungsgruppe;
use SL::DB::Chart;
use DateTime;

Support::TestSetup::login();

clear_up();

my $buchungsgruppe7 = SL::DB::Manager::Buchungsgruppe->find_by(description => 'Standard 7%') || die "No accounting group for 7\%";
my $bank            = SL::DB::Manager::Chart->find_by(description => 'Bank')                 || die 'Can\'t find chart "Bank"';
my $date            = DateTime->new(year => 2017, month =>  1, day => 1);
my $payment_date    = DateTime->new(year => 2017, month =>  1, day => 5);

my $part1 = SL::Dev::Part::create_part(partnumber => '19', description => 'Part 19%')->save;
my $part2 = SL::Dev::Part::create_part(
  partnumber         => '7',
  description        => 'Part 7%',
  buchungsgruppen_id => $buchungsgruppe7->id,
)->save;

my $invoice = SL::Dev::Record::create_sales_invoice(
  invnumber    => "1 sales invoice",
  taxincluded  => 0,
  transdate    => $date,
  invoiceitems => [ SL::Dev::Record::create_invoice_item(part => $part1, qty =>  3, sellprice => 70),
                    SL::Dev::Record::create_invoice_item(part => $part2, qty => 10, sellprice => 50),
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

my $invoice2 = SL::Dev::Record::create_sales_invoice(
  invnumber    => "2 sales invoice",
  taxincluded  => 0,
  transdate    => $date,
  invoiceitems => [ SL::Dev::Record::create_invoice_item(part => $part1, qty =>  6, sellprice => 70),
                    SL::Dev::Record::create_invoice_item(part => $part2, qty => 20, sellprice => 50),
                  ]
);

my $credit_note = SL::Dev::Record::create_credit_note(
  invnumber    => 'Gutschrift 34',
  taxincluded  => 0,
  transdate    => $date,
  invoiceitems => [ SL::Dev::Record::create_invoice_item(part => $part1, qty =>  3, sellprice => 70),
                    SL::Dev::Record::create_invoice_item(part => $part2, qty => 10, sellprice => 50),
                  ]
);

my $startdate = DateTime->new(year => 2017, month =>  1, day => 1);
my $enddate   = DateTime->new(year => 2017, month => 12, day => 31);

my $datev = SL::DATEV->new(
  dbh        => $credit_note->db->dbh,
  from       => $startdate,
  to         => $enddate
);
$datev->generate_datev_data(from_to => $datev->fromto);
my $datev_lines = $datev->generate_datev_lines;
my $umsatzsumme = sum map { $_->{umsatz} } @{ $datev_lines };
is($umsatzsumme, 3924.50, "umsatzsumme ok");

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

