package SL::PriceSource::Pricegroup;

use strict;
use parent qw(SL::PriceSource::Base);

use SL::PriceSource::Price;
use SL::Locale::String;

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

sub make_price {
  my ($self, $price_obj) = @_;

  SL::PriceSource::Price->new(
    price        => $price_obj->price,
    source       => 'pricegroup/' . $price_obj->id,
    description  => $price_obj->pricegroup->pricegroup,
    price_source => $self,
  )
}

1;
