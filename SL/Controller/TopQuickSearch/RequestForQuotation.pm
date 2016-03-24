package SL::Controller::TopQuickSearch::RequestForQuotation;

use strict;
use parent qw(SL::Controller::TopQuickSearch::OERecord);

use SL::Locale::String qw(t8);

sub auth { 'request_quotation_edit' }

sub name { 'request_quotation' }

sub description_config { t8('Request Quotations') }

sub description_field { t8('Request Quotations') }

sub type { 'request_quotation' }

sub vc { 'vendor' }

1;
