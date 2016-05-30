package SL::DB::Manager::PartsPriceHistory;

use strict;

use parent qw(SL::DB::Helper::Manager);

sub object_class { 'SL::DB::PartsPriceHistory' }

__PACKAGE__->make_manager_methods;

1;
