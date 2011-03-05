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

use strict;

our $cgi;
our $form;
our $auth;

sub run {
  $::lxdebug->enter_sub;
  my $session_result = shift;

  $cgi    = $::cgi;
  $form   = $::form;
  $auth   = $::auth;

  $form->{stylesheet} = "lx-office-erp.css";
  $form->{favicon}    = "favicon.ico";

  if (SL::Auth::SESSION_EXPIRED == $session_result) {
    $form->{error_message} = $::locale->text('The session is invalid or has expired.');
    login_screen();
    ::end_of_request();
  }
  my $action = $form->{action};
  if (!$action && $auth->{SESSION}->{login}) {
    $action = 'login';
  }
  if ($action) {
    %::myconfig = $auth->read_user($form->{login}) if ($form->{login});
    $::locale   = Locale->new($::myconfig{countrycode}) if $::myconfig{countrycode};

    if (SL::Auth::OK != $auth->authenticate($::myconfig{login}, $form->{password})) {
      $form->{error_message} = $::locale->text('Incorrect username or password!');
      login_screen();
    } else {
      $auth->set_session_value('login', $form->{login}, 'password', $form->{password});
      $auth->create_or_refresh_session();

      $form->{titlebar} .= " - $::myconfig{name} - $::myconfig{dbname}";
      call_sub($::locale->findsub($action));
    }
  } else {
    login_screen();
  }

  $::lxdebug->leave_sub;
}

sub login_screen {
  $main::lxdebug->enter_sub();
  my ($msg) = @_;

  if (-f "css/lx-office-erp.css") {
    $form->{stylesheet} = "lx-office-erp.css";
  }

  $form->{msg} = $msg;
  $form->header();

  print $form->parse_html_template('login/login_screen');

  $main::lxdebug->leave_sub();
}

sub login {
  $main::lxdebug->enter_sub();

  unless ($form->{login}) {
    login_screen($::locale->text('You did not enter a name!'));
    ::end_of_request();
  }

  my $user = new User $form->{login};

  # if we get an error back, bale out
  my $result;
  if (($result = $user->login($form)) <= -1) {
    ::end_of_request() if $result == -2;
    login_screen($::locale->text('Incorrect username or password!'));
    ::end_of_request();
  }

  my %style_to_script_map = ( 'v3'  => 'v3',
                              'neu' => 'new',
                              'v4' => 'v4',
                              'xml' => 'XML',
    );

  my $menu_script = $style_to_script_map{$user->{menustyle}} || '';

  # made it this far, execute the menu
  # standard redirect does not seem to work for this invocation, (infinite loops?)
  # do a manual invocation instead
#  $form->{callback} = build_std_url("script=menu${menu_script}.pl", 'action=display', "callback=" . $form->escape($form->{callback}));

  $main::auth->set_cookie_environment_variable();

  $::form->{script}   = "menu${menu_script}.pl";
  $::form->{action}   = 'display';
  $::form->{callback} = $::form->escape($::form->{callback});

  require "bin/mozilla/$::form->{script}";
  display();

#  $form->redirect();

  $main::lxdebug->leave_sub();
}

sub logout {
  $main::lxdebug->enter_sub();

  $main::auth->destroy_session();

  # remove the callback to display the message
  $form->{callback} = "login.pl?action=";
  $form->redirect($::locale->text('You are logged out!'));

  $main::lxdebug->leave_sub();
}

sub company_logo {
  $main::lxdebug->enter_sub();

  my %myconfig = %main::myconfig;
  $form->{todo_list}  =  create_todo_list('login_screen' => 1) if (!$form->{no_todo_list});

  $form->{stylesheet} =  $myconfig{stylesheet};
  $form->{title}      =  $::locale->text('Lx-Office');
  $form->{interface}  = $::dispatcher->interface_type;

  # create the logo screen
  $form->header() unless $form->{noheader};

  print $form->parse_html_template('login/company_logo');

  $main::lxdebug->leave_sub();
}

sub show_error {
  my $template           = shift;
  my %myconfig           = %main::myconfig;
  $myconfig{countrycode} = $::lx_office_conf{system}->{language};
  $form->{stylesheet}    = 'css/lx-office-erp.css';

  $form->header();
  print $form->parse_html_template($template);

  # $form->parse_html_template('login/auth_db_unreachable');
  # $form->parse_html_template('login/authentication_pl_missing');

  ::end_of_request();
}

1;

__END__
