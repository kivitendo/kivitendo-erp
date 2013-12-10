package SL::DB::DeliveryTerm;

use strict;

use SL::DB::MetaSetup::DeliveryTerm;
use SL::DB::Manager::DeliveryTerm;
use SL::DB::Helper::ActsAsList;
use SL::DB::Helper::TranslatedAttributes;

__PACKAGE__->meta->initialize;

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, $::locale->text('The description is missing.')      if !$self->description;
  push @errors, $::locale->text('The long description is missing.') if !$self->description_long;

  return @errors;
}

1;
