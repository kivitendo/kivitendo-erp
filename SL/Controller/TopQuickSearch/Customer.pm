package SL::Controller::TopQuickSearch::Customer;

use strict;
use parent qw(SL::Controller::TopQuickSearch::CustomerVendor);
use SL::DB::Customer;

use SL::Locale::String qw(t8);

sub auth { undef }

sub name { 'customer' }

sub model { 'Customer' }

sub db { 'customer' }

sub description_config { t8('Customers') }

sub description_field { t8('Customers') }

1;
