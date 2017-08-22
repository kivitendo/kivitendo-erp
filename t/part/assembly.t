use strict;
use Test::More;

use lib 't';
use Support::TestSetup;
use Test::Exception;
use SL::DB::Unit;
use SL::DB::Part;
use SL::DB::Assembly;
use SL::Dev::Part qw(new_assembly);
use SL::DB::Helper::ValidateAssembly;

Support::TestSetup::login();
$::locale        = Locale->new("en");

clear_up();
reset_state();

is( SL::DB::Manager::Part->get_all_count(), 4,  "total number of parts created by reset_state() is 4");

my $assembly_part      = SL::DB::Manager::Part->find_by( partnumber => '19000' )   || die "Can't find assembly 19000";
my $assembly_item_part = SL::DB::Manager::Part->find_by( partnumber => '19000 1' ) || die "Can't find assembly item part '19000 1'";

is($assembly_part->part_type, 'assembly', 'assembly has correct type');
is( scalar @{$assembly_part->assemblies}, 3, 'assembly consists of three parts' );

# fetch assembly item corresponding to partnumber 19000
my $assembly_items = $assembly_part->find_assemblies( { parts_id => $assembly_item_part->id } ) || die "can't find assembly_item";
my $assembly_item = $assembly_items->[0];
is($assembly_item->part->partnumber, '19000 1', 'assembly part part relation works');
is($assembly_item->assembly_part->partnumber, '19000', 'assembly part assembly part relation works');



my $assembly2_part = new_assembly( partnumber => '20000', assnumber => 'as2' )->save;
my $retval = validate_assembly($assembly_part,$assembly2_part);
ok(!defined $retval, 'assembly 19000 can be child of assembly 20000' );
$assembly2_part->add_assemblies(SL::DB::Assembly->new(parts_id => $assembly_part->id, qty => 3, bom => 1));
$assembly2_part->save;

my $assembly3_part = new_assembly( partnumber => '30000', assnumber => 'as3' )->save;
$retval = validate_assembly($assembly3_part,$assembly_part);
ok(!defined $retval, 'assembly 30000 can be child of assembly 19000' );

$retval = validate_assembly($assembly3_part,$assembly2_part);
ok(!defined $retval, 'assembly 30000 can be child of assembly 20000' );

$assembly_part->add_assemblies(SL::DB::Assembly->new(parts_id => $assembly3_part->id, qty => 4, bom => 1));
$assembly_part->save;

$retval = validate_assembly($assembly3_part,$assembly2_part);
ok(!defined $retval, 'assembly 30000 can be child of assembly 20000' );

$assembly2_part->add_assemblies(SL::DB::Assembly->new(parts_id => $assembly3_part->id, qty => 5, bom => 1));
$assembly2_part->save;

# fetch assembly item corresponding to partnumber 20000
my $assembly2_items = $assembly2_part->find_assemblies() || die "can't find assembly_item";
is( scalar @{$assembly2_items}, 5, 'assembly2 consists of ive parts' );
my $assembly2_item = $assembly2_items->[3];
is($assembly2_item->qty, 3, 'qty of 3rd assembly item is 3' );
is($assembly2_item->part->part_type, 'assembly', '3rd assembly item \'' . $assembly2_item->part->partnumber . '\' is also an assembly');
my $assembly3_items = $assembly2_item->part->find_assemblies() || die "can't find assembly_item";
is( scalar @{$assembly3_items}, 4, 'assembly3 consists of four parts' );



# check loop to itself
$retval = validate_assembly($assembly_part,$assembly_part);
is( $retval,"The assembly '19000' cannot be a part from itself.", 'assembly loops to itself' );
if (!$retval && $assembly_part->add_assemblies( SL::DB::Assembly->new(parts_id => $assembly_part->id, qty => 8, bom => 1))) {
  $assembly_part->save;
}
is( scalar @{$assembly_part->assemblies}, 4, 'assembly consists of four parts' );

# check indirekt loop
$retval = validate_assembly($assembly2_part,$assembly_part);
ok( $retval, 'assembly indirect loop' );
if (!$retval && $assembly_part->add_assemblies( SL::DB::Assembly->new(parts_id => $assembly2_part->id, qty => 9, bom => 1))) {
  $assembly_part->save;
}
is( scalar @{$assembly_part->assemblies}, 4, 'assembly consists of four parts' );

clear_up();
done_testing;

sub clear_up {
  SL::DB::Manager::Assembly->delete_all(all => 1);
  SL::DB::Manager::Part->delete_all(    all => 1);
};

sub reset_state {
  my %params = @_;

  my $assembly = new_assembly( assnumber => '19000', partnumber => '19000' )->save;
};

1;
