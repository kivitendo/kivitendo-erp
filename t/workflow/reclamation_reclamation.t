use Test::More;

use strict;

use lib 't';
use utf8;

use Carp;
use Data::Dumper;
use Support::TestSetup;
use Test::Exception;
use List::MoreUtils qw(pairwise);

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
  $reclamation_reason,
);


sub clear_up {
  foreach (qw(
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

  $reclamation_reason = SL::DB::ReclamationReason->new(
    name => "test_reason",
    description => "",
    position => 1,
  );
}

Support::TestSetup::login();

reset_state();

#####

my $sales_reclamation = create_sales_reclamation(
  save                    => 1,
  employee                => $employee,
  shippingpoint           => "sp",
  transaction_description => "td1",
  payment                 => $payment_term,
  delivery_term           => $delivery_term,
  taxincluded             => 0,
  reclamation_items       => [
    create_reclamation_item(
      part => $parts[0], qty =>  3, sellprice => 70,
      reason => $reclamation_reason,
    ),
    create_reclamation_item(
      part => $parts[1], qty => 10, sellprice => 50,
      reason => $reclamation_reason,
    ),
  ],
)->load;

my $purchase_reclamation = create_purchase_reclamation(
  save                    => 1,
  employee                => $employee,
  shippingpoint           => "sp",
  transaction_description => "td2",
  payment                 => $payment_term,
  delivery_term           => $delivery_term,
  taxincluded             => 0,
  reclamation_items       => [
    create_reclamation_item(
      part => $parts[0], qty =>  3, sellprice => 70,
      reason => $reclamation_reason,
    ),
    create_reclamation_item(
      part => $parts[1], qty => 10, sellprice => 50,
      reason => $reclamation_reason,
    ),
  ],
)->load;

# new
my $new_sales_reclamation = SL::Model::Record->new_from_workflow($sales_reclamation, 'sales_reclamation')->save->load;
my $new_purchase_reclamation = SL::Model::Record->new_from_workflow($purchase_reclamation, 'purchase_reclamation')->save->load;

# convert
my $converted_purchase_reclamation = SL::Model::Record->new_from_workflow($sales_reclamation, 'purchase_reclamation');
$converted_purchase_reclamation->vendor_id($purchase_reclamation->{vendor_id});
$converted_purchase_reclamation->save->load;
my $converted_sales_reclamation = SL::Model::Record->new_from_workflow($purchase_reclamation, 'sales_reclamation');
$converted_sales_reclamation->customer_id($sales_reclamation->{customer_id});
$converted_sales_reclamation->save->load;

#get items before strip
my @purchase_reclamation_items           = @{$purchase_reclamation->items_sorted};
my @sales_reclamation_items              = @{$sales_reclamation->items_sorted};
my @new_purchase_reclamation_items       = @{$new_purchase_reclamation->items_sorted};
my @new_sales_reclamation_items          = @{$new_sales_reclamation->items_sorted};
my @converted_purchase_reclamation_items = @{$converted_purchase_reclamation->items_sorted};
my @converted_sales_reclamation_items    = @{$converted_sales_reclamation->items_sorted};


### TESTS #####################################################################

## created sales und purchase reclamation should be nearly the same
my $sales_tmp = clone($sales_reclamation);
my $purchase_tmp = clone($purchase_reclamation);
# clean different values
foreach (qw(
  customer_id vendor_id
  id record_number transaction_description
  itime mtime
  )) {
  $sales_tmp->$_(undef);
  $purchase_tmp->$_(undef);
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
is_deeply($purchase_tmp->strip->as_tree, $sales_tmp->strip->as_tree);


## converted have to be linked to parent
# new
my $linked_sales_reclamation_n = $new_sales_reclamation->linked_records->[0];
my $linked_purchase_reclamation_n = $new_purchase_reclamation->linked_records->[0];
is_deeply($linked_sales_reclamation_n->strip->as_tree, $sales_reclamation->load->strip->as_tree);
is_deeply($linked_purchase_reclamation_n->strip->as_tree, $purchase_reclamation->load->strip->as_tree);

# converted
my $linked_sales_reclamation_c = $converted_purchase_reclamation->linked_records->[0];
my $linked_purchase_reclamation_c = $converted_sales_reclamation->linked_records->[0];
is_deeply($linked_sales_reclamation_c->strip->as_tree, $sales_reclamation->load->strip->as_tree);
is_deeply($linked_purchase_reclamation_c->strip->as_tree, $purchase_reclamation->load->strip->as_tree);


## new reclamations should be nealy the same
my $new_sales_tmp = clone($new_sales_reclamation);
my $sales_tmp2 = clone($sales_reclamation);
my $new_purchase_tmp = clone($new_purchase_reclamation);
my $purchase_tmp2 = clone($purchase_reclamation);
# clean different values
foreach (qw(
  id record_number
  reqdate employee_id transdate
  itime mtime
  )) {
  $new_sales_tmp->$_(undef);
  $sales_tmp2->$_(undef);
  $new_purchase_tmp->$_(undef);
  $purchase_tmp2->$_(undef);
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
} @sales_reclamation_items, @new_sales_reclamation_items;
is_deeply($sales_tmp2->strip->as_tree, $new_sales_tmp->strip->as_tree);

pairwise { my $first_tmp = clone($a); my $second_tmp = clone($b);
  foreach (qw(
    id reclamation_id
    itime mtime
    )) {
    $first_tmp->$_(undef);
    $second_tmp->$_(undef);
  }
  is_deeply($first_tmp->strip->as_tree, $second_tmp->strip->as_tree);
} @purchase_reclamation_items, @new_purchase_reclamation_items;
is_deeply($purchase_tmp2->strip->as_tree, $new_purchase_tmp->strip->as_tree);


## converted reclamation should be nealy the same
my $sales_tmp3 = clone($sales_reclamation);
my $converted_sales_tmp = clone($converted_sales_reclamation);
my $purchase_tmp3 = clone($purchase_reclamation);
my $converted_purchase_tmp = clone($converted_purchase_reclamation);
# clean changing values
foreach (qw(
  transdate
  customer_id vendor_id
  id record_number
  employee_id reqdate
  itime mtime

  delivery_term_id
  payment_id
  )) {
  $sales_tmp3->$_(undef);
  $converted_sales_tmp->$_(undef);
  $purchase_tmp3->$_(undef);
  $converted_purchase_tmp->$_(undef);
}

# from sales to purchase
pairwise { my $first_tmp = clone($a); my $second_tmp = clone($b);
  foreach (qw(
    id reclamation_id
    sellprice discount
    itime mtime
    )) {
    $first_tmp->$_(undef);
    $second_tmp->$_(undef);
  }
  is_deeply($first_tmp->strip->as_tree, $second_tmp->strip->as_tree);
} @sales_reclamation_items, @converted_purchase_reclamation_items;
is_deeply($sales_tmp3->strip->as_tree, $converted_purchase_tmp->strip->as_tree);


# from purchase to sales
pairwise { my $first_tmp = clone($a); my $second_tmp = clone($b);
  foreach (qw(
    id reclamation_id
    lastcost
    itime mtime
    )) {
    $first_tmp->$_(undef);
    $second_tmp->$_(undef);
  }
  is_deeply($first_tmp->strip->as_tree, $second_tmp->strip->as_tree);
} @purchase_reclamation_items, @converted_sales_reclamation_items;
is_deeply($purchase_tmp3->strip->as_tree, $converted_sales_tmp->strip->as_tree);

#diag Dumper($first->strip->as_tree);
#diag Dumper($second->strip->as_tree);

####
clear_up();

done_testing;

1;

# set emacs to perl mode
# Local Variables:
# mode: perl
# End:
