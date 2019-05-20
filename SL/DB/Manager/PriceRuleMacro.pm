# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Manager::PriceRuleMacro;

use strict;

use parent qw(SL::DB::Helper::Manager);

sub object_class { 'SL::DB::PriceRuleMacro' }

use SL::DB::Helper::Filtered;
use SL::DB::Helper::Paginated;
use SL::DB::Helper::Sorted;

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return ( columns => { SIMPLE => 'ALL', },
           default => [ 'name', 1 ],
           nulls   => { price => 'LAST', discount => 'LAST'  }
         );
}

1;
