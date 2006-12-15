#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 2001
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
# module for Chart of Accounts, Income Statement and Balance Sheet
# search and edit transactions posted by the GL, AR and AP
#
#======================================================================

use SL::CA;

1;

# end of main

# this is for our long dates
# $locale->text('January')
# $locale->text('February')
# $locale->text('March')
# $locale->text('April')
# $locale->text('May ')
# $locale->text('June')
# $locale->text('July')
# $locale->text('August')
# $locale->text('September')
# $locale->text('October')
# $locale->text('November')
# $locale->text('December')

# this is for our short month
# $locale->text('Jan')
# $locale->text('Feb')
# $locale->text('Mar')
# $locale->text('Apr')
# $locale->text('May')
# $locale->text('Jun')
# $locale->text('Jul')
# $locale->text('Aug')
# $locale->text('Sep')
# $locale->text('Oct')
# $locale->text('Nov')
# $locale->text('Dec')

sub chart_of_accounts {
  $lxdebug->enter_sub();

  CA->all_accounts(\%myconfig, \%$form);

  @column_index = qw(accno gifi_accno description debit credit);

  $column_header{accno} =
    qq|<th class=listheading>| . $locale->text('Account') . qq|</th>\n|;
  $column_header{gifi_accno} =
    qq|<th class=listheading>| . $locale->text('GIFI') . qq|</th>\n|;
  $column_header{description} =
    qq|<th class=listheading>| . $locale->text('Description') . qq|</th>\n|;
  $column_header{debit} =
    qq|<th class=listheading>| . $locale->text('Debit') . qq|</th>\n|;
  $column_header{credit} =
    qq|<th class=listheading>| . $locale->text('Credit') . qq|</th>\n|;

  $form->{title} = $locale->text('Chart of Accounts');

  $colspan = $#column_index + 1;

  $form->header;

  print qq|
<body>

<table border=0 width=100%>
  <tr><th class=listtop colspan=$colspan>$form->{title}</th></tr>
  <tr height="5"></tr>
  <tr class=listheading>|;

  map { print $column_header{$_} } @column_index;

  print qq|
  </tr>
|;

  foreach $ca (@{ $form->{CA} }) {

    $description      = $form->escape($ca->{description});
    $gifi_description = $form->escape($ca->{gifi_description});

    $href =
      qq|$form->{script}?path=$form->{path}&action=list&accno=$ca->{accno}&login=$form->{login}&password=$form->{password}&description=$description&gifi_accno=$ca->{gifi_accno}&gifi_description=$gifi_description|;

    if ($ca->{charttype} eq "H") {
      print qq|<tr class=listheading>|;
      map { $column_data{$_} = "<th>$ca->{$_}</th>"; } qw(accno description);
      $column_data{gifi_accno} = "<th>$ca->{gifi_accno}&nbsp;</th>";
    } else {
      $i++;
      $i %= 2;
      print qq|<tr class=listrow$i>|;
      $column_data{accno}      = "<td><a href=$href>$ca->{accno}</a></td>";
      $column_data{gifi_accno} =
        "<td><a href=$href&accounttype=gifi>$ca->{gifi_accno}</a>&nbsp;</td>";
      $column_data{description} = "<td>$ca->{description}</td>";
    }
    my $debit = "";
    my $credit = "";
    if ($ca->{debit}) {
      $debit = $form->format_amount(\%myconfig, $ca->{debit}, 2, "&nbsp;");
    }
    if ($ca->{credit}) {
      $credit = $form->format_amount(\%myconfig, $ca->{credit}, 2, "&nbsp;");
    }
    $column_data{debit} =
        "<td align=right>"
      . $debit
      . "</td>\n";
    $column_data{credit} =
        "<td align=right>"
      . $credit
      . "</td>\n";

    $totaldebit  += $ca->{debit};
    $totalcredit += $ca->{credit};

    map { print $column_data{$_} } @column_index;

    print qq|
</tr>
|;
  }

  map { $column_data{$_} = "<td>&nbsp;</td>"; }
    qw(accno gifi_accno description);

  $column_data{debit} =
    "<th align=right class=listtotal>"
    . $form->format_amount(\%myconfig, $totaldebit, 2, 0) . "</th>";
  $column_data{credit} =
    "<th align=right class=listtotal>"
    . $form->format_amount(\%myconfig, $totalcredit, 2, 0) . "</th>";

  print "<tr class=listtotal>";

  map { print $column_data{$_} } @column_index;

  print qq|
</tr>
<tr>
  <td colspan=$colspan><hr size=3 noshade></td>
</tr>
</table>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub list {
  $lxdebug->enter_sub();

  $form->{title} = $locale->text('List Transactions');
  if ($form->{accounttype} eq 'gifi') {
    $form->{title} .= " - " . $locale->text('GIFI') . " $form->{gifi_accno}";
  } else {
    $form->{title} .= " - " . $locale->text('Account') . " $form->{accno}";
  }

  # get departments
  $form->all_departments(\%myconfig);
  if (@{ $form->{all_departments} }) {
    $form->{selectdepartment} = "<option>\n";

    map {
      $form->{selectdepartment} .=
        "<option>$_->{description}--$_->{id}\n"
    } (@{ $form->{all_departments} });
  }

  $department = qq|
        <tr>
	  <th align=right nowrap>| . $locale->text('Department') . qq|</th>
	  <td colspan=3><select name=department>$form->{selectdepartment}</select></td>
	</tr>
| if $form->{selectdepartment};

  $form->header;

  map { $form->{$_} =~ s/\"/&quot;/g; } qw(description gifi_description);

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=accno value=$form->{accno}>
<input type=hidden name=description value="$form->{description}">
<input type=hidden name=sort value=transdate>
<input type=hidden name=eur value=$eur>
<input type=hidden name=accounttype value=$form->{accounttype}>
<input type=hidden name=gifi_accno value=$form->{gifi_accno}>
<input type=hidden name=gifi_description value="$form->{gifi_description}">

<table border=0 width=100%>
  <tr><th class=listtop>$form->{title}</th></tr>
  <tr height="5"></tr
  <tr valign=top>
    <td>
      <table>
        $department
	<tr>
	  <th align=right>| . $locale->text('From') . qq|</th>
	  <td><input name=fromdate size=11 title="$myconfig{dateformat}"></td>
	  <th align=right>| . $locale->text('To') . qq|</th>
	  <td><input name=todate size=11 title="$myconfig{dateformat}"></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Include in Report') . qq|</th>
	  <td colspan=3>
	  <input name=l_subtotal class=checkbox type=checkbox value=Y>&nbsp;|
    . $locale->text('Subtotal') . qq|</td>
	</tr>
      </table>
    </td>
  </tr>
  <tr><td><hr size=3 noshade></td></tr>
</table>

<input type=hidden name=login value=$form->{login}>
<input type=hidden name=path value=$form->{path}>
<input type=hidden name=password value=$form->{password}>

<br><input class=submit type=submit name=action value="|
    . $locale->text('List Transactions') . qq|">
</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub list_transactions {
  $lxdebug->enter_sub();

  CA->all_transactions(\%myconfig, \%$form);

  $description      = $form->escape($form->{description});
  $gifi_description = $form->escape($form->{gifi_description});
  $department       = $form->escape($form->{department});
  $projectnumber    = $form->escape($form->{projectnumber});
  $title            = $form->escape($form->{title});

  # construct href
  $href =
    "$form->{script}?path=$form->{path}&action=list_transactions&accno=$form->{accno}&login=$form->{login}&password=$form->{password}&fromdate=$form->{fromdate}&todate=$form->{todate}&description=$description&accounttype=$form->{accounttype}&gifi_accno=$form->{gifi_accno}&gifi_description=$gifi_description&l_heading=$form->{l_heading}&l_subtotal=$form->{l_subtotal}&department=$department&projectnumber=$projectnumber&project_id=$form->{project_id}&title=$title";

  $description      = $form->escape($form->{description},      1);
  $gifi_description = $form->escape($form->{gifi_description}, 1);
  $department       = $form->escape($form->{department},       1);
  $projectnumber    = $form->escape($form->{projectnumber},    1);
  $title            = $form->escape($form->{title},            1);

  # construct callback
  $callback =
    "$form->{script}?path=$form->{path}&action=list_transactions&accno=$form->{accno}&login=$form->{login}&password=$form->{password}&fromdate=$form->{fromdate}&todate=$form->{todate}&description=$description&accounttype=$form->{accounttype}&gifi_accno=$form->{gifi_accno}&gifi_description=$gifi_description&l_heading=$form->{l_heading}&l_subtotal=$form->{l_subtotal}&department=$department&projectnumber=$projectnumber&project_id=$form->{project_id}&title=$title";

  # figure out which column comes first
  $column_header{transdate} =
      qq|<th><a class=listheading href=$href&sort=transdate>|
    . $locale->text('Date')
    . qq|</a></th>|;
  $column_header{reference} =
      qq|<th><a class=listheading href=$href&sort=reference>|
    . $locale->text('Reference')
    . qq|</a></th>|;
  $column_header{description} =
      qq|<th><a class=listheading href=$href&sort=description>|
    . $locale->text('Description')
    . qq|</a></th>|;
  $column_header{debit}   = qq|<th>| . $locale->text('Debit') . qq|</th>|;
  $column_header{credit}  = qq|<th>| . $locale->text('Credit') . qq|</th>|;
  $column_header{balance} = qq|<th>| . $locale->text('Balance') . qq|</th>|;

  @column_index =
    $form->sort_columns(qw(transdate reference description debit credit));

  if ($form->{accounttype} eq 'gifi') {
    map { $form->{$_} = $form->{"gifi_$_"} } qw(accno description);
  }
  if ($form->{accno}) {
    push @column_index, "balance";
  }

  $form->{title} =
    ($form->{accounttype} eq 'gifi')
    ? $locale->text('GIFI')
    : $locale->text('Account');

  $form->{title} .= " $form->{accno} - $form->{description}";

  if ($form->{department}) {
    ($department) = split /--/, $form->{department};
    $options = $locale->text('Department') . " : $department<br>";
  }
  if ($form->{projectnumber}) {
    $options .= $locale->text('Project Number');
    $options .= " : $form->{projectnumber}<br>";
  }

  if ($form->{fromdate} || $form->{todate}) {
    if ($form->{fromdate}) {
      $fromdate = $locale->date(\%myconfig, $form->{fromdate}, 1);
    }
    if ($form->{todate}) {
      $todate = $locale->date(\%myconfig, $form->{todate}, 1);
    }

    $form->{period} = "$fromdate - $todate";
  } else {
    $form->{period} =
      $locale->date(\%myconfig, $form->current_date(\%myconfig), 1);
  }

  $options .= $form->{period};

  $form->header;

  print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>$options</td>
  </tr>
  <tr>
    <td>
      <table width=100%>
       <tr class=listheading>
|;

  map { print "$column_header{$_}\n" } @column_index;

  print qq|
       </tr>
|;

  # add sort to callback
  $callback = $form->escape($callback . "&sort=$form->{sort}");

  if (@{ $form->{CA} }) {
    $sameitem = $form->{CA}->[0]->{ $form->{sort} };
  }

  $ml = ($form->{category} =~ /(A|E)/) ? -1 : 1;
  if ($form->{accno} && $form->{balance}) {

    map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;

    $column_data{balance} =
        "<td align=right>"
      . $form->format_amount(\%myconfig, $form->{balance} * $ml, 2, 0)
      . "</td>";

    $i++;
    $i %= 2;
    print qq|
        <tr class=listrow$i>
|;
    map { print $column_data{$_} } @column_index;
    print qq|
       </tr>
|;
  }

  foreach $ca (@{ $form->{CA} }) {

    if ($form->{l_subtotal} eq 'Y') {
      if ($sameitem ne $ca->{ $form->{sort} }) {
        &ca_subtotal;
      }
    }

    # construct link to source
    $href =
      "<a href=$ca->{module}.pl?path=$form->{path}&action=edit&id=$ca->{id}&login=$form->{login}&password=$form->{password}&callback=$callback>$ca->{reference}</a>";

    $column_data{debit} =
      "<td align=right>"
      . $form->format_amount(\%myconfig, $ca->{debit}, 2, "&nbsp;") . "</td>";
    $column_data{credit} =
      "<td align=right>"
      . $form->format_amount(\%myconfig, $ca->{credit}, 2, "&nbsp;") . "</td>";

    $form->{balance} += $ca->{amount};
    $column_data{balance} =
        "<td align=right>"
      . $form->format_amount(\%myconfig, $form->{balance} * $ml, 2, 0)
      . "</td>";

    $subtotaldebit  += $ca->{debit};
    $subtotalcredit += $ca->{credit};

    $totaldebit  += $ca->{debit};
    $totalcredit += $ca->{credit};

    $column_data{transdate}   = qq|<td>$ca->{transdate}</td>|;
    $column_data{reference}   = qq|<td>$href</td>|;
    $column_data{description} = qq|<td>$ca->{description}</td>|;

    $i++;
    $i %= 2;
    print qq|
        <tr class=listrow$i>
|;

    map { print $column_data{$_} } @column_index;

    print qq|
        </tr>
|;

  }

  if ($form->{l_subtotal} eq 'Y') {
    &ca_subtotal;
  }

  map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;

  $column_data{debit} =
    "<th align=right>"
    . $form->format_amount(\%myconfig, $totaldebit, 2, "&nbsp;") . "</th>";
  $column_data{credit} =
    "<th align=right>"
    . $form->format_amount(\%myconfig, $totalcredit, 2, "&nbsp;") . "</th>";
  $column_data{balance} =
    "<th align=right>"
    . $form->format_amount(\%myconfig, $form->{balance} * $ml, 2, 0) . "</th>";

  print qq|
	<tr class=listtotal>
|;

  map { print $column_data{$_} } @column_index;

  print qq|
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub ca_subtotal {
  $lxdebug->enter_sub();

  map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;

  $column_data{debit} =
    "<th align=right>"
    . $form->format_amount(\%myconfig, $subtotaldebit, 2, "&nbsp;") . "</th>";
  $column_data{credit} =
    "<th align=right>"
    . $form->format_amount(\%myconfig, $subtotalcredit, 2, "&nbsp;") . "</th>";

  $subtotaldebit  = 0;
  $subtotalcredit = 0;

  $sameitem = $ca->{ $form->{sort} };

  print qq|
      <tr class=listsubtotal>
|;

  map { print "$column_data{$_}\n" } @column_index;

  print qq|
      </tr>
|;

  $lxdebug->leave_sub();
}
