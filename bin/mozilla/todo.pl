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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1335, USA.
#######################################################################

use SL::TODO;

use strict;

sub create_todo_list {
  $main::lxdebug->enter_sub();

  $main::auth->assert('productivity');

  my $form     = $main::form;

  my %params   = @_;
  my $postfix  = $params{login_screen} ? '_login' : '';

  my %todo_cfg = TODO->get_user_config('login' => $::myconfig{login});

  if ($params{login_screen} && !$todo_cfg{show_after_login}) {
    $main::lxdebug->leave_sub();
    return '';
  }

  my (@todo_items, $todo_list);

  push @todo_items, todo_list_follow_ups()               if ($todo_cfg{"show_follow_ups${postfix}"});
  push @todo_items, todo_list_overdue_sales_quotations() if ($todo_cfg{"show_overdue_sales_quotations${postfix}"});

  @todo_items = grep { $_ } @todo_items;
  $todo_list  = join("", @todo_items);

  $main::lxdebug->leave_sub();

  return $todo_list;
}

sub show_todo_list {
  $main::lxdebug->enter_sub();

  $main::auth->assert('productivity');

  my $form     = $main::form;
  my $locale   = $main::locale;

  $form->{todo_list} = create_todo_list();
  $form->{title}     = $locale->text('TODO list');

  $form->header();
  print $form->parse_html_template('todo/show_todo_list');

  $main::lxdebug->leave_sub();
}

sub todo_list_follow_ups {
  $main::lxdebug->enter_sub();

  $main::auth->assert('productivity');

  require "bin/mozilla/fu.pl";

  my $content = report_for_todo_list();

  $main::lxdebug->leave_sub();

  return $content;
}

sub todo_list_overdue_sales_quotations {
  $main::lxdebug->enter_sub();

  $main::auth->assert('productivity');

  require "bin/mozilla/oe.pl";

  my $content = report_for_todo_list();

  $main::lxdebug->leave_sub();

  return $content;
}

1;
