package SL::DB::Manager::Business;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::Business' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return ( default => [ 'description', 1 ],
           columns => { SIMPLE => 'ALL',
                        map { ( $_ => "lower(business.$_)" ) } qw(description)
                      });
}

1;
