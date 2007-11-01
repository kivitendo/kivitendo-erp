#!/usr/bin/perl
#

BEGIN {
  unshift @INC, "modules/override"; # Use our own versions of various modules (e.g. YAML).
  push    @INC, "modules/fallback"; # Only use our own versions of modules if there's no system version.
}

use SL::LXDebug;
$lxdebug = LXDebug->new();

use SL::Form;
use SL::Locale;

eval { require "lx-erp.conf"; };

$form = new Form;

eval { require("$userspath/$form->{login}.conf"); };

$locale = new Locale "$myconfig{countrycode}", "kopf";

eval { require "bin/mozilla/kopf.pl"; };
