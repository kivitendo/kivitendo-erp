use Test::More tests => 34;

use strict;

use lib 't';
use utf8;

use Support::TestSetup;

use List::MoreUtils qw(none any);

use SL::Controller::CsvImport;
use_ok 'SL::Controller::CsvImport::DeliveryOrder';

use SL::DB::DeliveryOrder::TypeData qw(:types);

use SL::Dev::ALL qw(:ALL);

Support::TestSetup::login();

#####
sub do_import {
  my ($file, $settings) = @_;

  my $controller = SL::Controller::CsvImport->new(
    type => 'delivery_orders',
  );
  $controller->load_default_profile;
  $controller->profile->set(
    charset  => 'utf-8',
    sep_char => ';',
    %$settings
  );

  my $worker = SL::Controller::CsvImport::DeliveryOrder->new(
    controller => $controller,
    file       => $file,
  );
  $worker->run(test => 0);

  return if $worker->controller->errors;

  # don't try and save objects that have errors
  $worker->save_objects unless scalar @{$worker->controller->data->[0]->{errors}};

  return $worker->controller->data;
}

sub clear_up {
  foreach (qw(RecordLink Order DeliveryOrder Customer Part)) {
    "SL::DB::Manager::${_}"->delete_all(all => 1);
  }
  SL::DB::Manager::Employee->delete_all(where => [ '!login' => 'unittests' ]);
}

#####

# set numberformat and locale (so we can match errors)
my $old_numberformat      = $::myconfig{numberformat};
$::myconfig{numberformat} = '1.000,00';
my $old_locale            = $::locale;
$::locale                 = Locale->new('en');

clear_up;

#####
my @customers;
my @parts;
my @orders;
my $file;
my $entries;
my $entry;

# simple import
@customers = (new_customer(name => 'TestCustomer1', discount => 0)->save);
@parts = (
  new_part(description => 'TestPart1', ean => '')->save,
  new_part(description => 'TestPart2', ean => '')->save
);

$file = \<<EOL;
datatype;customer
datatype;description;qty
datatype
DeliveryOrder;TestCustomer1
OrderItem;TestPart1;5
OrderItem;TestPart2;10
EOL

$entries = do_import($file);

$entry = $entries->[0];
is $entry->{object}->customer_id, $customers[0]->id, 'simple import: customer_id';

$entry = $entries->[1];
is $entry->{object}->parts_id,    $parts[0]->id,     'simple import: part 1: parts_id';
is $entry->{object}->qty,         5,                 'simple import: part 1: qty';

$entry = $entries->[2];
is $entry->{object}->parts_id,    $parts[1]->id,     'simple import: part 2: parts_id';
is $entry->{object}->qty,         10,                'simple import: part 2: qty';

$entries = undef;

#####
# test handling of record type
#####
$file = \<<EOL;
datatype;customer;vendor
datatype;description;qty
datatype
DeliveryOrder;TestCustomer1
OrderItem;TestPart1;5
DeliveryOrder;;TestVendor1
OrderItem;TestPart2;10
EOL

$entries = do_import($file);

$entry = $entries->[0];
is $entry->{object}->record_type, SALES_DELIVERY_ORDER_TYPE, 'record type is sales order when customer given';

$entry = $entries->[2];
is $entry->{object}->record_type, PURCHASE_DELIVERY_ORDER_TYPE, 'record type is purchase order when vendor given';

$entries = undef;

$file = \<<EOL;
datatype;customer;vendor;record_type
datatype;description;qty
datatype
DeliveryOrder;TestCustomer1;;sales_delivery_order
OrderItem;TestPart1;1
DeliveryOrder;;TestVendor1;purchase_delivery_order
OrderItem;TestPart2;2
DeliveryOrder;TestVendor11;;supplier_delivery_order
OrderItem;TestPart1;3
DeliveryOrder;;TestCustomer1;rma_delivery_order
OrderItem;TestPart1;4
EOL

$entries = do_import($file);

$entry = $entries->[0];
is $entry->{object}->record_type, SALES_DELIVERY_ORDER_TYPE, '"sales_delivery_order" as explicitly given record type works';
$entry = $entries->[2];
is $entry->{object}->record_type, PURCHASE_DELIVERY_ORDER_TYPE, '"purchase_delivery_order" as explicitly given record type works';
$entry = $entries->[4];
is $entry->{object}->record_type, SUPPLIER_DELIVERY_ORDER_TYPE, '"supplier_delivery_order" as explicitly given record type works';
$entry = $entries->[6];
is $entry->{object}->record_type, RMA_DELIVERY_ORDER_TYPE, '"rma_delivery_order" as explicitly given record type works';
$entry = $entries->[8];

$entries = undef;
clear_up;

#####
# with source order
@customers = (new_customer(name => 'TestCustomer1', discount => 0)->save);
@parts = (
  new_part(description => 'TestPart1', ean => '')->save,
  new_part(description => 'TestPart2', ean => '')->save,
  new_part(description => 'TestPart3', ean => '')->save
);
@orders = (
  create_sales_order(
    save       => 1,
    customer   => $customers[0],
    ordnumber  => '1234',
    orderitems => [ create_order_item(part => $parts[0], qty =>  3, sellprice => 70),
                    create_order_item(part => $parts[1], qty => 10, sellprice => 50),
                    create_order_item(part => $parts[2], qty =>  8, sellprice => 80),
                    create_order_item(part => $parts[2], qty => 11, sellprice => 80)
    ]
  )
);

$file = \<<EOL;
datatype;customer;ordnumber
datatype;description;qty
datatype
DeliveryOrder;TestCustomer1;1234
OrderItem;TestPart1;5
OrderItem;TestPart2;10
OrderItem;TestPart3;7
OrderItem;TestPart3;1
OrderItem;TestPart3;11
EOL

  1;                            # make emacs happy

