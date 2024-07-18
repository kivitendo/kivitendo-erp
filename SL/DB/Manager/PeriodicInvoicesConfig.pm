package SL::DB::Manager::PeriodicInvoicesConfig;

use strict;

use parent qw(SL::DB::Helper::Manager);

sub object_class { 'SL::DB::PeriodicInvoicesConfig' }

__PACKAGE__->make_manager_methods;

1;
