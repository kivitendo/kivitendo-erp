package SL::DB::Helpers::Metadata;

use strict;

use Rose::DB::Object::Metadata;
use SL::DB::Helpers::ConventionManager;

use base qw(Rose::DB::Object::Metadata);

sub convention_manager_class {
  return 'SL::DB::Helpers::ConventionManager';
}

sub default_manager_base_class {
  return 'SL::DB::Helpers::Manager';
}

sub initialize {
  my $self = shift;
  $self->make_attr_auto_helpers;
  $self->SUPER::initialize(@_);
}

sub make_attr_helpers {
  my ($self, %params) = @_;
  SL::DB::Helper::Attr::make($self->class, %params);
}

sub make_attr_auto_helpers {
  my ($self) = @_;
  SL::DB::Helper::Attr::auto_make($self->class);
}

1;
