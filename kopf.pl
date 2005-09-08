#!/usr/bin/perl
#

use SL::LXDebug;
$lxdebug = LXDebug->new();

use SL::Form;

eval { require "lx-erp.conf"; };

$form = new Form;

eval { require("$userspath/$form->{login}.conf"); };

$locale = new Locale "$myconfig{countrycode}", "kopf";

eval { require "bin/mozilla/kopf.pl"; };
