package SL::DB::RequirementSpecVersion;

use strict;

use SL::DB::MetaSetup::RequirementSpecVersion;
use SL::Locale::String;

__PACKAGE__->meta->initialize;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, t8('The version number is missing.') if !$self->version_number;
  push @errors, t8('The description is missing.')    if !$self->description;

  return @errors;
}

1;
