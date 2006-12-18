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
# administration
#
#======================================================================

use SL::AM;
use SL::CA;
use SL::Form;
use SL::User;

use Data::Dumper;

1;

require "$form->{path}/common.pl";

# end of main

sub add    { &{"add_$form->{type}"} }
sub edit   { &{"edit_$form->{type}"} }
sub save   { &{"save_$form->{type}"} }
sub delete { &{"delete_$form->{type}"} }

sub add_account {
  $lxdebug->enter_sub();

  $form->{title}     = "Add";
  $form->{charttype} = "A";
  AM->get_account(\%myconfig, \%$form);

  $form->{callback} =
    "$form->{script}?action=list_account&path=$form->{path}&login=$form->{login}&password=$form->{password}"
    unless $form->{callback};

  &account_header;
  &form_footer;

  $lxdebug->leave_sub();
}

sub edit_account {
  $lxdebug->enter_sub();

  $form->{title} = "Edit";
  AM->get_account(\%myconfig, \%$form);

  foreach my $item (split(/:/, $form->{link})) {
    $form->{$item} = "checked";
  }

  &account_header;
  &form_footer;

  $lxdebug->leave_sub();
}

sub account_header {
  $lxdebug->enter_sub();

  $form->{title} = $locale->text("$form->{title} Account");

  $checked{ $form->{charttype} } = "checked";
  $checked{"$form->{category}_"} = "checked";
  $checked{CT_tax} = ($form->{CT_tax}) ? "" : "checked";

  $form->{description} =~ s/\"/&quot;/g;

  if (@{ $form->{TAXKEY} }) {
    foreach $item (@{ $form->{TAXKEY} }) {
      if ($item->{tax} == $form->{tax}) {
        $form->{selecttaxkey} .=
          "<option value=$item->{tax} selected>$item->{taxdescription}\n";
      } else {
        $form->{selecttaxkey} .=
          "<option value=$item->{tax}>$item->{taxdescription}\n";
      }

    }
  }

  $taxkey = qq|
	      <tr>
		<th align=right>| . $locale->text('Steuersatz') . qq|</th>
		<td><select name=tax>$form->{selecttaxkey}</select></td>
		<th align=right>| . $locale->text('Gültig ab') . qq|</th>
                <td><input name=startdate value="$form->{startdate}"></td>
	      </tr>|;

  if (@{ $form->{NEWACCOUNT} }) {
    if (!$form->{new_chart_valid}) {
      $form->{selectnewaccount} = "<option value=></option>";
    }
    foreach $item (@{ $form->{NEWACCOUNT} }) {
      if ($item->{id} == $form->{new_chart_id}) {
        $form->{selectnewaccount} .=
          "<option value=$item->{id} selected>$item->{accno}--$item->{description}</option>";
      } elsif (!$form->{new_chart_valid}) {
        $form->{selectnewaccount} .=
          "<option value=$item->{id}>$item->{accno}--$item->{description}</option>";
      }

    }
  }

  $newaccount = qq|
	      <tr>
                <td colspan=2>
                  <table>
                    <tr>
		      <th align=right>| . $locale->text('Folgekonto') . qq|</th>
		      <td><select name=new_chart_id>$form->{selectnewaccount}</select></td>
                      <th align=right>| . $locale->text('Gültig ab') . qq|</th>
		      <td><input name=valid_from value="$form->{valid_from}"></td>
                    </tr>
                  </table>
                </td>
	      </tr>|;

  $form->{selectustva} = "<option>\n";

  %ustva = (35  => $locale->text('UStVA-Nr. 35'),
            36  => $locale->text('UStVA-Nr. 36'),
            39  => $locale->text('UStVA-Nr. 39'),
            41  => $locale->text('UStVA-Nr. 41'),
            42  => $locale->text('UStVA-Nr. 42'),
            43  => $locale->text('UStVA-Nr. 43'),
            44  => $locale->text('UStVA-Nr. 44'),
            45  => $locale->text('UStVA-Nr. 45'),
            48  => $locale->text('UStVA-Nr. 48'),
            49  => $locale->text('UStVA-Nr. 49'),
            51  => $locale->text('UStVA-Nr. 51 left'),
            511 => $locale->text('UStVA-Nr. 51 right'),
            52  => $locale->text('UStVA-Nr. 52'),
            53  => $locale->text('UStVA-Nr. 53'),
            59  => $locale->text('UStVA-Nr. 59'),
            60  => $locale->text('UStVA-Nr. 60'),
            61  => $locale->text('UStVA-Nr. 61'),
            62  => $locale->text('UStVA-Nr. 62'),
            63  => $locale->text('UStVA-Nr. 63'),
            64  => $locale->text('UStVA-Nr. 64'),
            65  => $locale->text('UStVA-Nr. 65'),
            66  => $locale->text('UStVA-Nr. 66'),
            67  => $locale->text('UStVA-Nr. 67'),
            69  => $locale->text('UStVA-Nr. 69'),
            73  => $locale->text('UStVA-Nr. 73'),
            74  => $locale->text('UStVA-Nr. 74'),
            76  => $locale->text('UStVA-Nr. 76'),
            77  => $locale->text('UStVA-Nr. 77'),
            80  => $locale->text('UStVA-Nr. 80'),
            84  => $locale->text('UStVA-Nr. 84'),
            85  => $locale->text('UStVA-Nr. 85'),
            86  => $locale->text('UStVA-Nr. 86 left'),
            861 => $locale->text('UStVA-Nr. 86 right'),
            91  => $locale->text('UStVA-Nr. 91'),
            93  => $locale->text('UStVA-Nr. 93 left'),
            931 => $locale->text('UStVA-Nr. 93 right'),
            94  => $locale->text('UStVA-Nr. 94'),
            95  => $locale->text('UStVA-Nr. 95'),
            96  => $locale->text('UStVA-Nr. 96'),
            97  => $locale->text('UStVA-Nr. 97 links'),
            971 => $locale->text('UStVA-Nr. 97 rechts'),
            98  => $locale->text('UStVA-Nr. 98'));

  foreach $item (sort({ $a cmp $b } keys %ustva)) {
    if ($item == $form->{pos_ustva}) {
      $form->{selectustva} .= "<option value=$item selected>$ustva{$item}\n";
    } else {
      $form->{selectustva} .= "<option value=$item>$ustva{$item}\n";
    }

  }

  $ustva = qq|
	      <tr>
		<th align=right>| . $locale->text('Umsatzsteuervoranmeldung') . qq|</th>
		<td><select name=pos_ustva>$form->{selectustva}</select></td>
		<input type=hidden name=selectustva value="$form->{selectustva}">
	      </tr>|;

  $form->{selecteur} = "<option>\n";
  %eur = (1  => "Umsatzerlöse",
          2  => "sonstige Erlöse",
          3  => "Privatanteile",
          4  => "Zinserträge",
          5  => "Ausserordentliche Erträge",
          6  => "Vereinnahmte Umsatzst.",
          7  => "Umsatzsteuererstattungen",
          8  => "Wareneingänge",
          9  => "Löhne und Gehälter",
          10 => "Gesetzl. sozialer Aufw.",
          11 => "Mieten",
          12 => "Gas, Strom, Wasser",
          13 => "Instandhaltung",
          14 => "Steuern, Versich., Beiträge",
          15 => "Kfz-Steuern",
          16 => "Kfz-Versicherungen",
          17 => "Sonst. Fahrtkosten",
          18 => "Werbe- und Reisekosten",
          19 => "Instandhaltung u. Werkzeuge",
          20 => "Fachzeitschriften, Bücher",
          21 => "Miete für Einrichtungen",
          22 => "Rechts- und Beratungskosten",
          23 => "Bürobedarf, Porto, Telefon",
          24 => "Sonstige Aufwendungen",
          25 => "Abschreibungen auf Anlagever.",
          26 => "Abschreibungen auf GWG",
          27 => "Vorsteuer",
          28 => "Umsatzsteuerzahlungen",
          29 => "Zinsaufwand",
          30 => "Ausserordentlicher Aufwand",
          31 => "Betriebliche Steuern");
  foreach $item (sort({ $a <=> $b } keys(%eur))) {
    if ($item == $form->{pos_eur}) {
      $form->{selecteur} .= "<option value=$item selected>$eur{$item}\n";
    } else {
      $form->{selecteur} .= "<option value=$item>$eur{$item}\n";
    }

  }

  $eur = qq|
	      <tr>
		<th align=right>| . $locale->text('EUER') . qq|</th>
		<td><select name=pos_eur>$form->{selecteur}</select></td>
		<input type=hidden name=selecteur value="$form->{selecteur}">
	      </tr>|;

  $form->{selectbwa} = "<option>\n";

  %bwapos = (1  => 'Umsatzerlöse',
             2  => 'Best.Verdg.FE/UE',
             3  => 'Aktiv.Eigenleistung',
             4  => 'Mat./Wareneinkauf',
             5  => 'So.betr.Erlöse',
             10 => 'Personalkosten',
             11 => 'Raumkosten',
             12 => 'Betriebl.Steuern',
             13 => 'Vers./Beiträge',
             14 => 'Kfz.Kosten o.St.',
             15 => 'Werbe-Reisek.',
             16 => 'Kosten Warenabgabe',
             17 => 'Abschreibungen',
             18 => 'Rep./instandhlt.',
             19 => 'Übrige Steuern',
             20 => 'Sonst.Kosten',
             30 => 'Zinsauwand',
             31 => 'Sonst.neutr.Aufw.',
             32 => 'Zinserträge',
             33 => 'Sonst.neutr.Ertrag',
             34 => 'Verr.kalk.Kosten',
             35 => 'Steuern Eink.u.Ertr.');
  foreach $item (sort({ $a <=> $b } keys %bwapos)) {
    if ($item == $form->{pos_bwa}) {
      $form->{selectbwa} .= "<option value=$item selected>$bwapos{$item}\n";
    } else {
      $form->{selectbwa} .= "<option value=$item>$bwapos{$item}\n";
    }

  }

  $bwa = qq|
	      <tr>
		<th align=right>| . $locale->text('BWA') . qq|</th>
		<td><select name=pos_bwa>$form->{selectbwa}</select></td>
		<input type=hidden name=selectbwa value="$form->{selectbwa}">
	      </tr>|;

# Entfernt bis es ordentlich umgesetzt wird (hli) 30.03.2006
#  $form->{selectbilanz} = "<option>\n";
#  foreach $item ((1, 2, 3, 4)) {
#    if ($item == $form->{pos_bilanz}) {
#      $form->{selectbilanz} .= "<option value=$item selected>$item\n";
#    } else {
#      $form->{selectbilanz} .= "<option value=$item>$item\n";
#    }
#
#  }
#
#  $bilanz = qq|
#	      <tr>
#		<th align=right>| . $locale->text('Bilanz') . qq|</th>
#		<td><select name=pos_bilanz>$form->{selectbilanz}</select></td>
#		<input type=hidden name=selectbilanz value="$form->{selectbilanz}">
#	      </tr>|;

  # this is for our parser only!
  # type=submit $locale->text('Add Account')
  # type=submit $locale->text('Edit Account')
  $form->{type} = "account";

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{id}>
<input type=hidden name=type value=account>
<input type=hidden name=orphaned value=$form->{orphaned}>
<input type=hidden name=new_chart_valid value=$form->{new_chart_valid}>

<input type=hidden name=inventory_accno_id value=$form->{inventory_accno_id}>
<input type=hidden name=income_accno_id value=$form->{income_accno_id}>
<input type=hidden name=expense_accno_id value=$form->{expense_accno_id}>
<input type=hidden name=fxgain_accno_id value=$form->{fxgain_accno_id}>
<input type=hidden name=fxloss_accno_id value=$form->{fxloss_accno_id}>

<table border=0 width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr valign=top>
    <td>
      <table>
	<tr>
	  <th align=right>| . $locale->text('Account Number') . qq|</th>
	  <td><input name=accno size=20 value=$form->{accno}></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Description') . qq|</th>
	  <td><input name=description size=40 value="$form->{description}"></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Account Type') . qq|</th>
	  <td>
	    <table>
	      <tr valign=top>
		<td><input name=category type=radio class=radio value=A $checked{A_}>&nbsp;|
    . $locale->text('Asset') . qq|\n<br>
		<input name=category type=radio class=radio value=L $checked{L_}>&nbsp;|
    . $locale->text('Liability') . qq|\n<br>
		<input name=category type=radio class=radio value=Q $checked{Q_}>&nbsp;|
    . $locale->text('Equity') . qq|\n<br>
		<input name=category type=radio class=radio value=I $checked{I_}>&nbsp;|
    . $locale->text('Revenue') . qq|\n<br>
		<input name=category type=radio class=radio value=E $checked{E_}>&nbsp;|
    . $locale->text('Expense') . qq|</td>
		<td width=50>&nbsp;</td>
		<td>
		<input name=charttype type=radio class=radio value="H" $checked{H}>&nbsp;|
    . $locale->text('Heading') . qq|<br>
		<input name=charttype type=radio class=radio value="A" $checked{A}>&nbsp;|
    . $locale->text('Account') . qq|</td>
	      </tr>
	    </table>
	  </td>
	</tr>
|;

  if ($form->{charttype} eq "A") {
    print qq|
	<tr>
	  <td colspan=2>
	    <table>
	      <tr>
		<th align=left>|
      . $locale->text('Is this a summary account to record') . qq|</th>
		<td>
		<input name=AR type=checkbox class=checkbox value=AR $form->{AR}>&nbsp;|
      . $locale->text('AR')
      . qq|&nbsp;<input name=AP type=checkbox class=checkbox value=AP $form->{AP}>&nbsp;|
      . $locale->text('AP')
      . qq|&nbsp;<input name=IC type=checkbox class=checkbox value=IC $form->{IC}>&nbsp;|
      . $locale->text('Inventory')
      . qq|</td>
	      </tr>
	    </table>
	  </td>
	</tr>
	<tr>
	  <th colspan=2>| . $locale->text('Include in drop-down menus') . qq|</th>
	</tr>
	<tr valign=top>
	  <td colspan=2>
	    <table width=100%>
	      <tr>
		<th align=left>| . $locale->text('Receivables') . qq|</th>
		<th align=left>| . $locale->text('Payables') . qq|</th>
		<th align=left>| . $locale->text('Parts Inventory') . qq|</th>
		<th align=left>| . $locale->text('Service Items') . qq|</th>
	      </tr>
	      <tr>
		<td>
		<input name=AR_amount type=checkbox class=checkbox value=AR_amount $form->{AR_amount}>&nbsp;|
      . $locale->text('Revenue') . qq|\n<br>
		<input name=AR_paid type=checkbox class=checkbox value=AR_paid $form->{AR_paid}>&nbsp;|
      . $locale->text('Receipt') . qq|\n<br>
		<input name=AR_tax type=checkbox class=checkbox value=AR_tax $form->{AR_tax}>&nbsp;|
      . $locale->text('Tax') . qq|
		</td>
		<td>
		<input name=AP_amount type=checkbox class=checkbox value=AP_amount $form->{AP_amount}>&nbsp;|
      . $locale->text('Expense/Asset') . qq|\n<br>
		<input name=AP_paid type=checkbox class=checkbox value=AP_paid $form->{AP_paid}>&nbsp;|
      . $locale->text('Payment') . qq|\n<br>
		<input name=AP_tax type=checkbox class=checkbox value=AP_tax $form->{AP_tax}>&nbsp;|
      . $locale->text('Tax') . qq|
		</td>
		<td>
		<input name=IC_sale type=checkbox class=checkbox value=IC_sale $form->{IC_sale}>&nbsp;|
      . $locale->text('Revenue') . qq|\n<br>
		<input name=IC_cogs type=checkbox class=checkbox value=IC_cogs $form->{IC_cogs}>&nbsp;|
      . $locale->text('Expense') . qq|\n<br>
		<input name=IC_taxpart type=checkbox class=checkbox value=IC_taxpart $form->{IC_taxpart}>&nbsp;|
      . $locale->text('Tax') . qq|
		</td>
		<td>
		<input name=IC_income type=checkbox class=checkbox value=IC_income $form->{IC_income}>&nbsp;|
      . $locale->text('Revenue') . qq|\n<br>
		<input name=IC_expense type=checkbox class=checkbox value=IC_expense $form->{IC_expense}>&nbsp;|
      . $locale->text('Expense') . qq|\n<br>
		<input name=IC_taxservice type=checkbox class=checkbox value=IC_taxservice $form->{IC_taxservice}>&nbsp;|
      . $locale->text('Tax') . qq|
		</td>
	      </tr>
	    </table>
	  </td>
	</tr>
|;
  }

  print qq|
        $taxkey
        $ustva
        $eur
	$bwa
        $bilanz
      </table>
    </td>
  </tr>
  $newaccount
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>
|;

  $lxdebug->leave_sub();
}

