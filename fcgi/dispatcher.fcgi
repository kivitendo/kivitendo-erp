#!/usr/bin/perl

use strict;

BEGIN {
  use FindBin;

  unshift(@INC, $FindBin::Bin . '/modules/override'); # Use our own versions of various modules (e.g. YAML).
  push   (@INC, $FindBin::Bin);                       # '.' will be removed from @INC soon.
  push   (@INC, $FindBin::Bin . '/modules/fallback'); # Only use our own versions of modules if there's no system version.
}

use SL::Dispatcher;
use SL::FCGIFixes;
use SL::LXDebug;

our $dispatcher = SL::Dispatcher->new('FastCGI');
$dispatcher->pre_startup_setup;
SL::FCGIFixes::apply_fixes();
$dispatcher->pre_startup_checks;
$dispatcher->handle_all_requests;

1;
