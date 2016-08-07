package SL::DB::Manager::PriceFactor;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::PriceFactor' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return ( default => [ 'sortkey', 1 ],
           columns => { SIMPLE => 'ALL' });
}

1;

