package SL::Helper::ShippedQty;

use strict;
use parent qw(Rose::Object);

use Carp;
use Scalar::Util qw(blessed);
use List::Util qw(min);
use List::MoreUtils qw(any all uniq);
use List::UtilsBy qw(partition_by);
use SL::AM;
use SL::DBUtils qw(selectall_hashref_query selectall_as_map);
use SL::Locale::String qw(t8);

use Rose::Object::MakeMethods::Generic (
  'scalar'                => [ qw(objects objects_or_ids shipped_qty keep_matches) ],
  'scalar --get_set_init' => [ qw(oe_ids dbh require_stock_out fill_up item_identity_fields oi2oe oi_qty delivered matches) ],
);

my $no_stock_item_links_query = <<'';
  SELECT oi.trans_id, oi.id AS oi_id, oi.qty AS oi_qty, oi.unit AS oi_unit, doi.id AS doi_id, doi.qty AS doi_qty, doi.unit AS doi_unit
  FROM record_links rl
  INNER JOIN orderitems oi            ON oi.id = rl.from_id AND rl.from_table = 'orderitems'
  INNER JOIN delivery_order_items doi ON doi.id = rl.to_id AND rl.to_table = 'delivery_order_items'
  WHERE oi.trans_id IN (%s)
  ORDER BY oi.trans_id, oi.position

# oi not item linked. takes about 250ms for 100k hits
my $fill_up_oi_query = <<'';
  SELECT oi.id, oi.trans_id, oi.position, oi.parts_id, oi.description, oi.reqdate, oi.serialnumber, oi.qty, oi.unit
  FROM orderitems oi
  WHERE oi.trans_id IN (%s)
  ORDER BY oi.trans_id, oi.position

# doi linked by record, but not by items; 250ms for 100k hits
my $no_stock_fill_up_doi_query = <<'';
  SELECT doi.id, doi.delivery_order_id, doi.position, doi.parts_id, doi.description, doi.reqdate, doi.serialnumber, doi.qty, doi.unit
  FROM delivery_order_items doi
  WHERE doi.delivery_order_id IN (
    SELECT to_id
    FROM record_links
    WHERE from_id IN (%s)
      AND from_table = 'oe'
      AND to_table = 'delivery_orders'
      AND to_id = doi.delivery_order_id)
   AND NOT EXISTS (
    SELECT NULL
    FROM record_links
    WHERE from_table = 'orderitems'
      AND to_table = 'delivery_order_items'
      AND to_id = doi.id)

my $stock_item_links_query = <<'';
  SELECT oi.trans_id, oi.id AS oi_id, oi.qty AS oi_qty, oi.unit AS oi_unit, doi.id AS doi_id,
    (CASE WHEN doe.customer_id > 0 THEN -1 ELSE 1 END) * i.qty AS doi_qty, p.unit AS doi_unit
  FROM record_links rl
  INNER JOIN orderitems oi                   ON oi.id = rl.from_id AND rl.from_table = 'orderitems'
  INNER JOIN delivery_order_items doi        ON doi.id = rl.to_id AND rl.to_table = 'delivery_order_items'
  INNER JOIN delivery_orders doe             ON doe.id = doi.delivery_order_id
  INNER JOIN delivery_order_items_stock dois ON dois.delivery_order_item_id = doi.id
  INNER JOIN inventory i                     ON dois.id = i.delivery_order_items_stock_id
  INNER JOIN parts p                         ON p.id = doi.parts_id
  WHERE oi.trans_id IN (%s)
  ORDER BY oi.trans_id, oi.position

my $stock_fill_up_doi_query = <<'';
  SELECT doi.id, doi.delivery_order_id, doi.position, doi.parts_id, doi.description, doi.reqdate, doi.serialnumber,
    (CASE WHEN doe.customer_id > 0 THEN -1 ELSE 1 END) * i.qty, p.unit
  FROM delivery_order_items doi
  INNER JOIN parts p                         ON p.id = doi.parts_id
  INNER JOIN delivery_order_items_stock dois ON dois.delivery_order_item_id = doi.id
  INNER JOIN delivery_orders doe             ON doe.id = doi.delivery_order_id
  INNER JOIN inventory i                     ON dois.id = i.delivery_order_items_stock_id
  WHERE doi.delivery_order_id IN (
    SELECT to_id
    FROM record_links
    WHERE from_id IN (%s)
      AND from_table = 'oe'
      AND to_table = 'delivery_orders'
      AND to_id = doi.delivery_order_id)
   AND NOT EXISTS (
    SELECT NULL
    FROM record_links
    WHERE from_table = 'orderitems'
      AND to_table = 'delivery_order_items'
      AND to_id = doi.id)

