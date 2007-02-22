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

BEGIN {
  push(@INC, "modules");
}

# setup defaults, DO NOT CHANGE
$userspath  = "users";
$templates  = "templates";
$memberfile = "users/members";
$sendmail   = "| /usr/sbin/sendmail -t";
########## end ###########################################

$| = 1;

use SL::LXDebug;
$lxdebug = LXDebug->new();

use CGI;
use SL::Form;
use SL::Locale;

eval { require "lx-erp.conf"; };

if (defined($latex) && !defined($latex_templates)) {
  $latex_templates = $latex;
  undef($latex);
}

$form = new Form;
$cgi = new CGI('');

# name of this script
$0 =~ tr/\\/\//;
$pos = rindex $0, '/';
$script = substr($0, $pos + 1);

# we use $script for the language module
$form->{script} = $script;

# strip .pl for translation files
$script =~ s/\.pl//;

# pull in DBI
use DBI;

# check for user config file, could be missing or ???
eval { require("$userspath/$form->{login}.conf"); };
if ($@) {
  $locale = new Locale "$language", "$script";

  $form->{callback} = "";
  $msg1             = $locale->text('You are logged out!');
  $msg2             = $locale->text('Login');
  $form->redirect("$msg1 <p><a href=login.pl target=_top>$msg2</a>");
}

$myconfig{dbpasswd} = unpack 'u', $myconfig{dbpasswd};
map { $form->{$_} = $myconfig{$_} } qw(stylesheet charset)
  unless (($form->{action} eq 'save') && ($form->{type} eq 'preferences'));

# locale messages
$locale = new Locale "$myconfig{countrycode}", "$script";

# check password
$form->error($locale->text('Incorrect Password!'))
  if ($form->{password} ne $myconfig{password});

$form->{path} =~ s/\.\.\///g;
if ($form->{path} !~ /^bin\//) {
  $form->error($locale->text('Invalid path!') . "\n");
}

# did sysadmin lock us out
if (-e "$userspath/nologin") {
  $form->error($locale->text('System currently down for maintenance!'));
}

# pull in the main code
require "$form->{path}/$form->{script}";

# customized scripts
if (-f "$form->{path}/custom_$form->{script}") {
  eval { require "$form->{path}/custom_$form->{script}"; };
  $form->error($@) if ($@);
}

# customized scripts for login
if (-f "$form->{path}/$form->{login}_$form->{script}") {
  eval { require "$form->{path}/$form->{login}_$form->{script}"; };
  $form->error($@) if ($@);
}

if ($form->{action}) {

  # window title bar, user info
  $form->{titlebar} =
      "Lx-Office "
    . $locale->text('Version')
    . " $form->{version} - $myconfig{name} - $myconfig{dbname}";

  &{ $locale->findsub($form->{action}) };
} else {
  $form->error($locale->text('action= not defined!'));
}

# end

