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

# same test, but check exception class and error messages
throws_ok{
SL::Helper::Inventory::produce_assembly(
  part          => $assembly1,
  qty           => 1,
  auto_allocate => 1,
  # where to put it
  bin          => $bin_moon,
  chargenumber => "Lunar Dust inside",
);
} "SL::X::Inventory::Allocation::Multi", "producing for wrong warehouse throws correct error class";
my $e = $@;
like $e, qr/multiple errors during allocation/, "producing for wrong warehouse throws correct error message for multiple errors";
like $e->errors->[0]->message, qr/Part ap (1|2) Testpart (1|2) exists in warehouse Warehouse, but not in warehouse Our warehouse location at the moon/,
  "producing for wrong warehouse throws correct error message";

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


# check with own allocations
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
@alloc1 = SL::Helper::Inventory::allocate(part => $part1, qty => 12);
@alloc2 = SL::Helper::Inventory::allocate(part => $part2, qty => 6.34);

lives_ok {
  SL::Helper::Inventory::produce_assembly(
    part          => $assembly_service,
    qty           => 1,
    allocations => [ @alloc1, @alloc2 ],

    # where to put it
    bin          => $bin1,
  );
} 'no exception on produce_assembly with own allocations (no service)';

is(SL::Helper::Inventory::get_stock(part => $assembly_service), "2.00000", 'produce with own allocations works');
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
             ignore(), ignore(),
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

local $::instance_conf->data->{produce_assembly_transfer_service} = 1;

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

throws_ok{
  SL::Helper::Inventory::produce_assembly(
    part          => $assembly_service,
    qty           => 1,
    auto_allocate => 1,
    # where to put it
    bin          => $bin1,
  );
} "SL::X::Inventory::Allocation::Multi", "producing assembly with services and unstocked service throws correct error class";
$e = $@;
like $e, qr/multiple errors during allocation/, "producing assembly with services and unstocked service throws correct error message for multiple errors";
like $e->errors->[0]->message, qr/can not allocate 1,2 units of service number 1 We really need this service, missing 1,2 units/,
  "producing assembly with services and unstocked service throws correct error message";

is(SL::Helper::Inventory::get_stock(part => $assembly_service), "2.00000", 'produce without service does not work');
is(SL::Helper::Inventory::get_stock(part => $part1), "12.00000", 'and does not consume...');
is(SL::Helper::Inventory::get_stock(part => $part2), "6.34000", '..the materials');


# ok, now add the missing service
is('SL::DB::Part', ref $service1);
set_stock(
  part => $service1,
  qty => 1.2,
  bin => $bin2,
);

SL::Helper::Inventory::produce_assembly(
  part          => $assembly_service,
  qty           => 1,
  auto_allocate => 1,
  # where to put it
  bin          => $bin1,
);

is(SL::Helper::Inventory::get_stock(part => $assembly_service), "3.00000", 'produce with service does work if services is needed and stocked');
is(SL::Helper::Inventory::get_stock(part => $part1), "0.00000", 'and does consume...');
is(SL::Helper::Inventory::get_stock(part => $part2), "0.00000", '..the materials');
is(SL::Helper::Inventory::get_stock(part => $service1), "0.00000", '..and service');

# check with own allocations
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
is('SL::DB::Part', ref $service1);
set_stock(
  part => $service1,
  qty => 1.2,
  bin => $bin2,
);

@alloc1    = SL::Helper::Inventory::allocate(part => $part1,    qty => 12);
@alloc2    = SL::Helper::Inventory::allocate(part => $part2,    qty => 6.34);
my @alloc3 = SL::Helper::Inventory::allocate(part => $service1, qty => 1.2);

lives_ok {
  SL::Helper::Inventory::produce_assembly(
    part          => $assembly_service,
    qty           => 1,
    allocations => [ @alloc1, @alloc2, @alloc3 ],

    # where to put it
    bin          => $bin1,
  );
} 'no exception on produce_assembly with own allocations (with service)';

is(SL::Helper::Inventory::get_stock(part => $assembly_service), "4.00000", 'produce with own allocations and service does work if services is needed and stocked');
is(SL::Helper::Inventory::get_stock(part => $part1), "0.00000", 'and does consume...');
is(SL::Helper::Inventory::get_stock(part => $part2), "0.00000", '..the materials');
is(SL::Helper::Inventory::get_stock(part => $service1), "0.00000", '..and service');

