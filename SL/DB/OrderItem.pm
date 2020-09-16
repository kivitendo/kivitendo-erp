package SL::DB::OrderItem;

use strict;

use SL::DB::MetaSetup::OrderItem;
use SL::DB::Manager::OrderItem;
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
use SL::Helper::ShippedQty;

__PACKAGE__->meta->initialize;

__PACKAGE__->configure_acts_as_list(group_by => [qw(trans_id)]);

sub is_price_update_available {
  my $self = shift;
  return $self->origprice > $self->part->sellprice;
}

sub shipped_qty {
  my ($self, %params) = @_;

  my $force = delete $params{force};

  SL::Helper::ShippedQty->new(%params)->calculate($self)->write_to_objects if $force || !defined $self->{shipped_qty};

  $self->{shipped_qty};
}

sub linked_delivery_order_items {
  my ($self) = @_;

  return $self->linked_records(direction => 'to', to => 'SL::DB::DeliveryOrderItem');
}

sub delivered_qty { goto &shipped_qty }

sub record { goto &order }

1;

__END__

=pod

=head1 NAME

SL::DB::OrderItems: Rose model for orderitems

=head1 FUNCTIONS

=over 4

=item C<shipped_qty PARAMS>

Calculates the shipped qty for this orderitem (measured in the current unit)
and returns it.

Note that the shipped qty is expected not to change within the request and is
cached in C<shipped_qty> once calculated. If C<< force => 1 >> is passed, the
existibng cache is ignored.

Given parameters will be passed to L<SL::Helper::ShippedQty>, so you can force
the shipped/delivered distinction like this:

  $_->shipped_qty(require_stock_out => 0);

Note however that calculating shipped_qty on individual Orderitems is generally
a bad idea. See L<SL::Helper::ShippedQty> for way to compute these all at once.

=item C<delivered_qty>

Alias for L</shipped_qty>.

=back

=head1 AUTHORS

G. Richardson E<lt>grichardson@kivitendo-premium.deE<gt>

=cut
