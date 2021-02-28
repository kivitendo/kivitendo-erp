package SL::Layout::MobileLogin;

use strict;
use parent qw(SL::Layout::Base);
use SL::Layout::MaterialStyle;
use SL::Layout::MaterialMenu;

sub get_stylesheet_for_user {
  # overwrite kivitendo fallback
  'css/material';
}

sub webpages_path {
  "templates/mobile_webpages"
}

sub init_sub_layouts {
  [
    SL::Layout::None->new,
    SL::Layout::MaterialStyle->new,
    SL::Layout::MaterialMenu->new,
  ]
}

1;
