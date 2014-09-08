package SL::DB::Pricegroup;

use strict;

use SL::DB::MetaSetup::Pricegroup;
use SL::DB::Manager::Pricegroup;

__PACKAGE__->meta->initialize;

sub displayable_name {
  my $self = shift;

  return join ' ', grep $_, $self->id, $self->pricegroup;
}


1;
