package SL::DB::Manager::Inventory;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Filtered;
use SL::DB::Helper::Paginated;
use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::Inventory' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return (
    default        => [ 'itime', 1 ],
    columns        => {
      SIMPLE       => 'ALL',
    });
}

sub default_objects_per_page {
  20;
}

1;
