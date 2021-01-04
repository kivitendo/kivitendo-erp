package SL::Controller::TopQuickSearch::Vendor;

use strict;
use parent qw(SL::Controller::TopQuickSearch::CustomerVendor);
use SL::DB::Vendor;

use SL::Locale::String qw(t8);

sub auth { undef }

sub name { 'vendor' }

sub model { 'Vendor' }

sub db { 'vendor' }

sub description_config { t8('Vendors') }

sub description_field { t8('Vendors') }

1;
