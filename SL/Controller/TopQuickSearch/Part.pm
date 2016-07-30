package SL::Controller::TopQuickSearch::Part;

use strict;
use parent qw(SL::Controller::TopQuickSearch::Article);

use SL::Locale::String qw(t8);

sub name { 'part' }

sub description_config { t8('Parts') }

sub description_field { t8('Parts') }

sub part_type { 'part' }

1;
