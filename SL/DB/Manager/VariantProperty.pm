# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Manager::VariantProperty;

use strict;

use parent qw(SL::DB::Helper::Manager);

sub object_class { 'SL::DB::VariantProperty' }

use SL::DB::Helper::Sorted;

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return ( default => [ 'sortkey', 1 ],
           columns => { SIMPLE => 'ALL' } );
}

1;
