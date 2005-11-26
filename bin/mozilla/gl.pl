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
# Genereal Ledger
#
#======================================================================

use SL::GL;
use SL::PE;

require "$form->{path}/arap.pl";

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

sub add {
  $lxdebug->enter_sub();

  $form->{title} = "Add";

  $form->{callback} =
    "$form->{script}?action=add&path=$form->{path}&login=$form->{login}&password=$form->{password}"
    unless $form->{callback};

  # we use this only to set a default date
  GL->transaction(\%myconfig, \%$form);

  map {
    $chart .=
      "<option value=\"$_->{accno}--$_->{taxkey_id}\">$_->{accno}--$_->{description}</option>"
  } @{ $form->{chart} };
  map {
    $tax .=
      qq|<option value="$_->{taxkey}--$_->{rate}">$_->{taxdescription}  |
      . ($_->{rate} * 100) . qq| %|
  } @{ $form->{TAX} };

  $form->{chart}     = $chart;
  $form->{chartinit} = $chart;
  $form->{rowcount}  = 2;

  $form->{debitchart}  = $chart;
  $form->{creditchart} = $chart;
  $form->{taxchart}    = $tax;

  $form->{debit}  = 0;
  $form->{credit} = 0;
  $form->{tax}    = 0;

  # departments
  $form->all_departments(\%myconfig);
  if (@{ $form->{all_departments} }) {
    $form->{selectdepartment} = "<option>\n";

    map {
      $form->{selectdepartment} .=
        "<option>$_->{description}--$_->{id}\n"
    } (@{ $form->{all_departments} });
  }

  &display_form(1);
  $lxdebug->leave_sub();

}

sub edit {
  $lxdebug->enter_sub();

  GL->transaction(\%myconfig, \%$form);
  map {
    $chart .=
      "<option value=\"$_->{accno}--$_->{taxkey_id}\">$_->{accno}--$_->{description}</option>"
  } @{ $form->{chart} };

  map {
    $tax .=
      qq|<option value="$_->{taxkey}--$_->{rate}">$_->{taxdescription}  |
      . ($_->{rate} * 100) . qq| %|
  } @{ $form->{TAX} };

  $form->{chart} = $chart;

  $form->{taxchart} = $tax;

  $form->{amount} = $form->format_amount(\%myconfig, $form->{amount}, 2);

  # departments
  $form->all_departments(\%myconfig);
  if (@{ $form->{all_departments} }) {
    $form->{selectdepartment} = "<option>\n";

    map {
      $form->{selectdepartment} .=
        "<option>$_->{description}--$_->{id}\n"
    } (@{ $form->{all_departments} });
  }

  my $i        = 1;
  my $tax      = 0;
  my $taxaccno = "";
  foreach $ref (@{ $form->{GL} }) {
    $form->{"projectnumber_$i"} = "$ref->{projectnumber}--$ref->{project_id}";

    $j = $i - 1;
    if ($tax && ($ref->{accno} eq $taxaccno)) {
      $form->{"tax_$j"}      = abs($ref->{amount});
      $form->{"taxchart_$j"} = $ref->{taxkey} . "--" . $ref->{taxrate};
      if ($form->{taxincluded}) {
        if ($ref->{amount} < 0) {
          $form->{"debit_$j"} += $form->{"tax_$j"};
        } else {
          $form->{"credit_$j"} += $form->{"tax_$j"};
        }
      }
    } else {
      $form->{"accno_$i"} = "$ref->{accno}--$ref->{accnotaxkey}";
      for (qw(fx_transaction source memo)) { $form->{"${_}_$i"} = $ref->{$_} }
      if ($ref->{amount} < 0) {
        $form->{totaldebit} -= $ref->{amount};
        $form->{"debit_$i"} = $ref->{amount} * -1;
      } else {
        $form->{totalcredit} += $ref->{amount};
        $form->{"credit_$i"} = $ref->{amount};
      }
      $form->{"taxchart_$i"} = "0--";
      $i++;
    }
    if ($ref->{taxaccno} && !$tax) {
      $taxaccno = $ref->{taxaccno};
      $tax      = 1;
    } else {
      $taxaccno = "";
      $tax      = 0;
    }

  }

  $form->{rowcount} = $i;
  $form->{locked}   =
    ($form->datetonum($form->{transdate}, \%myconfig) <=
     $form->datetonum($form->{closedto}, \%myconfig));

  $form->{title} = "Edit";

  &form_header;
  &display_rows;
  &form_footer;
  $lxdebug->leave_sub();

}

sub search {
  $lxdebug->enter_sub();

  $form->{title} = $locale->text('Buchungsjournal');

  $form->all_departments(\%myconfig);

  # departments
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

  # use JavaScript Calendar or not
  $form->{jsscript} = $jscalendar;
  $jsscript = "";
  if ($form->{jsscript}) {

    # with JavaScript Calendar
    $button1 = qq|
       <td><input name=datefrom id=datefrom size=11 title="$myconfig{dateformat}">
       <input type=button name=datefrom id="trigger1" value=|
      . $locale->text('button') . qq|></td>  
       |;
    $button2 = qq|
       <td><input name=dateto id=dateto size=11 title="$myconfig{dateformat}">
       <input type=button name=dateto id="trigger2" value=|
      . $locale->text('button') . qq|></td>
     |;

    #write Trigger
    $jsscript =
      Form->write_trigger(\%myconfig, "2", "datefrom", "BR", "trigger1",
                          "dateto", "BL", "trigger2");
  } else {

    # without JavaScript Calendar
    $button1 =
      qq|<td><input name=datefrom id=datefrom size=11 title="$myconfig{dateformat}"></td>|;
    $button2 =
      qq|<td><input name=dateto id=dateto size=11 title="$myconfig{dateformat}"></td>|;
  }

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=sort value=transdate>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
	<tr>
	  <th align=right>| . $locale->text('Reference') . qq|</th>
	  <td><input name=reference size=20></td>
	  <th align=right>| . $locale->text('Source') . qq|</th>
	  <td><input name=source size=20></td>
	</tr>
	$department
	<tr>
	  <th align=right>| . $locale->text('Description') . qq|</th>
	  <td colspan=3><input name=description size=40></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Notes') . qq|</th>
	  <td colspan=3><input name=notes size=40></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('From') . qq|</th>
          $button1
          $button2
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Include in Report') . qq|</th>
	  <td colspan=3>
	    <table>
	      <tr>
		<td>
		  <input name="category" class=radio type=radio value=X checked>&nbsp;|
    . $locale->text('All') . qq|
		  <input name="category" class=radio type=radio value=A>&nbsp;|
    . $locale->text('Asset') . qq|
		  <input name="category" class=radio type=radio value=L>&nbsp;|
    . $locale->text('Liability') . qq|
		  <input name="category" class=radio type=radio value=I>&nbsp;|
    . $locale->text('Revenue') . qq|
		  <input name="category" class=radio type=radio value=E>&nbsp;|
    . $locale->text('Expense') . qq|
		</td>
	      </tr>
	      <tr>
		<table>
		  <tr>
		    <td align=right><input name="l_id" class=checkbox type=checkbox value=Y></td>
		    <td>| . $locale->text('ID') . qq|</td>
		    <td align=right><input name="l_transdate" class=checkbox type=checkbox value=Y checked></td>
		    <td>| . $locale->text('Date') . qq|</td>
		    <td align=right><input name="l_reference" class=checkbox type=checkbox value=Y checked></td>
		    <td>| . $locale->text('Reference') . qq|</td>
		    <td align=right><input name="l_description" class=checkbox type=checkbox value=Y checked></td>
		    <td>| . $locale->text('Description') . qq|</td>
		    <td align=right><input name="l_notes" class=checkbox type=checkbox value=Y></td>
		    <td>| . $locale->text('Notes') . qq|</td>
		  </tr>
		  <tr>
		    <td align=right><input name="l_debit" class=checkbox type=checkbox value=Y checked></td>
		    <td>| . $locale->text('Debit') . qq|</td>
		    <td align=right><input name="l_credit" class=checkbox type=checkbox value=Y checked></td>
		    <td>| . $locale->text('Credit') . qq|</td>
		    <td align=right><input name="l_source" class=checkbox type=checkbox value=Y checked></td>
		    <td>| . $locale->text('Source') . qq|</td>
		    <td align=right><input name="l_accno" class=checkbox type=checkbox value=Y checked></td>
		    <td>| . $locale->text('Account') . qq|</td>
		    <td align=right><input name="l_gifi_accno" class=checkbox type=checkbox value=Y></td>
		    <td>| . $locale->text('GIFI') . qq|</td>
		  </tr>
		  <tr>
		    <td align=right><input name="l_subtotal" class=checkbox type=checkbox value=Y></td>
		    <td>| . $locale->text('Subtotal') . qq|</td>
		  </tr>
		</table>
	      </tr>
	    </table>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

$jsscript

<input type=hidden name=nextsub value=generate_report>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<br>
<input class=submit type=submit name=action value="|
    . $locale->text('Continue') . qq|">
</form>

</body>
</html>
|;
  $lxdebug->leave_sub();
}

