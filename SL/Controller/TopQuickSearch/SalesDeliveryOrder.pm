package SL::Controller::TopQuickSearch::SalesDeliveryOrder;

use strict;
use parent qw(SL::Controller::TopQuickSearch::DeliveryOrder);

use SL::Locale::String qw(t8);

sub auth { 'sales_delivery_order_edit' }

sub name { 'sales_delivery_order' }

sub description_config { t8('Sales Delivery Orders') }

sub description_field { t8('Sales Delivery Orders') }

sub type { 'sales_delivery_order' }

sub vc { 'customer' }

1;
