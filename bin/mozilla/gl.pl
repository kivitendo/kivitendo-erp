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

use Data::Dumper;

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
  
  $form->{callback} = "$form->{script}?action=add&path=$form->{path}&login=$form->{login}&password=$form->{password}" unless $form->{callback};

  # we use this only to set a default date
  GL->transaction(\%myconfig, \%$form);

  map { $chart .= "<option value=\"$_->{accno}--$_->{taxkey_id}\">$_->{accno}--$_->{description}</option>" } @{ $form->{chart} };
  map { $tax .= qq|<option value="$_->{taxkey}--$_->{rate}">$_->{taxdescription}  |.($_->{rate} * 100).qq| %|} @{ $form->{TAX} };
  
  $form->{chart} = $chart;

  $form->{debitchart} = $chart;
  $form->{creditchart} = $chart;
  $form->{taxchart} = $tax;
  
  $form->{debit} = 0;
  $form->{credit} = 0;
  $form->{tax} = 0;
  
  $form->{creditrowcount} = 2;
  $form->{debitrowcount} = 2;
  

  # departments
  $form->all_departments(\%myconfig);
  if (@{ $form->{all_departments} }) {
    $form->{selectdepartment} = "<option>\n";

    map { $form->{selectdepartment} .= "<option>$_->{description}--$_->{id}\n" } (@{ $form->{all_departments} });
  }
 
  &display_form;
  
  $lxdebug->leave_sub();
}


sub edit {
  $lxdebug->enter_sub();

  GL->transaction(\%myconfig, \%$form);

  map { if ($form->{debitaccno} eq $_->{accno}) {$form->{debitchart} .= "<option value=\"$_->{accno}--$_->{taxkey_id}\">$_->{accno}--$_->{description}"} } @{ $form->{chart} };
  map { if ($form->{creditaccno} eq $_->{accno}) {$form->{creditchart} .= "<option value=\"$_->{accno}--$_->{taxkey_id}\">$_->{accno}--$_->{description}"} } @{ $form->{chart} };
  map { $tax .= qq|<option value="$_->{taxkey}--$_->{rate}">$_->{taxdescription}  |.($_->{rate} * 100).qq| %|} @{ $form->{TAX} };
  
  if ($form->{creditrowcount} > 2) {
    for $i (2 .. $form->{creditrowcount}) {
      map { if ($form->{"creditchartselected_$i"} eq $_->{accno}) {$form->{"creditchartselected_$i"} = "$_->{accno}--$_->{taxkey_id}" }} @{ $form->{chart} };
      map { if ($form->{"taxchartselected_$i"} eq $_->{taxkey}) {$form->{"taxchartselected_$i"} = "$_->{taxkey}--$_->{rate}" }} @{ $form->{TAX} };
    }
  }
  if ($form->{debitrowcount} > 2) {
    for $i (2 .. $form->{debitrowcount}) {
      map { if ($form->{"debitchartselected_$i"} eq $_->{accno}) {$form->{"debitchartselected_$i"} = "$_->{accno}--$_->{taxkey_id}" }} @{ $form->{chart} };
      map { if ($form->{"taxchartselected_$i"} eq $_->{taxkey}) {$form->{"taxchartselected_$i"} = "$_->{taxkey}--$_->{rate}" }} @{ $form->{TAX} };
    }
  }
  map { $chart .= "<option value=\"$_->{accno}--$_->{taxkey_id}\">$_->{accno}--$_->{description}</option>" } @{ $form->{chart} };  
  $form->{chart} = $chart;
  map { $tax .= qq|<option value="$_->{taxkey}--$_->{rate}">$_->{taxdescription}  |.($_->{rate} * 100).qq| %|} @{ $form->{TAX} };
  $form->{taxchart} = $tax;
  
  if ($form->{tax} < 0) {
    $form->{tax} = $form->{tax} * (-1);
  }
  
  $form->{amount}=$form->format_amount(\%myconfig, $form->{amount}, 2);
  
  # departments
  $form->all_departments(\%myconfig);
  if (@{ $form->{all_departments} }) {
    $form->{selectdepartment} = "<option>\n";

    map { $form->{selectdepartment} .= "<option>$_->{description}--$_->{id}\n" } (@{ $form->{all_departments} });
  }
 
  $form->{locked} = ($form->datetonum($form->{transdate}, \%myconfig) <= $form->datetonum($form->{closedto}, \%myconfig));

  $form->{title} = "Edit";
  
  &form_header;


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

    map { $form->{selectdepartment} .= "<option>$_->{description}--$_->{id}\n" } (@{ $form->{all_departments} });
  }
 
  $department = qq|
  	<tr>
	  <th align=right nowrap>|.$locale->text('Department').qq|</th>
	  <td colspan=3><select name=department>$form->{selectdepartment}</select></td>
	</tr>
