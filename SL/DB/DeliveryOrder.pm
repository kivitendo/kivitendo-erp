package SL::DB::DeliveryOrder;

use strict;

use SL::DB::MetaSetup::DeliveryOrder;
use SL::DB::Manager::DeliveryOrder;
use SL::DB::Order;

use List::Util qw(first);

__PACKAGE__->meta->add_relationship(orderitems => { type         => 'one to many',
                                                    class        => 'SL::DB::DeliveryOrderItem',
                                                    column_map   => { id => 'trans_id' },
                                                    manager_args => { with_objects => [ 'part' ] }
                                                  },
                                   );

__PACKAGE__->meta->initialize;

# methods

sub items { goto &orderitems; }

sub sales_order {
  my $self   = shift;
  my %params = @_;

  my $orders = SL::DB::Manager::Order->get_all(
    query => [
      ordnumber => $self->ordnumber,
      @{ $params{query} || [] },
    ],
  );

  return first { $_->is_type('sales_order') } @{ $orders };
}

1;
