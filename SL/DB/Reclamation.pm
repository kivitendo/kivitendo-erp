package SL::DB::Reclamation;

use utf8;
use strict;

use Carp;
use DateTime;
use List::Util qw(max sum0);
use List::MoreUtils qw(any);

use SL::DB::MetaSetup::Reclamation;
use SL::DB::Manager::Reclamation;
use SL::DB::Helper::Attr;
use SL::DB::Helper::AttrHTML;
use SL::DB::Helper::AttrSorted;
use SL::DB::Helper::FlattenToForm;
use SL::DB::Helper::LinkedRecords;
use SL::DB::Helper::PriceTaxCalculator;
use SL::DB::Helper::PriceUpdater;
use SL::DB::Helper::TransNumberGenerator;
use SL::Locale::String qw(t8);
use SL::RecordLinks;
use Rose::DB::Object::Helpers qw(as_tree strip);

__PACKAGE__->meta->add_relationship(

  reclamation_items => {
    type         => 'one to many',
    class        => 'SL::DB::ReclamationItem',
    column_map   => { id => 'reclamation_id' },
    manager_args => {
      with_objects => [ 'part', 'reason' ]
    }
  },
  custom_shipto            => {
    type                   => 'one to one',
    class                  => 'SL::DB::Shipto',
    column_map             => { id => 'trans_id' },
    query_args             => [ module => 'Reclamation' ],
  },
  exchangerate_obj         => {
    type                   => 'one to one',
    class                  => 'SL::DB::Exchangerate',
    column_map             => { currency_id => 'currency_id', transdate => 'transdate' },
  },
);

SL::DB::Helper::Attr::make(__PACKAGE__, daily_exchangerate => 'numeric');

__PACKAGE__->meta->initialize;

__PACKAGE__->attr_html('notes');
__PACKAGE__->attr_sorted('items');

__PACKAGE__->before_save('_before_save_set_record_number');
__PACKAGE__->before_save('_before_save_remove_empty_custom_shipto');
__PACKAGE__->before_save('_before_save_set_custom_shipto_module');
__PACKAGE__->after_save('_after_save_link_records');

# hooks

sub _before_save_set_record_number {
  my ($self) = @_;

  $self->create_trans_number if !$self->record_number;

  return 1;
}

sub _before_save_remove_empty_custom_shipto {
  my ($self) = @_;

  $self->custom_shipto(undef) if $self->custom_shipto && $self->custom_shipto->is_empty;

  return 1;
}

sub _before_save_set_custom_shipto_module {
  my ($self) = @_;

  $self->custom_shipto->module('Reclamation') if $self->custom_shipto;

  return 1;
}

sub _after_save_link_records {
  my ($self) = @_;
  my %allowed_linked_records = map {$_ => 1} qw(
    SL::DB::Reclamation
    SL::DB::Order
    SL::DB::DeliveryOrder
    SL::DB::Invoice
    SL::DB::PurchaseInvoice
  );
  my %allowed_linked_record_items = map {$_ => 1} qw(
    SL::DB::ReclamationItem
    SL::DB::OrderItem
    SL::DB::DeliveryOrderItem
    SL::DB::InvoiceItem
  );

  my $from_record_id = $self->{converted_from_record_id};
  if ($from_record_id) {
    my $from_record_type = $self->{converted_from_record_type_ref};
    unless ($allowed_linked_records{$from_record_type}) {
      croak("Not allowed converted_from_record_type_ref: '" . $from_record_type);
    }
    my $src = ${from_record_type}->new(id => $from_record_id)->load;
    $src->link_to_record($self);
    #clear converted_from;
    delete $self->{$_} for qw(converted_from_record_id converted_from_record_type_ref);

    if (scalar @{ $self->items_sorted || [] }) {
      for my $idx (0 .. $#{ $self->items_sorted }) {
        my $reclamation_item = $self->items_sorted->[$idx];
        my $from_item_id = $reclamation_item->{converted_from_record_item_id};
        next if !$from_item_id;
        my $from_item_type = $reclamation_item->{converted_from_record_item_type_ref};
        unless ($allowed_linked_record_items{$from_item_type}) {
          croak("Not allowed converted_from_record_item_type_ref: '" . $from_item_type);
        }
        my $src_item = ${from_item_type}->new(id => $from_item_id)->load;
        $src_item->link_to_record($reclamation_item);
        #clear converted_from;
        delete $reclamation_item->{$_} for qw(converted_from_record_item_id converted_from_record_item_type_ref);
      }
    }
  }

  return 1;
}

