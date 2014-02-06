package SL::DB::DeliveryOrder;

use strict;

use Carp;

use SL::DB::MetaSetup::DeliveryOrder;
use SL::DB::Manager::DeliveryOrder;
use SL::DB::Helper::FlattenToForm;
use SL::DB::Helper::LinkedRecords;
use SL::DB::Helper::TransNumberGenerator;

use List::Util qw(first);

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

__PACKAGE__->before_save('_before_save_set_donumber');

# hooks

sub _before_save_set_donumber {
  my ($self) = @_;

  $self->create_trans_number if !$self->donumber;

  return 1;
}

# methods

sub items { goto &orderitems; }

sub items_sorted {
  my ($self) = @_;

  return [ sort {$a->id <=> $b->id } @{ $self->items } ];
}

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

sub displayable_state {
  my ($self) = @_;

  return join '; ',
    ($self->closed    ? $::locale->text('closed')    : $::locale->text('open')),
    ($self->delivered ? $::locale->text('delivered') : $::locale->text('not delivered'));
}

sub date {
  goto &transdate;
}

sub new_from {
  my ($class, $source, %params) = @_;

  croak("Unsupported source object type '" . ref($source) . "'") unless ref($source) eq 'SL::DB::Order';

  my $terms = $source->can('payment_id') && $source->payment_id ? $source->payment_terms->terms_netto : 0;

  my %args = ( map({ ( $_ => $source->$_ ) } qw(cp_id currency_id customer_id cusordnumber department_id employee_id globalproject_id intnotes language_id notes
                                                ordnumber reqdate salesman_id shippingpoint shipvia taxincluded taxzone_id transaction_description vendor_id
                                             )),
               closed    => 0,
               is_sales  => !!$source->customer_id,
               delivered => 0,
               terms     => $terms,
               transdate => DateTime->today_local,
            );

  # Custom shipto addresses (the ones specific to the sales/purchase
  # record and not to the customer/vendor) are only linked from
  # shipto -> delivery_orders. Meaning delivery_orders.shipto_id
  # will not be filled in that case. Therefore we have to return the
  # new shipto object as a separate object so that the caller can
  # save it, too.
  my $custom_shipto;
  if (!$source->shipto_id && $source->id) {
    my $old = $source->custom_shipto;
    if ($old) {
      $custom_shipto = SL::DB::Shipto->new(
        map  { +($_ => $old->$_) }
        grep { !m{^ (?: itime | mtime | shipto_id | trans_id ) $}x }
        map  { $_->name }
        @{ $old->meta->columns }
      );
      $custom_shipto->module('DO');
    }

  } else {
    $args{shipto_id} = $source->shipto_id;
  }

  my $delivery_order = $class->new(%args, %params);

  my @items = map {
    my $source_item = $_;
    SL::DB::DeliveryOrderItem->new(map({ ( $_ => $source_item->$_ ) }
                                   qw(base_qty cusordnumber description discount lastcost longdescription marge_price_factor ordnumber parts_id price_factor price_factor_id
                                      project_id qty reqdate sellprice serialnumber transdate unit
                                   )));
  } @{ $source->items_sorted };

  $delivery_order->items(\@items);

  return ($delivery_order, $custom_shipto);
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

An alias for L</transdate> for compatibility with other sales/purchase models.

=item C<displayable_state>

Returns a human-readable description of the state regarding being
closed and delivered.

=item C<items>

An alias for L</deliver_orer_items> for compatibility with other
sales/purchase models.

=item C<items_sorted>

Returns the delivery order items sorted by their ID (same order they
appear in the frontend delivery order masks).

=item C<new_from $source>

Creates a new C<SL::DB::DeliveryOrder> instance and copies as much
information from C<$source> as possible. At the moment only instances
of C<SL::DB::Order> (sales quotations, sales orders, requests for
quotations and purchase orders) are supported as sources.

The conversion copies order items into delivery order items. Dates are copied
as appropriate, e.g. the C<transdate> field will be set to the current date.

Returns one or two objects depending on the context. In list context
the new delivery order instance and a shipto instance will be
returned. In scalar instance only the delivery order instance is
returned.

Custom shipto addresses (the ones specific to the sales/purchase
record and not to the customer/vendor) are only linked from C<shipto>
to C<delivery_orders>. Meaning C<delivery_orders.shipto_id> will not
be filled in that case. That's why a separate shipto object is created
and returned.

The objects returned are not saved.

=item C<sales_order>

TODO: Describe sales_order

=item C<type>

Returns a stringdescribing this record's type: either
C<sales_delivery_order> or C<purchase_delivery_order>.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
