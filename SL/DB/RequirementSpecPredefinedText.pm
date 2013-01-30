package SL::DB::RequirementSpecPredefinedText;

use strict;

use SL::DB::MetaSetup::RequirementSpecPredefinedText;
use SL::DB::Helper::ActsAsList;
use SL::Locale::String;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, t8('The title is missing.')       if !$self->title;
  push @errors, t8('The description is missing.') if !$self->description;

  return @errors;
}

1;
