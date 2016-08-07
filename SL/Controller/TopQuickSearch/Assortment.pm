package SL::Controller::TopQuickSearch::Assortment;

use strict;
use parent qw(SL::Controller::TopQuickSearch::Article);

use SL::Locale::String qw(t8);

sub name { 'assortment' }

sub description_config { t8('Assortment') }

sub description_field { t8('Assortment') }

sub part_type { 'assortment' }

1;
