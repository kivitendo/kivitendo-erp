package SL::DB::Manager::TransferType;

use strict;

use base qw(SL::DB::Helper::Manager);

use Carp;

sub object_class { 'SL::DB::TransferType' }

__PACKAGE__->make_manager_methods;

# class functions

sub get_all_in {
  return shift()->get_all( query => [ direction => 'in', ] );
}

sub get_all_out {
  return shift()->get_all( query => [ direction => 'out', ] );
}

sub get_all_transfer {
  return shift()->get_all( query => [ direction => 'transfer', ] );
}

1;