sub generate_report {
  $lxdebug->enter_sub();

  $form->{sort} = "transdate" unless $form->{sort};

  GL->all_transactions(\%myconfig, \%$form);

  $callback =
    "$form->{script}?action=generate_report&path=$form->{path}&login=$form->{login}&password=$form->{password}";

  $href = $callback;

  %acctype = ('A' => $locale->text('Asset'),
              'C' => $locale->text('Contra'),
              'L' => $locale->text('Liability'),
              'Q' => $locale->text('Equity'),
              'I' => $locale->text('Revenue'),
              'E' => $locale->text('Expense'),);

  $form->{title} = $locale->text('General Ledger');

  $ml = ($form->{ml} =~ /(A|E|Q)/) ? -1 : 1;

  unless ($form->{category} eq 'X') {
    $form->{title} .= " : " . $locale->text($acctype{ $form->{category} });
  }
  if ($form->{accno}) {
    $href .= "&accno=" . $form->escape($form->{accno});
    $callback .= "&accno=" . $form->escape($form->{accno}, 1);
    $option =
      $locale->text('Account')
      . " : $form->{accno} $form->{account_description}";
  }
  if ($form->{gifi_accno}) {
    $href     .= "&gifi_accno=" . $form->escape($form->{gifi_accno});
    $callback .= "&gifi_accno=" . $form->escape($form->{gifi_accno}, 1);
    $option   .= "\n<br>" if $option;
    $option   .=
      $locale->text('GIFI')
      . " : $form->{gifi_accno} $form->{gifi_account_description}";
  }
  if ($form->{source}) {
    $href     .= "&source=" . $form->escape($form->{source});
    $callback .= "&source=" . $form->escape($form->{source}, 1);
    $option   .= "\n<br>" if $option;
    $option   .= $locale->text('Source') . " : $form->{source}";
  }
  if ($form->{reference}) {
    $href     .= "&reference=" . $form->escape($form->{reference});
    $callback .= "&reference=" . $form->escape($form->{reference}, 1);
    $option   .= "\n<br>" if $option;
    $option   .= $locale->text('Reference') . " : $form->{reference}";
  }
  if ($form->{department}) {
    $href .= "&department=" . $form->escape($form->{department});
    $callback .= "&department=" . $form->escape($form->{department}, 1);
    ($department) = split /--/, $form->{department};
    $option .= "\n<br>" if $option;
    $option .= $locale->text('Department') . " : $department";
  }

  if ($form->{description}) {
    $href     .= "&description=" . $form->escape($form->{description});
    $callback .= "&description=" . $form->escape($form->{description}, 1);
    $option   .= "\n<br>" if $option;
    $option   .= $locale->text('Description') . " : $form->{description}";
  }
  if ($form->{notes}) {
    $href     .= "&notes=" . $form->escape($form->{notes});
    $callback .= "&notes=" . $form->escape($form->{notes}, 1);
    $option   .= "\n<br>" if $option;
    $option   .= $locale->text('Notes') . " : $form->{notes}";
  }

  if ($form->{datefrom}) {
    $href     .= "&datefrom=$form->{datefrom}";
    $callback .= "&datefrom=$form->{datefrom}";
    $option   .= "\n<br>" if $option;
    $option   .=
        $locale->text('From') . " "
      . $locale->date(\%myconfig, $form->{datefrom}, 1);
  }
  if ($form->{dateto}) {
    $href     .= "&dateto=$form->{dateto}";
    $callback .= "&dateto=$form->{dateto}";
    if ($form->{datefrom}) {
      $option .= " ";
    } else {
      $option .= "\n<br>" if $option;
    }
    $option .=
        $locale->text('Bis') . " "
      . $locale->date(\%myconfig, $form->{dateto}, 1);
  }

  @columns = $form->sort_columns(
    qw(transdate id reference description notes source debit debit_accno credit credit_accno debit_tax debit_tax_accno credit_tax credit_tax_accno accno gifi_accno)
  );

  if ($form->{accno} || $form->{gifi_accno}) {
    @columns = grep !/(accno|gifi_accno)/, @columns;
    push @columns, "balance";
    $form->{l_balance} = "Y";

  }

  $form->{l_credit_accno}     = "Y";
  $form->{l_debit_accno}      = "Y";
  $form->{l_credit_tax}       = "Y";
  $form->{l_debit_tax}        = "Y";
  $form->{l_credit_tax_accno} = "Y";
  $form->{l_debit_tax_accno}  = "Y";
  $form->{l_accno}            = "N";
  foreach $item (@columns) {
    if ($form->{"l_$item"} eq "Y") {
      push @column_index, $item;

      # add column to href and callback
      $callback .= "&l_$item=Y";
      $href     .= "&l_$item=Y";
    }
  }

  if ($form->{l_subtotal} eq 'Y') {
    $callback .= "&l_subtotal=Y";
    $href     .= "&l_subtotal=Y";
  }

  $callback .= "&category=$form->{category}";
  $href     .= "&category=$form->{category}";

  $column_header{id} =
      "<th><a class=listheading href=$href&sort=id>"
    . $locale->text('ID')
    . "</a></th>";
  $column_header{transdate} =
      "<th><a class=listheading href=$href&sort=transdate>"
    . $locale->text('Date')
    . "</a></th>";
  $column_header{reference} =
      "<th><a class=listheading href=$href&sort=reference>"
    . $locale->text('Reference')
    . "</a></th>";
  $column_header{source} =
      "<th><a class=listheading href=$href&sort=source>"
    . $locale->text('Source')
    . "</a></th>";
  $column_header{description} =
      "<th><a class=listheading href=$href&sort=description>"
    . $locale->text('Description')
    . "</a></th>";
  $column_header{notes} =
    "<th class=listheading>" . $locale->text('Notes') . "</th>";
  $column_header{debit} =
    "<th class=listheading>" . $locale->text('Debit') . "</th>";
  $column_header{debit_accno} =
      "<th><a class=listheading href=$href&sort=accno>"
    . $locale->text('Debit Account')
    . "</a></th>";
  $column_header{credit} =
    "<th class=listheading>" . $locale->text('Credit') . "</th>";
  $column_header{credit_accno} =
      "<th><a class=listheading href=$href&sort=accno>"
    . $locale->text('Credit Account')
    . "</a></th>";
  $column_header{debit_tax} =
      "<th><a class=listheading href=$href&sort=accno>"
    . $locale->text('Debit Tax')
    . "</a></th>";
  $column_header{debit_tax_accno} =
      "<th><a class=listheading href=$href&sort=accno>"
    . $locale->text('Debit Tax Account')
    . "</a></th>";
  $column_header{credit_tax} =
      "<th><a class=listheading href=$href&sort=accno>"
    . $locale->text('Credit Tax')
    . "</a></th>";
  $column_header{credit_tax_accno} =
      "<th><a class=listheading href=$href&sort=accno>"
    . $locale->text('Credit Tax Account')
    . "</a></th>";
  $column_header{gifi_accno} =
      "<th><a class=listheading href=$href&sort=gifi_accno>"
    . $locale->text('GIFI')
    . "</a></th>";
  $column_header{balance} = "<th>" . $locale->text('Balance') . "</th>";

  $form->{landscape} = 1;

  $form->header;

  print qq|
<body>

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
       <thead>
	<tr class=listheading>
|;

  map { print "$column_header{$_}\n" } @column_index;

  print "
        </tr>
        </thead>
        </tfoot>
        <tbody>
";

  # add sort to callback
  $form->{callback} = "$callback&sort=$form->{sort}";
  $callback = $form->escape($form->{callback});

  # initial item for subtotals
  if (@{ $form->{GL} }) {
    $sameitem = $form->{GL}->[0]->{ $form->{sort} };
  }

  if (($form->{accno} || $form->{gifi_accno}) && $form->{balance}) {

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
    map { print "$column_data{$_}\n" } @column_index;

    print qq|
        </tr>
|;
  }
   $form->{balance} *= $ml;
  foreach $ref (@{ $form->{GL} }) {
    $form->{balance} *= $ml;
    # if item ne sort print subtotal
    if ($form->{l_subtotal} eq 'Y') {
      if ($sameitem ne $ref->{ $form->{sort} }) {
        &gl_subtotal;
      }
    }
    #foreach $key (sort keys(%{ $ref->{amount} })) {
    #  $form->{balance} += $ref->{amount}{$key};
    #}

    $debit = "";
    foreach $key (sort keys(%{ $ref->{debit} })) {
      $subtotaldebit += $ref->{debit}{$key};
      $totaldebit    += $ref->{debit}{$key};
      if ($key == 0) {
        $debit = $form->format_amount(\%myconfig, $ref->{debit}{$key}, 2, 0);
      } else {
        $debit .=
          "<br>" . $form->format_amount(\%myconfig, $ref->{debit}{$key}, 2, 0);
      }
      $form->{balance} = abs($form->{balance}) - abs($ref->{debit}{$key});
    }

    $credit = "";
    foreach $key (sort keys(%{ $ref->{credit} })) {
      $subtotalcredit += $ref->{credit}{$key};
      $totalcredit    += $ref->{credit}{$key};
      if ($key == 0) {
        $credit = $form->format_amount(\%myconfig, $ref->{credit}{$key}, 2, 0);
      } else {
        $credit .= "<br>"
          . $form->format_amount(\%myconfig, $ref->{credit}{$key}, 2, 0);
      }
      $form->{balance} = abs($form->{balance}) - abs( $ref->{credit}{$key});
    }

    $debittax = "";
    foreach $key (sort keys(%{ $ref->{debit_tax} })) {
      $subtotaldebittax += $ref->{debit_tax}{$key};
      $totaldebittax    += $ref->{debit_tax}{$key};
      if ($key == 0) {
        $debittax =
          $form->format_amount(\%myconfig, $ref->{debit_tax}{$key}, 2, 0);
      } else {
        $debittax .= "<br>"
          . $form->format_amount(\%myconfig, $ref->{debit_tax}{$key}, 2, 0);
      }
      $form->{balance} = abs($form->{balance}) - abs($ref->{debit_tax}{$key});
    }

    $credittax = "";
    foreach $key (sort keys(%{ $ref->{credit_tax} })) {
      $subtotalcredittax += $ref->{credit_tax}{$key};
      $totalcredittax    += $ref->{credit_tax}{$key};
      if ($key == 0) {
        $credittax =
          $form->format_amount(\%myconfig, $ref->{credit_tax}{$key}, 2, 0);
      } else {
        $credittax .= "<br>"
          . $form->format_amount(\%myconfig, $ref->{credit_tax}{$key}, 2, 0);
      }
      $form->{balance} = abs($form->{balance}) - abs($ref->{credit_tax}{$key});
    }

    $debitaccno  = "";
    $debittaxkey = "";
    $taxaccno    = "";
    foreach $key (sort keys(%{ $ref->{debit_accno} })) {
      if ($key == 0) {
        $debitaccno =
          "<a href=$href&accno=$ref->{accno}&callback=$callback>$ref->{debit_accno}{$key}</a>";
      } else {
        $debitaccno .=
          "<br><a href=$href&accno=$ref->{accno}&callback=$callback>$ref->{debit_accno}{$key}</a>";
      }
      if ($ref->{debit_taxkey}{$key} eq $debittaxkey) {
        $ref->{debit_tax_accno}{$key} = $taxaccno;
      }
      $taxaccno    = $ref->{debit_tax_accno}{$key};
      $debittaxkey = $ref->{debit_taxkey}{$key};
    }

    $creditaccno  = "";
    $credittaxkey = "";
    $taxaccno     = "";
    foreach $key (sort keys(%{ $ref->{credit_accno} })) {
      if ($key == 0) {
        $creditaccno =
          "<a href=$href&accno=$ref->{accno}&callback=$callback>$ref->{credit_accno}{$key}</a>";
      } else {
        $creditaccno .=
          "<br><a href=$href&accno=$ref->{accno}&callback=$callback>$ref->{credit_accno}{$key}</a>";
      }
      if ($ref->{credit_taxkey}{$key} eq $credittaxkey) {
        $ref->{credit_tax_accno}{$key} = $taxaccno;
      }
      $taxaccno     = $ref->{credit_tax_accno}{$key};
      $credittaxkey = $ref->{credit_taxkey}{$key};
    }

    $debittaxaccno = "";
    foreach $key (sort keys(%{ $ref->{debit_tax_accno} })) {
      if ($key == 0) {
        $debittaxaccno =
          "<a href=$href&accno=$ref->{accno}&callback=$callback>$ref->{debit_tax_accno}{$key}</a>";
      } else {
        $debittaxaccno .=
          "<br><a href=$href&accno=$ref->{accno}&callback=$callback>$ref->{debit_tax_accno}{$key}</a>";
      }
    }

    $credittaxaccno = "";
    foreach $key (sort keys(%{ $ref->{credit_tax_accno} })) {
      if ($key == 0) {
        $credittaxaccno =
          "<a href=$href&accno=$ref->{accno}&callback=$callback>$ref->{credit_tax_accno}{$key}</a>";
      } else {
        $credittaxaccno .=
          "<br><a href=$href&accno=$ref->{accno}&callback=$callback>$ref->{credit_tax_accno}{$key}</a>";
      }
    }

    #    $ref->{debit} = $form->format_amount(\%myconfig, $ref->{debit}, 2, "&nbsp;");
    #    $ref->{credit} = $form->format_amount(\%myconfig, $ref->{credit}, 2, "&nbsp;");

    $column_data{id}        = "<td align=right>&nbsp;$ref->{id}&nbsp;</td>";
    $column_data{transdate} =
      "<td align=center>&nbsp;$ref->{transdate}&nbsp;</td>";
    $column_data{reference} =
      "<td align=center><a href=$ref->{module}.pl?action=edit&id=$ref->{id}&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback>$ref->{reference}</td>";
    $column_data{description} =
      "<td align=center>$ref->{description}&nbsp;</td>";
    $column_data{source}       = "<td align=center>$ref->{source}&nbsp;</td>";
    $column_data{notes}        = "<td align=center>$ref->{notes}&nbsp;</td>";
    $column_data{debit}        = "<td align=right>$debit</td>";
    $column_data{debit_accno}  = "<td align=center>$debitaccno</td>";
    $column_data{credit}       = "<td align=right>$credit</td>";
    $column_data{credit_accno} = "<td align=center>$creditaccno</td>";
    $column_data{debit_tax}    =
      ($ref->{debit_tax_accno} ne "")
      ? "<td align=right>$debittax</td>"
      : "<td></td>";
    $column_data{debit_tax_accno} = "<td align=center>$debittaxaccno</td>";
    $column_data{gifi_accno}      =
      "<td><a href=$href&gifi_accno=$ref->{gifi_accno}&callback=$callback>$ref->{gifi_accno}</a>&nbsp;</td>";
    $column_data{credit_tax} =
      ($ref->{credit_tax_accno} ne "")
      ? "<td align=right>$credittax</td>"
      : "<td></td>";
    $column_data{credit_tax_accno} = "<td align=center>$credittaxaccno</td>";
    $column_data{gifi_accno}       =
      "<td><a href=$href&gifi_accno=$ref->{gifi_accno}&callback=$callback>$ref->{gifi_accno}</a>&nbsp;</td>";
    $column_data{balance} =
        "<td align=right>"
      . $form->format_amount(\%myconfig, $form->{balance}, 2, 0)
      . "</td>";

    $i++;
    $i %= 2;
    print "
        <tr class=listrow$i>";
    map { print "$column_data{$_}\n" } @column_index;
    print "</tr>";

  }

  &gl_subtotal if ($form->{l_subtotal} eq 'Y');

  map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;

  $column_data{debit} =
    "<th align=right class=listtotal>"
    . $form->format_amount(\%myconfig, $totaldebit, 2, "&nbsp;") . "</th>";
  $column_data{credit} =
    "<th align=right class=listtotal>"
    . $form->format_amount(\%myconfig, $totalcredit, 2, "&nbsp;") . "</th>";
  $column_data{debit_tax} =
    "<th align=right class=listtotal>"
    . $form->format_amount(\%myconfig, $totaldebittax, 2, "&nbsp;") . "</th>";
  $column_data{credit_tax} =
    "<th align=right class=listtotal>"
    . $form->format_amount(\%myconfig, $totalcredittax, 2, "&nbsp;") . "</th>";
  $column_data{balance} =
    "<th align=right class=listtotal>"
    . $form->format_amount(\%myconfig, $form->{balance} * $ml, 2, 0) . "</th>";

  print qq|
	<tr class=listtotal>
|;

  map { print "$column_data{$_}\n" } @column_index;

  print qq|
        </tr>
        </tbody>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<br>

<form method=post action=$form->{script}>

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input class=submit type=submit name=action value="|
    . $locale->text('GL Transaction') . qq|">
<input class=submit type=submit name=action value="|
    . $locale->text('AR Transaction') . qq|">
<input class=submit type=submit name=action value="|
    . $locale->text('AP Transaction') . qq|">
<input class=submit type=submit name=action value="|
    . $locale->text('Sales Invoice') . qq|">
<input class=submit type=submit name=action value="|
    . $locale->text('Vendor Invoice') . qq|">|;

  if ($form->{menubar}) {
    require "$form->{path}/menu.pl";
    &menubar;
  }

  print qq|

</form>

</body>
</html>
|;
  $lxdebug->leave_sub();

}

