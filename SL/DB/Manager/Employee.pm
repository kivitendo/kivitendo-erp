package SL::DB::Manager::Employee;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

sub object_class { 'SL::DB::Employee' }

__PACKAGE__->make_manager_methods;

sub current {
  return undef unless $::form && $::form->{login};
  return shift->find_by(login => $::form->{login});
}

1;
