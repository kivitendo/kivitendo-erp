use strict;
use Test::More;
use Test::Exception;

use lib 't';

use SL::Dev::Part qw(new_part new_assembly);
use SL::Dev::Inventory qw(create_warehouse_and_bins set_stock);
use SL::Dev::Record qw(create_sales_order);

use_ok 'Support::TestSetup';
use_ok 'SL::DB::Bin';
use_ok 'SL::DB::Part';
use_ok 'SL::DB::Warehouse';
use_ok 'SL::DB::Inventory';
use_ok 'SL::WH';
use_ok 'SL::Helper::Inventory';

Support::TestSetup::login();

my ($wh, $bin1, $bin2, $assembly1, $part1, $part2);

reset_db();
create_standard_stock();


# simple stock in, get_stock, get_onhand
set_stock(
  part => $part1,
  qty => 25,
  bin => $bin1,
);

is(SL::Helper::Inventory::get_stock(part => $part1), "25.00000", 'simple get_stock works');
is(SL::Helper::Inventory::get_onhand(part => $part1), "25.00000", 'simple get_onhand works');

# stock on some more, get_stock, get_onhand

WH->transfer({
  parts_id          => $part1->id,
  qty               => 15,
  transfer_type     => 'stock',
  dst_warehouse_id  => $bin1->warehouse_id,
  dst_bin_id        => $bin1->id,
  comment           => 'more',
});

WH->transfer({
  parts_id          => $part1->id,
  qty               => 20,
  transfer_type     => 'stock',
  chargenumber      => '298345',
  dst_warehouse_id  => $bin1->warehouse_id,
  dst_bin_id        => $bin1->id,
  comment           => 'more',
});

is(SL::Helper::Inventory::get_stock(part => $part1), "60.00000", 'normal get_stock works');
is(SL::Helper::Inventory::get_onhand(part => $part1), "60.00000", 'normal get_onhand works');

# allocate some stuff

my @allocations = SL::Helper::Inventory::allocate(
  part => $part1,
  qty  => 12,
);

is_deeply(\%{ $allocations[0] }, {
   bestbefore        => undef,
   bin_id            => $bin1->id,
   chargenumber      => '',
   parts_id          => $part1->id,
   qty               => 12,
   warehouse_id      => $wh->id,
   comment           => undef, # comment is not a partition so is not set by allocate
   for_object_id     => undef,
 }, 'allocation works');

# allocate something where more than one result will match

@allocations = SL::Helper::Inventory::allocate(
  part => $part1,
  qty  => 55,
);

is_deeply(\@allocations, [
  {
    bestbefore        => undef,
    bin_id            => $bin1->id,
    chargenumber      => '',
    parts_id          => $part1->id,
    qty               => '40.00000',
    warehouse_id      => $wh->id,
    comment           => undef,
    for_object_id     => undef,
  },
  {
    bestbefore        => undef,
    bin_id            => $bin1->id,
    chargenumber      => '298345',
    parts_id          => $part1->id,
    qty               => '15',
    warehouse_id      => $wh->id,
    comment           => undef,
    for_object_id     => undef,
  }
], 'complex allocation works');

# try to allocate too much

dies_ok(sub {
  SL::Helper::Inventory::allocate(part => $part1, qty => 100)
},
"allocate too much dies");

# produce something

reset_db();
create_standard_stock();

set_stock(
  part => $part1,
  qty => 5,
  bin => $bin1,
);
set_stock(
  part => $part2,
  qty => 10,
  bin => $bin1,
);


my @alloc1 = SL::Helper::Inventory::allocate(part => $part1, qty => 3);
my @alloc2 = SL::Helper::Inventory::allocate(part => $part2, qty => 3);

SL::Helper::Inventory::produce_assembly(
  part          => $assembly1,
  qty           => 3,
  allocations => [ @alloc1, @alloc2 ],

  # where to put it
  bin          => $bin1,
  chargenumber => "537",
);

is(SL::Helper::Inventory::get_stock(part => $assembly1), "3.00000", 'produce works');
is(SL::Helper::Inventory::get_stock(part => $part1), "2.00000", 'and consumes...');
is(SL::Helper::Inventory::get_stock(part => $part2), "7.00000", '..the materials');

# produce the same using auto_allocation

reset_db();
create_standard_stock();

set_stock(
  part => $part1,
  qty => 5,
  bin => $bin1,
);
set_stock(
  part => $part2,
  qty => 10,
  bin => $bin1,
);

SL::Helper::Inventory::produce_assembly(
  part          => $assembly1,
  qty           => 3,
  auto_allocate => 1,

  # where to put it
  bin          => $bin1,
  chargenumber => "537",
);

is(SL::Helper::Inventory::get_stock(part => $assembly1), "3.00000", 'produce with auto allocation works');
is(SL::Helper::Inventory::get_stock(part => $part1), "2.00000", 'and consumes...');
is(SL::Helper::Inventory::get_stock(part => $part2), "7.00000", '..the materials');

# try to produce without allocations dies

dies_ok(sub {
SL::Helper::Inventory::produce_assembly(
  part          => $assembly1,
  qty           => 3,

  # where to put it
  bin          => $bin1,
  chargenumber => "537",
);
}, "producing without allocations dies");

# try to produce with insufficient allocations dies

@alloc1 = SL::Helper::Inventory::allocate(part => $part1, qty => 1);
@alloc2 = SL::Helper::Inventory::allocate(part => $part2, qty => 1);

dies_ok(sub {
SL::Helper::Inventory::produce_assembly(
  part          => $assembly1,
  qty           => 3,
  allocations => [ @alloc1, @alloc2 ],

  # where to put it
  bin          => $bin1,
  chargenumber => "537",
);
}, "producing with insufficient allocations dies");



# bestbefore tests

reset_db();
create_standard_stock();

set_stock(
  part => $part1,
  qty => 5,
  bin => $bin1,
);
set_stock(
  part => $part2,
  qty => 10,
  bin => $bin1,
);



SL::Helper::Inventory::produce_assembly(
  part          => $assembly1,
  qty           => 3,
  auto_allocate => 1,

  bin               => $bin1,
  chargenumber      => "537",
  bestbefore        => DateTime->today->clone->add(days => -14), # expired 2 weeks ago
  shippingdate      => DateTime->today->clone->add(days => 1),
);

is(SL::Helper::Inventory::get_stock(part => $assembly1), "3.00000", 'produce with bestbefore works');
is(SL::Helper::Inventory::get_onhand(part => $assembly1), "3.00000", 'produce with bestbefore works');
is(SL::Helper::Inventory::get_stock(
  part       => $assembly1,
  bestbefore => DateTime->today,
), undef, 'get_stock with bestbefore date skips expired');
{
  local $::instance_conf->data->{show_bestbefore} = 1;
  is(SL::Helper::Inventory::get_onhand(
    part       => $assembly1,
  ), undef, 'get_onhand with bestbefore skips expired as of today');
}

{
  local $::instance_conf->data->{show_bestbefore} = 0;
  is(SL::Helper::Inventory::get_onhand(
    part       => $assembly1,
  ), "3.00000", 'get_onhand without bestbefore finds all');
}


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

  $assembly1  =  new_assembly(number_of_parts => 2)->save;
  ($part1, $part2) = map { $_->part } $assembly1->assemblies;
}


reset_db();

done_testing();

1;
