package SL::DB::Helper::ConventionManager;

use strict;

use Rose::DB::Object::ConventionManager;

use base qw(Rose::DB::Object::ConventionManager);

sub auto_manager_class_name {
  my $self         = shift;
  my $object_class = shift || $self->meta->class;

  my @parts        = split m/::/, $object_class;
  my $last         = pop @parts;

  return join('::', @parts, 'Manager', $last);
}

# Base name used for 'make_manager_class', e.g. 'get_all',
# 'update_all'
sub auto_manager_base_name {
  return 'all';
}

sub auto_manager_base_class {
  return 'SL::DB::Helper::Manager';
}

1;
