package SL::Layout::Material;

use strict;
use parent qw(SL::Layout::Base);

use SL::Layout::None;
use SL::Layout::MaterialMenu;
use SL::Layout::MaterialStyle;
use SL::Layout::Flash;
use SL::Layout::Content;

sub get_stylesheet_for_user {
  # overwrite kivitendo fallback
  'css/material';
}

sub webpages_path {
  "templates/mobile_webpages";
}

sub webpages_fallback_path {
  "templates/design40_webpages";
}

sub init_sub_layouts {
  [
    SL::Layout::None->new,
    SL::Layout::MaterialStyle->new,
    SL::Layout::MaterialMenu->new,
    SL::Layout::Flash->new,
    SL::Layout::Content->new,
  ]
}

1;
