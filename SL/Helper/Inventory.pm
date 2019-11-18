package SL::Helper::Inventory;

use strict;
use Carp;
use DateTime;
use Exporter qw(import);
use List::Util qw(min sum);
use List::UtilsBy qw(sort_by);
use List::MoreUtils qw(any);

use SL::Locale::String qw(t8);
use SL::MoreCommon qw(listify);
use SL::DBUtils qw(selectall_hashref_query selectrow_query);
use SL::DB::TransferType;
use SL::Helper::Number qw(_round_qty _qty);
use SL::X;

our @EXPORT_OK = qw(get_stock get_onhand allocate allocate_for_assembly produce_assembly check_constraints);
our %EXPORT_TAGS = (ALL => \@EXPORT_OK);

sub _get_stock_onhand {
  my (%params) = @_;

  my $onhand_mode = !!$params{onhand};

  my @selects = ('SUM(qty) as qty');
  my @values;
  my @where;
  my @groups;

  if ($params{part}) {
    my @ids = map { ref $_ ? $_->id : $_ } listify($params{part});
    push @where, sprintf "parts_id IN (%s)", join ', ', ("?") x @ids;
    push @values, @ids;
  }

  if ($params{bin}) {
    my @ids = map { ref $_ ? $_->id : $_ } listify($params{bin});
    push @where, sprintf "bin_id IN (%s)", join ', ', ("?") x @ids;
    push @values, @ids;
  }

  if ($params{warehouse}) {
    my @ids = map { ref $_ ? $_->id : $_ } listify($params{warehouse});
    push @where, sprintf "warehouse.id IN (%s)", join ', ', ("?") x @ids;
    push @values, @ids;
  }

  if ($params{chargenumber}) {
    my @ids = listify($params{chargenumber});
    push @where, sprintf "chargenumber IN (%s)", join ', ', ("?") x @ids;
    push @values, @ids;
  }

  if ($params{date}) {
    push @where, sprintf "shippingdate <= ?";
    push @values, $params{date};
  }

  if ($params{bestbefore}) {
    push @where, sprintf "bestbefore >= ?";
    push @values, $params{bestbefore};
  }

  # reserve_warehouse
  if ($params{onhand} && !$params{warehouse}) {
    push @where, 'NOT warehouse.forreserve';
  }

  # reserve_for
  if ($params{onhand} && !$params{reserve_for}) {
    push @where, 'reserve_for_id IS NULL AND reserve_for_table IS NULL';
  }

  if ($params{reserve_for}) {
    my @objects = listify($params{chargenumber});
    my @tokens;
    push @tokens, ( "(reserve_for_id = ? AND reserve_for_table = ?)") x @objects;
    push @values, map { ($_->id, $_->meta->table) } @objects;
    push @where, '(' . join(' OR ', @tokens) . ')';
  }

  # by
  my %allowed_by = (
    part          => [ qw(parts_id) ],
    bin           => [ qw(bin_id inventory.warehouse_id warehouse.forreserve)],
    warehouse     => [ qw(inventory.warehouse_id warehouse.forreserve) ],
    chargenumber  => [ qw(chargenumber) ],
    bestbefore    => [ qw(bestbefore) ],
    reserve_for   => [ qw(reserve_for_id reserve_for_table) ],
    for_allocate  => [ qw(parts_id bin_id inventory.warehouse_id warehouse.forreserve chargenumber bestbefore reserve_for_id reserve_for_table) ],
  );

  if ($params{by}) {
    for (listify($params{by})) {
      my $selects = $allowed_by{$_} or Carp::croak("unknown option for by: $_");
      push @selects, @$selects;
      push @groups,  @$selects;
    }
  }

  my $select   = join ',', @selects;
  my $where    = @where  ? 'WHERE ' . join ' AND ', @where : '';
  my $group_by = @groups ? 'GROUP BY ' . join ', ', @groups : '';

  my $query = <<"";
    SELECT $select FROM inventory
    LEFT JOIN bin ON bin_id = bin.id
    LEFT JOIN warehouse ON bin.warehouse_id = warehouse.id
    $where
    $group_by
    HAVING SUM(qty) > 0

  my $results = selectall_hashref_query($::form, SL::DB->client->dbh, $query, @values);

  my %with_objects = (
    part         => 'SL::DB::Manager::Part',
    bin          => 'SL::DB::Manager::Bin',
    warehouse    => 'SL::DB::Manager::Warehouse',
    reserve_for  => undef,
  );

  my %slots = (
    part      =>  'parts_id',
    bin       =>  'bin_id',
    warehouse =>  'warehouse_id',
  );

  if ($params{by} && $params{with_objects}) {
    for my $with_object (listify($params{with_objects})) {
      Carp::croak("unknown with_object $with_object") if !exists $with_objects{$with_object};

      if (my $manager = $with_objects{$with_object}) {
        my $slot = $slots{$with_object};
        next if !(my @ids = map { $_->{$slot} } @$results);
        my $objects = $manager->get_all(query => [ id => \@ids ]);
        my %objects_by_id = map { $_->id => $_ } @$objects;

        $_->{$with_object} = $objects_by_id{$_->{$slot}} for @$results;
      } else {
        # need to fetch all reserve_for_table partitions
      }
    }
  }

  if ($params{by}) {
    return $results;
  } else {
    return $results->[0]{qty};
  }
}

