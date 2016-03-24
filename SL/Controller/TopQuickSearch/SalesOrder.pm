package SL::Controller::TopQuickSearch::SalesOrder;

use strict;
use parent qw(SL::Controller::TopQuickSearch::OERecord);

use SL::Locale::String qw(t8);

sub auth { 'sales_order_edit' }

sub name { 'sales_order' }

sub description_config { t8('Sales Orders') }

sub description_field { t8('Sales Orders') }

sub type { 'sales_order' }

sub vc { 'customer' }

1;