# methods

sub items { goto &reclamation_items; }
sub add_items { goto &add_reclamation_items; }
sub record_items { goto &reclamation_items; }

sub type {
  my ($self) = @_;

  return 'sales_reclamation'    if $self->customer_id;
  return 'purchase_reclamation' if $self->vendor_id;

  return;
}

sub is_type {
  my ($self, $type) = @_;
  return $self->type eq $type;
}

sub effective_tax_point {
  my ($self) = @_;

  return $self->tax_point || $self->reqdate || $self->transdate;
}

sub displayable_type {
  my $type = shift->type;

  return $::locale->text('Sales Reclamation')    if $type eq 'sales_reclamation';
  return $::locale->text('Purchase Reclamation') if $type eq 'purchase_reclamation';

  die 'invalid type';
}

sub displayable_name {
  join ' ', grep $_, map $_[0]->$_, qw(displayable_type record_number);
};

sub is_sales {
  croak 'not an accessor' if @_ > 1;
  return !!shift->customer_id;
}

sub daily_exchangerate {
  my ($self, $val) = @_;

  return 1 if $self->currency_id == $::instance_conf->get_currency_id;

  my $rate = (any { $self->is_type($_) } qw(sales_reclamation))    ? 'buy'
           : (any { $self->is_type($_) } qw(purchase_reclamation)) ? 'sell'
           : undef;
  return if !$rate;

  if (defined $val) {
    croak t8('exchange rate has to be positive') if $val <= 0;
    if (!$self->exchangerate_obj) {
      $self->exchangerate_obj(SL::DB::Exchangerate->new(
        currency_id => $self->currency_id,
        transdate   => $self->transdate,
        $rate       => $val,
      ));
    } elsif (!defined $self->exchangerate_obj->$rate) {
      $self->exchangerate_obj->$rate($val);
    } else {
      croak t8('exchange rate already exists, no update allowed');
    }
  }
  return $self->exchangerate_obj->$rate if $self->exchangerate_obj;
}

sub taxes {
  my ($self) = @_;
  # add taxes to recalmation
  my %pat = $self->calculate_prices_and_taxes();
  my @taxes;
  foreach my $tax_id (keys %{ $pat{taxes_by_tax_id} }) {
    my $netamount = sum0 map { $pat{amounts}->{$_}->{amount} } grep { $pat{amounts}->{$_}->{tax_id} == $tax_id } keys %{ $pat{amounts} };
    push(@taxes, { amount    => $pat{taxes_by_tax_id}->{$tax_id},
                                netamount => $netamount,
                                tax       => SL::DB::Tax->new(id => $tax_id)->load });
  }
  return \@taxes;
}

sub displayable_state {
  my ($self) = @_;

  return $self->closed ? $::locale->text('closed') : $::locale->text('open');
}

sub valid_reclamation_reasons {
  my ($self) = @_;

  my $valid_for_type = ($self->type =~ m{sales} ? 'valid_for_sales' : 'valid_for_purchase');
  return SL::DB::Manager::ReclamationReason->get_all_sorted(
      where => [  $valid_for_type => 1 ]);
}

