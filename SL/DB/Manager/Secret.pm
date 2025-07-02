package SL::DB::Manager::Secret;

use strict;

use parent qw(SL::DB::Helper::Manager);
use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::Secret' }

__PACKAGE__->make_manager_methods;

1;
