# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::StockCountingItem;

use strict;

use List::Util qw(none);

use SL::DB::MetaSetup::StockCountingItem;
use SL::DB::Manager::StockCountingItem;

use SL::Locale::String qw(t8);

__PACKAGE__->meta->initialize;

sub validate {
  my ($self) = @_;

  my @errors;

  push @errors, t8('A Stock Counting must be set.') if !$self->counting_id;
  push @errors, t8('A part must be set.')           if !$self->part_id;
  push @errors, t8('A bin must be set.')            if !$self->bin_id;

  # If part in counting is given then it must match the part of the item to count.
  if ($self->counting->part_id && $self->part_id != $self->counting->part_id) {
    push @errors, t8('The part must match the part given in the counting.');
  }

  # If partsgroup in counting is given then the part of the item to count must belong to the partsgroup.
  if ($self->counting->partsgroup_id && $self->part->partsgroup_id != $self->counting->partsgroup_id) {
    push @errors, t8('The part must belong to the partsgroup given in the counting.');
  }

  # If vendor in counting is given then the vendor must be a make of the part of the item to count.
  if ($self->counting->vendor_id && none { $_->make == $self->counting->vendor_id } @{$self->part->makemodels}) {
    push @errors, t8('The vendor given in the counting must be a vendor of the part.');
  }

  return @errors;
}

1;
