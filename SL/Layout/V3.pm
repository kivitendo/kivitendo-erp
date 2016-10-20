package SL::Layout::V3;

use strict;
use parent qw(SL::Layout::Base);

use SL::Layout::None;
use SL::Layout::Top;
use SL::Layout::CssMenu;
use SL::Layout::ActionBar;
use SL::Layout::Content;

sub init_sub_layouts {
  $_[0]->sub_layouts_by_name->{actionbar} = SL::Layout::ActionBar->new;

  [
    SL::Layout::None->new,
    SL::Layout::Top->new,
    SL::Layout::CssMenu->new,
    $_[0]->sub_layouts_by_name->{actionbar},
    SL::Layout::Content->new,
  ]
}


1;
