package SL::DB::Manager::Piece;

use strict;

use base qw(SL::DB::Helper::Manager);

sub object_class { 'SL::DB::Piece' }

__PACKAGE__->make_manager_methods;

1;
