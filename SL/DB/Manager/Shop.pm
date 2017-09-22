# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Manager::Shop;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

sub object_class { 'SL::DB::Shop' }

use SL::DB::Helper::Sorted;

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return ( default => [ 'sortkey', 1 ],
           columns => { SIMPLE => 'ALL' } );
}

sub get_default {
    return $_[0]->get_first(where => [ obsolete => 0 ], sort_by => 'sortkey');
}

1;

1;
