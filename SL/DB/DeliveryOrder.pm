package SL::DB::DeliveryOrder;

use strict;

use Carp;

use Rose::DB::Object::Helpers qw(as_tree strip);

use SL::DB::MetaSetup::DeliveryOrder;
use SL::DB::Manager::DeliveryOrder;
use SL::DB::Helper::AttrHTML;
use SL::DB::Helper::AttrSorted;
use SL::DB::Helper::FlattenToForm;
use SL::DB::Helper::LinkedRecords;
use SL::DB::Helper::TypeDataProxy;
use SL::DB::Helper::TransNumberGenerator;
use SL::DB::Helper::RecordLink qw(RECORD_ID RECORD_TYPE_REF);

use SL::DB::DeliveryOrder::TypeData qw(:types);
use SL::DB::Order::TypeData qw(:types);
use SL::DB::Reclamation::TypeData qw(:types);

use SL::Helper::Number qw(_format_total _round_total);
use SL::Helper::ShippedQty;

use List::Util qw(first);
use List::MoreUtils qw(any pairwise);
use Math::Round qw(nhimult);

__PACKAGE__->meta->add_relationship(orderitems => { type         => 'one to many',
                                                    class        => 'SL::DB::DeliveryOrderItem',
                                                    column_map   => { id => 'delivery_order_id' },
                                                    manager_args => { with_objects => [ 'part' ] }
                                                  },
                                    custom_shipto => {
                                      type        => 'one to one',
                                      class       => 'SL::DB::Shipto',
                                      column_map  => { id => 'trans_id' },
                                      query_args  => [ module => 'DO' ],
                                    },
                                   );

__PACKAGE__->meta->initialize;

__PACKAGE__->attr_html('notes');
__PACKAGE__->attr_sorted('items');

__PACKAGE__->before_save('_before_save_set_donumber');
__PACKAGE__->after_save('_after_save_link_records');
__PACKAGE__->after_save('_mark_orders_if_delivered');

# hooks

sub _before_save_set_donumber {
  my ($self) = @_;

  $self->create_trans_number if !$self->donumber;

  return 1;
}

sub _after_save_link_records {
  my ($self) = @_;

  my @allowed_record_sources = qw(SL::DB::Reclamation SL::DB::Order);
  my @allowed_item_sources = qw(SL::DB::ReclamationItem SL::DB::OrderItem);

  SL::DB::Helper::RecordLink::link_records(
    $self,
    \@allowed_record_sources,
    \@allowed_item_sources,
  );
}

sub _mark_orders_if_delivered {
  my ($self) = @_;
  my $orders = $self->linked_records(from => 'Order');
  SL::Helper::ShippedQty->new->calculate($orders)->write_to_objects;
  foreach my $order (@$orders) {
    next if $order->is_sales != $self->is_sales;
    $order->update_attributes(delivered => $order->{delivered});
  }
  return 1;
}

# methods

sub items { goto &orderitems; }
sub add_items { goto &add_orderitems; }
sub payment_terms { goto &payment; }
sub record_number { goto &donumber; }

sub sales_order {
  my $self   = shift;
  my %params = @_;


  require SL::DB::Order;
  my $orders = SL::DB::Manager::Order->get_all(
    query => [
      ordnumber => $self->ordnumber,
      @{ $params{query} || [] },
    ],
  );

  return first { $_->is_type(SALES_ORDER_TYPE()) } @{ $orders };
}

sub type {
  goto &record_type;
}

sub is_type {
  return shift->type eq shift;
}

sub displayable_type {
  my ($self) = @_;
  return $self->type_data->text('type');
}

sub displayable_name {
  join ' ', grep $_, map $_[0]->$_, qw(displayable_type record_number);
};

sub displayable_state {
  my ($self) = @_;

  return join '; ',
    ($self->closed    ? $::locale->text('closed')    : $::locale->text('open')),
    ($self->delivered ? $::locale->text('delivered') : $::locale->text('not delivered'));
}

sub date {
  goto &transdate;
}

sub number {
  goto &donumber;
}

