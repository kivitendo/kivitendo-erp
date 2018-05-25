package SL::DB::Order;

use utf8;
use strict;

use Carp;
use DateTime;
use List::Util qw(max);
use List::MoreUtils qw(any);

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

  my $delivery_order;
  if (!$self->db->with_transaction(sub {
    require SL::DB::DeliveryOrder;
    $delivery_order = SL::DB::DeliveryOrder->new_from($self, @args);
    $delivery_order->save;
    $self->link_to_record($delivery_order);
    # TODO extend link_to_record for items, otherwise long-term no d.r.y.
    foreach my $item (@{ $delivery_order->items }) {
      foreach (qw(orderitems)) {    # expand if needed (delivery_order_items)
        if ($item->{"converted_from_${_}_id"}) {
          die unless $item->{id};
          RecordLinks->create_links('dbh'        => $self->db->dbh,
                                    'mode'       => 'ids',
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
    return undef;
  }

  return $delivery_order;
}

sub _clone_orderitem_cvar {
  my ($cvar) = @_;

  my $cloned = $_->clone_and_reset;
  $cloned->sub_module('orderitems');

  return $cloned;
}

sub new_from {
  my ($class, $source, %params) = @_;

  croak("Unsupported source object type '" . ref($source) . "'") unless ref($source) eq 'SL::DB::Order';
  croak("A destination type must be given as parameter")         unless $params{destination_type};

  my $destination_type  = delete $params{destination_type};

  my @from_tos = (
    { from => 'sales_quotation',   to => 'sales_order',       abbr => 'sqso' },
    { from => 'request_quotation', to => 'purchase_order',    abbr => 'rqpo' },
    { from => 'sales_quotation',   to => 'sales_quotation',   abbr => 'sqsq' },
    { from => 'sales_order',       to => 'sales_order',       abbr => 'soso' },
    { from => 'request_quotation', to => 'request_quotation', abbr => 'rqrq' },
    { from => 'purchase_order',    to => 'purchase_order',    abbr => 'popo' },
    { from => 'sales_order',       to => 'purchase_order',    abbr => 'sopo' },
    { from => 'purchase_order',    to => 'sales_order',       abbr => 'poso' },
  );
  my $from_to = (grep { $_->{from} eq $source->type && $_->{to} eq $destination_type} @from_tos)[0];
  croak("Cannot convert from '" . $source->type . "' to '" . $destination_type . "'") if !$from_to;

  my $is_abbr_any = sub {
    # foreach my $abbr (@_) {
    #   croak "no such abbreviation: '$abbr'" if !grep { $_->{abbr} eq $abbr } @from_tos;
    # }
    any { $from_to->{abbr} eq $_ } @_;
  };

  my ($item_parent_id_column, $item_parent_column);

  if (ref($source) eq 'SL::DB::Order') {
    $item_parent_id_column = 'trans_id';
    $item_parent_column    = 'order';
  }

  my %args = ( map({ ( $_ => $source->$_ ) } qw(amount cp_id currency_id cusordnumber customer_id delivery_customer_id delivery_term_id delivery_vendor_id
                                                department_id employee_id globalproject_id intnotes marge_percent marge_total language_id netamount notes
                                                ordnumber payment_id quonumber reqdate salesman_id shippingpoint shipvia taxincluded taxzone_id
                                                transaction_description vendor_id
                                             )),
               quotation => !!($destination_type =~ m{quotation$}),
               closed    => 0,
               delivered => 0,
               transdate => DateTime->today_local,
            );

  if ( $is_abbr_any->(qw(sopo poso)) ) {
    $args{ordnumber} = undef;
    $args{reqdate}   = DateTime->today_local->next_workday();
    $args{employee}  = SL::DB::Manager::Employee->current;
  }
  if ( $is_abbr_any->(qw(sopo)) ) {
    $args{customer_id}      = undef;
    $args{salesman_id}      = undef;
    $args{payment_id}       = undef;
    $args{delivery_term_id} = undef;
  }
  if ( $is_abbr_any->(qw(poso)) ) {
    $args{vendor_id} = undef;
  }

  # Custom shipto addresses (the ones specific to the sales/purchase
  # record and not to the customer/vendor) are only linked from
  # shipto → order. Meaning order.shipto_id
  # will not be filled in that case.
  if (!$source->shipto_id && $source->id) {
    $args{custom_shipto} = $source->custom_shipto->clone($class) if $source->can('custom_shipto') && $source->custom_shipto;

  } else {
    $args{shipto_id} = $source->shipto_id;
  }

  my $order = $class->new(%args);
  $order->assign_attributes(%{ $params{attributes} }) if $params{attributes};
  my $items = delete($params{items}) || $source->items_sorted;
  my %item_parents;

  my @items = map {
    my $source_item      = $_;
    my $source_item_id   = $_->$item_parent_id_column;
    my @custom_variables = map { _clone_orderitem_cvar($_) } @{ $source_item->custom_variables };

    $item_parents{$source_item_id} ||= $source_item->$item_parent_column;
    my $item_parent                  = $item_parents{$source_item_id};

    my $current_oe_item = SL::DB::OrderItem->new(map({ ( $_ => $source_item->$_ ) }
                                                     qw(active_discount_source active_price_source base_qty cusordnumber
                                                        description discount lastcost longdescription
                                                        marge_percent marge_price_factor marge_total
                                                        ordnumber parts_id price_factor price_factor_id pricegroup_id
                                                        project_id qty reqdate sellprice serialnumber ship subtotal transdate unit
                                                     )),
                                                 custom_variables => \@custom_variables,
    );
    if ( $is_abbr_any->(qw(sopo)) ) {
      $current_oe_item->sellprice($source_item->lastcost);
      $current_oe_item->discount(0);
    }
    if ( $is_abbr_any->(qw(poso)) ) {
      $current_oe_item->lastcost($source_item->sellprice);
    }
    $current_oe_item->{"converted_from_orderitems_id"} = $_->{id} if ref($item_parent) eq 'SL::DB::Order';
    $current_oe_item;
  } @{ $items };

  @items = grep { $params{item_filter}->($_) } @items if $params{item_filter};
  @items = grep { $_->qty * 1 } @items if $params{skip_items_zero_qty};
  @items = grep { $_->qty >=0 } @items if $params{skip_items_negative_qty};

  $order->items(\@items);

  return $order;
}

sub number {
  my $self = shift;

  return if !$self->type;

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

=pod

=encoding utf8

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

Returns C<undef> on failure. Otherwise the new delivery order will be
returned.

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

=head2 C<new_from $source, %params>

Creates a new C<SL::DB::Order> instance and copies as much
information from C<$source> as possible. At the moment only records with the
same destination type as the source type and sales orders from
sales quotations and purchase orders from requests for quotations can be
created.

The C<transdate> field will be set to the current date.

The conversion copies the order items as well.

Returns the new order instance. The object returned is not
saved.

C<%params> can include the following options
(C<destination_type> is mandatory):

=over 4

=item C<destination_type>

(mandatory)
The type of the newly created object. Can be C<sales_quotation>,
C<sales_order>, C<purchase_quotation> or C<purchase_order> for now.

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
