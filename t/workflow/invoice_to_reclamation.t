use Test::More;

use strict;

use lib 't';
use utf8;

use Carp;
use Data::Dumper;
use Support::TestSetup;
use Support::TestRoutines qw(test_deeply);
use Test::Exception;
use List::MoreUtils qw(pairwise);

use SL::DB::Order;
use SL::DB::Reclamation;
use SL::DB::ReclamationReason;
use SL::DB::Customer;
use SL::DB::Vendor;
use SL::DB::Department;
use SL::DB::Currency;
use SL::DB::PaymentTerm;
use SL::DB::DeliveryTerm;
use SL::DB::Employee;
use SL::DB::Part;
use SL::DB::Unit;
use SL::Model::Record;

use Rose::DB::Object::Helpers qw(clone);

use SL::Dev::ALL qw(:ALL);

my (
  $customer, $vendor,
  $employee,
  $payment_term,
  $delivery_term,
  $unit,
  @parts,
  $department,
  $relamation_reason,
);


sub clear_up {
  foreach (qw(
    Invoice PurchaseInvoice InvoiceItem
    Reclamation ReclamationItem
    ReclamationReason
    Part
    Customer Vendor
    Department PaymentTerm DeliveryTerm
    )) {
    "SL::DB::Manager::${_}"->delete_all(all => 1);
  }
  SL::DB::Manager::Employee->delete_all(where => [ login => 'testuser' ]);
};

sub reset_state {
  my %params = @_;

  clear_up();

  $unit     = SL::DB::Manager::Unit->find_by(name => 'kg') || die "Can't find unit 'kg'";

  $employee = SL::DB::Employee->new(
    'login' => 'testuser',
    'name'  => 'Test User',
  )->save;

  $department = SL::DB::Department->new(
    'description' => 'Test Department',
  )->save;

  $payment_term = create_payment_terms(
     'description'      => '14Tage 2%Skonto, 30Tage netto',
     'description_long' => "Innerhalb von 14 Tagen abzüglich 2 % Skonto, innerhalb von 30 Tagen rein netto.|Bei einer Zahlung bis zum <%skonto_date%> gewähren wir 2 % Skonto (EUR <%skonto_amount%>) entspricht EUR <%total_wo_skonto%>.Bei einer Zahlung bis zum <%netto_date%> ist der fällige Betrag in Höhe von <%total%> <%currency%> zu überweisen.",
     'percent_skonto'   => '0.02',
     'terms_netto'      => 30,
     'terms_skonto'     => 14
  );

  $delivery_term = SL::DB::DeliveryTerm->new(
    'description'      => 'Test Delivey Term',
    'description_long' => 'Test Delivey Term Test Delivey Term',
  )->save;

  # some parts/services
  @parts = ();
  push @parts, new_part(
    partnumber => 'Part_1_KG',
    unit        => $unit->name,
  )->save;
  push @parts, new_service(
    partnumber => 'Serv_1',
  )->save;
  push @parts, new_part(
    partnumber => 'Part_2',
  )->save;
  push @parts, new_service(
    partnumber => 'Serv_2'
  )->save;

  $relamation_reason = SL::DB::ReclamationReason->new(
    name => "test_reason",
    description => "",
    position => 1,
  );
}

Support::TestSetup::login();

reset_state();

#####

my $sales_reclamation = SL::Dev::Record::create_sales_reclamation(
  save                    => 1,
  employee                => $employee,
  shippingpoint           => "sp",
  transaction_description => "td1",
  payment                 => $payment_term,
  delivery_term           => $delivery_term,
  taxincluded             => 0,
  reclamation_items       => [
    SL::Dev::Record::create_reclamation_item(
      part => $parts[0], qty =>  3, sellprice => 70,
      reason => $relamation_reason,
    ),
    SL::Dev::Record::create_reclamation_item(
      part => $parts[1], qty => 10, sellprice => 50,
      reason => $relamation_reason,
    ),
  ],
)->load;

my $purchase_reclamation = SL::Dev::Record::create_purchase_reclamation(
  save                    => 1,
  employee                => $employee,
  shippingpoint           => "sp",
  transaction_description => "td2",
  payment                 => $payment_term,
  delivery_term           => $delivery_term,
  taxincluded             => 0,
  reclamation_items       => [
    SL::Dev::Record::create_reclamation_item(
      part => $parts[0], qty =>  3, sellprice => 70,
      reason => $relamation_reason,
    ),
    SL::Dev::Record::create_reclamation_item(
      part => $parts[1], qty => 10, sellprice => 50,
      reason => $relamation_reason,
    ),
  ],
)->load;


my $sales_invoice = SL::Dev::Record::create_sales_invoice(
  save                    => 1,
  employee                => $employee,
  shippingpoint           => "sp",
  transaction_description => "td3",
  payment_terms           => $payment_term,
  delivery_term           => $delivery_term,
  taxincluded             => 0,
  invoiceitems => [ create_invoice_item(part => $parts[0], qty =>  3, sellprice => 70),
                    create_invoice_item(part => $parts[1], qty => 10, sellprice => 50),
  ]
)->load;

my $purchase_invoice = create_minimal_purchase_invoice(
  save                    => 1,
  employee                => $employee,
  invnumber               => "t1",
  transaction_description => "td4",
  payment_terms           => $payment_term,
  delivery_term           => $delivery_term,
  taxincluded             => 0,
  invoiceitems => [ SL::Dev::Record::create_invoice_item(part => $parts[0], qty =>  3, sellprice => 70),
                  SL::Dev::Record::create_invoice_item(part => $parts[1], qty => 10, sellprice => 50),
  ]
)->load;

