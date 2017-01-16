package SL::Dev::Inventory;

use strict;
use base qw(Exporter);
our @EXPORT = qw(create_warehouse_and_bins set_stock);

use SL::DB::Warehouse;
use SL::DB::Bin;
use SL::DB::Inventory;
use SL::DB::TransferType;
use SL::DB::Employee;
use SL::WH;
use DateTime;
use Data::Dumper;

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
  my (%params) = @_;

  die "param part is missing or not an SL::DB::Part object" unless ref($params{part}) eq 'SL::DB::Part';
  my $part = delete $params{part};
  die "qty is missing" unless $params{qty} or $params{abs_qty};
  die "need a bin or default bin" unless $part->warehouse_id or $part->bin_id or $params{bin} or $params{bin_id};

  my ($warehouse_id, $bin_id);

  if ( $params{bin} ) {
    die "illegal param bin: " . Dumper($params{bin}) unless ref($params{bin}) eq 'SL::DB::Bin';
    my $bin       = delete $params{bin};
    $bin_id       = $bin->id;
    $warehouse_id = $bin->warehouse_id;
  } elsif ( $params{bin_id} ) {
    my $bin       = SL::DB::Manager::Bin->find_by(id => delete $params{bin_id});
    $bin_id       = $bin->id;
    $warehouse_id = $bin->warehouse_id;
  } elsif ( $part->bin_id ) {
    $bin_id       = $part->bin_id;
    $warehouse_id = $part->warehouse_id;
  } else {
    die "can't determine bin and warehouse";
  }

  my $employee_id = delete $params{employee_id} // SL::DB::Manager::Employee->current->id;
  die "Can't determine employee" unless $employee_id;

  my $qty = delete $params{qty};

  my $transfer_type_description;
  my $transfer_type;
  if ( $params{abs_qty} ) {
    # determine the current qty and calculate the qty diff that needs to be applied
    # if abs_qty is set then any value that was in $params{qty} is ignored/overwritten
    my %get_stock_params;
    $get_stock_params{bin_id}       = $bin_id       if $bin_id;
    # $get_stock_params{warehouse_id} = $warehouse_id if $warehouse_id; # redundant
    my $current_qty = $part->get_stock(%get_stock_params);
    $qty = $params{abs_qty} - $current_qty;
  }

  if ( $qty > 0 ) {
    $transfer_type_description = delete $params{transfer_type} // 'stock';
    $transfer_type = SL::DB::Manager::TransferType->find_by( description => $transfer_type_description, direction => 'in' );
  } else {
    $transfer_type_description = delete $params{transfer_type} // 'shipped';
    $transfer_type = SL::DB::Manager::TransferType->find_by( description => $transfer_type_description, direction => 'out' );
  }
  die "can't determine transfer_type" unless $transfer_type;

  my $shippingdate;
  if ( $params{shippingdate} ) {
    $shippingdate = delete $params{shippingdate};
    $shippingdate = $::locale->parse_date_to_object($shippingdate) unless ref($shippingdate) eq 'DateTime';
  } else {
    $shippingdate = DateTime->today;
  }

  my $unit;
  if ( $params{unit} ) {
    $unit = delete $params{unit};
    $unit = SL::DB::Manager::Unit->find_by( name => $unit ) unless ref($unit) eq 'SL::DB::Unit';
    $qty  = $unit->convert_to($qty, $part->unit_obj);
  }

  my ($trans_id) = $part->db->dbh->selectrow_array("select nextval('id')", {});

  SL::DB::Inventory->new(
    parts_id         => $part->id,
    bin_id           => $bin_id,
    warehouse_id     => $warehouse_id,
    employee_id      => $employee_id,
    trans_type_id    => $transfer_type->id,
    comment          => $params{comment},
    shippingdate     => $shippingdate,
    qty              => $qty,
    trans_id         => $trans_id,
  )->save;
}

