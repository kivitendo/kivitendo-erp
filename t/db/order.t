use Test::More;

use strict;

use lib 't';
use utf8;

use Carp;
use Data::Dumper;
use Support::TestSetup;
use Test::Exception;

use SL::DB::Order;
use SL::DB::Customer;
use SL::DB::Department;
use SL::DB::Currency;
use SL::DB::PaymentTerm;
use SL::DB::DeliveryTerm;
use SL::DB::Employee;
use SL::DB::Part;
use SL::DB::Unit;

use SL::Dev::ALL qw(:ALL);

my ($customer, $employee, $payment_term, $delivery_term, $unit, @parts, $department);


sub clear_up {
  foreach (qw(OrderItem Order Part Customer Department PaymentTerm DeliveryTerm)) {
    "SL::DB::Manager::${_}"->delete_all(all => 1);
  }
  SL::DB::Manager::Employee->delete_all(where => [ login => 'testuser' ]);
};

sub reset_state {
  my %params = @_;

  clear_up();

  $unit     = SL::DB::Manager::Unit->find_by(name => 'kg') || die "Can't find unit 'kg'";
  $customer = new_customer()->save;

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
    partnumber => 'T4254',
    unit        => $unit->name,
  )->save;
  push @parts, new_service(
    partnumber => 'Serv1',
  )->save;
  push @parts, new_part(
    partnumber => 'P2445',
  )->save;
  push @parts, new_service(
    partnumber => 'Serv2'
  )->save;
}

Support::TestSetup::login();

reset_state();


#####
my $order1 = SL::Dev::Record::create_sales_order(
  save                    => 1,
  customer                => $customer,
  shippingpoint           => "sp",
  transaction_description => "td1",
  payment_terms           => $payment_term,
  delivery_term           => $delivery_term,
  taxincluded             => 0,
  orderitems => [ SL::Dev::Record::create_order_item(part => $parts[0], qty =>  3, sellprice => 70),
                  SL::Dev::Record::create_order_item(part => $parts[1], qty => 10, sellprice => 50),
  ]
);

my $delivery_term2 = SL::DB::DeliveryTerm->new(
  'description'      => 'Test Delivey Term2',
  'description_long' => 'Test Delivey Term2 Test Delivey Term2',
)->save;

my $order2 = SL::Dev::Record::create_sales_order(
  save                    => 1,
  customer                => $customer,
  shippingpoint           => "sp",
  transaction_description => "td2",
  payment_terms           => $payment_term,
  delivery_term           => $delivery_term2,
  taxincluded             => 0,
  orderitems => [ SL::Dev::Record::create_order_item(part => $parts[2], qty =>  1, sellprice => 60),
                  SL::Dev::Record::create_order_item(part => $parts[3], qty => 20, sellprice => 40),
  ]
);

my $order = SL::DB::Order->new_from_multi([$order1, $order2]);

ok    $order->items->[0]->part->id == $parts[0]->id
   && $order->items->[1]->part->id == $parts[1]->id
   && $order->items->[2]->part->id == $parts[2]->id
   && $order->items->[3]->part->id == $parts[3]->id,
  'new from multi: positions added ok';

ok $order->shippingpoint eq "sp",           'new from multi: keep same info';
ok !$order->transaction_description,        'new from multi: undefine differnt info';
ok $order->payment_id == $payment_term->id, 'new from multi: keep same info';
ok !$order->delivery_term,                  'new from multi: undefine differnt info';

reset_state();

#####
$order1 = SL::Dev::Record::create_sales_order(
  save         => 1,
  taxincluded  => 0,
  orderitems => [ SL::Dev::Record::create_order_item(part => $parts[0], qty =>  3, sellprice => 70),
                  SL::Dev::Record::create_order_item(part => $parts[1], qty => 10, sellprice => 50),
  ]
);
$order2 = SL::Dev::Record::create_sales_order(
  save         => 1,
  customer     => $customer,
  taxincluded  => 0,
  orderitems => [ SL::Dev::Record::create_order_item(part => $parts[2], qty =>  1, sellprice => 60),
                  SL::Dev::Record::create_order_item(part => $parts[3], qty => 20, sellprice => 40),
  ]
);

my $err_msg;
eval { $order = SL::DB::Order->new_from_multi([$order1, $order2]); 1 } or do {$err_msg = $@};

ok $err_msg =~ "^Cannot create order from source records of different customers", 'new from multi: fail on different customers';


####
clear_up();

done_testing;

1;


# set emacs to perl mode
# Local Variables:
# mode: perl
# End:
