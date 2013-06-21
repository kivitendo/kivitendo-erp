package SL::DB::Business;

use strict;

use SL::DB::MetaSetup::Business;
use SL::DB::Manager::Business;

__PACKAGE__->meta->initialize;

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, $::locale->text('The description is missing.')          if !$self->description;
  push @errors, $::locale->text('The discount must not be negative.')   if $self->discount <  0;
  push @errors, $::locale->text('The discount must be less than 100%.') if $self->discount >= 1;

  return @errors;
}

1;
