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

sub linked_delivery_order_items {
  my ($self) = @_;

  return $self->linked_records(direction => 'to', to => 'SL::DB::DeliveryOrderItem');
}

sub delivered_qty {
  # checks for delivery_order_stock_id entries, which have been converted to inventory entries
  # uses several rose relationships
  # doesn't differentiate between sales and orders

  my ($self) = @_;
  my $delivered_qty = 0;
  foreach my $doi ( @{$self->linked_delivery_order_items} ) {
    next unless scalar @{$doi->delivery_order_stock_entries};
    $delivered_qty += sum map { $_->inventory ? $_->qty : 0 } @{$doi->delivery_order_stock_entries};
  };
  return $delivered_qty;
};

sub delivered_qty_sql {
  # checks for delivery_order_stock_id entries, which have been converted to inventory entries
  my ($self) = @_;

my $query = <<SQL;
SELECT (sum(i.qty) * CASE WHEN oe.customer_id IS NULL THEN 1 ELSE -1 END) AS delivered
 FROM orderitems oi
 INNER JOIN record_links rl                 ON (    oi.id             = rl.FROM_id
                                                and rl.FROM_table     = 'orderitems'
                                                and rl.to_table::text = 'delivery_order_items'::text
                                               )
 INNER JOIN delivery_order_items doi        ON (doi.id =rl.to_id)
 INNER JOIN delivery_order_items_stock dois ON (dois.delivery_order_item_id = doi.id)
 INNER JOIN inventory i                     ON (dois.id = i.delivery_order_items_stock_id)
 INNER JOIN oe                              ON (oe.id = oi.trans_id)
 WHERE oi.id = ?
 GROUP BY oi.id, oe.id
SQL
  my ($delivered_qty) = selectfirst_array_query($::form, $self->db->dbh, $query, $self->id);

  return $delivered_qty;
};

sub delivered_qty_sql_multi {
  # checks for delivery_order_stock_id entries, which have been converted to inventory entries
  my ($self) = @_;

my $query = <<SQL;
SELECT sum(dois.qty) from delivery_order_items_stock dois
  LEFT OUTER JOIN inventory i ON (dois.id = i.delivery_order_items_stock_id)
WHERE
  dois.delivery_order_item_id in (
SELECT
  to_id
FROM
  record_links
WHERE
  (
    from_id = in AND
    from_table = 'orderitems' AND
    to_table = 'delivery_order_items'
  )
)
SQL
  my ($delivered_qty) = selectfirst_array_query($::form, $self->db->dbh, $query, $self->id);

  return $delivered_qty;
};

sub record { goto &order }

1;

__END__

=pod

=head1 NAME

SL::DB::OrderItems: Rose model for orderitems

=head1 FUNCTIONS

=over 4

=item C<shipped_qty>

=item C<shipped_qty>

returns the number of orderitems which are already linked to Delivery Orders.
The linked key is parts_id and not orderitems (id) -> delivery_order_items (id).
Therefore this function is not safe for identical parts_id.
Sample call:
C<$::form-E<gt>format_amount(\%::myconfig, $_[0]-E<gt>shipped_qty);>

=item C<delivered_qty>

Returns the amount of this orderitem that has been delivered, meaning it
appears in a delivery order AND has been transferred. The delivery order items
are found by direct record_links from orderitems to delivery order items.
Delivery order items that were added manually and not via the record workflow
will therefore not be calculated correctly.

Orders that were created before the individual items were linked (this feature
was added in kivitendo 3.2.0) will therefore return incorrect results.

=item C<delivered_qty_sql>

Does the same as delivered_qty, but via sql.



=item C<delivered_qty_sql>

Returns the amount of the orderitem that has actually been shipped, not just where delivery_order_items exist (how delivered_qty works).

Doesn't deal with different units yet.

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

=head1 AUTHORS

G. Richardson E<lt>grichardson@kivitendo-premium.deE<gt>

=cut


