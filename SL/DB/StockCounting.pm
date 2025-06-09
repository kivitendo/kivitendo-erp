# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::StockCounting;

use strict;

use List::Util qw(any min none);

use SL::DB::MetaSetup::StockCounting;
use SL::DB::Manager::StockCounting;

use SL::Locale::String qw(t8);

__PACKAGE__->meta->add_relationship(
  stock_counting_items => {
    type         => 'one to many',
    class        => 'SL::DB::StockCountingItem',
    column_map   => { id => 'counting_id' },
  },
);

__PACKAGE__->meta->initialize;

sub items     { goto &stock_counting_items; }
sub add_items { goto &add_stock_counting_items; }

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

sub is_reconciliated {
  any { !!$_->correction_inventory_id } @{$_[0]->items};
}

sub start_time_of_counting {
  min map { $_->counted_at } @{$_[0]->items};
}

1;
