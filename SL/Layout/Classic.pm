package SL::Layout::Classic;

use strict;
use parent qw(SL::Layout::Base);

use SL::Layout::Top;
use SL::Layout::MenuLeft;
use SL::Layout::None;

sub init_sub_layouts {
  [
    SL::Layout::None->new,
    SL::Layout::Top->new,
    SL::Layout::MenuLeft->new,
  ]
}

1;
