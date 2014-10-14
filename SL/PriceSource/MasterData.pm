package SL::PriceSource::MasterData;

use strict;
use parent qw(SL::PriceSource::Base);

use SL::PriceSource::Price;
use SL::Locale::String;

sub name { 'master_data' }

sub description { t8('Master Data') }

sub available_prices {
  my ($self, %params) = @_;

  return () unless $self->part;

  grep { $_->price > 0 } $self->record->is_sales
    ? ($self->make_sellprice, $self->make_listprice)
    : ($self->make_lastcost,  $self->make_listprice);
}

sub available_discounts { }

sub price_from_source {
  my ($self, $source, $spec) = @_;

    $spec eq 'sellprice' ? $self->make_sellprice
  : $spec eq 'lastcost'  ? $self->make_lastcost
  : $spec eq 'listprice' ? $self->make_listprice
  : do { die "unknown spec '$spec'" };
}

sub best_price {
  $_[0]->record->is_sales
  ? $_[0]->make_sellprice
  : $_[0]->make_lastcost
}

sub best_discount { }

sub make_sellprice {
  my ($self) = @_;

  return SL::PriceSource::Price->new(
    price        => $self->part->sellprice,
    spec         => 'sellprice',
    description  => t8('Sellprice'),
    price_source => $self,
  );
}

sub make_listprice {
  my ($self) = @_;

  return SL::PriceSource::Price->new(
    price        => $self->part->listprice,
    spec         => 'listprice',
    description  => t8('List Price'),
    price_source => $self,
  );
}

sub make_lastcost {
  my ($self) = @_;

  return SL::PriceSource::Price->new(
    price        => $self->part->lastcost,
    spec         => 'lastcost',
    description  => t8('Lastcost'),
    price_source => $self,
  );
}

1;
