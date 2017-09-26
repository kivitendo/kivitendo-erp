package SL::ShopConnector::ALL;

use strict;

use SL::ShopConnector::Shopware;

my %shop_connector_by_name = (
  shopware    => 'SL::ShopConnector::Shopware',
);

my %shop_connector_by_connector = (
  shopware   => 'SL::ShopConnector::Shopware',
);

my @shop_connector_order = qw(
  shopware
);

my @shop_connectors = (
  { id => "shopware",   description => "Shopware" },
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
