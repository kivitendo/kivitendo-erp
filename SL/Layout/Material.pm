package SL::Layout::Material;

use strict;
use parent qw(SL::Layout::Base);

use SL::Layout::None;
use SL::Layout::MaterialMenu;
use SL::Layout::MaterialStyle;
use SL::Layout::Content;

sub get_stylesheet_for_user {
  # overwrite kivitendo fallback
  'css/material';
}

sub init_sub_layouts {
  [
    SL::Layout::None->new,
    SL::Layout::MaterialStyle->new,
    SL::Layout::MaterialMenu->new,
    SL::Layout::Content->new,
  ]
}

1;
