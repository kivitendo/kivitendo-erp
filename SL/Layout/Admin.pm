package SL::Layout::Admin;

use strict;
use parent qw(SL::Layout::Design40Switch);

use SL::Menu;
use SL::Layout::None;
use SL::Layout::Top;
use SL::Layout::CssMenu;
use SL::Layout::Flash;

sub init_sub_layouts {
  $_[0]->sub_layouts_by_name->{flash}     = SL::Layout::Flash->new;

  [
    SL::Layout::None->new,
    SL::Layout::CssMenu->new(menu => SL::Menu->new('admin')),
    $_[0]->sub_layouts_by_name->{flash},
  ]
}

sub start_content {
  "<div id='admin' class='admin'>\n";
}

sub end_content {
  "</div>\n";
}


1;
