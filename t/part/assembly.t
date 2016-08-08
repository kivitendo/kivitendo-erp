use strict;
use Test::More;

use lib 't';
use Support::TestSetup;
use Test::Exception;
use SL::DB::Unit;
use SL::DB::Part;
use SL::DB::Assembly;

Support::TestSetup::login();

clear_up();
reset_state();

is( SL::DB::Manager::Part->get_all_count(), 3,  "total number of parts created is 3");

my $assembly_part      = SL::DB::Manager::Part->find_by( partnumber => 'as1' );
my $assembly_item_part = SL::DB::Manager::Part->find_by( partnumber => '19000' );

is($assembly_part->part_type, 'assembly', 'assembly has correct type');
is( scalar @{$assembly_part->assemblies}, 2, 'assembly consists of two parts' );

# fetch assembly item corresponding to partnumber 19000
my $assembly_items = $assembly_part->find_assemblies( { parts_id => $assembly_item_part->id } ) || die "can't find assembly_item";
my $assembly_item = $assembly_items->[0];
is($assembly_item->part->partnumber, '19000', 'assembly part part relation works');
is($assembly_item->assembly_part->partnumber, 'as1', 'assembly part assembly part relation works');

clear_up();
done_testing;

sub clear_up {
  SL::DB::Manager::Assembly->delete_all(all => 1);
  SL::DB::Manager::Part->delete_all(    all => 1);
};

sub reset_state {
  my %params = @_;

  # create an assembly that consists of two parts
  my ($part1, $part2, $unit, $assembly_part, $assembly_1, $assembly_2);
  $unit = SL::DB::Manager::Unit->find_by(name => 'Stck') || die "Can't find unit 'Stck'";

  $part1 = SL::DB::Part->new_part(partnumber => '19000',
                                  unit       => $unit->name,
                                  part_type  => 'part',
                                 )->save;
  $part2 = $part1->clone_and_reset($part1);
  $part2->partnumber($part1->partnumber + 1);
  $part2->save;

  $assembly_part = SL::DB::Part->new_assembly(partnumber         => 'as1',
                                                 description        => 'assembly',
                                                 unit               => $unit->name,
                                                );
  $assembly_1 = SL::DB::Assembly->new(parts_id => $part1->id, qty => 3, bom => 1);
  $assembly_2 = SL::DB::Assembly->new(parts_id => $part2->id, qty => 3, bom => 1);
  $assembly_part->add_assemblies($assembly_1, $assembly_2);
  $assembly_part->save;
};

1;