sub get_stock {
  _get_stock_onhand(@_, onhand => 0);
}

sub get_onhand {
  _get_stock_onhand(@_, onhand => 1);
}

sub allocate {
  my (%params) = @_;

  my $part = $params{part} or Carp::croak('allocate needs a part');
  my $qty  = $params{qty}  or Carp::croak('allocate needs a qty');

  return () if $qty <= 0;

  my $results = get_stock(part => $part, by => 'for_allocate');
  my %bin_whitelist = map { (ref $_ ? $_->id : $_) => 1 } listify($params{bin});
  my %wh_whitelist  = map { (ref $_ ? $_->id : $_) => 1 } listify($params{warehouse});
  my %chargenumbers = map { (ref $_ ? $_->id : $_) => 1 } listify($params{chargenumber});
  my %reserve_whitelist;
  if ($params{reserve_for}) {
    $reserve_whitelist{ $_->meta->table }{ $_->id } = 1 for listify($params{reserve_for});
  }

  # filter the results. we don't want:
  # - negative amounts
  # - bins that are reserve but not in the white-list of warehouses or bins
  # - reservations that are not white-listed

  my @filtered_results = grep {
       (!$_->{forreserve} || $bin_whitelist{$_->{bin_id}} || $wh_whitelist{$_->{warehouse_id}})
    && (!$_->{reserve_for_id} || $reserve_whitelist{ $_->{reserve_for_table} }{ $_->{reserve_for_id} })
  } @$results;

  # sort results so that reserve_for is first, then chargenumbers, then wanted bins, then wanted warehouses
  my @sorted_results = sort {
       (!!$b->{reserve_for_id})    <=> (!!$a->{reserve_for_id})                   # sort by existing reserve_for_id first.
    || exists $chargenumbers{$b->{chargenumber}}  <=> exists $chargenumbers{$a->{chargenumber}} # then prefer wanted chargenumbers
    || exists $bin_whitelist{$b->{bin_id}}        <=> exists $bin_whitelist{$a->{bin_id}}       # then prefer wanted bins
    || exists $wh_whitelist{$b->{warehouse_id}}   <=> exists $wh_whitelist{$a->{warehouse_id}}  # then prefer wanted bins
  } @filtered_results;
  my @allocations;
  my $rest_qty = $qty;

  for my $chunk (@sorted_results) {
    my $qty = min($chunk->{qty}, $rest_qty);
    if ($qty > 0) {
      push @allocations, SL::Helper::Inventory::Allocation->new(
        parts_id          => $chunk->{parts_id},
        qty               => $qty,
        comment           => $params{comment},
        bin_id            => $chunk->{bin_id},
        warehouse_id      => $chunk->{warehouse_id},
        chargenumber      => $chunk->{chargenumber},
        bestbefore        => $chunk->{bestbefore},
        reserve_for_id    => $chunk->{reserve_for_id},
        reserve_for_table => $chunk->{reserve_for_table},
        oe_id             => undef,
      );
      $rest_qty -= $qty;
    }

    last if $rest_qty == 0;
  }
  if ($rest_qty > 0) {
    die SL::X::Inventory::Allocation->new(
      error => 'not enough to allocate',
      msg => t8("can not allocate #1 units of #2, missing #3 units", $qty, $part->displayable_name, $rest_qty),
    );
  } else {
    if ($params{constraints}) {
      check_constraints($params{constraints},\@allocations);
    }
    return @allocations;
  }
}

