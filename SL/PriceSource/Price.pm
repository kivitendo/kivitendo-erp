package SL::PriceSource::Price;

use strict;

use parent 'SL::DB::Object';
use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(price description spec price_source) ],
  array => [ qw(depends_on) ]
);

use SL::DB::Helper::Attr;
SL::DB::Helper::Attr::make(__PACKAGE__,
  price => 'numeric(15,5)',
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

sub to_str {
  "source: @{[ $_[0]->source ]}, price: @{[ $_[0]->price]}, description: @{[ $_[0]->description ]}"
}

1;
