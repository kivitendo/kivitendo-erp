package SL::DB::RequirementSpecAcceptanceStatus;

use strict;

use List::MoreUtils qw(none);

use SL::DB::MetaSetup::RequirementSpecAcceptanceStatus;
use SL::DB::Manager::RequirementSpecAcceptanceStatus;
use SL::DB::Helper::ActsAsList;
use SL::Locale::String;

__PACKAGE__->meta->initialize;

our @valid_names = qw(accepted accepted_with_defects accepted_with_defects_to_be_fixed not_accepted);

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, t8('The name is missing.')                     if !$self->name;
  push @errors, t8('The name and description are not unique.') if  $self->get_first_conflicting('name', 'description');
  push @errors, t8('The name is invalid.')                     if  none { $_ eq $self->name } @valid_names;
  push @errors, t8('The description is missing.')              if !$self->description;

  return @errors;
}

1;