my $oe_do_record_links = <<'';
  SELECT from_id, to_id
  FROM record_links
  WHERE from_id IN (%s)
    AND from_table = 'oe'
    AND to_table = 'delivery_orders'

my @known_item_identity_fields = qw(parts_id description reqdate serialnumber);
my %item_identity_fields = (
  parts_id     => t8('Part'),
  description  => t8('Description'),
  reqdate      => t8('Reqdate'),
  serialnumber => t8('Serial Number'),
);

sub calculate {
  my ($self, $data) = @_;

  croak 'Need exactly one argument, either id, object or arrayref of ids or objects.' unless 2 == @_;

  $self->normalize_input($data);

  return $self unless @{ $self->oe_ids };

  $self->calculate_item_links;
  $self->calculate_fill_up if $self->fill_up;

  $self;
}

sub calculate_item_links {
  my ($self) = @_;

  my @oe_ids = @{ $self->oe_ids };

  my $item_links_query = $self->require_stock_out ? $stock_item_links_query : $no_stock_item_links_query;

  my $query = sprintf $item_links_query, join (', ', ('?')x @oe_ids);

  my $data = selectall_hashref_query($::form, $self->dbh, $query, @oe_ids);

  for (@$data) {
    my $qty = $_->{doi_qty} * AM->convert_unit($_->{doi_unit} => $_->{oi_unit});
    $self->shipped_qty->{$_->{oi_id}} //= 0;
    $self->shipped_qty->{$_->{oi_id}} += $qty;
    $self->oi2oe->{$_->{oi_id}}        = $_->{trans_id};
    $self->oi_qty->{$_->{oi_id}}       = $_->{oi_qty};

    push @{ $self->matches }, [ $_->{oi_id}, $_->{doi_id}, $qty, 1 ] if $self->keep_matches;
  }
}

sub _intersect {
  my ($a1, $a2) = @_;
  my %seen;
  grep { $seen{$_}++ } @$a1, @$a2;
}

