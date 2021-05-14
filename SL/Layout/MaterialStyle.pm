package SL::Layout::MaterialStyle;

use strict;
use parent qw(SL::Layout::Base);

sub static_stylesheets {
  "https://cdnjs.cloudflare.com/ajax/libs/materialize/1.0.0/css/materialize.min.css",
  "https://fonts.googleapis.com/icon?family=Material+Icons";
}

sub static_javascripts {
  "https://cdnjs.cloudflare.com/ajax/libs/materialize/1.0.0/js/materialize.min.js",
  "kivi.Materialize.js";
}

sub javascripts_inline {
  "kivi.Materialize.init();"
}

sub get_stylesheet_for_user {
  # overwrite kivitendo fallback
  'css/material';
}

1;