| if $form->{selectdepartment};
  
  # use JavaScript Calendar or not
  $form->{jsscript} = $jscalendar;
  $jsscript = "";
  if ($form->{jsscript}) 
  {
    # with JavaScript Calendar
    $button1 = qq|
       <td><input name=datefrom id=datefrom size=11 title="$myconfig{dateformat}">
       <input type=button name=datefrom id="trigger1" value=|.$locale->text('button').qq|></td>  
       |;
     $button2 = qq|
       <td><input name=dateto id=dateto size=11 title="$myconfig{dateformat}">
       <input type=button name=dateto id="trigger2" value=|.$locale->text('button').qq|></td>
     |;
     #write Trigger
     $jsscript = Form->write_trigger(\%myconfig,"2","datefrom","BR","trigger1","dateto","BL","trigger2");
   }
   else
   {
      # without JavaScript Calendar
      $button1 = qq|<td><input name=datefrom id=datefrom size=11 title="$myconfig{dateformat}"></td>|;
      $button2 = qq|<td><input name=dateto id=dateto size=11 title="$myconfig{dateformat}"></td>|;
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
	  <th align=right>|.$locale->text('Reference').qq|</th>
	  <td><input name=reference size=20></td>
	  <th align=right>|.$locale->text('Source').qq|</th>
	  <td><input name=source size=20></td>
	</tr>
	$department
	<tr>
	  <th align=right>|.$locale->text('Description').qq|</th>
	  <td colspan=3><input name=description size=40></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Notes').qq|</th>
	  <td colspan=3><input name=notes size=40></td>
	</tr>
	<tr>
	  <th align=right>|.$locale->text('From').qq|</th>
          $button1
          $button2
	</tr>
	<tr>
	  <th align=right>|.$locale->text('Include in Report').qq|</th>
	  <td colspan=3>
	    <table>
	      <tr>
		<td>
		  <input name="category" class=radio type=radio value=X checked>&nbsp;|.$locale->text('All').qq|
		  <input name="category" class=radio type=radio value=A>&nbsp;|.$locale->text('Asset').qq|
       		  <input name="category" class=radio type=radio value=L>&nbsp;|.$locale->text('Liability').qq|
		  <input name="category" class=radio type=radio value=I>&nbsp;|.$locale->text('Revenue').qq|
		  <input name="category" class=radio type=radio value=E>&nbsp;|.$locale->text('Expense').qq|
		</td>
	      </tr>
	      <tr>
		<table>
		  <tr>
		    <td align=right><input name="l_id" class=checkbox type=checkbox value=Y></td>
		    <td>|.$locale->text('ID').qq|</td>
		    <td align=right><input name="l_transdate" class=checkbox type=checkbox value=Y checked></td>
		    <td>|.$locale->text('Date').qq|</td>
		    <td align=right><input name="l_reference" class=checkbox type=checkbox value=Y checked></td>
		    <td>|.$locale->text('Reference').qq|</td>
		    <td align=right><input name="l_description" class=checkbox type=checkbox value=Y checked></td>
		    <td>|.$locale->text('Description').qq|</td>
		    <td align=right><input name="l_notes" class=checkbox type=checkbox value=Y></td>
		    <td>|.$locale->text('Notes').qq|</td>
		  </tr>
		  <tr>
		    <td align=right><input name="l_debit" class=checkbox type=checkbox value=Y checked></td>
		    <td>|.$locale->text('Debit').qq|</td>
		    <td align=right><input name="l_credit" class=checkbox type=checkbox value=Y checked></td>
		    <td>|.$locale->text('Credit').qq|</td>
		    <td align=right><input name="l_source" class=checkbox type=checkbox value=Y checked></td>
		    <td>|.$locale->text('Source').qq|</td>
		    <td align=right><input name="l_accno" class=checkbox type=checkbox value=Y checked></td>
		    <td>|.$locale->text('Account').qq|</td>
		    <td align=right><input name="l_gifi_accno" class=checkbox type=checkbox value=Y></td>
		    <td>|.$locale->text('GIFI').qq|</td>
		  </tr>
		  <tr>
		    <td align=right><input name="l_subtotal" class=checkbox type=checkbox value=Y></td>
		    <td>|.$locale->text('Subtotal').qq|</td>
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
<input class=submit type=submit name=action value="|.$locale->text('Continue').qq|">
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
  
  $callback = "$form->{script}?action=generate_report&path=$form->{path}&login=$form->{login}&password=$form->{password}";

  $href = $callback;
  
  %acctype = ( 'A' => $locale->text('Asset'),
               'C' => $locale->text('Contra'),
               'L' => $locale->text('Liability'),
	       'Q' => $locale->text('Equity'),
	       'I' => $locale->text('Revenue'),
	       'E' => $locale->text('Expense'),
	     );
  
  $form->{title} = $locale->text('General Ledger');
  
  $ml = ($form->{ml} =~ /(A|E)/) ? -1 : 1;

  unless ($form->{category} eq 'X') {
    $form->{title} .= " : ".$locale->text($acctype{$form->{category}});
  }
  if ($form->{accno}) {
    $href .= "&accno=".$form->escape($form->{accno});
    $callback .= "&accno=".$form->escape($form->{accno},1);
    $option = $locale->text('Account')." : $form->{accno} $form->{account_description}";
  }
  if ($form->{gifi_accno}) {
    $href .= "&gifi_accno=".$form->escape($form->{gifi_accno});
    $callback .= "&gifi_accno=".$form->escape($form->{gifi_accno},1);
    $option .= "\n<br>" if $option;
    $option .= $locale->text('GIFI')." : $form->{gifi_accno} $form->{gifi_account_description}";
  }
  if ($form->{source}) {
    $href .= "&source=".$form->escape($form->{source});
    $callback .= "&source=".$form->escape($form->{source},1);
    $option .= "\n<br>" if $option;
    $option .= $locale->text('Source')." : $form->{source}";
  }
  if ($form->{reference}) {
    $href .= "&reference=".$form->escape($form->{reference});
    $callback .= "&reference=".$form->escape($form->{reference},1);
    $option .= "\n<br>" if $option;
    $option .= $locale->text('Reference')." : $form->{reference}";
  }
  if ($form->{department}) {
    $href .= "&department=".$form->escape($form->{department});
    $callback .= "&department=".$form->escape($form->{department},1);
    ($department) = split /--/, $form->{department};
    $option .= "\n<br>" if $option;
    $option .= $locale->text('Department')." : $department";
  }

  if ($form->{description}) {
    $href .= "&description=".$form->escape($form->{description});
    $callback .= "&description=".$form->escape($form->{description},1);
    $option .= "\n<br>" if $option;
    $option .= $locale->text('Description')." : $form->{description}";
  }
  if ($form->{notes}) {
    $href .= "&notes=".$form->escape($form->{notes});
    $callback .= "&notes=".$form->escape($form->{notes},1);
    $option .= "\n<br>" if $option;
    $option .= $locale->text('Notes')." : $form->{notes}";
  }
   
  if ($form->{datefrom}) {
    $href .= "&datefrom=$form->{datefrom}";
    $callback .= "&datefrom=$form->{datefrom}";
    $option .= "\n<br>" if $option;
    $option .= $locale->text('From')." ".$locale->date(\%myconfig, $form->{datefrom}, 1);
  }
  if ($form->{dateto}) {
    $href .= "&dateto=$form->{dateto}";
    $callback .= "&dateto=$form->{dateto}";
    if ($form->{datefrom}) {
      $option .= " ";
    } else {
      $option .= "\n<br>" if $option;
    }
    $option .= $locale->text('Bis')." ".$locale->date(\%myconfig, $form->{dateto}, 1);
  }


  @columns = $form->sort_columns(qw(transdate id reference description notes source debit debit_accno credit credit_accno debit_tax debit_tax_accno credit_tax credit_tax_accno accno gifi_accno));

  if ($form->{accno} || $form->{gifi_accno}) {
    @columns = grep !/(accno|gifi_accno)/, @columns;
    push @columns, "balance";
    $form->{l_balance} = "Y";
 
 }
  
  $form->{l_credit_accno} = "Y";
  $form->{l_debit_accno} = "Y";
  $form->{l_credit_tax} = "Y";
  $form->{l_debit_tax} = "Y";
  $form->{l_credit_tax_accno} = "Y";
  $form->{l_debit_tax_accno} = "Y";
  $form->{l_accno} = "N";
  foreach $item (@columns) {
    if ($form->{"l_$item"} eq "Y") {
      push @column_index, $item;

      # add column to href and callback
      $callback .= "&l_$item=Y";
      $href .= "&l_$item=Y";
    }
  }

  if ($form->{l_subtotal} eq 'Y') {
    $callback .= "&l_subtotal=Y";
    $href .= "&l_subtotal=Y";
  }

  $callback .= "&category=$form->{category}";
  $href .= "&category=$form->{category}";

  $column_header{id} = "<th><a class=listheading href=$href&sort=id>".$locale->text('ID')."</a></th>";
  $column_header{transdate} = "<th><a class=listheading href=$href&sort=transdate>".$locale->text('Date')."</a></th>";
  $column_header{reference} = "<th><a class=listheading href=$href&sort=reference>".$locale->text('Reference')."</a></th>";
  $column_header{source} = "<th><a class=listheading href=$href&sort=source>".$locale->text('Source')."</a></th>";
  $column_header{description} = "<th><a class=listheading href=$href&sort=description>".$locale->text('Description')."</a></th>";
  $column_header{notes} = "<th class=listheading>".$locale->text('Notes')."</th>";
  $column_header{debit} = "<th class=listheading>".$locale->text('Debit')."</th>";
  $column_header{debit_accno} = "<th><a class=listheading href=$href&sort=accno>".$locale->text('Debit Account')."</a></th>";
  $column_header{credit} = "<th class=listheading>".$locale->text('Credit')."</th>";
  $column_header{credit_accno} = "<th><a class=listheading href=$href&sort=accno>".$locale->text('Credit Account')."</a></th>";
  $column_header{debit_tax} = "<th><a class=listheading href=$href&sort=accno>".$locale->text('Debit Tax')."</a></th>";
  $column_header{debit_tax_accno} = "<th><a class=listheading href=$href&sort=accno>".$locale->text('Debit Tax Account')."</a></th>";
  $column_header{credit_tax} = "<th><a class=listheading href=$href&sort=accno>".$locale->text('Credit Tax')."</a></th>";
  $column_header{credit_tax_accno} = "<th><a class=listheading href=$href&sort=accno>".$locale->text('Credit Tax Account')."</a></th>";
  $column_header{gifi_accno} = "<th><a class=listheading href=$href&sort=gifi_accno>".$locale->text('GIFI')."</a></th>";
  $column_header{balance} = "<th>".$locale->text('Balance')."</th>";
  
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
    $sameitem = $form->{GL}->[0]->{$form->{sort}};
  }
  
  if (($form->{accno} || $form->{gifi_accno}) && $form->{balance}) {

    map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;
    $column_data{balance} = "<td align=right>".$form->format_amount(\%myconfig, $form->{balance} * $ml, 2, 0)."</td>";
    
    $i++; $i %= 2;
    print qq|
        <tr class=listrow$i>
|;
    map { print "$column_data{$_}\n" } @column_index;
    
    print qq|
        </tr>
|;
  }
    
  foreach $ref (@{ $form->{GL} }) {

    # if item ne sort print subtotal
    if ($form->{l_subtotal} eq 'Y') {
      if ($sameitem ne $ref->{$form->{sort}}) {
	&gl_subtotal;
      }
    }
    foreach $key (sort keys (%{$ref->{amount}})) {
      $form->{balance} += $ref->{amount}{$key};
    }
    
    $debit = "";
    foreach $key (sort keys (%{$ref->{debit}})) {
      $subtotaldebit += $ref->{debit}{$key};
      $totaldebit += $ref->{debit}{$key};
      if ($key == 0) {
        $debit = $form->format_amount(\%myconfig, $ref->{debit}{$key} , 2, 0);
      } else {
        $debit .= "<br>".$form->format_amount(\%myconfig, $ref->{debit}{$key} , 2, 0);
      }
    }
    
    $credit = "";
    foreach $key (sort keys (%{$ref->{credit}})) {
      $subtotalcredit += $ref->{credit}{$key};
      $totalcredit += $ref->{credit}{$key};
      if ($key == 0) {
        $credit = $form->format_amount(\%myconfig, $ref->{credit}{$key} , 2, 0);
      } else {
        $credit .= "<br>".$form->format_amount(\%myconfig, $ref->{credit}{$key} , 2, 0);
      }      
    }
    
    $debittax = "";
    foreach $key (sort keys (%{$ref->{debit_tax}})) {
      $subtotaldebittax += $ref->{debit_tax}{$key};
      $totaldebittax += $ref->{debit_tax}{$key};
      if ($key == 0) {
        $debittax = $form->format_amount(\%myconfig, $ref->{debit_tax}{$key} , 2, 0);
      } else {
        $debittax .= "<br>".$form->format_amount(\%myconfig, $ref->{debit_tax}{$key} , 2, 0);
      }
    }
    
    $credittax = "";
    foreach $key (sort keys (%{$ref->{credit_tax}})) {
      $subtotalcredittax += $ref->{credit_tax}{$key};
      $totalcredittax += $ref->{credit_tax}{$key};
      if ($key == 0) {
        $credittax = $form->format_amount(\%myconfig, $ref->{credit_tax}{$key} , 2, 0);
      } else {
        $credittax .= "<br>".$form->format_amount(\%myconfig, $ref->{credit_tax}{$key} , 2, 0);
      }
    }
    
    $debitaccno = "";
    $debittaxkey = "";
    $taxaccno = "";
    foreach $key (sort keys (%{$ref->{debit_accno}})) {
      if ($key == 0) {
        $debitaccno = "<a href=$href&accno=$ref->{accno}&callback=$callback>$ref->{debit_accno}{$key}</a>";
      } else {
        $debitaccno .= "<br><a href=$href&accno=$ref->{accno}&callback=$callback>$ref->{debit_accno}{$key}</a>";
      }
      if ($ref->{debit_taxkey}{$key} eq $debittaxkey) {
        $ref->{debit_tax_accno}{$key} = $taxaccno;
      }      
      $taxaccno = $ref->{debit_tax_accno}{$key};
      $debittaxkey = $ref->{debit_taxkey}{$key};
    }
    
    $creditaccno = "";
    $credittaxkey = "";
    $taxaccno = "";
    foreach $key (sort keys (%{$ref->{credit_accno}})) {
      if ($key == 0) {
        $creditaccno = "<a href=$href&accno=$ref->{accno}&callback=$callback>$ref->{credit_accno}{$key}</a>";
      } else {
        $creditaccno .= "<br><a href=$href&accno=$ref->{accno}&callback=$callback>$ref->{credit_accno}{$key}</a>";
      }
      if ($ref->{credit_taxkey}{$key} eq $credittaxkey) {
        $ref->{credit_tax_accno}{$key} = $taxaccno;
      }
      $taxaccno = $ref->{credit_tax_accno}{$key};
      $credittaxkey = $ref->{credit_taxkey}{$key};
    }    
    
    $debittaxaccno = "";
    foreach $key (sort keys (%{$ref->{debit_tax_accno}})) {
      if ($key == 0) {
        $debittaxaccno = "<a href=$href&accno=$ref->{accno}&callback=$callback>$ref->{debit_tax_accno}{$key}</a>";
      } else {
        $debittaxaccno .= "<br><a href=$href&accno=$ref->{accno}&callback=$callback>$ref->{debit_tax_accno}{$key}</a>";
      }
    }
    
    $credittaxaccno = "";
    foreach $key (sort keys (%{$ref->{credit_tax_accno}})) {
      if ($key == 0) {
        $credittaxaccno = "<a href=$href&accno=$ref->{accno}&callback=$callback>$ref->{credit_tax_accno}{$key}</a>";
      } else {
        $credittaxaccno .= "<br><a href=$href&accno=$ref->{accno}&callback=$callback>$ref->{credit_tax_accno}{$key}</a>";
      }
    }    
#    $ref->{debit} = $form->format_amount(\%myconfig, $ref->{debit}, 2, "&nbsp;");
#    $ref->{credit} = $form->format_amount(\%myconfig, $ref->{credit}, 2, "&nbsp;");
    
    $column_data{id} = "<td align=right>&nbsp;$ref->{id}&nbsp;</td>";
    $column_data{transdate} = "<td align=center>&nbsp;$ref->{transdate}&nbsp;</td>";
    $column_data{reference} = "<td align=center><a href=$ref->{module}.pl?action=edit&id=$ref->{id}&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback>$ref->{reference}</td>";
    $column_data{description} = "<td align=center>$ref->{description}&nbsp;</td>";
    $column_data{source} = "<td align=center>$ref->{source}&nbsp;</td>";
    $column_data{notes} = "<td align=center>$ref->{notes}&nbsp;</td>";
    $column_data{debit} = "<td align=right>$debit</td>";
    $column_data{debit_accno} = "<td align=center>$debitaccno</td>";
    $column_data{credit} = "<td align=right>$credit</td>";
    $column_data{credit_accno} = "<td align=center>$creditaccno</td>";
    $column_data{debit_tax} = ($ref->{debit_tax_accno} ne "") ? "<td align=right>$debittax</td>" : "<td></td>";
    $column_data{debit_tax_accno} = "<td align=center>$debittaxaccno</td>";
    $column_data{gifi_accno} = "<td><a href=$href&gifi_accno=$ref->{gifi_accno}&callback=$callback>$ref->{gifi_accno}</a>&nbsp;</td>";
    $column_data{credit_tax} = ($ref->{credit_tax_accno} ne "") ? "<td align=right>$credittax</td>" : "<td></td>";
    $column_data{credit_tax_accno} = "<td align=center>$credittaxaccno</td>";
    $column_data{gifi_accno} = "<td><a href=$href&gifi_accno=$ref->{gifi_accno}&callback=$callback>$ref->{gifi_accno}</a>&nbsp;</td>";
    $column_data{balance} = "<td align=right>".$form->format_amount(\%myconfig, $form->{balance} * $ml, 2, 0)."</td>";

    $i++; $i %= 2;
    print "
        <tr class=listrow$i>";
    map { print "$column_data{$_}\n" } @column_index;
    print "</tr>";
    
  }


  &gl_subtotal if ($form->{l_subtotal} eq 'Y');


  map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;
  
  $column_data{debit} = "<th align=right class=listtotal>".$form->format_amount(\%myconfig, $totaldebit, 2, "&nbsp;")."</th>";
  $column_data{credit} = "<th align=right class=listtotal>".$form->format_amount(\%myconfig, $totalcredit, 2, "&nbsp;")."</th>";
  $column_data{debit_tax} = "<th align=right class=listtotal>".$form->format_amount(\%myconfig, $totaldebittax, 2, "&nbsp;")."</th>";
  $column_data{credit_tax} = "<th align=right class=listtotal>".$form->format_amount(\%myconfig, $totalcredittax, 2, "&nbsp;")."</th>";
  $column_data{balance} = "<th align=right class=listtotal>".$form->format_amount(\%myconfig, $form->{balance} * $ml, 2, 0)."</th>";
  
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