sub gl_subtotal {
  $lxdebug->enter_sub();

  $subtotaldebit =
    $form->format_amount(\%myconfig, $subtotaldebit, 2, "&nbsp;");
  $subtotalcredit =
    $form->format_amount(\%myconfig, $subtotalcredit, 2, "&nbsp;");

  map { $column_data{$_} = "<td>&nbsp;</td>" }
    qw(transdate id reference source description accno);
  $column_data{debit}  = "<th align=right>$subtotaldebit</td>";
  $column_data{credit} = "<th align=right>$subtotalcredit</td>";

  print "<tr class=listsubtotal>";
  map { print "$column_data{$_}\n" } @column_index;
  print "</tr>";

  $subtotaldebit  = 0;
  $subtotalcredit = 0;

  $sameitem = $ref->{ $form->{sort} };
  $lxdebug->leave_sub();

}

sub update {
  $lxdebug->enter_sub();

  if ($form->{transdate} ne $form->{oldtransdate}) {
    if ($form->{selectprojectnumber}) {
      $form->all_projects(\%myconfig, undef, $form->{transdate});
      if (@{ $form->{all_project} }) {
        $form->{selectprojectnumber} = "<option>\n";
        for (@{ $form->{all_project} }) {
          $form->{selectprojectnumber} .=
            qq|<option value="$_->{projectnumber}--$_->{id}">$_->{projectnumber}\n|;
        }
        $form->{selectprojectnumber} =
          $form->escape($form->{selectprojectnumber}, 1);
      }
    }
    $form->{oldtransdate} = $form->{transdate};
  }

  my @a           = ();
  my $count       = 0;
  my $debittax    = 0;
  my $credittax   = 0;
  my $debitcount  = 0;
  my $creditcount = 0;
  $debitlock  = 0;
  $creditlock = 0;

  my @flds =
    qw(accno debit credit projectnumber fx_transaction source memo tax taxchart);

  for my $i (1 .. $form->{rowcount}) {

    unless (($form->{"debit_$i"} eq "") && ($form->{"credit_$i"} eq "")) {
      for (qw(debit credit tax)) {
        $form->{"${_}_$i"} =
          $form->parse_amount(\%myconfig, $form->{"${_}_$i"});
      }

      push @a, {};
      $debitcredit = ($form->{"debit_$i"} == 0) ? "0" : "1";
      if ($debitcredit) {
        $debitcount++;
      } else {
        $creditcount++;
      }

      if (($debitcount >= 2) && ($creditcount == 2)) {
        $form->{"credit_$i"} = 0;
        $form->{"tax_$i"}    = 0;
        $creditcount--;
        $creditlock = 1;
      }
      if (($creditcount >= 2) && ($debitcount == 2)) {
        $form->{"debit_$i"} = 0;
        $form->{"tax_$i"}   = 0;
        $debitcount--;
        $debitlock = 1;
      }
      if (($creditcount == 1) && ($debitcount == 2)) {
        $creditlock = 1;
      }
      if (($creditcount == 2) && ($debitcount == 1)) {
        $debitlock = 1;
      }
      if ($debitcredit && $credittax) {
        $form->{"taxchart_$i"} = "0--0.00";
      }
      if (!$debitcredit && $debittax) {
        $form->{"taxchart_$i"} = "0--0.00";
      }
      $amount =
        ($form->{"debit_$i"} == 0)
        ? $form->{"credit_$i"}
        : $form->{"debit_$i"};
      $j = $#a;
      if (($debitcredit && $credittax) || (!$debitcredit && $debittax)) {
        $form->{"taxchart_$i"} = "0--";
        $form->{"tax_$i"}      = 0;
      }
      if (!$form->{"korrektur_$i"}) {
        ($taxkey, $rate) = split(/--/, $form->{"taxchart_$i"});
        if ($taxkey > 1) {
          if ($debitcredit) {
            $debittax = 1;
          } else {
            $credittax = 1;
          }
          if ($form->{taxincluded}) {
            $form->{"tax_$i"} = $amount / ($rate + 1) * $rate;
          } else {
            $form->{"tax_$i"} = $amount * $rate;
          }
        } else {
          $form->{"tax_$i"} = 0;
        }
      }

      for (@flds) { $a[$j]->{$_} = $form->{"${_}_$i"} }
      $count++;
    }
  }

  for $i (1 .. $count) {
    $j = $i - 1;
    for (@flds) { $form->{"${_}_$i"} = $a[$j]->{$_} }
  }

  for $i ($count + 1 .. $form->{rowcount}) {
    for (@flds) { delete $form->{"${_}_$i"} }
  }

  $form->{rowcount} = $count + 1;

  &display_form;
  $lxdebug->leave_sub();

}

