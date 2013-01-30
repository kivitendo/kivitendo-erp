package SL::DB::RequirementSpecPredefinedText;

use strict;

use SL::DB::MetaSetup::RequirementSpecPredefinedText;
use SL::DB::Manager::RequirementSpecPredefinedText;
use SL::DB::Helper::ActsAsList;
use SL::Locale::String;

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, t8('The title is missing.')       if !$self->title;
  push @errors, t8('The description is missing.') if !$self->description;

  return @errors;
}

1;
