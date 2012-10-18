package SL::Layout::Admin;

use strict;
use parent qw(SL::Layout::Base);

sub init_sub_layouts {
  [ SL::Layout::None->new ]
}

sub start_content {
  "<div id='admin' class='admin'>\n";
}

sub end_content {
  "</div>\n";
}

1;
