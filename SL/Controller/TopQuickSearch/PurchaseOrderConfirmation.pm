package SL::Controller::TopQuickSearch::PurchaseOrderConfirmation;

use strict;
use parent qw(SL::Controller::TopQuickSearch::OERecord);

use SL::Locale::String qw(t8);

sub auth { 'purchase_order_edit | purchase_order_view' }

sub name { 'purchase_order_confirmation' }

sub description_config { t8('Purchase Order Confirmations') }

sub description_field { t8('Purchase Order Confirmations') }

sub type { 'purchase_order_confirmation' }

sub vc { 'vendor' }

1;
