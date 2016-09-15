# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::PartsClassification;

use strict;

use SL::DB::MetaSetup::PartsClassification;
use SL::DB::Manager::PartsClassification;

__PACKAGE__->meta->initialize;

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, $::locale->text('The description is missing.')  if !$self->description;
  push @errors, $::locale->text('The abbreviation is missing.') if !$self->abbreviation;

  return @errors;
}


1;
