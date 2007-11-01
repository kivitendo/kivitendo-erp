#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
######################################################################
# SQL-Ledger Accounting
# Copyright (c) 1998-2002
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
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

use DBI;
use SL::User;
use SL::Form;

require "bin/mozilla/common.pl";

$form = new Form;

$locale = new Locale $language, "login";

# customization
if (-f "bin/mozilla/custom_$form->{script}") {
  eval { require "bin/mozilla/custom_$form->{script}"; };
  $form->error($@) if ($@);
}

# per login customization
if (-f "bin/mozilla/$form->{login}_$form->{script}") {
  eval { require "bin/mozilla/$form->{login}_$form->{script}"; };
  $form->error($@) if ($@);
}

# window title bar, user info
$form->{titlebar} = "Lx-Office " . $locale->text('Version') . " $form->{version}";

if ($form->{action}) {
  $form->{titlebar} .= " - $myconfig{name} - $myconfig{dbname}";
  call_sub($locale->findsub($form->{action}));

} else {
  login_screen();
}

1;

sub login_screen {
  $lxdebug->enter_sub();

  if (-f "css/lx-office-erp.css") {
    $form->{stylesheet} = "lx-office-erp.css";
  }

  $form->{fokus} = "loginscreen.login";
  $form->header;

  print $form->parse_html_template('login/login_screen');

  $lxdebug->leave_sub();
}

sub login {
  $lxdebug->enter_sub();

  $form->error($locale->text('You did not enter a name!')) unless ($form->{login});

  $user = new User $memberfile, $form->{login};

  # if we get an error back, bale out
  if (($result = $user->login(\%$form, $userspath)) <= -1) {
    if ($result == -2) {
      exit;
    }

    $form->error($locale->text('Incorrect username or password!'));
  }

  my %style_to_script_map = ( 'v3'  => 'v3',
                              'neu' => 'new',
                              'xml' => 'XML',
    );

  my $menu_script = $style_to_script_map{$user->{menustyle}} || '';

  # made it this far, execute the menu
  $form->{callback} = build_std_url("script=menu${menu_script}.pl", 'action=display');

  $form->redirect();

  $lxdebug->leave_sub();
}

sub logout {
  $lxdebug->enter_sub();

  unlink "$userspath/$form->{login}.conf";

  # remove the callback to display the message
  $form->{callback} = "login.pl?action=&login=";
  $form->redirect($locale->text('You are logged out!'));

  $lxdebug->leave_sub();
}

sub company_logo {
  $lxdebug->enter_sub();

  require "$userspath/$form->{login}.conf";

  $locale             =  new Locale $myconfig{countrycode}, "login" if ($language ne $myconfig{countrycode});

  $form->{stylesheet} =  $myconfig{stylesheet};
  $form->{title}      =  $locale->text('About');

  # create the logo screen
  $form->header() unless $form->{noheader};

  print $form->parse_html_template('login/company_logo');

  $lxdebug->leave_sub();
}
