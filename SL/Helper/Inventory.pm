package SL::Helper::Inventory;

use strict;
use Carp;
use DateTime;
use Exporter qw(import);
use List::Util qw(min sum);
use List::UtilsBy qw(sort_by);
use List::MoreUtils qw(any none);
use POSIX qw(ceil);
use Scalar::Util qw(blessed);

use SL::Locale::String qw(t8);
use SL::MoreCommon qw(listify);
use SL::DBUtils qw(selectall_hashref_query selectrow_query);
use SL::DB::TransferType;
use SL::Helper::Number qw(_format_number _round_number);
use SL::Helper::Inventory::Allocation;
use SL::X;

our @EXPORT_OK = qw(get_stock get_onhand allocate allocate_for_assembly produce_assembly check_constraints check_allocations_for_assembly);
our %EXPORT_TAGS = (ALL => \@EXPORT_OK);

sub _get_stock_onhand {
  my (%params) = @_;

  my $onhand_mode = !!$params{onhand};

  my @selects = (
    'SUM(qty) AS qty',
    'MIN(EXTRACT(epoch FROM inventory.itime)) AS itime',
  );
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
    Carp::croak("not DateTime ".$params{date}) unless ref($params{date}) eq 'DateTime';
    push @where, sprintf "shippingdate <= ?";
    push @values, $params{date};
  }

  if (!$params{bestbefore} && $onhand_mode && default_show_bestbefore()) {
    $params{bestbefore} = DateTime->now_local;
  }

  if ($params{bestbefore}) {
    Carp::croak("not DateTime ".$params{date}) unless ref($params{bestbefore}) eq 'DateTime';
    push @where, sprintf "(bestbefore IS NULL OR bestbefore >= ?)";
    push @values, $params{bestbefore};
  }

  # by
  my %allowed_by = (
    part          => [ qw(parts_id) ],
    bin           => [ qw(bin_id inventory.warehouse_id)],
    warehouse     => [ qw(inventory.warehouse_id) ],
    chargenumber  => [ qw(chargenumber) ],
    bestbefore    => [ qw(bestbefore) ],
    for_allocate  => [ qw(parts_id bin_id inventory.warehouse_id chargenumber bestbefore) ],
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

  if ($onhand_mode) {
    $query .= ' HAVING SUM(qty) > 0';
  }

  my $results = selectall_hashref_query($::form, SL::DB->client->dbh, $query, @values);

  my %with_objects = (
    part         => 'SL::DB::Manager::Part',
    bin          => 'SL::DB::Manager::Bin',
    warehouse    => 'SL::DB::Manager::Warehouse',
  );

  my %slots = (
    part      =>  'parts_id',
    bin       =>  'bin_id',
    warehouse =>  'warehouse_id',
  );

  if ($params{by} && $params{with_objects}) {
    for my $with_object (listify($params{with_objects})) {
      Carp::croak("unknown with_object $with_object") if !exists $with_objects{$with_object};

      my $manager = $with_objects{$with_object};
      my $slot = $slots{$with_object};
      next if !(my @ids = map { $_->{$slot} } @$results);
      my $objects = $manager->get_all(query => [ id => \@ids ]);
      my %objects_by_id = map { $_->id => $_ } @$objects;

      $_->{$with_object} = $objects_by_id{$_->{$slot}} for @$results;
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

  croak('allocate needs a part') unless $params{part};
  croak('allocate needs a qty')  unless $params{qty};

  my $part = $params{part};
  my $qty  = $params{qty};

  return () if $qty <= 0;

  my $results = get_stock(part => $part, by => 'for_allocate');
  my %bin_whitelist = map { (ref $_ ? $_->id : $_) => 1 } grep defined, listify($params{bin});
  my %wh_whitelist  = map { (ref $_ ? $_->id : $_) => 1 } grep defined, listify($params{warehouse});
  my %chargenumbers = map { (ref $_ ? $_->id : $_) => 1 } grep defined, listify($params{chargenumber});

  # sort results so that chargenumbers are matched first, then wanted bins, then wanted warehouses
  my @sorted_results = sort {
       exists $chargenumbers{$b->{chargenumber}}  <=> exists $chargenumbers{$a->{chargenumber}} # then prefer wanted chargenumbers
    || exists $bin_whitelist{$b->{bin_id}}        <=> exists $bin_whitelist{$a->{bin_id}}       # then prefer wanted bins
    || exists $wh_whitelist{$b->{warehouse_id}}   <=> exists $wh_whitelist{$a->{warehouse_id}}  # then prefer wanted bins
    || $a->{itime}                                <=> $b->{itime}                               # and finally prefer earlier charges
  } @$results;
  my @allocations;
  my $rest_qty = $qty;

  for my $chunk (@sorted_results) {
    my $qty = min($chunk->{qty}, $rest_qty);

    # since allocate operates on stock, this also ensures that no negative stock results are used
    if ($qty > 0) {
      push @allocations, SL::Helper::Inventory::Allocation->new(
        parts_id          => $chunk->{parts_id},
        qty               => $qty,
        comment           => $params{comment},
        bin_id            => $chunk->{bin_id},
        warehouse_id      => $chunk->{warehouse_id},
        chargenumber      => $chunk->{chargenumber},
        bestbefore        => $chunk->{bestbefore},
        for_object_id     => undef,
      );
      $rest_qty -=  _round_number($qty, 5);
    }
    $rest_qty = _round_number($rest_qty, 5);
    last if $rest_qty == 0;
  }
  if ($rest_qty > 0) {
    die SL::X::Inventory::Allocation::MissingQty->new(
      code             => 'not enough to allocate',
      message          => t8("can not allocate #1 units of #2, missing #3 units", _format_number($qty), $part->displayable_name, _format_number($rest_qty)),
      part             => $part,
      to_allocate_qty  => $qty,
      missing_qty      => $rest_qty,
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
  my $wh   = $params{warehouse};
  my $wh_strict         = $::instance_conf->get_produce_assembly_same_warehouse;
  my $consume_service   = $::instance_conf->get_produce_assembly_transfer_service;
  my $allow_empty_items = $::instance_conf->get_produce_assembly_allow_empty_items;

  Carp::croak('not an assembly')       unless $part->is_assembly;
  Carp::croak('No warehouse selected') if $wh_strict && !$wh;

  my %parts_to_allocate;

  for my $assembly ($part->assemblies) {
    next if $assembly->part->type eq 'service' && !$consume_service;
    next if $assembly->qty == 0                && $allow_empty_items;

    $parts_to_allocate{ $assembly->part->id } //= 0;
    $parts_to_allocate{ $assembly->part->id } += $assembly->qty * $qty;
  }

  my (@allocations, @errors);

  for my $part_id (keys %parts_to_allocate) {
    my $part = SL::DB::Part->load_cached($part_id);

    eval {
      push @allocations, allocate(%params, part => $part, qty => $parts_to_allocate{$part_id});
      if ($wh_strict) {
        die SL::X::Inventory::Allocation->new(
          code    => "wrong warehouse for part",
          message => t8('Part #1 exists in warehouse #2, but not in warehouse #3 ',
                          $part->partnumber . ' ' . $part->description,
                          SL::DB::Manager::Warehouse->find_by(id => $allocations[-1]->{warehouse_id})->description,
                          $wh->description),
        ) unless $allocations[-1]->{warehouse_id} == $wh->id;
      }
      1;
    } or do {
      my $ex = $@;
      die $ex unless blessed($ex) && $ex->can('rethrow');

      if ($ex->isa('SL::X::Inventory::Allocation')) {
        push @errors, $@;
      } else {
        $ex->rethrow;
      }
    };
  }

  if (@errors) {
    die SL::X::Inventory::Allocation::Multi->new(
      code    => "multiple errors during allocation",
      message => "multiple errors during allocation",
      errors  => \@errors,
    );
  }

  @allocations;
}

sub check_constraints {
  my ($constraints, $allocations) = @_;
  if ('CODE' eq ref $constraints) {
    if (!$constraints->(@$allocations)) {
      die SL::X::Inventory::Allocation->new(
        code    => 'allocation constraints failure',
        message => t8("Allocations didn't pass constraints"),
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
      next unless defined $constraints->{$_};

      my %whitelist = map { (ref $_ ? $_->id : $_) => 1 } listify($constraints->{$_});
      my $accessor = $supported_constraints{$_};

      if (any { !$whitelist{$_->$accessor} } @$allocations) {
        my %error_constraints = (
          bin_id         => t8('Bins'),
          warehouse_id   => t8('Warehouses'),
          chargenumber   => t8('Chargenumbers'),
        );
        my @allocs = grep { $whitelist{$_->$accessor} } @$allocations;
        my $needed = sum map { $_->qty } grep { !$whitelist{$_->$accessor} } @$allocations;
        my $err    = t8("Cannot allocate parts.");
        $err      .= ' '.t8('part \'#\'1 in bin \'#2\' only with qty #3 (need additional #4) and chargenumber \'#5\'.',
              SL::DB::Part->load_cached($_->parts_id)->description,
              SL::DB::Bin->load_cached($_->bin_id)->full_description,
              _format_number($_->qty), _format_number($needed), $_->chargenumber ? $_->chargenumber : '--') for @allocs;
        die SL::X::Inventory::Allocation->new(
          code    => 'allocation constraints failure',
          message => $err,
        );
      }
    }
  }
}

sub produce_assembly {
  my (%params) = @_;

  my $part = $params{part} or Carp::croak('produce_assembly needs a part');
  my $qty  = $params{qty}  or Carp::croak('produce_assembly needs a qty');
  my $bin  = $params{bin}  or Carp::croak("need target bin");

  my $allocations = $params{allocations};
  my $strict_wh = $::instance_conf->get_produce_assembly_same_warehouse ? $bin->warehouse : undef;
  my $consume_service = $::instance_conf->get_produce_assembly_transfer_service;

  if ($params{auto_allocate}) {
    Carp::croak("produce_assembly: can't have both allocations and auto_allocate") if $params{allocations};
    $allocations = [ allocate_for_assembly(part => $part, qty => $qty, warehouse => $strict_wh, chargenumber => $params{chargenumber}) ];
  } else {
    Carp::croak("produce_assembly: need allocations or auto_allocate to produce something") if !$params{allocations};
    $allocations = $params{allocations};
  }

  my $chargenumber  = $params{chargenumber};
  my $bestbefore    = $params{bestbefore};
  my $for_object_id = $params{for_object_id};
  my $comment       = $params{comment} // '';
  my $invoice       = $params{invoice};
  my $project       = $params{project};
  my $shippingdate  = $params{shippingsdate} // DateTime->now_local;
  my $trans_id      = $params{trans_id};

  ($trans_id) = selectrow_query($::form, SL::DB->client->dbh, qq|SELECT nextval('id')| ) unless $trans_id;

  my $trans_type_out = SL::DB::Manager::TransferType->find_by(direction => 'out', description => 'used');
  my $trans_type_in  = SL::DB::Manager::TransferType->find_by(direction => 'in',  description => 'assembled');

  # check whether allocations are sane
  if (!$params{no_check_allocations} && !$params{auto_allocate}) {
    die SL::X::Inventory::Allocation->new(
      code    => "allocations are insufficient for production",
      message => t8('can not allocate enough resources for production'),
    ) if !check_allocations_for_assembly(part => $part, qty => $qty, allocations => $allocations);
  }

  my @transfers;
  for my $allocation (@$allocations) {
    my $oe_id = delete $allocation->{for_object_id};
    push @transfers, $allocation->transfer_object(
      trans_id     => $trans_id,
      qty          => -$allocation->qty,
      trans_type   => $trans_type_out,
      shippingdate => $shippingdate,
      employee     => SL::DB::Manager::Employee->current,
      comment      => t8('Used for assembly #1 #2', $part->partnumber, $part->description),
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
    shippingdate      => $shippingdate,
    project           => $project,
    invoice           => $invoice,
    comment           => $comment,
    employee          => SL::DB::Manager::Employee->current,
    oe_id             => $for_object_id,
  );

  SL::DB->client->with_transaction(sub {
    $_->save for @transfers;
    1;
  }) or do {
    die SL::DB->client->error;
  };

  @transfers;
}

sub check_allocations_for_assembly {
  my (%params) = @_;

  my $part = $params{part} or Carp::croak('check_allocations_for_assembly needs a part');
  my $qty  = $params{qty}  or Carp::croak('check_allocations_for_assembly needs a qty');

  my $check_overfulfilment = !!$params{check_overfulfilment};
  my $allocations          = $params{allocations};

  my $consume_service      = $::instance_conf->get_produce_assembly_transfer_service;

  my %allocations_by_part;
  for (@{ $allocations || []}) {
    $allocations_by_part{$_->parts_id} //= 0;
    $allocations_by_part{$_->parts_id}  += $_->qty;
  }

  for my $assembly ($part->assemblies) {
    next if $assembly->part->type eq 'service' && !$consume_service;
    $allocations_by_part{ $assembly->parts_id } -= $assembly->qty * $qty;
  }

  return (none { $_ < 0 } values %allocations_by_part) && (!$check_overfulfilment || (none { $_ > 0 } values %allocations_by_part));
}

sub check_stock_out_transfer_requests {
  my (%params) = @_;

  my $transfer_requests = $params{transfer_requests} or Carp::croak('check_stock_out_transfer_requests needs transfer_requests');
  my $default_transfer = $params{default_transfer} || 0;

  my $grouped_qtys; # part_id -> bin_id -> chargenumber -> bestbefore -> qty;
  my %part_ids;
  my %bin_ids;
  my %chargenumbers;
  foreach my $request (@$transfer_requests) {
    $grouped_qtys
      ->{$request->parts_id}
      ->{$request->bin_id}
      ->{$request->chargenumber}
      ->{$request->bestbefore} += -$request->qty; # qty is negative
    $bin_ids{$request->bin_id} = 1;
    $chargenumbers{$request->chargenumber} = 1;
  }

  my $stocks = get_stock(
    by => [qw(part bin chargenumber bestbefore)],
    part => [keys %$grouped_qtys],
    bin  => [keys %bin_ids],
    chargenumber => [keys %chargenumbers],
  );

  # make stock searchable
  my $available_qty;
  foreach my $stock (@$stocks) {
    $available_qty
      ->{$stock->{parts_id}}
      ->{$stock->{bin_id}}
      ->{$stock->{chargenumber}}
      ->{DateTime->from_kivitendo($stock->{bestbefore}) || undef} = $stock->{qty};
  }

  my @missing_qtys;
  foreach my $p_id (keys %{$grouped_qtys}) {
    foreach my $b_id (keys %{$grouped_qtys->{$p_id}}) {
      next if $default_transfer
           && $::instance_conf->get_transfer_default_ignore_onhand
           && $::instance_conf->get_bin_id_ignore_onhand eq $b_id;
      foreach my $cn (keys %{$grouped_qtys->{$p_id}->{$b_id}}) {
        foreach my $bb (keys %{$grouped_qtys->{$p_id}->{$b_id}->{$cn}}) {
          my $available_stock = $available_qty->{$p_id}->{$b_id}->{$cn}->{$bb};
          if ($available_stock < $grouped_qtys->{$p_id}->{$b_id}->{$cn}->{$bb}) {
            my $part = SL::DB::Manager::Part->find_by(id => $p_id);
            my $bin  = SL::DB::Manager::Bin->find_by(id => $b_id);
            push @missing_qtys, {
              missing_qty  => $grouped_qtys->{$p_id}->{$b_id}->{$cn}->{$bb} - $available_stock,
              part         => $part,
              bin          => $bin,
              chargenumber => $cn,
              bestbefore   => $bb
            }
          }
        }
      }
    }
  }

  return @missing_qtys;
}

sub default_show_bestbefore {
  $::instance_conf->get_show_bestbefore
}

1;

=encoding utf-8

=head1 NAME

SL::WH - Warehouse and Inventory API

=head1 SYNOPSIS

  # See description for an intro to the concepts used here.

  use SL::Helper::Inventory qw(:ALL);

  # stock, get "what's there" for a part with various conditions:
  my $qty = get_stock(part => $part);                              # how much is on stock?
  my $qty = get_stock(part => $part, date => $date);               # how much was on stock at a specific time?
  my $qty = get_stock(part => $part, bin => $bin);                 # how much is on stock in a specific bin?
  my $qty = get_stock(part => $part, warehouse => $warehouse);     # how much is on stock in a specific warehouse?
  my $qty = get_stock(part => $part, chargenumber => $chargenumber); # how much is on stock of a specific chargenumber?

  # onhand, get "what's available" for a part with various conditions:
  my $qty = get_onhand(part => $part);                              # how much is available?
  my $qty = get_onhand(part => $part, date => $date);               # how much was available at a specific time?
  my $qty = get_onhand(part => $part, bin => $bin);                 # how much is available in a specific bin?
  my $qty = get_onhand(part => $part, warehouse => $warehouse);     # how much is available in a specific warehouse?
  my $qty = get_onhand(part => $part, chargenumber => $chargenumber); # how much is availbale of a specific chargenumber?

  # onhand batch mode:
  my $data = get_onhand(
    warehouse    => $warehouse,
    by           => [ qw(bin part chargenumber) ],
    with_objects => [ qw(bin part) ],
  );

  # allocate:
  my @allocations = allocate(
    part         => $part,          # part_id works too
    qty          => $qty,           # must be positive
    chargenumber => $chargenumber,  # optional, may be arrayref. if provided these charges will be used first
    bestbefore   => $datetime,      # optional, defaults to today. items with bestbefore prior to that date wont be used
    bin          => $bin,           # optional, may be arrayref. if provided
  );

  # shortcut to allocate all that is needed for producing an assembly, will use chargenumbers as appropriate
  my @allocations = allocate_for_assembly(
    part         => $assembly,      # part_id works too
    qty          => $qty,           # must be positive
  );

  # create allocation manually, bypassing checks. all of these need to be passed, even undefs
  my $allocation = SL::Helper::Inventory::Allocation->new(
    parts_id          => $part->id,
    qty               => 15,
    bin_id            => $bin_obj->id,
    warehouse_id      => $bin_obj->warehouse_id,
    chargenumber      => '1823772365',
    bestbefore        => undef,
    comment           => undef,
    for_object_id     => $order->id,
  );

  # produce_assembly:
  produce_assembly(
    part         => $part,           # target assembly
    qty          => $qty,            # qty
    allocations  => \@allocations,   # allocations to use. alternatively use "auto_allocate => 1,"

    # where to put it
    bin          => $bin,           # needed unless a global standard target is configured
    chargenumber => $chargenumber,  # optional
    bestbefore   => $datetime,      # optional
    comment      => $comment,       # optional
  );

=head1 DESCRIPTION

New functions for the warehouse and inventory api.

The WH api currently has three large shortcomings: It is very hard to just get
the current stock for an item, it's extremely complicated to use it to produce
assemblies while ensuring that no stock ends up negative, and it's very hard to
use it to get an overview over the actual contents of the inventory.

The first problem has spawned several dozen small functions in the program that
try to implement that, and those usually miss some details. They may ignore
bestbefore times, comments, ignore negative quantities etc.

To get this cleaned up a bit this code introduces two concepts: stock and onhand.

=over 4

=item * Stock is defined as the actual contents of the inventory, everything that is
there.

=item * Onhand is what is available, which means things that are stocked,
not expired and not in any other way reserved for other uses.

=back

The two new functions C<get_stock> and C<get_onhand> encapsulate these principles and
allow simple access with some optional filters for chargenumbers or warehouses.
Both of them have a batch mode that can be used to get these information to
supplement simple reports.

To address the safe assembly creation a new function has been added.
C<allocate> will try to find the requested quantity of a part in the inventory
and will return allocations of it which can then be used to create the
assembly. Allocation will happen with the C<onhand> semantics defined above,
meaning that by default no expired goods will be used. The caller can supply
hints of what shold be used and in those cases chargenumbers will be used up as
much as possible first. C<allocate> will always try to fulfil the request even
beyond those. Should the required amount not be stocked, allocate will throw an
exception.

C<produce_assembly> has been rewritten to only accept parameters about the
target of the production, and requires allocations to complete the request. The
allocations can be supplied manually, or can be generated automatically.
C<produce_assembly> will check whether enough allocations are given to create
the assembly, but will not check whether the allocations are backed. If the
allocations are not sufficient or if the auto-allocation fails an exception
is returned. If you need to produce something that is not in the inventory, you
can bypass those checks by creating the allocations yourself (see
L</"ALLOCATION DATA STRUCTURE">).

Note: this is only intended to cover the scenarios described above. For other cases:

=over 4

=item *

If you need actual inventory objects because of record links or something like
that load them directly. And strongly consider redesigning that, because it's
really fragile.

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

Returns for single parts how much is available in the inventory. That excludes
stock with expired bestbefore.

It takes the same options as L</get_stock>.

=over 4

=item * bestbefore

If given, will only return stock with a bestbefore at or after the given date.
Optional. Must be L<DateTime> object.

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

=back

Tries to allocate the required quantity using what is currently onhand. If
given any of C<bin>, C<warehouse>, C<chargenumber>

=item * allocate_for_assembly PARAMS

Shortcut to allocate everything for an assembly. Takes the same arguments. Will
compute the required amount for each assembly part and allocate all of them.

=item * produce_assembly

=item * check_allocations_for_assembly PARAMS

Checks if enough quantity is allocated for production. Returns a trueish
value if there is enough allocated, a falsish one otherwise (but see the
parameter C<check_overfulfilment>).

Accepted parameters:

=over 4

=item * part

The part object to be assembled. Mandatory.

=item * qty

The quantity of the part to be assembled. Mandatory.

=item * allocations

An array ref of the allocations.

=item * check_overfulfilment

Whether or not overfulfilment should be checked. If more quantity is allocated
than needed for production a falsish value is returned. Optional.

=back

=item * check_stock_out_transfer_requests PARAMS

Checks if enough stock is availbale for the transfer requests. Returns a list
of missing quantities as hashref with the keys C<part>, C<bin>, C<missing_qty>, C<chargenumber>
and C<bestbefore>. C<chargenumber> and C<bestbefore> can be C<undef> if not set
in the transfer requests.

Accepted parameters:

=over 4

=item * transfer_requests

Transfer requests to stock out as arrayref. Mandatory.

=item * default_transfer

Has to be trueish if the transfer requests are for a delivery order called with
'Transfer out via default'. Optional, Default 0.

=back

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

=back

Note: If you want to use the returned data to create allocations you I<need> to
enable all of these. To make this easier a special shortcut exists

In this mode, C<with_objects> can be used to load C<warehouse>, C<bin>,
C<parts>  objects in one go, just like with Rose. They
need to be present in C<by> before that though.

=head1 ALLOCATION ALGORITHM

When calling allocate, the current onhand (== available stock) of the item will
be used to decide which bins/chargenumbers/bestbefore can be used.

In general allocate will try to make the request happen, and will use the
provided charges up first, and then tap everything else. If you need to only
I<exactly> use the provided charges, you'll need to craft the allocations
yourself. See L</"ALLOCATION DATA STRUCTURE"> for that.

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

=item * comment

=item * for_object_id

If set the allocations will be marked as allocated for the given object.
If these allocations are later used to produce an assembly, the resulting
consuming transactions will be marked as belonging to the given object.
The object may be an order, productionorder or other objects

=back

C<chargenumber>, C<bestbefore> and C<for_object_id> and C<comment> may be
C<undef> (but must still be present at creation time). Instances are considered
immutable.

Allocations also provide the method C<transfer_object> which will create a new
C<SL::DB::Inventory> bject with all the playload.

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
      # and must all have a bestbefore date
      all { $_->bestbefore } @_;
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

=head1 KNOWN PROBLEMS

  * It's not currently possible to identify allocations between requests, for
    example for presenting the user possible allocations and then actually using
    them on the next request.
  * It's not currently possible to give C<allocate> prior constraints.
    Currently all constraints are treated as hints (and will be preferred) but
    the internal ordering of the hints is fixed and more complex preferentials
    are not supported.
  * bestbefore handling is untested
  * interaction with config option "transfer_default_ignore_onhand" is
    currently undefined (and implicitly ignores it)

=head1 TODO

  * define and describe error classes
  * define wrapper classes for stock/onhand batch mode return values
  * handle extra arguments in produce: shippingdate, project
  * document no_ check
  * tests

=head1 BUGS

None yet :)

=head1 AUTHOR

Sven Schöling E<lt>sven.schoeling@googlemail.comE<gt>

=cut
