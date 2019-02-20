package SL::Dev::Inventory;

use strict;
use base qw(Exporter);
our @EXPORT_OK = qw(
  create_warehouse_and_bins set_stock transfer_stock
  transfer_sales_delivery_order transfer_purchase_delivery_order
  transfer_delivery_order_item transfer_in transfer_out
);
our %EXPORT_TAGS = (ALL => \@EXPORT_OK);

use SL::DB::Warehouse;
use SL::DB::Bin;
use SL::DB::Inventory;
use SL::DB::TransferType;
use SL::DB::Employee;
use SL::DB::DeliveryOrderItemsStock;
use SL::WH;
use DateTime;
use Data::Dumper;
use Carp;

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

  die "param part is missing or not an SL::DB::Part object"
    unless ref($params{part}) eq 'SL::DB::Part';

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

sub _transfer {
  my (%params) = @_;

  my $transfer_type = delete $params{transfer_type};

  die "param transfer_type is not a SL::DB::TransferType object: " . Dumper($transfer_type)
    unless ref($transfer_type) eq 'SL::DB::TransferType';

  my $shippingdate  = delete $params{shippingdate}  // DateTime->today;

  my $part = delete($params{part}) or croak 'part missing';
  my $qty  = delete($params{qty})  or croak 'qty missing';

  # distinguish absolute qty in inventory depending on transfer type direction
  $qty *= -1 if $transfer_type->direction eq 'out';

  # use defaults for unit/wh/bin is they exist and nothing else is specified
  my $unit = delete($params{unit}) // $part->unit      or croak 'unit missing';
  my $bin  = delete($params{bin})  // $part->bin       or croak 'bin missing';
  # if bin is given, we don't need a warehouse param
  my $wh   = $bin->warehouse or croak 'wh missing';

  WH->transfer({
    parts_id         => $part->id,
    dst_bin          => $bin,
    dst_wh           => $wh,
    qty              => $qty,
    transfer_type    => $transfer_type,
    unit             => $unit,
    comment          => delete $params{comment},
    shippingdate     => $shippingdate,
  });
}

sub transfer_in {
  my (%params) = @_;

  my $transfer_type = delete $params{transfer_type} // 'stock';

  my $transfer_type_obj = SL::DB::Manager::TransferType->find_by(
    direction   => 'in',
    description => $transfer_type,
  ) or die "Can't find transfer_type with direction in and description " . $params{transfer_type};

  $params{transfer_type} = $transfer_type_obj;

  _transfer(%params);
}

sub transfer_out {
  my (%params) = @_;

  my $transfer_type = delete $params{transfer_type} // 'shipped';

  my $transfer_type_obj = SL::DB::Manager::TransferType->find_by(
    direction   => 'out',
    description => $transfer_type,
  ) or die "Can't find transfer_type with direction in and description " . $params{transfer_type};

  $params{transfer_type} = $transfer_type_obj;

  _transfer(%params);
}

sub transfer_sales_delivery_order {
  my ($sales_delivery_order) = @_;
  die "first argument must be a sales delivery order Rose DB object"
    unless ref($sales_delivery_order) eq 'SL::DB::DeliveryOrder'
           and $sales_delivery_order->is_sales;

  die "the delivery order has already been delivered" if $sales_delivery_order->delivered;

  my ($wh, $bin, $trans_type);

  $sales_delivery_order->db->with_transaction(sub {

   foreach my $doi ( @{ $sales_delivery_order->items } ) {
     next if $doi->part->is_service or $doi->part->is_assortment;
     my $trans_type = SL::DB::Manager::TransferType->find_by(direction => 'out', description => 'shipped');
     transfer_delivery_order_item($doi, $wh, $bin, $trans_type);
   };
   $sales_delivery_order->delivered(1);
   $sales_delivery_order->save(changes_only=>1);
   1;
  }) or die "error while transferring sales_delivery_order: " . $sales_delivery_order->db->error;
};

sub transfer_purchase_delivery_order {
  my ($purchase_delivery_order) = @_;
  die "first argument must be a purchase delivery order Rose DB object"
   unless ref($purchase_delivery_order) eq 'SL::DB::DeliveryOrder'
          and not $purchase_delivery_order->is_sales;

  my ($wh, $bin, $trans_type);

  $purchase_delivery_order->db->with_transaction(sub {

   foreach my $doi ( @{ $purchase_delivery_order->items } ) {
     my $trans_type = SL::DB::Manager::TransferType->find_by(direction => 'in', description => 'stock');
     transfer_delivery_order_item($doi, $wh, $bin, $trans_type);
   };
   1;
  }) or die "error while transferring purchase_Delivery_order: " . $purchase_delivery_order->db->error;
};

