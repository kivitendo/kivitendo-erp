use strict;
use Test::More;

use lib 't';

use SL::Dev::Part qw(new_part new_assembly);
use SL::Dev::Inventory qw(create_warehouse_and_bins set_stock);
use SL::Dev::Record qw(create_sales_order);
use SL::DB::Helper::Reservation qw(make_reservation);

use_ok 'Support::TestSetup';
use_ok 'SL::DB::Bin';
use_ok 'SL::DB::Part';
use_ok 'SL::DB::Warehouse';
use_ok 'SL::DB::Inventory';
use_ok 'SL::WH';
use_ok 'SL::Helper::Inventory';

Support::TestSetup::login();

my ($wh, $bin1, $bin2, $assembly1);

reset_db();
create_standard_stock();


# simple stock in, get_stock, get_onhand
set_stock(
  part => $assembly1,
  qty => 25,
  bin => $bin1,
);

is(SL::Helper::Inventory::get_stock(part => $assembly1), "25.00000", 'simple get_stock works');
is(SL::Helper::Inventory::get_onhand(part => $assembly1), "25.00000", 'simple get_onhand works');

# stock on some more, get_stock, get_onhand

WH->transfer({
  parts_id          => $assembly1->id,
  qty               => 15,
  transfer_type     => 'stock',
  dst_warehouse_id  => $bin1->warehouse_id,
  dst_bin_id        => $bin1->id,
  comment           => 'more',
});

WH->transfer({
  parts_id          => $assembly1->id,
  qty               => 20,
  transfer_type     => 'stock',
  chargenumber      => '298345',
  dst_warehouse_id  => $bin1->warehouse_id,
  dst_bin_id        => $bin1->id,
  comment           => 'more',
});

is(SL::Helper::Inventory::get_stock(part => $assembly1), "60.00000", 'normal get_stock works');
is(SL::Helper::Inventory::get_onhand(part => $assembly1), "60.00000", 'normal get_onhand works');

# reserve some of it, get_stock, get_onhand

my $order = create_sales_order(save => 1);

make_reservation(
  part        => $assembly1,
  bin         => $bin1,
  reserve_for => $order,
  qty         => 25,
);

is(WH->get_stock_(part => $assembly1), "60.00000", 'normal get_stock works');
is(WH->get_onhand_(part => $assembly1), "35.00000", 'normal get_onhand works');

# allocate some stuff

my @allocations = SL::Helper::Inventory::allocate(
  part => $assembly1,
  qty  => 12,
);

is_deeply(\%{ $allocations[0] }, {
   bestbefore        => undef,
   bin_id            => $bin1->id,
   chargenumber      => '',
   parts_id          => $assembly1->id,
   qty               => 12,
   reserve_for_id    => undef,
   reserve_for_table => undef,
   warehouse_id      => $wh->id,
 }, 'allocatiion works');

# simple

# with reservation

# more than exists

# produce something

# produce the same using auto_allocation


sub reset_db {
  SL::DB::Manager::Order->delete_all(all => 1);
  SL::DB::Manager::Inventory->delete_all(all => 1);
  SL::DB::Manager::Assembly->delete_all(all => 1);
  SL::DB::Manager::Part->delete_all(all => 1);
  SL::DB::Manager::Bin->delete_all(all => 1);
  SL::DB::Manager::Warehouse->delete_all(all => 1);
}

sub create_standard_stock {
  ($wh, $bin1) = create_warehouse_and_bins();
  $bin2 = SL::DB::Bin->new(description => "Bin 2", warehouse => $wh)->save;
  $wh->load;

  $assembly1  =  new_assembly()->save;
}


reset();

done_testing();

1;
