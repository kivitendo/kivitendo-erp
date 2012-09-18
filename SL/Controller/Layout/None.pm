package SL::Controller::Layout::None;

use strict;
use parent qw(SL::Controller::Layout::Base);

sub javascripts_inline {
  $::form->parse_html_template('generic/javascript_setup')
}

1;