sub convert_to_order {
  my ($self, %params) = @_;

  my $order;
  $params{destination_type} = $self->is_sales ? 'sales_order'
                                              : 'purchase_order';
  if (!$self->db->with_transaction(sub {
    require SL::DB::Order;
    $order = SL::DB::Order->new_from($self, %params);
    $order->save;
    $self->link_to_record($order);
    foreach my $item (@{ $order->items }) {
      foreach (qw(reclamation_item)) {
        if ($item->{"converted_from_${_}_id"}) {
          die unless $item->{id};
          RecordLinks->create_links('dbh'        => $self->db->dbh,
                                    'mode'       => 'ids',
                                    'from_table' => 'reclamation_items',
                                    'from_ids'   => $item->{"converted_from_${_}_id"},
                                    'to_table'   => 'orderitems',
                                    'to_id'      => $item->{id},
          ) || die;
          delete $item->{"converted_from_${_}_id"};
        }
      }
    }

    1;
  })) {
    return undef, $self->db->error->db_error->db_error;
  }

  return $order;
}

sub convert_to_delivery_order {
  my ($self, %params) = @_;

  my $delivery_order;
  if (!$self->db->with_transaction(sub {
    require SL::DB::DeliveryOrder;
    $delivery_order = SL::DB::DeliveryOrder->new_from($self, %params);
    $delivery_order->save;
    $self->link_to_record($delivery_order);
    # TODO extend link_to_record for items, otherwise long-term no d.r.y.
    foreach my $item (@{ $delivery_order->items }) {
      foreach (qw(reclamation_items)) {
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

    $self->update_attributes(delivered => 1) unless $::instance_conf->get_shipped_qty_require_stock_out;
    1;
  })) {
    return undef, $self->db->error->db_error->db_error;
  }

  return $delivery_order;
}

#TODO(Werner): überprüfen ob alle Felder richtig gestetzt werden
sub new_from {
  my ($class, $source, %params) = @_;
  my %allowed_sources = map { $_ => 1 } qw(
    SL::DB::Reclamation
    SL::DB::Order
    SL::DB::DeliveryOrder
    SL::DB::Invoice
    SL::DB::PurchaseInvoice
  );
  unless( $allowed_sources{ref $source} ) {
    croak("Unsupported source object type '" . ref($source) . "'");
  }
  croak("A destination type must be given as parameter") unless $params{destination_type};

  my $destination_type  = delete $params{destination_type};

  my @from_tos = (
    #Reclamation
    { from => 'sales_reclamation',       to => 'sales_reclamation',    abbr => 'srsr', },
    { from => 'purchase_reclamation',    to => 'purchase_reclamation', abbr => 'prpr', },
    { from => 'sales_reclamation',       to => 'purchase_reclamation', abbr => 'srpr', },
    { from => 'purchase_reclamation',    to => 'sales_reclamation',    abbr => 'prsr', },
    #Order
    { from => 'sales_order',             to => 'sales_reclamation',    abbr => 'sosr', },
    { from => 'purchase_order',          to => 'purchase_reclamation', abbr => 'popr', },
    #Delivery Order
    { from => 'sales_delivery_order',    to => 'sales_reclamation',    abbr => 'sdsr', },
    { from => 'purchase_delivery_order', to => 'purchase_reclamation', abbr => 'pdpr', },
    #Invoice
    { from => 'invoice',                 to => 'sales_reclamation',    abbr => 'sisr', },
    { from => 'purchase_invoice',        to => 'purchase_reclamation', abbr => 'pipr', },
  );
  my $from_to = (grep { $_->{from} eq $source->type && $_->{to} eq $destination_type} @from_tos)[0];
  if (!$from_to) {
    croak("Cannot convert from '" . $source->type . "' to '" . $destination_type . "'");
  }

  my $is_abbr_any = sub {
    any { $from_to->{abbr} eq $_ } @_;
  };

  my %record_args = (
    record_number => undef,
    employee => SL::DB::Manager::Employee->current,
    closed    => 0,
    delivered => 0,
    transdate => DateTime->today_local,
    reqdate => DateTime->today_local->next_workday(),
  );
  if ( $is_abbr_any->(qw(srsr prpr srpr prsr)) ) { #Reclamation
    map { $record_args{$_} = $source->$_ } # {{{ for vim folds
    qw(
      amount
      contact_id
      currency_id
      customer_id
      cv_record_number
      delivery_term_id
      department_id
      exchangerate
      globalproject_id
      intnotes
      language_id
      netamount
      notes
      payment_id
      salesman_id
      shippingpoint
      shipvia
      tax_point
      taxincluded
      taxzone_id
      transaction_description
      vendor_id
    ); # }}} for vim folds
  } elsif ( $is_abbr_any->(qw(sosr popr)) ) { #Order
    map { $record_args{$_} = $source->$_ } # {{{ for vim folds
    qw(
      amount
      currency_id
      customer_id
      delivery_term_id
      department_id
      exchangerate
      globalproject_id
      intnotes
      language_id
      netamount
      notes
      payment_id
      salesman_id
      shippingpoint
      shipvia
      tax_point
      taxincluded
      taxzone_id
      transaction_description
      vendor_id
    );
    $record_args{contact_id} = $source->cp_id;
    $record_args{cv_record_number} = $source->cusordnumber;
    # }}} for vim folds
  } elsif ( $is_abbr_any->(qw(sdsr pdpr)) ) { #DeliveryOrder
    map { $record_args{$_} = $source->$_ } # {{{ for vim folds
    qw(
      currency_id
      customer_id
      delivery_term_id
      department_id
      globalproject_id
      intnotes
      language_id
      notes
      payment_id
      salesman_id
      shippingpoint
      shipvia
      tax_point
      taxincluded
      taxzone_id
      transaction_description
      vendor_id
    );
    $record_args{contact_id} = $source->cp_id;
    $record_args{cv_record_number} = $source->cusordnumber;
    # }}} for vim folds
  } elsif ( $is_abbr_any->(qw(sisr)) ) { #Invoice(ar)
    map { $record_args{$_} = $source->$_ } # {{{ for vim folds
    qw(
      amount
      currency_id
      customer_id
      delivery_term_id
      department_id
      globalproject_id
      intnotes
      language_id
      netamount
      notes
      payment_id
      salesman_id
      shippingpoint
      shipvia
      tax_point
      taxincluded
      taxzone_id
      transaction_description
    );
    $record_args{contact_id} = $source->cp_id;
    $record_args{cv_record_number} = $source->cusordnumber;
    # }}} for vim folds
  } elsif ( $is_abbr_any->(qw(pipr)) ) { #Invoice(ap)
    map { $record_args{$_} = $source->$_ } # {{{ for vim folds
    qw(
      amount
      currency_id
      delivery_term_id
      department_id
      globalproject_id
      intnotes
      language_id
      netamount
      notes
      payment_id
      shipvia
      tax_point
      taxincluded
      taxzone_id
      transaction_description
      vendor_id
    );
    $record_args{contact_id} = $source->cp_id;
    # }}} for vim folds
  }

  if ( ($from_to->{from} =~ m{sales}) && ($from_to->{to} =~ m{purchase}) ) {
    $record_args{customer_id}      = undef;
    $record_args{salesman_id}      = undef;
    $record_args{payment_id}       = undef;
    $record_args{delivery_term_id} = undef;
  }
  if ( ($from_to->{from} =~ m{purchase}) && ($from_to->{to} =~ m{sales}) ) {
    $record_args{vendor_id} = undef;
    $record_args{salesman_id} = undef;
    $record_args{payment_id} = undef;
    $record_args{delivery_term_id} = undef;
  }


  if ($source->can('shipto_id')) {
    # Custom shipto addresses (the ones specific to the sales/purchase record and
    # not to the customer/vendor) are only linked from shipto → record.
    # Meaning record.shipto_id will not be filled in that case.
    if (!$source->shipto_id && $source->id) {
      $record_args{custom_shipto} = $source->custom_shipto->clone($class) if $source->can('custom_shipto') && $source->custom_shipto;
    } elsif ($source->shipto_id) {
      $record_args{shipto_id} = $source->shipto_id;
    }
  }

  my $reclamation = $class->new(%record_args);
  $reclamation->assign_attributes(%{ $params{attributes} }) if $params{attributes};

  unless ($params{no_linked_records}) {
    $reclamation->{"converted_from_record_type_ref"} = ref($source);
    $reclamation->{"converted_from_record_id"} = $source->id;
  };

  my $items = delete($params{items}) || $source->items;

  my @items = map { SL::DB::ReclamationItem->new_from($_, $from_to->{to}, no_linked_records => $params{no_linked_records}); } @{ $items };

  @items = grep { $params{item_filter}->($_) } @items if $params{item_filter};
  @items = grep { $_->qty * 1 } @items if $params{skip_items_zero_qty};
  @items = grep { $_->qty >=0 } @items if $params{skip_items_negative_qty};

  $reclamation->items(\@items);
  return $reclamation;
}

sub customervendor {
  my ($reclamation) = @_;
  return $reclamation->is_sales ? $reclamation->customer : $reclamation->vendor;
}

sub date {
  goto &transdate;
}

sub digest {
  my ($self) = @_;

  sprintf "%s %s %s (%s)",
    $self->record_number,
    $self->customervendor->name,
    $self->amount_as_number,
    $self->date->to_kivitendo;
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Reclamation - reclamation Datenbank Objekt.

=head1 FUNCTIONS

=head2 C<type>

Returns one of the following string types:

=over 4

=item sales_reclamation

=item purchase_reclamation

=item sales_quotation

=item request_quotation

=back

=head2 C<is_type TYPE>

Returns true if the reclamation is of the given type.

=head2 C<daily_exchangerate $val>

Gets or sets the exchangerate object's value. This is the value from the
table C<exchangerate> depending on the reclamation's currency, the transdate and
if it is a sales or purchase reclamation.

The reclamation object (respectively the table C<oe>) has an own column
C<exchangerate> which can be get or set with the accessor C<exchangerate>.

The idea is to drop the legacy table C<exchangerate> in the future and to
give all relevant tables it's own C<exchangerate> column.

So, this method is here if you need to access the "legacy" exchangerate via
an reclamation object.

=over 4

=item C<$val>

(optional) If given, the exchangerate in the "legacy" table is set to this
value, depending on currency, transdate and sales or purchase.

=back

=head2 C<convert_to_delivery_order %params>

Creates a new delivery reclamation with C<$self> as the basis by calling
L<SL::DB::DeliveryReclamation::new_from>. That delivery reclamation is saved, and
C<$self> is linked to the new invoice via
L<SL::DB::RecordLink>. C<$self>'s C<delivered> attribute is set to
C<true>, and C<$self> is saved.

The arguments in C<%params> are passed to
L<SL::DB::DeliveryReclamation::new_from>.

Returns C<undef> on failure. Otherwise the new delivery reclamation will be
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

At the moment only sales quotations and sales reclamations can be converted.

=head2 C<new_from $source, %params>

Creates a new C<SL::DB::Reclamation> instance and copies as much
information from C<$source> as possible. At the moment only records with the
same destination type as the source type and sales reclamations from
sales quotations and purchase reclamations from requests for quotations can be
created.

The C<transdate> field will be set to the current date.

The conversion copies the reclamation items as well.

Returns the new reclamation instance. The object returned is not
saved.

C<%params> can include the following options
(C<destination_type> is mandatory):

=over 4

=item C<destination_type>

(mandatory)
The type of the newly created object. Can be C<sales_quotation>,
C<sales_reclamation>, C<purchase_quotation> or C<purchase_reclamation> for now.

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
reclamation.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Sven Schöling <s.schoeling@linet-services.de>

=cut
