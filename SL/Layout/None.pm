package SL::Layout::None;

use strict;
use parent qw(SL::Layout::Base);

sub javascripts_inline {
  _setup_formats(),
  _setup_focus(),
}


sub _setup_formats {
  $::form->parse_html_template('generic/javascript_setup')
}

sub _setup_focus {
  if ($::request->{layout}->focus || $::form->{fokus}) {
    return $::form->parse_html_template('generic/focus_setup', {
      focus => $::request->{layout}->focus,
      fokus => $::form->{fokus},
    })
  } else {
    return ();
  }
}

1;
