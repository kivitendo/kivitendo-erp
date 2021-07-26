use strict;
use Test::Deep qw(cmp_deeply ignore superhashof);
use Test::More;
use Test::Exception;

use lib 't';

use SL::Dev::Part qw(new_part new_assembly new_service);
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

my ($wh, $bin1, $bin2, $assembly1, $assembly_service, $part1, $part2, $wh_moon, $bin_moon, $service1);
my @contents;

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

local $::locale = Locale->new('en');
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

# check comments and warehouses
$::form->{l_comment}        = 'Y';
$::form->{l_warehouse_from} = 'Y';
$::form->{l_warehouse_to}   = 'Y';
local $::instance_conf->data->{produce_assembly_same_warehouse} = 1;

@contents = WH->get_warehouse_journal(sort => 'date');

cmp_deeply(\@contents,
           [ ignore(), ignore(),
              superhashof({
                'comment'        => 'Used for assembly '. $assembly1->partnumber .' Test Assembly',
                'warehouse_from' => 'Warehouse'
              }),
              superhashof({
                'comment'        => 'Used for assembly '. $assembly1->partnumber .' Test Assembly',
                'warehouse_from' => 'Warehouse'
              }),
              superhashof({
                'part_type'    => 'assembly',
                'warehouse_to' => 'Warehouse'
              }),
           ],
          "Comments for assembly productions are ok"
);

# try to produce something for our lunar warehouse, but parts are only available on earth
dies_ok(sub {
SL::Helper::Inventory::produce_assembly(
  part          => $assembly1,
  qty           => 1,
  auto_allocate => 1,
  # where to put it
  bin          => $bin_moon,
  chargenumber => "Lunar Dust inside",
);
}, "producing for wrong warehouse dies");

# same test, but check exception class
throws_ok{
SL::Helper::Inventory::produce_assembly(
  part          => $assembly1,
  qty           => 1,
  auto_allocate => 1,
  # where to put it
  bin          => $bin_moon,
  chargenumber => "Lunar Dust inside",
);
 } "SL::X::Inventory::Allocation", "producing for wrong warehouse throws correct error class";

# same test, but check user feedback for the error message
throws_ok{
SL::Helper::Inventory::produce_assembly(
  part          => $assembly1,
  qty           => 1,
  auto_allocate => 1,
  # where to put it
  bin          => $bin_moon,
  chargenumber => "Lunar Dust inside",
);
 } qr/Part ap (1|2) Testpart (1|2) exists in warehouse Warehouse, but not in warehouse Our warehouse location at the moon/, "producing for wrong warehouse throws correct error message";

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


# assembly with service default tests (services won't be consumed)

local $::locale = Locale->new('en');
reset_db();
create_standard_stock();

set_stock(
  part => $part1,
  qty => 12,
  bin => $bin2,
);
set_stock(
  part => $part2,
  qty => 6.34,
  bin => $bin2,
);

SL::Helper::Inventory::produce_assembly(
  part          => $assembly_service,
  qty           => 1,
  auto_allocate => 1,
  # where to put it
  bin          => $bin1,
);

is(SL::Helper::Inventory::get_stock(part => $assembly_service), "1.00000", 'produce with auto allocation works');
is(SL::Helper::Inventory::get_stock(part => $part1), "0.00000", 'and consumes...');
is(SL::Helper::Inventory::get_stock(part => $part2), "0.00000", '..the materials');

# check comments and warehouses
$::form->{l_comment}        = 'Y';
$::form->{l_warehouse_from} = 'Y';
$::form->{l_warehouse_to}   = 'Y';
local $::instance_conf->data->{produce_assembly_same_warehouse} = 1;

@contents = WH->get_warehouse_journal(sort => 'date');

cmp_deeply(\@contents,
           [ ignore(), ignore(),
              superhashof({
                'comment'        => 'Used for assembly '. $assembly_service->partnumber .' Ein Erzeugnis mit Dienstleistungen',
                'warehouse_from' => 'Warehouse'
              }),
              superhashof({
                'comment'        => 'Used for assembly '. $assembly_service->partnumber .' Ein Erzeugnis mit Dienstleistungen',
                'warehouse_from' => 'Warehouse'
              }),
              superhashof({
                'part_type'    => 'assembly',
                'warehouse_to' => 'Warehouse'
              }),
           ],
          "Comments for assembly with service productions are ok"
);

# assembly with service non default tests (services will be consumed)


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
  ($wh, $bin1)          = create_warehouse_and_bins();
  ($wh_moon, $bin_moon) = create_warehouse_and_bins(
      warehouse_description => 'Our warehouse location at the moon',
      bin_description       => 'Lunar crater',
    );
  $bin2 = SL::DB::Bin->new(description => "Bin 2", warehouse => $wh)->save;
  $wh->load;

  $assembly1  =  new_assembly(number_of_parts => 2)->save;
  ($part1, $part2) = map { $_->part } $assembly1->assemblies;

  my $service1 = new_service(partnumber  => "service number 1",
                             description => "We really need this service",
                            )->save;
  my $assembly_items;
  push( @{$assembly_items}, SL::DB::Assembly->new(parts_id => $part1->id,
                                                  qty      => 12,
                                                  position => 1,
                                                  ));
  push( @{$assembly_items}, SL::DB::Assembly->new(parts_id => $part2->id,
                                                  qty      => 6.34,
                                                  position => 2,
                                                  ));
  push( @{$assembly_items}, SL::DB::Assembly->new(parts_id => $service1->id,
                                                  qty      => 1.2,
                                                  position => 3,
                                                  ));
  $assembly_service  =  new_assembly(description    => 'Ein Erzeugnis mit Dienstleistungen',
                                     assembly_items => $assembly_items
                                    )->save;
}


reset_db();

done_testing();

1;
