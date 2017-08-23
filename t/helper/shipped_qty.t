use strict;
use Test::More;

use lib 't';
use Support::TestSetup;
use Carp;
use Test::Exception;
use Data::Dumper;
use SL::DB::Part;
use SL::DB::Inventory;
use SL::DB::TransferType;
use SL::DB::Order;
use SL::DB::DeliveryOrder;
use SL::DB::Customer;
use SL::DB::Vendor;
use SL::DB::RecordLink;
use SL::DB::DeliveryOrderItemsStock;
use SL::DB::Bin;
use SL::WH;
use SL::AM;
use SL::Dev::ALL qw(:ALL);
use SL::Helper::ShippedQty;
use DateTime;

Support::TestSetup::login();

clear_up();

my ($customer, $vendor, @parts, $unit);

$customer = new_customer(name => 'Testkunde'    )->save;
$vendor   = new_vendor(  name => 'Testlieferant')->save;

my $default_sellprice = 10;
my $default_lastcost  =  4;

my ($wh) = create_warehouse_and_bins();
my $bin1 = SL::DB::Manager::Bin->find_by(description => "Bin 1");
my $bin2 = SL::DB::Manager::Bin->find_by(description => "Bin 2");

my %part_defaults = (
    sellprice    => $default_sellprice,
    warehouse_id => $wh->id,
    bin_id       => $bin1->id
);

# create 3 parts to be used in test
for my $i ( 1 .. 4 ) {
  new_part( %part_defaults, partnumber => $i, description => "part $i test" )->save;
};

my $part1 = SL::DB::Manager::Part->find_by( partnumber => '1' );
my $part2 = SL::DB::Manager::Part->find_by( partnumber => '2' );
my $part3 = SL::DB::Manager::Part->find_by( partnumber => '3' );
my $part4 = SL::DB::Manager::Part->find_by( partnumber => '4' );

my @part_ids; # list of all part_ids to run checks against
push( @part_ids, $_->id ) foreach ( $part1, $part2, $part3, $part4 );
my %default_transfer_params = ( wh => $wh, bin => $bin1, unit => 'Stck');


# test purchases first, so there is actually stock available when sales is tested

note("testing purchases, no fill_up");

my $purchase_order = create_purchase_order(
  save       => 1,
  orderitems => [ create_order_item(part => $part1, qty => 11),
                  create_order_item(part => $part2, qty => 12),
                  create_order_item(part => $part3, qty => 13),
                ]
);

Rose::DB::Object::Helpers::forget_related($purchase_order, 'orderitems');
$purchase_order->orderitems;

SL::Helper::ShippedQty
  ->new(require_stock_out => 1)  # should make no difference while there is no delivery order
  ->calculate($purchase_order)
  ->write_to_objects;

is($purchase_order->items_sorted->[0]->{shipped_qty}, 0, "first purchase orderitem has no shipped_qty");
ok(!$purchase_order->items_sorted->[0]->{delivered},     "first purchase orderitem is not delivered");

my $purchase_orderitem_part1 = SL::DB::Manager::OrderItem->find_by( parts_id => $part1->id, trans_id => $purchase_order->id);

is($purchase_orderitem_part1->shipped_qty, 0, "OrderItem shipped_qty method ok");

is($purchase_order->closed,     0, 'purchase order is open');
ok(!$purchase_order->delivered,    'purchase order is not delivered');

note('converting purchase order to delivery order');
# create purchase delivery order from purchase order
my $purchase_delivery_order = $purchase_order->convert_to_delivery_order;
is($purchase_order->closed,    0, 'purchase order is open');
ok($purchase_order->delivered,    'purchase order is now delivered');

SL::Helper::ShippedQty
  ->new(require_stock_out => 0)
  ->calculate($purchase_order)
  ->write_to_objects;

is($purchase_order->items_sorted->[0]->{shipped_qty}, 11, "require_stock_out => 0: first purchase orderitem has shipped_qty");
ok($purchase_order->items_sorted->[0]->{delivered},       "require_stock_out => 0: first purchase orderitem is delivered");

Rose::DB::Object::Helpers::forget_related($purchase_order, 'orderitems');
$purchase_order->orderitems;

SL::Helper::ShippedQty
  ->new(require_stock_out => 1)
  ->calculate($purchase_order)
  ->write_to_objects;

is($purchase_order->items_sorted->[0]->{shipped_qty}, 0,  "require_stock_out => 1: first purchase orderitem has no shipped_qty");
ok(!$purchase_order->items_sorted->[0]->{delivered},      "require_stock_out => 1: first purchase orderitem is not delivered");

# ship items from delivery order
transfer_purchase_delivery_order($purchase_delivery_order);

Rose::DB::Object::Helpers::forget_related($purchase_order, 'orderitems');
$purchase_order->orderitems;

SL::Helper::ShippedQty
  ->new(require_stock_out => 1, keep_matches => 1)  # shouldn't make a difference now after shipping
  ->calculate($purchase_order)
  ->write_to_objects;

is($purchase_order->items_sorted->[0]->{shipped_qty}, 11, "require_stock_out => 1: first purchase orderitem has shipped_qty");
ok($purchase_order->items_sorted->[0]->{delivered},       "require_stock_out => 1: first purchase orderitem is delivered");

my $purchase_orderitem_part2 = SL::DB::Manager::OrderItem->find_by(parts_id => $part1->id, trans_id => $purchase_order->id);

