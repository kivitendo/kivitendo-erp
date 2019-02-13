package SL::DB::Manager::EmployeeProjectInvoices;

use strict;

use parent qw(SL::DB::Helper::Manager);

sub object_class { 'SL::DB::EmployeeProjectInvoices' }

__PACKAGE__->make_manager_methods;

1;
