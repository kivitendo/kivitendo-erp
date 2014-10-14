package SL::PriceSource::ALL;

use strict;
use SL::PriceSource::Pricegroup;
use SL::PriceSource::MasterData;
use SL::PriceSource::Makemodel;
use SL::PriceSource::Customer;
use SL::PriceSource::Vendor;
use SL::PriceSource::Business;

my %price_sources_by_name = (
  master_data => 'SL::PriceSource::MasterData',
  customer    => 'SL::PriceSource::Customer',
  vendor      => 'SL::PriceSource::Vendor',
  pricegroup  => 'SL::PriceSource::Pricegroup',
  makemodel   => 'SL::PriceSource::Makemodel',
  business    => 'SL::PriceSource::Business',
);

my @price_sources_order = qw(
  master_data
  customer
  vendor
  pricegroup
  makemodel
  business
);

sub all_enabled_price_sources {
  my %disabled = map { $_ => 1 } @{ $::instance_conf->get_disabled_price_sources || [] };

  map { $price_sources_by_name{$_} } grep { !$disabled{$_} } @price_sources_order;
}

sub all_price_sources {
  map { $price_sources_by_name{$_} } @price_sources_order;
}

sub price_source_class_by_name {
  $price_sources_by_name{$_[1]};
}

1;
