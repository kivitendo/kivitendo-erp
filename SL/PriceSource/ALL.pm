package SL::PriceSource::ALL;

use strict;
use SL::PriceSource::Pricegroup;
use SL::PriceSource::MasterData;
use SL::PriceSource::Makemodel;
use SL::PriceSource::CustomerPrice;
use SL::PriceSource::Customer;
use SL::PriceSource::Vendor;
use SL::PriceSource::Business;
use SL::PriceSource::PriceRules;

my %price_sources_by_name = (
  master_data       => 'SL::PriceSource::MasterData',
  customer_discount => 'SL::PriceSource::Customer',
  vendor_discount   => 'SL::PriceSource::Vendor',
  pricegroup        => 'SL::PriceSource::Pricegroup',
  makemodel         => 'SL::PriceSource::Makemodel',
  customerprice     => 'SL::PriceSource::CustomerPrice',
  business          => 'SL::PriceSource::Business',
  price_rules       => 'SL::PriceSource::PriceRules',
);

my @price_sources_order = qw(
  master_data
  customer_discount
  vendor_discount
  pricegroup
  makemodel
  customerprice
  business
  price_rules
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
