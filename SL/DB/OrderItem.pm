package SL::DB::OrderItem;

use strict;

use List::Util qw(sum);
use SL::AM;

use SL::DB::MetaSetup::OrderItem;
use SL::DB::Helper::CustomVariables (
  sub_module  => 'orderitems',
  cvars_alias => 1,
  overloads   => {
    parts_id => 'SL::DB::Part',
  },
);

__PACKAGE__->meta->add_relationship(
  part => {
    type         => 'one to one',
    class        => 'SL::DB::Part',
    column_map   => { parts_id => 'id' },
  },
  price_factor_obj => {
    type           => 'one to one',
    class          => 'SL::DB::PriceFactor',
    column_map     => { price_factor_id => 'id' },
  },
  unit_obj       => {
    type         => 'one to one',
    class        => 'SL::DB::Unit',
    column_map   => { unit => 'name' },
  },
  order => {
    type         => 'one to one',
    class        => 'SL::DB::Order',
    column_map   => { trans_id => 'id' },
  },
);

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

__PACKAGE__->meta->initialize;

sub is_price_update_available {
  my $self = shift;
  return $self->origprice > $self->part->sellprice;
}

sub shipped_qty {
  my ($self) = @_;

  my $d_orders = $self->order->linked_records(direction => 'to', to => 'SL::DB::DeliveryOrder');
  my @doi      = grep { $_->parts_id == $self->parts_id } map { $_->orderitems } @$d_orders;

  return sum(map { AM->convert_unit($_->unit => $self->unit) * $_->qty } @doi);
}

package SL::DB::Manager::OrderItem;

use SL::DB::Helper::Paginated;
use SL::DB::Helper::Sorted;

sub _sort_spec {
  return ( columns => { delivery_date => [ 'deliverydate',        ],
                        description   => [ 'lower(orderitems.description)',  ],
                        partnumber    => [ 'part.partnumber',     ],
                        qty           => [ 'qty'                  ],
                        ordnumber     => [ 'order.ordnumber'      ],
                        customer      => [ 'lower(customer.name)', ],
                        position      => [ 'trans_id', 'runningnumber' ],
                        reqdate       => [ 'COALESCE(orderitems.reqdate, order.reqdate)' ],
                        orddate       => [ 'order.orddate' ],
                        sellprice     => [ 'sellprice' ],
                        discount      => [ 'discount' ],
                        transdate     => [ 'transdate::date', 'order.reqdate' ],
                      },
           default => [ 'position', 1 ],
           nulls   => { }
         );
}

sub default_objects_per_page { 40 }

1;
