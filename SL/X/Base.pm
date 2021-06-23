package SL::X::Base;

use strict;
use warnings;

use parent qw(Exception::Class::Base);

sub _defaults { return () }

sub message { goto &error }

sub error {
  my ($self, @params) = @_;

  return $self->{message} unless ($self->{message} // '') eq '';

  return $self->SUPER::error(@params) if !$self->can('_defaults');

  my %defaults = $self->_defaults;
  return $self->SUPER::error(@params) if !$defaults{error_template};

  my ($format, @fields) = @{ $defaults{error_template} };
  return sprintf $format, map { $self->$_ } @fields;
}

1;