sub allocate_for_assembly {
  my (%params) = @_;

  my $part = $params{part} or Carp::croak('allocate needs a part');
  my $qty  = $params{qty}  or Carp::croak('allocate needs a qty');

  Carp::croak('not an assembly') unless $part->is_assembly;

  my %parts_to_allocate;

  for my $assembly ($part->assemblies) {
    $parts_to_allocate{ $assembly->part->id } //= 0;
    $parts_to_allocate{ $assembly->part->id } += $assembly->qty * $qty; # TODO recipe factor
  }

  my @allocations;

  for my $part_id (keys %parts_to_allocate) {
    my $part = SL::DB::Part->load_cached($part_id);
    push @allocations, allocate(%params, part => $part, qty => $parts_to_allocate{$part_id});
  }

  @allocations;
}

sub check_constraints {
  my ($constraints, $allocations) = @_;
  if ('CODE' eq ref $constraints) {
    if (!$constraints->(@$allocations)) {
      die SL::X::Inventory::Allocation->new(
        error => 'allocation constraints failure',
        msg => t8("Allocations didn't pass constraints"),
      );
    }
  } else {
    croak 'constraints needs to be a hashref' unless 'HASH' eq ref $constraints;

    my %supported_constraints = (
      bin_id       => 'bin_id',
      warehouse_id => 'warehouse_id',
      chargenumber => 'chargenumber',
    );

    for (keys %$constraints ) {
      croak "unsupported constraint '$_'" unless $supported_constraints{$_};

      my %whitelist = map { (ref $_ ? $_->id : $_) => 1 } listify($constraints->{$_});
      my $accessor = $supported_constraints{$_};

      if (any { !$whitelist{$_->$accessor} } @$allocations) {
        my %error_constraints = (
          bin_id       => t8('Bins'),
          warehouse_id => t8('Warehouses'),
          chargenumber => t8('Chargenumbers'),
        );
        my @allocs = grep { $whitelist{$_->$accessor} } @$allocations;
        my $needed = sum map { $_->qty } grep { !$whitelist{$_->$accessor} } @$allocations;
        my $err    = t8("Cannot allocate parts.");
        $err      .= ' '.t8('part \'#\'1 in bin \'#2\' only with qty #3 (need additional #4) and chargenumber \'#5\'.',
              SL::DB::Part->load_cached($_->parts_id)->description,
              SL::DB::Bin->load_cached($_->bin_id)->full_description,
              _qty($_->qty), _qty($needed), $_->chargenumber ? $_->chargenumber : '--') for @allocs;
        die SL::X::Inventory::Allocation->new(
          error => 'allocation constraints failure',
          msg   => $err,
        );
      }
    }
  }
}

