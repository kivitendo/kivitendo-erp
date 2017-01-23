#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (c) 2002
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
#======================================================================
#
# common routines for gl, ar, ap, is, ir, oe
#

use strict;

# any custom scripts for this one
if (-f "bin/mozilla/custom_arap.pl") {
  eval { require "bin/mozilla/custom_arap.pl"; };
}
if (-f "bin/mozilla/$::myconfig{login}_arap.pl") {
  eval { require "bin/mozilla/$::myconfig{login}_arap.pl"; };
}

1;

require "bin/mozilla/common.pl";

# end of main

sub select_project {
  $::lxdebug->enter_sub;

  $::auth->assert('ar_transactions | ap_transactions | vendor_invoice_edit  | sales_order_edit    | invoice_edit |' .
                  'request_quotation_edit | sales_quotation_edit | purchase_order_edit | cash         | report');

  my ($is_global, $nextsub) = @_;
  my $project_list = delete $::form->{project_list};

  map { delete $::form->{$_} } qw(action header update);

  my @hiddens;
  for my $key (keys %$::form) {
    next if $key eq 'login' || $key eq 'password' || '' ne ref $::form->{$key};
    push @hiddens, { key => $key, value => $::form->{$key} };
  }
  push @hiddens, { key => 'is_global',                value => $is_global },
                 { key => 'project_selected_nextsub', value => $nextsub };

  $::form->header;
  print $::form->parse_html_template('arap/select_project', { hiddens => \@hiddens, project_list => $project_list });

  $::lxdebug->leave_sub;
}

sub project_selected {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  $main::auth->assert('ar_transactions  | ap_transactions    | vendor_invoice_edit  | sales_order_edit    | invoice_edit |' .
                'request_quotation_edit | sales_quotation_edit | purchase_order_edit | cash         | report');

  # replace the variable with the one checked

  # index for new item
  my $i = $form->{ndx};

  my $prefix = $form->{"is_global"} ? "global" : "";
  my $suffix = $form->{"is_global"} ? "" : "_$form->{rownumber}";

  $form->{"${prefix}projectnumber${suffix}"} =
    $form->{"new_projectnumber_$i"};
  $form->{"old${prefix}projectnumber${suffix}"} =
    $form->{"new_projectnumber_$i"};
  $form->{"${prefix}project_id${suffix}"} = $form->{"new_id_$i"};

  # delete all the new_ variables
  for $i (1 .. $form->{lastndx}) {
    map { delete $form->{"new_${_}_$i"} } qw(id projectnumber description);
  }

  my $nextsub = $form->{project_selected_nextsub} || 'update';

  map { delete $form->{$_} } qw(ndx lastndx nextsub is_global project_selected_nextsub);

  call_sub($nextsub);

  $main::lxdebug->leave_sub();
}

sub continue       { call_sub($main::form->{"nextsub"}); }

1;

__END__

=head1 NAME

arap.pl - helper functions or customer/vendor retrieval

=head1 SYNOPSIS

 check_name('vendor')

=head1 DESCRIPTION

Don't use anyting in this file without extreme care, and even then be prepared for massive headaches.

It's a collection of helper routines that wrap the customer/vendor dropdown/textfield duality into something even complexer.

=cut
