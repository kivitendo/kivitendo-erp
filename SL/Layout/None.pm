package SL::Layout::None;

use strict;
use parent qw(SL::Layout::Base);

sub javascripts_inline {
  _setup_formats(),
  _setup_focus(),
}

sub use_javascript {
  my $self = shift;
  qw(
    js/jquery.js
    js/common.js
  ),
  $self->SUPER::use_javascript(@_);
}

sub use_stylesheet {
  my $self = shift;
  qw(
    main.css
    menu.css
  ),
  $self->SUPER::use_stylesheet(@_);
}

sub _setup_formats {
  $::form->parse_html_template('layout/javascript_setup')
}

sub _setup_focus {
  if ($::request->{layout}->focus) {
    return $::form->parse_html_template('layout/focus_setup', {
      focus => $::request->{layout}->focus,
    })
  } else {
    return ();
  }
}

1;
