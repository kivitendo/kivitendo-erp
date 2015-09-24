package SL::DB::Manager::EmailJournal;

use strict;

use parent qw(SL::DB::Helper::Manager);

sub object_class { 'SL::DB::EmailJournal' }

__PACKAGE__->make_manager_methods;

1;
