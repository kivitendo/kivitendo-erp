package SL::Layout::Classic;

use strict;
use parent qw(SL::Layout::Base);

use SL::Layout::Top;
use SL::Layout::MenuLeft;
use SL::Layout::None;
use SL::Layout::Split;
use SL::Layout::Content;

sub init_sub_layouts {
  [
    SL::Layout::None->new,
    SL::Layout::Top->new,
    SL::Layout::Split->new(
      left  => [ SL::Layout::MenuLeft->new ],
      right => [ SL::Layout::Content->new ],
    )
  ]
}

1;
