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
    Order OrderItem
    Reclamation ReclamationItem
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


my $sales_order = SL::Dev::Record::create_sales_order(
  save                    => 1,
  employee                => $employee,
  shippingpoint           => "sp",
  transaction_description => "td3",
  payment_terms           => $payment_term,
  delivery_term           => $delivery_term,
  taxincluded             => 0,
  orderitems => [ SL::Dev::Record::create_order_item(part => $parts[0], qty =>  3, sellprice => 70),
                  SL::Dev::Record::create_order_item(part => $parts[1], qty => 10, sellprice => 50),
  ]
)->load;

my $purchase_order = SL::Dev::Record::create_purchase_order(
  save                    => 1,
  employee                => $employee,
  shippingpoint           => "sp",
  transaction_description => "td4",
  payment_terms           => $payment_term,
  delivery_term           => $delivery_term,
  taxincluded             => 0,
  orderitems => [ SL::Dev::Record::create_order_item(part => $parts[0], qty =>  3, sellprice => 70),
                  SL::Dev::Record::create_order_item(part => $parts[1], qty => 10, sellprice => 50),
  ]
)->load;

# convert order → reclamation
my $converted_sales_reclamation = SL::Model::Record->new_from_workflow($sales_order, "sales_reclamation");
$converted_sales_reclamation->items_sorted->[0]->reason($relamation_reason);
$converted_sales_reclamation->items_sorted->[1]->reason($relamation_reason);
$converted_sales_reclamation->save->load;
my $converted_purchase_reclamation = SL::Model::Record->new_from_workflow($purchase_order, "purchase_reclamation");
$converted_purchase_reclamation->items_sorted->[0]->reason($relamation_reason);
$converted_purchase_reclamation->items_sorted->[1]->reason($relamation_reason);
$converted_purchase_reclamation->save->load;

# TODO: use SL::Model::Record for conversion
# convert reclamation → order
my $converted_sales_order = $sales_reclamation->convert_to_order->save->load;
my $converted_purchase_order = $purchase_reclamation->convert_to_order->save->load;


#get items before strip
my @purchase_reclamation_items           = @{$purchase_reclamation->items_sorted};
my @sales_reclamation_items              = @{$sales_reclamation->items_sorted};
my @converted_purchase_reclamation_items = @{$converted_purchase_reclamation->items_sorted};
my @converted_sales_reclamation_items    = @{$converted_sales_reclamation->items_sorted};
my @purchase_order_items                 = @{$purchase_order->items_sorted};
my @sales_order_items                    = @{$sales_order->items_sorted};
my @converted_purchase_order_items       = @{$converted_purchase_order->items_sorted};
my @converted_sales_order_items          = @{$converted_sales_order->items_sorted};


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

## created sales und purchase order should be nearly the same
my $sales_order_tmp = clone($sales_order);
my $purchase_order_tmp = clone($purchase_order);
# clean different values
foreach (qw(
  customer_id vendor_id
  id
  ordnumber salesman_id
  transaction_description
  itime mtime
  )) {
  $sales_order_tmp->$_(undef);
  $purchase_order_tmp->$_(undef);
}
pairwise { my $first_tmp = clone($a); my $second_tmp = clone($b);
  foreach (qw(
    id trans_id
    itime mtime
    )) {
    $first_tmp->$_(undef);
    $second_tmp->$_(undef);
  }
  is_deeply($first_tmp->strip->as_tree, $second_tmp->strip->as_tree);
} @purchase_order_items, @sales_order_items;
is_deeply($purchase_order_tmp->strip->as_tree, $sales_order_tmp->strip->as_tree);


## converted have to be linked to parent
# sales
my $linked_sales_order = $converted_sales_reclamation->linked_records->[0];
my $linked_sales_reclamation = $converted_sales_order->linked_records->[0];
is_deeply($linked_sales_order->strip->as_tree, $sales_order->strip->as_tree);
is_deeply($linked_sales_reclamation->strip->as_tree, $sales_reclamation->load->strip->as_tree);

