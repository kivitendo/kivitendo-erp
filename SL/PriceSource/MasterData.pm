package SL::PriceSource::MasterData;

use strict;
use parent qw(SL::PriceSource::Base);

use SL::PriceSource::Price;
use SL::Locale::String;

sub name { 'master_data' }

sub description { t8('Master Data') }

sub available_prices {
  my ($self, %params) = @_;

  my $part = $self->part;

  return () unless $part;

  # TODO: sellprice only in sales, lastcost in purchase
  return $self->make_sellprice($part);
}

sub price_from_source {
  my ($self, $source, $spec) = @_;

  if ($spec eq 'sellprice') {
    return $self->make_sellprice($self->part);
  }
}

sub make_sellprice {
  my ($self, $part) = @_;

  return SL::PriceSource::Price->new(
    price        => $part->sellprice,
    source       => 'master_data/sellprice',
    description  => t8('Sellprice'),
    price_source => $self,
  );
}

1;
