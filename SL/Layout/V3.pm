package SL::Layout::V3;

use strict;
use parent qw(SL::Layout::Base);

use SL::Layout::None;
use SL::Layout::Top;
use SL::Layout::CssMenu;
use SL::Layout::Content;

sub init_sub_layouts {
  [
    SL::Layout::None->new,
    SL::Layout::Top->new,
    SL::Layout::CssMenu->new,
    SL::Layout::Content->new,
  ]
}


1;
