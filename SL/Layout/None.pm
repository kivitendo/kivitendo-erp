package SL::Layout::None;

use strict;
use parent qw(SL::Layout::Base);

use List::MoreUtils qw(apply);

sub javascripts_inline {
  my ($self)  = @_;

  my $datefmt = apply {
    s/d+/dd/gi;
    s/m+/mm/gi;
    s/y+/yy/gi;
  } $::myconfig{dateformat};

  return $self->presenter->render(
    'layout/javascript_setup',
    { type => 'js' },
    datefmt      => $datefmt,
    focus        => $::request->layout->focus,
    ajax_spinner => 1,
  );
}

sub static_javascripts {
  qw(
    jquery.js
    common.js
    namespace.js
    jquery-ui.js
    kivi.js
  ),
  'locale/'. $::myconfig{countrycode} .'.js',
}

sub static_stylesheets {
  qw(
    main.css
    menu.css
  ),
}

1;
