package SL::PriceSource::Price;

use strict;

use parent 'SL::DB::Object';
use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(price description source price_source) ],
  array => [ qw(depends_on) ]
);

sub full_description {
  my ($self) = @_;

  $self->price_source
    ? $self->price_source->description . ': ' . $self->description
    : $self->description
}

1;