sub produce_assembly {
  my (%params) = @_;

  my $part = $params{part} or Carp::croak('produce_assembly needs a part');
  my $qty  = $params{qty}  or Carp::croak('produce_assembly needs a qty');

  my $allocations = $params{allocations};
  if ($params{auto_allocate}) {
    Carp::croak("produce_assembly: can't have both allocations and auto_allocate") if $params{allocations};
    $allocations = [ allocate_for_assembly(part => $part, qty => $qty) ];
  } else {
    Carp::croak("produce_assembly: need allocations or auto_allocate to produce something") if !$params{allocations};
    $allocations = $params{allocations};
  }

  my $bin          = $params{bin} or Carp::croak("need target bin");
  my $chargenumber = $params{chargenumber};
  my $bestbefore   = $params{bestbefore};
  my $oe_id        = $params{oe_id};
  my $comment      = $params{comment} // '';

  my $production_order_item = $params{production_order_item};
  my $invoice               = $params{invoice};
  my $project               = $params{project};
  my $reserve_for           = $params{reserve_for};

  my $reserve_for_id    = $reserve_for ? $reserve_for->id          : undef;
  my $reserve_for_table = $reserve_for ? $reserve_for->meta->table : undef;

  my $shippingdate = $params{shippingsdate} // DateTime->now_local;

  my $trans_id              = $params{trans_id};
  ($trans_id) = selectrow_query($::form, SL::DB->client->dbh, qq|SELECT nextval('id')| ) unless $trans_id;

  my $trans_type_out = SL::DB::Manager::TransferType->find_by(direction => 'out', description => 'used');
  my $trans_type_in  = SL::DB::Manager::TransferType->find_by(direction => 'in', description => 'assembled');

  # check whether allocations are sane
  if (!$params{no_check_allocations} && !$params{auto_allocate}) {
    my %allocations_by_part = map { $_->parts_id  => $_->qty } @$allocations;
    for my $assembly ($part->assemblies) {
      $allocations_by_part{ $assembly->parts_id } -= $assembly->qty * $qty; # TODO recipe factor
    }

    die "allocations are insufficient for production" if any { $_ < 0 } values %allocations_by_part;
  }

  my @transfers;
  for my $allocation (@$allocations) {
    push @transfers, SL::DB::Inventory->new(
      trans_id     => $trans_id,
      %$allocation,
      qty          => -$allocation->qty,
      trans_type   => $trans_type_out,
      shippingdate => $shippingdate,
      employee     => SL::DB::Manager::Employee->current,
      oe_id        => $allocation->oe_id,
    );
  }

  push @transfers, SL::DB::Inventory->new(
    trans_id          => $trans_id,
    trans_type        => $trans_type_in,
    part              => $part,
    qty               => $qty,
    bin               => $bin,
    warehouse         => $bin->warehouse_id,
    chargenumber      => $chargenumber,
    bestbefore        => $bestbefore,
    reserve_for_id    => $reserve_for_id,
    reserve_for_table => $reserve_for_table,
    shippingdate      => $shippingdate,
    project           => $project,
    invoice           => $invoice,
    comment           => $comment,
    prod              => $production_order_item,
    employee          => SL::DB::Manager::Employee->current,
    oe_id             => $oe_id,
  );

  SL::DB->client->with_transaction(sub {
    $_->save for @transfers;
    1;
  }) or do {
    die SL::DB->client->error;
  };

  @transfers;
}

package SL::Helper::Inventory::Allocation {
  my @attributes = qw(parts_id qty bin_id warehouse_id chargenumber bestbefore comment reserve_for_id reserve_for_table oe_id);
  my %attributes = map { $_ => 1 } @attributes;

  for my $name (@attributes) {
    no strict 'refs';
    *{"SL::Helper::Inventory::Allocation::$name"} = sub { $_[0]{$name} };
  }

  sub new {
    my ($class, %params) = @_;

    Carp::croak("missing attribute $_") for grep { !exists $params{$_}     } @attributes;
    Carp::croak("unknown attribute $_") for grep { !exists $attributes{$_} } keys %params;
    Carp::croak("$_ must be set")       for grep { !$params{$_} } qw(parts_id qty bin_id);
    Carp::croak("$_ must be positive")  for grep { !($params{$_} > 0) } qw(parts_id qty bin_id);

    bless { %params }, $class;
  }
}

1;

=encoding utf-8

=head1 NAME

SL::WH - Warehouse and Inventory API

