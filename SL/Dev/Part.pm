package SL::Dev::Part;

use strict;
use base qw(Exporter);
our @EXPORT_OK = qw(new_part new_service new_assembly new_assortment);
our %EXPORT_TAGS = (ALL => \@EXPORT_OK);

use SL::DB::Part;
use SL::DB::Unit;
use SL::DB::Buchungsgruppe;

sub new_part {
  my (%params) = @_;

  my $part = SL::DB::Part->new_part(
    description        => 'Test part',
    sellprice          => '10',
    lastcost           => '5',
    buchungsgruppen_id => _default_buchungsgruppe()->id,
    unit               => _default_unit()->name
  );
  $part->assign_attributes( %params );
  return $part;
}

sub new_service {
  my (%params) = @_;

  my $part = SL::DB::Part->new_service(
    description        => 'Test service',
    sellprice          => '10',
    lastcost           => '5',
    buchungsgruppen_id => _default_buchungsgruppe()->id,
    unit               => _default_unit()->name
  );
  $part->assign_attributes( %params );
  return $part;
}

sub new_assembly {
  my (%params) = @_;

  my $assnumber       = delete $params{assnumber};
  my $base_partnumber = delete $params{partnumber} || 'ap';

  my $assembly_items = [];

  if ( $params{assembly_items} ) {
    $assembly_items = delete $params{assembly_items};
  } else {
    for my $i ( 1 .. delete $params{number_of_parts} || 3) {
      my $part = new_part(partnumber  => "$base_partnumber $i",
                             description => "Testpart $i",
                            )->save;
      push( @{$assembly_items}, SL::DB::Assembly->new(parts_id => $part->id,
                                                      qty      => 1,
                                                      position => $i,
                                                     ));
    }
  }

  my $assembly = SL::DB::Part->new_assembly(
    partnumber         => $assnumber,
    description        => 'Test Assembly',
    sellprice          => '10',
    lastcost           => '5',
    assemblies         => $assembly_items,
    buchungsgruppen_id => _default_buchungsgruppe()->id,
    unit               => _default_unit()->name
  );
  $assembly->assign_attributes( %params );
  return $assembly;
}

sub new_assortment {
  my (%params) = @_;

  my $assnumber       = delete $params{assnumber};
  my $base_partnumber = delete $params{partnumber} || 'ap';

  my $assortment_items = [];

  if ( $params{assortment_items} ) {
    $assortment_items = delete $params{assortment_items};
  } else {
    for my $i ( 1 .. delete $params{number_of_parts} || 3) {
      my $part = new_part(partnumber  => "$base_partnumber $i",
                             description => "Testpart $i",
                            )->save;
      push( @{$assortment_items}, SL::DB::AssortmentItem->new(parts_id => $part->id,
                                                              qty      => 1,
                                                              position => $i,
                                                              unit     => $part->unit,
                                                             ));
    }
  }

  my $assortment = SL::DB::Part->new_assortment(
    partnumber         => $assnumber,
    description        => 'Test Assortment',
    sellprice          => '10',
    lastcost           => '5',
    assortment_items   => $assortment_items,
    buchungsgruppen_id => _default_buchungsgruppe()->id,
    unit               => _default_unit()->name
  );

  $assortment->assign_attributes( %params );
  return $assortment;
}


sub _default_buchungsgruppe {
  return SL::DB::Manager::Buchungsgruppe->find_by(description => 'Standard 19%') || die "No accounting group";
}

sub _default_unit {
  return SL::DB::Manager::Unit->find_by(name => 'Stck') || die "No unit";
}


1;

__END__

=head1 NAME

SL::Dev::Part - create part objects for testing, with minimal defaults

=head1 SYNOPSIS

  use SL::Dev::Part qw(new_part new_assembly new_service new_assortment);

  # simple default objects
  my $part     = new_part()->save;
  my $assembly = new_assembly()->save;
  my $service  = new_service()->save;
  my $assortment = new_assortment()->save;

  # pass additional params to the generated object
  # see individual functions for special parameters
  my $part     = new_part(
    partnumber   => 'Test 001',
    warehouse_id => $bin->warehouse->id,
    bin_id       => $bin->id,
  );

=head1 FUNCTIONS

=head2 C<new_part %PARAMS>

Creates a new part (part_type = part).

=head2 C<new_service %PARAMS>

Creates a new service (part_type = service).

=head2 C<new_assembly %PARAMS>

Create a new assembly (part_type = assembly).

Special params:

=over 2

=item * C<number_of_parts>

The number of automatically created assembly parts.

=item * C<assnumber>

the partnumber of the assembly

=item * C<partnumber>

the partnumber of the first assembly part to be created

=back

By default 3 parts (p1, p2, p3) are created and saved as an assembly (as1).

Create a new assembly with 10 parts, the assembly gets partnumber 'Ass1' and the
parts get partnumbers 'Testpart 1' to 'Testpart 10':

  my $assembly = SL::Dev::Part::new_assembly(
    number_of_parts => 10,
    partnumber      => 'Testpart',
    assnumber       => 'Ass1'
  )->save;

Create an assembly with specific parts:

  my $assembly_item_1 = SL::DB::Assembly->new( parts_id => $part1->id, qty => 3, position => 1);
  my $assembly_item_2 = SL::DB::Assembly->new( parts_id => $part2->id, qty => 3, position => 2);
  my $assembly_part   = new_assembly(
    assnumber      => 'Assembly 1',
    description    => 'Assembly test',
    sellprice      => $part1->sellprice + $part2->sellprice,
    assembly_items => [ $assembly_item_1, $assembly_item_2 ],
  );

=head2 C<new_assortment %PARAMS>

Create a new assortment (part_type = assortment).

Special params:

=over 2

=item * C<number_of_parts>

The number of automatically created assembly parts.

=item * C<assnumber>

the partnumber of the assortment

=item * C<partnumber>

the partnumber of the first assembly part to be created

=back

By default 3 parts (p1, p2, p3) are created and saved as an assortment.

Create a new assortment with 10 automatically created parts using the
number_of_parts param:

  my $assortment = new_assortment(number_of_parts => 10)->save;

Create an assortment with a certain name and pass some assortment_item Objects
from newly created parts:

  my $part1             = new_part(sellprice => 7.77)->save;
  my $part2             = new_part(sellprice => 6.66)->save;
  my $assortment_item_1 = SL::DB::AssortmentItem->new( parts_id => $part1->id, qty => 3, unit => $part1->unit, position => 1);
  my $assortment_item_2 = SL::DB::AssortmentItem->new( parts_id => $part2->id, qty => 3, unit => $part2->unit, position => 2);
  my $assortment_part   = SL::Dev::Part::new_assortment(
    assnumber        => 'Assortment 1',
    description      => 'assortment test',
    sellprice        => (3*$part1->sellprice + 3*$part2->sellprice),
    lastcost         => (3*$part1->lastcost  + 3*$part2->lastcost),
    assortment_items => [ $assortment_item_1, $assortment_item_2 ],
  )->save;

=head1 TODO

Nothing here yet.

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

G. Richardson E<lt>grichardson@kivitendo-premium.deE<gt>

=cut