sub preceding_purchase_order_confirmations {
  my ($self) = @_;

  my @lrs = ();
  if ($self->id) {
    @lrs = grep { $_->record_type eq PURCHASE_ORDER_CONFIRMATION_TYPE() } @{$self->linked_records(from => 'SL::DB::Order')};
  } else {
    if ('SL::DB::Order' eq $self->{RECORD_TYPE_REF()}) {
      my $order = SL::DB::Order->load_cached($self->{RECORD_ID()});
      push @lrs, $order if $order->record_type eq PURCHASE_ORDER_CONFIRMATION_TYPE();
    }
  }

  return \@lrs;
}

sub _clone_orderitem_cvar {
  my ($cvar) = @_;

  my $cloned = $_->clone_and_reset;
  $cloned->sub_module('delivery_order_items');

  return $cloned;
}

sub convert_to_reclamation {
  my ($self, %params) = @_;

  $params{destination_type} = $self->is_sales ? SALES_RECLAMATION_TYPE()
                                              : PURCHASE_RECLAMATION_TYPE();

  my $reclamation = SL::DB::Reclamation->new_from($self, %params);

  return $reclamation;
}

sub new_from {
  my ($class, $source, %params) = @_;

  my %allowed_sources = map { $_ => 1 } qw(
    SL::DB::Reclamation
    SL::DB::Order
    SL::DB::DeliveryOrder
  );
  unless( $allowed_sources{ref $source} ) {
    croak("Unsupported source object type '" . ref($source) . "'");
  }

  my %record_args = (
    donumber => undef,
    employee => SL::DB::Manager::Employee->current,
    closed    => 0,
    delivered => 0,
    record_type => $params{destination_type},
    transdate => DateTime->today_local,
  );

  if ( ref($source) eq 'SL::DB::Order' ) {
    map{ ( $record_args{$_} = $source->$_ ) } # {{{ for vim folds
    qw(
      billing_address_id
      cp_id
      currency_id
      cusordnumber
      customer_id
      delivery_term_id
      department_id
      globalproject_id
      intnotes
      language_id
      notes
      payment_id
      reqdate
      salesman_id
      shippingpoint
      shipvia
      taxincluded
      taxzone_id
      transaction_description
      vendor_confirmation_number
      vendor_id
    );
    if ($source->record_type eq PURCHASE_ORDER_CONFIRMATION_TYPE()) {
      $record_args{ordnumber} = join ' ', map { $_->ordnumber } @{$source->preceding_purchase_orders()};
    } else {
      $record_args{ordnumber} = $source->ordnumber;
    }
    # }}} for vim folds
  } elsif ( ref($source) eq 'SL::DB::Reclamation' ) {
    map{ ( $record_args{$_} = $source->$_ ) } # {{{ for vim folds
    qw(
      billing_address_id
      currency_id
      customer_id
      delivery_term_id
      department_id
      globalproject_id
      intnotes
      language_id
      notes
      payment_id
      reqdate
      salesman_id
      shippingpoint
      shipvia
      taxincluded
      taxzone_id
      transaction_description
      vendor_id
    );
    $record_args{cp_id} = $source->contact_id;
    $record_args{cusordnumber} = $source->cv_record_number;
    $record_args{is_sales} = $source->is_sales;
    # }}} for vim folds
  } elsif ( ref($source) eq 'SL::DB::DeliveryOrder' ) {
    map{ ( $record_args{$_} = $source->$_ ) } # {{{ for vim folds
    qw(
      billing_address_id
      cp_id
      currency_id
      cusordnumber
      customer_id
      delivery_term_id
      department_id
      donumber
      globalproject_id
      intnotes
      language_id
      notes
      ordnumber
      oreqnumber
      payment_id
      reqdate
      salesman_id
      shippingpoint
      shipto_id
      shipvia
      taxincluded
      taxzone_id
      transdate
      transaction_description
      vendor_confirmation_number
      vendor_id
    );
    # }}} for vim folds
  }

  # Custom shipto addresses (the ones specific to the sales/purchase
  # record and not to the customer/vendor) are only linked from
  # shipto → delivery_orders. Meaning delivery_orders.shipto_id
  # will not be filled in that case.
  if (!$source->shipto_id && $source->id) {
    $record_args{custom_shipto} = $source->custom_shipto->clone($class) if $source->can('custom_shipto') && $source->custom_shipto;
  } else {
    $record_args{shipto_id} = $source->shipto_id;
  }

  # infer type from legacy fields if not given
  $record_args{record_type} //= $source->customer_id ? SALES_DELIVERY_ORDER_TYPE()
                              : $source->vendor_id   ? PURCHASE_DELIVERY_ORDER_TYPE()
                              : $source->is_sales    ? SALES_DELIVERY_ORDER_TYPE()
                              : croak "need some way to set delivery order type from source";

  my $delivery_order = $class->new(%record_args);
  $delivery_order->assign_attributes(%{ $params{attributes} }) if $params{attributes};

  my $items = delete($params{items}) || $source->items_sorted;
  my @items = ( $delivery_order->is_type(SUPPLIER_DELIVERY_ORDER_TYPE()) && ref($source) ne 'SL::DB::Reclamation' ) ?
                ()
              : map { SL::DB::DeliveryOrderItem->new_from($_, %params) } @{ $items };

  @items = grep { $params{item_filter}->($_) } @items if $params{item_filter};
  @items = grep { $_->qty * 1 } @items if $params{skip_items_zero_qty};
  @items = grep { $_->qty >=0 } @items if $params{skip_items_negative_qty};

  $delivery_order->items(\@items);

  unless ($params{no_linked_records}) {
    $delivery_order->{ RECORD_ID() } = $source->id;
    $delivery_order->{ RECORD_TYPE_REF() } = ref $source;
  }

  return $delivery_order;
}