=head1 SYNOPSIS

  # See description for an intro to the concepts used here.

  use SL::Helper::Inventory;

  # stock, get "what's there" for a part with various conditions:
  my $qty = SL::Helper::Inventory->get_stock(part => $part);                              # how much is on stock?
  my $qty = SL::Helper::Inventory->get_stock(part => $part, date => $date);               # how much was on stock at a specific time?
  my $qty = SL::Helper::Inventory->get_stock(part => $part, bin => $bin);                 # how is on stock in a specific bin?
  my $qty = SL::Helper::Inventory->get_stock(part => $part, warehouse => $warehouse);     # how is on stock in a specific warehouse?
  my $qty = SL::Helper::Inventory->get_stock(part => $part, chargenumber => $chargenumber); # how is on stock of a specific chargenumber?

  # onhand, get "what's available" for a part with various conditions:
  my $qty = SL::Helper::Inventory->get_onhand(part => $part);                              # how much is available?
  my $qty = SL::Helper::Inventory->get_onhand(part => $part, date => $date);               # how much was available at a specific time?
  my $qty = SL::Helper::Inventory->get_onhand(part => $part, bin => $bin);                 # how much is available in a specific bin?
  my $qty = SL::Helper::Inventory->get_onhand(part => $part, warehouse => $warehouse);     # how much is available in a specific warehouse?
  my $qty = SL::Helper::Inventory->get_onhand(part => $part, chargenumber => $chargenumber); # how much is availbale of a specific chargenumber?
  my $qty = SL::Helper::Inventory->get_onhand(part => $part, reserve_for => $order);       # how much is available if you include this reservation?

  # onhand batch mode:
  my $data = SL::Helper::Inventory->get_onhand(
    warehouse    => $warehouse,
    by           => [ qw(bin part chargenumber reserve_for) ],
    with_objects => [ qw(bin part) ],
  );

  # allocate:
  my @allocations, SL::Helper::Inventory->allocate(
    part         => $part,          # part_id works too
    qty          => $qty,           # must be positive
    chargenumber => $chargenumber,  # optional, may be arrayref. if provided these charges will be used first
    bestbefore   => $datetime,      # optional, defaults to today. items with bestbefore prior to that date wont be used
    reserve_for  => $object,        # optional, may be arrayref. if provided the qtys reserved for these objects will be used first
    bin          => $bin,           # optional, may be arrayref. if provided
  );

  # shortcut to allocate all that is needed for producing an assembly, will use chargenumbers as appropriate
  my @allocations, SL::Helper::Inventory->allocate_for_assembly(
    part         => $assembly,      # part_id works too
    qty          => $qty,           # must be positive
  );

  # create allocation manually, bypassing checks, all of these need to be passed, even undefs
  my $allocation = SL::Helper::Inventory::Allocation->new(
    part_id           => $part->id,
    qty               => 15,
    bin_id            => $bin_obj->id,
    warehouse_id      => $bin_obj->warehouse_id,
    chargenumber      => '1823772365',
    bestbefore        => undef,
    reserve_for_id    => undef,
    reserve_for_table => undef,
    oe_id             => $my_document,
  );

  # produce_assembly:
  SL::Helper::Inventory->produce_assembly(
    part         => $part,           # target assembly
    qty          => $qty,            # qty
    allocations  => \@allocations,   # allocations to use. alternatively use "auto_allocate => 1,"

    # where to put it
    bin          => $bin,           # needed unless a global standard target is configured
    chargenumber => $chargenumber,  # optional
    bestbefore   => $datetime,      # optional
    comment      => $comment,       # optional

    # links, all optional
    production_order_item => $item,
    reserve_for           => $object,
  );

=head1 DESCRIPTION

New functions for the warehouse and inventory api.

The WH api currently has three large shortcomings. It is very hard to just get
the current stock for an item, it's extremely complicated to use it to produce
assemblies while ensuring that no stock ends up negative, and it's very hard to
use it to get an overview over the actual contents of the inventory.

The first problem has spawned several dozen small functions in the program that
try to implement that, and those usually miss some details. They may ignore
reservations, or reserve warehouses, or bestbefore times.

To get this cleaned up a bit this code introduces two concepts: stock and onhand.

