package SL::DB::DeliveryOrder;

use strict;

use Carp;

use Rose::DB::Object::Helpers ();

use SL::DB::MetaSetup::DeliveryOrder;
use SL::DB::Manager::DeliveryOrder;
use SL::DB::Helper::AttrHTML;
use SL::DB::Helper::AttrSorted;
use SL::DB::Helper::FlattenToForm;
use SL::DB::Helper::LinkedRecords;
use SL::DB::Helper::TransNumberGenerator;

use SL::DB::Part;
use SL::DB::Unit;

use SL::Helper::Number qw(_format_total _round_total);

use List::Util qw(first notall);
use List::MoreUtils qw(any);
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

# hooks

sub _before_save_set_donumber {
  my ($self) = @_;

  $self->create_trans_number if !$self->donumber;

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

  return first { $_->is_type('sales_order') } @{ $orders };
}

sub type {
  return shift->customer_id ? 'sales_delivery_order' : 'purchase_delivery_order';
}

sub displayable_type {
  my $type = shift->type;

  return $::locale->text('Sales Delivery Order')    if $type eq 'sales_delivery_order';
  return $::locale->text('Purchase Delivery Order') if $type eq 'purchase_delivery_order';

  die 'invalid type';
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

sub _clone_orderitem_cvar {
  my ($cvar) = @_;

  my $cloned = $_->clone_and_reset;
  $cloned->sub_module('delivery_order_items');

  return $cloned;
}

sub new_from {
  my ($class, $source, %params) = @_;

  croak("Unsupported source object type '" . ref($source) . "'") unless ref($source) eq 'SL::DB::Order';

  my ($item_parent_id_column, $item_parent_column);

  if (ref($source) eq 'SL::DB::Order') {
    $item_parent_id_column = 'trans_id';
    $item_parent_column    = 'order';
  }

  my %args = ( map({ ( $_ => $source->$_ ) } qw(cp_id currency_id customer_id cusordnumber delivery_term_id department_id employee_id globalproject_id intnotes language_id notes
                                                ordnumber payment_id reqdate salesman_id shippingpoint shipvia taxincluded taxzone_id transaction_description vendor_id
                                             )),
               closed    => 0,
               is_sales  => !!$source->customer_id,
               delivered => 0,
               transdate => DateTime->today_local,
            );

  # Custom shipto addresses (the ones specific to the sales/purchase
  # record and not to the customer/vendor) are only linked from
  # shipto → delivery_orders. Meaning delivery_orders.shipto_id
  # will not be filled in that case.
  if (!$source->shipto_id && $source->id) {
    $args{custom_shipto} = $source->custom_shipto->clone($class) if $source->can('custom_shipto') && $source->custom_shipto;

  } else {
    $args{shipto_id} = $source->shipto_id;
  }

  my $delivery_order = $class->new(%args);
  $delivery_order->assign_attributes(%{ $params{attributes} }) if $params{attributes};
  my $items          = delete($params{items}) || $source->items_sorted;
  my %item_parents;

  my @items = map {
    my $source_item      = $_;
    my $source_item_id   = $_->$item_parent_id_column;
    my @custom_variables = map { _clone_orderitem_cvar($_) } @{ $source_item->custom_variables };

    $item_parents{$source_item_id} ||= $source_item->$item_parent_column;
    my $item_parent                  = $item_parents{$source_item_id};

    my $current_do_item = SL::DB::DeliveryOrderItem->new(map({ ( $_ => $source_item->$_ ) }
                                         qw(base_qty cusordnumber description discount lastcost longdescription marge_price_factor parts_id price_factor price_factor_id
                                            project_id qty reqdate sellprice serialnumber transdate unit active_discount_source active_price_source
                                         )),
                                   custom_variables => \@custom_variables,
                                   ordnumber        => ref($item_parent) eq 'SL::DB::Order' ? $item_parent->ordnumber : $source_item->ordnumber,
                                 );
    $current_do_item->{"converted_from_orderitems_id"} = $_->{id} if ref($item_parent) eq 'SL::DB::Order';
    $current_do_item;
  } @{ $items };

  @items = grep { $params{item_filter}->($_) } @items if $params{item_filter};
  @items = grep { $_->qty * 1 } @items if $params{skip_items_zero_qty};
  @items = grep { $_->qty >=0 } @items if $params{skip_items_negative_qty};

  $delivery_order->items(\@items);

  return $delivery_order;
}

sub new_from_time_recordings {
  my ($class, $sources, %params) = @_;

  croak("Unsupported object type in sources")                                      if any { ref($_) ne 'SL::DB::TimeRecording' }            @$sources;
  croak("Cannot create delivery order from source records of different customers") if any { $_->customer_id != $sources->[0]->customer_id } @$sources;

  my %args = (
    is_sales    => 1,
    delivered   => 0,
    customer_id => $sources->[0]->customer_id,
    taxzone_id  => $sources->[0]->customer->taxzone_id,
    currency_id => $sources->[0]->customer->currency_id,
    employee_id => SL::DB::Manager::Employee->current->id,
    salesman_id => SL::DB::Manager::Employee->current->id,
    items       => [],
  );
  my $delivery_order = $class->new(%args);
  $delivery_order->assign_attributes(%{ $params{attributes} }) if $params{attributes};

  # - one item per part (article)
  # - qty is sum of duration
  # - description goes to item longdescription
  #  - ordered and summed by date
  #  - each description goes to an ordered list
  #  - (as time recording descriptions are formatted text by now, use stripped text)
  #  - merge same descriptions (todo)
  #

  ### config
  my $default_partnummer = 6;
  my $default_part_id    = SL::DB::Manager::Part->find_by(partnumber => $default_partnummer)->id;

  # check parts and collect entries
  my %part_by_part_id;
  my $entries;
  foreach my $source (@$sources) {
    my $part_id  = $source->part_id ? $source->part_id
                 : $default_part_id ? $default_part_id
                 : undef;

    die 'article not found for entry "' . $source->displayable_times . '"' if !$part_id;

    if (!$part_by_part_id{$part_id}) {
      $part_by_part_id{$part_id} = SL::DB::Part->new(id => $part_id)->load;
      die 'article unit must be time based for entry "' . $source->displayable_times . '"' if !$part_by_part_id{$part_id}->unit_obj->is_time_based;
    }

    my $date = $source->start_time->to_kivitendo;
    $entries->{$part_id}->{$date}->{duration} += $source->{rounding} ?
                                                   nhimult(0.25, ($source->duration_in_hours))
                                                 : _round_total($source->duration_in_hours);
    # add content if not already in description
    my $new_description = $source->description_as_stripped_html;
    $entries->{$part_id}->{$date}->{content}  .= '<li>' . $new_description . '</li>'
      unless $entries->{$part_id}->{$date}->{content} =~ m/\Q$new_description/;

    $entries->{$part_id}->{$date}->{date_obj}  = $source->start_time; # for sorting
  }

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
      unit_obj        => $h_unit,
      sellprice       => $part_by_part_id{$key}->sellprice,
      longdescription => $longdescription,
    );

    $delivery_order->add_items($item);
  }

  return $delivery_order;
}

