package SL::Layout::Javascript;

use strict;
use parent qw(SL::Layout::Design40Switch);

use SL::Layout::None;
use SL::Layout::DHTMLMenu;
use SL::Layout::Top;
use SL::Layout::ActionBar;
use SL::Layout::AsyncMsg;
use SL::Layout::Flash;
use SL::Layout::Content;

use List::Util qw(max);
use List::MoreUtils qw(uniq);
use URI;

sub init_sub_layouts {
  $_[0]->sub_layouts_by_name->{actionbar} = SL::Layout::ActionBar->new;
  $_[0]->sub_layouts_by_name->{flash}     = SL::Layout::Flash->new;
  $_[0]->sub_layouts_by_name->{asyncmsg}  = SL::Layout::AsyncMsg->new;
  [
    SL::Layout::None->new,
    SL::Layout::Top->new,
    SL::Layout::DHTMLMenu->new,
    $_[0]->sub_layouts_by_name->{actionbar},
    $_[0]->sub_layouts_by_name->{flash},
    $_[0]->sub_layouts_by_name->{asyncmsg},
    SL::Layout::Content->new,
  ]
}

1;
