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
use SL::DB::DeliveryOrder;
use SL::DB::DeliveryOrder::TypeData qw(:types);

use SL::Dev::ALL qw(:ALL);

Support::TestSetup::login();


#######

my $order1 = SL::Dev::Record::create_purchase_order(
  save                    => 1,
  taxincluded             => 0,
);

my $delivery_order = SL::DB::DeliveryOrder->new_from($order1);

is $delivery_order->type, PURCHASE_DELIVERY_ORDER_TYPE, "new_from purchase order gives purchase delivery order";
is scalar @{ $delivery_order->items }, 2, "purchase delivery order keeps items";
is $delivery_order->vendor_id, $order1->vendor_id, "purchase delivery order keeps vendor";

my $supplier_delivery_order = SL::DB::DeliveryOrder->new_from($order1, type => SUPPLIER_DELIVERY_ORDER_TYPE);

is $supplier_delivery_order->type, SUPPLIER_DELIVERY_ORDER_TYPE, "new_from purchase order with given type gives supplier delivery order";
is scalar @{ $supplier_delivery_order->items }, 0, "supplier delivery order ignores items";
is $supplier_delivery_order->vendor_id, $order1->vendor_id, "supplier delivery order keeps vendor";

done_testing();