# purchase
my $linked_purchase_order = $converted_purchase_reclamation->linked_records->[0];
my $linked_purchase_reclamation = $converted_purchase_order->linked_records->[0];
is_deeply($linked_purchase_order->strip->as_tree, $purchase_order->strip->as_tree);
is_deeply($linked_purchase_reclamation->strip->as_tree, $purchase_reclamation->load->strip->as_tree);


## converted should be nealy the same
# sales
pairwise {
  test_deeply( $a->strip->as_tree, $b->strip->as_tree,
    "sales_order_items to sales_reclamation_items",
    qw(
      id trans_id reclamation_id itime mtime
      cusordnumber marge_percent marge_price_factor marge_total optional ordnumber ship subtotal transdate
      reason_description_ext reason_description_int reason_id
      recurring_billing_mode recurring_billing_invoice_id
    ));
} @sales_order_items, @converted_sales_reclamation_items;
test_deeply( $sales_order->strip->as_tree, $converted_sales_reclamation->strip->as_tree,
  "sales_order to sales_reclamation",
  qw(
    id employee_id itime mtime reqdate transdate
    delivery_customer_id delivery_vendor_id expected_billing_date marge_percent marge_total order_probability order_status_id proforma quonumber quotation
    cp_id contact_id
    cusordnumber cv_record_number
    ordnumber record_number
    intake
  ));

pairwise {
  test_deeply( $a->strip->as_tree, $b->strip->as_tree,
    "sales_reclamation_items to sales_order_items",
    qw(
      id trans_id reclamation_id itime mtime
      cusordnumber marge_percent marge_price_factor marge_total optional ordnumber ship subtotal transdate
      reason_description_ext reason_description_int reason_id
      recurring_billing_mode recurring_billing_invoice_id
    ));
} @sales_reclamation_items, @converted_sales_order_items;
test_deeply($sales_reclamation->strip->as_tree, $converted_sales_order->strip->as_tree,
  "sales_reclamation to sales_order",
  qw(
    id employee_id itime mtime reqdate transdate
    delivery_customer_id delivery_vendor_id expected_billing_date marge_percent marge_total order_probability order_status_id proforma quonumber quotation
    cp_id contact_id
    cusordnumber cv_record_number
    ordnumber record_number
    intake
  ));

# purchase
pairwise {
  test_deeply($a->strip->as_tree, $b->strip->as_tree,
    "purchase_order_items to purchase_reclamation_items",
    qw(
      id trans_id reclamation_id itime mtime
      cusordnumber marge_percent marge_price_factor marge_total optional ordnumber ship subtotal transdate
      reason_description_ext reason_description_int reason_id
      recurring_billing_mode recurring_billing_invoice_id
    ));
} @purchase_order_items, @converted_purchase_reclamation_items;
test_deeply($purchase_order->strip->as_tree, $converted_purchase_reclamation->strip->as_tree,
  "purchase_order to purchase_reclamation",
  qw(
    id employee_id itime mtime reqdate transdate
    delivery_customer_id delivery_vendor_id expected_billing_date marge_percent marge_total order_probability order_status_id proforma quonumber quotation
    cp_id contact_id
    cusordnumber cv_record_number
    ordnumber record_number
    intake
  ));

pairwise {
  test_deeply($a->strip->as_tree, $b->strip->as_tree,
    "purchase_reclamation_items to purchase_order_items",
    qw(
      id trans_id reclamation_id itime mtime
      cusordnumber marge_percent marge_price_factor marge_total optional ordnumber ship subtotal transdate
      reason_description_ext reason_description_int reason_id
      recurring_billing_mode recurring_billing_invoice_id
    ));
} @purchase_reclamation_items, @converted_purchase_order_items;
test_deeply($purchase_reclamation->strip->as_tree, $converted_purchase_order->strip->as_tree,
  "purchase_reclamation to purchase_order",
  qw(
    id employee_id itime mtime reqdate transdate
    delivery_customer_id delivery_vendor_id expected_billing_date marge_percent marge_total order_probability order_status_id proforma quonumber quotation
    cp_id contact_id
    cusordnumber cv_record_number
    ordnumber record_number
    intake
  ));

# diag Dumper($sales_order->strip->as_tree);
# diag Dumper($converted_sales_reclamation->strip->as_tree);

####
clear_up();

done_testing;

1;
