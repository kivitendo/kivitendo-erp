package SL::DB::PaymentTerm;

use strict;

use SL::DB::MetaSetup::PaymentTerm;
use SL::DB::Manager::PaymentTerm;
use SL::DB::Helper::ActsAsList;
use SL::DB::Helper::TranslatedAttributes;

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, $::locale->text('The description is missing.')      if !$self->description;
  push @errors, $::locale->text('The long description is missing.') if !$self->description_long;

  return @errors;
}

1;
