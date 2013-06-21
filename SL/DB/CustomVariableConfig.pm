# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::CustomVariableConfig;

use strict;

use SL::DB::MetaSetup::CustomVariableConfig;
use SL::DB::Manager::CustomVariableConfig;
use SL::DB::Helper::ActsAsList;

__PACKAGE__->meta->initialize;

__PACKAGE__->configure_acts_as_list(group_by => [qw(module)]);

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, $::locale->text('The name is missing.')        if !$self->name;
  push @errors, $::locale->text('The description is missing.') if !$self->description;
  push @errors, $::locale->text('The type is missing.')        if !$self->type;
  push @errors, $::locale->text('The option field is empty.')  if (($self->type || '') eq 'select') && !$self->options;

  return @errors;
}

1;
