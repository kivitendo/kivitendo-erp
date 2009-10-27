#!/usr/bin/perl
#
######################################################################
# SQL-Ledger Accounting
# Copyright (C) 2001
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
#  Contributors:
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#######################################################################
#
# this script is the frontend called from bin/$terminal/$script
# all the accounting modules are linked to this script which in
# turn execute the same script in bin/$terminal/
#
#######################################################################

use strict;

use Time::HiRes qw(gettimeofday tv_interval);

my $time;

BEGIN {
  unshift @INC, "modules/override"; # Use our own versions of various modules (e.g. YAML).
  push    @INC, "modules/fallback"; # Only use our own versions of modules if there's no system version.

  $time = [gettimeofday];
}

# setup defaults, DO NOT CHANGE
$main::userspath  = "users";
$main::templates  = "templates";
$main::memberfile = "users/members";
$main::sendmail   = "| /usr/sbin/sendmail -t";
########## end ###########################################

$| = 1;

use SL::LXDebug;
$main::lxdebug = LXDebug->new();

use CGI qw( -no_xhtml);
use SL::Auth;
use SL::Form;
use SL::Locale;

eval { require "config/lx-erp.conf"; };
eval { require "config/lx-erp-local.conf"; } if -f "config/lx-erp-local.conf";

our $cgi  = new CGI('');
our $form = new Form;

our $auth = SL::Auth->new();
if (!$auth->session_tables_present()) {
  _show_error('login/auth_db_unreachable');
}
$auth->expire_sessions();
my $session_result = $auth->restore_session();

require "bin/mozilla/common.pl";

if (defined($main::latex) && !defined($main::latex_templates)) {
  $main::latex_templates = $main::latex;
  undef($main::latex);
}

# this prevents most of the tabindexes being created by CGI.
# note: most. popup menus and selecttables will still have tabindexes
# use common.pl's NTI function to get rid of those
local $CGI::TABINDEX = 0;

# name of this script
$0 =~ tr/\\/\//;
my $pos = rindex $0, '/';
my $script = substr($0, $pos + 1);

# we use $script for the language module
$form->{script} = $script;

# strip .pl for translation files
$script =~ s/\.pl//;

# pull in DBI
use DBI;

# locale messages
$main::locale = new Locale($main::language, "$script");
my $locale = $main::locale;

# did sysadmin lock us out
if (-e "$main::userspath/nologin") {
  $form->error($locale->text('System currently down for maintenance!'));
}

if (SL::Auth::SESSION_EXPIRED == $session_result) {
  _show_error('login/password_error', 'session');
}

$form->{login} =~ s|.*/||;

%main::myconfig = $auth->read_user($form->{login});
my %myconfig = %main::myconfig;

if (!$myconfig{login}) {
  _show_error('login/password_error', 'password');
}

# locale messages
$locale = new Locale "$myconfig{countrycode}", "$script";

if (SL::Auth::OK != $auth->authenticate($form->{login}, $form->{password}, 0)) {
  _show_error('login/password_error', 'password');
}

$auth->set_session_value('login', $form->{login}, 'password', $form->{password});
$auth->create_or_refresh_session();

delete $form->{password};

map { $form->{$_} = $myconfig{$_} } qw(stylesheet charset)
  unless (($form->{action} eq 'save') && ($form->{type} eq 'preferences'));

# pull in the main code
require "bin/mozilla/$form->{script}";

# customized scripts
if (-f "bin/mozilla/custom_$form->{script}") {
  eval { require "bin/mozilla/custom_$form->{script}"; };
  $form->error($@) if ($@);
}

# customized scripts for login
if (-f "bin/mozilla/$form->{login}_$form->{script}") {
  eval { require "bin/mozilla/$form->{login}_$form->{script}"; };
  $form->error($@) if ($@);
}

if ($form->{action}) {

  # window title bar, user info
  $form->{titlebar} =
      "Lx-Office "
    . $locale->text('Version')
    . " $form->{version} - $myconfig{name} - $myconfig{dbname}";

  call_sub($locale->findsub($form->{action}));
} else {
  $form->error($locale->text('action= not defined!'));
}

sub _show_error {
  my $template           = shift;
  my $error_type         = shift;
  my $locale                = Locale->new($main::language, 'all');
  $form->{error}         = $locale->text('The session is invalid or has expired.') if ($error_type eq 'session');
  $form->{error}         = $locale->text('Incorrect password!.')                   if ($error_type eq 'password');
  $myconfig{countrycode} = $main::language;
  $form->{stylesheet}    = 'css/lx-office-erp.css';

  $form->header();
  print $form->parse_html_template($template);
  exit;
}

END {
  print "<!-- time elapsed: ", tv_interval($time), "s -->";
}
# end

