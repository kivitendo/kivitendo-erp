package SL::DB::DeliveryOrderItem;

use strict;

use SL::DB::MetaSetup::DeliveryOrderItem;
use SL::DB::Helper::ActsAsList;
use SL::DB::Helper::LinkedRecords;
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

__PACKAGE__->meta->make_manager_class;

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

sub record { goto &delivery_order }

sub displayable_delivery_order_info {
  my ($self, $dec) = @_;

  $dec //= 2;

  $self->delivery_order->presenter->sales_delivery_order(display => 'inline')
         . " " . $::form->format_amount(\%::myconfig, $self->qty, $dec) . " " . $self->unit
         . " (" . $self->delivery_order->transdate->to_kivitendo . ")";
};

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
