package SL::DB::Manager::Batch;

use strict;

use base qw(SL::DB::Helper::Manager);

sub object_class { 'SL::DB::Batch' }

__PACKAGE__->make_manager_methods;

1;
