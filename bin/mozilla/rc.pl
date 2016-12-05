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
# Account reconciliation module
#
#======================================================================

use SL::RC;

require "bin/mozilla/common.pl";

use strict;

1;

# end of main

sub reconciliation {
  $::lxdebug->enter_sub;
  $::auth->assert('cash');

  RC->paymentaccounts(\%::myconfig, $::form);

  $::form->header;
  print $::form->parse_html_template('rc/step1', {
    selection_sub => sub { ("$_[0]{accno}--$_[0]{description}")x2 },
  });

  $::lxdebug->leave_sub;
}

sub continue { call_sub($::form->{"nextsub"}); }

sub get_payments {
  $::lxdebug->enter_sub;
  $::auth->assert('cash');

  ($::form->{accno}, $::form->{account}) = split /--/, $::form->{accno};

  RC->payment_transactions(\%::myconfig, $::form);

  display_form();

  $::lxdebug->leave_sub;
}

sub display_form {
  $::lxdebug->enter_sub;
  $::auth->assert('cash');

  my @options;
  push @options, $::locale->text('From') . " " . $::locale->date(\%::myconfig, $::form->{fromdate}, 0) if $::form->{fromdate};
  push @options, $::locale->text('Until') . " " . $::locale->date(\%::myconfig, $::form->{todate}, 0) if $::form->{todate};

  my $ml = ($::form->{category} eq 'A') ? -1 : 1;
  my $beginningbalance = $::form->{beginningbalance} * $ml;
  my $clearedbalance   =
  my $balance          = $beginningbalance;
  my $i                = 0;
  my $last_id          = 0;
  my ($last_fx, @rows, $cleared, $totaldebits, $totalcredits, $fx);

  for my $ref (@{ $::form->{PR} }) {
    $balance      += $ref->{amount} * $ml;
    $cleared      += $ref->{amount} * $ml if $ref->{cleared};
    $totaldebits  += $ref->{amount} * -1  if $ref->{amount} < 0;
    $totalcredits += $ref->{amount}       if $ref->{amount} >= 0;
    $fx           += $ref->{amount} * $ml if $ref->{fx_transaction};
    $i++                                  if (!$ref->{fx_transaction} && !$last_fx) || $last_id != $ref->{id};
    $last_fx       = $ref->{fx_transaction};
    $last_id       = $ref->{id};

    push @rows, { %$ref, balance => $balance, i => $i };
  }

  my $statementbalance = $::form->parse_amount(\%::myconfig, $::form->{statementbalance});
  my $difference       = $statementbalance - $clearedbalance - $cleared;

  $::form->header;
  print $::form->parse_html_template('rc/step2', {
    is_asset         => $::form->{category} eq 'A',
    option           => \@options,
    DATA             => \@rows,
    total            => {
      credit => $totalcredits,
      debit  => $totaldebits,
    },
    balance          => {
      beginning => $beginningbalance,
      cleared   => $clearedbalance,
      statement => $statementbalance,
    },
    difference       => $difference,
    rowcount         => $i,
    fx               => $fx,
  });

  $::lxdebug->leave_sub;
}

sub update {
  $::lxdebug->enter_sub;
  $::auth->assert('cash');

  # reset difference as it doesn't always arrive here empty
  $::form->{difference} = 0;

  RC->payment_transactions(\%::myconfig, $::form);

  my $i;
  for my $ref (@{ $::form->{PR} }) {
    next if $ref->{fx_transaction};
    $i++;
    $ref->{cleared} = $::form->{"cleared_$i"};
  }

  display_form();

  $::lxdebug->leave_sub;
}

sub done {
  $::lxdebug->enter_sub;
  $::auth->assert('cash');

  $::form->{callback} = "$::form->{script}?action=reconciliation";

  $::form->error($::locale->text('Out of balance!')) if $::form->{difference} *= 1;

  RC->reconcile(\%::myconfig, $::form);
  $::form->redirect;

  $::lxdebug->leave_sub;
}

