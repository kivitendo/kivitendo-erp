package SL::DB::Helper::Metadata;

use strict;
use SL::X;

use Rose::DB::Object::Metadata;
use SL::DB::Helper::ConventionManager;

use base qw(Rose::DB::Object::Metadata);

sub convention_manager_class {
  return 'SL::DB::Helper::ConventionManager';
}

sub default_manager_base_class {
  return 'SL::DB::Helper::Manager';
}

sub initialize {
  my $self = shift;
  $self->make_attr_auto_helpers unless $self->is_initialized;
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

sub handle_error {
  my($self, $object) = @_;

  # these are used as Rose internal canaries, don't wrap them
  die $object->error if UNIVERSAL::isa($object->error, 'Rose::DB::Object::Exception');

  SL::X::DBRoseError->throw(
    db_error   => $object->error,
    class      => ref($object),
    metaobject => $self,
    object     => $object,
  );
}

1;
