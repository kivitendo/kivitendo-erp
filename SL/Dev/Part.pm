package SL::Dev::Part;

use strict;
use base qw(Exporter);
our @EXPORT = qw(create_part create_service);

use SL::DB::Part;
use SL::DB::Unit;
use SL::DB::Buchungsgruppe;

sub create_part {
  my (%params) = @_;

  my ($buchungsgruppe, $unit);
  $buchungsgruppe  = SL::DB::Manager::Buchungsgruppe->find_by(description => 'Standard 19%') || die "No accounting group";
  $unit            = SL::DB::Manager::Unit->find_by(name => 'Stck')                          || die "No unit";

  my $part = SL::DB::Part->new_part(
    description        => 'Test part',
    sellprice          => '10',
    lastcost           => '5',
    buchungsgruppen_id => $buchungsgruppe->id,
    unit               => $unit->name,
  );
  $part->assign_attributes( %params );
  return $part;
}

sub create_service {
  my (%params) = @_;

  my ($buchungsgruppe, $unit);
  $buchungsgruppe  = SL::DB::Manager::Buchungsgruppe->find_by(description => 'Standard 19%') || die "No accounting group";
  $unit            = SL::DB::Manager::Unit->find_by(name => 'Stck')                          || die "No unit";

  my $part = SL::DB::Part->new_service(
    description        => 'Test service',
    sellprice          => '10',
    lastcost           => '5',
    buchungsgruppen_id => $buchungsgruppe->id,
    unit               => $unit->name,
  );
  $part->assign_attributes( %params );
  return $part;
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

=head1 TODO

=over 2

=item * create_assembly

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

G. Richardson E<lt>grichardson@kivitendo-premium.deE<gt>

=cut
