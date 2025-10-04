package SL::DB::Bin;

use strict;

use SL::DB::MetaSetup::Bin;
use SL::DB::Manager::Bin;

__PACKAGE__->meta->initialize;


sub full_description {
  my ($self) = @_;

  $self->warehouse
    ? $self->warehouse->description . "->" . $self->description
    : $self->description
}

sub displayable_name { goto &full_description };

1;
