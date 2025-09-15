package SL::DB::Manager::OrderItem;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Filtered;
use SL::DB::Helper::Paginated;
use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::OrderItem' }

__PACKAGE__->make_manager_methods;
__PACKAGE__->add_filter_specs(
  reqdate => sub {
    my ($key, $value, $prefix) = @_;

    return or => [
      $prefix . reqdate => $value,
      and => [
        $prefix . reqdate => undef,
        $prefix . 'order.reqdate' => $value,
      ]
    ], $prefix . 'order';
  },
);


sub _sort_spec {
  return ( columns => { delivery_date => [ 'deliverydate',        ],
                        description   => [ 'lower(orderitems.description)',  ],
                        partnumber    => [ 'part.partnumber',     ],
                        qty           => [ 'qty'                  ],
                        ordnumber     => [ 'order.ordnumber'      ],
                        customer      => [ 'lower(customer.name)', ],
                        position      => [ 'trans_id', 'position' ],
                        reqdate       => [ 'COALESCE(orderitems.reqdate, order.reqdate)' ],
                        orddate       => [ 'order.orddate' ],
                        sellprice     => [ 'orderitems.sellprice' ],
                        discount      => [ 'orderitems.discount' ],
                        transdate     => [ 'orderitems.transdate::date', 'order.reqdate' ],
                        transaction_description => [ 'lower(order.transaction_description)'],
                      },
           default => [ 'position', 1 ],
           nulls   => { }
         );
}

sub default_objects_per_page { 15 }

1;
