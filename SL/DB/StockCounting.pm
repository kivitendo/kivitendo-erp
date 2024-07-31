# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::StockCounting;

use strict;

use List::Util qw(none);

use SL::DB::MetaSetup::StockCounting;
use SL::DB::Manager::StockCounting;

use SL::Locale::String qw(t8);

__PACKAGE__->meta->initialize;

sub validate {
  my ($self) = @_;

  my @errors;

  # If part and partsgroup are given then part must belong to the partsgroup.
  if ($self->part && $self->partsgroup_id && $self->part->partsgroup_id != $self->partsgroup_id) {
    push @errors, t8('The part must belong to the partsgroup.');
  }

  # If part and vendor are given then vendor must be a make of the part.
  if ($self->part && $self->vendor_id && none { $_->make == $self->vendor_id } @{$self->part->makemodels}) {
    push @errors, t8('The vendor must be a vendor of the part.');
  }

  return @errors;
}

1;
