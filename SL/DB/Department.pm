package SL::DB::Department;

use strict;

use SL::DB::MetaSetup::Department;
use SL::DB::Manager::Department;

__PACKAGE__->meta->initialize;

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, $::locale->text('The description is missing.') if !$self->description;

  return @errors;
}

sub is_used {
  my ($self) = @_;

  # Since the removal of table dpt_trans no check is required here anymore.
  return undef if !$self->id;
  return 0;
}

1;