sub transfer_delivery_order_item {
  my ($doi, $wh, $bin, $trans_type) = @_;

  unless ( defined $trans_type and ref($trans_type eq 'SL::DB::TransferType') ) {
    if ( $doi->record->is_sales ) {
      $trans_type //=  SL::DB::Manager::TransferType->find_by(direction => 'out', description => 'shipped');
    } else {
      $trans_type //= SL::DB::Manager::TransferType->find_by(direction => 'in', description => 'stock');
    }
  }

  $bin //= $doi->part->bin;
  $wh  //= $doi->part->warehouse;

  die "no bin and wh specified and part has no default bin or wh" unless $bin and $wh;

  my $employee = SL::DB::Manager::Employee->current || die "No employee";

  # dois are converted to base_qty, which is qty
  # AM->convert_unit( 'g' => 'kg') * 1000;   # 1
  #               $doi->unit   $doi->part->unit   $doi->qty
  my $dois = SL::DB::DeliveryOrderItemsStock->new(
    delivery_order_item => $doi,
    qty                 => AM->convert_unit($doi->unit => $doi->part->unit) * $doi->qty,
    unit                => $doi->part->unit,
    warehouse_id        => $wh->id,
    bin_id              => $bin->id,
  )->save;

  my $inventory = SL::DB::Inventory->new(
    parts                      => $dois->delivery_order_item->part,
    qty                        => $dois->delivery_order_item->record->is_sales ? $dois->qty * -1 : $dois->qty,
    oe                         => $doi->record,
    warehouse_id               => $dois->warehouse_id,
    bin_id                     => $dois->bin_id,
    trans_type_id              => $trans_type->id,
    delivery_order_items_stock => $dois,
    trans_id                   => $dois->id,
    employee_id                => $employee->id,
    shippingdate               => $doi->record->transdate,
  )->save;
};

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

  my ($wh, $bin) = SL::Dev::Inventory::create_warehouse_and_bins(
    warehouse_description => 'Test warehouse',
    bin_description       => 'Test bin',
    number_of_bins        => 10,
  );

To access the second bin:

  my $bin2 = $wh->bins->[1];

=head2 C<set_stock %PARAMS>

Change the stock level of a certain part by creating an inventory event.
To access the updated onhand the part object needs to be loaded afterwards.

Parameter:

=over 4

=item C<part>

Mandatory. An SL::DB::Part object or a parts_id.

=item C<qty>

The qty to increase of decrease the stock level by.

Exactly one of C<qty> and C<abs_qty> is mandatory.

=item C<abs_qty>

Sets stock level for a certain part to abs_qty by creating a stock event with
the current difference.

Exactly one of C<qty> and C<abs_qty> is mandatory.

=item C<bin_id>

=item C<bin>

Optional. The bin for inventory entry.

If no bin is passed the default bin of the part is used, if that doesn't exist
either there will be an error.

=item C<shippingdate>

Optional. May be a DateTime object or a string that needs to be parsed by
parse_date_to_object.

=item C<unit>

Optional. SL::DB::Unit object, or the name of an SL::DB::Unit object.

=back

C<set_stock> creates the SL::DB::Inventory object from scratch, rather
than passing params to WH->transfer_in or WH->transfer_out.

Examples:

  my $part = SL::DB::Manager::Part->find_by(partnumber => '1');
  SL::Dev::Inventory::set_stock(part => $part, abs_qty => 5);
  SL::Dev::Inventory::set_stock(part => $part, qty => -2);
  $part->load;
  $part->onhand; # 3

Set stock level of a part in a certain bin_id to 10:

  SL::Dev::Inventory::set_stock(part => $part, bin_id => 99, abs_qty => 10);

Create 10 warehouses with 5 bins each, then create 100 parts and increase the
stock qty in a random bin by a random positive qty for each of the parts:

  SL::Dev::Inventory::create_warehouse_and_bins(
    warehouse_description => "Test Warehouse $_"
  ) for 1 .. 10;
  SL::Dev::Part::create_part(
    description => "Test Part $_"
  )->save for 1 .. 100;
  my $bins = SL::DB::Manager::Bin->get_all;
  SL::Dev::Inventory::set_stock(
    part => $_,
    qty  => int(rand(99))+1,
    bin  => $bins->[ rand @{$bins} ],
  ) for @{ SL::DB::Manager::Part->get_all };

