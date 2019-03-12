package SL::Controller::TopQuickSearch::PurchaseDeliveryOrder;

use strict;
use parent qw(SL::Controller::TopQuickSearch::DeliveryOrder);

use SL::Locale::String qw(t8);

sub auth { 'purchase_delivery_order_edit' }

sub name { 'purchase_delivery_order' }

sub description_config { t8('Purchase Delivery Orders') }

sub description_field { t8('Purchase Delivery Orders') }

sub type { 'purchase_delivery_order' }

sub vc { 'vendor' }

1;