sub new_from_time_recordings {
  my ($class, $sources, %params) = @_;
  require SL::DB::Part;
  require SL::DB::Unit;

  croak("Unsupported object type in sources")                                      if any { ref($_) ne 'SL::DB::TimeRecording' }            @$sources;
  croak("Cannot create delivery order from source records of different customers") if any { $_->customer_id != $sources->[0]->customer_id } @$sources;

  # - one item per part (article)
  # - qty is sum of duration
  # - description goes to item longdescription
  #  - ordered and summed by date
  #  - each description goes to an ordered list
  #  - (as time recording descriptions are formatted text by now, use stripped text)
  #  - merge same descriptions
  #

  my $default_part_id  = $params{default_part_id}     ? $params{default_part_id}
                       : $params{default_partnumber}  ? SL::DB::Manager::Part->find_by(partnumber => $params{default_partnumber})->id
                       : undef;
  my $override_part_id = $params{override_part_id}    ? $params{override_part_id}
                       : $params{override_partnumber} ? SL::DB::Manager::Part->find_by(partnumber => $params{override_partnumber})->id
                       : undef;

  # check parts and collect entries
  my %part_by_part_id;
  my $entries;
  foreach my $source (@$sources) {
    next if !$source->duration;

    my $part_id   = $override_part_id;
    $part_id    ||= $source->part_id;
    $part_id    ||= $default_part_id;

    die 'article not found for entry "' . $source->displayable_times . '"' if !$part_id;

    if (!$part_by_part_id{$part_id}) {
      $part_by_part_id{$part_id} = SL::DB::Part->new(id => $part_id)->load;
      die 'article unit must be time based for entry "' . $source->displayable_times . '"' if !$part_by_part_id{$part_id}->unit_obj->is_time_based;
    }

    my $date = $source->date->to_kivitendo;
    $entries->{$part_id}->{$date}->{duration} += $params{rounding}
                                               ? nhimult(0.25, ($source->duration_in_hours))
                                               : _round_total($source->duration_in_hours);
    # add content if not already in description
    my $new_description = '' . $source->description_as_stripped_html;
    $entries->{$part_id}->{$date}->{content} ||= '';
    $entries->{$part_id}->{$date}->{content}  .= '<li>' . $new_description . '</li>'
      unless $entries->{$part_id}->{$date}->{content} =~ m/\Q$new_description/;

    $entries->{$part_id}->{$date}->{date_obj}  = $source->start_time || $source->date; # for sorting
  }

  my @items;

  my $h_unit = SL::DB::Manager::Unit->find_h_unit;

  my @keys = sort { $part_by_part_id{$a}->partnumber cmp $part_by_part_id{$b}->partnumber } keys %$entries;
  foreach my $key (@keys) {
    my $qty = 0;
    my $longdescription = '';

    my @dates = sort { $entries->{$key}->{$a}->{date_obj} <=> $entries->{$key}->{$b}->{date_obj} } keys %{$entries->{$key}};
    foreach my $date (@dates) {
      my $entry = $entries->{$key}->{$date};

      $qty             += $entry->{duration};
      $longdescription .= $date . ' <strong>' . _format_total($entry->{duration}) . ' h</strong>';
      $longdescription .= '<ul>';
      $longdescription .= $entry->{content};
      $longdescription .= '</ul>';
    }

    my $item = SL::DB::DeliveryOrderItem->new(
      parts_id        => $part_by_part_id{$key}->id,
      description     => $part_by_part_id{$key}->description,
      qty             => $qty,
      base_qty        => $h_unit->convert_to($qty, $part_by_part_id{$key}->unit_obj),
      unit_obj        => $h_unit,
      sellprice       => $part_by_part_id{$key}->sellprice, # Todo: use price rules to get sellprice
      longdescription => $longdescription,
    );

    push @items, $item;
  }

  my $delivery_order;

  if ($params{related_order}) {
    # collect suitable items in related order
    my @items_to_use;
    my @new_attributes;
    foreach my $item (@items) {
      my $item_to_use = first {$item->parts_id == $_->parts_id} @{ $params{related_order}->items_sorted };

      die "no suitable item found in related order" if !$item_to_use;

      my %new_attributes;
      $new_attributes{$_} = $item->$_ for qw(qty base_qty unit_obj longdescription);
      push @items_to_use,   $item_to_use;
      push @new_attributes, \%new_attributes;
    }

    $delivery_order = $class->new_from($params{related_order}, items => \@items_to_use, %params);
    pairwise { $a->assign_attributes( %$b) } @{$delivery_order->items}, @new_attributes;

  } else {
    my %args = (
      record_type => SALES_DELIVERY_ORDER_TYPE,
      delivered   => 0,
      customer_id => $sources->[0]->customer_id,
      taxzone_id  => $sources->[0]->customer->taxzone_id,
      currency_id => $sources->[0]->customer->currency_id,
      employee_id => SL::DB::Manager::Employee->current->id,
      salesman_id => SL::DB::Manager::Employee->current->id,
      items       => \@items,
    );
    $delivery_order = $class->new(%args);
    $delivery_order->assign_attributes(%{ $params{attributes} }) if $params{attributes};
  }

  return $delivery_order;
}

