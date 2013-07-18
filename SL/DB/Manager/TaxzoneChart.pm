package SL::DB::Manager::TaxzoneChart;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::TaxzoneChart' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return ( default => [ 'taxzone_id', 1 ],
           columns => { SIMPLE      => 'ALL',
                      });
}

1;
