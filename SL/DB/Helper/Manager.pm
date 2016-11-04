package SL::DB::Helper::Manager;

use strict;

use Rose::DB::Object::Manager;
use base qw(Rose::DB::Object::Manager);

sub make_manager_methods {
  my $class  = shift;
  my @params = scalar(@_) ? @_ : qw(all);
  return $class->SUPER::make_manager_methods(@params);
}

sub find_by {
  my $class = shift;

  return if !@_;
  return $class->get_all(query => [ @_ ], limit => 1)->[0];
}

sub find_by_or_create {
  my $class = shift;

  my $found;
  eval {
    $found = $class->find_by(@_);
    1;
  } or die $@;
  return defined $found ? $found : $class->object_class->new;
}

sub get_first {
  shift->get_all(
    @_,
    limit => 1,
  )->[0];
}

1;