# check comments and warehouses for assembly with service
$::form->{l_comment}        = 'Y';
$::form->{l_warehouse_from} = 'Y';
$::form->{l_warehouse_to}   = 'Y';
local $::instance_conf->data->{produce_assembly_same_warehouse} = 1;

@contents = WH->get_warehouse_journal(sort => 'date');
#use Data::Dumper;
#diag("hier" . Dumper(@contents));
cmp_deeply(\@contents,
           [ ignore(), ignore(), ignore(), ignore(), ignore(), ignore(), ignore(), ignore(), ignore(), ignore(), ignore(), ignore(), ignore(),
              superhashof({
                'comment'        => 'Used for assembly '. $assembly_service->partnumber .' Ein Erzeugnis mit Dienstleistungen',
                'warehouse_from' => 'Warehouse'
              }),
              superhashof({
                'comment'        => 'Used for assembly '. $assembly_service->partnumber .' Ein Erzeugnis mit Dienstleistungen',
                'warehouse_from' => 'Warehouse'
              }),
              superhashof({
                'comment'        => 'Used for assembly '. $assembly_service->partnumber .' Ein Erzeugnis mit Dienstleistungen',
                'warehouse_from' => 'Warehouse',
                'part_type'      => 'service',
                'qty'            => '1.20000',
              }),
              superhashof({
                'part_type'    => 'assembly',
                'warehouse_to' => 'Warehouse'
              }),
             ignore(), ignore(), ignore(),
             superhashof({
                'comment'        => 'Used for assembly '. $assembly_service->partnumber .' Ein Erzeugnis mit Dienstleistungen',
                'warehouse_from' => 'Warehouse'
              }),
              superhashof({
                'comment'        => 'Used for assembly '. $assembly_service->partnumber .' Ein Erzeugnis mit Dienstleistungen',
                'warehouse_from' => 'Warehouse'
              }),
              superhashof({
                'comment'        => 'Used for assembly '. $assembly_service->partnumber .' Ein Erzeugnis mit Dienstleistungen',
                'warehouse_from' => 'Warehouse',
                'part_type'      => 'service',
                'qty'            => '1.20000',
              }),
              superhashof({
                'part_type'    => 'assembly',
                'warehouse_to' => 'Warehouse'
              }),
           ],
          "Comments for assembly with service productions are ok"
);



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


# test DB backend function bins, bins_sorted and bins_sorted_naturally

reset_db();
create_standard_stock();

$wh_moon->add_bins(SL::DB::Bin->new(description => "1A"));
$wh_moon->add_bins(SL::DB::Bin->new(description => "HomeOffice"));
$wh_moon->add_bins(SL::DB::Bin->new(description => "A2"));
$wh_moon->add_bins(SL::DB::Bin->new(description => "Z3"));
$wh_moon->add_bins(SL::DB::Bin->new(description => "a apple1"));
$wh_moon->save();

$wh_moon->load();

my @bins                   = map  { $_->description } @{ $wh_moon->bins };        # id
my @bins_sorted            = map  { $_->description } @{ $wh_moon->bins_sorted }; # id
my @bins_sorted_naturally  = map  { $_->description } @{ $wh_moon->bins_sorted_naturally }; # description

#diag explain @bins;
#diag explain @bins_sorted;
#diag explain @bins_sorted_naturally;
cmp_deeply(\@bins,
           ["Lunar crater 1", "Lunar crater 2", "Lunar crater 3", "Lunar crater 4",
            "Lunar crater 5", "1A", "HomeOffice", "A2", "Z3", "a apple1"],
           "Bins for warehouse moon sorted by default (default (id))"
          );

cmp_deeply(\@bins_sorted,
           ["Lunar crater 1", "Lunar crater 2", "Lunar crater 3", "Lunar crater 4",
            "Lunar crater 5", "1A", "HomeOffice", "A2", "Z3", "a apple1"],
           "Bins for warehouse moon sorted by id"
          );

cmp_deeply(\@bins_sorted_naturally,
           ["1A", "a apple1", "A2", "HomeOffice", "Lunar crater 1", "Lunar crater 2", "Lunar crater 3", "Lunar crater 4",
            "Lunar crater 5", "Z3"],
           "Bins for warehouse moon sorted naturally"
          );

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

  $service1 = new_service(partnumber  => "service number 1",
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
