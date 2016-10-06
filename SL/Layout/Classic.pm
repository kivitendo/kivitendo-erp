package SL::Layout::Classic;

use strict;
use parent qw(SL::Layout::Base);

use SL::Layout::Top;
use SL::Layout::MenuLeft;
use SL::Layout::None;
use SL::Layout::Split;
use SL::Layout::ActionBar;
use SL::Layout::Content;

sub init_sub_layouts {
  $_[0]->sub_layouts_by_name->{actionbar} = SL::Layout::ActionBar->new;

  [
    SL::Layout::None->new,
    SL::Layout::Top->new,
    SL::Layout::Split->new(
      left  => [ SL::Layout::MenuLeft->new ],
      right => [ $_[0]->sub_layouts_by_name->{actionbar}, SL::Layout::Content->new ],
    )
  ]
}

1;
