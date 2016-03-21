package SL::Controller::TopQuickSearch::Service;

use strict;
use parent qw(SL::Controller::TopQuickSearch::Article);

use SL::Locale::String qw(t8);

sub name { 'service' }

sub description_config { t8('Services') }

sub description_field { t8('Services') }

sub type { type => 'service' }

1;
