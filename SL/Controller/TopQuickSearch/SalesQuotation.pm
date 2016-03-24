package SL::Controller::TopQuickSearch::SalesQuotation;

use strict;
use parent qw(SL::Controller::TopQuickSearch::OERecord);

use SL::Locale::String qw(t8);

sub auth { 'sales_quotation_edit' }

sub name { 'sales_quotation' }

sub description_config { t8('Sales Quotations') }

sub description_field { t8('Sales Quotations') }

sub type { 'sales_quotation' }

sub vc { 'customer' }

1;
