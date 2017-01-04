package SL::DB::Assembly;

use strict;

use SL::DB::MetaSetup::Assembly;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

__PACKAGE__->meta->initialize;

sub linetotal_sellprice {
  my ($self) = @_;

  return 0 unless $self->qty > 0 and $self->part->sellprice > 0;
  return $self->qty * $self->part->sellprice / ( $self->part->price_factor_id ? $self->part->price_factor->factor : 1 );
}

sub linetotal_lastcost {
  my ($self) = @_;

  return 0 unless $self->qty > 0 and $self->part->lastcost > 0;
  return $self->qty * $self->part->lastcost / ( $self->part->price_factor_id ? $self->part->price_factor->factor : 1 );
}

1;
