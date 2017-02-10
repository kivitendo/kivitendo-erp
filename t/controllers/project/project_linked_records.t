use strict;
use Test::More;

use lib 't';
use Support::TestSetup;
use Carp;
use Test::Exception;
use SL::Dev::ALL;
use SL::DB::Part;
use SL::DB::Order;
use SL::DB::Customer;
use SL::DB::Vendor;
use SL::DB::Chart;
use SL::Controller::Project;
use DateTime;

use utf8;

Support::TestSetup::login();

clear_up();

my $vendor   = SL::Dev::CustomerVendor::create_vendor->save;
my $customer = SL::Dev::CustomerVendor::create_customer->save;
my $project  = SL::Dev::Record::create_project(projectnumber => 'p1', description => 'Project 1')->save;

my $part1 = SL::Dev::Part::create_part(   partnumber => 'T4254')->save;
my $part2 = SL::Dev::Part::create_service(partnumber => 'Serv1')->save;

# sales order with globalproject_id and item project_ids
my $sales_order = SL::Dev::Record::create_sales_order(
  save             => 1,
  customer         => $customer,
  globalproject_id => $project->id,
  taxincluded      => 0,
  orderitems       => [ SL::Dev::Record::create_order_item(part => $part1, qty =>  3, sellprice => 70, project_id => $project->id),
                        SL::Dev::Record::create_order_item(part => $part2, qty => 10, sellprice => 50, project_id => $project->id),
                      ]
);

# sales order with no globalproject_id but item project_ids
my $sales_order2 = SL::Dev::Record::create_sales_order(
  save             => 1,
  customer         => $customer,
  taxincluded      => 0,
  orderitems       => [ SL::Dev::Record::create_order_item(part => $part1, qty =>  3, sellprice => 70, project_id => $project->id),
                        SL::Dev::Record::create_order_item(part => $part2, qty => 10, sellprice => 50),
                      ]
);

# purchase order with globalproject_id and item project_ids
my $purchase_order = SL::Dev::Record::create_purchase_order(
  save             => 1,
  vendor           => $vendor,
  globalproject_id => $project->id,
  taxincluded      => 0,
  orderitems       => [ SL::Dev::Record::create_order_item(part => $part1, qty =>  3, sellprice => 70, project_id => $project->id),
                        SL::Dev::Record::create_order_item(part => $part2, qty => 10, sellprice => 50, project_id => $project->id),
                      ]
);

# sales_invoice with globalproject_id, and all items with project_id
my $sales_invoice = SL::Dev::Record::create_sales_invoice(
  customer         => $customer,
  globalproject_id => $project->id,
  taxincluded      => 0,
  invoiceitems     => [ SL::Dev::Record::create_invoice_item(part => $part1, qty =>  3, sellprice => 70, project_id => $project->id),
                        SL::Dev::Record::create_invoice_item(part => $part2, qty => 10, sellprice => 50, project_id => $project->id),
                      ]
);

# sales_invoice with globalproject_id, but none of the items has a project_id
my $sales_invoice2 = SL::Dev::Record::create_sales_invoice(
  customer         => $customer,
  globalproject_id => $project->id,
  taxincluded      => 0,
  invoiceitems     => [ SL::Dev::Record::create_invoice_item(part => $part1, qty =>  3, sellprice => 70),
                        SL::Dev::Record::create_invoice_item(part => $part2, qty => 10, sellprice => 50),
                      ]
);

# one of the invoice items has the project id, but there is no globalproject_id
my $sales_invoice4 = SL::Dev::Record::create_sales_invoice(
  customer         => $customer,
  taxincluded      => 0,
  invoiceitems     => [ SL::Dev::Record::create_invoice_item(part => $part1, qty =>  3, sellprice => 70),
                        SL::Dev::Record::create_invoice_item(part => $part2, qty => 10, sellprice => 50, project_id => $project->id),
                      ]
);

my $today = DateTime->today;
my $expense_chart_porto = SL::DB::Manager::Chart->find_by(description => 'Porto');
my $income_chart        = SL::DB::Manager::Chart->find_by(accno => 8400);
my $tax_9 = SL::DB::Manager::Tax->find_by(taxkey => 9, rate => 0.19) || die "No tax";
my $tax_3 = SL::DB::Manager::Tax->find_by(taxkey => 3, rate => 0.19) || die "No tax";