sub display_form {
  my ($init) = @_;
  $lxdebug->enter_sub();

  &form_header($init);

  #   for $i (1 .. $form->{rowcount}) {
  #     $form->{totaldebit} += $form->parse_amount(\%myconfig, $form->{"debit_$i"});
  #     $form->{totalcredit} += $form->parse_amount(\%myconfig, $form->{"credit_$i"});
  #
  #     &form_row($i);
  #   }
  &display_rows($init);
  &form_footer;
  $lxdebug->leave_sub();

}

sub display_rows {
  my ($init) = @_;
  $lxdebug->enter_sub();

  $form->{selectprojectnumber} = $form->unescape($form->{selectprojectnumber})
    if $form->{selectprojectnumber};

  $form->{totaldebit}  = 0;
  $form->{totalcredit} = 0;
  my $chart = $form->{chart};
  $chart            = $form->unquote($chart);
  $form->{taxchart} = $form->unquote($form->{taxchart});
  $taxchart         = $form->{taxchart};
  for $i (1 .. $form->{rowcount}) {

    $source = qq|
    <td><input name="source_$i" value="$form->{"source_$i"}" tabindex=|
      . ($i + 11 + (($i - 1) * 8)) . qq|></td>|;
    $memo = qq|
    <td><input name="memo_$i" value="$form->{"memo_$i"}" tabindex=|
      . ($i + 12 + (($i - 1) * 8)) . qq|></td>|;

    if ($init) {
      $accno = qq|
      <td><select name="accno_$i" onChange="setTaxkey(this, $i)" style="width:300px" tabindex=|
        . ($i + 5 + (($i - 1) * 8)) . qq|>$form->{chartinit}</select></td>|;
      $tax =
          qq|<td><select id="taxchart_$i" name="taxchart_$i" tabindex=|
        . ($i + 10 + (($i - 1) * 8))
        . qq|>$form->{taxchart}</select></td>|;
#       if ($form->{selectprojectnumber}) {
#         $project = qq|
#     <td><select name="projectnumber_$i">$form->{selectprojectnumber}</select></td>|;
#       }
      $korrektur =
        qq|<td><input type="checkbox" name="korrektur_$i" value="1" tabindex=|
        . ($i + 9 + (($i - 1) * 8))
        . qq|></td>|;
      if ($form->{transfer}) {
        $fx_transaction = qq|
        <td><input name="fx_transaction_$i" class=checkbox type=checkbox value=1></td>
    |;
      }

    } else {
      if ($form->{"debit_$i"} != 0) {
        $form->{totaldebit} += $form->{"debit_$i"};
        if (!$form->{taxincluded}) {
          $form->{totaldebit} += $form->{"tax_$i"};
        }
      } else {
        $form->{totalcredit} += $form->{"credit_$i"};
        if (!$form->{taxincluded}) {
          $form->{totalcredit} += $form->{"tax_$i"};
        }
      }

      for (qw(debit credit tax)) {
        $form->{"${_}_$i"} =
          ($form->{"${_}_$i"})
          ? $form->format_amount(\%myconfig, $form->{"${_}_$i"}, 2)
          : "";
      }

      if ($i < $form->{rowcount}) {

        $accno          = $chart;
        $chart_selected = $form->{"accno_$i"};
        $accno =~
          s/value=\"$chart_selected\"/value=\"$chart_selected\" selected/;
        $accno =
          qq|<td><select name="accno_$i" onChange="setTaxkey(this, $i)" style="width:300px" tabindex=|
          . ($i + 5 + (($i - 1) * 8))
          . qq|>$accno</select></td>|;
        $tax          = $taxchart;
        $tax_selected = $form->{"taxchart_$i"};
        $tax =~ s/value=\"$tax_selected\"/value=\"$tax_selected\" selected/;
        $tax =
            qq|<td><select id="taxchart_$i" name="taxchart_$i" tabindex=|
          . ($i + 10 + (($i - 1) * 8))
          . qq|>$tax</select></td>|;

#         if ($form->{selectprojectnumber}) {
#           $form->{"projectnumber_$i"} = ""
#             if $form->{selectprojectnumber} !~ /$form->{"projectnumber_$i"}/;
# 
#           $project = $form->{"projectnumber_$i"};
#           $project =~ s/--.*//;
#           $project = qq|<td>$project</td>|;
#         }

        if ($form->{transfer}) {
          $checked = ($form->{"fx_transaction_$i"}) ? "1" : "";
          $x = ($checked) ? "x" : "";
          $fx_transaction = qq|
      <td><input type=hidden name="fx_transaction_$i" value="$checked">$x</td>
    |;
        }
        $checked = ($form->{"korrektur_$i"}) ? "checked" : "";
        $korrektur =
          qq|<td><input type="checkbox" name="korrektur_$i" value="1" $checked tabindex=|
          . ($i + 9 + (($i - 1) * 8))
          . qq|></td>|;
        $form->hide_form("accno_$i");

      } else {

        $accno = qq|
      <td><select name="accno_$i" onChange="setTaxkey(this, $i)" style="width:300px" tabindex=|
          . ($i + 5 + (($i - 1) * 8)) . qq|>$chart</select></td>|;
        $tax = qq|
      <td><select id="taxchart_$i" name="taxchart_$i" tabindex=|
          . ($i + 10 + (($i - 1) * 8)) . qq|>$taxchart</select></td>|;
#         if ($form->{selectprojectnumber}) {
#           $project = qq|
#       <td><select name="projectnumber_$i">$form->{selectprojectnumber}</select></td>|;
#         }
        $korrektur =
          qq|<td><input type="checkbox" name="korrektur_$i" value="1" tabindex=|
          . ($i + 9 + (($i - 1) * 8))
          . qq|></td>|;
        if ($form->{transfer}) {
          $fx_transaction = qq|
      <td><input name="fx_transaction_$i" class=checkbox type=checkbox value=1></td>
    |;
        }
      }
    }
    my $debitreadonly  = "";
    my $creditreadonly = "";
    if ($i == $form->{rowcount}) {
      if ($debitlock) {
        $debitreadonly = "readonly";
      } elsif ($creditlock) {
        $creditreadonly = "readonly";
      }
    }

    print qq|<tr valign=top>
    $accno
    $fx_transaction
    <td><input name="debit_$i" size=10 value="$form->{"debit_$i"}" accesskey=$i tabindex=|
      . ($i + 6 + (($i - 1) * 8)) . qq| $debitreadonly></td>
    <td><input name="credit_$i" size=10 value="$form->{"credit_$i"}" tabindex=|
      . ($i + 7 + (($i - 1) * 8)) . qq| $creditreadonly></td>
    <td><input name="tax_$i" size=8 value="$form->{"tax_$i"}" tabindex=|
      . ($i + 8 + (($i - 1) * 8)) . qq|></td>
    $korrektur
    $tax
    $source
    $memo
  </tr>

  |;
  }

  $form->hide_form(qw(rowcount selectaccno));
#   print qq|
# <input type=hidden name=selectprojectnumber value="|
#     . $form->escape($form->{selectprojectnumber}, 1) . qq|">|;
  $lxdebug->leave_sub();

}

