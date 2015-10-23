package SL::PriceSource::Makemodel;

use strict;
use parent qw(SL::PriceSource::Base);

use SL::PriceSource::Price;
use SL::Locale::String;
use SL::DB::MakeModel;
use List::UtilsBy qw(min_by);

sub name { 'makemodel' }

sub description { t8('Makemodel Price') }

sub available_prices {
  my ($self, %params) = @_;

  return () if !$self->part;
  return () if  $self->record->is_sales;

  map { $self->make_price_from_makemodel($_) }
  grep { $_->make == $self->record->vendor_id }
  $self->part->makemodels;
}

sub available_discounts { }

sub price_from_source {
  my ($self, $source, $spec) = @_;

  my $makemodel = SL::DB::Manager::MakeModel->find_by(id => $spec);

  return SL::PriceSource::Price->new(
    price_source => $self,
    missing      => t8('This makemodel price does not exist anymore'),
  ) if !$makemodel;

  return $self->make_price_from_makemodel($makemodel);

}

sub discount_from_source { }

sub best_price {
  my ($self, %params) = @_;

  return () if $self->record->is_sales;

  min_by { $_->price } $self->available_prices;

}

sub best_discount { }

sub make_price_from_makemodel {
  my ($self, $makemodel) = @_;

  return SL::PriceSource::Price->new(
    price        => $makemodel->lastcost,
    spec         => $makemodel->id,
    description  => $makemodel->model,
    price_source => $self,
  );
}

1;
