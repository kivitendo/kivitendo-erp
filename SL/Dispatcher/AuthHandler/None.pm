package SL::Dispatcher::AuthHandler::None;

use strict;

use parent qw(Rose::Object);

sub handle {
  %::myconfig = ();
  return 1;
}

1;
