# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Manager::OrderStatus;

use strict;

use parent qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Paginated;
use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::OrderStatus' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return (
    default       => [ 'position', 1 ],
    columns       => {
      SIMPLE      => 'ALL',
      name        => 'lower(order_status.name)',
      description => 'lower(order_status.description)',
    });
}

1;
