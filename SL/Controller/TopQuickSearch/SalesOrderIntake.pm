package SL::Controller::TopQuickSearch::SalesOrderIntake;

use strict;
use parent qw(SL::Controller::TopQuickSearch::OERecord);

use SL::Locale::String qw(t8);

sub auth { 'sales_order_edit | sales_order_view' }

sub name { 'sales_order_intake' }

sub description_config { t8('Sales Order Intakes') }

sub description_field { t8('Sales Order Intakes') }

sub type { 'sales_order_intake' }

sub vc { 'customer' }

1;
