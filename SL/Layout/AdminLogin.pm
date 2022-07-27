package SL::Layout::AdminLogin;

use strict;
use parent qw(SL::Layout::Design40Switch);

sub start_content {
  "<div id='admin' class='admin'>\n";
}

sub end_content {
  "</div>\n";
}

1;
