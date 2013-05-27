# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::DeliveryTerm;

use strict;

use SL::DB::MetaSetup::DeliveryTerm;
use SL::DB::Manager::DeliveryTerm;
use SL::DB::Helper::ActsAsList;


sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, $::locale->text('The description is missing.')      if !$self->description;
  push @errors, $::locale->text('The long description is missing.') if !$self->description_long;

  return @errors;
}

1;
