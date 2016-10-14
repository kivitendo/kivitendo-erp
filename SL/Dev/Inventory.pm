package SL::Dev::Inventory;

use base qw(Exporter);
@EXPORT = qw(create_warehouse_and_bins set_stock);

use SL::DB::Warehouse;
use SL::DB::Bin;
use SL::DB::Inventory;
use SL::DB::TransferType;
use SL::DB::Employee;

sub create_warehouse_and_bins {
  my (%params) = @_;

  my $number_of_bins = $params{number_of_bins} || 5;
  my $wh = SL::DB::Warehouse->new(description => $params{warehouse_description} || "Warehouse", invalid => 0);
  for my $i ( 1 .. $number_of_bins ) {
    $wh->add_bins( SL::DB::Bin->new(description => ( $params{bin_description} || "Bin" ) . " $i" ) );
  }
  $wh->save;
  return ($wh, $wh->bins->[0]);
}

sub set_stock {
  my ($part, %params) = @_;

  die "first argument is not a part" unless ref($part) eq 'SL::DB::Part';

  die "no default warehouse" unless $part->warehouse_id or $part->bin_id;

  die "Can't determine employee" unless SL::DB::Manager::Employee->current;

  die "qty is missing or not positive" unless $params{qty} and $params{qty} > 0;

  my $transfer_type_description = delete $params{transfer_type} || 'stock';
  my $transfer_type = SL::DB::Manager::TransferType->find_by( description => $transfer_type_description, direction => 'in' );

  my $shippingdate;
  if ( $params{shippingdate} ) {
    $shippingdate = $::locale->parse_date_to_object(delete $params{shippingdate});
  } else {
    $shippingdate = DateTime->today;
  };

  my ($trans_id) = $part->db->dbh->selectrow_array("select nextval('id')", {});

  SL::DB::Inventory->new(
    parts_id         => $part->id,
    bin_id           => $part->bin_id,
    warehouse_id     => $part->warehouse_id,
    employee_id      => $params{employee_id} || SL::DB::Manager::Employee->current->id,
    trans_type_id    => $transfer_type->id,
    comment          => $params{comment},
    shippingdate     => $shippingdate,
    qty              => $params{qty},
    trans_id         => $trans_id,
  )->save;
}

1;

__END__

=head1 NAME

SL::Dev::Inventory - create inventory-related objects for testing, with minimal
defaults

=head1 FUNCTIONS

=head2 C<create_warehouse_and_bins %PARAMS>

Creates a new warehouse and bins, and immediately saves them. Returns the
warehouse and the first bin object.
  my ($wh, $bin) = SL::Dev::Inventory::create_warehouse_and_bins();

Create named warehouse with 10 bins:
  my ($wh, $bin) = SL::Dev::Inventory::create_warehouse_and_bins(warehouse_description => 'Testlager',
                                                                 bin_description       => 'Testlagerplatz',
                                                                 number_of_bins        => 10,
                                                                );
To access the second bin:
  my $bin2 = $wh->bins->[1];

=head2 C<set_stock $part, %PARAMS>

Increase the stock level of a certain part by creating an inventory event. Currently
only positive stock levels can be set. To access the updated onhand the part
object needs to be loaded afterwards.

  my $part = SL::DB::Manager::Part->find_by(partnumber => '1');
  SL::Dev::Inventory::set_stock($part, 5);
  $part->load;

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

G. Richardson E<lt>grichardson@kivitendo-premium.deE<gt>

=cut
