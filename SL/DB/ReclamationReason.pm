package SL::DB::ReclamationReason;

use strict;

use SL::DB::MetaSetup::ReclamationReason;
use SL::DB::Manager::ReclamationReason;
use SL::DB::Helper::ActsAsList

__PACKAGE__->meta->initialize;

sub validate {
  my ($self) = @_;

  my @errors;
  if (!$self->name) {
      push @errors, $::locale->text('The name is missing.');
  }
  if (!$self->description) {
    push @errors, $::locale->text('The description is missing.');
  }
  return @errors;
}

1;
