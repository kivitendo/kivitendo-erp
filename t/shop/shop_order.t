use strict;
use Test::More;

use lib 't';
use Support::TestSetup;
use Carp;
use Test::Exception;
use SL::Dev::ALL;
use SL::DB::Shop;
use SL::DB::ShopOrder;
use SL::DB::ShopOrderItem;
use SL::Controller::ShopOrder;
use Data::Dumper;

my ($shop, $shop_order, $shop_part, $part, $customer, $employee);

sub reset_state {
  my %params = @_;

  clear_up();

  $shop = SL::Dev::Shop::new_shop->save;
  $part = SL::Dev::Part::new_part->save;
  $shop_part = SL::Dev::Shop::new_shop_part(part => $part, shop => $shop)->save;

  $employee = SL::DB::Manager::Employee->current || croak "No employee";

  $customer = SL::Dev::CustomerVendor::new_customer(
    name    => 'Evil Inc',
    street  => 'Evil Street',
    zipcode => '66666',
    email   => 'evil@evilinc.com'
  )->save;
}

sub save_shorcontroller_to_string {

  my $output;
  open(my $outputFH, '<', \$output) or die "OUTPUT";
  my $oldFH = select $outputFH;
  my $shor_controller = SL::Controller::ShopOrder->new;
  $shor_controller->action_transfer;

  select $oldFH;
  close $outputFH;
  return $output;
}
sub test_transfer {
  my ( %params ) = @_;
  $::form = Support::TestSetup->create_new_form;
  $::form->{import_id} = $params{import_id};
  $::form->{customer} =  $params{customer};
  my $test_name = 'Test Controller Action Transfer';
  save_shorcontroller_to_string();
  my @links_record = RecordLinks->get_links( 'from_table' => 'shop_orders',
                                            'from_id'    => $params{import_id},
                                            'to_table'   => 'oe',
                                          );
  is($links_record[0]->{from_id}    , $params{import_id}, "record from id check");
  is($links_record[0]->{from_table} , 'shop_orders'     , "record from table <shop_orders> check");
  is($links_record[0]->{to_table}   , 'oe'              , "record to table <oe> check");
}

Support::TestSetup::login();

reset_state();

my $shop_trans_id = 1;

$shop_order = SL::Dev::Shop::new_shop_order(
  shop              => $shop,
  shop_trans_id     => $shop_trans_id,
  amount            => 59.5,
  billing_lastname  => 'Schmidt',
  billing_firstname => 'Sven',
  billing_company   => 'Evil Inc',
  billing_street    => 'Evil Street',
  billing_zipcode   => $customer->zipcode,
  billing_email     => $customer->email,
);

my $shop_order_item = SL::DB::ShopOrderItem->new(
  partnumber    => $part->partnumber,
  position      => 1,
  quantity      => 5,
  price         => 10,
  shop_trans_id => $shop_trans_id,
);
$shop_order->shop_order_items( [ $shop_order_item ] );
$shop_order->save;

note('testing check_for_existing_customers');
my $fuzzy_customers = $shop_order->check_for_existing_customers;

is(scalar @{ $fuzzy_customers }, 1, 'found 1 matching customer');
is($fuzzy_customers->[0]->name, 'Evil Inc', 'matched customer Evil Inc');

note('adding a not-so-similar customer');
my $customer_different = SL::Dev::CustomerVendor::new_customer(
  name    => "Different Name",
  street  => 'Good Straet', # difference large enough from "Evil Street"
  zipcode => $customer->zipcode,
  email   => "foo",
)->save;
$fuzzy_customers = $shop_order->check_for_existing_customers;
is(scalar @{ $fuzzy_customers }, 1, 'still only found 1 matching customer (zipcode equal + street dissimilar');

note('adding a similar customer');
my $customer_similar = SL::Dev::CustomerVendor::new_customer(
  name    => "Different Name",
  street  => 'Good Street', # difference not large enough from "Evil Street", street matches
  zipcode => $customer->zipcode,
  email   => "foo",
)->save;
$fuzzy_customers = $shop_order->check_for_existing_customers;
is(scalar @{ $fuzzy_customers }, 2, 'found 2 matching customers (zipcode equal + street similar)');

is($shop->description   , 'testshop' , 'shop description ok');
is($shop_order->shop_id , $shop->id  , "shop_id ok");

note('testing convert_to_sales_order');
my $order = $shop_order->convert_to_sales_order(employee => $employee, customer => $customer);
$order->calculate_prices_and_taxes;
$order->save;

is(ref($order), 'SL::DB::Order', 'order ok');
is($order->amount,    59.5, 'order amount ok');
is($order->netamount, 50,   'order netamount ok');

test_transfer( import_id => $shop_order->id , customer => $customer->id );

done_testing;

clear_up();

1;

sub clear_up {
  "SL::DB::Manager::${_}"->delete_all(all => 1) for qw(OrderItem Order);
  "SL::DB::Manager::${_}"->delete_all(all => 1) for qw(ShopPart Part ShopOrderItem ShopOrder Shop Customer);
}
