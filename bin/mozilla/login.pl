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

use SL::DB::Default;
use SL::Form;
use SL::Git;
use DateTime;

require "bin/mozilla/common.pl";
require "bin/mozilla/todo.pl";

use strict;

our $form;
our $auth;

sub company_logo {
  $main::lxdebug->enter_sub();

  my %myconfig = %main::myconfig;
  $form->{todo_list}  =  create_todo_list('login_screen' => 1) if (!$form->{no_todo_list}) and ($main::auth->check_right($::myconfig{login}, 'productivity'));

  $form->{stylesheet} =  $myconfig{stylesheet};
  $form->{title}      =  $::locale->text('kivitendo');
  $form->{interface}  = $::dispatcher->interface_type;
  $form->{client}     = $::auth->client;
  $form->{defaults}   = SL::DB::Default->get;

  my $git             = SL::Git->new;
  ($form->{git_head}) = $git->get_log(since => 'HEAD~1', until => 'HEAD') if $git->is_git_installation;
  $form->{xmas}       = '_xmas' if (DateTime->today->month == 12 && DateTime->today->day < 27);

  # create the logo screen
  $form->header() unless $form->{noheader};

  print $form->parse_html_template('login/company_logo', { version => $::form->read_version });

  $main::lxdebug->leave_sub();
}

1;

__END__
