use strict;
use Test::More;

use lib 't';
use Support::TestSetup;
use Carp;
use Test::Exception;
use SL::DB::Part;
use SL::Dev::Part;

Support::TestSetup::login();

clear_up();

my $assortment = SL::Dev::Part::create_assortment( partnumber         => 'aso1',
                                                   description        => "Assortment 1",
                                                   number_of_parts    => 10,
                                                 )->save;

is( SL::DB::Manager::Part->get_all_count(), 11,  "total number of parts created is 11");

$assortment = SL::DB::Manager::Part->find_by( partnumber => 'aso1' ) or die "Can't find assortment with partnumber aso1";

is($assortment->part_type,                  'assortment', 'assortment has correct part_type');
is(scalar @{$assortment->assortment_items},  10,          'assortment has 10 parts');
is($assortment->items_sellprice_sum,        100,          'assortment sellprice sum ok');
is($assortment->items_lastcost_sum,          50,          'assortment lastcost sum ok');

my $assortment_item = $assortment->assortment_items->[0];
is( $assortment_item->assortment->partnumber, 'aso1', "assortment_item links back to correct assortment");

clear_up();
done_testing;

sub clear_up {
  SL::DB::Manager::AssortmentItem->delete_all(all => 1);
  SL::DB::Manager::Part->delete_all(          all => 1);
};


1;
