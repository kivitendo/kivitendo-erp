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
use SL::Auth;
use SL::User;
use SL::Form;

require "bin/mozilla/common.pl";
require "bin/mozilla/todo.pl";

# This is required because the am.pl in the root directory
# is not scanned by locales.pl:
# $form->parse_html_template('login/password_error')

$form = new Form;

if (! -f 'config/authentication.pl') {
  show_error('login/authentication_pl_missing');
}

$locale = new Locale $language, "login";

our $auth = SL::Auth->new();
if (!$auth->session_tables_present()) {
  show_error('login/auth_db_unreachable');
}
$auth->expire_sessions();
my $session_result = $auth->restore_session();

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

if (SL::Auth::SESSION_EXPIRED == $session_result) {
  $form->{error_message} = $locale->text('The session is invalid or has expired.');
  login_screen();
  exit;
}

my $action = $form->{action};

if (!$action && $auth->{SESSION}->{login}) {
  $action = 'login';
}

if ($action) {
  our %myconfig = $auth->read_user($form->{login}) if ($form->{login});

  if (!$myconfig{login} || (SL::Auth::OK != $auth->authenticate($form->{login}, $form->{password}, 0))) {
    $form->{error_message} = $locale->text('Incorrect Password!');
    login_screen();
    exit;
  }

  $auth->set_session_value('login', $form->{login}, 'password', $form->{password});
  $auth->create_or_refresh_session();

  $form->{titlebar} .= " - $myconfig{name} - $myconfig{dbname}";
  call_sub($locale->findsub($action));

} else {
  login_screen();
}

1;

sub login_screen {
  $lxdebug->enter_sub();
  my ($msg) = @_;

  if (-f "css/lx-office-erp.css") {
    $form->{stylesheet} = "lx-office-erp.css";
  }

  $form->{msg} = $msg;
  $form->header();

  print $form->parse_html_template('login/login_screen');

  $lxdebug->leave_sub();
}

sub login {
  $lxdebug->enter_sub();

  unless ($form->{login}) {
    login_screen($locale->text('You did not enter a name!'));
    exit;
  }

  $user = new User $form->{login};

  # if we get an error back, bale out
  if (($result = $user->login($form)) <= -1) {
    exit if $result == -2;
    login_screen($locale->text('Incorrect username or password!'));
    exit;
  }

  my %style_to_script_map = ( 'v3'  => 'v3',
                              'neu' => 'new',
                              'xml' => 'XML',
    );

  my $menu_script = $style_to_script_map{$user->{menustyle}} || '';

  # made it this far, execute the menu
  $form->{callback} = build_std_url("script=menu${menu_script}.pl", 'action=display');

  $auth->set_cookie_environment_variable();

  $form->redirect();

  $lxdebug->leave_sub();
}

sub logout {
  $lxdebug->enter_sub();

  $auth->destroy_session();

  # remove the callback to display the message
  $form->{callback} = "login.pl?action=";
  $form->redirect($locale->text('You are logged out!'));

  $lxdebug->leave_sub();
}

sub company_logo {
  $lxdebug->enter_sub();

  $locale             =  new Locale $myconfig{countrycode}, "login" if ($language ne $myconfig{countrycode});

  $form->{todo_list}  =  create_todo_list('login_screen' => 1) if (!$form->{no_todo_list});

  $form->{stylesheet} =  $myconfig{stylesheet};
  $form->{title}      =  $locale->text('About');

  # create the logo screen
  $form->header() unless $form->{noheader};

  print $form->parse_html_template('login/company_logo');

  $lxdebug->leave_sub();
}

sub show_error {
  my $template           = shift;
  $locale                = Locale->new($language, 'all');
  $myconfig{countrycode} = $language;
  $form->{stylesheet}    = 'css/lx-office-erp.css';

  $form->header();
  print $form->parse_html_template($template);

  # $form->parse_html_template('login/auth_db_unreachable');
  # $form->parse_html_template('login/authentication_pl_missing');

  exit;
}