sub calculate_fill_up {
  my ($self) = @_;

  my @oe_ids = @{ $self->oe_ids };

  my $fill_up_doi_query = $self->require_stock_out ? $stock_fill_up_doi_query : $no_stock_fill_up_doi_query;

  my $oi_query  = sprintf $fill_up_oi_query,   join (', ', ('?')x@oe_ids);
  my $doi_query = sprintf $fill_up_doi_query,  join (', ', ('?')x@oe_ids);
  my $rl_query  = sprintf $oe_do_record_links, join (', ', ('?')x@oe_ids);

  my $oi  = selectall_hashref_query($::form, $self->dbh, $oi_query,  @oe_ids);

  return unless @$oi;

  my $doi = selectall_hashref_query($::form, $self->dbh, $doi_query, @oe_ids);
  my $rl  = selectall_hashref_query($::form, $self->dbh, $rl_query,  @oe_ids);

  my %oi_by_identity  = partition_by { $self->item_identity($_) } @$oi;
  my %doi_by_id       = partition_by { $_->{delivery_order_id} } @$doi;
  my %doi_by_trans_id;
  push @{ $doi_by_trans_id{$_->{from_id}} //= [] }, @{ $doi_by_id{$_->{to_id}} }
    for grep { exists $doi_by_id{$_->{to_id}} } @$rl;

  my %doi_by_identity = partition_by { $self->item_identity($_) } @$doi;

  for my $match (sort keys %oi_by_identity) {
    next unless exists $doi_by_identity{$match};

    my %oi_by_oe = partition_by { $_->{trans_id} } @{ $oi_by_identity{$match} };
    for my $trans_id (sort { $a <=> $b } keys %oi_by_oe) {
      next unless my @sorted_doi = _intersect($doi_by_identity{$match}, $doi_by_trans_id{$trans_id});

      # sorting should be quite fast here, because there are usually only a handful of matches
      next unless my @sorted_oi  = sort { $a->{position} <=> $b->{position} } @{ $oi_by_oe{$trans_id} };

      # parallel walk through sorted oi/doi entries
      my $oi_i = my $doi_i = 0;
      my ($oi, $doi) = ($sorted_oi[$oi_i], $sorted_doi[$doi_i]);
      while ($oi_i < @sorted_oi && $doi_i < @sorted_doi) {
        $oi =  $sorted_oi[++$oi_i],   next if $oi->{qty} <= $self->shipped_qty->{$oi->{id}};
        $doi = $sorted_doi[++$doi_i], next if 0 == $doi->{qty};

        my $factor  = AM->convert_unit($doi->{unit} => $oi->{unit});
        my $min_qty = min($oi->{qty} - $self->shipped_qty->{$oi->{id}}, $doi->{qty} * $factor);

        # min_qty should never be 0 now. the first part triggers the first next,
        # the second triggers the second next and factor must not be 0
        # but it would lead to an infinite loop, so catch that.
        die 'panic! invalid shipping quantity' unless $min_qty;

        $self->shipped_qty->{$oi->{id}} += $min_qty;
        $doi->{qty}                     -= $min_qty / $factor;  # TODO: find a way to avoid float rounding
        push @{ $self->matches }, [ $oi->{id}, $doi->{id}, $min_qty, 0 ] if $self->keep_matches;
      }
    }
  }

  $self->oi2oe->{$_->{id}}  = $_->{trans_id} for @$oi;
  $self->oi_qty->{$_->{id}} = $_->{qty}      for @$oi;
}

sub write_to {
  my ($self, $objects) = @_;

  croak 'expecting array of objects' unless 'ARRAY' eq ref $objects;

  my $shipped_qty = $self->shipped_qty;

  for my $obj (@$objects) {
    if ('SL::DB::OrderItem' eq ref $obj) {
      $obj->{shipped_qty} = $shipped_qty->{$obj->id} //= 0;
      $obj->{delivered}   = $shipped_qty->{$obj->id} == $obj->qty;
    } elsif ('SL::DB::Order' eq ref $obj) {
      if (defined $obj->{orderitems}) {
        $self->write_to($obj->{orderitems});
        $obj->{delivered} = all { $_->{delivered} } @{ $obj->{orderitems} };
      } else {
        # don't force a load on items. just compute by oe_id directly
        $obj->{delivered} = $self->delivered->{$obj->id};
      }
    } else {
      die "unknown reference '@{[ ref $obj ]}' for @{[ __PACKAGE__ ]}::write_to";
    }
  }
  $self;
}

sub write_to_objects {
  my ($self) = @_;

  return unless @{ $self->oe_ids };

  croak 'Can only use write_to_objects, when calculate was called with objects. Use write_to instead.' unless $self->objects_or_ids;

  $self->write_to($self->objects);
}

sub item_identity {
  my ($self, $row) = @_;

  join $;, map $row->{$_}, @{ $self->item_identity_fields };
}

sub normalize_input {
  my ($self, $data) = @_;

  $data = [$data] if 'ARRAY' ne ref $data;

  $self->objects_or_ids(!!blessed($data->[0]));

  if ($self->objects_or_ids) {
    croak 'unblessed object in data while expecting object' if any { !blessed($_) } @$data;
    $self->objects($data);
  } else {
    croak 'object or reference in data while expecting ids' if any { ref($_) } @$data;
    croak 'ids need to be numbers'                          if any { ! ($_ * 1) } @$data;
    $self->oe_ids($data);
  }

  $self->shipped_qty({});
}

sub available_item_identity_fields {
  map { [ $_ => $item_identity_fields{$_} ] } @known_item_identity_fields;
}

sub init_oe_ids {
  my ($self) = @_;

  croak 'oe_ids not initialized in id mode'            if !$self->objects_or_ids;
  croak 'objects not initialized before accessing ids' if $self->objects_or_ids && !defined $self->objects;
  croak 'objects need to be Order or OrderItem'        if any  {  ref($_) !~ /^SL::DB::Order(?:Item)?$/ } @{ $self->objects };

  [ uniq map { ref($_) =~ /Item/ ? $_->trans_id : $_->id } @{ $self->objects } ]
}

sub init_dbh { SL::DB->client->dbh }

sub init_oi2oe { {} }
sub init_oi_qty { {} }
sub init_matches { [] }
sub init_delivered {
  my ($self) = @_;
  my $d = { };
  for (keys %{ $self->oi_qty }) {
    my $oe_id = $self->oi2oe->{$_};
    $d->{$oe_id} //= 1;
    $d->{$oe_id} &&= $self->shipped_qty->{$_} == $self->oi_qty->{$_};
  }
  $d;
}

sub init_require_stock_out    { $::instance_conf->get_shipped_qty_require_stock_out }
sub init_item_identity_fields { [ grep $item_identity_fields{$_}, @{ $::instance_conf->get_shipped_qty_item_identity_fields } ] }
sub init_fill_up              { $::instance_conf->get_shipped_qty_fill_up  }

1;

__END__

=encoding utf-8

=head1 NAME

SL::Helper::ShippedQty - Algorithmic module for calculating shipped qty

=head1 SYNOPSIS

  use SL::Helper::ShippedQty;

  my $helper = SL::Helper::ShippedQty->new(
    fill_up              => 0,
    require_stock_out    => 0,
    item_identity_fields => [ qw(parts_id description reqdate serialnumber) ],
  );

  $helper->calculate($order_object);
  $helper->calculate(\@order_objects);
  $helper->calculate($orderitem_object);
  $helper->calculate(\@orderitem_objects);
  $helper->calculate($oe_id);
  $helper->calculate(\@oe_ids);

  # if these are items set delivered and shipped_qty
  # if these are orders, iterate through their items and set delivered on order
  $helper->write_to($objects);

  # if calculate was called with objects, you can use this shortcut:
  $helper->write_to_objects;

  # shipped_qtys by oi_id
  my $shipped_qty = $helper->shipped_qty->{$oi->id};

  # delivered by oe_id
  my $delivered = $helper->delievered->{$oi->id};

  # calculate and write_to can be chained:
  my $helper = SL::Helper::ShippedQty->new->calculate($orders)->write_to_objects;

=head1 DESCRIPTION

This module encapsulates the algorithm needed to compute the shipped qty for
orderitems (hopefully) correctly and efficiently for several use cases.

While this is used in object accessors, it can not be fast when called in a
loop over and over, so take advantage of batch processing when possible.

=head1 MOTIVATION AND PROBLEMS

The concept of shipped qty is sadly not as straight forward as it sounds at
first glance. Any correct implementation must in some way deal with the
following problems.

=over 4

=item *

When is an order shipped? For users that use the inventory it
will mean when a delivery order is stocked out. For those not using the
inventory it will mean when the delivery order is saved.

=item *

How to find the correct matching elements. After the changes
to record item links it's natural to assume that each position is linked, but
for various reasons this might not be the case. Positions that are not linked
in the database need to be matched by marching.

=item *

Double links need to be accounted for (these can stem from buggy code).

=item *

orderitems and oe entries may link to many of their counterparts in
delivery_orders. delivery_orders my be created from multiple orders. The
only constant is that a single entry in delivery_order_items has at most one
link from an orderitem.

=item *

For the fill up case the identity of positions is not clear. The naive approach
is just the same part, but description, charge number, reqdate and qty can all
be part of the identity of a position for finding shipped matches.

=item *

Certain delivery orders might not be eligible for qty calculations if delivery
orders are used for other purposes.

=item *

Units need to be handled correctly

=item *

Negative positions must be taken into account. A negative delivery order is
assumed to be a RMA of sorts, but a negative order is not as straight forward.

=item *

Must be able to work with plain ids and Rose objects, and absolutely must
include a bulk mode to speed up multiple objects.

=back


=head1 FUNCTIONS

=over 4

=item C<new PARAMS>

Creates a new helper object. PARAMS may include:

=over 4

=item * C<require_stock_out>

Boolean. If set, delivery orders must be stocked out to be considered
delivered. The default is a client setting.

=item * C<fill_up>

Boolean. If set, unlinked delivery order items will be used to fill up
undelivered order items. Not needed in newer installations. The default is a
client setting.

=item * C<item_identity_fields ARRAY>

If set, the fields are used to compute the identity of matching positions. The
default is a client setting. Possible values include:

=over 4

=item * C<parts_id>

=item * C<description>

=item * C<reqdate>

=item * C<serialnumber>

=back

=item * C<keep_matches>

Boolean. If set to true the internal matchings of OrderItems and
DeliveryOrderItems will be kept for later postprocessing, in case you need more
than this modules provides.

See C<matches> for the returned format.

=back

=item C<calculate OBJECTS>

=item C<calculate IDS>

Do the main work. There must be a single argument: Either an id or an
C<SL::DB::Order> object, or an arrayref of one of these types.

Mixing ids and objects will generate an exception.

No return value. All internal errors will throw an exception.

=item C<write_to OBJECTS>

=item C<write_to_objects>

Save the C<shipped_qty> and C<delivered> state to the given objects. If
L</calculate> was called with objects, then C<write_to_objects> will use these.

C<shipped_qty> and C<delivered> will be directly infused into the objects
without calling the accessor for delivered. If you want to save afterwards,
you'll have to do that yourself.

C<shipped_qty> is guaranteed to be coerced to a number. If no delivery_order
was found it will be set to zero.

C<delivered> is guaranteed only to be the correct boolean value, but not
any specific value.

Note: C<write_to> will avoid loading unnecessary objects. This means if it is
called with an Order object that has not loaded its orderitems yet, only
C<delivered> will be set in the Order object. A subsequent C<<
$order->orderitems->[0]->{delivered} >> will return C<undef>, and C<<
$order->orderitems->[0]->shipped_qty >> will invoke another implicit
calculation.

=item C<shipped_qty>

Valid after L</calculate>. Returns a hasref with shipped qtys by orderitems id.

Unlike the result of C</write_to>, entries in C<shipped_qty> may be C<undef> if
linked elements were found.

=item C<delivered>

Valid after L</calculate>. Returns a hashref with a delivered flag by order id.

=item C<matches>

Valid after L</calculate> with C<with_matches> set. Returns an arrayref of
individual matches. Each match is an arrayref with these fields:

=over 4

=item *

The id of the OrderItem.

=item *

The id of the DeliveryOrderItem.

=item *

The qty that was matched between the two converted to the unit of the OrderItem.

=item *

A boolean flag indicating if this match was found with record_item links. If
false, the match was made in the fill up stage.

=back

=back

=head1 REPLACED FUNCTIONALITY

=head2 delivered mode

Originally used in mark_orders_if_delivered. Searches for orders associated
with a delivery order and evaluates whether those are delivered or not. No
detailed information is needed.

This is to be integrated into fast delivered check on the orders. The calling
convention for the delivery_order is not part of the scope of this module.

=head2 do_mode

Originally used for printing delivery orders. Resolves for each position for
how much was originally ordered, and how much remains undelivered.

This one is likely to be dropped. The information only makes sense without
combined merge/split deliveries and is very fragile with unaccounted delivery
orders.

=head2 oe mode

Same from the order perspective. Used for transitions to delivery orders, where
delivered qtys should be removed from positions. Also used each time a record
is rendered to show the shipped qtys. Also used to find orders that are not
fully delivered.

Acceptable shortcuts would be the concepts fully shipped (for the order) and
providing already loaded objects.

=head2 Replaces the following functions

C<DO::get_shipped_qty>

C<SL::Controller::DeliveryPlan::calc_qtys>

C<SL::DB::OrderItem::shipped_qty>

C<SL::DB::OrderItem::delivered_qty>

=head1 OLD ALGORITHM

this is the old get_shipped_qty algorithm by Martin for reference

    in: oe_id, do_id, doctype, delivered flag

    not needed with better signatures
     if do_id:
       load oe->do links for this id,
       set oe_ids from those
     fi
     if oe_id:
       set oe_ids to this

    return if no oe_ids;

  2 load all orderitems for these oe_ids
    for orderitem:
      nomalize qty
      set undelivered := qty
    end

    create tuple: [ position => qty_ordered, qty_not_delivered, orderitem.id ]

  1 load all oe->do links for these oe_ids

    if no links:
      return all tuples so far
    fi

  4 create dictionary for orderitems from [2] by id

  3 load all delivery_order_items for do_ids from [1], with recorditem_links from orderitems
      - optionally with doctype filter (identity filter)

    # first pass for record_item_links
    for dois:
      normalize qty
      if link from orderitem exists and orderitem is in dictionary [4]
        reduce qty_notdelivered in orderitem by doi.qty
        keep link to do entry in orderitem
    end

    # second pass fill up
    for dois:
      ignroe if from link exists or qty == 0

      for orderitems from [2]:
        next if notdelivered_qty == 0
        if doi.parts_id == orderitem.parts_id:
          if oi.notdelivered_qty < 0:
            doi :+= -oi.notdelivered_qty,
            oi.notdelivered_qty := 0
          else:
            fi doi.qty < oi.notdelivered_qty:
              doi.qty := 0
              oi.notdelivered_qty :-= doi.qty
            else:
              doi.qty :-= oi.notdelivered_qty
              oi.notdelivered_qty := 0
            fi
            keep link to oi in doi
          fi
        fi
        last wenn doi.qty <= 0
      end
    end

    # post process for return

    if oe_id:
      copy notdelivered from oe to ship{position}{notdelivered}
    if !oe_id and do_id and delivered:
      ship.{oi.trans_id}.delivered := oi.notdelivered_qty <= 0
    if !oe_id and do_id and !delivered:
      for all doi:
        ignore if do.id != doi.delivery_order_id
        if oi in doi verlinkt und position bekannt:
          addiere oi.qty               zu doi.ordered_qty
          addiere oi.notdelievered_qty zu doi.notdelivered_qty
        fi
      end
    fi

=head1 NEW ALGORITHM

  in: orders, parameters

  normalize orders to ids

  # handle record_item links
  retrieve record_links entries with inner joins on orderitems, delivery_orderitems and stock/inventory if requested
  for all record_links:
    initialize shipped_qty for this doi to 0 if not yet seen
    convert doi.qty to oi.unit
    add normalized doi.qty to shipped_qty
  end

  # handle fill up
  abort if fill up is not requested

  retrieve all orderitems matching the given order ids
  retrieve all doi with a link to the given order ids but without item link (and optionally with stock/inventory)
  retrieve all record_links between orders and delivery_orders                  (1)

  abort when no dois were found

  create a partition of the delivery order items by do_id                       (2)
  create empty mapping for delivery order items by order_id                     (3)
  for all record_links from [1]:
    add all matching doi from (2) to (3)
  end

  create a partition of the orderitems by item identity                         (4)
  create a partition of the delivery order items by item identity               (5)

  for each identity in (4):
    skip if no matching entries in (5)

    create partition of all orderitems for this identity by order id            (6)
    for each sorted order id in [6]:
      look up matching delivery order items by identity from [5]                (7)
      look up matching delivery order items by order id from [3]                (8)
      create stable sorted intersection between [7] and [8]                     (9)

      sort the orderitems from (6) by position                                 (10)

      parallel walk through [9] and [10]:
        missing qty :=  oi.qty - shipped_qty[oi]


        next orderitem           if missing_qty <= 0
        next delivery order item if doi.qty == 0

        min_qty := minimum(missing_qty, [doi.qty converted to oi.unit]

        # transfer min_qty from doi.qty to shipped[qty]:
        shipped_qty[oi] += min_qty
        doi.qty         -= [min_qty converted to doi.unit]
      end
    end
  end

=head1 COMPLEXITY OBSERVATIONS

Perl ops except for sort are expected to be constant (relative to the op overhead).

=head2 Record item links

The query itself has indices available for all joins and filters and should
scale with sublinear with the number of affected orderitems.

The rest of the code iterates through the result and calls C<AM::convert_unit>,
which caches internally and is asymptotically constant.

=head2 Fill up

C<partition_by> and C<intersect> both scale linearly. The first two scale with
input size, but use existing indices. The delivery order items query scales
with the nested loop anti join of the "NOT EXISTS" subquery, which takes most
of the time. For large databases omitting the order id filter may be faster.

Three partitions after that scale linearly. Building the doi_by_oe_id
multimap is O(n²) worst case, but will be linear for most real life data.

Iterating through the values of the partitions scales with the number of
elements in the multimap, and does not add additional complexity.

The sort and parallel walk are O(nlogn) for the length of the subdivisions,
which again makes square worst case, but much less than that in the general
case.

=head3 Space requirements

In the current form the results of the 4 queries get fetched, and 4 of them are
held in memory at the same time. Three persistent structures are held:
C<shipped_qty>, C<oi2oe>, and C<oi_qty> - all hashes with one entry for each
orderitem. C<delivered> is calculated on demand and is a hash with an entry for
each order id of input.

Temporary structures are partitions of the orderitems, of which again the fill
up multi map between order id and delivery order items is potentially the
largest with square requierment worst case.


=head1 TODO

  * delivery order identity
  * test stocked
  * rewrite to avoid division
  * rewrite to avoid selectall for really large queries (no problem for up to 100k)
  * calling mode or return to flag delivery_orders as delivered?
  * add localized field white list
  * reduce worst case square space requirement to linear

=head1 BUGS

None yet, but there are most likely a lot in code this funky.

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
