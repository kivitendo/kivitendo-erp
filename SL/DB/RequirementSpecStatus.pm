package SL::DB::RequirementSpecStatus;

use strict;

use SL::DB::MetaSetup::RequirementSpecStatus;
use SL::DB::Manager::RequirementSpecStatus;
use SL::DB::Helper::ActsAsList;
use SL::Locale::String;

sub validate {
  my ($self) = @_;

  my @errors;

  push @errors, t8('The name is missing.')        if !$self->name;
  push @errors, t8('The description is missing.') if !$self->description;

  return @errors;
}

1;
