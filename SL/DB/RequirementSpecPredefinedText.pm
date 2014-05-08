package SL::DB::RequirementSpecPredefinedText;

use strict;

use SL::DB::MetaSetup::RequirementSpecPredefinedText;
use SL::DB::Manager::RequirementSpecPredefinedText;
use SL::DB::Helper::ActsAsList;
use SL::DB::Helper::AttrHTML;
use SL::Locale::String;

__PACKAGE__->meta->initialize;

__PACKAGE__->attr_html('text');

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, t8('The description is missing.')    if !$self->description;
  push @errors, t8('The description is not unique.') if  $self->get_first_conflicting('description');
  push @errors, t8('The title is missing.')          if !$self->title;

  return @errors;
}

1;
