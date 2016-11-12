use strict;
use Test::More;

use lib 't';
use Support::TestSetup;
use Test::Exception;
use SL::DB::Unit;
use SL::DB::Part;
use SL::DB::Assembly;
use SL::Dev::Part;

Support::TestSetup::login();

clear_up();
reset_state();

is( SL::DB::Manager::Part->get_all_count(), 4,  "total number of parts created is 4");

my $assembly_part      = SL::DB::Manager::Part->find_by( partnumber => '19000' ) || die "Can't find part 19000";
my $assembly_item_part = SL::DB::Manager::Part->find_by( partnumber => 'ap1' );

is($assembly_part->part_type, 'assembly', 'assembly has correct type');
is( scalar @{$assembly_part->assemblies}, 3, 'assembly consists of two parts' );

# fetch assembly item corresponding to partnumber 19000
my $assembly_items = $assembly_part->find_assemblies( { parts_id => $assembly_item_part->id } ) || die "can't find assembly_item";
my $assembly_item = $assembly_items->[0];
is($assembly_item->part->partnumber, 'ap1', 'assembly part part relation works');
is($assembly_item->assembly_part->partnumber, '19000', 'assembly part assembly part relation works');

clear_up();
done_testing;

sub clear_up {
  SL::DB::Manager::Assembly->delete_all(all => 1);
  SL::DB::Manager::Part->delete_all(    all => 1);
};

sub reset_state {
  my %params = @_;

  my $assembly = SL::Dev::Part::create_assembly( partnumber => '19000' )->save;
};

1;
