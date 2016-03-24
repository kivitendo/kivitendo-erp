package SL::DB::Order;

use utf8;
use strict;

use Carp;
use DateTime;
use List::Util qw(max);

use SL::DB::MetaSetup::Order;
use SL::DB::Manager::Order;
use SL::DB::Helper::AttrHTML;
use SL::DB::Helper::AttrSorted;
use SL::DB::Helper::FlattenToForm;
use SL::DB::Helper::LinkedRecords;
use SL::DB::Helper::PriceTaxCalculator;
use SL::DB::Helper::PriceUpdater;
use SL::DB::Helper::TransNumberGenerator;
use SL::RecordLinks;
use Rose::DB::Object::Helpers qw(as_tree);

__PACKAGE__->meta->add_relationship(
  orderitems => {
    type         => 'one to many',
    class        => 'SL::DB::OrderItem',
    column_map   => { id => 'trans_id' },
    manager_args => {
      with_objects => [ 'part' ]
    }
  },
  periodic_invoices_config => {
    type                   => 'one to one',
    class                  => 'SL::DB::PeriodicInvoicesConfig',
    column_map             => { id => 'oe_id' },
  },
  custom_shipto            => {
    type                   => 'one to one',
    class                  => 'SL::DB::Shipto',
    column_map             => { id => 'trans_id' },
    query_args             => [ module => 'OE' ],
  },
);

__PACKAGE__->meta->initialize;

__PACKAGE__->attr_html('notes');
__PACKAGE__->attr_sorted('items');

__PACKAGE__->before_save('_before_save_set_ord_quo_number');

# hooks

sub _before_save_set_ord_quo_number {
  my ($self) = @_;

  # ordnumber is 'NOT NULL'. Therefore make sure it's always set to at
  # least an empty string, even if we're saving a quotation.
  $self->ordnumber('') if !$self->ordnumber;

  my $field = $self->quotation ? 'quonumber' : 'ordnumber';
  $self->create_trans_number if !$self->$field;

  return 1;
}

# methods

sub items { goto &orderitems; }
sub add_items { goto &add_orderitems; }
sub record_number { goto &number; }

sub type {
  my $self = shift;

  return 'sales_order'       if $self->customer_id && ! $self->quotation;
  return 'purchase_order'    if $self->vendor_id   && ! $self->quotation;
  return 'sales_quotation'   if $self->customer_id &&   $self->quotation;
  return 'request_quotation' if $self->vendor_id   &&   $self->quotation;

  return;
}

sub is_type {
  return shift->type eq shift;
}

sub displayable_type {
  my $type = shift->type;

  return $::locale->text('Sales quotation')   if $type eq 'sales_quotation';
  return $::locale->text('Request quotation') if $type eq 'request_quotation';
  return $::locale->text('Sales Order')       if $type eq 'sales_order';
  return $::locale->text('Purchase Order')    if $type eq 'purchase_order';

  die 'invalid type';
}

sub displayable_name {
  join ' ', grep $_, map $_[0]->$_, qw(displayable_type record_number);
};

sub is_sales {
  croak 'not an accessor' if @_ > 1;
  return !!shift->customer_id;
}

sub invoices {
  my $self   = shift;
  my %params = @_;

  if ($self->quotation) {
    return [];
  } else {
    require SL::DB::Invoice;
    return SL::DB::Manager::Invoice->get_all(
      query => [
        ordnumber => $self->ordnumber,
        @{ $params{query} || [] },
      ]
    );
  }
}

sub displayable_state {
  my ($self) = @_;

  return $self->closed ? $::locale->text('closed') : $::locale->text('open');
}

sub abschlag_invoices {
  return shift()->invoices(query => [ abschlag => 1 ]);
}

sub end_invoice {
  return shift()->invoices(query => [ abschlag => 0 ]);
}

sub convert_to_invoice {
  my ($self, %params) = @_;

  croak("Conversion to invoices is only supported for sales records") unless $self->customer_id;

  my $invoice;
  if (!$self->db->with_transaction(sub {
    require SL::DB::Invoice;
    $invoice = SL::DB::Invoice->new_from($self)->post(%params) || die;
    $self->link_to_record($invoice);
    $self->update_attributes(closed => 1);
    1;
  })) {
    return undef;
  }

  return $invoice;
}

