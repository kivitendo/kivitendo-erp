#!/usr/bin/perl

use strict;

BEGIN {
  use FindBin;

  unshift(@INC, $FindBin::Bin . '/modules/override'); # Use our own versions of various modules (e.g. YAML).
  push   (@INC, $FindBin::Bin);                       # '.' will be removed from @INC soon.
}

use SL::Dispatcher;

our $dispatcher = SL::Dispatcher->new('CGI');
$dispatcher->pre_startup;
$dispatcher->handle_request;

1;
