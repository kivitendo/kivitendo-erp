package SL::ShopConnector::ALL;

use strict;

use SL::ShopConnector::Shopware;
use SL::ShopConnector::Shopware6;
use SL::ShopConnector::WooCommerce;

my %shop_connector_by_name = (
  shopware    => 'SL::ShopConnector::Shopware',
  shopware6   => 'SL::ShopConnector::Shopware6',
  woocommerce => 'SL::ShopConnector::WooCommerce',
);

my %shop_connector_by_connector = (
  shopware    => 'SL::ShopConnector::Shopware',
  shopware6   => 'SL::ShopConnector::Shopware6',
  woocommerce => 'SL::ShopConnector::WooCommerce',
);

my @shop_connector_order = qw(
  woocommerce
  shopware
  shopware6
);

my @shop_connectors = (
  { id => "shopware",    description => "Shopware" },
  { id => "shopware6",   description => "Shopware6" },
  { id => "woocommerce", description => "WooCommerce" },
);


sub all_shop_connectors {
  map { $shop_connector_by_name{$_} } @shop_connector_order;
}

sub shop_connector_class_by_name {
  $shop_connector_by_name{$_[1]};
}

sub shop_connector_class_by_connector {
  $shop_connector_by_connector{$_[1]};
}

sub connectors {
  \@shop_connectors;
}
1;
