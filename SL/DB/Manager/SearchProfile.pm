package SL::DB::Manager::SearchProfile;

use strict;

use parent qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::SearchProfile' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return ( default => [ 'name', 1 ],
           columns => { SIMPLE => 'ALL',
                        name   => 'lower(name)',
                      });
}

1;