Stock is defined as the actual contents of the inventory, everything that is
there. Onhand is what is available, which means things that are stocked and not
reserved and not expired.

The two new functions C<get_stock> and C<get_onhand> encapsulate these principles and
allow simple access with some optional filters for chargenumbers or warehouses.
Both of them have a batch mode that can be used to get these information to
supllement smiple reports.

To address the safe assembly creation a new function has been added.
C<allocate> will try to find the requested quantity of a part in the inventory
and will return allocations of it which can then be used to create the
assembly. Allocation will happen with the C<onhand> semantics defined above,
meaning that by default no reservations or expired goods will be used. The
caller can supply hints of what shold be used and in those cases chargenumber
and reservations will be used up as much as possible first.  C<allocate> will
always try to fulfil the request even beyond those. Should the required amount
not be stocked, allocate will throw an exception.

C<produce_assembly> has been rewritten to only accept parameters about the
target of the production, and requires allocations to complete the request. The
allocations can be supplied manually, or can be generated automatically.
C<produce_assembly> will check whether enough allocations are given to create
the recipe, but will not check whether the allocations are backed. If the
allocations are not sufficient or if the auto-allocation fails an exception
is returned. If you need to produce something that is not in the inventory, you
can bypass those checks by creating the allocations yourself (see
L</"ALLOCATION DATA STRUCTURE">).

Note: this is only intended to cover the scenarios described above. For other cases:

=over 4

=item *

If you need the reserved amount for an order use C<SL::DB::Helper::Reservation>
instead.

=item *

If you need actual inventory objects because of record links, prod_id links or
something like that load them directly. And strongly consider redesigning that,
because it's really fragile.

=item *

You need weight or accounting information you're on your own. The inventory api
only concerns itself with the raw quantities.

=item *

If you need the first stock date of parts, or anything related to a specific
transfer type or direction, this is not covered yet.

=back

=head1 FUNCTIONS

=over 4

=item * get_stock PARAMS

Returns for single parts how much actually exists in the inventory.

Options:

=over 4

=item * part

The part. Must be present without C<by>. May be arrayref with C<by>. Can be object or id.

=item * bin

If given, will only return stock on these bins. Optional. May be array, May be object or id.

=item * warehouse

If given, will only return stock on these warehouses. Optional. May be array, May be object or id.

=item * date

If given, will return stock as it were on this timestamp. Optional. Must be L<DateTime> object.

=item * chargenumber

If given, will only show stock with this chargenumber. Optional. May be array.

=item * by

See L</"STOCK/ONHAND REPORT MODE">

=item * with_objects

See L</"STOCK/ONHAND REPORT MODE">

=back

Will return a single qty normally, see L</"STOCK/ONHAND REPORT MODE"> for batch
mode when C<by> is given.

=item * get_onhand PARAMS

Returns for single parts how much is available in the inventory. That excludes:
reserved quantities, reserved warehouses and stock with expired bestbefore.

It takes all options of L</get_stock> but treats some of the differently and has some additional ones:

=over 4

=item * warehouse

Usually C<onhand> will not include results from warehouses with the C<reserve>
flag. However giving an explicit list of warehouses will include there in the
search, as well as all others.

=item * reserve_for

=item * reserve_warehouse

=item * bestbefore

=back

=item * allocate PARAMS

Accepted parameters:

=over 4

=item * part

=item * qty

=item * bin

Bin object. Optional.

=item * warehouse

Warehouse object. Optional.

=item * chargenumber

Optional.

=item * bestbefore

Datetime. Optional.

=item * reserve_for

Needs to be a rose object, where id and table can be extracted. Optional.

=back

Tries to allocate the required quantity using what is currently onhand. If
given any of C<bin>, C<warehouse>, C<chargenumber>, C<reserve_for>


=item * allocate_for_assembly PARAMS

Shortcut to allocate everything for an assembly. Takes the same arguments. Will
compute the required amount for each assembly part and allocate all of them.

=item * produce_assembly


=back

=head1 STOCK/ONHAND REPORT MODE

