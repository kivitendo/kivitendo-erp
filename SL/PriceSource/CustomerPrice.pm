package SL::PriceSource::CustomerPrice;

use strict;
use parent qw(SL::PriceSource::Base);

use SL::PriceSource::Price;
use SL::Locale::String;
use SL::DB::PartCustomerPrice;
# use List::UtilsBy qw(min_by max_by);

sub name { 'customer_price' }

sub description { t8('Customer specific Price') }

sub available_prices {
  my ($self, %params) = @_;

  return () if !$self->part;
  return () if !$self->record->is_sales;

  map { $self->make_price_from_customerprice($_) }
  grep { $_->customer_id == $self->record->customer_id }
  $self->part->customerprices;
}

sub available_discounts { }

sub price_from_source {
  my ($self, $source, $spec) = @_;

  my $customerprice = SL::DB::Manager::PartCustomerPrice->find_by(id => $spec);

  return $self->make_price_from_customerprice($customerprice);

}

sub best_price {
  my ($self, %params) = @_;

  return () if !$self->record->is_sales;

#  min_by { $_->price } $self->available_prices;
#  max_by { $_->price } $self->available_prices;
  &available_prices;

}

sub best_discount { }

sub make_price_from_customerprice {
  my ($self, $customerprice) = @_;

  return SL::PriceSource::Price->new(
    price        => $customerprice->price,
    spec         => $customerprice->id,
    description  => $customerprice->customer_partnumber,
    price_source => $self,
  );
}


1;
