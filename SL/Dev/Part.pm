package SL::Dev::Part;

use strict;
use base qw(Exporter);
our @EXPORT = qw(create_part create_service);

use SL::DB::Part;
use SL::DB::Unit;
use SL::DB::Buchungsgruppe;

sub create_part {
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

sub create_service {
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

sub create_assembly {
  my (%params) = @_;

  my @parts;
  my $part1 = SL::Dev::Part::create_part(partnumber   => 'ap1',
                                         description  => 'Testpart',
                                        )->save;
  push(@parts, $part1);

  my $number_of_parts = delete $params{number_of_parts} || 3;

  for my $i ( 2 .. $number_of_parts ) {
    my $part = $parts[0]->clone_and_reset;
    $part->partnumber(  ($part->partnumber  // '') . " " . $i );
    $part->description( ($part->description // '') . " " . $i );
    $part->save;
    push(@parts, $part);
  }

  my $assembly = SL::DB::Part->new_assembly(
    partnumber         => 'as1',
    description        => 'Test Assembly',
    sellprice          => '10',
    lastcost           => '5',
    buchungsgruppen_id => _default_buchungsgruppe()->id,
    unit               => _default_unit()->name
  );

  foreach my $part ( @parts ) {
    $assembly->add_assemblies( SL::DB::Assembly->new(parts_id => $part->id, qty => 1, bom => 1) );
  }
  $assembly->assign_attributes( %params );
  return $assembly;
}

sub create_assortment {
  my (%params) = @_;

  my @parts;
  my $part1 = SL::Dev::Part::create_part(partnumber   => 'sp1',
                                         description  => 'Testpart assortment',
                                        )->save;
  push(@parts, $part1);

  my $number_of_parts = delete $params{number_of_parts} || 3;

  for my $i ( 2 .. $number_of_parts ) {
    my $part = $parts[0]->clone_and_reset;
    $part->partnumber(  ($part->partnumber  // '') . " " . $i );
    $part->description( ($part->description // '') . " " . $i );
    $part->save;
    push(@parts, $part);
  }

  my $assortment = SL::DB::Part->new_assortment(
    partnumber         => 'as1',
    description        => 'Test Assortment',
    sellprice          => '10',
    lastcost           => '5',
    buchungsgruppen_id => _default_buchungsgruppe()->id,
    unit               => _default_unit()->name
  );

  my $position = 0;
  foreach my $part ( @parts ) {
    $assortment->add_assortment_items( SL::DB::AssortmentItem->new(parts_id => $part->id,
                                                                   qty      => 1,
                                                                   position => $position++,
                                                                   charge   => 1,
                                                                   unit     => $part->unit,
                                                                  ));
  }
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

=head1 FUNCTIONS

=head2 C<create_part %PARAMS>

Creates a new part (part_type = part).

Minimal usage, default values, without saving to database:

  my $part = SL::Dev::Part::create_part();

Create a test part with a default warehouse and bin and save it:

  my $wh    = SL::Dev::Inventory::create_warehouse_and_bins()->save;
  my $part1 = SL::Dev::Part::create_part(partnumber   => 'a123',
                                         description  => 'Testpart 1',
                                         warehouse_id => $wh->id,
                                         bin_id       => $wh->bins->[0]->id,
                                        )->save;

=head2 C<create_service %PARAMS>

Creates a new service (part_type = service).

Minimal usage, default values, without saving to database:

  my $part = SL::Dev::Part::create_service();

=head2 C<create_assembly %PARAMS>

Create a new assembly (part_type = assembly).

By default 3 parts (p1, p2, p3) are created and saved as an assembly (as1).

  my $assembly = SL::Dev::Part::create_assembly->save;

Create a new assembly with 10 parts:

  my $assembly = SL::Dev::Part::create_assembly(number_of_parts => 10)->save;

=head2 C<create_assortment %PARAMS>

Create a new assortment (part_type = assortment).

By default 3 parts (p1, p2, p3) are created and saved as an assortment.

  my $assortment = SL::Dev::Part::create_assortment->save;

Create a new assortment with 10 parts:

  my $assortment = SL::Dev::Part::create_assortment(number_of_parts => 10)->save;


=head1 TODO

Nothing here yet.

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

G. Richardson E<lt>grichardson@kivitendo-premium.deE<gt>

=cut