# convert invoice → reclamation
my $converted_sales_reclamation =SL::Model::Record->new_from_workflow($sales_invoice, "sales_reclamation");
$converted_sales_reclamation->items_sorted->[0]->reason($relamation_reason);
$converted_sales_reclamation->items_sorted->[1]->reason($relamation_reason);
$converted_sales_reclamation->save->load;
my $converted_purchase_reclamation = SL::Model::Record->new_from_workflow($purchase_invoice, "purchase_reclamation");
$converted_purchase_reclamation->items_sorted->[0]->reason($relamation_reason);
$converted_purchase_reclamation->items_sorted->[1]->reason($relamation_reason);
$converted_purchase_reclamation->save->load;

#get items before strip
my @purchase_reclamation_items           = @{$purchase_reclamation->items_sorted};
my @sales_reclamation_items              = @{$sales_reclamation->items_sorted};
my @converted_purchase_reclamation_items = @{$converted_purchase_reclamation->items_sorted};
my @converted_sales_reclamation_items    = @{$converted_sales_reclamation->items_sorted};
my @purchase_invoice_items               = @{$purchase_invoice->items_sorted};
my @sales_invoice_items                  = @{$sales_invoice->items_sorted};


### TESTS #####################################################################

## created sales und purchase reclamation should be nearly the same
my $sales_reclamation_tmp = clone($sales_reclamation);
my $purchase_reclamation_tmp = clone($purchase_reclamation);
# clean different values
foreach (qw(
  customer_id vendor_id
  id record_number
  salesman_id
  transaction_description
  itime mtime
  )) {
  $sales_reclamation_tmp->$_(undef);
  $purchase_reclamation_tmp->$_(undef);
}
pairwise { my $first_tmp = clone($a); my $second_tmp = clone($b);
  foreach (qw(
    id reclamation_id
    itime mtime
    )) {
    $first_tmp->$_(undef);
    $second_tmp->$_(undef);
  }
  is_deeply($first_tmp->strip->as_tree, $second_tmp->strip->as_tree);
} @purchase_reclamation_items, @sales_reclamation_items;
is_deeply($purchase_reclamation_tmp->strip->as_tree, $sales_reclamation_tmp->strip->as_tree);

## converted have to be linked to parent
my $linked_sales_invoice = $converted_sales_reclamation->linked_records->[0];
is_deeply($linked_sales_invoice->strip->as_tree, $sales_invoice->strip->as_tree);
my $linked_purchase_invoice = $converted_purchase_reclamation->linked_records->[0];
is_deeply($linked_purchase_invoice->strip->as_tree, $purchase_invoice->strip->as_tree);


## converted should be nealy the same
pairwise {
  test_deeply($a->strip->as_tree, $b->strip->as_tree,
    "sales_invoice_items to sales_reclamation_items",
    qw(
      id trans_id reclamation_id itime mtime
      allocated assemblyitem cusordnumber deliverydate donumber fxsellprice marge_percent marge_price_factor marge_total optional ordnumber subtotal transdate expense_chart_id tax_id inventory_chart_id
      reason_description_ext reason_description_int reason_id reqdate
      tax_chart_type
    ));
} @sales_invoice_items, @converted_sales_reclamation_items;
test_deeply($sales_invoice->strip->as_tree, $converted_sales_reclamation->strip->as_tree,
  "sales_invoice to sales_reclamation",
  qw(
    id employee_id itime mtime transdate
    datepaid delivery_customer_id delivery_vendor_id deliverydate direct_debit donumber duedate dunning_config_id gldate invnumber_for_credit_note invoice marge_percent marge_total orddate ordnumber paid qr_reference qr_unstructured_message qrbill_without_amount quodate quonumber storno storno_id type
    delivered closed exchangerate reqdate vendor_id
    cp_id contact_id
    cusordnumber cv_record_number
    invnumber record_number
  ));

pairwise {
  test_deeply($a->strip->as_tree, $b->strip->as_tree,
    "purchase_invoice_items to purchase_reclamation_items",
    qw(
      id trans_id reclamation_id itime mtime
      allocated assemblyitem cusordnumber deliverydate donumber fxsellprice marge_percent marge_price_factor marge_total optional ordnumber subtotal transdate expense_chart_id tax_id inventory_chart_id
      reason_description_ext reason_description_int reason_id reqdate
      tax_chart_type
    ));
} @purchase_invoice_items, @converted_purchase_reclamation_items;
test_deeply($purchase_invoice->strip->as_tree, $converted_purchase_reclamation->strip->as_tree,
  "purchase_invoice to purchase_reclamation",
  qw(
    id employee_id itime mtime transdate
    datepaid deliverydate direct_debit duedate gldate invoice orddate ordnumber paid quodate quonumber storno storno_id type is_sepa_blocked
    billing_address_id customer_id cv_record_number delivered closed exchangerate reqdate salesman_id shippingpoint shipto_id
    cp_id contact_id
    invnumber record_number qrbill_data
  ));

# diag Dumper($sales_invoice->strip->as_tree);
# diag Dumper($converted_sales_reclamation->strip->as_tree);

####
clear_up();

done_testing;

1;