sub convert_to_delivery_order {
  my ($self, @args) = @_;

  my ($delivery_order, $custom_shipto);
  if (!$self->db->with_transaction(sub {
    require SL::DB::DeliveryOrder;
    ($delivery_order, $custom_shipto) = SL::DB::DeliveryOrder->new_from($self, @args);
    $delivery_order->save;
    $custom_shipto->save if $custom_shipto;
    $self->link_to_record($delivery_order);
    # TODO extend link_to_record for items, otherwise long-term no d.r.y.
    foreach my $item (@{ $delivery_order->items }) {
      foreach (qw(orderitems)) {    # expand if needed (delivery_order_items)
        if ($item->{"converted_from_${_}_id"}) {
          die unless $item->{id};
          RecordLinks->create_links('mode'       => 'ids',
                                    'from_table' => $_,
                                    'from_ids'   => $item->{"converted_from_${_}_id"},
                                    'to_table'   => 'delivery_order_items',
                                    'to_id'      => $item->{id},
          ) || die;
          delete $item->{"converted_from_${_}_id"};
        }
      }
    }

    $self->update_attributes(delivered => 1);
    1;
  })) {
    return wantarray ? () : undef;
  }

  return wantarray ? ($delivery_order, $custom_shipto) : $delivery_order;
}

sub number {
  my $self = shift;

  my %number_method = (
    sales_order       => 'ordnumber',
    sales_quotation   => 'quonumber',
    purchase_order    => 'ordnumber',
    request_quotation => 'quonumber',
  );

  return $self->${ \ $number_method{$self->type} }(@_);
}

sub customervendor {
  $_[0]->is_sales ? $_[0]->customer : $_[0]->vendor;
}

sub date {
  goto &transdate;
}

sub digest {
  my ($self) = @_;

  sprintf "%s %s %s (%s)",
    $self->number,
    $self->customervendor->name,
    $self->amount_as_number,
    $self->date->to_kivitendo;
}

1;

__END__

=head1 NAME

SL::DB::Order - Order Datenbank Objekt.

=head1 FUNCTIONS

=head2 C<type>

Returns one of the following string types:

=over 4

=item sales_order

=item purchase_order

=item sales_quotation

=item request_quotation

=back

=head2 C<is_type TYPE>

Returns true if the order is of the given type.

=head2 C<convert_to_delivery_order %params>

Creates a new delivery order with C<$self> as the basis by calling
L<SL::DB::DeliveryOrder::new_from>. That delivery order is saved, and
C<$self> is linked to the new invoice via
L<SL::DB::RecordLink>. C<$self>'s C<delivered> attribute is set to
C<true>, and C<$self> is saved.

The arguments in C<%params> are passed to
L<SL::DB::DeliveryOrder::new_from>.

Returns C<undef> on failure. Otherwise the return value depends on the
context. In list context the new delivery order and a shipto instance
will be returned. In scalar instance only the delivery order instance
is returned.

Custom shipto addresses (the ones specific to the sales/purchase
record and not to the customer/vendor) are only linked from C<shipto>
to C<delivery_orders>. Meaning C<delivery_orders.shipto_id> will not
be filled in that case. That's why a separate shipto object is created
and returned.

=head2 C<convert_to_invoice %params>

Creates a new invoice with C<$self> as the basis by calling
L<SL::DB::Invoice::new_from>. That invoice is posted, and C<$self> is
linked to the new invoice via L<SL::DB::RecordLink>. C<$self>'s
C<closed> attribute is set to C<true>, and C<$self> is saved.

The arguments in C<%params> are passed to L<SL::DB::Invoice::post>.

Returns the new invoice instance on success and C<undef> on
failure. The whole process is run inside a transaction. On failure
nothing is created or changed in the database.

At the moment only sales quotations and sales orders can be converted.

=head2 C<create_sales_process>

Creates and saves a new sales process. Can only be called for sales
orders.

The newly created process will be linked bidirectionally to both
C<$self> and to all sales quotations that are linked to C<$self>.

Returns the newly created process instance.

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Sven Schöling <s.schoeling@linet-services.de>

=cut
