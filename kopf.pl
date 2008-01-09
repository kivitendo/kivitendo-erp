#!/usr/bin/perl
#

BEGIN {
  unshift @INC, "modules/override"; # Use our own versions of various modules (e.g. YAML).
  push    @INC, "modules/fallback"; # Only use our own versions of modules if there's no system version.
}

use SL::LXDebug;
$lxdebug = LXDebug->new();

use SL::Auth;
use SL::Form;
use SL::Locale;

eval { require "config/lx-erp.conf"; };
eval { require "config/lx-erp-local.conf"; } if (-f "config/lx-erp-local.conf");

$form = new Form;

our $auth     = SL::Auth->new();
if (!$auth->session_tables_present()) {
  _show_error('login/auth_db_unreachable');
}
$auth->expire_sessions();
$auth->restore_session();

our %myconfig = $auth->read_user($form->{login});

$locale = new Locale "$myconfig{countrycode}", "kopf";

delete $form->{password};

eval { require "bin/mozilla/kopf.pl"; };
