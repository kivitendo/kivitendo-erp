package SL::DB::Manager::Stocktaking;

use strict;

use parent qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Filtered;
use SL::DB::Helper::Paginated;
use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::Stocktaking' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return (
    default        => [ 'itime', 1 ],
    columns        => {
      SIMPLE       => 'ALL',
      comment      => 'lower(comment)',
      chargenumber => 'lower(chargenumber)',
      employee     => 'lower(employee.name)',
      ean          => 'lower(parts.ean)',
      partnumber   => 'lower(parts.partnumber)',
      part         => 'lower(parts.description)',
      bin          => ['lower(warehouse.description)', 'lower(bin.description)'],
    });
}

sub default_objects_per_page {
  20;
}

1;
