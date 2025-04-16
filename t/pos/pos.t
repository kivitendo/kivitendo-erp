use strict;

use lib 't';
use utf8;

use Carp;
use Data::Dumper;
use Test::More; # tests => 19;
use Support::TestSetup;
use Test::Exception;

use SL::Dev::CustomerVendor qw(new_customer);
use SL::Dev::Part qw(new_part);;
use SL::Dev::POS qw(:ALL);
use SL::Dev::Record qw(create_project create_sales_order create_order_item);
use SL::Dev::Inventory qw(create_warehouse_and_bins set_stock);

use SL::POS;

use SL::DB::ECterminal;
use SL::DB::PointOfSale;
use SL::DB::ValidityToken;
use SL::DB::TSETransaction;
use SL::DB::TSEterminal;

my ($customer, $employee, $project, $printer);
my (@parts, $unit_stck, $warehouse, $bin);
my ($ec_terminal, $tse_terminal, $receipt_printer, $tse_device);
my ($pos1, $pos1_chart, $pos2, $pos2_chart);

sub test_build_process_data {

  my $payments = [
                   {
                     'amount' => '35.7',
                     'type' => 'cash'
                   }
                 ];

  my $process_data = SL::Dev::POS::build_process_data($payments);
  is($process_data, 'Beleg^35.70_0.00_0.00_0.00_0.00^35.70:Bar', "process_data ok")

}

sub test_parse_tse_response {

  # build tse response with defaults
  my $json = build_tse_json_response(transaction_number => 10, sig_counter => 15, signature => "ababaaba");

  my $parsed_tse_response = SL::POS::parse_tse_response($json);

  is($parsed_tse_response->{"transaction_number"}, 10, "transaction_number ok");
  is($parsed_tse_response->{"sig_counter"}, 15, "sig_counter ok");
  is($parsed_tse_response->{"signature"}, "ababaaba", "signature ok");

}

sub test_configure_hardware {
  # test the global hardware setup configured in this test
  # my $testname = "configure_hardware";

  is($ec_terminal->ip_address, 'localhost', "ec_terminal configured ok");
  is($ec_terminal->transfer_chart->accno, "1001", "ec_terminal chart configured ok");
  is($receipt_printer->name, "RP1", "receipt printer name ok");
  is($pos1->name, "Kasse 1", "pos name ok");
  is($pos1->ec_terminal->ip_address, "localhost", "pos ec terminal ip address ok");
  is($pos1->cash_chart->description, "Kasse 1", "pos cash chart description ok");
}

sub test_pay_order_with_amounts {

  my ($order, $validity_token) = _create_order_and_token();
  my ($cash_amount, $terminal_amount) = (35.7, 0);
  my $transaction_number = 99;

  my $invoice = SL::POS::pay_order_with_amounts($pos1, $tse_device, $transaction_number, $order, $validity_token, $cash_amount, $terminal_amount);
  my $tse_transaction = SL::DB::Manager::TSETransaction->find_by(ar_id => $invoice->id);

  is($tse_transaction->transaction_number, 99, "stored transaction_number ok");
  is($tse_transaction->process_data, "QmVsZWdeMzUuNzBfMC4wMF8wLjAwXzAuMDBfMC4wMF4zNS43MDpCYXI=", "stored process_data ok");
}

sub test_order_to_delivery_order {
  my ($order, $validity_token) = _create_order_and_token();
  my ($part1, $part2) = @parts;

  my $stock_part1 = SL::Helper::Inventory::get_stock(part => $part1);

  my $delivery_order = SL::POS::order_to_delivery_order($order, $validity_token);
  is(ref($delivery_order), 'SL::DB::DeliveryOrder', "delivery order created ok");

  my $do = SL::DB::Manager::DeliveryOrder->find_by(id => $delivery_order->id);
  is($do->sales_order->ordnumber, $order->ordnumber, "sales order created ok");
  cmp_ok(SL::Helper::Inventory::get_stock(part => $part1), '==', $stock_part1 - 3, 'stock of part 1 after delivery order ok');
}

sub test_order_to_invoice {

  my ($order, $validity_token) = _create_order_and_token();
  my ($part1, $part2) = @parts;

  my $stock_part1 = SL::Helper::Inventory::get_stock(part => $part1);

  my $invoice = SL::POS::order_to_invoice($order, $validity_token);
  is(ref($invoice), 'SL::DB::Invoice', "invoice created ok");

  cmp_ok(SL::Helper::Inventory::get_stock(part => $part1), '==', $stock_part1 - 3, 'stock of part 1 after invoice ok');
}

