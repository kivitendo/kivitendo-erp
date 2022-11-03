package SL::Layout::Admin;

use strict;
use parent qw(SL::Layout::Design40Switch);

use SL::Menu;
use SL::Layout::None;
use SL::Layout::Top;
use SL::Layout::CssMenu;

sub init_sub_layouts {
  [
    SL::Layout::None->new,
    SL::Layout::CssMenu->new(menu => SL::Menu->new('admin')),
  ]
}

sub start_content {
  "<div id='admin' class='admin'>\n";
}

sub end_content {
  "</div>\n";
}


1;