sub form_header {
  my ($init) = @_;
  $lxdebug->enter_sub();
  $title         = $form->{title};
  $form->{title} = $locale->text("$title General Ledger Transaction");
  $readonly      = ($form->{id}) ? "readonly" : "";

  # $locale->text('Add General Ledger Transaction')
  # $locale->text('Edit General Ledger Transaction')

  map { $form->{$_} =~ s/\"/&quot;/g }
    qw(reference description chart taxchart);
  $form->{javascript} = qq|<script type="text/javascript">
  <!--
  function setTaxkey(accno, row) {
    var taxkey = accno.options[accno.selectedIndex].value;
    var reg = /--([0-9])*/;
    var found = reg.exec(taxkey);
    var index = found[1];
    index = parseInt(index);
    var tax = 'taxchart_' + row;
    for (var i = 0; i < document.getElementById(tax).options.length; ++i) {
      var reg2 = new RegExp("^"+ index, "");
      if (reg2.exec(document.getElementById(tax).options[i].value)) {
        document.getElementById(tax).options[i].selected = true;
        break;
      }
    }
  };
  //-->
  </script>|;

  $form->{selectdepartment} =~ s/ selected//;
  $form->{selectdepartment} =~
    s/option>\Q$form->{department}\E/option selected>$form->{department}/;

  if (($rows = $form->numtextrows($form->{description}, 50)) > 1) {
    $description =
      qq|<textarea name=description rows=$rows cols=50 wrap=soft $readonly >$form->{description}</textarea>|;
  } else {
    $description =
      qq|<input name=description size=50 value="$form->{description}" tabindex="3" $readonly>|;
  }

  $taxincluded = ($form->{taxincluded}) ? "checked" : "";

  if ($init) {
    $taxincluded = "checked";
  }

  $department = qq|
  	<tr>
	  <th align=right nowrap>| . $locale->text('Department') . qq|</th>
	  <td colspan=3><select name=department>$form->{selectdepartment}</select></td>
	  <input type=hidden name=selectdepartment value="$form->{selectdepartment}">
	</tr>
| if $form->{selectdepartment};
  if ($init) {
    $form->{fokus} = "gl.reference";
  } else {
    $form->{fokus} = qq|gl.accno_$form->{rowcount}|;
  }

  # use JavaScript Calendar or not
  $form->{jsscript} = $jscalendar;
  $jsscript = "";
  if ($form->{jsscript}) {

    # with JavaScript Calendar
    $button1 = qq|
       <td><input name=transdate id=transdate size=11 title="$myconfig{dateformat}" value=$form->{transdate} tabindex="2" $readonly>
       <input type=button name=transdate id="trigger1" value=|
      . $locale->text('button') . qq|></td>  
       |;

    #write Trigger
    $jsscript =
      Form->write_trigger(\%myconfig, "1", "transdate", "BL", "trigger1", "",
                          "", "");
  } else {

    # without JavaScript Calendar
    $button1 =
      qq|<td><input name=transdate id=transdate size=11 title="$myconfig{dateformat}" value=$form->{transdate} tabindex="2" $readonly></td>|;
  }

  $form->header;

  print qq|
<body onLoad="fokus()">

<form method=post name="gl" action=$form->{script}>

<input name=id type=hidden value=$form->{id}>

<input type=hidden name=closedto value=$form->{closedto}>
<input type=hidden name=locked value=$form->{locked}>
<input type=hidden name=title value="$title">
<input type=hidden name=taxchart value="$form->{taxchart}">
<input type=hidden name=chart value="$form->{chart}">


<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
	<tr>
	  <th align=left>| . $locale->text('Reference') . qq|</th>
	  <td><input name=reference size=20 value="$form->{reference}" tabindex="1" $readonly></td>
	  <td align=left>
	    <table>
	      <tr>
		<th align=right nowrap>| . $locale->text('Date') . qq|</th>
                $button1
	      </tr>
	    </table>
	  </td>
	</tr>|;
  if ($form->{id}) {
    print qq|
	<tr>
	  <th align=right>| . $locale->text('Belegnummer') . qq|</th>
	  <td><input name=id size=20 value="$form->{id}" $readonly></td>
	  <td align=left>
	  <table>
	      <tr>
		<th align=right width=50%>| . $locale->text('Buchungsdatum') . qq|</th>
		<td align=left><input name=gldate size=11 title="$myconfig{dateformat}" value=$form->{gldate} $readonly></td>
	      </tr>
	    </table>
	  </td>
	</tr>|;
  }
  print qq|	
	$department|;
  if ($form->{id}) {
    print qq|
	<tr>
	  <th align=left width=1%>| . $locale->text('Description') . qq|</th>
	  <td width=1%>$description</td>
          <td>
	    <table>
	      <tr>
		<th align=left>| . $locale->text('MwSt. inkl.') . qq|</th>
		<td><input type=checkbox name=taxincluded value=1 tabindex="5" $taxincluded></td>
	      </tr>
	    </table>
	 </td>
	  <td align=left>
	    <table width=100%>
	      <tr>
		<th align=right width=50%>| . $locale->text('Mitarbeiter') . qq|</th>
		<td align=left><input name=employee size=11  value=$form->{employee} $readonly></td>
	      </tr>
	    </table>
	  </td>
	</tr>|;
  } else {
    print qq|
	<tr>
	  <th align=left width=1%>| . $locale->text('Description') . qq|</th>
	  <td width=1%>$description</td>
	  <td>
	    <table>
	      <tr>
		<th align=left>| . $locale->text('MwSt. inkl.') . qq|</th>
		<td><input type=checkbox name=taxincluded value=1 tabindex="5" $taxincluded></td>
	      </tr>
	    </table>
	 </td>
	</tr>|;
  }
  print qq|
      <tr>
      <td colspan=4>
          <table width=100%>
	   <tr class=listheading>
	  <th class=listheading style="width:15%">|
    . $locale->text('Account') . qq|</th>
	  <th class=listheading style="width:10%">|
    . $locale->text('Debit') . qq|</th>
	  <th class=listheading style="width:10%">|
    . $locale->text('Credit') . qq|</th>
          <th class=listheading style="width:10%">|
    . $locale->text('Tax') . qq|</th>
          <th class=listheading style="width:5%">|
    . $locale->text('Korrektur') . qq|</th>
          <th class=listheading style="width:10%">|
    . $locale->text('Taxkey') . qq|</th>
	  <th class=listheading style="width:20%">|
    . $locale->text('Source') . qq|</th>
	  <th class=listheading style="width:20%">| . $locale->text('Memo') . qq|</th>
	  $project
	</tr>

$jsscript
|;
  $lxdebug->leave_sub();

}

sub form_footer {
  $lxdebug->enter_sub();
  ($dec) = ($form->{totaldebit} =~ /\.(\d+)/);
  $dec = length $dec;
  $decimalplaces = ($dec > 2) ? $dec : 2;
  $radieren = ($form->current_date(\%myconfig) eq $form->{gldate}) ? 1 : 0;

  map {
    $form->{$_} =
      $form->format_amount(\%myconfig, $form->{$_}, 2, "&nbsp;")
  } qw(totaldebit totalcredit);

  print qq|
    <tr class=listtotal>
    <td></td>
    <th align=right class=listtotal> $form->{totaldebit}</th>
    <th align=right class=listtotal> $form->{totalcredit}</th> 
    <td colspan=5></td>
    </tr>
  </table>
  </td>
  </tr>
</table>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input name=callback type=hidden value="$form->{callback}">

<br>
|;

  $transdate = $form->datetonum($form->{transdate}, \%myconfig);
  $closedto  = $form->datetonum($form->{closedto},  \%myconfig);

  if ($form->{id}) {

    print qq|<input class=submit type=submit name=action value="|
      . $locale->text('Storno') . qq|">|;

    # Löschen und ändern von Buchungen nicht mehr möglich (GoB) nur am selben Tag möglich

    if (!$form->{locked} && $radieren) {
      print qq|
		<input class=submit type=submit name=action value="|
        . $locale->text('Post') . qq|" accesskey="b">
		<input class=submit type=submit name=action value="|
        . $locale->text('Delete') . qq|">|;
    }

    # 	if ($transdate > $closedto) {
    # 		print qq|
    # 		<input class=submit type=submit name=action value="|.$locale->text('Post as new').qq|">|;
    # 	}
  } else {
    if ($transdate > $closedto) {
      print qq|<input class=submit type=submit name=action value="|
        . $locale->text('Update') . qq|">
     		 <input class=submit type=submit name=action value="|
        . $locale->text('Post') . qq|">|;
    }
  }

  if ($form->{menubar}) {
    require "$form->{path}/menu.pl";
    &menubar;
  }

  print "
  </form>

</body>
</html>
";
  $lxdebug->leave_sub();

}

sub delete {
  $lxdebug->enter_sub();

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>
|;

  map { $form->{$_} =~ s/\"/&quot;/g } qw(reference description chart);

  delete $form->{header};

  foreach $key (keys %$form) {
    print qq|<input type=hidden name=$key value="$form->{$key}">\n|;
  }

  print qq|
<h2 class=confirm>| . $locale->text('Confirm!') . qq|</h2>

<h4>|
    . $locale->text('Are you sure you want to delete Transaction')
    . qq| $form->{reference}</h4>

<input name=action class=submit type=submit value="|
    . $locale->text('Yes') . qq|">
</form>
|;
  $lxdebug->leave_sub();

}

sub yes {
  $lxdebug->enter_sub();

  $form->redirect($locale->text('Transaction deleted!'))
    if (GL->delete_transaction(\%myconfig, \%$form));
  $form->error($locale->text('Cannot delete transaction!'));
  $lxdebug->leave_sub();

}

sub post {
  $lxdebug->enter_sub();

  # check if there is something in reference and date
  $form->isblank("reference",   $locale->text('Reference missing!'));
  $form->isblank("transdate",   $locale->text('Transaction Date missing!'));
  $form->isblank("description", $locale->text('Description missing!'));

  $transdate = $form->datetonum($form->{transdate}, \%myconfig);
  $closedto  = $form->datetonum($form->{closedto},  \%myconfig);

  # check project
  &check_project;

  my @a           = ();
  my $count       = 0;
  my $debittax    = 0;
  my $credittax   = 0;
  my $debitcount  = 0;
  my $creditcount = 0;
  $creditlock = 0;
  $debitlock  = 0;

  my @flds =
    qw(accno debit credit projectnumber fx_transaction source memo tax taxchart);
  if ($form->{storno}) {
    for my $i (1 .. $form->{rowcount}) {
      unless (($form->{"debit_$i"} eq "") && ($form->{"credit_$i"} eq "")) {
        if ($form->{"debit_$i"} ne "") {
          $form->{"credit_$i"} = $form->{"debit_$i"};
          $form->{"debit_$i"} = "";
        } elsif ($form->{"credit_$i"} ne "") {
          $form->{"debit_$i"} = $form->{"credit_$i"};
          $form->{"credit_$i"} = "";
        }
      }
    }
  }

  for my $i (1 .. $form->{rowcount}) {

    unless (($form->{"debit_$i"} eq "") && ($form->{"credit_$i"} eq "")) {
      for (qw(debit credit tax)) {
        $form->{"${_}_$i"} =
          $form->parse_amount(\%myconfig, $form->{"${_}_$i"});
      }

      push @a, {};
      $debitcredit = ($form->{"debit_$i"} == 0) ? "0" : "1";

      if ($debitcredit) {
        $debitcount++;
      } else {
        $creditcount++;
      }

      if (($debitcount >= 2) && ($creditcount == 2)) {
        $form->{"credit_$i"} = 0;
        $form->{"tax_$i"}    = 0;
        $creditcount--;
        $creditlock = 1;
      }
      if (($creditcount >= 2) && ($debitcount == 2)) {
        $form->{"debit_$i"} = 0;
        $form->{"tax_$i"}   = 0;
        $debitcount--;
        $debitlock = 1;
      }
      if (($creditcount == 1) && ($debitcount == 2)) {
        $creditlock = 1;
      }
      if (($creditcount == 2) && ($debitcount == 1)) {
        $debitlock = 1;
      }
      if ($debitcredit && $credittax) {
        $form->{"taxchart_$i"} = "0--0.00";
      }
      if (!$debitcredit && $debittax) {
        $form->{"taxchart_$i"} = "0--0.00";
      }
      $amount =
        ($form->{"debit_$i"} == 0)
        ? $form->{"credit_$i"}
        : $form->{"debit_$i"};
      $j = $#a;
      if (($debitcredit && $credittax) || (!$debitcredit && $debittax)) {
        $form->{"taxchart_$i"} = "0--";
        $form->{"tax_$i"}      = 0;
      }
      if (!$form->{"korrektur_$i"}) {
        ($taxkey, $rate) = split(/--/, $form->{"taxchart_$i"});
        if ($taxkey > 1) {
          if ($debitcredit) {
            $debittax = 1;
          } else {
            $credittax = 1;
          }
          if ($form->{taxincluded}) {
            $form->{"tax_$i"} = $amount / ($rate + 1) * $rate;
            if ($debitcredit) {
              $form->{"debit_$i"} = $form->{"debit_$i"} - $form->{"tax_$i"};
            } else {
              $form->{"credit_$i"} = $form->{"credit_$i"} - $form->{"tax_$i"};
            }
          } else {
            $form->{"tax_$i"} = $amount * $rate;
          }
        } else {
          $form->{"tax_$i"} = 0;
        }
      } elsif ($form->{taxincluded}) {
        if ($debitcredit) {
          $form->{"debit_$i"} = $form->{"debit_$i"} - $form->{"tax_$i"};
        } else {
          $form->{"credit_$i"} = $form->{"credit_$i"} - $form->{"tax_$i"};
        }
      }

      for (@flds) { $a[$j]->{$_} = $form->{"${_}_$i"} }
      $count++;
    }
  }

  for $i (1 .. $count) {
    $j = $i - 1;
    for (@flds) { $form->{"${_}_$i"} = $a[$j]->{$_} }
  }

  for $i ($count + 1 .. $form->{rowcount}) {
    for (@flds) { delete $form->{"${_}_$i"} }
  }

  for $i (1 .. $form->{rowcount}) {
    $dr  = $form->{"debit_$i"};
    $cr  = $form->{"credit_$i"};
    $tax = $form->{"tax_$i"};
    if ($dr && $cr) {
      $form->error(
        $locale->text(
          'Cannot post transaction with a debit and credit entry for the same account!'
        ));
    }
    if ($form->{taxincluded}) {
      if ($dr) {
        $debit += $dr + $tax;
      }
      if ($cr) {
        $credit += $cr + $tax;
      }
      $taxtotal += $tax;
    } else {
      if ($dr) {
        $debit += $dr + $tax;
      }
      if ($cr) {
        $credit += $cr + $tax;
      }
    }
  }
  if (!$taxtotal) {
    $form->{taxincluded} = 0;
  }

  # this is just for the wise guys
  $form->error($locale->text('Cannot post transaction for a closed period!'))
    if ($transdate <= $closedto);
  if ($form->round_amount($debit, 2) != $form->round_amount($credit, 2)) {
    $form->error($locale->text('Out of balance transaction!'));
  }
  if (($errno = GL->post_transaction(\%myconfig, \%$form)) <= -1) {
    $errno *= -1;
    $err[1] = $locale->text('Cannot have a value in both Debit and Credit!');
    $err[2] = $locale->text('Debit and credit out of balance!');
    $err[3] = $locale->text('Cannot post a transaction without a value!');

    $form->error($err[$errno]);
  }
  undef($form->{callback});
  $form->redirect("Buchung gespeichert. Buchungsnummer = " . $form->{id});
  $lxdebug->leave_sub();

}

sub post_as_new {
  $lxdebug->enter_sub();

  $form->{id} = 0;
  &add;
  $lxdebug->leave_sub();

}

sub storno {
  $lxdebug->enter_sub();

  $form->{id}     = 0;
  $form->{storno} = 1;
  &post;
  $lxdebug->leave_sub();

}

