package SL::PriceSource::ALL;

use strict;
use SL::PriceSource::Pricegroup;
use SL::PriceSource::MasterData;

my %price_sources_by_name = (
  master_data => 'SL::PriceSource::MasterData',
  pricegroup  => 'SL::PriceSource::Pricegroup',
);

my @price_sources_order = qw(
  master_data
  pricegroup
);

sub all_price_sources {
  map { $price_sources_by_name{$_} } @price_sources_order;
}

sub price_source_class_by_name {
  $price_sources_by_name{$_[1]};
}

1;