=head2 C<transfer_stock %PARAMS>

Transfers parts from one bin to another.

Parameters:

=over 4

=item C<part>

=item C<part_id>

Mandatory. An SL::DB::Part object or a parts_id.

=item C<from_bin>

=item C<to_bin>

Mandatory. SL::DB::Bin objects.

=item C<qty>

Mandatory.

=item C<shippingdate>

Optional.

=back

The unit is always base_unit and there is no check for negative stock values.

Example: Create a warehouse and bins, a part, stock the part and then move some
of the stock to a different bin inside the same warehouse:

  my ($wh, $bin) = SL::Dev::Inventory::create_warehouse_and_bins();
  my $part = SL::Dev::Part::create_part->save;
  SL::Dev::Inventory::set_stock(
    part   => $part,
    bin_id => $wh->bins->[2]->id,
    qty    => 5,
  );
  SL::Dev::Inventory::transfer_stock(
    part     => $part,
    from_bin => $wh->bins->[2],
    to_bin   => $wh->bins->[4],
    qty      => 3,
  );
  $part->get_stock(bin_id => $wh->bins->[4]->id); # 3.00000
  $part->get_stock(bin_id => $wh->bins->[2]->id); # 2.00000

=head2 C<transfer_sales_delivery_order %PARAMS>

Takes a SL::DB::DeliveryOrder object as its first argument and transfers out
all the items via their default bin, creating the delivery_order_stock and
inventory entries.

Assumes a fresh delivery order where nothing has been transferred out yet.

Should work like the functions in do.pl transfer_in/transfer_out and DO.pm
transfer_in_out, except that those work on the current form where as this just
works on database objects.

As this is just Dev it doesn't check for negative stocks etc.

Usage:

  my $sales_delivery_order = SL::DB::Manager::DeliveryOrder->find_by(donumber => 112);
  SL::Dev::Inventory::transfer_sales_delivery_order($sales_delivery_order1);

=head2 C<transfer_purchase_delivery_order %PARAMS>

Transfer in all the items in a purchase order.

Behaves like C<transfer_sales_delivery_order>.

=head2 C<transfer_delivery_order_item @PARAMS>

Transfers a delivery order item from a delivery order. The whole qty is transferred.
Doesn't check for available qty.

Usage:

  SL::Dev::Inventory::transfer_delivery_order_item($doi, $wh, $bin, $trans_type);

=head2 C<transfer_in %PARAMS>

Create stock in event for a part. Ideally the interface should mirror how data
is entered via the web interface.

Does some param checking, sets some defaults, but otherwise uses WH->transfer.

Parameters:

=over 4

=item C<part>

Mandatory. An SL::DB::Part object.

=item C<qty>

Mandatory.

=item C<bin>

Optional. An SL::DB::Bin object, defaults to $part->bin.

=item C<wh>

Optional. An SL::DB::Bin object, defaults to $part->warehouse.

=item C<unit>

Optional. A string such as 't', 'Stck', defaults to $part->unit->name.

=item C<shippingdate>

Optional. A DateTime object, defaults to today.

=item C<transfer_type>

Optional. A string such as 'correction', defaults to 'stock'.

=item C<comment>

Optional.

=back

Example minimal usage using part default warehouse and bin:

  my ($wh, $bin) = SL::Dev::Inventory::create_warehouse_and_bins();
  my $part       = SL::Dev::Part::create_part(
    unit      => 'kg',
    warehouse => $wh,
    bin       => $bin,
  )->save;
  SL::Dev::Inventory::transfer_in(
    part    => $part,
    qty     => 0.9,
    unit    => 't',
    comment => '900 kg in t',
  );

Example with specific transfer_type and warehouse and bin and shipping_date:

  my $shipping_date = DateTime->today->subtract( days => 20 );
  SL::Dev::Inventory::transfer_in(
    part          => $part,
    qty           => 5,
    transfer_type => 'correction',
    bin           => $bin,
    shipping_date => $shipping_date,
  );

=head2 C<transfer_out %PARAMS>

Create stock out event for a part. See C<transfer_in>.

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

G. Richardson E<lt>grichardson@kivitendo-premium.deE<gt>

=cut
