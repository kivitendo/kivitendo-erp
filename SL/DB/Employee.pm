package SL::DB::Employee;

use strict;

use SL::DB::MetaSetup::Employee;
use SL::DB::Manager::Employee;

sub has_right {
  my $self  = shift;
  my $right = shift;

  return $::auth->check_right($self->login, $right);
}

1;
