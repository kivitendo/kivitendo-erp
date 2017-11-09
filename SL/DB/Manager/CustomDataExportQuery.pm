package SL::DB::Manager::CustomDataExportQuery;

use strict;

use parent qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::CustomDataExportQuery' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return ( default => [ 'name', 1 ],
           name    => 'lower(custom_data_export_queries.name)',
           columns => { SIMPLE => 'ALL' });
}

1;
