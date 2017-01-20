package SL::DB::Manager::RecordTemplateItem;

use strict;

use parent qw(SL::DB::Helper::Manager);

sub object_class { 'SL::DB::RecordTemplateItem' }

__PACKAGE__->make_manager_methods;

1;
