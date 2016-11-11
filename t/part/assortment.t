use strict;
use Test::More;

use lib 't';
use Support::TestSetup;
use Carp;
use Test::Exception;
use SL::DB::Unit;
use SL::DB::Part;
use Data::Dumper;

Support::TestSetup::login();

clear_up();
reset_state();

is( SL::DB::Manager::Part->get_all_count(), 3,  "total number of parts created is 3");

my $assortment = SL::DB::Manager::Part->find_by( partnumber => 'as1' );

is($assortment->part_type,                  'assortment', 'assortment has correct part_type');
is(scalar @{$assortment->assortment_items},  2,           'assortment has two parts');
is($assortment->items_sellprice_sum,        19.98,        'assortment sellprice sum ok');
is($assortment->items_lastcost_sum,         13.32,        'assortment lastcost sum ok');

my $assortment_item = $assortment->assortment_items->[0];
is( $assortment_item->assortment->partnumber, 'as1', "assortment_item links back to correct assortment");

clear_up();
done_testing;

sub reset_state {
  my %params = @_;

  # SL::DB::Manager::AssortmentItem->delete_all(all => 1);
  # SL::DB::Manager::Part->delete_all(all => 1);
  my ($part1, $part2, $unit, $assortment_part, $assortment_1, $assortment_2);

  $unit = SL::DB::Manager::Unit->find_by(name => 'Stck') || die "Can't find unit 'Stck'";
  $part1 = SL::DB::Part->new_part( partnumber         => '7777',
                                   description        => "assortment part 1",
                                   unit               => $unit->name,
                                   sellprice          => '3.33',
                                   lastcost           => '2.22',
                                 )->save;
  $part2 = $part1->clone_and_reset($part1);
  $part2->partnumber( $part1->partnumber + 1 );
  $part2->description( "assortment part 2" );
  $part2->save;

  $assortment_part = SL::DB::Part->new_assortment( partnumber         => 'as1',
                                                   description        => 'assortment',
                                                   sellprice          => '0',
                                                   unit               => $unit->name);
  $assortment_1 = SL::DB::AssortmentItem->new( parts_id => $part1->id, qty => 3, unit => $part1->unit, position => 1);
  $assortment_2 = SL::DB::AssortmentItem->new( parts_id => $part2->id, qty => 3, unit => $part2->unit, position => 2);
  $assortment_part->add_assortment_items($assortment_1, $assortment_2);
  $assortment_part->save or die "Couldn't save assortment";

};

sub clear_up {
  SL::DB::Manager::AssortmentItem->delete_all(all => 1);
  SL::DB::Manager::Part->delete_all(          all => 1);
};


1;