# legacy for compatibility
# use type_data cusomtervendor and transfer direction instead
sub is_sales {
  if ($_[0]->record_type) {
   return SL::DB::DeliveryOrder::TypeData::get3($_[0]->record_type, "properties", "is_customer");
  }
  return $_[0]{is_sales};
}

sub customervendor {
  SL::DB::DeliveryOrder::TypeData::get3($_[0]->record_type, "properties", "is_customer") ? $_[0]->customer : $_[0]->vendor;
}

sub convert_to_invoice {
  my ($self, %params) = @_;

  croak("Conversion to invoices is only supported for sales records") unless $self->customer_id;

  my $invoice;
  if (!$self->db->with_transaction(sub {
    require SL::DB::Invoice;
    $invoice = SL::DB::Invoice->new_from($self, %params)->post || die;
    $self->update_attributes(closed => 1);
    1;
  })) {
    return undef;
  }

  return $invoice;
}

sub digest {
  my ($self) = @_;

  sprintf "%s %s (%s)",
    $self->donumber,
    $self->customervendor->name,
    $self->date->to_kivitendo;
}

sub type_data {
  SL::DB::Helper::TypeDataProxy->new(ref $_[0], $_[0]->type);
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::DeliveryOrder - Rose model for delivery orders (table
"delivery_orders")

=head1 FUNCTIONS

=over 4

=item C<date>

An alias for C<transdate> for compatibility with other sales/purchase models.

=item C<displayable_name>

Returns a human-readable and translated description of the delivery order, consisting of
record type and number, e.g. "Verkaufslieferschein 123".

=item C<displayable_state>

Returns a human-readable description of the state regarding being
closed and delivered.

=item C<items>

An alias for C<delivery_order_items> for compatibility with other
sales/purchase models.

=item C<new_from $source, %params>

Creates a new C<SL::DB::DeliveryOrder> instance and copies as much
information from C<$source> as possible. At the moment only instances
of C<SL::DB::Order> (sales quotations, sales orders, requests for
quotations and purchase orders) are supported as sources.

The conversion copies order items into delivery order items. Dates are copied
as appropriate, e.g. the C<transdate> field will be set to the current date.

Returns the new delivery order instance. The object returned is not
saved.

C<%params> can include the following options:

=over 2

=item C<items>

An optional array reference of RDBO instances for the items to use. If
missing then the method C<items_sorted> will be called on
C<$source>. This option can be used to override the sorting, to
exclude certain positions or to add additional ones.

=item C<skip_items_negative_qty>

If trueish then items with a negative quantity are skipped. Items with
a quantity of 0 are not affected by this option.

=item C<skip_items_zero_qty>

If trueish then items with a quantity of 0 are skipped.

=item C<item_filter>

An optional code reference that is called for each item with the item
as its sole parameter. Items for which the code reference returns a
falsish value will be skipped.

=item C<attributes>

An optional hash reference. If it exists then it is passed to C<new>
allowing the caller to set certain attributes for the new delivery
order.

=back

=item C<new_from_time_recordings $sources, %params>

Creates a new C<SL::DB::DeliveryOrder> instance from the time recordings
given as C<$sources>. All time recording entries must belong to the same
customer. Time recordings are sorted by article and date. For each article
a new delivery order item is created. If no article is associated with an
entry, a default article will be used. The article given in the time
recording entry can be overriden.
Entries of the same date (for each article) are summed together and form a
list entry in the long description of the item.

The created delivery order object will be returnd but not saved.

C<$sources> must be an array reference of C<SL::DB::TimeRecording> instances.

C<%params> can include the following options:

=over 2

=item C<attributes>

An optional hash reference. If it exists then it is used to set
attributes of the newly created delivery order object.

=item C<default_part_id>

An optional part id which is used as default value if no part is set
in the time recording entry.

=item C<default_partnumber>

Like C<default_part_id> but given as partnumber, not as id.

=item C<override_part_id>

An optional part id which is used instead of a value set in the time
recording entry.

=item C<override_partnumber>

Like C<overrride_part_id> but given as partnumber, not as id.

=item C<related_order>

An optional C<SL::DB::Order> object. If it exists then it is used to
generate the delivery order from that via C<new_from>.
The generated items are created from a suitable item of the related
order. If no suitable item is found, an exception is thrown.

=item C<rounding>

An optional boolean value. If truish, then the durations of the time entries
are rounded up to the full quarters of an hour.

=back

=item C<sales_order>

TODO: Describe sales_order

=item C<type>

Returns a string describing this record's type: either
C<sales_delivery_order> or C<purchase_delivery_order>.

=item C<convert_to_invoice %params>

Creates a new invoice with C<$self> as the basis by calling
L<SL::DB::Invoice::new_from>. That invoice is posted, and C<$self> is
linked to the new invoice via L<SL::DB::RecordLink>. C<$self>'s
C<closed> attribute is set to C<true>, and C<$self> is saved.

The arguments in C<%params> are passed to L<SL::DB::Invoice::new_from>.

Returns the new invoice instance on success and C<undef> on
failure. The whole process is run inside a transaction. On failure
nothing is created or changed in the database.

At the moment only sales delivery orders can be converted.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
