package SL::PriceSource::Price;

use strict;

use parent 'SL::DB::Object';
use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(price description spec price_source) ],
  array => [ qw(depends_on) ]
);

sub source {
  $_[0]->price_source
  ?  $_[0]->price_source->name . '/' . $_[0]->spec
  : '';
}

sub full_description {
  my ($self) = @_;

  $self->price_source
    ? $self->price_source->description . ': ' . $self->description
    : $self->description
}

1;
