package SL::DB::RequirementSpecStatus;

use strict;

use List::MoreUtils qw(none);

use SL::DB::MetaSetup::RequirementSpecStatus;
use SL::DB::Manager::RequirementSpecStatus;
use SL::DB::Helper::ActsAsList;
use SL::Locale::String;

__PACKAGE__->meta->initialize;

our @valid_names = qw(planning running done);

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
