use strict;
use Test::More tests => 9;

use lib 't';
use Support::TestSetup;
use Test::Exception;
use SL::DB::Part;
use SL::DB::Inventory;
use SL::DB::MakeModel;
use SL::DB::PurchaseBasketItem;
use SL::Controller::DispositionManager;
use DateTime;
use Data::Dumper;
use SL::Dev::Part qw(new_part);
use SL::Dev::Inventory qw(create_warehouse_and_bins set_stock);
use SL::Dev::CustomerVendor qw(new_vendor);

use utf8;

Support::TestSetup::login();
clear_up();

my ($wh, $bin) = create_warehouse_and_bins();
my $vendor = new_vendor()->save;

my $part1 = new_part(
  partnumber   => 'TP 1',
  description  => 'Testpart 1 rop no stock',
  sellprice    => 5,
  lastcost     => 3,
  rop          => 20,
  order_qty    => 1,
  warehouse_id => $wh->id,
  bin_id       => $bin->id,
  makemodels   => [ _create_makemodel_for_vendor(vendor => $vendor) ],
)->save;

my $part2 = new_part(
  partnumber   => 'TP 2',
  description  => 'Testpart 2 norop',
  rop          => 60,
  order_qty    => 2,
)->save;
set_stock(part => $part2, bin_id => $bin->id, qty => 80);

for my $i (1 .. 10) {
  my $part = new_part(
    partnumber   => "TPO $i",
    description  => "Testpart onhand $i",
    rop          => 50,
    order_qty    => $i+2,
    sellprice    => 5,
    lastcost     => 3,
    warehouse_id => $wh->id,
    bin_id       => $bin->id,
    makemodels   => [ _create_makemodel_for_vendor(vendor => $vendor) ],
  )->save;
  set_stock(part => $part, bin_id => $bin->id, qty => ($i * 10));
}

my $controller = SL::Controller::DispositionManager->new();
my $reorder_parts = $controller->_get_parts;
is(scalar @{$reorder_parts}, 5, "found 5 parts where onhand < rop");

# die; # die here if you want to test making basket manually

note('creating purchase basket items');
$::form = Support::TestSetup->create_new_form;
$::form->{ids} = [ map { $_->id } @{$reorder_parts} ];

# call action_add_to_purchase_basket while redirecting rendered HTML output
my $output;
open(my $outputFH, '>', \$output) or die;
my $oldFH = select $outputFH;
$controller->action_add_to_purchase_basket;
select $oldFH;
close $outputFH;

is(SL::DB::Manager::PurchaseBasketItem->get_all_count(), 5, "5 items in purchase basket ok");

# die; # die here if you want to test creating purchase orders manually

note('making purchase order from purchase basket items');
my $purchase_basket_items = SL::DB::Manager::PurchaseBasketItem->get_all;
$::form = Support::TestSetup->create_new_form;
$::form->{ids}        = [ map { $_->id       } @{ $purchase_basket_items } ];
$::form->{vendor_ids} = [ map { $vendor->id  } @{ $purchase_basket_items } ];

open($outputFH, '>', \$output) or die;
$oldFH = select $outputFH;
$controller->action_transfer_to_purchase_order;
select $oldFH;
close $outputFH;

is(SL::DB::Manager::Order->get_all_count( where => [ SL::DB::Manager::Order->type_filter('purchase_order') ] ), 1, "1 purchase order created ok");
is(SL::DB::Manager::PurchaseBasketItem->get_all_count(), 0, "purchase basket empty after purchase order was created");

my $purchase_order = SL::DB::Manager::Order->get_first();

is( scalar @{$purchase_order->items}, 5, "Purchase order has 5 item ok");
# print "PART\n";
# print Dumper($part1);
my $first_item = $purchase_order->items_sorted->[0];
# print "FIRST\n";
# print Dumper($first_item);
is( $first_item->parts_id, $part1->id, "Purchase order: first item is part1");
is( $first_item->qty, '20.00000', "Purchase order: first item has qty 20");
cmp_ok( $purchase_order->netamount, '==', 240, "Purchase order: netamount ok");
is( $first_item->active_price_source, 'makemodel/' . $part1->makemodels->[0]->id, "Purchase order: first item has correct active_price_source" . $first_item->part->partnumber);

clear_up();
done_testing();

sub clear_up {
  my %params = @_;
  SL::DB::Manager::Inventory->delete_all(all => 1);
  SL::DB::Manager::Order->delete_all(all => 1);
  SL::DB::Manager::PurchaseBasketItem->delete_all(all => 1);
  SL::DB::Manager::MakeModel->delete_all(all => 1);
  SL::DB::Manager::Part->delete_all(all => 1);
  SL::DB::Manager::Vendor->delete_all(all => 1);
  SL::DB::Manager::Customer->delete_all(all => 1);
  SL::DB::Manager::Bin->delete_all(all => 1);
  SL::DB::Manager::Warehouse->delete_all(all => 1);
};

sub _create_makemodel_for_vendor {
  my %params = @_;

  my $vendor = delete $params{vendor};
  die "no vendor" unless ref($vendor) eq 'SL::DB::Vendor';

  my $mm = SL::DB::MakeModel->new(make          => $vendor->id,
                                  model         => '',
                                  lastcost      => 2,
                                  sortorder     => 1,
                                 );
  $mm->assign_attributes( %params );
  return $mm;
}

1;
