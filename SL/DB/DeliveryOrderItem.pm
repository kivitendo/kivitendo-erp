package SL::DB::DeliveryOrderItem;

use strict;

use Carp;

use Rose::DB::Object::Helpers qw(as_tree strip);

use SL::DB::MetaSetup::DeliveryOrderItem;
use SL::DB::Manager::DeliveryOrderItem;
use SL::DB::Helper::ActsAsList;
use SL::DB::Helper::LinkedRecords;
use SL::DB::Helper::RecordLink qw(RECORD_ITEM_ID RECORD_ITEM_TYPE_REF);
use SL::DB::Helper::RecordItem;
use SL::DB::Helper::CustomVariables (
  sub_module  => 'delivery_order_items',
  cvars_alias => 1,
  overloads   => {
    parts_id => {
      class => 'SL::DB::Part',
      module => 'IC',
    }
  },
);

__PACKAGE__->meta->add_relationship(
  delivery_order_stock_entries => {
    type         => 'one to many',
    class        => 'SL::DB::DeliveryOrderItemsStock',
    column_map   => { id => 'delivery_order_item_id' },
    manager_args => {
      with_objects => [ 'inventory' ]
    },
  },
);

__PACKAGE__->meta->initialize;

__PACKAGE__->configure_acts_as_list(group_by => [qw(delivery_order_id)]);

# methods

sub new_from {
  my ($class, $source, %params) = @_;

  my %allowed_sources = map { $_ => 1 } qw(
      SL::DB::ReclamationItem
      SL::DB::OrderItem
      SL::DB::DeliveryOrderItem
  );
  unless( $allowed_sources{ref $source} ) {
    croak("Unsupported source object type '" . ref($source) . "'");
  }

  my @custom_variables = map { _clone_cvar_for_delivery_order_item($_) } @{ $source->custom_variables };

  my %item_args;
  if (ref($source) eq 'SL::DB::ReclamationItem') {
    map { $item_args{$_} = $source->$_ } # {{{ for vim folds
    qw(
      active_discount_source
      active_price_source
      base_qty
      description
      discount
      lastcost
      longdescription
      parts_id
      position
      price_factor
      price_factor_id
      pricegroup_id
      project_id
      qty
      reqdate
      sellprice
      serialnumber
      unit
    );
    $item_args{custom_variables} = \@custom_variables;
    # }}} for vim folds
  } elsif (ref($source) eq 'SL::DB::OrderItem') {
    map { $item_args{$_} = $source->$_ } # {{{ for vim folds
    qw(
      active_discount_source
      active_price_source
      base_qty
      cusordnumber
      description
      discount
      lastcost
      longdescription
      marge_price_factor
      parts_id
      position
      price_factor
      price_factor_id
      project_id
      qty
      reqdate
      sellprice
      serialnumber
      transdate
      unit
    );
    $item_args{custom_variables} = \@custom_variables;
    $item_args{ordnumber}        = ref($source->record) eq 'SL::DB::Order' ? $source->record->ordnumber : $source->ordnumber;
    # }}} for vim folds
  } elsif (ref($source) eq 'SL::DB::DeliveryOrderItem') {
    map { $item_args{$_} = $source->$_ } # {{{ for vim folds
    qw(
      active_discount_source
      active_price_source
      base_qty
      cusordnumber
      description
      discount
      lastcost
      longdescription
      marge_price_factor
      parts_id
      position
      price_factor
      price_factor_id
      project_id
      qty
      reqdate
      sellprice
      serialnumber
      transdate
      unit
    );
    $item_args{custom_variables} = \@custom_variables;
    # }}} for vim folds
  }

  my $item = $class->new(%item_args);

  unless ($params{no_linked_records}) {
    $item->{ RECORD_ITEM_ID() } = $source->id;
    $item->{ RECORD_ITEM_TYPE_REF() } = ref $source;
  }

  return $item;
}

sub _clone_cvar_for_delivery_order_item {
  my ($cvar) = @_;

  my $cloned = $_->clone_and_reset;
  $cloned->sub_module('delivery_order_items');

  return $cloned;
}

sub record { goto &delivery_order }
sub record_id { goto &delivery_order_id }

sub displayable_delivery_order_info {
  my ($self, $dec) = @_;

  $dec //= 2;

  $self->delivery_order->presenter->sales_delivery_order(display => 'inline')
         . " " . $::form->format_amount(\%::myconfig, $self->qty, $dec) . " " . $self->unit
         . " (" . $self->delivery_order->transdate->to_kivitendo . ")";
};

sub effective_project {
  my ($self) = @_;

  $self->project // $self->delivery_order->globalproject;
}

__END__

=pod

=encoding utf-8

=head1 NAME

SL::DB::DeliveryOrderItem Model for the 'delivery_order_items' table

=head1 SYNOPSIS

This is a standard Rose::DB::Object based model and can be used as one.

=head1 METHODS

=over 4

=item C<displayable_delivery_order_info DEC>

Returns a string with information about the delivery order item in relation to
its delivery order, specifically

* the (HTML-linked) delivery order number

* the qty and unit of the part in the delivery order

* the date of the delivery order

Doesn't include any part information, it is assumed that is already shown elsewhere.

The method takes an optional argument "dec" which determines how many decimals to
round to, as used by format_amount.

  SL::DB::Manager::DeliveryOrderItem->get_first->displayable_delivery_order_info(0);
  # 201601234 5 Stck (12.12.2016)

=back

=head1 AUTHORS

G. Richardson E<lt>grichardson@kivitendo-premium.deE<gt>

=cut

1;
