package SL::DB::RequirementSpecType;

use strict;

use SL::DB::MetaSetup::RequirementSpecType;
use SL::DB::Manager::RequirementSpecType;
use SL::DB::Helper::ActsAsList;
use SL::Locale::String;

__PACKAGE__->meta->initialize;

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, t8('The description is missing.')    if !$self->description;
  push @errors, t8('The description is not unique.') if  $self->get_first_conflicting('description');

  return @errors;
}

1;
