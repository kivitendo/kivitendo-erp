package SL::DB::Department;

use strict;

use SL::DB::MetaSetup::Department;
use SL::DB::Manager::Department;

use SL::DB::DptTrans;

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, $::locale->text('The description is missing.') if !$self->description;

  return @errors;
}

sub is_used {
  my ($self) = @_;

  return undef if !$self->id;
  my $is_used = SL::DB::Manager::DptTrans->find_by(department_id => $self->id);
  return !!$is_used;
}

1;
