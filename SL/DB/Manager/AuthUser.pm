package SL::DB::Manager::AuthUser;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Paginated;
use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::AuthUser' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return ( default => [ 'login', 1 ],
           columns => { SIMPLE => 'ALL' } );
}

1;
