package SL::Controller::TopQuickSearch::PurchaseOrder;

use strict;
use parent qw(SL::Controller::TopQuickSearch::OERecord);

use SL::Locale::String qw(t8);

sub auth { 'purchase_order_edit | purchase_order_view' }

sub name { 'purchase_order' }

sub description_config { t8('Purchase Orders') }

sub description_field { t8('Purchase Orders') }

sub type { 'purchase_order' }

sub vc { 'vendor' }

1;
