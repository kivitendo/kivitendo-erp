package SL::DB::Manager::PeriodicInvoice;

use strict;

use parent qw(SL::DB::Helper::Manager);

sub object_class { 'SL::DB::PeriodicInvoice' }

__PACKAGE__->make_manager_methods;

1;