sub form_footer {
  $lxdebug->enter_sub();

  print qq|

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<br>|;
  if ((!$form->{id}) || ($form->{id} && $form->{orphaned}) || (($form->{type} eq "account") && (!$form->{new_chart_valid}))) {
    print qq|
<input type=submit class=submit name=action value="|
    . $locale->text('Save') . qq|">
|;
}

  if ($form->{id} && $form->{orphaned}) {
    print qq|<input type=submit class=submit name=action value="|
      . $locale->text('Delete') . qq|">|;
  }

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

sub save_account {
  $lxdebug->enter_sub();

  $form->isblank("accno",    $locale->text('Account Number missing!'));
  $form->isblank("category", $locale->text('Account Type missing!'));

  $form->redirect($locale->text('Account saved!'))
    if (AM->save_account(\%myconfig, \%$form));
  $form->error($locale->text('Cannot save account!'));

  $lxdebug->leave_sub();
}

sub list_account {
  $lxdebug->enter_sub();

  CA->all_accounts(\%myconfig, \%$form);

  $form->{title} = $locale->text('Chart of Accounts');

  # construct callback
  $callback =
    "$form->{script}?action=list_account&path=$form->{path}&login=$form->{login}&password=$form->{password}";

  @column_index = qw(accno gifi_accno description debit credit link);

  $column_header{accno} = qq|<th>| . $locale->text('Account') . qq|</a></th>|;
  $column_header{gifi_accno} =
    qq|<th>| . $locale->text('GIFI') . qq|</a></th>|;
  $column_header{description} =
    qq|<th>| . $locale->text('Description') . qq|</a></th>|;
  $column_header{debit}  = qq|<th>| . $locale->text('Debit') . qq|</a></th>|;
  $column_header{credit} = qq|<th>| . $locale->text('Credit') . qq|</a></th>|;
  $column_header{link}   = qq|<th>| . $locale->text('Link') . qq|</a></th>|;

  $form->header;
  $colspan = $#column_index + 1;

  print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop colspan=$colspan>$form->{title}</th>
  </tr>
  <tr height=5></tr>
  <tr class=listheading>
|;

  map { print "$column_header{$_}\n" } @column_index;

  print qq|
</tr>
|;

  # escape callback
  $callback = $form->escape($callback);

  foreach $ca (@{ $form->{CA} }) {

    $ca->{debit}  = "&nbsp;";
    $ca->{credit} = "&nbsp;";

    if ($ca->{amount} > 0) {
      $ca->{credit} =
        $form->format_amount(\%myconfig, $ca->{amount}, 2, "&nbsp;");
    }
    if ($ca->{amount} < 0) {
      $ca->{debit} =
        $form->format_amount(\%myconfig, -$ca->{amount}, 2, "&nbsp;");
    }

    $ca->{link} =~ s/:/<br>/og;

    if ($ca->{charttype} eq "H") {
      print qq|<tr class=listheading>|;

      $column_data{accno} =
        qq|<th><a href=$form->{script}?action=edit_account&id=$ca->{id}&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback>$ca->{accno}</a></th>|;
      $column_data{gifi_accno} =
        qq|<th><a href=$form->{script}?action=edit_gifi&accno=$ca->{gifi_accno}&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback>$ca->{gifi_accno}</a>&nbsp;</th>|;
      $column_data{description} = qq|<th>$ca->{description}&nbsp;</th>|;
      $column_data{debit}       = qq|<th>&nbsp;</th>|;
      $column_data{credit}      = qq| <th>&nbsp;</th>|;
      $column_data{link}        = qq|<th>&nbsp;</th>|;

    } else {
      $i++;
      $i %= 2;
      print qq|
<tr valign=top class=listrow$i>|;
      $column_data{accno} =
        qq|<td><a href=$form->{script}?action=edit_account&id=$ca->{id}&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback>$ca->{accno}</a></td>|;
      $column_data{gifi_accno} =
        qq|<td><a href=$form->{script}?action=edit_gifi&accno=$ca->{gifi_accno}&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback>$ca->{gifi_accno}</a>&nbsp;</td>|;
      $column_data{description} = qq|<td>$ca->{description}&nbsp;</td>|;
      $column_data{debit}       = qq|<td align=right>$ca->{debit}</td>|;
      $column_data{credit}      = qq|<td align=right>$ca->{credit}</td>|;
      $column_data{link}        = qq|<td>$ca->{link}&nbsp;</td>|;

    }

    map { print "$column_data{$_}\n" } @column_index;

    print "</tr>\n";
  }

  print qq|
  <tr><td colspan=$colspan><hr size=3 noshade></td></tr>
</table>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub delete_account {
  $lxdebug->enter_sub();

  $form->{title} = $locale->text('Delete Account');

  foreach $id (
    qw(inventory_accno_id income_accno_id expense_accno_id fxgain_accno_id fxloss_accno_id)
    ) {
    if ($form->{id} == $form->{$id}) {
      $form->error($locale->text('Cannot delete default account!'));
    }
  }

  $form->redirect($locale->text('Account deleted!'))
    if (AM->delete_account(\%myconfig, \%$form));
  $form->error($locale->text('Cannot delete account!'));

  $lxdebug->leave_sub();
}

sub list_gifi {
  $lxdebug->enter_sub();

  @{ $form->{fields} } = (accno, description);
  $form->{table}     = "gifi";
  $form->{sortorder} = "accno";

  AM->gifi_accounts(\%myconfig, \%$form);

  $form->{title} = $locale->text('GIFI');

  # construct callback
  $callback =
    "$form->{script}?action=list_gifi&path=$form->{path}&login=$form->{login}&password=$form->{password}";

  @column_index = qw(accno description);

  $column_header{accno} = qq|<th>| . $locale->text('GIFI') . qq|</a></th>|;
  $column_header{description} =
    qq|<th>| . $locale->text('Description') . qq|</a></th>|;

  $form->header;
  $colspan = $#column_index + 1;

  print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop colspan=$colspan>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr class=listheading>
|;

  map { print "$column_header{$_}\n" } @column_index;

  print qq|
</tr>
|;

  # escape callback
  $callback = $form->escape($callback);

  foreach $ca (@{ $form->{ALL} }) {

    $i++;
    $i %= 2;

    print qq|
<tr valign=top class=listrow$i>|;

    $column_data{accno} =
      qq|<td><a href=$form->{script}?action=edit_gifi&coa=1&accno=$ca->{accno}&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback>$ca->{accno}</td>|;
    $column_data{description} = qq|<td>$ca->{description}&nbsp;</td>|;

    map { print "$column_data{$_}\n" } @column_index;

    print "</tr>\n";
  }

  print qq|
  <tr>
    <td colspan=$colspan><hr size=3 noshade></td>
  </tr>
</table>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub add_gifi {
  $lxdebug->enter_sub();

  $form->{title} = "Add";

  # construct callback
  $form->{callback} =
    "$form->{script}?action=list_gifi&path=$form->{path}&login=$form->{login}&password=$form->{password}";

  $form->{coa} = 1;

  &gifi_header;
  &gifi_footer;

  $lxdebug->leave_sub();
}

sub edit_gifi {
  $lxdebug->enter_sub();

  $form->{title} = "Edit";

  AM->get_gifi(\%myconfig, \%$form);

  &gifi_header;
  &gifi_footer;

  $lxdebug->leave_sub();
}

sub gifi_header {
  $lxdebug->enter_sub();

  $form->{title} = $locale->text("$form->{title} GIFI");

  # $locale->text('Add GIFI')
  # $locale->text('Edit GIFI')

  $form->{description} =~ s/\"/&quot;/g;

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{accno}>
<input type=hidden name=type value=gifi>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
	<tr>
	  <th align=right>| . $locale->text('GIFI') . qq|</th>
	  <td><input name=accno size=20 value=$form->{accno}></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Description') . qq|</th>
	  <td><input name=description size=60 value="$form->{description}"></td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td colspan=2><hr size=3 noshade></td>
  </tr>
</table>
|;

  $lxdebug->leave_sub();
}

sub gifi_footer {
  $lxdebug->enter_sub();

  print qq|

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<br><input type=submit class=submit name=action value="|
    . $locale->text('Save') . qq|">|;

  if ($form->{coa}) {
    print qq|
<input type=submit class=submit name=action value="|
      . $locale->text('Copy to COA') . qq|">
|;

    if ($form->{accno} && $form->{orphaned}) {
      print qq|<input type=submit class=submit name=action value="|
        . $locale->text('Delete') . qq|">|;
    }
  }

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

sub save_gifi {
  $lxdebug->enter_sub();

  $form->isblank("accno", $locale->text('GIFI missing!'));
  AM->save_gifi(\%myconfig, \%$form);
  $form->redirect($locale->text('GIFI saved!'));

  $lxdebug->leave_sub();
}

sub copy_to_coa {
  $lxdebug->enter_sub();

  $form->isblank("accno", $locale->text('GIFI missing!'));

  AM->save_gifi(\%myconfig, \%$form);

  delete $form->{id};
  $form->{gifi_accno} = $form->{accno};
  $form->{title}      = "Add";
  $form->{charttype}  = "A";

  &account_header;
  &form_footer;

  $lxdebug->leave_sub();
}

sub delete_gifi {
  $lxdebug->enter_sub();

  AM->delete_gifi(\%myconfig, \%$form);
  $form->redirect($locale->text('GIFI deleted!'));

  $lxdebug->leave_sub();
}

sub add_department {
  $lxdebug->enter_sub();

  $form->{title} = "Add";
  $form->{role}  = "P";

  $form->{callback} =
    "$form->{script}?action=add_department&path=$form->{path}&login=$form->{login}&password=$form->{password}"
    unless $form->{callback};

  &department_header;
  &form_footer;

  $lxdebug->leave_sub();
}

sub edit_department {
  $lxdebug->enter_sub();

  $form->{title} = "Edit";

  AM->get_department(\%myconfig, \%$form);

  &department_header;
  &form_footer;

  $lxdebug->leave_sub();
}

sub list_department {
  $lxdebug->enter_sub();

  AM->departments(\%myconfig, \%$form);

  $form->{callback} =
    "$form->{script}?action=list_department&path=$form->{path}&login=$form->{login}&password=$form->{password}";

  $callback = $form->escape($form->{callback});

  $form->{title} = $locale->text('Departments');

  @column_index = qw(description cost profit);

  $column_header{description} =
      qq|<th class=listheading width=90%>|
    . $locale->text('Description')
    . qq|</th>|;
  $column_header{cost} =
      qq|<th class=listheading nowrap>|
    . $locale->text('Cost Center')
    . qq|</th>|;
  $column_header{profit} =
      qq|<th class=listheading nowrap>|
    . $locale->text('Profit Center')
    . qq|</th>|;

  $form->header;

  print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>
|;

  map { print "$column_header{$_}\n" } @column_index;

  print qq|
        </tr>
|;

  foreach $ref (@{ $form->{ALL} }) {

    $i++;
    $i %= 2;

    print qq|
        <tr valign=top class=listrow$i>
|;

    $costcenter   = ($ref->{role} eq "C") ? "X" : "";
    $profitcenter = ($ref->{role} eq "P") ? "X" : "";

    $column_data{description} =
      qq|<td><a href=$form->{script}?action=edit_department&id=$ref->{id}&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback>$ref->{description}</td>|;
    $column_data{cost}   = qq|<td align=center>$costcenter</td>|;
    $column_data{profit} = qq|<td align=center>$profitcenter</td>|;

    map { print "$column_data{$_}\n" } @column_index;

    print qq|
	</tr>
|;
  }

  print qq|
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

<input type=hidden name=type value=department>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input class=submit type=submit name=action value="|
    . $locale->text('Add') . qq|">|;

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

sub department_header {
  $lxdebug->enter_sub();

  $form->{title} = $locale->text("$form->{title} Department");

  # $locale->text('Add Department')
  # $locale->text('Edit Department')

  $form->{description} =~ s/\"/&quot;/g;

  if (($rows = $form->numtextrows($form->{description}, 60)) > 1) {
    $description =
      qq|<textarea name="description" rows=$rows cols=60 wrap=soft>$form->{description}</textarea>|;
  } else {
    $description =
      qq|<input name=description size=60 value="$form->{description}">|;
  }

  $costcenter   = "checked" if $form->{role} eq "C";
  $profitcenter = "checked" if $form->{role} eq "P";

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{id}>
<input type=hidden name=type value=department>

<table width=100%>
  <tr>
    <th class=listtop colspan=2>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <th align=right>| . $locale->text('Description') . qq|</th>
    <td>$description</td>
  </tr>
  <tr>
    <td></td>
    <td><input type=radio style=radio name=role value="C" $costcenter> |
    . $locale->text('Cost Center') . qq|
        <input type=radio style=radio name=role value="P" $profitcenter> |
    . $locale->text('Profit Center') . qq|
    </td>
  <tr>
    <td colspan=2><hr size=3 noshade></td>
  </tr>
</table>
|;

  $lxdebug->leave_sub();
}

sub save_department {
  $lxdebug->enter_sub();

  $form->isblank("description", $locale->text('Description missing!'));
  AM->save_department(\%myconfig, \%$form);
  $form->redirect($locale->text('Department saved!'));

  $lxdebug->leave_sub();
}

sub delete_department {
  $lxdebug->enter_sub();

  AM->delete_department(\%myconfig, \%$form);
  $form->redirect($locale->text('Department deleted!'));

  $lxdebug->leave_sub();
}

sub add_lead {
  $lxdebug->enter_sub();

  $form->{title} = "Add";

  $form->{callback} =
    "$form->{script}?action=add_lead&path=$form->{path}&login=$form->{login}&password=$form->{password}"
    unless $form->{callback};

  &lead_header;
  &form_footer;

  $lxdebug->leave_sub();
}

sub edit_lead {
  $lxdebug->enter_sub();

  $form->{title} = "Edit";

  AM->get_lead(\%myconfig, \%$form);

  &lead_header;

  $form->{orphaned} = 1;
  &form_footer;

  $lxdebug->leave_sub();
}

sub list_lead {
  $lxdebug->enter_sub();

  AM->lead(\%myconfig, \%$form);

  $form->{callback} =
    "$form->{script}?action=list_lead&path=$form->{path}&login=$form->{login}&password=$form->{password}";

  $callback = $form->escape($form->{callback});

  $form->{title} = $locale->text('Lead');

  @column_index = qw(description cost profit);

  $column_header{description} =
      qq|<th class=listheading width=100%>|
    . $locale->text('Description')
    . qq|</th>|;

  $form->header;

  print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr class=listheading>
|;

  map { print "$column_header{$_}\n" } @column_index;

  print qq|
        </tr>
|;

  foreach $ref (@{ $form->{ALL} }) {

    $i++;
    $i %= 2;

    print qq|
        <tr valign=top class=listrow$i>
|;

	$lead = $ref->{lead};
	
    $column_data{description} =
      qq|<td><a href=$form->{script}?action=edit_lead&id=$ref->{id}&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback>$ref->{lead}</td>|;

    map { print "$column_data{$_}\n" } @column_index;

    print qq|
	</tr>
|;
  }

  print qq|
  <tr>
  <td><hr size=3 noshade></td>
  </tr>
</table>

<br>
<form method=post action=$form->{script}>

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=type value=lead>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input class=submit type=submit name=action value="|
    . $locale->text('Add') . qq|">|;

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

sub lead_header {
  $lxdebug->enter_sub();

  $form->{title} = $locale->text("$form->{title} Lead");

  # $locale->text('Add Lead')
  # $locale->text('Edit Lead')

  $form->{description} =~ s/\"/&quot;/g;

  $description =
      qq|<input name=description size=50 value="$form->{lead}">|;

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{id}>
<input type=hidden name=type value=lead>

<table width=100%>
  <tr>
    <th class=listtop colspan=2>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <th align=right>| . $locale->text('Description') . qq|</th>
    <td>$description</td>
  </tr>
    <td colspan=2><hr size=3 noshade></td>
  </tr>
</table>
|;

  $lxdebug->leave_sub();
}

sub save_lead {
  $lxdebug->enter_sub();

  $form->isblank("description", $locale->text('Description missing!'));
  AM->save_lead(\%myconfig, \%$form);
  $form->redirect($locale->text('lead saved!'));

  $lxdebug->leave_sub();
}

sub delete_lead {
  $lxdebug->enter_sub();

  AM->delete_lead(\%myconfig, \%$form);
  $form->redirect($locale->text('lead deleted!'));

  $lxdebug->leave_sub();
}

sub add_business {
  $lxdebug->enter_sub();

  $form->{title} = "Add";

  $form->{callback} =
    "$form->{script}?action=add_business&path=$form->{path}&login=$form->{login}&password=$form->{password}"
    unless $form->{callback};

  &business_header;
  &form_footer;

  $lxdebug->leave_sub();
}

sub edit_business {
  $lxdebug->enter_sub();

  $form->{title} = "Edit";

  AM->get_business(\%myconfig, \%$form);

  &business_header;

  $form->{orphaned} = 1;
  &form_footer;

  $lxdebug->leave_sub();
}

sub list_business {
  $lxdebug->enter_sub();

  AM->business(\%myconfig, \%$form);

  $form->{callback} =
    "$form->{script}?action=list_business&path=$form->{path}&login=$form->{login}&password=$form->{password}";

  $callback = $form->escape($form->{callback});

  $form->{title} = $locale->text('Type of Business');

  @column_index = qw(description discount customernumberinit);

  $column_header{description} =
      qq|<th class=listheading width=60%>|
    . $locale->text('Description')
    . qq|</th>|;
  $column_header{discount} =
      qq|<th class=listheading width=10%>|
    . $locale->text('Discount')
    . qq| %</th>|;
  $column_header{customernumberinit} =
      qq|<th class=listheading>|
    . $locale->text('Customernumberinit')
    . qq|</th>|;

  $form->header;

  print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>
|;

  map { print "$column_header{$_}\n" } @column_index;

  print qq|
        </tr>
|;

  foreach $ref (@{ $form->{ALL} }) {

    $i++;
    $i %= 2;

    print qq|
        <tr valign=top class=listrow$i>
|;

    $discount =
      $form->format_amount(\%myconfig, $ref->{discount} * 100, 1, "&nbsp");
    $description =
      ($ref->{salesman})
      ? "<b>$ref->{description}</b>"
      : "$ref->{description}";
    $column_data{description} =
      qq|<td><a href=$form->{script}?action=edit_business&id=$ref->{id}&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback>$description</td>|;
    $column_data{discount}           = qq|<td align=right>$discount</td>|;
    $column_data{customernumberinit} =
      qq|<td align=right>$ref->{customernumberinit}</td>|;

    map { print "$column_data{$_}\n" } @column_index;

    print qq|
	</tr>
|;
  }

  print qq|
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

<input type=hidden name=type value=business>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input class=submit type=submit name=action value="|
    . $locale->text('Add') . qq|">|;

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

sub business_header {
  $lxdebug->enter_sub();

  $form->{title}    = $locale->text("$form->{title} Business");
  $form->{salesman} = "checked" if $form->{salesman};

  # $locale->text('Add Business')
  # $locale->text('Edit Business')

  $form->{description} =~ s/\"/&quot;/g;
  $form->{discount} =
    $form->format_amount(\%myconfig, $form->{discount} * 100);

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{id}>
<input type=hidden name=type value=business>

<table width=100%>
  <tr>
    <th class=listtop colspan=2>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <th align=right>| . $locale->text('Type of Business') . qq|</th>
    <td><input name=description size=30 value="$form->{description}"></td>
  <tr>
  <tr>
    <th align=right>| . $locale->text('Discount') . qq| %</th>
    <td><input name=discount size=5 value=$form->{discount}></td>
  </tr>
  <tr>
    <th align=right>| . $locale->text('Customernumberinit') . qq|</th>
    <td><input name=customernumberinit size=10 value=$form->{customernumberinit}></td>
  </tr>
  <tr>
    <td align=right>| . $locale->text('Salesman') . qq|</td>
    <td><input name=salesman class=checkbox type=checkbox value=1 $form->{salesman}></td>
  </tr>
  <td colspan=2><hr size=3 noshade></td>
  </tr>
</table>
|;

  $lxdebug->leave_sub();
}

sub save_business {
  $lxdebug->enter_sub();

  $form->isblank("description", $locale->text('Description missing!'));
  AM->save_business(\%myconfig, \%$form);
  $form->redirect($locale->text('Business saved!'));

  $lxdebug->leave_sub();
}

sub delete_business {
  $lxdebug->enter_sub();

  AM->delete_business(\%myconfig, \%$form);
  $form->redirect($locale->text('Business deleted!'));

  $lxdebug->leave_sub();
}

sub add_language {
  $lxdebug->enter_sub();

  $form->{title} = "Add";

  $form->{callback} =
    "$form->{script}?action=add_language&path=$form->{path}&login=$form->{login}&password=$form->{password}"
    unless $form->{callback};

  &language_header;
  &form_footer;

  $lxdebug->leave_sub();
}

sub edit_language {
  $lxdebug->enter_sub();

  $form->{title} = "Edit";

  AM->get_language(\%myconfig, \%$form);

  &language_header;

  $form->{orphaned} = 1;
  &form_footer;

  $lxdebug->leave_sub();
}

sub list_language {
  $lxdebug->enter_sub();

  AM->language(\%myconfig, \%$form);

  $form->{callback} =
    "$form->{script}?action=list_language&path=$form->{path}&login=$form->{login}&password=$form->{password}";

  $callback = $form->escape($form->{callback});

  $form->{title} = $locale->text('Languages');

  @column_index = qw(description template_code article_code);

  $column_header{description} =
      qq|<th class=listheading width=60%>|
    . $locale->text('Description')
    . qq|</th>|;
  $column_header{template_code} =
      qq|<th class=listheading width=10%>|
    . $locale->text('Template Code')
    . qq|</th>|;
  $column_header{article_code} =
      qq|<th class=listheading>|
    . $locale->text('Article Code')
    . qq|</th>|;

  $form->header;

  print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>
|;

  map { print "$column_header{$_}\n" } @column_index;

  print qq|
        </tr>
|;

  foreach $ref (@{ $form->{ALL} }) {

    $i++;
    $i %= 2;

    print qq|
        <tr valign=top class=listrow$i>
|;


    $column_data{description} =
      qq|<td><a href=$form->{script}?action=edit_language&id=$ref->{id}&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback>$ref->{description}</td>|;
    $column_data{template_code}           = qq|<td align=right>$ref->{template_code}</td>|;
    $column_data{article_code} =
      qq|<td align=right>$ref->{article_code}</td>|;

    map { print "$column_data{$_}\n" } @column_index;

    print qq|
	</tr>
|;
  }

  print qq|
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

<input type=hidden name=type value=language>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input class=submit type=submit name=action value="|
    . $locale->text('Add') . qq|">|;

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

sub language_header {
  $lxdebug->enter_sub();

  $form->{title}    = $locale->text("$form->{title} Language");

  # $locale->text('Add Language')
  # $locale->text('Edit Language')

  $form->{description} =~ s/\"/&quot;/g;
  $form->{template_code} =~ s/\"/&quot;/g;
  $form->{article_code} =~ s/\"/&quot;/g;


  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{id}>
<input type=hidden name=type value=language>

<table width=100%>
  <tr>
    <th class=listtop colspan=2>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <th align=right>| . $locale->text('Language') . qq|</th>
    <td><input name=description size=30 value="$form->{description}"></td>
  <tr>
  <tr>
    <th align=right>| . $locale->text('Template Code') . qq|</th>
    <td><input name=template_code size=5 value=$form->{template_code}></td>
  </tr>
  <tr>
    <th align=right>| . $locale->text('Article Code') . qq|</th>
    <td><input name=article_code size=10 value=$form->{article_code}></td>
  </tr>
  <td colspan=2><hr size=3 noshade></td>
  </tr>
</table>
|;

  $lxdebug->leave_sub();
}

sub save_language {
  $lxdebug->enter_sub();

  $form->isblank("description", $locale->text('Language missing!'));
  $form->isblank("template_code", $locale->text('Template Code missing!'));
  $form->isblank("article_code", $locale->text('Article Code missing!'));
  AM->save_language(\%myconfig, \%$form);
  $form->redirect($locale->text('Language saved!'));

  $lxdebug->leave_sub();
}

sub delete_language {
  $lxdebug->enter_sub();

  AM->delete_language(\%myconfig, \%$form);
  $form->redirect($locale->text('Language deleted!'));

  $lxdebug->leave_sub();
}


sub add_buchungsgruppe {
  $lxdebug->enter_sub();

  # $locale->text("Add Buchungsgruppe")
  # $locale->text("Edit Buchungsgruppe")
  $form->{title} = "Add";

  $form->{callback} =
    "$form->{script}?action=add_buchungsgruppe&path=$form->{path}&login=$form->{login}&password=$form->{password}"
    unless $form->{callback};
  AM->get_buchungsgruppe(\%myconfig, \%$form);
  if ($eur) {
    $form->{"inventory_accno_id"} = $form->{"std_inventory_accno_id"};
  }

  &buchungsgruppe_header;
  &form_footer;

  $lxdebug->leave_sub();
}

sub edit_buchungsgruppe {
  $lxdebug->enter_sub();

  $form->{title} = "Edit";

  AM->get_buchungsgruppe(\%myconfig, \%$form);

  &buchungsgruppe_header;

  &form_footer;

  $lxdebug->leave_sub();
}

sub list_buchungsgruppe {
  $lxdebug->enter_sub();

  AM->buchungsgruppe(\%myconfig, \%$form);

  $form->{callback} =
    "$form->{script}?action=list_buchungsgruppe&path=$form->{path}&login=$form->{login}&password=$form->{password}";

  $callback = $form->escape($form->{callback});

  $form->{title} = $locale->text('Buchungsgruppen');

  @column_index = qw(description inventory_accno income_accno_0 expense_accno_0 income_accno_1 expense_accno_1 income_accno_2 expense_accno_2 income_accno_3 expense_accno_3 );

  $column_header{description} =
      qq|<th class=listheading width=60%>|
    . $locale->text('Description')
    . qq|</th>|;
  $column_header{inventory_accno} =
      qq|<th class=listheading width=10%>|
    . $locale->text('Bestandskonto')
    . qq|</th>|;
  $column_header{income_accno_0} =
      qq|<th class=listheading>|
    . $locale->text('Erlöse Inland')
    . qq|</th>|;
  $column_header{expense_accno_0} =
      qq|<th class=listheading>|
    . $locale->text('Aufwand Inland')
    . qq|</th>|;
  $column_header{income_accno_1} =
      qq|<th class=listheading>|
    . $locale->text('Erlöse EU m. UStId')
    . qq|</th>|;
  $column_header{expense_accno_1} =
      qq|<th class=listheading>|
    . $locale->text('Aufwand EU m. UStId')
    . qq|</th>|;
  $column_header{income_accno_2} =
      qq|<th class=listheading>|
    . $locale->text('Erlöse EU o. UStId')
    . qq|</th>|;
  $column_header{expense_accno_2} =
      qq|<th class=listheading>|
    . $locale->text('Aufwand EU o. UStId')
    . qq|</th>|;
  $column_header{income_accno_3} =
      qq|<th class=listheading>|
    . $locale->text('Erlöse Ausland')
    . qq|</th>|;
  $column_header{expense_accno_3} =
      qq|<th class=listheading>|
    . $locale->text('Aufwand Ausland')
    . qq|</th>|;
  $form->header;

  print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>
|;

  map { print "$column_header{$_}\n" } @column_index;

  print qq|
        </tr>
|;

  foreach $ref (@{ $form->{ALL} }) {

    $i++;
    $i %= 2;

    print qq|
        <tr valign=top class=listrow$i>
|;


    $column_data{description} =
      qq|<td><a href=$form->{script}?action=edit_buchungsgruppe&id=$ref->{id}&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback>$ref->{description}</td>|;
    $column_data{inventory_accno}           = qq|<td align=right>$ref->{inventory_accno}</td>|;
    $column_data{income_accno_0} =
      qq|<td align=right>$ref->{income_accno_0}</td>|;
    $column_data{expense_accno_0}           = qq|<td align=right>$ref->{expense_accno_0}</td>|;
    $column_data{income_accno_1} =
      qq|<td align=right>$ref->{income_accno_1}</td>|;
    $column_data{expense_accno_1}           = qq|<td align=right>$ref->{expense_accno_1}</td>|;
    $column_data{income_accno_2} =
      qq|<td align=right>$ref->{income_accno_2}</td>|;
    $column_data{expense_accno_2}           = qq|<td align=right>$ref->{expense_accno_2}</td>|;
    $column_data{income_accno_3} =
      qq|<td align=right>$ref->{income_accno_3}</td>|;
    $column_data{expense_accno_3}           = qq|<td align=right>$ref->{expense_accno_3}</td>|;

    map { print "$column_data{$_}\n" } @column_index;

    print qq|
	</tr>
|;
  }

  print qq|
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

<input type=hidden name=type value=buchungsgruppe>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input class=submit type=submit name=action value="|
    . $locale->text('Add') . qq|">|;

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

sub buchungsgruppe_header {
  $lxdebug->enter_sub();

  $form->{title}    = $locale->text("$form->{title} Buchungsgruppe");

  # $locale->text('Buchungsgruppe hinzufügen')
  # $locale->text('Buchungsgruppe bearbeiten')

  my ($acc_inventory, $acc_income, $acc_expense) = ({}, {}, {});
  my %acc_type_map = (
    "IC" => $acc_inventory,
    "IC_income" => $acc_income,
    "IC_sale" => $acc_income,
    "IC_expense" => $acc_expense,
    "IC_cogs" => $acc_expense,
    );

  foreach $key (keys(%acc_type_map)) {
    foreach $ref (@{ $form->{IC_links}{$key} }) {
      $acc_type_map{$key}->{$ref->{"id"}} = $ref;
    }
  }

  foreach my $type (qw(IC IC_income IC_expense)) {
    $form->{"select$type"} =
      join("",
           map({ "<option value=$_->{id} $_->{selected}>" .
                   "$_->{accno}--" . H($_->{description}) . "</option>" }
               sort({ $a->{"accno"} cmp $b->{"accno"} }
                    values(%{$acc_type_map{$type}}))));
  }

  if ($form->{id}) {
    $form->{selectIC} =~ s/selected//g;
    $form->{selectIC} =~ s/ value=$form->{inventory_accno_id}/  value=$form->{inventory_accno_id} selected/;
    $form->{selectIC_income} =~ s/selected//g;
    $form->{selectIC_income} =~ s/ value=$form->{income_accno_id_0}/  value=$form->{income_accno_id_0} selected/;
    $form->{selectIC_expense} =~ s/selected//g;
    $form->{selectIC_expense} =~ s/ value=$form->{expense_accno_id_0}/  value=$form->{expense_accno_id_0} selected/;
  }

  if (!$eur) {
    $linkaccounts = qq|
               <tr>
		<th align=right>| . $locale->text('Inventory') . qq|</th>
		<td><select name=inventory_accno_id>$form->{selectIC}</select></td>
		<input name=selectIC type=hidden value="$form->{selectIC}">
	      </tr>|;
  } else {
    $linkaccounts = qq|
                <input type=hidden name=inventory_accno_id value=$form->{inventory_accno_id}>|;
  }


  $linkaccounts .= qq|
	      <tr>
		<th align=right>| . $locale->text('Erlöse Inland') . qq|</th>
		<td><select name=income_accno_id_0>$form->{selectIC_income}</select></td>
	      </tr>
	      <tr>
		<th align=right>| . $locale->text('Aufwand Inland') . qq|</th>
		<td><select name=expense_accno_id_0>$form->{selectIC_expense}</select></td>
	      </tr>|;
  if ($form->{id}) {
    $form->{selectIC_income} =~ s/selected//g;
    $form->{selectIC_income} =~ s/ value=$form->{income_accno_id_1}/  value=$form->{income_accno_id_1} selected/;
    $form->{selectIC_expense} =~ s/selected//g;
    $form->{selectIC_expense} =~ s/ value=$form->{expense_accno_id_1}/  value=$form->{expense_accno_id_1} selected/;
  }
  $linkaccounts .= qq|	      <tr>
		<th align=right>| . $locale->text('Erlöse EU m. UStId') . qq|</th>
		<td><select name=income_accno_id_1>$form->{selectIC_income}</select></td>
	      </tr>
	      <tr>
		<th align=right>| . $locale->text('Aufwand EU m UStId') . qq|</th>
		<td><select name=expense_accno_id_1>$form->{selectIC_expense}</select></td>
	      </tr>|;

  if ($form->{id}) {
    $form->{selectIC_income} =~ s/selected//g;
    $form->{selectIC_income} =~ s/ value=$form->{income_accno_id_2}/  value=$form->{income_accno_id_2} selected/;
    $form->{selectIC_expense} =~ s/selected//g;
    $form->{selectIC_expense} =~ s/ value=$form->{expense_accno_id_2}/  value=$form->{expense_accno_id_2} selected/;
  }

  $linkaccounts .= qq|	      <tr>
		<th align=right>| . $locale->text('Erlöse EU o. UStId') . qq|</th>
		<td><select name=income_accno_id_2>$form->{selectIC_income}</select></td>
	      </tr>
	      <tr>
		<th align=right>| . $locale->text('Aufwand EU o. UStId') . qq|</th>
		<td><select name=expense_accno_id_2>$form->{selectIC_expense}</select></td>
	      </tr>|;

  if ($form->{id}) {
    $form->{selectIC_income} =~ s/selected//g;
    $form->{selectIC_income} =~ s/ value=$form->{income_accno_id_3}/  value=$form->{income_accno_id_3} selected/;
    $form->{selectIC_expense} =~ s/selected//g;
    $form->{selectIC_expense} =~ s/ value=$form->{expense_accno_id_3}/  value=$form->{expense_accno_id_3} selected/;
  }

  $linkaccounts .= qq|	      <tr>
		<th align=right>| . $locale->text('Erlöse Ausland') . qq|</th>
		<td><select name=income_accno_id_3>$form->{selectIC_income}</select></td>
	      </tr>
	      <tr>
		<th align=right>| . $locale->text('Aufwand Ausland') . qq|</th>
		<td><select name=expense_accno_id_3>$form->{selectIC_expense}</select></td>
	      </tr>
|;


  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{id}>
<input type=hidden name=type value=buchungsgruppe>

<table width=100%>
  <tr>
    <th class=listtop colspan=2>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <th align=right>| . $locale->text('Buchungsgruppe') . qq|</th>
    <td><input name=description size=30 value="| . $form->quote($form->{description}) . qq|"></td>
  <tr>
  $linkaccounts
  <td colspan=2><hr size=3 noshade></td>
  </tr>
</table>
|;

  $lxdebug->leave_sub();
}

sub save_buchungsgruppe {
  $lxdebug->enter_sub();

  $form->isblank("description", $locale->text('Description missing!'));

  AM->save_buchungsgruppe(\%myconfig, \%$form);
  $form->redirect($locale->text('Buchungsgruppe gespeichert!'));

  $lxdebug->leave_sub();
}

sub delete_buchungsgruppe {
  $lxdebug->enter_sub();

  AM->delete_buchungsgruppe(\%myconfig, \%$form);
  $form->redirect($locale->text('Buchungsgruppe gelöscht!'));

  $lxdebug->leave_sub();
}


sub add_printer {
  $lxdebug->enter_sub();

  $form->{title} = "Add";

  $form->{callback} =
    "$form->{script}?action=add_printer&path=$form->{path}&login=$form->{login}&password=$form->{password}"
    unless $form->{callback};

  &printer_header;
  &form_footer;

  $lxdebug->leave_sub();
}

sub edit_printer {
  $lxdebug->enter_sub();

  $form->{title} = "Edit";

  AM->get_printer(\%myconfig, \%$form);

  &printer_header;

  $form->{orphaned} = 1;
  &form_footer;

  $lxdebug->leave_sub();
}

sub list_printer {
  $lxdebug->enter_sub();

  AM->printer(\%myconfig, \%$form);

  $form->{callback} =
    "$form->{script}?action=list_printer&path=$form->{path}&login=$form->{login}&password=$form->{password}";

  $callback = $form->escape($form->{callback});

  $form->{title} = $locale->text('Printer');

  @column_index = qw(printer_description printer_command template_code);

  $column_header{printer_description} =
      qq|<th class=listheading width=60%>|
    . $locale->text('Printer Description')
    . qq|</th>|;
  $column_header{printer_command} =
      qq|<th class=listheading width=10%>|
    . $locale->text('Printer Command')
    . qq|</th>|;
  $column_header{template_code} =
      qq|<th class=listheading>|
    . $locale->text('Template Code')
    . qq|</th>|;

  $form->header;

  print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>
|;

  map { print "$column_header{$_}\n" } @column_index;

  print qq|
        </tr>
|;

  foreach $ref (@{ $form->{ALL} }) {

    $i++;
    $i %= 2;

    print qq|
        <tr valign=top class=listrow$i>
|;


    $column_data{printer_description} =
      qq|<td><a href=$form->{script}?action=edit_printer&id=$ref->{id}&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback>$ref->{printer_description}</td>|;
    $column_data{printer_command}           = qq|<td align=right>$ref->{printer_command}</td>|;
    $column_data{template_code} =
      qq|<td align=right>$ref->{template_code}</td>|;

    map { print "$column_data{$_}\n" } @column_index;

    print qq|
	</tr>
|;
  }

  print qq|
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

<input type=hidden name=type value=printer>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input class=submit type=submit name=action value="|
    . $locale->text('Add') . qq|">|;

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

sub printer_header {
  $lxdebug->enter_sub();

  $form->{title}    = $locale->text("$form->{title} Printer");

  # $locale->text('Add Printer')
  # $locale->text('Edit Printer')

  $form->{printer_description} =~ s/\"/&quot;/g;
  $form->{template_code} =~ s/\"/&quot;/g;
  $form->{printer_command} =~ s/\"/&quot;/g;


  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{id}>
<input type=hidden name=type value=printer>

<table width=100%>
  <tr>
    <th class=listtop colspan=2>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <th align=right>| . $locale->text('Printer') . qq|</th>
    <td><input name=printer_description size=30 value="$form->{printer_description}"></td>
  <tr>
  <tr>
    <th align=right>| . $locale->text('Printer Command') . qq|</th>
    <td><input name=printer_command size=30 value="$form->{printer_command}"></td>
  </tr>
  <tr>
    <th align=right>| . $locale->text('Template Code') . qq|</th>
    <td><input name=template_code size=5 value="$form->{template_code}"></td>
  </tr>
  <td colspan=2><hr size=3 noshade></td>
  </tr>
</table>
|;

  $lxdebug->leave_sub();
}

sub save_printer {
  $lxdebug->enter_sub();

  $form->isblank("printer_description", $locale->text('Description missing!'));
  $form->isblank("printer_command", $locale->text('Printer Command missing!'));
  AM->save_printer(\%myconfig, \%$form);
  $form->redirect($locale->text('Printer saved!'));

  $lxdebug->leave_sub();
}

sub delete_printer {
  $lxdebug->enter_sub();

  AM->delete_printer(\%myconfig, \%$form);
  $form->redirect($locale->text('Printer deleted!'));

  $lxdebug->leave_sub();
}


sub add_payment {
  $lxdebug->enter_sub();

  $form->{title} = "Add";

  $form->{callback} =
    "$form->{script}?action=add_payment&path=$form->{path}&login=$form->{login}&password=$form->{password}"
    unless $form->{callback};

  $form->{terms_netto} = 0;
  $form->{terms_skonto} = 0;
  $form->{percent_skonto} = 0;
  &payment_header;
  &form_footer;

  $lxdebug->leave_sub();
}

sub edit_payment {
  $lxdebug->enter_sub();

  $form->{title} = "Edit";

  AM->get_payment(\%myconfig, \%$form);

  &payment_header;

  $form->{orphaned} = 1;
  &form_footer;

  $lxdebug->leave_sub();
}

sub list_payment {
  $lxdebug->enter_sub();

  AM->payment(\%myconfig, \%$form);

  $form->{callback} =
    "$form->{script}?action=list_payment&path=$form->{path}&login=$form->{login}&password=$form->{password}";

  $callback = $form->escape($form->{callback});

  $form->{title} = $locale->text('Payment Terms');

  @column_index = qw(description description_long terms_netto terms_skonto percent_skonto);

  $column_header{description} =
      qq|<th class=listheading>|
    . $locale->text('Description')
    . qq|</th>|;
  $column_header{description_long} =
      qq|<th class=listheading>|
    . $locale->text('Long Description')
    . qq|</th>|;
  $column_header{terms_netto} =
      qq|<th class=listheading>|
    . $locale->text('Netto Terms')
    . qq|</th>|;
  $column_header{terms_skonto} =
      qq|<th class=listheading>|
    . $locale->text('Skonto Terms')
    . qq|</th>|;
  $column_header{percent_skonto} =
      qq|<th class=listheading>|
    . $locale->text('Skonto')
    . qq| %</th>|;

  $form->header;

  print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>
|;

  map { print "$column_header{$_}\n" } @column_index;

  print qq|
        </tr>
|;

  foreach $ref (@{ $form->{ALL} }) {

    $i++;
    $i %= 2;

    print qq|
        <tr valign=top class=listrow$i>
|;


    $column_data{description} =
      qq|<td><a href=$form->{script}?action=edit_payment&id=$ref->{id}&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback>$ref->{description}</td>|;
    $column_data{description_long}           = qq|<td align=right>$ref->{description_long}</td>|;
    $column_data{terms_netto} =
      qq|<td align=right>$ref->{terms_netto}</td>|;
    $column_data{terms_skonto} =
      qq|<td align=right>$ref->{terms_skonto}</td>|;
    $column_data{percent_skonto} =
      qq|<td align=right>$ref->{percent_skonto} %</td>|;
    map { print "$column_data{$_}\n" } @column_index;

    print qq|
	</tr>
|;
  }

  print qq|
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

<input type=hidden name=type value=business>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input class=submit type=submit name=action value="|
    . $locale->text('Add') . qq|">|;

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

sub payment_header {
  $lxdebug->enter_sub();

  $form->{title}    = $locale->text("$form->{title} Payment Terms");

  # $locale->text('Add Payment Terms')
  # $locale->text('Edit Payment Terms')

  $form->{description} =~ s/\"/&quot;/g;



  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{id}>
<input type=hidden name=type value=payment>

<table width=100%>
  <tr>
    <th class=listtop colspan=2>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <th align=right>| . $locale->text('Description') . qq|</th>
    <td><input name=description size=30 value="$form->{description}"></td>
  <tr>
  <tr>
    <th align=right>| . $locale->text('Long Description') . qq|</th>
    <td><input name=description_long size=50 value="$form->{description_long}"></td>
  </tr>
  <tr>
    <th align=right>| . $locale->text('Netto Terms') . qq|</th>
    <td><input name=terms_netto size=10 value="$form->{terms_netto}"></td>
  </tr>
  <tr>
    <th align=right>| . $locale->text('Skonto Terms') . qq|</th>
    <td><input name=terms_skonto size=10 value="$form->{terms_skonto}"></td>
  </tr>  
  <tr>
    <th align=right>| . $locale->text('Skonto') . qq| %</th>
    <td><input name=percent_skonto size=10 value="$form->{percent_skonto}"></td>
  </tr> 
  <td colspan=2><hr size=3 noshade></td>
  </tr>
</table>
|;

  $lxdebug->leave_sub();
}

sub save_payment {
  $lxdebug->enter_sub();

  $form->isblank("description", $locale->text('Language missing!'));
  AM->save_payment(\%myconfig, \%$form);
  $form->redirect($locale->text('Payment Terms saved!'));

  $lxdebug->leave_sub();
}

sub delete_payment {
  $lxdebug->enter_sub();

  AM->delete_payment(\%myconfig, \%$form);
  $form->redirect($locale->text('Payment terms deleted!'));

  $lxdebug->leave_sub();
}

sub add_sic {
  $lxdebug->enter_sub();

  $form->{title} = "Add";

  $form->{callback} =
    "$form->{script}?action=add_sic&path=$form->{path}&login=$form->{login}&password=$form->{password}"
    unless $form->{callback};

  &sic_header;
  &form_footer;

  $lxdebug->leave_sub();
}

sub edit_sic {
  $lxdebug->enter_sub();

  $form->{title} = "Edit";

  AM->get_sic(\%myconfig, \%$form);

  &sic_header;

  $form->{orphaned} = 1;
  &form_footer;

  $lxdebug->leave_sub();
}

sub list_sic {
  $lxdebug->enter_sub();

  AM->sic(\%myconfig, \%$form);

  $form->{callback} =
    "$form->{script}?action=list_sic&path=$form->{path}&login=$form->{login}&password=$form->{password}";

  $callback = $form->escape($form->{callback});

  $form->{title} = $locale->text('Standard Industrial Codes');

  @column_index = qw(code description);

  $column_header{code} =
    qq|<th class=listheading>| . $locale->text('Code') . qq|</th>|;
  $column_header{description} =
    qq|<th class=listheading>| . $locale->text('Description') . qq|</th>|;

  $form->header;

  print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>
|;

  map { print "$column_header{$_}\n" } @column_index;

  print qq|
        </tr>
|;

  foreach $ref (@{ $form->{ALL} }) {

    $i++;
    $i %= 2;

    if ($ref->{sictype} eq 'H') {
      print qq|
        <tr valign=top class=listheading>
|;
      $column_data{code} =
        qq|<th><a href=$form->{script}?action=edit_sic&code=$ref->{code}&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback>$ref->{code}</th>|;
      $column_data{description} = qq|<th>$ref->{description}</th>|;

    } else {
      print qq|
        <tr valign=top class=listrow$i>
|;

      $column_data{code} =
        qq|<td><a href=$form->{script}?action=edit_sic&code=$ref->{code}&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback>$ref->{code}</td>|;
      $column_data{description} = qq|<td>$ref->{description}</td>|;

    }

    map { print "$column_data{$_}\n" } @column_index;

    print qq|
	</tr>
|;
  }

  print qq|
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

<input type=hidden name=type value=sic>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input class=submit type=submit name=action value="|
    . $locale->text('Add') . qq|">|;

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

sub sic_header {
  $lxdebug->enter_sub();

  $form->{title} = $locale->text("$form->{title} SIC");

  # $locale->text('Add SIC')
  # $locale->text('Edit SIC')

  $form->{code}        =~ s/\"/&quot;/g;
  $form->{description} =~ s/\"/&quot;/g;

  $checked = ($form->{sictype} eq 'H') ? "checked" : "";

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=type value=sic>
<input type=hidden name=id value=$form->{code}>

<table width=100%>
  <tr>
    <th class=listtop colspan=2>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <th align=right>| . $locale->text('Code') . qq|</th>
    <td><input name=code size=10 value=$form->{code}></td>
  <tr>
  <tr>
    <td></td>
    <th align=left><input name=sictype type=checkbox style=checkbox value="H" $checked> |
    . $locale->text('Heading') . qq|</th>
  <tr>
  <tr>
    <th align=right>| . $locale->text('Description') . qq|</th>
    <td><input name=description size=60 value="$form->{description}"></td>
  </tr>
    <td colspan=2><hr size=3 noshade></td>
  </tr>
</table>
|;

  $lxdebug->leave_sub();
}

sub save_sic {
  $lxdebug->enter_sub();

  $form->isblank("code",        $locale->text('Code missing!'));
  $form->isblank("description", $locale->text('Description missing!'));
  AM->save_sic(\%myconfig, \%$form);
  $form->redirect($locale->text('SIC saved!'));

  $lxdebug->leave_sub();
}

sub delete_sic {
  $lxdebug->enter_sub();

  AM->delete_sic(\%myconfig, \%$form);
  $form->redirect($locale->text('SIC deleted!'));

  $lxdebug->leave_sub();
}

sub display_stylesheet {
  $lxdebug->enter_sub();

  $form->{file} = "css/$myconfig{stylesheet}";
  &display_form;

  $lxdebug->leave_sub();
}

sub display_form {
  $lxdebug->enter_sub();

  $form->{file} =~ s/^(.:)*?\/|\.\.\///g;
  $form->{file} =~ s/^\/*//g;
  $form->{file} =~ s/$userspath//;

  $form->error("$!: $form->{file}") unless -f $form->{file};

  AM->load_template(\%$form);

  $form->{title} = $form->{file};

  # if it is anything but html
  if ($form->{file} !~ /\.html$/) {
    $form->{body} = "<pre>\n$form->{body}\n</pre>";
  }

  $form->header;

  print qq|
<body>

$form->{body}

<form method=post action=$form->{script}>

<input name=file type=hidden value=$form->{file}>
<input name=type type=hidden value=template>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input name=action type=submit class=submit value="|
    . $locale->text('Edit') . qq|">|;

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

sub edit_template {
  $lxdebug->enter_sub();

  AM->load_template(\%$form);

  $form->{title} = $locale->text('Edit Template');

  # convert &nbsp to &amp;nbsp;
  $form->{body} =~ s/&nbsp;/&amp;nbsp;/gi;

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input name=file type=hidden value=$form->{file}>
<input name=type type=hidden value=template>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input name=callback type=hidden value="$form->{script}?action=display_form&file=$form->{file}&path=$form->{path}&login=$form->{login}&password=$form->{password}">

<textarea name=body rows=25 cols=70>
$form->{body}
</textarea>

<br>
<input type=submit class=submit name=action value="|
    . $locale->text('Save') . qq|">|;

  if ($form->{menubar}) {
    require "$form->{path}/menu.pl";
    &menubar;
  }

  print q|
  </form>


</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub save_template {
  $lxdebug->enter_sub();

  AM->save_template(\%$form);
  $form->redirect($locale->text('Template saved!'));

  $lxdebug->leave_sub();
}

sub config {
  $lxdebug->enter_sub();

  # get defaults for account numbers and last numbers
  AM->defaultaccounts(\%myconfig, \%$form);

  foreach $item (qw(mm-dd-yy mm/dd/yy dd-mm-yy dd/mm/yy dd.mm.yy yyyy-mm-dd)) {
    $dateformat .=
      ($item eq $myconfig{dateformat})
      ? "<option selected>$item\n"
      : "<option>$item\n";
  }

  foreach $item (qw(1,000.00 1000.00 1.000,00 1000,00)) {
    $numberformat .=
      ($item eq $myconfig{numberformat})
      ? "<option selected>$item\n"
      : "<option>$item\n";
  }

  foreach $item (qw(name company address signature)) {
    $myconfig{$item} =~ s/\"/&quot;/g;
  }

  foreach $item (qw(address signature)) {
    $myconfig{$item} =~ s/\\n/\r\n/g;
  }

  %countrycodes = User->country_codes;
  $countrycodes = '';
  foreach $key (sort { $countrycodes{$a} cmp $countrycodes{$b} }
                keys %countrycodes
    ) {
    $countrycodes .=
      ($myconfig{countrycode} eq $key)
      ? "<option selected value=$key>$countrycodes{$key}\n"
      : "<option value=$key>$countrycodes{$key}\n";
  }
  $countrycodes = "<option>American English\n$countrycodes";

  # use an other input number format than output numberformat
  # look at Form.pm, sub parse_amount
  my $in_numberformat = '';
  $text1 = qq|value="0">| . $locale->text('equal Outputformat');
  $text2 = qq|value="1">| . $locale->text('1000,00 or 1000.00');
  @in_nf = ($text1, $text2);
  foreach $item (@in_nf) {
    $in_numberformat .=
      (substr($item, 7, 1) eq $myconfig{in_numberformat})
      ? "<option selected $item\n"
      : "<option $item\n";
  }

  foreach $key (keys %{ $form->{IC} }) {
    foreach $accno (sort keys %{ $form->{IC}{$key} }) {
      $myconfig{$key} .=
        ($form->{IC}{$key}{$accno}{id} == $form->{defaults}{$key})
        ? "<option selected>$accno--$form->{IC}{$key}{$accno}{description}\n"
        : "<option>$accno--$form->{IC}{$key}{$accno}{description}\n";
    }
  }

  opendir CSS, "css/.";
  @all = grep /.*\.css$/, readdir CSS;
  closedir CSS;

  foreach $item (@all) {
    if ($item eq $myconfig{stylesheet}) {
      $selectstylesheet .= qq|<option selected>$item\n|;
    } else {
      $selectstylesheet .= qq|<option>$item\n|;
    }
  }
  $selectstylesheet .= "<option>\n";

  $form->{title} = $locale->text('Edit Preferences for') . qq| $form->{login}|;

  $form->header;

  if ($myconfig{menustyle} eq "old") { $oldS = "checked"; }
  else { $newS = "checked"; }

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=old_password value=$myconfig{password}>
<input type=hidden name=type value=preferences>
<input type=hidden name=role value=$myconfig{role}>

<table width=100%>
  <tr><th class=listtop>$form->{title}</th></tr>
  <tr>
    <td>
      <table>
        <tr>
	  <th align=right>| . $locale->text('Name') . qq|</th>
	  <td><input name=name size=15 value="$myconfig{name}"></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Password') . qq|</th>
	  <td><input type=password name=new_password size=10 value=$myconfig{password}></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('E-mail') . qq|</th>
	  <td><input name=email size=30 value="$myconfig{email}"></td>
	</tr>
	<tr valign=top>
	  <th align=right>| . $locale->text('Signature') . qq|</th>
	  <td><textarea name=signature rows=3 cols=50>$myconfig{signature}</textarea></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Phone') . qq|</th>
	  <td><input name=tel size=14 value="$myconfig{tel}"></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Fax') . qq|</th>
	  <td><input name=fax size=14 value="$myconfig{fax}"></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Company') . qq|</th>
	  <td><input name=company size=30 value="$myconfig{company}"></td>
	</tr>
	<tr valign=top>
	  <th align=right>| . $locale->text('Address') . qq|</th>
	  <td><textarea name=address rows=4 cols=50>$myconfig{address}</textarea></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Date Format') . qq|</th>
	  <td><select name=dateformat>$dateformat</select></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Output Number Format') . qq|</th>
	  <td><select name=numberformat>$numberformat</select></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Input Number Format') . qq|</th>
	  <td><select name=in_numberformat>$in_numberformat</select></td>
	</tr>

	<tr>
	  <th align=right>| . $locale->text('Dropdown Limit') . qq|</th>
	  <td><input name=vclimit size=10 value="$myconfig{vclimit}"></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Language') . qq|</th>
	  <td><select name=countrycode>$countrycodes</select></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Stylesheet') . qq|</th>
	  <td><select name=usestylesheet>$selectstylesheet</select></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Setup Menu') . qq|</th>
	  <td><input name=menustyle type=radio class=radio value=neu $newS>&nbsp;New
  		  <input name=menustyle type=radio class=radio value=old $oldS>&nbsp;Old</td>
	</tr>	
	<input name=printer type=hidden value="$myconfig{printer}">
	<tr class=listheading>
	  <th colspan=2>&nbsp;</th>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Business Number') . qq|</th>
	  <td><input name=businessnumber size=25 value="$myconfig{businessnumber}"></td>
	</tr>
	<tr>
	  <td colspan=2>
	    <table width=100%>
	      <tr>
		<th align=right>| . $locale->text('Year End') . qq| (mm/dd)</th>
		<td><input name=yearend size=5 value=$form->{defaults}{yearend}></td>
		<th align=right>| . $locale->text('Weight Unit') . qq|</th>
		<td><input name=weightunit size=5 value="$form->{defaults}{weightunit}"></td>
	      </tr>
	    </table>
	  </td>
	</tr>
	<tr class=listheading>
	  <th colspan=2>|
    . $locale->text('Last Numbers & Default Accounts') . qq|</th>
	</tr>
	<tr>
	  <td colspan=2>
	    <table width=100%>
	      <tr>
		<th align=right nowrap>| . $locale->text('Inventory Account') . qq|</th>
		<td><select name=inventory_accno>$myconfig{IC}</select></td>
	      </tr>
	      <tr>
		<th align=right nowrap>| . $locale->text('Revenue Account') . qq|</th>
		<td><select name=income_accno>$myconfig{IC_income}</select></td>
	      </tr>
	      <tr>
		<th align=right nowrap>| . $locale->text('Expense Account') . qq|</th>
		<td><select name=expense_accno>$myconfig{IC_expense}</select></td>
	      </tr>
	      <tr>
		<th align=right nowrap>| . $locale->text('Foreign Exchange Gain') . qq|</th>
		<td><select name=fxgain_accno>$myconfig{FX_gain}</select></td>
	      </tr>
	      <tr>
		<th align=right nowrap>| . $locale->text('Foreign Exchange Loss') . qq|</th>
		<td><select name=fxloss_accno>$myconfig{FX_loss}</select></td>
	      </tr>
	      <tr>
		<td colspan=2>|
    . $locale->text(
    'Enter up to 3 letters separated by a colon (i.e CAD:USD:EUR) for your native and foreign currencies'
    )
    . qq|<br><input name=curr size=40 value="$form->{defaults}{curr}"></td>
	      </tr>
            </table>
          </td>
         </tr>
         <tr>
           <td colspan=2>
             <table width=100%>
	      <tr>
		<th align=right nowrap>| . $locale->text('Last Invoice Number') . qq|</th>
		<td><input name=invnumber size=10 value=$form->{defaults}{invnumber}></td>
                <th align=right nowrap>|
    . $locale->text('Last Customer Number') . qq|</th>
		<td><input name=customernumber size=10 value=$form->{defaults}{customernumber}></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|
    . $locale->text('Last Credit Note Number') . qq|</th>
		<td><input name=cnnumber size=10 value=$form->{defaults}{cnnumber}></td>
                <th align=right nowrap>|
    . $locale->text('Last Vendor Number') . qq|</th>
		<td><input name=vendornumber size=10 value=$form->{defaults}{vendornumber}></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|
    . $locale->text('Last Sales Order Number') . qq|</th>
		<td><input name=sonumber size=10 value=$form->{defaults}{sonumber}></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|
    . $locale->text('Last Purchase Order Number') . qq|</th>
		<td><input name=ponumber size=10 value=$form->{defaults}{ponumber}></td>
                <th align=right nowrap>|
    . $locale->text('Last Article Number') . qq|</th>
		<td><input name=articlenumber size=10 value=$form->{defaults}{articlenumber}></td>
	      </tr>
	      <tr>
		<th align=right nowrap>|
    . $locale->text('Last Sales Quotation Number') . qq|</th>
		<td><input name=sqnumber size=10 value=$form->{defaults}{sqnumber}></td>
                <th align=right nowrap>|
    . $locale->text('Last Service Number') . qq|</th>
		<td><input name=servicenumber size=10 value=$form->{defaults}{servicenumber}></td>
	      </tr>
	      <tr>
		<th align=right nowrap>| . $locale->text('Last RFQ Number') . qq|</th>
		<td><input name=rfqnumber size=10 value=$form->{defaults}{rfqnumber}></td>
                <th align=right nowrap></th>
		<td></td>
	      </tr>
	    </table>
	  </td>
	</tr>|;
# 	<tr class=listheading>
# 	  <th colspan=2>| . $locale->text('Tax Accounts') . qq|</th>
# 	</tr>
# 	<tr>
# 	  <td colspan=2>
# 	    <table>
# 	      <tr>
# 		<th>&nbsp;</th>
# 		<th>| . $locale->text('Rate') . qq| (%)</th>
# 		<th>| . $locale->text('Number') . qq|</th>
# 	      </tr>
# |;
# 
#   foreach $accno (sort keys %{ $form->{taxrates} }) {
#     print qq|
#               <tr>
# 		<th align=right>$form->{taxrates}{$accno}{description}</th>
# 		<td><input name=$form->{taxrates}{$accno}{id} size=6 value=$form->{taxrates}{$accno}{rate}></td>
# 		<td><input name="taxnumber_$form->{taxrates}{$accno}{id}" value="$form->{taxrates}{$accno}{taxnumber}"></td>
# 	      </tr>
# |;
#     $form->{taxaccounts} .= "$form->{taxrates}{$accno}{id} ";
#   }
# 
#   chop $form->{taxaccounts};
# 
#   print qq|
# <input name=taxaccounts type=hidden value="$form->{taxaccounts}">
# 
#             </table>
# 	  </td>
# 	</tr>
print qq|      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<br>
<input type=submit class=submit name=action value="|
    . $locale->text('Save') . qq|">|;

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

sub save_preferences {
  $lxdebug->enter_sub();

  $form->{stylesheet} = $form->{usestylesheet};

  $form->redirect($locale->text('Preferences saved!'))
    if (
     AM->save_preferences(\%myconfig, \%$form, $memberfile, $userspath, $webdav
     ));
  $form->error($locale->text('Cannot save preferences!'));

  $lxdebug->leave_sub();
}

sub backup {
  $lxdebug->enter_sub();

  if ($form->{media} eq 'email') {
    $form->error($locale->text('No email address for') . " $myconfig{name}")
      unless ($myconfig{email});

    $form->{OUT} = "$sendmail";

  }

  AM->backup(\%myconfig, \%$form, $userspath);

  if ($form->{media} eq 'email') {
    $form->redirect($locale->text('Backup sent to') . qq| $myconfig{email}|);
  }

  $lxdebug->leave_sub();
}

sub audit_control {
  $lxdebug->enter_sub();

  $form->{title} = $locale->text('Audit Control');

  AM->closedto(\%myconfig, \%$form);

  if ($form->{revtrans}) {
    $checked{Y} = "checked";
  } else {
    $checked{N} = "checked";
  }

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<table width=100%>
  <tr><th class=listtop>$form->{title}</th></tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
	<tr>
	  <td>|
    . $locale->text('Enforce transaction reversal for all dates') . qq|</th>
	  <td><input name=revtrans class=radio type=radio value="1" $checked{Y}> |
    . $locale->text('Yes')
    . qq| <input name=revtrans class=radio type=radio value="0" $checked{N}> |
    . $locale->text('No')
    . qq|</td>
	</tr>
	<tr>
	  <th>| . $locale->text('Close Books up to') . qq|</th>
	  <td><input name=closedto size=11 title="$myconfig{dateformat}" value=$form->{closedto}></td>
	</tr>
      </table>
    </td>
  </tr>
</table>

<hr size=3 noshade>

<br>
<input type=hidden name=nextsub value=doclose>

<input type=submit class=submit name=action value="|
    . $locale->text('Continue') . qq|">

</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub doclose {
  $lxdebug->enter_sub();

  AM->closebooks(\%myconfig, \%$form);

  if ($form->{revtrans}) {
    $form->redirect(
                 $locale->text('Transaction reversal enforced for all dates'));
  } else {
    if ($form->{closedto}) {
      $form->redirect(
                     $locale->text('Transaction reversal enforced up to') . " "
                       . $locale->date(\%myconfig, $form->{closedto}, 1));
    } else {
      $form->redirect($locale->text('Books are open'));
    }
  }

  $lxdebug->leave_sub();
}

sub add_warehouse {
  $lxdebug->enter_sub();

  $form->{title} = "Add";

  $form->{callback} =
    "$form->{script}?action=add_warehouse&path=$form->{path}&login=$form->{login}&password=$form->{password}"
    unless $form->{callback};

  &warehouse_header;
  &form_footer;

  $lxdebug->leave_sub();
}

sub edit_warehouse {
  $lxdebug->enter_sub();

  $form->{title} = "Edit";

  AM->get_warehouse(\%myconfig, \%$form);

  &warehouse_header;
  &form_footer;

  $lxdebug->leave_sub();
}

sub list_warehouse {
  $lxdebug->enter_sub();

  AM->warehouses(\%myconfig, \%$form);

  $form->{callback} =
    "$form->{script}?action=list_warehouse&path=$form->{path}&login=$form->{login}&password=$form->{password}";

  $callback = $form->escape($form->{callback});

  $form->{title} = $locale->text('Warehouses');

  @column_index = qw(description);

  $column_header{description} =
      qq|<th class=listheading width=100%>|
    . $locale->text('Description')
    . qq|</th>|;

  $form->header;

  print qq|
<body>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>
|;

  map { print "$column_header{$_}\n" } @column_index;

  print qq|
        </tr>
|;

  foreach $ref (@{ $form->{ALL} }) {

    $i++;
    $i %= 2;

    print qq|
        <tr valign=top class=listrow$i>
|;

    $column_data{description} =
      qq|<td><a href=$form->{script}?action=edit_warehouse&id=$ref->{id}&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback>$ref->{description}</td>|;

    map { print "$column_data{$_}\n" } @column_index;

    print qq|
	</tr>
|;
  }

  print qq|
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

<input type=hidden name=type value=warehouse>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input class=submit type=submit name=action value="|
    . $locale->text('Add') . qq|">|;

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

sub warehouse_header {
  $lxdebug->enter_sub();

  $form->{title} = $locale->text("$form->{title} Warehouse");

  # $locale->text('Add Warehouse')
  # $locale->text('Edit Warehouse')

  $form->{description} =~ s/\"/&quot;/g;

  if (($rows = $form->numtextrows($form->{description}, 60)) > 1) {
    $description =
      qq|<textarea name="description" rows=$rows cols=60 wrap=soft>$form->{description}</textarea>|;
  } else {
    $description =
      qq|<input name=description size=60 value="$form->{description}">|;
  }

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{id}>
<input type=hidden name=type value=warehouse>

<table width=100%>
  <tr>
    <th class=listtop colspan=2>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <th align=right>| . $locale->text('Description') . qq|</th>
    <td>$description</td>
  </tr>
  <tr>
    <td colspan=2><hr size=3 noshade></td>
  </tr>
</table>
|;

  $lxdebug->leave_sub();
}

sub save_warehouse {
  $lxdebug->enter_sub();

  $form->isblank("description", $locale->text('Description missing!'));
  AM->save_warehouse(\%myconfig, \%$form);
  $form->redirect($locale->text('Warehouse saved!'));

  $lxdebug->leave_sub();
}

sub delete_warehouse {
  $lxdebug->enter_sub();

  AM->delete_warehouse(\%myconfig, \%$form);
  $form->redirect($locale->text('Warehouse deleted!'));

  $lxdebug->leave_sub();
}

sub continue {
  $lxdebug->enter_sub();

  &{ $form->{nextsub} };

  $lxdebug->leave_sub();
}

sub edit_units {
  $lxdebug->enter_sub();

  $units = AM->retrieve_units(\%myconfig, $form, $form->{"unit_type"}, "resolved_");
  AM->units_in_use(\%myconfig, $form, $units);
  map({ $units->{$_}->{"BASE_UNIT_DDBOX"} = AM->unit_select_data($units, $units->{$_}->{"base_unit"}, 1); } keys(%{$units}));

  @unit_list = ();
  foreach $name (sort({ lc($a) cmp lc($b) } grep({ !$units->{$_}->{"base_unit"} } keys(%{$units})))) {
    map({ push(@unit_list, $units->{$_}); }
        sort({ ($units->{$a}->{"resolved_factor"} * 1) <=> ($units->{$b}->{"resolved_factor"} * 1) }
             grep({ $units->{$_}->{"resolved_base_unit"} eq $name } keys(%{$units}))));
  }
  map({ $_->{"factor"} = $form->format_amount(\%myconfig, $_->{"factor"}, 5) if ($_->{"factor"}); } @unit_list);

  $units = AM->retrieve_units(\%myconfig, $form, $form->{"unit_type"});
  $ddbox = AM->unit_select_data($units, undef, 1);

  $form->{"title"} = sprintf($locale->text("Add and edit %s"), $form->{"unit_type"} eq "dimension" ? $locale->text("dimension units") : $locale->text("service units"));
  $form->header();
  print($form->parse_html_template("am/edit_units", { "UNITS" => \@unit_list, "NEW_BASE_UNIT_DDBOX" => $ddbox }));

  $lxdebug->leave_sub();
}

sub add_unit {
  $lxdebug->enter_sub();

  $form->isblank("new_name", $locale->text("The name is missing."));
  $units = AM->retrieve_units(\%myconfig, $form, $form->{"unit_type"});
  $form->show_generic_error($locale->text("A unit with this name does already exist.")) if ($units->{$form->{"new_name"}});

  my ($base_unit, $factor);
  if ($form->{"new_base_unit"}) {
    $form->show_generic_error($locale->text("The base unit does not exist.")) unless (defined($units->{$form->{"new_base_unit"}}));

    $form->isblank("new_factor", $locale->text("The factor is missing."));
    $factor = $form->parse_amount(\%myconfig, $form->{"new_factor"});
    $form->show_generic_error($locale->text("The factor is missing.")) unless ($factor);
    $base_unit = $form->{"new_base_unit"};
  }

  AM->add_unit(\%myconfig, $form, $form->{"new_name"}, $base_unit, $factor, $form->{"unit_type"});

  $form->{"saved_message"} = $locale->text("The unit has been saved.");

  edit_units();

  $lxdebug->leave_sub();
}

sub save_unit {
  $lxdebug->enter_sub();

  $old_units = AM->retrieve_units(\%myconfig, $form, $form->{"unit_type"}, "resolved_");
  AM->units_in_use(\%myconfig, $form, $old_units);

  $new_units = {};
  @delete_units = ();
  foreach $i (1..($form->{"rowcount"} * 1)) {
    $old_unit = $old_units->{$form->{"old_name_$i"}};
    if (!$old_unit) {
      $form->show_generic_error(sprintf($locale->text("The unit in row %d has been deleted in the meantime."), $i));
    }

    if ($form->{"unchangeable_$i"}) {
      $new_units->{$form->{"old_name_$i"}} = $old_units->{$form->{"old_name_$i"}};
      $new_units->{$form->{"old_name_$i"}}->{"unchanged_unit"} = 1;
      next;
    }

    if ($old_unit->{"in_use"}) {
      $form->show_generic_error(sprintf($locale->text("The unit in row %d has been used in the meantime and cannot be changed anymore."), $i));
    }

    if ($form->{"delete_$i"}) {
      push(@delete_units, $old_unit->{"name"});
      next;
    }

    $form->isblank("name_$i", sprintf($locale->text("The name is missing in row %d."), $i));

    $form->show_generic_error(sprintf($locale->text("The name in row %d has already been used before."), $i)) if ($new_units->{$form->{"name_$i"}});
    my %h = map({ $_ => $form->{"${_}_$i"} } qw(name base_unit factor old_name));
    $new_units->{$form->{"name_$i"}} = \%h;
    $new_units->{$form->{"name_$i"}}->{"row"} = $i;
  }

  foreach $unit (values(%{$new_units})) {
    next unless ($unit->{"old_name"});
    if ($unit->{"base_unit"}) {
      $form->show_generic_error(sprintf($locale->text("The base unit does not exist or it is about to be deleted in row %d."), $unit->{"row"}))
        unless (defined($new_units->{$unit->{"base_unit"}}));
      $unit->{"factor"} = $form->parse_amount(\%myconfig, $unit->{"factor"});
      $form->show_generic_error(sprintf($locale->text("The factor is missing in row %d."), $unit->{"row"})) unless ($unit->{"factor"} >= 1.0);
    } else {
      $unit->{"base_unit"} = undef;
      $unit->{"factor"} = undef;
    }
  }

  foreach $unit (values(%{$new_units})) {
    next if ($unit->{"unchanged_unit"});

    map({ $_->{"seen"} = 0; } values(%{$new_units}));
    $new_unit = $unit;
    while ($new_unit->{"base_unit"}) {
      $new_unit->{"seen"} = 1;
      $new_unit = $new_units->{$new_unit->{"base_unit"}};
      if ($new_unit->{"seen"}) {
        $form->show_generic_error(sprintf($locale->text("The base unit relations must not contain loops (e.g. by saying that unit A's base unit is B, " .
                                                        "B's base unit is C and C's base unit is A) in row %d."), $unit->{"row"}));
      }
    }
  }

  AM->save_units(\%myconfig, $form, $form->{"unit_type"}, $new_units, \@delete_units);

  $form->{"saved_message"} = $locale->text("The units have been saved.");

  edit_units();

  $lxdebug->leave_sub();
}