If the special option C<by> is given with an arrayref, the result will instead
be an arrayref of partitioned stocks by those fields. Valid partitions are:

=over 4

=item * part

If this is given, part is optional in the parameters

=item * bin

=item * warehouse

=item * chargenumber

=item * bestbefore

=item * reserve_for

=back

Note: If you want to use the returned data to create allocations you I<need> to
enable all of these. To make this easier a special shortcut exists

In this mode, C<with_objects> can be used to load C<warehouse>, C<bin>,
C<parts>, and the C<reserve_for> objects in one go, just like with Rose. They
need to be present in C<by> before that though.

=head1 ALLOCATION ALGORITHM

When calling allocate, the current onhand (== available stock) of the item will
be used to decide which bins/chargenumbers/bestbefore can be used.

In general allocate will try to make the request happen, and will use the
provided charges up first, and then tap everything else. If you need to only
I<exactly> use the provided charges, you'll need to craft the allocations
yourself. See L</"ALLOCATION DATA STRUCTURE"> for that.

If C<reserve_for> is given, those will be used up first too.

If C<reserved_warehouse> is given, those will be used up second.

If C<chargenumber> is given, those will be used up next.

After that normal quantities will be used.

These are tiebreakers and expected to rarely matter in reality. If you need
finegrained control over which allocation is used, you may want to get the
onhands yourself and select the appropriate ones.

Only quantities with C<bestbefore> unset or after the given date will be
considered. If more than one charge is eligible, the earlier C<bestbefore>
will be used.

Allocations do NOT have an internal memory and can't react to other allocations
of the same part earlier. Never double allocate the same part within a
transaction.

=head1 ALLOCATION DATA STRUCTURE

Allocations are instances of the helper class C<SL::Helper::Inventory::Allocation>. They require
each of the following attributes to be set at creation time:

=over 4

=item * parts_id

=item * qty

=item * bin_id

=item * warehouse_id

=item * chargenumber

=item * bestbefore

=item * reserve_for_id

=item * reserve_for_table

=item * oe_id

Must be explicit set if the allocation needs also an (other) document.

=back

C<chargenumber>, C<bestbefore>, C<reserve_for_id>, C<reserve_for_table> and oe_id  may
be C<undef> (but must still be present at creation time). Instances are
considered immutable.


=head1 CONSTRAINTS

  # whitelist constraints
  ->allocate(
    ...
    constraints => {
      bin_id       => \@allowed_bins,
      chargenumber => \@allowed_chargenumbers,
    }
  );

  # custom constraints
  ->allocate(
    constraints => sub {
      # only allow chargenumbers with specific format
      all { $_->chargenumber =~ /^ C \d{8} - \a{d2} $/x } @_

      &&
      # and must be all reservations
      all { $_->reserve_for_id } @_;
    }
  )

C<allocation> is "best effort" in nature. It will take the C<bin>,
C<chargenumber> etc hints from the parameters, but will try it's bvest to
fulfil the request anyway and only bail out if it is absolutely not possible.

Sometimes you need to restrict allocations though. For this you can pass
additional constraints to C<allocate>. A constraint serves as a whitelist.
Every allocation must fulfil every constraint by having that attribute be one
of the given values.

In case even that is not enough, you may supply a custom check by passing a
function that will be given the allocation objects.

Note that both whitelists and constraints do not influence the order of
allocations, which is done purely from the initial parameters. They only serve
to reject allocations made in good faith which do fulfil required assertions.

=head1 ERROR HANDLING

C<allocate> and C<produce_assembly> will throw exceptions if the request can
not be completed. The usual reason will be insufficient onhand to allocate, or
insufficient allocations to process the request.

=head1 TODO

  * define and describe error classes
  * define wrapper classes for stock/onhand batch mode return values
  * handle extra arguments in produce: shippingdate, project, oe
  * clean up allocation helper class
  * with objects for reservations
  * document no_ check
  * tests

=head1 BUGS

None yet :)

=head1 AUTHOR

Sven Schöling E<lt>sven.schoeling@opendynamic.deE<gt>

=cut