# create an ar_transaction manually, with globalproject_id and acc_trans project_ids
my $ar_transaction = SL::DB::Invoice->new(
      invoice          => 0,
      invnumber        => 'test ar_transaction globalproject_id',
      amount           => 119,
      netamount        => 100,
      transdate        => $today,
      taxincluded      => 0,
      customer_id      => $customer->id,
      taxzone_id       => $customer->taxzone_id,
      currency_id      => $::instance_conf->get_currency_id,
      transactions     => [],
      notes            => 'test ar_transaction globalproject_id',
      globalproject_id => $project->id,
);
$ar_transaction->add_ar_amount_row(
    amount     => $ar_transaction->netamount,
    chart      => $income_chart,
    tax_id     => $tax_3->id,
    project_id => $project->id,
);
my $ar_chart = SL::DB::Manager::Chart->find_by( accno => '1400' ); # Forderungen
$ar_transaction->create_ar_row(chart => $ar_chart);
$ar_transaction->save;

# create an ap_transaction manually, with globalproject_id and acc_trans project_ids
my $ap_transaction = SL::DB::PurchaseInvoice->new(
      invoice          => 0,
      invnumber        => 'test ap_transaction globalproject_id',
      amount           => 119,
      netamount        => 100,
      transdate        => $today,
      taxincluded      => 0,
      vendor_id        => $vendor->id,
      taxzone_id       => $vendor->taxzone_id,
      currency_id      => $::instance_conf->get_currency_id,
      transactions     => [],
      notes            => 'test ap_transaction globalproject_id',
      globalproject_id => $project->id,
);
$ap_transaction->add_ap_amount_row(
    amount     => $ap_transaction->netamount,
    chart      => $expense_chart_porto,
    tax_id     => $tax_9->id,
    project_id => $project->id,
);
my $ap_chart = SL::DB::Manager::Chart->find_by( accno => '1600' ); # Verbindlichkeiten
$ap_transaction->create_ap_row(chart => $ap_chart);
$ap_transaction->save;

# create an ap_transaction manually, with no globalproject_id but acc_trans project_ids
my $ap_transaction2 = SL::DB::PurchaseInvoice->new(
      invoice          => 0,
      invnumber        => 'test ap_transaction no globalproject_id',
      amount           => 119,
      netamount        => 100,
      transdate        => $today,
      taxincluded      => 0,
      vendor_id        => $vendor->id,
      taxzone_id       => $vendor->taxzone_id,
      currency_id      => $::instance_conf->get_currency_id,
      transactions     => [],
      notes            => 'test ap_transaction no globalproject_id',
);
$ap_transaction2->add_ap_amount_row(
    amount     => $ap_transaction2->netamount,
    chart      => $expense_chart_porto,
    tax_id     => $tax_9->id,
    project_id => $project->id,
);
$ap_chart = SL::DB::Manager::Chart->find_by( accno => '1600' ); # Verbindlichkeiten
$ap_transaction2->create_ap_row(chart => $ap_chart);
$ap_transaction2->save;

my $expense_chart = SL::DB::Manager::Chart->find_by(accno => '4660'); # Reisekosten
my $cash_chart    = SL::DB::Manager::Chart->find_by(accno => '1000'); # Kasse
my $tax_chart     = SL::DB::Manager::Chart->find_by(accno => '1576'); # Vorsteuer

my @acc_trans;
push(@acc_trans, SL::DB::AccTransaction->new(
                                      chart_id   => $expense_chart->id,
                                      chart_link => $expense_chart->link,
                                      amount     => -84.03,
                                      transdate  => $today,
                                      source     => '',
                                      taxkey     => 9,
                                      tax_id     => $tax_9->id,
                                      project_id => $project->id,
));
push(@acc_trans, SL::DB::AccTransaction->new(
                                      chart_id   => $tax_chart->id,
                                      chart_link => $tax_chart->link,
                                      amount     => -15.97,
                                      transdate  => $today,
                                      source     => '',
                                      taxkey     => 9,
                                      tax_id     => $tax_9->id,
                                      project_id => $project->id,
));
push(@acc_trans, SL::DB::AccTransaction->new(
                                      chart_id   => $cash_chart->id,
                                      chart_link => $cash_chart->link,
                                      amount     => 100,
                                      transdate  => $today,
                                      source     => '',
                                      taxkey     => 0,
                                      tax_id     => 0,
));

my $gl_transaction = SL::DB::GLTransaction->new(
  reference      => "reise",
  description    => "reise",
  transdate      => $today,
  gldate         => $today,
  employee_id    => SL::DB::Manager::Employee->current->id,
  taxincluded    => 1,
  type           => undef,
  ob_transaction => 0,
  cb_transaction => 0,
  storno         => 0,
  storno_id      => undef,
  transactions   => \@acc_trans,
)->save;

my $controller = SL::Controller::Project->new;
$::form->{id} = $project->id;
$controller->load_project;
is( scalar @{$controller->linked_records}, 10, "found all records that have a link to the project");

clear_up();

done_testing;

sub clear_up {
  foreach (qw(OrderItem Order InvoiceItem Invoice PurchaseInvoice Part GLTransaction AccTransaction PurchaseInvoice Project Vendor Customer)) {
    "SL::DB::Manager::${_}"->delete_all(all => 1);
  }
}

1
