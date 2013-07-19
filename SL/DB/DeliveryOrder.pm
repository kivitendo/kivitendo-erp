package SL::DB::DeliveryOrder;

use strict;

use Carp;

use SL::DB::MetaSetup::DeliveryOrder;
use SL::DB::Manager::DeliveryOrder;
use SL::DB::Helper::LinkedRecords;
use SL::DB::Helper::TransNumberGenerator;

use List::Util qw(first);

__PACKAGE__->meta->add_relationship(orderitems => { type         => 'one to many',
                                                    class        => 'SL::DB::DeliveryOrderItem',
                                                    column_map   => { id => 'delivery_order_id' },
                                                    manager_args => { with_objects => [ 'part' ] }
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

1;