sub test_tse_transaction {

  my ($order, $validity_token) = _create_order_and_token();
  my ($part1, $part2) = @parts;

  my $stock_part1 = SL::Helper::Inventory::get_stock(part => $part1);

  my $invoice = SL::POS::order_to_invoice($order, $validity_token);

  my $process_data = 'Beleg^100.00_0.00_0.00_0.00_0.00^100.00:Bar';
  my $transaction_number = 88;

  my $json_tse_response = build_tse_json_response(
    process_data => $process_data,
    transaction_number => $transaction_number
  );
  my $tse_response = SL::POS::parse_tse_response($json_tse_response);

  my $tse = SL::POS::store_tse_transaction($pos1, $tse_device, $transaction_number, $invoice, $tse_response);

  is($tse->transaction_number, 88, "transaction_number ok");
  is($tse->sig_counter, $tse_response->{"sig_counter"}, "sig_counter ok");
}

sub reset_state {
  my %params = @_;

  clear_up();

  $unit_stck = SL::DB::Manager::Unit->find_by(name => 'Stck') || die "Can't find unit 'Stck'";
  $customer  = new_customer(name => "Kassenkunde")->save;
  $printer   = create_printer();
  $project   = create_project(projectnumber => "KOST1", description => "KOST1");

  my @pos_configs = (
    { "accno" => "1001", "description" => "Kasse 1" },
    { "accno" => "1002", "description" => "POS2" }
  );

  ($pos1_chart, $pos2_chart) = map {
    SL::DB::Chart->new(
      accno => $_->{"accno"},
      description => $_->{"description"},
      charttype => 'A',
      category => 'A',
      link => 'AR_paid:AP_paid',
      taxkey_id => 0,
      invalid => 0
    )->save;
  } @pos_configs;

  $ec_terminal = create_ec_terminal(transfer_chart_id => $pos1_chart->id);
  $receipt_printer = create_receipt_printer();
  $tse_terminal = create_tse_terminal();
  $tse_device = create_tse_device();
  $pos1 = create_pos(name => "Kasse 1", cash_chart_id => $pos1_chart->id);
  $pos2 = create_pos(name => "POS 2", cash_chart_id => $pos2_chart->id);

  $employee = SL::DB::Employee->new(
    'login' => 'testuser',
    'name'  => 'Test User',
  )->save;

  ($warehouse, $bin) = create_warehouse_and_bins;

  # some parts/services
  my $part1 = new_part(
    partnumber   => '1',
    description  => 'T-Shirt',
    unit         => $unit_stck->name,
    warehouse_id => $warehouse->id,
    bin_id       => $bin->id,
  )->save;
  set_stock(part => $part1, abs_qty => 20);
  my $part2 = new_part(
    partnumber   => '2',
    description  => 'Socke',
    unit         => $unit_stck->name,
    warehouse_id => $warehouse->id,
    bin_id       => $bin->id,
  )->save;
  set_stock(part => $part2, abs_qty => 20);
  @parts = ($part1, $part2);
}

Support::TestSetup::login();

# tests without state
test_build_process_data();
test_parse_tse_response();

reset_state(); # includes a clear_up

# tests with db state
test_pay_order_with_amounts();
test_order_to_delivery_order();
test_order_to_invoice();
test_configure_hardware();
test_tse_transaction();

# final clear_up
clear_up();

done_testing;

sub clear_up {
  foreach (qw(TSETransaction OrderItem Order InvoiceItem Invoice Inventory
              DeliveryOrder Part Customer PointOfSale Project ReceiptPrinter
              ECterminal TSEDevice TSEterminal)
          ) {
    "SL::DB::Manager::${_}"->delete_all(all => 1);
  }
  SL::DB::Manager::Employee->delete_all(where => [ login => 'testuser' ]);
  SL::DB::Manager::Customer->delete_all(where => [ name => 'Kassenkunde' ]);
  SL::DB::Manager::Chart->delete_all(where => [ description => 'Kasse 1']);
  SL::DB::Manager::Chart->delete_all(where => [ description => 'POS2']);
};

sub _generate_order_validity_token {
  SL::DB::ValidityToken->create(
    scope => SL::DB::ValidityToken::SCOPE_ORDER_SAVE()
  )->token;
}

sub _create_order_and_token {
  my $part = $parts[0];
  my $order = create_sales_order(
    save         => 1,
    customer     => $customer,
    taxincluded  => 0,
    orderitems => [
                    create_order_item(part => $part, qty =>  3),
                  ]
  );
  my $validity_token = _generate_order_validity_token();
  ($order, $validity_token);
}

1;