<input class=submit type=submit name=action value="|.$locale->text('GL Transaction').qq|">
<input class=submit type=submit name=action value="|.$locale->text('AR Transaction').qq|">
<input class=submit type=submit name=action value="|.$locale->text('AP Transaction').qq|">
<input class=submit type=submit name=action value="|.$locale->text('Sales Invoice').qq|">
<input class=submit type=submit name=action value="|.$locale->text('Vendor Invoice').qq|">|;


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
      
  $subtotaldebit = $form->format_amount(\%myconfig, $subtotaldebit, 2, "&nbsp;");
  $subtotalcredit = $form->format_amount(\%myconfig, $subtotalcredit, 2, "&nbsp;");
  
  map { $column_data{$_} = "<td>&nbsp;</td>" } qw(transdate id reference source description accno);
  $column_data{debit} = "<th align=right>$subtotaldebit</td>";
  $column_data{credit} = "<th align=right>$subtotalcredit</td>";

  
  print "<tr class=listsubtotal>";
  map { print "$column_data{$_}\n" } @column_index;
  print "</tr>";

  $subtotaldebit = 0;
  $subtotalcredit = 0;

  $sameitem = $ref->{$form->{sort}};

  $lxdebug->leave_sub();

  return $sameitem;
}


sub update {
  $lxdebug->enter_sub();

  @a = ();
  $count = 0;
  @flds = (qw(accno debit credit projectnumber project_id oldprojectnumber));
  $credit_save = $form->{credit};
  $debit_save = $form->{debit};
  
  if ($form->{chart} eq "") {
    $form->{creditchart} = "<option>".$form->{creditchartselected}."</option>";
    $form->{debitchart} = "<option>".$form->{debitchartselected}."</option>";
  } else {
	$form->{creditchart} = $form->{chart};
	$form->{creditchart}  =~ s/value=\"$form->{creditchartselected}\"/value=\"$form->{creditchartselected}\" selected/;
	
	$form->{debitchart} = $form->{chart};
	$form->{debitchart}  =~ s/value=\"$form->{debitchartselected}\"/value=\"$form->{debitchartselected}\" selected/;
  }
  ($debitaccno, $debittaxkey) = split(/--/, $form->{debitchartselected});  
  ($creditaccno, $credittaxkey) = split(/--/, $form->{creditchartselected});
  if ($debittaxkey >0) {  
	$form->{taxchart} = $form->unescape($form->{taxchart});
	$form->{taxchart} =~ s/selected//ig;
	$form->{taxchart} =~ s/\"$debittaxkey--([^\"]*)\"/\"$debittaxkey--$1\" selected/;
	
	$rate = $1;
	
	if ($form->{taxincluded}) {
		$form->{debit} = $form->parse_amount(\%myconfig, $form->{amount}) / ($rate + 1);
		$form->{credit} = $form->parse_amount(\%myconfig, $form->{amount}) * 1;
		$form->{tax} = $form->parse_amount(\%myconfig, $form->{amount}) / ($rate + 1) * $rate;
	} else {
		$form->{debit} = $form->parse_amount(\%myconfig, $form->{amount}) * 1;
		$form->{credit} = $form->parse_amount(\%myconfig, $form->{amount}) * ($rate + 1);
		$form->{tax} = $form->parse_amount(\%myconfig, $form->{amount}) * $rate;
	}
  } else {
		$form->{taxchart} = $form->unescape($form->{taxchart});
		$form->{taxchart} =~ s/selected//ig;
		$form->{taxchart} =~ s/\"$credittaxkey--([^\"]*)\"/\"$credittaxkey--$1\" selected/;
		$rate = $1;
		
		if ($form->{taxincluded}) {
			$form->{debit} = $form->parse_amount(\%myconfig, $form->{amount}) * 1;
			$form->{credit} = $form->parse_amount(\%myconfig, $form->{amount}) / ($rate + 1);
			$form->{tax} = $form->parse_amount(\%myconfig, $form->{amount}) / ($rate + 1) * $rate;
		} else {
			$form->{debit} = $form->parse_amount(\%myconfig, $form->{amount}) * ($rate + 1);
			$form->{credit} = $form->parse_amount(\%myconfig, $form->{amount}) * 1;
			$form->{tax} = $form->parse_amount(\%myconfig, $form->{amount}) * $rate;
		}
	}
  if ($form->{credit_splited}) {   
    $form->{debit} = $form->parse_amount(\%myconfig, $form->{amount}) * 1;
    $form->{credit} = $credit_save;
    $form->{tax} = 0;
  } elsif ($form->{debit_splited}) {
    $form->{credit} = $form->parse_amount(\%myconfig, $form->{amount}) * 1;
    $form->{debit} = $debit_save;
    $form->{tax} = 0;
  }
  &check_project;

  &display_form;
  
  $lxdebug->leave_sub();
}