is($purchase_orderitem_part2->shipped_qty(require_stock_out => 1), 11, "OrderItem shipped_qty from helper ok");


note('testing sales, no fill_up');

my $sales_order = create_sales_order(
  save       => 1,
  orderitems => [ create_order_item(part => $part1, qty => 5),
                  create_order_item(part => $part2, qty => 6),
                  create_order_item(part => $part3, qty => 7),
                ]
);

Rose::DB::Object::Helpers::forget_related($sales_order, 'orderitems');
$sales_order->orderitems;

SL::Helper::ShippedQty
  ->new(require_stock_out => 1)  # should make no difference while there is no delivery order
  ->calculate($sales_order)
  ->write_to_objects;

is($sales_order->items_sorted->[0]->{shipped_qty}, 0,  "first sales orderitem has no shipped_qty");
ok(!$sales_order->items_sorted->[0]->{delivered},      "first sales orderitem is not delivered");

my $orderitem_part1 = SL::DB::Manager::OrderItem->find_by(parts_id => $part1->id, trans_id => $sales_order->id);
my $orderitem_part2 = SL::DB::Manager::OrderItem->find_by(parts_id => $part2->id, trans_id => $sales_order->id);

is($orderitem_part1->shipped_qty, 0, "OrderItem shipped_qty method ok");

# create sales delivery order from sales order
my $sales_delivery_order = $sales_order->convert_to_delivery_order;

SL::Helper::ShippedQty
  ->new(require_stock_out => 0)
  ->calculate($sales_order)
  ->write_to_objects;

is($sales_order->items_sorted->[0]->{shipped_qty}, 5, "require_stock_out => 0: first sales orderitem has shipped_qty");
ok($sales_order->items_sorted->[0]->{delivered},      "require_stock_out => 0: first sales orderitem is delivered");

Rose::DB::Object::Helpers::forget_related($sales_order, 'orderitems');
$sales_order->orderitems;

SL::Helper::ShippedQty
  ->new(require_stock_out => 1)
  ->calculate($sales_order)
  ->write_to_objects;

is($sales_order->items_sorted->[0]->{shipped_qty}, 0,  "require_stock_out => 1: first sales orderitem has no shipped_qty");
ok(!$sales_order->items_sorted->[0]->{delivered},      "require_stock_out => 1: first sales orderitem is not delivered");

# ship items from delivery order
transfer_sales_delivery_order($sales_delivery_order);

Rose::DB::Object::Helpers::forget_related($sales_order, 'orderitems');
$sales_order->orderitems;

SL::Helper::ShippedQty
  ->new(require_stock_out => 1)
  ->calculate($sales_order)
  ->write_to_objects;

is($sales_order->items_sorted->[0]->{shipped_qty}, 5, "require_stock_out => 1: first sales orderitem has no shipped_qty");
ok($sales_order->items_sorted->[0]->{delivered},      "require_stock_out => 1: first sales orderitem is not delivered");

$orderitem_part1 = SL::DB::Manager::OrderItem->find_by(parts_id => $part1->id, trans_id => $sales_order->id);

is($orderitem_part1->shipped_qty(require_stock_out => 1), 5, "OrderItem shipped_qty from helper ok");


note('misc tests');
my $number_of_linked_items = SL::DB::Manager::RecordLink->get_all_count( where => [ from_table => 'orderitems', to_table => 'delivery_order_items' ] );
is ($number_of_linked_items , 6, "6 record_links for items, 3 from sales order, 3 from purchase order");

clear_up();

{
#  legacy unlinked scenario:
#
#  order with two positions of the same part, qtys: 5, 3.
#  3 linked delivery orders, with positions:
#    1:  3 unlinked
#    2:  1 linked to 1, 3 linked to 2
#    3:  1 linked to 1
#
#  should be resolved under fill_up as 5/3, but gets resolved as 4/4
  my $part = new_part()->save;
  my $order = create_sales_order(
    orderitems => [
      create_order_item(part => $part, qty => 5),
      create_order_item(part => $part, qty => 3),
    ],
  )->save;
  my $do1 = create_sales_delivery_order(
    orderitems => [
      create_delivery_order_item(part => $part, qty => 3),
    ],
  );
  my $do2 = create_sales_delivery_order(
    orderitems => [
      create_delivery_order_item(part => $part, qty => 1),
      create_delivery_order_item(part => $part, qty => 3),
    ],
  );
  my $do3 = create_sales_delivery_order(
    orderitems => [
      create_delivery_order_item(part => $part, qty => 1),
    ],
  );
  $order->link_to_record($do1);
  $order->link_to_record($do2);
  $order->items_sorted->[0]->link_to_record($do2->items_sorted->[0]);
  $order->items_sorted->[1]->link_to_record($do2->items_sorted->[1]);
  $order->link_to_record($do3);
  $order->items_sorted->[0]->link_to_record($do3->items->[0]);

  SL::Helper::ShippedQty
    ->new(fill_up => 1, require_stock_out => 0)
    ->calculate($order)
    ->write_to_objects;

  is $order->items_sorted->[0]->{shipped_qty}, 5, 'unlinked legacy position test 1';
  is $order->items_sorted->[1]->{shipped_qty}, 3, 'unlinked legacy position test 2';
}

clear_up();

done_testing;

sub clear_up {
  foreach ( qw(Inventory DeliveryOrderItem DeliveryOrder Price OrderItem Order Part Customer Vendor Bin Warehouse) ) {
    "SL::DB::Manager::${_}"->delete_all(all => 1);
  }
};
