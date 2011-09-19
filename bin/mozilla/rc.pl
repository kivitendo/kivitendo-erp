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
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
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

sub continue { call_sub($main::form->{"nextsub"}); }

sub get_payments {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $main::auth->assert('cash');

  ($form->{accno}, $form->{account}) = split /--/, $form->{accno};

  RC->payment_transactions(\%myconfig, \%$form);

  &display_form;

  $main::lxdebug->leave_sub();
}

sub display_form {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('cash');

  my @column_index = qw(cleared transdate source name credit debit balance);
  my %column_header;
  $column_header{cleared} = "<th>&nbsp;</th>";
  $column_header{source}  =
    "<th class=listheading>" . $locale->text('Source') . "</a></th>";
  $column_header{name} =
    "<th class=listheading>" . $locale->text('Description') . "</a></th>";
  $column_header{transdate} =
    "<th class=listheading>" . $locale->text('Date') . "</a></th>";

  if ($form->{category} eq 'A') {
    $column_header{debit} =
      "<th class=listheading>" . $locale->text('Deposit') . "</a></th>";
    $column_header{credit} =
      "<th class=listheading>" . $locale->text('Payment') . "</a></th>";
  } else {
    $column_header{debit} =
      "<th class=listheading>" . $locale->text('Decrease') . "</a></th>";
    $column_header{credit} =
      "<th class=listheading>" . $locale->text('Increase') . "</a></th>";
  }

  $column_header{balance} =
    "<th class=listheading>" . $locale->text('Balance') . "</a></th>";

  my $option;
  if ($form->{fromdate}) {
    $option .= "\n<br>" if ($option);
    $option .=
        $locale->text('From') . "&nbsp;"
      . $locale->date(\%myconfig, $form->{fromdate}, 0);
  }
  if ($form->{todate}) {
    $option .= "\n<br>" if ($option);
    $option .=
        $locale->text('Until') . "&nbsp;"
      . $locale->date(\%myconfig, $form->{todate}, 0);
  }

  $form->{title} = "$form->{accno}--$form->{account}";

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>$option</td>
  </tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>
|;

  map { print "\n$column_header{$_}" } @column_index;

  print qq|
        </tr>
|;

  my $ml = ($form->{category} eq 'A') ? -1 : 1;
  $form->{beginningbalance} *= $ml;
  my $balance        = $form->{beginningbalance};
  my $clearedbalance = $balance;
  my $i              = 0;
  my $id             = 0;

  my %column_data;
  map { $column_data{$_} = "<td>&nbsp;</td>" }
    qw(cleared transdate source name debit credit);
  $column_data{balance} =
    "<td align=right>"
    . $form->format_amount(\%myconfig, $balance, 2, 0) . "</td>";
  my $j = 0;
  print qq|
        <tr class=listrow$j>
|;

  map { print "\n$column_data{$_}" } @column_index;

  print qq|
        </tr>
|;

  my $cleared;
  my $totaldebits;
  my $totalcredits;
  my $fx_transaction;
  my $fx;
  foreach my $ref (@{ $form->{PR} }) {

    $balance += $ref->{amount} * $ml;
    $cleared += $ref->{amount} * $ml if $ref->{cleared};

    $column_data{name}   = "<td>$ref->{name}&nbsp;</td>";
    $column_data{source} = qq|<td>$ref->{source}&nbsp;</a>
    </td>|;
    $column_data{transdate} = "<td>$ref->{transdate}&nbsp;</td>";

    $column_data{debit}  = "<td>&nbsp;</td>";
    $column_data{credit} = "<td>&nbsp;</td>";

    if ($ref->{amount} < 0) {
      $totaldebits += $ref->{amount} * -1;
      $column_data{debit} =
          "<td align=right>"
        . $form->format_amount(\%myconfig, $ref->{amount} * -1, 2, "&nbsp;")
        . "</td>";
    } else {
      $totalcredits += $ref->{amount};
      $column_data{credit} =
          "<td align=right>"
        . $form->format_amount(\%myconfig, $ref->{amount}, 2, "&nbsp;")
        . "</td>";
    }

    $column_data{balance} =
      "<td align=right>"
      . $form->format_amount(\%myconfig, $balance, 2, 0) . "</td>";

    if ($ref->{fx_transaction}) {
      $i++ unless $id == $ref->{id};
      $fx_transaction = 1;
      $fx += $ref->{amount} * $ml;
      $column_data{cleared} = qq|<td align=center>&nbsp;
      <input type=hidden name="fxoid_$i" value=$ref->{oid}>
      </td>|;
    } else {
      $i++ unless ($fx_transaction && $id == $ref->{id});
      $fx_transaction = 0;
      $column_data{cleared} = qq|<td>
      <input name="cleared_$i" type=checkbox class=checkbox value=1 $ref->{cleared}>
      <input type=hidden name="oid_$i" value=$ref->{oid}>
      </td>|;
    }
    $id = $ref->{id};

    $j++;
    $j %= 2;
    print qq|
        <tr class=listrow$j>
|;

    map { print "\n$column_data{$_}" } @column_index;

    print qq|
        </tr>
|;

  }

  # print totals
  map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;

  $column_data{debit} =
    "<th class=listtotal align=right>"
    . $form->format_amount(\%myconfig, $totaldebits, 2, "&nbsp;") . "</th>";
  $column_data{credit} =
    "<th class=listtotal align=right>"
    . $form->format_amount(\%myconfig, $totalcredits, 2, "&nbsp;") . "</th>";

  print qq|
        <tr class=listtotal>
|;

  map { print "\n$column_data{$_}" } @column_index;

  $form->{statementbalance} =
    $form->parse_amount(\%myconfig, $form->{statementbalance});
  my $difference =
    $form->format_amount(\%myconfig,
                        $form->{statementbalance} - $clearedbalance - $cleared,
                        2, 0);

  $form->{statementbalance} =
    $form->format_amount(\%myconfig, $form->{statementbalance}, 2, 0);

  $clearedbalance = $form->format_amount(\%myconfig, $clearedbalance, 2, 0);

  my $exchdiff;
  if ($fx) {
    $fx       = $form->format_amount(\%myconfig, $fx, 2, 0);
    $exchdiff = qq|
          <th align=right nowrap>| . $locale->text('Exchangerate Difference') . qq|</th>
          <td width=10%></td>
          <td align=right>$fx</td>
|;
  }

  print qq|
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td>
      <table width=100%>
        <tr valign=top>
          <td>
            <table>
              <tr>
                <th align=right nowrap>| . $locale->text('Cleared Balance') . qq|</th>
                <td width=10%></td>
                <td align=right>$clearedbalance</td>
              </tr>
              <tr>
                $exchdiff
              </tr>
            </table>
          </td>
          <td align=right>
            <table>
              <tr>
                <th align=right nowrap>| . $locale->text('Statement Balance') . qq|</th>
                <td width=10%></td>
                <td align=right><input name=statementbalance size=11 value=$form->{statementbalance}></td>
              </tr>
              <tr>
                <th align=right nowrap>| . $locale->text('Difference') . qq|</th>
                <td width=10%></td>
                <td align=right><input name=null size=11 value=$difference></td>
                <input type=hidden name=difference value=$difference>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<input type=hidden name=rowcount value=$i>
<input type=hidden name=accno value=$form->{accno}>
<input type=hidden name=account value="$form->{account}">

<input type=hidden name=fromdate value=$form->{fromdate}>
<input type=hidden name=todate value=$form->{todate}>

<br>
<input type=submit class=submit name=action value="|
    . $locale->text('Update') . qq|">
<input type=submit class=submit name=action value="|
    . $locale->text('Select all') . qq|">
<input type=submit class=submit name=action value="|
    . $locale->text('Done') . qq|">

</form>

</body>
</html>
|;

  $main::lxdebug->leave_sub();
}

sub update {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $main::auth->assert('cash');

  RC->payment_transactions(\%myconfig, \%$form);

  my $i;
  foreach my $ref (@{ $form->{PR} }) {
    if (!$ref->{fx_transaction}) {
      $i++;
      $ref->{cleared} = ($form->{"cleared_$i"}) ? "checked" : "";
    }
  }

  &display_form;

  $main::lxdebug->leave_sub();
}

sub select_all {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $main::auth->assert('cash');

  RC->payment_transactions(\%myconfig, \%$form);

  map { $_->{cleared} = "checked" unless $_->{fx_transaction} }
    @{ $form->{PR} };

  &display_form;

  $main::lxdebug->leave_sub();
}

sub done {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('cash');

  $form->{callback} = "$form->{script}?action=reconciliation";

  $form->error($locale->text('Out of balance!')) if ($form->{difference} *= 1);

  RC->reconcile(\%myconfig, \%$form);
  $form->redirect;

  $main::lxdebug->leave_sub();
}