sub display_form {
  $lxdebug->enter_sub();


  &form_header;
#   for $i (1 .. $form->{rowcount}) {
#     $form->{totaldebit} += $form->parse_amount(\%myconfig, $form->{"debit_$i"});
#     $form->{totalcredit} += $form->parse_amount(\%myconfig, $form->{"credit_$i"});
#  
#     &form_row($i);
#   }

  &form_footer;

  $lxdebug->leave_sub();
}




sub form_header {
  $lxdebug->enter_sub();

  $title = $form->{title};
  $form->{title} = $locale->text("$title General Ledger Transaction");
  $readonly = ($form->{id}) ? "readonly" : "";
  
  $form->{urldebit} = "$form->{script}?action=split_debit&path=$form->{path}&login=$form->{login}&password=$form->{password}";
  $form->{urlcredit} = "$form->{script}?action=split_credit&path=$form->{path}&login=$form->{login}&password=$form->{password}";
# $locale->text('Add General Ledger Transaction')
# $locale->text('Edit General Ledger Transaction')
  map { $form->{$_} =~ s/\"/&quot;/g } qw(reference description chart);

  $form->{selectdepartment} =~ s/ selected//;
  $form->{taxchart} =~ s/ selected//;
  $form->{selectdepartment} =~ s/option>\Q$form->{department}\E/option selected>$form->{department}/;

  if (($rows = $form->numtextrows($form->{description}, 50)) > 1) {
    $description = qq|<textarea name=description rows=$rows cols=50 wrap=soft $readonly >$form->{description}</textarea>|;
  } else {
    $description = qq|<input name=description size=50 value="$form->{description}" tabindex="3" $readonly>|;
  }
  
  $taxincluded = ($form->{taxincluded}) ? "checked" : "";
  
  if (!$form->{id}) {
  	$taxincluded = "checked";
  }
  
  $amount = qq|<input name=amount size=20 value="$form->{amount}" tabindex="4" $readonly>|;
  
  
  $department = qq|
  	<tr>
	  <th align=right nowrap>|.$locale->text('Department').qq|</th>
	  <td colspan=3><select name=department>$form->{selectdepartment}</select></td>
	  <input type=hidden name=selectdepartment value="$form->{selectdepartment}">
	</tr>
| if $form->{selectdepartment};

  $form->{fokus} = "gl.reference";
  $form->{remote} = 1;
  
  # use JavaScript Calendar or not
  $form->{jsscript} = $jscalendar;
  $jsscript = "";
  if ($form->{jsscript}) 
  {
    # with JavaScript Calendar
    $button1 = qq|
       <td><input name=transdate id=transdate size=11 title="$myconfig{dateformat}" value=$form->{transdate} tabindex="2" $readonly></td>
       <td><input type=button name=transdate id="trigger1" value=|.$locale->text('button').qq|></td>  
       |;
   #write Trigger
   $jsscript = Form->write_trigger(\%myconfig,"1","transdate","BL","trigger1","","","");
   }
   else
   {
      # without JavaScript Calendar
      $button1 = qq|<td><input name=transdate id=transdate size=11 title="$myconfig{dateformat}" value=$form->{transdate} tabindex="2" $readonly></td>|;
    }
    
  $form->header;

  
  print qq|
<body onLoad="fokus()">

<form method=post name="gl" action=$form->{script}>

<input name=id type=hidden value=$form->{id}>

<input type=hidden name=closedto value=$form->{closedto}>
<input type=hidden name=locked value=$form->{locked}>
<input type=hidden name=title value="$title">
<input type=hidden name=taxchart value=|.$form->escape($form->{taxchart}).qq|>
<input type=hidden name=chart value="$form->{chart}">
<input type=hidden name=creditrowcount value="$form->{creditrowcount}">
<input type=hidden name=debitrowcount value="$form->{debitrowcount}">


<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
	<tr>
	  <th align=right>|.$locale->text('Reference').qq|</th>
	  <td><input name=reference size=20 value="$form->{reference}" tabindex="1" $readonly></td>
	  <td align=left>
	    <table width=100%>
	      <tr>
		<th align=right nowrap>|.$locale->text('Date').qq|</th>
                $button1
	      </tr>
	    </table>
	  </td>
	</tr>|;
if ($form->{id}) {
	print qq|
	<tr>
	  <th align=right>|.$locale->text('Belegnummer').qq|</th>
	  <td><input name=id size=20 value="$form->{id}" $readonly></td>
	  <td align=left>
	  <table width=100%>
	      <tr>
		<th align=right width=50%>|.$locale->text('Buchungsdatum').qq|</th>
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
	  <th align=right>|.$locale->text('Description').qq|</th>
	  <td>$description</td>
	  <td align=left>
	    <table width=100%>
	      <tr>
		<th align=right width=50%>|.$locale->text('Mitarbeiter').qq|</th>
		<td align=left><input name=employee size=11  value=$form->{employee} $readonly></td>
	      </tr>
	    </table>
	  </td>
	</tr>|;	
	} else {
	print qq|
	<tr>
	  <th align=right>|.$locale->text('Description').qq|</th>
	  <td colspan=3>$description</td>
	</tr>|;
	}
	print qq|
	<tr>
	  <th align=right>|.$locale->text('Betrag').qq|</th>
	  <td>$amount</td>
	  <td align=left colspan=2>
	    <table>
	      <tr>
		<th align=left>|.$locale->text('MwSt. inkl.').qq|</th>
		<td><input type=checkbox name=taxincluded value=1 tabindex="8" $taxincluded></td>
	      </tr>
	    </table>
	 </td>
	</tr>|;
        if ($form->{debit_splited}) {
        print qq|
	<tr>
	  <th align=right>|.$locale->text('Debit').qq|</th>
	  <td>Betrag gesplittet</td>
	  <td><input  name=debit size=10 value="|.$form->format_amount(\%myconfig, $form->{debit}, 2).qq|" readonly> EUR</td>
          <td><input class=submit type=submit name=action value="|.$locale->text('Split Debit').qq|"></td>
          <input  name=debit_splited type=hidden size=10 value=$form->{debit_splited}>
	</tr>
        <tr>
          <th align=right>|.$locale->text('Credit').qq|</th>
	  <td><select name=creditchartselected tabindex="6">$form->{creditchart}</select></td>
	  <td><input name=credit size=10 value="|.$form->format_amount(\%myconfig, $form->{credit},2).qq|" readonly > EUR</td>
          <input  name=credit_splited type=hidden size=10 value=$form->{credit_splited}>
        </tr>
        |;
        } elsif ($form->{credit_splited}) {
          print qq|
          <tr>
	  <th align=right>|.$locale->text('Debit').qq|</th>
	  <td><select name=debitchartselected tabindex="6">$form->{debitchart}</select></td>
	  <td><input  name=debit size=10 value="|.$form->format_amount(\%myconfig, $form->{debit}, 2).qq|" readonly> EUR</td>
          <input  name=debit_splited type=hidden size=10 value=$form->{debit_splited}>
	  </tr>
          <tr>
          <th align=right>|.$locale->text('Credit').qq|</th>
          <td>Betrag gesplittet</td>
	  <td><input name=credit size=10 value="|.$form->format_amount(\%myconfig, $form->{credit},2).qq|" readonly > EUR</td>
          <td><input class=submit type=submit name=action value="|.$locale->text('Split Credit').qq|"></td>
          <input  name=credit_splited type=hidden size=10 value=$form->{credit_splited}>
          |;
        } else {
          print qq|
          <tr>
	  <th align=right>|.$locale->text('Debit').qq|</th>
	  <td><select name=debitchartselected tabindex="6">$form->{debitchart}</select></td>
	  <td><input  name=debit size=10 value="|.$form->format_amount(\%myconfig, $form->{debit}, 2).qq|" readonly> EUR</td>
          <td><input class=submit type=submit name=action value="|.$locale->text('Split Debit').qq|"></td>
          <input  name=debit_splited type=hidden size=10 value=$form->{debit_splited}>
	  </tr>          
          <tr>
	  <th align=right>|.$locale->text('Credit').qq|</th>
	  <td><select name=creditchartselected tabindex="6">$form->{creditchart}</select></td>
	  <td><input name=credit size=10 value="|.$form->format_amount(\%myconfig, $form->{credit},2).qq|" readonly > EUR</td>
          <td><input class=submit type=submit name=action value="|.$locale->text('Split Credit').qq|"></td>
          <input  name=credit_splited type=hidden size=10 value=$form->{credit_splited}>
	  </tr>
	  <tr>
	  <th align=right>|.$locale->text('Tax').qq|</th>
	  <td><select name=taxchartselected tabindex="7">$form->{taxchart}</select></td>
	  <td><input name=tax size=10 value="|.$form->format_amount(\%myconfig, $form->{tax},2).qq|" readonly > EUR</td>
          <td></td>
	  </tr>|;
        }
        print qq|
	</tr>      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
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
  $taxrowcount = ($form->{creditrowcount} > $form->{debitrowcount}) ? $form->{creditrowcount} : $form->{debitrowcount};
  $radieren = ($form->current_date(\%myconfig) eq $form->{gldate})? 1 : 0;

  map { $form->{$_} = $form->format_amount(\%myconfig, $form->{$_}, $decimalplaces, "&nbsp;") } qw(totaldebit totalcredit);
  
  print qq|
</table>
|;
  for $i (2 .. $form->{creditrowcount}) {
    print qq|
    <input type=hidden name=creditchartselected_$i value="$form->{"creditchartselected_$i"}">
    <input type=hidden name=credit_$i value="$form->{"credit_$i"}">
    |;
  }
  for $i (2 .. $form->{debitrowcount}) {
    print qq|
    <input type=hidden name=debitchartselected_$i value="$form->{"debitchartselected_$i"}">
    <input type=hidden name=debit_$i value="$form->{"debit_$i"}">
    |;
  }
  if ($taxrowcount > 1) {
   for $i (2 .. $taxrowcount) {
    print qq|
      <input type=hidden name=taxchartselected_$i value="$form->{"taxchartselected_$i"}">
      <input type=hidden name=tax_$i value="$form->{"tax_$i"}">
      |;
    }
  } 
print qq| 
<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input name=callback type=hidden value="$form->{callback}">
<br>
|;

  $transdate = $form->datetonum($form->{transdate}, \%myconfig);
  $closedto = $form->datetonum($form->{closedto}, \%myconfig);

  if ($form->{id}) {
  
  print qq|<input class=submit type=submit name=action value="|.$locale->text('Storno').qq|">|;

# Löschen und ändern von Buchungen nicht mehr möglich (GoB) nur am selben Tag möglich

 

	if (!$form->{locked} && $radieren) {
		print qq|
		<input class=submit type=submit name=action value="|.$locale->text('Post').qq|" accesskey="b">
		<input class=submit type=submit name=action value="|.$locale->text('Delete').qq|">|;
	}

	
# 	if ($transdate > $closedto) {
# 		print qq|
# 		<input class=submit type=submit name=action value="|.$locale->text('Post as new').qq|">|;
# 	}
   }  else {
    	if ($transdate > $closedto) {
      		print qq|<input class=submit type=submit name=action value="|.$locale->text('Update').qq|">
     		 <input class=submit type=submit name=action value="|.$locale->text('Post').qq|">|;
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
<h2 class=confirm>|.$locale->text('Confirm!').qq|</h2>

<h4>|.$locale->text('Are you sure you want to delete Transaction').qq| $form->{reference}</h4>

<input name=action class=submit type=submit value="|.$locale->text('Yes').qq|">
</form>
|;

  $lxdebug->leave_sub();
}


sub yes {
  $lxdebug->enter_sub();

  $form->redirect($locale->text('Transaction deleted!')) if (GL->delete_transaction(\%myconfig, \%$form));
  $form->error($locale->text('Cannot delete transaction!'));
  
  $lxdebug->leave_sub();
}


sub post {
  $lxdebug->enter_sub();
  # check if there is something in reference and date
  $form->isblank("reference", $locale->text('Reference missing!'));
  $form->isblank("transdate", $locale->text('Transaction Date missing!'));
  $form->isblank("description", $locale->text('Description missing!'));
  
  $transdate = $form->datetonum($form->{transdate}, \%myconfig);
  $closedto = $form->datetonum($form->{closedto}, \%myconfig);

  ($debitaccno, $debittaxkey) = split(/--/, $form->{debitchartselected});  
  ($creditaccno, $credittaxkey) = split(/--/, $form->{creditchartselected});
  
  $credit_save = $form->{credit};
  $debit_save = $form->{debit};    

  # check project
  &check_project;
  ($taxkey, $taxrate) = split(/--/, $form->{taxchartselected});    

  if ($debittaxkey >0) { 
	$form->{taxchart} = $form->unescape($form->{taxchart});
	$form->{taxchart} =~ s/\"$debittaxkey--([^\"]*)\"/\"$debittaxkey--$1\"/;
	
	$rate = ($form->{taxchart} =~ /selected/) ? $taxrate : $1;
	$form->{taxkey} = ($form->{taxchart} =~ /selected/) ? $taxkey : $debittaxkey;
	
	if ($form->{storno}) {
		$form->{debit} = $form->parse_amount(\%myconfig, $form->{debit});
		$form->{credit} = $form->parse_amount(\%myconfig, $form->{credit});
		$form->{tax} = $form->parse_amount(\%myconfig, $form->{tax});
	} else {
		if ($form->{taxincluded}) {
			$form->{debit} = $form->parse_amount(\%myconfig, $form->{amount}) / ($rate + 1);
			$form->{credit} = $form->parse_amount(\%myconfig, $form->{amount}) * 1;
			$form->{tax} = $form->parse_amount(\%myconfig, $form->{amount}) / ($rate + 1) * $rate;
		} else {
			$form->{debit} = $form->parse_amount(\%myconfig, $form->{amount}) * 1;
			$form->{credit} = $form->parse_amount(\%myconfig, $form->{amount}) * ($rate + 1);
			$form->{tax} = $form->parse_amount(\%myconfig, $form->{amount}) * $rate;
		}
	}	
	$form->{debittaxkey}=1;
	
  } else {
		$form->{taxchart} = $form->unescape($form->{taxchart});
		$form->{taxchart} =~ s/\"$credittaxkey--([^\"]*)\"/\"$credittaxkey--$1\"/;
		

		$rate = ($form->{taxchart} =~ /selected/) ? $taxrate : $1;
		$form->{taxkey} = ($form->{taxchart} =~ /selected/) ? $taxkey : $credittaxkey;
		
		if ($form->{storno}) {
			$form->{debit} = $form->parse_amount(\%myconfig, $form->{debit});
			$form->{credit} = $form->parse_amount(\%myconfig, $form->{credit});
			$form->{tax} = $form->parse_amount(\%myconfig, $form->{tax});
		} else {
			if ($form->{taxincluded}) {
				$form->{debit} = $form->parse_amount(\%myconfig, $form->{amount}) * 1;
				$form->{credit} = $form->parse_amount(\%myconfig, $form->{amount}) / ($rate + 1);
				$form->{tax} = $form->parse_amount(\%myconfig, $form->{amount}) / ($rate + 1) * $rate;
			} else {
				$form->{debit} = $form->parse_amount(\%myconfig, $form->{amount}) * ($rate + 1);
				$form->{credit} = $form->parse_amount(\%myconfig, $form->{amount}) * 1;
				$form->{tax} = $form->parse_amount(\%myconfig, $form->{amount}) * $rate;
			}
		}
		$form->{debittaxkey}=0;
		
	}
  if ($form->{credit_splited}) {
    $form->{debit} = $form->parse_amount(\%myconfig, $form->{amount}) * 1;
    $form->{credit} = $credit_save;
    $form->{tax} = 0;
  } elsif ($form->{debit_splited}) {
    $form->{credit} = $form->parse_amount(\%myconfig, $form->{amount}) * 1;
    $form->{debit} = $debit_save;
    $form->{tax} = 0;
  }
   

  # this is just for the wise guys
  $form->error($locale->text('Cannot post transaction for a closed period!')) if ($transdate <= $closedto);
  $form->error($locale->text('Soll- und Habenkonto sind gleich!')) if ($debitaccno eq $creditaccno);
  $form->error($locale->text('Keine Steuerautomatik möglich!')) if ($debittaxkey && $credittaxkey && !($taxkey == 0));  
  
  if (($errno = GL->post_transaction(\%myconfig, \%$form)) <= -1) {
    $errno *= -1;
    $err[1] = $locale->text('Cannot have a value in both Debit and Credit!');
    $err[2] = $locale->text('Debit and credit out of balance!');
    $err[3] = $locale->text('Cannot post a transaction without a value!');
    
    $form->error($err[$errno]);
  }
  undef($form->{callback});
  $form->redirect("Buchung gespeichert. Buchungsnummer = ".$form->{id});
  
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

  $form->{id} = 0;
  $form->{storno} =1;
  &post;

  $lxdebug->leave_sub();
}

sub split_debit {
  $lxdebug->enter_sub();
  # change callback
  $form->{old_callback} = $form->escape($form->{callback},1);
  $form->{callback} = $form->escape("$form->{script}?action=update",1);
  # delete action
  delete $form->{action};
  # save all other form variables in a previousform variable
  foreach $key (keys %$form) {
    # escape ampersands
    $form->{$key} =~ s/&/%26/g;
    $previousform .= qq|$key=$form->{$key}&|;
  }
  chop $previousform;
  $previousform = $form->escape($previousform, 1);
  if (!$form->{debitpost}) {
    $form->{debitpost} = $form->{amount};
  } 
  $form->{previousform} = $previousform;
  &display_split_debit();


  $lxdebug->leave_sub();
}

sub split_credit {
  $lxdebug->enter_sub();
  # change callback
  $form->{old_callback} = $form->escape($form->{callback},1);
  $form->{callback} = $form->escape("$form->{script}?action=update",1);
  # delete action
  delete $form->{action};
  # save all other form variables in a previousform variable
  foreach $key (keys %$form) {
    # escape ampersands
    $form->{$key} =~ s/&/%26/g;
    $previousform .= qq|$key=$form->{$key}&|;
  }
  chop $previousform;
  $previousform = $form->escape($previousform, 1);
  if (!$form->{creditpost}) {
    $form->{creditpost} = $form->{amount};
  } 
  $form->{previousform} = $previousform;
  &display_split_credit();
  $lxdebug->leave_sub();
}

sub display_split_credit {
  $lxdebug->enter_sub();
  $form->{taxchart} = $form->unescape($form->{taxchart});
    
  $form->header;

  print qq|
<body>
<form method=post name=split_credit action=gl.pl>
|.$locale->text('Credit').qq|: |.$form->format_amount(\%myconfig, $form->{amount},2).qq| EUR<br>
|.$locale->text('Still to post').qq|:<input name=creditpost size=10 value="|.$form->format_amount(\%myconfig, $form->{creditpost},2).qq|"> EUR<br>
<script type="text/javascript">
           function update_stilltopost (betrag){
           remaining = parseFloat(document.split_credit.creditpost.value) - parseFloat(betrag);
           document.split_credit.creditpost.value= remaining;
           }           
</script>

<table>|;
for $i (2 .. $form->{creditrowcount}) {
  $form->{"creditchart_$i"} = $form->{chart};
  $form->{"creditchart_$i"}  =~ s/value=\"$form->{"creditchartselected_$i"}\"/value=\"$form->{"creditchartselected_$i"}\" selected/;
  
  $form->{"taxchart_$i"} = $form->{taxchart};
  $form->{"taxchart_$i"}  =~ s/value=\"$form->{"taxchartselected_$i"}\"/value=\"$form->{"taxchartselected_$i"}\" selected/;
  $position = $i -1;
print qq|
  <tr><td></td></tr>
  <tr>
    <th>Position $position</th>
    <td><select name=creditchartselected_$i>$form->{"creditchart_$i"}</select></td>
    <th align=right>|.$locale->text('Amount').qq| $1</th>
    <td><input name=credit_$i size=10 value="|.$form->format_amount(\%myconfig, $form->{"credit_$i"},2).qq|" onBlur="update_stilltopost(this.value)"> EUR</td>
  </tr>
  <tr>
    <th></th>
    <td><select name=taxchartselected_$i>$form->{"taxchart_$i"}</select></td>
    <th align=right>|.$locale->text('Tax').qq|</th>
    <td><input name=tax_$i size=10 value="|.$form->format_amount(\%myconfig, $form->{"tax_$i"},2).qq|"> EUR</td>
    <td><input type=checkbox name=tax_manual_$i value=1> Steuerkorrektur</td>
  </tr>
  <td></td>
  <tr>
  </tr>
  <tr>
    <td colspan=5><hr size=3 noshade></td>
  </tr>

|;
}
print qq|
</table>
<input type=hidden name=previousform value="$form->{previousform}">

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>
<input type=hidden name=callback value=$form->{callback}>
<input type=hidden name=old_callback value=$form->{old_callback}>
<input type=hidden name=amount value=$form->{amount}>
<input type=hidden name=credit_splited value=1>
<input type=hidden name=creditrowcount value="$form->{creditrowcount}">
<input type=hidden name=chart value=|.$form->escape($form->{chart}).qq|>
<input type=hidden name=taxchart value=|.$form->escape($form->{taxchart}).qq|>
<p>
<input class=submit type=submit name=action value="|.$locale->text('New Account').qq|">
<input class=submit type=submit name=action value="|.$locale->text('Close').qq|">
</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub display_split_debit {
  $lxdebug->enter_sub();
  $form->{taxchart} = $form->unescape($form->{taxchart});
    
  $form->header;

  print qq|
<body>
<form method=post name=split_debit action=gl.pl>
|.$locale->text('Debit').qq|: |.$form->format_amount(\%myconfig, $form->{amount},2).qq| EUR<br>
|.$locale->text('Still to post').qq|:<input name=debitpost size=10 value="|.$form->format_amount(\%myconfig, $form->{debitpost},2).qq|"> EUR<br>
<script type="text/javascript">
           function update_stilltopost (betrag){
           remaining = parseFloat(document.split_debit.debitpost.value) - parseFloat(betrag);
           document.split_debit.debitpost.value= remaining;
           }           
</script>

<table>|;
for $i (2 .. $form->{debitrowcount}) {
  $form->{"debitchart_$i"} = $form->{chart};
  $form->{"debitchart_$i"}  =~ s/value=\"$form->{"debitchartselected_$i"}\"/value=\"$form->{"debitchartselected_$i"}\" selected/;
  
  $form->{"taxchart_$i"} = $form->{taxchart};
  $form->{"taxchart_$i"}  =~ s/value=\"$form->{"taxchartselected_$i"}\"/value=\"$form->{"taxchartselected_$i"}\" selected/;
  $position = $i -1;
print qq|
  <tr><td></td></tr>
  <tr>
    <th>Position $position</th>
    <td><select name=debitchartselected_$i>$form->{"debitchart_$i"}</select></td>
    <th align=right>|.$locale->text('Amount').qq| $1</th>
    <td><input name=debit_$i size=10 value="|.$form->format_amount(\%myconfig, $form->{"debit_$i"},2).qq|" onBlur="update_stilltopost(this.value)"> EUR</td>
  </tr>
  <tr>
    <th></th>
    <td><select name=taxchartselected_$i>$form->{"taxchart_$i"}</select></td>
    <th align=right>|.$locale->text('Tax').qq|</th>
    <td><input name=tax_$i size=10 value="|.$form->format_amount(\%myconfig, $form->{"tax_$i"},2).qq|"> EUR</td>
    <td><input type=checkbox name=tax_manual_$i value=1> Steuerkorrektur</td>
  </tr>
  <td></td>
  <tr>
  </tr>
  <tr>
    <td colspan=5><hr size=3 noshade></td>
  </tr>

|;
}
print qq|
</table>
<input type=hidden name=previousform value="$form->{previousform}">

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>
<input type=hidden name=callback value=$form->{callback}>
<input type=hidden name=old_callback value=$form->{old_callback}>
<input type=hidden name=amount value=$form->{amount}>
<input type=hidden name=debit_splited value=1>
<input type=hidden name=debitrowcount value="$form->{debitrowcount}">
<input type=hidden name=chart value=|.$form->escape($form->{chart}).qq|>
<input type=hidden name=taxchart value=|.$form->escape($form->{taxchart}).qq|>
<p>
<input class=submit type=submit name=action value="|.$locale->text('New Account').qq|">
<input class=submit type=submit name=action value="|.$locale->text('Close').qq|">
</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub new_account {
  $lxdebug->enter_sub();

  $form->{chart} = $form->unescape($form->{chart});
  
  if ($form->{credit_splited}) {
    $form->{creditpost} = $form->{amount};
    
    for $i (2 .. $form->{creditrowcount}) {
      $form->{"credit_$i"} = $form->parse_amount(\%myconfig, $form->{"credit_$i"});
      $form->{creditpost} -= $form->{"credit_$i"};
      ($taxkey, $taxrate) = split(/--/, $form->{"taxchartselected_$i"});
      if ($form->{"tax_manual_$i"}) {
        $form->{"tax_$i"} = $form->parse_amount(\%myconfig, $form->{"tax_$i"});
      } else {
        $form->{"tax_$i"} = $form->{"credit_$i"} * $taxrate;
      }
      $form->{creditpost} -= $form->{"tax_$i"};

    }
    if ($form->{"credit_$form->{creditrowcount}"}) {
      $form->{creditrowcount}++;
    }
    
    &display_split_credit;
  }
  if ($form->{debit_splited}) {
    $form->{debitpost} = $form->{amount};
    
    for $i (2 .. $form->{debitrowcount}) {
      $form->{"debit_$i"} = $form->parse_amount(\%myconfig, $form->{"debit_$i"});
      $form->{debitpost} -= $form->{"debit_$i"};
      ($taxkey, $taxrate) = split(/--/, $form->{"taxchartselected_$i"});
      if ($form->{"tax_manual_$i"}) {
        $form->{"tax_$i"} = $form->parse_amount(\%myconfig, $form->{"tax_$i"});
      } else {
        $form->{"tax_$i"} = $form->{"debit_$i"} * $taxrate;
      }
      $form->{debitpost} -= $form->{"tax_$i"};

    }
    if ($form->{"debit_$form->{debitrowcount}"}) {
      $form->{debitrowcount}++;
    }
    
    &display_split_debit;
  }  
  $lxdebug->leave_sub();
}

sub close {
  $lxdebug->enter_sub();

    # save the new form variables before splitting previousform
    map { $newform{$_} = $form->{$_} } keys %$form;

    $previousform = $form->unescape($form->{previousform});

    # don't trample on previous variables
    map { delete $form->{$_} } keys %newform;

    # now take it apart and restore original values
    foreach $item (split /&/, $previousform) {
      ($key, $value) = split /=/, $item, 2;
      $value =~ s/%26/&/g;
      $form->{$key} = $value;
    }
    if ($newform{credit_splited}) {
      $form->{credit} = 0;
      $form->{credit_splited} = $newform{credit_splited};
      $form->{creditrowcount} = $newform{creditrowcount};
      for $i (2 .. $form->{creditrowcount}) {     
        $form->{"creditchartselected_$i"} =$newform{"creditchartselected_$i"};
        $form->{"credit_$i"} =$newform{"credit_$i"};
        $form->{"credit_$i"} = $form->parse_amount(\%myconfig, $form->{"credit_$i"});
        $form->{"taxchartselected_$i"} =$newform{"taxchartselected_$i"};
        ($taxkey, $taxrate) = split(/--/, $form->{"taxchartselected_$i"});
        if ($newform{"tax_manual_$i"}) {
          $form->{"tax_$i"} = $form->parse_amount(\%myconfig, $newform{"tax_$i"});
        } else {
          $form->{"tax_$i"} = $form->{"credit_$i"} * $taxrate;
        }
        $form->{credit} += $form->round_amount($form->{"credit_$i"},2);
        $form->{credit} += $form->round_amount($form->{"tax_$i"},2);;
        
      }
    } else {
      $form->{debit} = 0;
      $form->{debit_splited} = $newform{debit_splited};
      $form->{debitrowcount} = $newform{debitrowcount};
      for $i (2 .. $form->{debitrowcount}) {     
        $form->{"debitchartselected_$i"} =$newform{"debitchartselected_$i"};
        $form->{"debit_$i"} =$newform{"debit_$i"};
        $form->{"debit_$i"} = $form->parse_amount(\%myconfig, $form->{"debit_$i"});
        $form->{"taxchartselected_$i"} =$newform{"taxchartselected_$i"};
        ($taxkey, $taxrate) = split(/--/, $form->{"taxchartselected_$i"});
        if ($newform{"tax_manual_$i"}) {
          $form->{"tax_$i"} = $form->parse_amount(\%myconfig, $newform{"tax_$i"});
        } else {
          $form->{"tax_$i"} = $form->{"debit_$i"} * $taxrate;
        }
        $form->{debit} += $form->round_amount($form->{"debit_$i"},2);
        $form->{debit} += $form->round_amount($form->{"tax_$i"},2);;
      }
    }
    delete $form->{action};
    $callback = $form->unescape($form->{callback});
    $form->{callback} = $form->unescape($form->{old_callback});
    delete $form->{old_callback};

    # put callback together
    foreach $key (keys %$form) {
      # do single escape for Apache 2.0
      $value = $form->escape($form->{$key}, 1);
      $callback .= qq|&$key=$value|;
    }
    $form->{callback} = $callback;
  

  # redirect
  $form->redirect;
  $lxdebug->leave_sub();
}