sub transfer_stock {
  my (%params) = @_;

  # check params:
  die "missing params" unless ( $params{parts_id} or $params{part} ) and $params{from_bin} and $params{to_bin};

  my $part;
  if ( $params{parts_id} ) {
    $part = SL::DB::Manager::Part->find_by( id => delete $params{parts_id} ) or die "illegal parts_id";
  } else {
    $part = delete $params{part};
  }
  die "illegal part" unless ref($part) eq 'SL::DB::Part';

  my $from_bin = delete $params{from_bin};
  my $to_bin   = delete $params{to_bin};
  die "illegal bins" unless ref($from_bin) eq 'SL::DB::Bin' and ref($to_bin) eq 'SL::DB::Bin';

  my $qty = delete($params{qty});
  die "qty must be > 0" unless $qty > 0;

  # set defaults
  my $transfer_type = SL::DB::Manager::TransferType->find_by(description => 'transfer') or die "can't determine transfer type";
  my $employee_id   = delete $params{employee_id} // SL::DB::Manager::Employee->current->id;

  my $WH_params = {
    'bestbefore'         => undef,
    'change_default_bin' => undef,
    'chargenumber'       => '',
    'comment'            => delete $params{comment} // '',
    'dst_bin_id'         => $to_bin->id,
    'dst_warehouse_id'   => $to_bin->warehouse_id,
    'parts_id'           => $part->id,
    'qty'                => $qty,
    'src_bin_id'         => $from_bin->id,
    'src_warehouse_id'   => $from_bin->warehouse_id,
    'transfer_type_id'   => $transfer_type->id,
  };

  WH->transfer($WH_params);

  return 1;

  # do it manually via rose:
  # my $trans_id;

  # my $db = SL::DB::Inventory->new->db;
  # $db->with_transaction(sub{
  #   ($trans_id) = $db->dbh->selectrow_array("select nextval('id')", {});
  #   die "no trans_id" unless $trans_id;

  #   my %params = (
  #     shippingdate  => delete $params{shippingdate} // DateTime->today,
  #     employee_id   => $employee_id,
  #     trans_id      => $trans_id,
  #     trans_type_id => $transfer_type->id,
  #     parts_id      => $part->id,
  #     comment       => delete $params{comment} || 'Umlagerung',
  #   );

  #   SL::DB::Inventory->new(
  #     warehouse_id => $from_bin->warehouse_id,
  #     bin_id       => $from_bin->id,
  #     qty          => $qty * -1,
  #     %params,
  #   )->save;

  #   SL::DB::Inventory->new(
  #     warehouse_id => $to_bin->warehouse_id,
  #     bin_id       => $to_bin->id,
  #     qty          => $qty,
  #     %params,
  #   )->save;
  # }) or die $@ . "\n";
  # return 1;
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

=head2 C<set_stock %PARAMS>

Change the stock level of a certain part by creating an inventory event.
To access the updated onhand the part object needs to be loaded afterwards.

Mandatory params:
  part - an SL::DB::Part object or a parts_id
  qty | abs_qty
    qty     : the qty to increase of decrease the stock level by
    abs_qty : sets stock level for a certain part to abs_qty by creating
              a stock event with the current difference

Optional params:
  bin_id | bin
  shippingdate : may be a DateTime object or a string that needs to be parsed by parse_date_to_object.
  unit         : SL::DB::Unit object, or the name of an SL::DB::Unit object

If no bin is passed the default bin of the part is used, if that doesn't exist
either there will be an error.

C<set_stock> creates the SL::DB::Inventory object from scratch, rather
than passing params to WH->transfer_in or WH->transfer_out.

Examples:
  my $part = SL::DB::Manager::Part->find_by(partnumber => '1');
  SL::Dev::Inventory::set_stock(part => $part, qty =>  5);
  SL::Dev::Inventory::set_stock(part => $part, qty => -2);
  $part->load;
  $part->onhand; # 3

Set stock level of a part in a certain bin_id to 10:
  SL::Dev::Inventory::set_stock(part => $part, bin_id => 99, abs_qty => 10);

Create 10 warehouses with 5 bins each, then create 100 parts and increase the
stock qty in a random bin by a random positive qty for each of the parts:

  SL::Dev::Inventory::create_warehouse_and_bins(warehouse_description => "Testlager $_") for ( 1 .. 10 );
  SL::Dev::Part::create_part(description => "Testpart $_")->save for ( 1 .. 100 );
  my $bins = SL::DB::Manager::Bin->get_all;
  SL::Dev::Inventory::set_stock(part => $_,
                                qty  => int(rand(99))+1,
                                bin  => $bins->[ rand @{$bins} ],
                               ) foreach @{ SL::DB::Manager::Part->get_all() };

=head2 C<transfer_stock %PARAMS>

Transfers parts from one bin to another.

Mandatory params:
  part | parts_id    - an SL::DB::Part object or a parts_id
  from_bin           - an SL::DB::Bin object
  to_bin qty         - an SL::DB::Bin object

Optional params: shippingdate

The unit is always base_unit and there is no check for negative stock values.

Example: Create a warehouse and bins, a part, stock the part and then move some
of the stock to a different bin inside the same warehouse:

  my ($wh, $bin) = SL::Dev::Inventory::create_warehouse_and_bins();
  my $part = SL::Dev::Part::create_part->save;
  SL::Dev::Inventory::set_stock(part => $part, bin_id => $wh->bins->[2]->id, qty => 5);
  SL::Dev::Inventory::transfer_stock(part     => $part,
                                     from_bin => $wh->bins->[2],
                                     to_bin   => $wh->bins->[4],
                                     qty      => 3
                                    );
  $part->get_stock(bin_id => $wh->bins->[4]->id); # 3.00000
  $part->get_stock(bin_id => $wh->bins->[2]->id); # 2.00000

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

G. Richardson E<lt>grichardson@kivitendo-premium.deE<gt>

=cut
