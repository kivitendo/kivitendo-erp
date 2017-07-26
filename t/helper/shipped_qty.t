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
use SL::Dev::ALL;
use SL::Helper::ShippedQty;
use DateTime;

Support::TestSetup::login();

clear_up();

my ($customer, $vendor, @parts, $unit);

$customer = SL::Dev::CustomerVendor::create_customer(name => 'Testkunde'    )->save;
$vendor   = SL::Dev::CustomerVendor::create_vendor(  name => 'Testlieferant')->save;

my $default_sellprice = 10;
my $default_lastcost  =  4;

my ($wh) = SL::Dev::Inventory::create_warehouse_and_bins();
my $bin1 = SL::DB::Manager::Bin->find_by(description => "Bin 1");
my $bin2 = SL::DB::Manager::Bin->find_by(description => "Bin 2");

my %part_defaults = (
    sellprice    => $default_sellprice,
    warehouse_id => $wh->id,
    bin_id       => $bin1->id
);

# create 3 parts to be used in test
for my $i ( 1 .. 4 ) {
  SL::Dev::Part::create_part( %part_defaults, partnumber => $i, description => "part $i test" )->save;
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

my $purchase_order = SL::Dev::Record::create_purchase_order(
  save       => 1,
  orderitems => [ SL::Dev::Record::create_order_item(part => $part1, qty => 11),
                  SL::Dev::Record::create_order_item(part => $part2, qty => 12),
                  SL::Dev::Record::create_order_item(part => $part3, qty => 13),
                ]
);

SL::Helper::ShippedQty
  ->new(require_stock_out => 1)  # should make no difference while there is no delivery order
  ->calculate($purchase_order)
  ->write_to_objects;

is($purchase_order->orderitems->[0]->{shipped_qty}, 0, "first purchase orderitem has no shipped_qty");
is($purchase_order->orderitems->[0]->{delivered},   '', "first purchase orderitem is not delivered");

my $purchase_orderitem_part1 = SL::DB::Manager::OrderItem->find_by( parts_id => $part1->id, trans_id => $purchase_order->id);

is($purchase_orderitem_part1->shipped_qty, 0, "OrderItem shipped_qty method ok");

is($purchase_order->closed,     0, 'purchase order is open');
is($purchase_order->delivered, '', 'purchase order is not delivered');

note('converting purchase order to delivery order');
# create purchase delivery order from purchase order
my $purchase_delivery_order = $purchase_order->convert_to_delivery_order;
is($purchase_order->closed,    0, 'purchase order is open');
is($purchase_order->delivered, 1, 'purchase order is now delivered');

SL::Helper::ShippedQty
  ->new(require_stock_out => 0)
  ->calculate($purchase_order)
  ->write_to_objects;

is($purchase_order->orderitems->[0]->{shipped_qty}, 11, "require_stock_out => 0: first purchase orderitem has shipped_qty");
is($purchase_order->orderitems->[0]->{delivered},    1, "require_stock_out => 0: first purchase orderitem is delivered");

Rose::DB::Object::Helpers::forget_related($purchase_order, 'orderitems');
$purchase_order->orderitems;

SL::Helper::ShippedQty
  ->new(require_stock_out => 1)
  ->calculate($purchase_order)
  ->write_to_objects;

is($purchase_order->orderitems->[0]->{shipped_qty}, 0,  "require_stock_out => 1: first purchase orderitem has no shipped_qty");
is($purchase_order->orderitems->[0]->{delivered},   '', "require_stock_out => 1: first purchase orderitem is not delivered");

# ship items from delivery order
SL::Dev::Inventory::transfer_purchase_delivery_order($purchase_delivery_order);

Rose::DB::Object::Helpers::forget_related($purchase_order, 'orderitems');
$purchase_order->orderitems;

SL::Helper::ShippedQty
  ->new(require_stock_out => 1)  # shouldn't make a difference now after shipping
  ->calculate($purchase_order)
  ->write_to_objects;

is($purchase_order->orderitems->[0]->{shipped_qty}, 11, "require_stock_out => 1: first purchase orderitem has shipped_qty");
is($purchase_order->orderitems->[0]->{delivered},    1, "require_stock_out => 1: first purchase orderitem is delivered");

my $purchase_orderitem_part2 = SL::DB::Manager::OrderItem->find_by(parts_id => $part1->id, trans_id => $purchase_order->id);

is($purchase_orderitem_part2->shipped_qty(require_stock_out => 1), 11, "OrderItem shipped_qty from helper ok");


note('testing sales, no fill_up');

my $sales_order = SL::Dev::Record::create_sales_order(
  save       => 1,
  orderitems => [ SL::Dev::Record::create_order_item(part => $part1, qty => 5),
                  SL::Dev::Record::create_order_item(part => $part2, qty => 6),
                  SL::Dev::Record::create_order_item(part => $part3, qty => 7),
                ]
);

SL::Helper::ShippedQty
  ->new(require_stock_out => 1)  # should make no difference while there is no delivery order
  ->calculate($sales_order)
  ->write_to_objects;

is($sales_order->orderitems->[0]->{shipped_qty}, 0,  "first sales orderitem has no shipped_qty");
is($sales_order->orderitems->[0]->{delivered},   '', "first sales orderitem is not delivered");

my $orderitem_part1 = SL::DB::Manager::OrderItem->find_by(parts_id => $part1->id, trans_id => $sales_order->id);
my $orderitem_part2 = SL::DB::Manager::OrderItem->find_by(parts_id => $part2->id, trans_id => $sales_order->id);

is($orderitem_part1->shipped_qty, 0, "OrderItem shipped_qty method ok");

# create sales delivery order from sales order
my $sales_delivery_order = $sales_order->convert_to_delivery_order;

SL::Helper::ShippedQty
  ->new(require_stock_out => 0)
  ->calculate($sales_order)
  ->write_to_objects;

is($sales_order->orderitems->[0]->{shipped_qty}, 5, "require_stock_out => 0: first sales orderitem has shipped_qty");
is($sales_order->orderitems->[0]->{delivered},   1, "require_stock_out => 0: first sales orderitem is delivered");

Rose::DB::Object::Helpers::forget_related($sales_order, 'orderitems');
$sales_order->orderitems;

SL::Helper::ShippedQty
  ->new(require_stock_out => 1)
  ->calculate($sales_order)
  ->write_to_objects;

is($sales_order->orderitems->[0]->{shipped_qty}, 0,  "require_stock_out => 1: first sales orderitem has no shipped_qty");
is($sales_order->orderitems->[0]->{delivered},   '', "require_stock_out => 1: first sales orderitem is not delivered");

# ship items from delivery order
SL::Dev::Inventory::transfer_sales_delivery_order($sales_delivery_order);

Rose::DB::Object::Helpers::forget_related($sales_order, 'orderitems');
$sales_order->orderitems;

SL::Helper::ShippedQty
  ->new(require_stock_out => 1)
  ->calculate($sales_order)
  ->write_to_objects;

is($sales_order->orderitems->[0]->{shipped_qty}, 5, "require_stock_out => 1: first sales orderitem has no shipped_qty");
is($sales_order->orderitems->[0]->{delivered},   1, "require_stock_out => 1: first sales orderitem is not delivered");

$orderitem_part1 = SL::DB::Manager::OrderItem->find_by(parts_id => $part1->id, trans_id => $sales_order->id);

is($orderitem_part1->shipped_qty(require_stock_out => 1), 5, "OrderItem shipped_qty from helper ok");


note('misc tests');
my $number_of_linked_items = SL::DB::Manager::RecordLink->get_all_count( where => [ from_table => 'orderitems', to_table => 'delivery_order_items' ] );
is ($number_of_linked_items , 6, "6 record_links for items, 3 from sales order, 3 from purchase order");

clear_up();

done_testing;

sub clear_up {
  foreach ( qw(Inventory DeliveryOrderItem DeliveryOrder Price OrderItem Order Part Customer Vendor Bin Warehouse) ) {
    "SL::DB::Manager::${_}"->delete_all(all => 1);
  }
};
