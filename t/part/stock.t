use strict;
use Test::More;

use lib 't';
use Support::TestSetup;
use Carp;
use Test::Exception;
use SL::DB::Part;
use SL::Dev::Part;
use SL::Dev::Inventory;

Support::TestSetup::login();

clear_up();

my ($wh1, $bin1_1) = SL::Dev::Inventory::create_warehouse_and_bins(
  warehouse_description => 'Testlager',
  bin_description       => 'Testlagerplatz',
  number_of_bins        => 2,
);
my $bin1_2 = $wh1->bins->[1];
my ($wh2, $bin2_1) = SL::Dev::Inventory::create_warehouse_and_bins(
  warehouse_description => 'Testlager 2',
  bin_description       => 'Testlagerplatz 2',
  number_of_bins        => 2,
);

my $today     = DateTime->today;
my $yesterday = $today->clone->add(days => -1);

my $part = SL::Dev::Part::create_part->save;
SL::Dev::Inventory::set_stock(part => $part, bin_id => $bin1_1->id, qty => 7, shippingdate => $yesterday);
SL::Dev::Inventory::set_stock(part => $part, bin_id => $bin1_1->id, qty => 5);
SL::Dev::Inventory::set_stock(part => $part, bin_id => $bin1_1->id, abs_qty => 8); # apply -4 to get qty 8 in bin1_1
SL::Dev::Inventory::set_stock(part => $part, bin_id => $bin1_2->id, qty => 9);

SL::Dev::Inventory::set_stock(part => $part, bin_id => $bin2_1->id, abs_qty => 10);
SL::Dev::Inventory::transfer_stock(part     => $part,
                                   from_bin => $wh2->bins->[0],
                                   to_bin   => $wh2->bins->[1],
                                   qty      => 2,
                                  );

is( SL::DB::Manager::Part->get_all_count(), 1,  "total number of parts created is 1");
is( $part->get_stock == 27                                     , 1 , "total stock of part is 27");
is( $part->get_stock(shippingdate => $yesterday) == 7          , 1 , "total stock of part was 7 yesterday");
is( $part->get_stock(shippingdate => $today) == 27             , 1 , "total stock of part is 27");
is( $part->get_stock(bin_id       => $bin1_1->id) == 8         , 1 , "total stock of part in bin1_1 is 8");
is( $part->get_stock(warehouse_id => $wh1->id) == 17           , 1 , "total stock of part in wh1 is 17");
is( $part->get_stock(warehouse_id => $wh2->id) == 10           , 1 , "total stock of part in wh2 is 10");
is( $part->get_stock(bin_id       => $wh2->bins->[0]->id) == 8 , 1 , "total stock of part in wh2 2nd bin is 8 after transfer");
is( $part->get_stock(bin_id       => $wh2->bins->[1]->id) == 2 , 1 , "total stock of part in wh2 2nd bin is 2 after transfer");

clear_up();
done_testing;

sub clear_up {
  "SL::DB::Manager::${_}"->delete_all(all => 1) for qw(Inventory Part Bin Warehouse);
}

1;