sub customervendor {
  $_[0]->is_sales ? $_[0]->customer : $_[0]->vendor;
}

sub convert_to_invoice {
  my ($self, %params) = @_;

  croak("Conversion to invoices is only supported for sales records") unless $self->customer_id;

  my $invoice;
  if (!$self->db->with_transaction(sub {
    require SL::DB::Invoice;
    $invoice = SL::DB::Invoice->new_from($self, %params)->post || die;
    $self->link_to_record($invoice);
    # TODO extend link_to_record for items, otherwise long-term no d.r.y.
    foreach my $item (@{ $invoice->items }) {
      foreach (qw(delivery_order_items)) {    # expand if needed (orderitems)
        if ($item->{"converted_from_${_}_id"}) {
          die unless $item->{id};
          RecordLinks->create_links('mode'       => 'ids',
                                    'from_table' => $_,
                                    'from_ids'   => $item->{"converted_from_${_}_id"},
                                    'to_table'   => 'invoice',
                                    'to_id'      => $item->{id},
          ) || die;
          delete $item->{"converted_from_${_}_id"};
        }
      }
    }
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

Creates a new C<SL::DB::DeliveryOrder> instace from the time recordings
given as C<$sources>. All time recording entries must belong to the same
customer. Time recordings are sorted by article and date. For each article
a new delivery order item is created. If no article is associated with an
entry, a default article will be used (hard coded).
Entries of the same date (for each article) are summed together and form a
list entry in the long description of the item.

The created delivery order object will be returnd but not saved.

C<$sources> must be an array reference of C<SL::DB::TimeRecording> instances.

C<%params> can include the following options:

=over 2

=item C<attributes>

An optional hash reference. If it exists then it is used to set
attributes of the newly created delivery order object.

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