# should be:
# delivery oder pos/qty <- order pos/qty
#       1/5             <-       -
#       2/10            <-      2/10
#       3/7             <-      3/7
#       4/1             <-      3/1
#       5/11            <-      4/11

$entries = do_import($file);
$orders[0]->load;               # reload order to get correct delivered status

$entry = $entries->[0];
is $entry->{object}->ordnumber, '1234', 'with source order: ordnumber';

my $linked = $orders[0]->linked_records(to => 'DeliveryOrder');
ok(scalar @$linked == 1, 'with source order: order linked to one delivery order');
ok($linked->[0]->id == $entry->{object}->id, 'with source order: order linked to imported delivery order');


$linked = $entry->{object}->linked_records(from => 'Order');
ok(scalar @$linked == 1, 'with source order: delivery order linked from one order');
ok($linked->[0]->id == $orders[0]->id, 'with source order: delivery order linked from source order');

$entry = $entries->[1];
$linked = $entry->{object}->linked_records(from => 'OrderItem');
ok(scalar @$linked == 0, 'with source order: delivered qty > ordered qty: delivery order item not linked');

$entry = $entries->[2];
$linked = $entry->{object}->linked_records(from => 'OrderItem');
ok(scalar @$linked == 1, 'with source order: same qtys: delivery order item linked');
ok($linked->[0]->id == $orders[0]->items_sorted->[1]->id, 'with source order: same qtys: delivery order item linked from source order item');

$entry = $entries->[3];
$linked = $entry->{object}->linked_records(from => 'OrderItem');
ok(scalar @$linked == 1, 'with source order: delivered qty < ordered qty: delivery order item linked (fill up)');
ok($linked->[0]->position == 3, 'with source order: delivered qty < ordered qty: order position ok (fill up)');

$entry = $entries->[4];
$linked = $entry->{object}->linked_records(from => 'OrderItem');
ok(scalar @$linked == 1, 'with source order: delivered qty < ordered qty: delivery order item linked (fill up) 2');
ok($linked->[0]->position == 3, 'with source order: delivered qty < ordered qty: order position ok (fill up) 2');

$entry = $entries->[5];
$linked = $entry->{object}->linked_records(from => 'OrderItem');
ok(scalar @$linked == 1, 'with source order: delivered qty == ordered qty: found exact match after fill up');
ok($linked->[0]->position == 4, 'with source order: delivered qty == ordered qty: order position ok after fill up');

ok(!$orders[0]->delivered, 'with source order: order not completely delivered');

$entries = undef;
clear_up;

#####
@customers = (new_customer(name => 'TestCustomer1', discount => 0)->save);
@parts = (
  new_part(description => 'TestPart1', ean => '')->save,
  new_part(description => 'TestPart2', ean => '')->save,
  new_part(description => 'TestPart3', ean => '')->save
);
@orders = (
  create_sales_order(
    save       => 1,
    customer   => $customers[0],
    ordnumber  => '1234',
    orderitems => [ create_order_item(part => $parts[0], qty =>  3, sellprice => 70),
                    create_order_item(part => $parts[1], qty => 10, sellprice => 50),
                    create_order_item(part => $parts[2], qty =>  8, sellprice => 80),
                    create_order_item(part => $parts[2], qty => 11, sellprice => 80)
    ]
  )
);

$file = \<<EOL;
datatype;customer;ordnumber
datatype;description;qty
datatype
DeliveryOrder;TestCustomer1;1234
OrderItem;TestPart1;1
OrderItem;TestPart2;10
OrderItem;TestPart1;2
OrderItem;TestPart3;7
OrderItem;TestPart3;11
OrderItem;TestPart3;1

EOL

  1;                            # make emacs happy

# should be:
# delivery oder pos/qty <- order pos/qty
#       1/1             <-      1/1
#       2/10            <-      2/10
#       3/2             <-      1/2
#       4/7             <-      3/7
#       5/11            <-      4/11
#       6/1             <-      3/1

$entries = do_import($file);
$orders[0]->load;               # reload order to get correct delivered status

$entry = $entries->[1];
$linked = $entry->{object}->linked_records(from => 'OrderItem');
ok($linked->[0]->position == 1, 'with source order: mixed qtys and fill up: order position ok 1');

$entry = $entries->[2];
$linked = $entry->{object}->linked_records(from => 'OrderItem');
ok($linked->[0]->position == 2, 'with source order: mixed qtys and fill up: order position ok 2');

$entry = $entries->[3];
$linked = $entry->{object}->linked_records(from => 'OrderItem');
ok($linked->[0]->position == 1, 'with source order: mixed qtys and fill up: order position ok 3');

$entry = $entries->[4];
$linked = $entry->{object}->linked_records(from => 'OrderItem');
ok($linked->[0]->position == 3, 'with source order: mixed qtys and fill up: order position ok 4');

$entry = $entries->[5];
$linked = $entry->{object}->linked_records(from => 'OrderItem');
ok($linked->[0]->position == 4, 'with source order: mixed qtys and fill up: order position ok 5');

$entry = $entries->[6];
$linked = $entry->{object}->linked_records(from => 'OrderItem');
ok($linked->[0]->position == 3, 'with source order: mixed qtys and fill up: order position ok 6');

ok(!!$orders[0]->delivered, 'with source order: mixed qtys and fill up: order completely delivered');

#####
$entries = undef;
clear_up;

#####

$::myconfig{numberformat} = $old_numberformat;
$::locale                 = $old_locale;

1;

#####
# vim: ft=perl
# set emacs to perl mode
# Local Variables:
# mode: perl
# End:
