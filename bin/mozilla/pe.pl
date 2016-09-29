#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
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
#======================================================================
#
# partsgroup administration
#
#======================================================================

use SL::PE;

require "bin/mozilla/common.pl";

use strict;

1;

# end of main

sub add {
  $::lxdebug->enter_sub;
  $::auth->assert('config');

  $::form->{title} = "Add";
  $::form->{callback} ||= "$::form->{script}?action=add&type=$::form->{type}";

  call_sub("form_$::form->{type}");

  $::lxdebug->leave_sub;
}

sub edit {
  $::lxdebug->enter_sub;
  $::auth->assert('config');

  $::form->{title} = "Edit";

  if ($::form->{type} eq 'partsgroup') {
    PE->get_partsgroup(\%::myconfig, $::form);
  }
  call_sub("form_$::form->{type}");

  $::lxdebug->leave_sub;
}

sub search {
  $::lxdebug->enter_sub;
  $::auth->assert('config');

  $::form->header;
  print $::form->parse_html_template('pe/search', {
    is_pricegroup => $::form->{type} eq 'pricegroup',
  });

  $::lxdebug->leave_sub;
}

sub save {
  $::lxdebug->enter_sub;
  $::auth->assert('config');

  if ($::form->{type} eq 'partsgroup') {
    $::form->isblank("partsgroup", $::locale->text('Group missing!'));
    PE->save_partsgroup(\%::myconfig, $::form);
    $::form->redirect($::locale->text('Group saved!'));
  }

  # saving the history
  if(!exists $::form->{addition} && $::form->{id} ne "") {
    $::form->{snumbers} = qq|projectnumber_| . $::form->{projectnumber};
    $::form->{addition} = "SAVED";
    $::form->save_history;
  }
  # /saving the history

  $::lxdebug->leave_sub;
}

sub delete {
  $::lxdebug->enter_sub;
  $::auth->assert('config');

  PE->delete_tuple(\%::myconfig, $::form);

  if ($::form->{type} eq 'partsgroup') {
    $::form->redirect($::locale->text('Group deleted!'));
  }
  $::lxdebug->leave_sub;
}

sub continue { call_sub($::form->{nextsub}); }

sub partsgroup_report {
  $::lxdebug->enter_sub;
  $::auth->assert('config');

  $::form->{$_} = $::form->unescape($::form->{$_}) for qw(partsgroup);
  PE->partsgroups(\%::myconfig, $::form);

  my $callback = build_std_url("action=partsgroup_report", qw(type status));

  my $option = '';
  $option .= $::locale->text('All')      if $::form->{status} eq 'all';
  $option .= $::locale->text('Orphaned') if $::form->{status} eq 'orphaned';

  if ($::form->{partsgroup}) {
    $callback .= "&partsgroup=$::form->{partsgroup}";
    $option   .= ", " . $::locale->text('Group') . " : $::form->{partsgroup}";
  }

  # escape callback
  $::form->{callback} = $callback;

  $::form->header;
  print $::form->parse_html_template('pe/partsgroup_report', {
    option   => $option,
    callback => $callback,
    editlink => build_std_url('action=edit', qw(type status callback)),
  });

  $::lxdebug->leave_sub;
}

sub form_partsgroup {
  $::lxdebug->enter_sub;
  $::auth->assert('config');

  # $locale->text('Add Group')
  # $locale->text('Edit Group')
  $::form->{title} = $::locale->text("$::form->{title} Group");

  $::form->header;
  print $::form->parse_html_template('pe/partsgroup_form');

  $::lxdebug->leave_sub;
}
