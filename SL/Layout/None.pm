package SL::Layout::None;

use strict;
use parent qw(SL::Layout::Base);

use List::MoreUtils qw(apply);

sub javascripts_inline {
  _setup_formats(),
  _setup_focus(),
  _setup_ajax_spinner(),
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
  my $datefmt = apply {
    s/d+/dd/gi;
    s/m+/mm/gi;
    s/y+/yy/gi;
  } $::myconfig{dateformat};

  $::form->parse_html_template('layout/javascript_setup', { datefmt => $datefmt });
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

sub _setup_ajax_spinner {
  return SL::Presenter->get->render('layout/ajax_spinner_setup', { type => 'js' });
}

1;
