package SL::PriceSource::Pricegroup;

use strict;
use parent qw(SL::PriceSource::Base);

use SL::PriceSource::Price;
use SL::Locale::String;
use List::UtilsBy qw(min_by);
use List::Util qw(first);

sub name { 'pricegroup' }

sub description { t8('Pricegroup') }

sub available_prices {
  my ($self, %params) = @_;

  my $item = $self->record_item;

  my $prices = SL::DB::Manager::Price->get_all(
    query        => [ parts_id => $item->parts_id, price => { gt => 0 } ],
    with_objects => 'pricegroup',
    order_by     => 'pricegroun.id',
  );

  return () unless @$prices;

  return map {
    $self->make_price($_);
  } @$prices;
}

sub price_from_source {
  my ($self, $source, $spec) = @_;

  my $price = SL::DB::Manager::Price->find_by(id => $spec);

  return $self->make_price($price);
}

sub best_price {
  my ($self, %params) = @_;

  my @prices    = $self->availabe_prices;
  my $customer  = $self->record->customer;
  my $min_price = min_by { $_->price } @prices;

  return $min_price if !$customer || !$customer->cv_klass;

  my $best_price = first { $_->spec == $customer->cv_class } @prices;

  return $best_price || $min_price;
}

sub make_price {
  my ($self, $price_obj) = @_;

  SL::PriceSource::Price->new(
    price        => $price_obj->price,
    spec         => $price_obj->id,
    description  => $price_obj->pricegroup->pricegroup,
    price_source => $self,
  )
}

1;
