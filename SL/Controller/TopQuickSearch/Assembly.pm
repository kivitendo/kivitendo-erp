package SL::Controller::TopQuickSearch::Assembly;

use strict;
use parent qw(SL::Controller::TopQuickSearch::Article);

use SL::Locale::String qw(t8);

sub name { 'assembly' }

sub description_config { t8('Assemblies') }

sub description_field { t8('Assemblies') }

sub part_type { 'assembly' }

1;
