package SL::Controller::TopQuickSearch::PurchaseQuotationIntake;

use strict;
use parent qw(SL::Controller::TopQuickSearch::OERecord);

use SL::Locale::String qw(t8);

sub auth { 'request_quotation_edit | request_quotation_view' }

sub name { 'purchase_quotation_intake' }

sub description_config { t8('Purchase Quotation Intakes') }

sub description_field { t8('Purchase Quotation Intakes') }

sub type { 'purchase_quotation_intake' }

sub vc { 'vendor' }

1;
