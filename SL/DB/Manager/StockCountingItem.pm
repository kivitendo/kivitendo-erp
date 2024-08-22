# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Manager::StockCountingItem;

use strict;

use parent qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::StockCountingItem' }

__PACKAGE__->make_manager_methods;


sub _sort_spec {
  return ( default => [ 'counted_at', 1 ],
           columns => { SIMPLE       => 'ALL' ,
                        counted_at   => [ 'counted_at' ],
                        employee     => [ 'lower(employee.name)',   'counted_at'],
                        part         => [ 'lower(part.partnumber)', 'counted_at'],
                        counting     => [ 'lower(counting.name)',   'counted_at'],
           }
  );
}

1;
