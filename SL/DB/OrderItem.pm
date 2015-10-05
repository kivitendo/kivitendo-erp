package SL::DB::OrderItem;

use strict;

use List::Util qw(sum);

use SL::DB::MetaSetup::OrderItem;
use SL::DB::Manager::OrderItem;
use SL::DB::DeliveryOrderItemsStock;
use SL::DB::Helper::ActsAsList;
use SL::DB::Helper::LinkedRecords;
use SL::DB::Helper::RecordItem;
use SL::DB::Helper::CustomVariables (
  sub_module  => 'orderitems',
  cvars_alias => 1,
  overloads   => {
    parts_id => {
      class => 'SL::DB::Part',
      module => 'IC',
    }
  },
);

__PACKAGE__->meta->initialize;

__PACKAGE__->configure_acts_as_list(group_by => [qw(trans_id)]);

sub is_price_update_available {
  my $self = shift;
  return $self->origprice > $self->part->sellprice;
}

sub shipped_qty {
  my ($self) = @_;

  my $d_orders = $self->order->linked_records(direction => 'to', to => 'SL::DB::DeliveryOrder');
  my @doi      = grep { $_->parts_id == $self->parts_id } map { $_->orderitems } @$d_orders;

  require SL::AM;
  return sum(map { AM->convert_unit($_->unit => $self->unit) * $_->qty } @doi);
}

sub record { goto &order }

1;

__END__

=pod

=head1 NAME

SL::DB::OrderItems: Rose model for orderitems

=head1 FUNCTIONS

=over 4

=item C<shipped_qty>

returns the number of orderitems which are already linked to Delivery Orders.
The linked key is parts_id and not orderitems (id) -> delivery_order_items (id).
Therefore this function is not safe for identical parts_id.
Sample call:
C<$::form-E<gt>format_amount(\%::myconfig, $_[0]-E<gt>shipped_qty);>

=back

=head1 TODO

Older versions of OrderItem.pm had more functions which where used for calculating the
qty for the different states of the Delivery Order.
For example to get the qty in already marked as delivered Delivery Orders:

C<delivered_qty>

return $self-E<gt>_delivered_qty;

  sub _delivered_qty {
  (..)
    my @d_orders_delivered = grep { $_-E<gt>delivered } @$d_orders;
    my @doi_delivered      = grep { $_-E<gt>parts_id == $self-E<gt>parts_id } map { $_-E<gt>orderitems } @d_orders_delivered;
  }

In general the function C<shipped_qty> and all (project) related functions should be marked deprecate,
 because of the better linked item to item data in the record_links table.




