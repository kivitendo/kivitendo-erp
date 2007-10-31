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
use SL::USTVA;
use SL::Iconv;
use CGI::Ajax;
use CGI;

use Data::Dumper;

1;

require "bin/mozilla/common.pl";

# end of main

sub add      { call_sub("add_$form->{type}"); }
sub delete   { call_sub("delete_$form->{type}"); }
sub save     { call_sub("save_$form->{type}"); }
sub edit     { call_sub("edit_$form->{type}"); }
sub continue { call_sub($form->{"nextsub"}); }

sub add_account {
  $lxdebug->enter_sub();

  $form->{title}     = "Add";
  $form->{charttype} = "A";
  AM->get_account(\%myconfig, \%$form);

  $form->{callback} =
    "$form->{script}?action=list_account&login=$form->{login}&password=$form->{password}"
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

  if ( $form->{action} eq 'edit_account') {
    $form->{account_exists} = '1';
  } 
  
  $form->{title} = $locale->text("$form->{title} Account");

  $form->{"$form->{charttype}_checked"} = "checked";
  $form->{"$form->{category}_checked"}  = "checked";

  $form->{select_tax} = "";

  my @tax_report_pos = USTVA->report_variables({
      myconfig   => \%myconfig, 
      form       => $form, 
      type       => '', 
      attribute  => 'position',
      calc       => '',
  });

  if (@{ $form->{TAXKEY} }) {
    foreach my $item (@{ $form->{TAXKEY} }) {
      $item->{rate} = $item->{rate} * 100 . '%';
    }

    # Fill in empty row for new Taxkey
    $newtaxkey_ref = {
      id             => '',
      chart_id       => '',
      accno          => '',
      tax_id         => '',
      taxdescription => '',
      rate           => '',
      taxkey_id      => '',
      pos_ustva      => '',
      startdate      => '',
    };

    push @{ $form->{ACCOUNT_TAXKEYS} }, $newtaxkey_ref;

    my $i = 0;
    foreach my $taxkey_used (@{ $form->{ACCOUNT_TAXKEYS} } ) {

      # Fill in a runningnumber
      $form->{ACCOUNT_TAXKEYS}[$i]{runningnumber} = $i;

      # Fill in the Taxkeys as select options
      foreach my $item (@{ $form->{TAXKEY} }) {
        if ($item->{id} == $taxkey_used->{tax_id}) {
          $form->{ACCOUNT_TAXKEYS}[$i]{selecttaxkey} .=
            qq|<option value="$item->{id}" selected="selected">|
            . sprintf("%.2d", $item->{taxkey}) 
            . qq|. $item->{taxdescription} ($item->{rate}) |
            . $locale->text('Tax-o-matic Account') 
            . qq|: $item->{chart_accno}\n|;
        } 
        else {
          $form->{ACCOUNT_TAXKEYS}[$i]{selecttaxkey} .=
            qq|<option value="$item->{id}">|
            . sprintf("%.2d", $item->{taxkey}) 
            . qq|. $item->{taxdescription} ($item->{rate}) |
            . $locale->text('Tax-o-matic Account')
            . qq|: $item->{chart_accno}\n|;
        }

      }
      
      # Fill in the USTVA Numbers as select options
      foreach my $item ( '', sort({ $a cmp $b } @tax_report_pos) ) {
        if ($item eq ''){
          $form->{ACCOUNT_TAXKEYS}[$i]{select_tax} .= qq|<option value="" selected="selected">-\n|;
        } 
        elsif ( $item eq $taxkey_used->{pos_ustva} ) {
          $form->{ACCOUNT_TAXKEYS}[$i]{select_tax} .= qq|<option value="$item" selected="selected">$item\n|;
        }
        else {
          $form->{ACCOUNT_TAXKEYS}[$i]{select_tax} .= qq|<option value="$item">$item\n|;
        }

      }      

      $i++;
    }
  }

  # Newaccount Folgekonto 
  if (@{ $form->{NEWACCOUNT} }) {
    if (!$form->{new_chart_valid}) {
      $form->{selectnewaccount} = qq|<option value=""> |. $locale->text('None') .q|</option>|;
    }
    foreach $item (@{ $form->{NEWACCOUNT} }) {
      if ($item->{id} == $form->{new_chart_id}) {
        $form->{selectnewaccount} .=
          qq|<option value="$item->{id}" selected>$item->{accno}--$item->{description}</option>|;
      } elsif (!$form->{new_chart_valid}) {
        $form->{selectnewaccount} .=
          qq|<option value="$item->{id}">$item->{accno}--$item->{description}</option>|;
      }

    }
  }

  $select_eur = q|<option value=""> |. $locale->text('None') .q|</option>\n|;
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
    my $text = H(SL::Iconv::convert("ISO-8859-15", $dbcharset, $eur{$item}));
    if ($item == $form->{pos_eur}) {
      $select_eur .= qq|<option value=$item selected>|. sprintf("%.2d", $item) .qq|. $text</option>\n|;
    } else {
      $select_eur .= qq|<option value=$item>|. sprintf("%.2d", $item) .qq|. $text</option>\n|;
    }

  }

  $select_bwa = q|<option value=""> |. $locale->text('None') .q|</option>\n|;

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
    my $text = H(SL::Iconv::convert("ISO-8859-15", $dbcharset, $bwapos{$item}));
    if ($item == $form->{pos_bwa}) {
      $select_bwa .= qq|<option value="$item" selected>|. sprintf("%.2d", $item) .qq|. $text\n|;
    } else {
      $select_bwa .= qq|<option value="$item">|. sprintf("%.2d", $item) .qq|. $text\n|;
    }

  }

# Wieder hinzugefügt zu evaluationszwecken (us) 09.03.2007
  $select_bilanz = q|<option value=""> |. $locale->text('None') .q|</option>\n|;
  foreach $item ((1, 2, 3, 4)) {
    if ($item == $form->{pos_bilanz}) {
      $select_bilanz .= qq|<option value=$item selected>|. sprintf("%.2d", $item) .qq|.\n|;
    } else {
      $select_bilanz .= qq|<option value=$item>|. sprintf("%.2d", $item) .qq|.\n|;
    }

  }

  # this is for our parser only! Do not remove.
  # type=submit $locale->text('Add Account')
  # type=submit $locale->text('Edit Account')
  
  $form->{type} = "account";

  # preselections category
 
  $select_category = q|<option value=""> |. $locale->text('None') .q|</option>\n|;

  %category = (
      'A'  => $locale->text('Asset'),
      'L'  => $locale->text('Liability'),
      'Q'  => $locale->text('Equity'),
      'I'  => $locale->text('Revenue'),      
      'E'  => $locale->text('Expense'),
      'C'  => $locale->text('Costs'),
  );
  foreach $item ( sort({ $a <=> $b } keys %category) ) {
    if ($item eq $form->{category}) {
      $select_category .= qq|<option value="$item" selected="selected">$category{$item} (|. sprintf("%s", $item) .qq|)\n|;
    } else {
      $select_category .= qq|<option value="$item">$category{$item} (|. sprintf("%s", $item) .qq|)\n|;
    }

  }
  
  # preselection chart type
  my $select_charttype = q{};

  my %charttype = (
      'A'  => $locale->text('Account'),
      'H'  => $locale->text('Header'),
  );
  
  foreach $item ( sort({ $a <=> $b } keys %charttype) ) {
    if ($item eq $form->{charttype}) {
      $select_charttype .= qq|<option value="$item" selected="selected">$charttype{$item}\n|;

    } else {
      $select_charttype .= qq|<option value="$item">$charttype{$item}\n|;
    }

  }

  my $ChartTypeIsAccount = ($form->{charttype} eq "A") ? "1":"";
  
  $form->header();
  
  my $parameters_ref = {
    ChartTypeIsAccount         => $ChartTypeIsAccount,
    select_category            => $select_category,
    select_charttype           => $select_charttype,
    newaccount                 => $newaccount,
    checked                    => $checked,
    select_bwa                 => $select_bwa,
    select_bilanz              => $select_bilanz,
    select_eur                 => $select_eur,
  };
  
  # Ausgabe des Templates
  print($form->parse_html_template2('am/edit_accounts', $parameters_ref));


  $lxdebug->leave_sub();
}

sub form_footer {
  $lxdebug->enter_sub();

  print qq|

<input name=callback type=hidden value="$form->{callback}">

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

  print qq|
</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub save_account {
  $lxdebug->enter_sub();

  $form->isblank("accno",       $locale->text('Account Number missing!'));
  $form->isblank("description", $locale->text('Account Description missing!'));
  
  if ($form->{charttype} eq 'A'){
    $form->isblank("category",  $locale->text('Account Type missing!'));
  }

  $form->redirect($locale->text('Account saved!'))
    if (AM->save_account(\%myconfig, \%$form));
  $form->error($locale->text('Cannot save account!'));

  $lxdebug->leave_sub();
}

sub list_account {
  $lxdebug->enter_sub();

  $form->{callback}     = build_std_url('action=list_account');
  my $link_edit_account = build_std_url('action=edit_account', 'callback');

  CA->all_accounts(\%myconfig, \%$form);

  foreach $ca (@{ $form->{CA} }) {

    $ca->{debit}  = "";
    $ca->{credit} = "";

    if ($ca->{amount} > 0) {
      $ca->{credit} = $form->format_amount(\%myconfig, $ca->{amount}, 2);
    }
    if ($ca->{amount} < 0) {
      $ca->{debit} = $form->format_amount(\%myconfig, -1 * $ca->{amount}, 2);
    }
    $ca->{heading}   = ( $ca->{charttype} eq 'H' ) ? 1:''; 
    $ca->{link_edit_account} = $link_edit_account . '&id=' . E($ca->{id});
  }
  
  # Ajax 
  my $pjx = new CGI::Ajax('list_account_details' => build_std_url('action=list_account_details'));

  # Eneable AJAX debuging
  #$pjx->DEBUG(1);
  #$pjx->JSDEBUG(1);
    
  push(@ { $form->{AJAX} }, $pjx);

  $form->{stylesheets} = "list_accounts.css";
  $form->{title}       = $locale->text('Chart of Accounts');

  $form->header;
  
  
  my $parameters_ref = {
  #   hidden_variables                => $_hidden_variables_ref,
  };
  
  # Ausgabe des Templates
  print($form->parse_html_template2('am/list_accounts', $parameters_ref));
  
  $lxdebug->leave_sub();

}


sub list_account_details {
# Ajax Funktion aus list_account_details
  $lxdebug->enter_sub();

  my $chart_id = $form->{args};

  CA->all_accounts(\%myconfig, \%$form, $chart_id);

  foreach $ca (@{ $form->{CA} }) {

    $ca->{debit}  = "&nbsp;";
    $ca->{credit} = "&nbsp;";

    if ($ca->{amount} > 0) {
      $ca->{credit} =
        $form->format_amount(\%myconfig, $ca->{amount}, 2, "&nbsp;");
    }
    if ($ca->{amount} < 0) {
      $ca->{debit} =
        $form->format_amount(\%myconfig, -1 * $ca->{amount}, 2, "&nbsp;");
    }

    my @links = split( q{:}, $ca->{link});

    $ca->{link} = q{};

    foreach my $link (@links){
      $link =    ( $link eq 'AR')             ? $locale->text('Account Link AR')
               : ( $link eq 'AP')             ? $locale->text('Account Link AP')
               : ( $link eq 'IC')             ? $locale->text('Account Link IC')
               : ( $link eq 'AR_amount' )     ? $locale->text('Account Link AR_amount')
               : ( $link eq 'AR_paid' )       ? $locale->text('Account Link AR_paid')
               : ( $link eq 'AR_tax' )        ? $locale->text('Account Link AR_tax')
               : ( $link eq 'AP_amount' )     ? $locale->text('Account Link AP_amount')
               : ( $link eq 'AP_paid' )       ? $locale->text('Account Link AP_paid')
               : ( $link eq 'AP_tax' )        ? $locale->text('Account Link AP_tax')
               : ( $link eq 'IC_sale' )       ? $locale->text('Account Link IC_sale')
               : ( $link eq 'IC_cogs' )       ? $locale->text('Account Link IC_cogs')
               : ( $link eq 'IC_taxpart' )    ? $locale->text('Account Link IC_taxpart')
               : ( $link eq 'IC_income' )     ? $locale->text('Account Link IC_income')
               : ( $link eq 'IC_expense' )    ? $locale->text('Account Link IC_expense')
               : ( $link eq 'IC_taxservice' ) ? $locale->text('Account Link IC_taxservice')
#               : ( $link eq 'CT_tax' )        ? $locale->text('Account Link CT_tax')
               : $locale->text('Unknown Link') . ': ' . $link;
      $ca->{link} .= ($link ne '') ?  "[$link] ":'';
    }

    $ca->{category} = ($ca->{category} eq 'A') ? $locale->text('Account Category A')
                    : ($ca->{category} eq 'E') ? $locale->text('Account Category E')
                    : ($ca->{category} eq 'L') ? $locale->text('Account Category L')
                    : ($ca->{category} eq 'I') ? $locale->text('Account Category I')
                    : ($ca->{category} eq 'Q') ? $locale->text('Account Category Q')
                    : ($ca->{category} eq 'C') ? $locale->text('Account Category C')
                    : ($ca->{category} eq 'G') ? $locale->text('Account Category G')
                    : $locale->text('Unknown Category') . ': ' . $ca->{category};
  }

  $form->{title} = $locale->text('Chart of Accounts');
  $form->header();

  print $form->parse_html_template2('am/list_account_details');

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

sub add_department {
  $lxdebug->enter_sub();

  $form->{title} = "Add";
  $form->{role}  = "P";

  $form->{callback} =
    "$form->{script}?action=add_department&login=$form->{login}&password=$form->{password}"
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
    "$form->{script}?action=list_department&login=$form->{login}&password=$form->{password}";

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
      qq|<td><a href=$form->{script}?action=edit_department&id=$ref->{id}&login=$form->{login}&password=$form->{password}&callback=$callback>$ref->{description}</td>|;
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

<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input class=submit type=submit name=action value="|
    . $locale->text('Add') . qq|">

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
    "$form->{script}?action=add_lead&login=$form->{login}&password=$form->{password}"
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
    "$form->{script}?action=list_lead&login=$form->{login}&password=$form->{password}";

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
      qq|<td><a href=$form->{script}?action=edit_lead&id=$ref->{id}&login=$form->{login}&password=$form->{password}&callback=$callback>$ref->{lead}</td>|;

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

<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input class=submit type=submit name=action value="|
    . $locale->text('Add') . qq|">

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
    "$form->{script}?action=add_business&login=$form->{login}&password=$form->{password}"
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
    "$form->{script}?action=list_business&login=$form->{login}&password=$form->{password}";

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
      $form->format_amount(\%myconfig, $ref->{discount} * 100);
    $description =
      $ref->{description};
    $column_data{description} =
      qq|<td><a href=$form->{script}?action=edit_business&id=$ref->{id}&login=$form->{login}&password=$form->{password}&callback=$callback>$description</td>|;
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

<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input class=submit type=submit name=action value="|
    . $locale->text('Add') . qq|">

  </form>

  </body>
  </html>
|;

  $lxdebug->leave_sub();
}

sub business_header {
  $lxdebug->enter_sub();

  $form->{title}    = $locale->text("$form->{title} Business");

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
  <td colspan=2><hr size=3 noshade></td>
  </tr>
</table>
|;

  $lxdebug->leave_sub();
}

sub save_business {
  $lxdebug->enter_sub();

  $form->isblank("description", $locale->text('Description missing!'));
  $form->{discount} = $form->parse_amount(\%myconfig, $form->{discount}) / 100;
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
    "$form->{script}?action=add_language&login=$form->{login}&password=$form->{password}"
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
    "$form->{script}?action=list_language&login=$form->{login}&password=$form->{password}";

  $callback = $form->escape($form->{callback});

  $form->{title} = $locale->text('Languages');

  @column_index = qw(description template_code article_code output_numberformat output_dateformat output_longdates);

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
  $column_header{output_numberformat} =
      qq|<th class=listheading>|
    . $locale->text('Number Format')
    . qq|</th>|;
  $column_header{output_dateformat} =
      qq|<th class=listheading>|
    . $locale->text('Date Format')
    . qq|</th>|;
  $column_header{output_longdates} =
      qq|<th class=listheading>|
    . $locale->text('Long Dates')
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
      qq|<td><a href=$form->{script}?action=edit_language&id=$ref->{id}&login=$form->{login}&password=$form->{password}&callback=$callback>$ref->{description}</td>|;
    $column_data{template_code}           = qq|<td align=right>$ref->{template_code}</td>|;
    $column_data{article_code} =
      qq|<td align=right>$ref->{article_code}</td>|;
    $column_data{output_numberformat} =
      "<td nowrap>" .
      ($ref->{output_numberformat} ? $ref->{output_numberformat} :
       $locale->text("use program settings")) .
      "</td>";
    $column_data{output_dateformat} =
      "<td nowrap>" .
      ($ref->{output_dateformat} ? $ref->{output_dateformat} :
       $locale->text("use program settings")) .
      "</td>";
    $column_data{output_longdates} =
      "<td nowrap>" .
      ($ref->{output_longdates} ? $locale->text("Yes") : $locale->text("No")) .
      "</td>";

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

<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input class=submit type=submit name=action value="|
    . $locale->text('Add') . qq|">

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

  my $numberformat =
    qq|<option value="">| . $locale->text("use program settings") .
    qq|</option>|;
  foreach $item (qw(1,000.00 1000.00 1.000,00 1000,00)) {
    $numberformat .=
      ($item eq $form->{output_numberformat})
      ? "<option selected>$item"
      : "<option>$item"
      . "</option>";
  }

  my $dateformat =
    qq|<option value="">| . $locale->text("use program settings") .
    qq|</option>|;
  foreach $item (qw(mm-dd-yy mm/dd/yy dd-mm-yy dd/mm/yy dd.mm.yy yyyy-mm-dd)) {
    $dateformat .=
      ($item eq $form->{output_dateformat})
      ? "<option selected>$item"
      : "<option>$item"
      . "</option>";
  }

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
    <td><input name=description size=30 value="| . $form->quote($form->{description}) . qq|"></td>
  <tr>
  <tr>
    <th align=right>| . $locale->text('Template Code') . qq|</th>
    <td><input name=template_code size=5 value="| . $form->quote($form->{template_code}) . qq|"></td>
  </tr>
  <tr>
    <th align=right>| . $locale->text('Article Code') . qq|</th>
    <td><input name=article_code size=10 value="| . $form->quote($form->{article_code}) . qq|"></td>
  </tr>
  <tr>
    <th align=right>| . $locale->text('Number Format') . qq|</th>
    <td><select name="output_numberformat">$numberformat</select></td>
  </tr>
  <tr>
    <th align=right>| . $locale->text('Date Format') . qq|</th>
    <td><select name="output_dateformat">$dateformat</select></td>
  </tr>
  <tr>
    <th align=right>| . $locale->text('Long Dates') . qq|</th>
    <td><input type="radio" name="output_longdates" value="1"| .
    ($form->{output_longdates} ? " checked" : "") .
    qq|>| . $locale->text("Yes") .
    qq|<input type="radio" name="output_longdates" value="0"| .
    ($form->{output_longdates} ? "" : " checked") .
    qq|>| . $locale->text("No") .
    qq|</td>
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
    "$form->{script}?action=add_buchungsgruppe&login=$form->{login}&password=$form->{password}"
    unless $form->{callback};
  AM->get_buchungsgruppe(\%myconfig, \%$form);
  $form->{"inventory_accno_id"} = $form->{"std_inventory_accno_id"};
  for (my $i = 0; 4 > $i; $i++) {
    map({ $form->{"${_}_accno_id_$i"} = $form->{"std_${_}_accno_id"}; }
        qw(income expense));
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
    "$form->{script}?action=list_buchungsgruppe&login=$form->{login}&password=$form->{password}";

  $callback = $form->escape($form->{callback});

  $form->{title} = $locale->text('Buchungsgruppen');

  @column_index = qw(up down description inventory_accno
                     income_accno_0 expense_accno_0
                     income_accno_1 expense_accno_1
                     income_accno_2 expense_accno_2
                     income_accno_3 expense_accno_3 );

  $column_header{up} =
      qq|<th class="listheading" width="16">|
    . qq|<img src="image/up.png" alt="| . $locale->text("up") . qq|">|
    . qq|</th>|;
  $column_header{down} =
      qq|<th class="listheading" width="16">|
    . qq|<img src="image/down.png" alt="| . $locale->text("down") . qq|">|
    . qq|</th>|;
  $column_header{description} =
      qq|<th class="listheading" width="40%">|
    . $locale->text('Description')
    . qq|</th>|;
  $column_header{inventory_accno} =
      qq|<th class=listheading>|
    . $locale->text('Bestandskonto')
    . qq|</th>|;
  $column_header{income_accno_0} =
      qq|<th class=listheading>|
    . $locale->text('National Revenues')
    . qq|</th>|;
  $column_header{expense_accno_0} =
      qq|<th class=listheading>|
    . $locale->text('National Expenses')
    . qq|</th>|;
  $column_header{income_accno_1} =
      qq|<th class=listheading>|
    . $locale->text('Revenues EU with UStId')
    . qq|</th>|;
  $column_header{expense_accno_1} =
      qq|<th class=listheading>|
    . $locale->text('Expenses EU with UStId')
    . qq|</th>|;
  $column_header{income_accno_2} =
      qq|<th class=listheading>|
    . $locale->text('Revenues EU without UStId')
    . qq|</th>|;
  $column_header{expense_accno_2} =
      qq|<th class=listheading>|
    . $locale->text('Expenses EU without UStId')
    . qq|</th>|;
  $column_header{income_accno_3} =
      qq|<th class=listheading>|
    . $locale->text('Foreign Revenues')
    . qq|</th>|;
  $column_header{expense_accno_3} =
      qq|<th class=listheading>|
    . $locale->text('Foreign Expenses')
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

  my $swap_link = qq|$form->{script}?action=swap_buchungsgruppen&|;
  map({ $swap_link .= $_ . "=" . $form->escape($form->{$_}) . "&" }
      qw(login password));

  my $row = 0;
  foreach $ref (@{ $form->{ALL} }) {

    $i++;
    $i %= 2;

    print qq|
        <tr valign=top class=listrow$i>
|;

    if ($row) {
      my $pref = $form->{ALL}->[$row - 1];
      $column_data{up} =
        qq|<td align="center" valign="center" width="16">| .
        qq|<a href="${swap_link}id1=$ref->{id}&id2=$pref->{id}">| .
        qq|<img border="0" src="image/up.png" alt="| . $locale->text("up") . qq|">| .
        qq|</a></td>|;
    } else {
      $column_data{up} = qq|<td width="16">&nbsp;</td>|;
    }

    if ($row == (scalar(@{ $form->{ALL} }) - 1)) {
      $column_data{down} = qq|<td width="16">&nbsp;</td>|;
    } else {
      my $nref = $form->{ALL}->[$row + 1];
      $column_data{down} =
        qq|<td align="center" valign="center" width="16">| .
        qq|<a href="${swap_link}id1=$ref->{id}&id2=$nref->{id}">| .
        qq|<img border="0" src="image/down.png" alt="| . $locale->text("down") . qq|">| .
        qq|</a></td>|;
    }

    $column_data{description} =
      qq|<td><a href=$form->{script}?action=edit_buchungsgruppe&id=$ref->{id}&login=$form->{login}&password=$form->{password}&callback=$callback>$ref->{description}</td>|;
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

    $row++;
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

<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input class=submit type=submit name=action value="|
    . $locale->text('Add') . qq|">

  </form>

  </body>
  </html>
|;

  $lxdebug->leave_sub();
}

sub buchungsgruppe_header {
  $lxdebug->enter_sub();

  $form->{title}    = $locale->text("$form->{title} Buchungsgruppe");

  # $locale->text('Add Accounting Group')
  # $locale->text('Edit Accounting Group')

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
    $form->{selectIC} =~ s/ value=\Q$form->{inventory_accno_id}\E/  value=$form->{inventory_accno_id} selected/;
    $form->{selectIC_income} =~ s/selected//g;
    $form->{selectIC_income} =~ s/ value=\Q$form->{income_accno_id_0}\E/  value=$form->{income_accno_id_0} selected/;
    $form->{selectIC_expense} =~ s/selected//g;
    $form->{selectIC_expense} =~ s/ value=\Q$form->{expense_accno_id_0}\E/  value=$form->{expense_accno_id_0} selected/;
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
		<th align=right>| . $locale->text('National Revenues') . qq|</th>
		<td><select name=income_accno_id_0>$form->{selectIC_income}</select></td>
	      </tr>
	      <tr>
		<th align=right>| . $locale->text('National Expenses') . qq|</th>
		<td><select name=expense_accno_id_0>$form->{selectIC_expense}</select></td>
	      </tr>|;
  if ($form->{id}) {
    $form->{selectIC_income} =~ s/selected//g;
    $form->{selectIC_income} =~ s/ value=\Q$form->{income_accno_id_1}\E/  value=$form->{income_accno_id_1} selected/;
    $form->{selectIC_expense} =~ s/selected//g;
    $form->{selectIC_expense} =~ s/ value=\Q$form->{expense_accno_id_1}\E/  value=$form->{expense_accno_id_1} selected/;
  }
  $linkaccounts .= qq|	      <tr>
		<th align=right>| . $locale->text('Revenues EU with UStId') . qq|</th>
		<td><select name=income_accno_id_1>$form->{selectIC_income}</select></td>
	      </tr>
	      <tr>
		<th align=right>| . $locale->text('Expenses EU with UStId') . qq|</th>
		<td><select name=expense_accno_id_1>$form->{selectIC_expense}</select></td>
	      </tr>|;

  if ($form->{id}) {
    $form->{selectIC_income} =~ s/selected//g;
    $form->{selectIC_income} =~ s/ value=\Q$form->{income_accno_id_2}\E/  value=$form->{income_accno_id_2} selected/;
    $form->{selectIC_expense} =~ s/selected//g;
    $form->{selectIC_expense} =~ s/ value=\Q$form->{expense_accno_id_2}\E/  value=$form->{expense_accno_id_2} selected/;
  }

  $linkaccounts .= qq|	      <tr>
		<th align=right>| . $locale->text('Revenues EU without UStId') . qq|</th>
		<td><select name=income_accno_id_2>$form->{selectIC_income}</select></td>
	      </tr>
	      <tr>
		<th align=right>| . $locale->text('Expenses EU without UStId') . qq|</th>
		<td><select name=expense_accno_id_2>$form->{selectIC_expense}</select></td>
	      </tr>|;

  if ($form->{id}) {
    $form->{selectIC_income} =~ s/selected//g;
    $form->{selectIC_income} =~ s/ value=\Q$form->{income_accno_id_3}\E/  value=$form->{income_accno_id_3} selected/;
    $form->{selectIC_expense} =~ s/selected//g;
    $form->{selectIC_expense} =~ s/ value=\Q$form->{expense_accno_id_3}\E/  value=$form->{expense_accno_id_3} selected/;
  }

  $linkaccounts .= qq|	      <tr>
		<th align=right>| . $locale->text('Foreign Revenues') . qq|</th>
		<td><select name=income_accno_id_3>$form->{selectIC_income}</select></td>
	      </tr>
	      <tr>
		<th align=right>| . $locale->text('Foreign Expenses') . qq|</th>
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
  $form->redirect($locale->text('Accounting Group saved!'));

  $lxdebug->leave_sub();
}

sub delete_buchungsgruppe {
  $lxdebug->enter_sub();

  AM->delete_buchungsgruppe(\%myconfig, \%$form);
  $form->redirect($locale->text('Accounting Group deleted!'));

  $lxdebug->leave_sub();
}

sub swap_buchungsgruppen {
  $lxdebug->enter_sub();

  AM->swap_sortkeys(\%myconfig, $form, "buchungsgruppen");
  list_buchungsgruppe();

  $lxdebug->leave_sub();
}


sub add_printer {
  $lxdebug->enter_sub();

  $form->{title} = "Add";

  $form->{callback} =
    "$form->{script}?action=add_printer&login=$form->{login}&password=$form->{password}"
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
    "$form->{script}?action=list_printer&login=$form->{login}&password=$form->{password}";

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
      qq|<td><a href=$form->{script}?action=edit_printer&id=$ref->{id}&login=$form->{login}&password=$form->{password}&callback=$callback>$ref->{printer_description}</td>|;
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

<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input class=submit type=submit name=action value="|
    . $locale->text('Add') . qq|">

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
    "$form->{script}?action=add_payment&login=$form->{login}&password=$form->{password}"
    unless $form->{callback};

  $form->{terms_netto} = 0;
  $form->{terms_skonto} = 0;
  $form->{percent_skonto} = 0;
  my @languages = AM->language(\%myconfig, $form, 1);
  map({ $_->{"language"} = $_->{"description"};
        $_->{"language_id"} = $_->{"id"}; } @languages);
  $form->{"TRANSLATION"} = \@languages;
  &payment_header;
  &form_footer;

  $lxdebug->leave_sub();
}

sub edit_payment {
  $lxdebug->enter_sub();

  $form->{title} = "Edit";

  AM->get_payment(\%myconfig, $form);
  $form->{percent_skonto} =
    $form->format_amount(\%myconfig, $form->{percent_skonto} * 100);

  &payment_header;

  $form->{orphaned} = 1;
  &form_footer;

  $lxdebug->leave_sub();
}

sub list_payment {
  $lxdebug->enter_sub();

  AM->payment(\%myconfig, \%$form);

  $form->{callback} = build_std_url("action=list_payment");

  $callback = $form->escape($form->{callback});

  $form->{title} = $locale->text('Payment Terms');

  @column_index = qw(up down description description_long terms_netto
                     terms_skonto percent_skonto);

  $column_header{up} =
      qq|<th class="listheading" align="center" valign="center" width="16">|
    . qq|<img src="image/up.png" alt="| . $locale->text("up") . qq|">|
    . qq|</th>|;
  $column_header{down} =
      qq|<th class="listheading" align="center" valign="center" width="16">|
    . qq|<img src="image/down.png" alt="| . $locale->text("down") . qq|">|
    . qq|</th>|;
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

  my $swap_link = build_std_url("action=swap_payment_terms");

  my $row = 0;
  foreach $ref (@{ $form->{ALL} }) {

    $i++;
    $i %= 2;

    print qq|
        <tr valign=top class=listrow$i>
|;

    if ($row) {
      my $pref = $form->{ALL}->[$row - 1];
      $column_data{up} =
        qq|<td align="center" valign="center" width="16">| .
        qq|<a href="${swap_link}&id1=$ref->{id}&id2=$pref->{id}">| .
        qq|<img border="0" src="image/up.png" alt="| . $locale->text("up") . qq|">| .
        qq|</a></td>|;
    } else {
      $column_data{up} = qq|<td width="16">&nbsp;</td>|;
    }

    if ($row == (scalar(@{ $form->{ALL} }) - 1)) {
      $column_data{down} = qq|<td width="16">&nbsp;</td>|;
    } else {
      my $nref = $form->{ALL}->[$row + 1];
      $column_data{down} =
        qq|<td align="center" valign="center" width="16">| .
        qq|<a href="${swap_link}&id1=$ref->{id}&id2=$nref->{id}">| .
        qq|<img border="0" src="image/down.png" alt="| . $locale->text("down") . qq|">| .
        qq|</a></td>|;
    }

    $column_data{description} =
      qq|<td><a href="| .
      build_std_url("action=edit_payment", "id=$ref->{id}", "callback=$callback") .
      qq|">| . H($ref->{description}) . qq|</a></td>|;
    $column_data{description_long} =
      qq|<td>| . H($ref->{description_long}) . qq|</td>|;
    $column_data{terms_netto} =
      qq|<td align=right>$ref->{terms_netto}</td>|;
    $column_data{terms_skonto} =
      qq|<td align=right>$ref->{terms_skonto}</td>|;
    $column_data{percent_skonto} =
      qq|<td align=right>| .
      $form->format_amount(\%myconfig, $ref->{percent_skonto} * 100) .
      qq|%</td>|;
    map { print "$column_data{$_}\n" } @column_index;

    print qq|
	</tr>
|;
    $row++;
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

<input type=hidden name=type value=payment>

<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input class=submit type=submit name=action value="|
    . $locale->text('Add') . qq|">

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
|;

  foreach my $language (@{ $form->{"TRANSLATION"} }) {
    print qq|
  <tr>
    <th align="right">| .
    sprintf($locale->text('Translation (%s)'),
            $language->{"language"})
    . qq|</th>
    <td><input name="description_long_$language->{language_id}" size="50"
         value="| . Q($language->{"description_long"}) . qq|"></td>
  </tr>
|;
  }

  print qq|
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

<p>| . $locale->text("You can use the following strings in the long " .
                     "description and all translations. They will be " .
                     "replaced by their actual values by Lx-Office " .
                     "before they're output.")
. qq|</p>

<ul>
  <li>| . $locale->text("&lt;%netto_date%&gt; -- Date the payment is due in " .
                        "full")
. qq|</li>
  <li>| . $locale->text("&lt;%skonto_date%&gt; -- Date the payment is due " .
                        "with discount")
. qq|</li>
  <li>| . $locale->text("&lt;%skonto_amount%&gt; -- The deductible amount")
. qq|</li>
  <li>| . $locale->text("&lt;%total%&gt; -- Amount payable")
. qq|</li>
  <li>| . $locale->text("&lt;%total_wo_skonto%&gt; -- Amount payable less discount")
. qq|</li>
  <li>| . $locale->text("&lt;%invtotal%&gt; -- Invoice total")
. qq|</li>
  <li>| . $locale->text("&lt;%invtotal_wo_skonto%&gt; -- Invoice total less discount")
. qq|</li>
  <li>| . $locale->text("&lt;%currency%&gt; -- The selected currency")
. qq|</li>
  <li>| . $locale->text("&lt;%terms_netto%&gt; -- The number of days for " .
                        "full payment")
. qq|</li>
  <li>| . $locale->text("&lt;%account_number%&gt; -- Your account number")
. qq|</li>
  <li>| . $locale->text("&lt;%bank%&gt; -- Your bank")
. qq|</li>
  <li>| . $locale->text("&lt;%bank_code%&gt; -- Your bank code")
. qq|</li>
</ul>|;

  $lxdebug->leave_sub();
}

sub save_payment {
  $lxdebug->enter_sub();

  $form->isblank("description", $locale->text('Description missing!'));
  $form->{"percent_skonto"} =
    $form->parse_amount(\%myconfig, $form->{percent_skonto}) / 100;
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

sub swap_payment_terms {
  $lxdebug->enter_sub();

  AM->swap_sortkeys(\%myconfig, $form, "payment_terms");
  list_payment();

  $lxdebug->leave_sub();
}

sub _build_cfg_options {
  my $idx   = shift;
  my $array = uc($idx) . 'S';

  $form->{$array} = [];
  foreach my $item (@_) {
    push @{ $form->{$array} }, {
      'name'     => $item,
      'value'    => $item,
      'selected' => $item eq $myconfig{$idx},
    };
  }
}

sub config {
  $lxdebug->enter_sub();

  # get defaults for account numbers and last numbers
  AM->defaultaccounts(\%myconfig, \%$form);

  map { $form->{"defaults_${_}"} = $form->{defaults}->{$_} } keys %{ $form->{defaults} };

  _build_cfg_options('dateformat', qw(mm-dd-yy mm/dd/yy dd-mm-yy dd/mm/yy dd.mm.yy yyyy-mm-dd));
  _build_cfg_options('numberformat', qw(1,000.00 1000.00 1.000,00 1000,00));

  @formats = ();
  if ($opendocument_templates && $openofficeorg_writer_bin &&
      $xvfb_bin && (-x $openofficeorg_writer_bin) && (-x $xvfb_bin)) {
    push(@formats, { "name" => $locale->text("PDF (OpenDocument/OASIS)"),
                     "value" => "opendocument_pdf" });
  }
  if ($latex_templates) {
    push(@formats, { "name" => $locale->text("PDF"), "value" => "pdf" });
  }
  push(@formats, { "name" => "HTML", "value" => "html" });
  if ($latex_templates) {
    push(@formats, { "name" => $locale->text("Postscript"),
                     "value" => "postscript" });
  }
  if ($opendocument_templates) {
    push(@formats, { "name" => $locale->text("OpenDocument/OASIS"),
                     "value" => "opendocument" });
  }

  if (!$myconfig{"template_format"}) {
    $myconfig{"template_format"} = "pdf";
  }
  $form->{TEMPLATE_FORMATS} = [];
  foreach $item (@formats) {
    push @{ $form->{TEMPLATE_FORMATS} }, {
      'name'     => $item->{name},
      'value'    => $item->{value},
      'selected' => $item->{value} eq $myconfig{template_format},
    };
  }

  if (!$myconfig{"default_media"}) {
    $myconfig{"default_media"} = "screen";
  }

  my %selected = ($myconfig{"default_media"} => "selected");
  $form->{MEDIA} = [
    { 'name' => $locale->text('Screen'),  'value' => 'screen',  'selected' => $selected{screen}, },
    { 'name' => $locale->text('Printer'), 'value' => 'printer', 'selected' => $selected{printer}, },
    { 'name' => $locale->text('Queue'),   'value' => 'queue',   'selected' => $selected{queue}, },
    ];

  AM->printer(\%myconfig, $form);

  $form->{PRINTERS} = [];
  foreach my $printer (@{$form->{"ALL"}}) {
    push @{ $form->{PRINTERS} }, {
      'name'     => $printer->{printer_description},
      'value'    => $printer->{id},
      'selected' => $printer->{id} == $myconfig{default_printer_id},
    };
  }

  %countrycodes = User->country_codes;

  $countrycodes{""} = "American English";
  $form->{COUNTRYCODES} = [];
  foreach $countrycode (sort { $countrycodes{$a} cmp $countrycodes{$b} } keys %countrycodes) {
    push @{ $form->{COUNTRYCODES} }, {
      'name'     => $countrycodes{$countrycode},
      'value'    => $countrycode,
      'selected' => $countrycode eq $myconfig{countrycode},
    };
  }

  foreach $key (keys %{ $form->{IC} }) {
    foreach $accno (sort keys %{ $form->{IC}->{$key} }) {
      my $array = "ACCNOS_" . uc($key);
      $form->{$array} ||= [];

      my $value = "${accno}--" . $form->{IC}->{$key}->{$accno}->{description};
      push @{ $form->{$array} }, {
        'name'     => $value,
        'value'    => $value,
        'selected' => $form->{IC}->{$key}->{$accno}->{id} == $form->{defaults}->{$key},
      };
    }
  }

  $form->{STYLESHEETS} = [];
  foreach $item (qw(lx-office-erp.css Win2000.css)) {
    push @{ $form->{STYLESHEETS} }, {
      'name'     => $item,
      'value'    => $item,
      'selected' => $item eq $myconfig{stylesheet},
    };
  }

  $myconfig{show_form_details}              = 1 unless (defined($myconfig{show_form_details}));
  $form->{"menustyle_$myconfig{menustyle}"} = 1;

  $form->{title}                            = $locale->text('Edit Preferences for #1', $form->{login});

  $form->header();
  print $form->parse_html_template2('am/config');

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

sub edit_units {
  $lxdebug->enter_sub();

  $units = AM->retrieve_units(\%myconfig, $form, $form->{"unit_type"}, "resolved_");
  AM->units_in_use(\%myconfig, $form, $units);
  map({ $units->{$_}->{"BASE_UNIT_DDBOX"} = AM->unit_select_data($units, $units->{$_}->{"base_unit"}, 1); } keys(%{$units}));

  @languages = AM->language(\%myconfig, $form, 1);

  @unit_list = sort({ $a->{"sortkey"} <=> $b->{"sortkey"} } values(%{$units}));

  my $i = 1;
  foreach (@unit_list) {
    $_->{"factor"} = $form->format_amount(\%myconfig, $_->{"factor"} * 1) if ($_->{"factor"});
    $_->{"UNITLANGUAGES"} = [];
    foreach my $lang (@languages) {
      push(@{ $_->{"UNITLANGUAGES"} },
           { "idx" => $i,
             "unit" => $_->{"name"},
             "language_id" => $lang->{"id"},
             "localized" => $_->{"LANGUAGES"}->{$lang->{"template_code"}}->{"localized"},
             "localized_plural" => $_->{"LANGUAGES"}->{$lang->{"template_code"}}->{"localized_plural"},
           });
    }
    $i++;
  }

  $units = AM->retrieve_units(\%myconfig, $form, $form->{"unit_type"});
  $ddbox = AM->unit_select_data($units, undef, 1);

  my $updownlink = build_std_url("action=swap_units", "unit_type");

  $form->{"title"} = sprintf($locale->text("Add and edit %s"), $form->{"unit_type"} eq "dimension" ? $locale->text("dimension units") : $locale->text("service units"));
  $form->header();
  print($form->parse_html_template2("am/edit_units",
                                    { "UNITS"               => \@unit_list,
                                      "NEW_BASE_UNIT_DDBOX" => $ddbox,
                                      "LANGUAGES"           => \@languages,
                                      "updownlink"          => $updownlink }));

  $lxdebug->leave_sub();
}

sub add_unit {
  $lxdebug->enter_sub();

  $form->isblank("new_name", $locale->text("The name is missing."));
  $units = AM->retrieve_units(\%myconfig, $form, $form->{"unit_type"});
  $all_units = AM->retrieve_units(\%myconfig, $form);
  $form->show_generic_error($locale->text("A unit with this name does already exist.")) if ($all_units->{$form->{"new_name"}});

  my ($base_unit, $factor);
  if ($form->{"new_base_unit"}) {
    $form->show_generic_error($locale->text("The base unit does not exist.")) unless (defined($units->{$form->{"new_base_unit"}}));

    $form->isblank("new_factor", $locale->text("The factor is missing."));
    $factor = $form->parse_amount(\%myconfig, $form->{"new_factor"});
    $form->show_generic_error($locale->text("The factor is missing.")) unless ($factor);
    $base_unit = $form->{"new_base_unit"};
  }

  my @languages;
  foreach my $lang (AM->language(\%myconfig, $form, 1)) {
    next unless ($form->{"new_localized_$lang->{id}"} || $form->{"new_localized_plural_$lang->{id}"});
    push(@languages, { "id" => $lang->{"id"},
                       "localized" => $form->{"new_localized_$lang->{id}"},
                       "localized_plural" => $form->{"new_localized_plural_$lang->{id}"},
         });
  }

  AM->add_unit(\%myconfig, $form, $form->{"new_name"}, $base_unit, $factor, $form->{"unit_type"}, \@languages);

  $form->{"saved_message"} = $locale->text("The unit has been saved.");

  edit_units();

  $lxdebug->leave_sub();
}

sub set_unit_languages {
  $lxdebug->enter_sub();

  my ($unit, $languages, $idx) = @_;

  $unit->{"LANGUAGES"} = [];

  foreach my $lang (@{$languages}) {
    push(@{ $unit->{"LANGUAGES"} },
         { "id" => $lang->{"id"},
           "localized" => $form->{"localized_${idx}_$lang->{id}"},
           "localized_plural" => $form->{"localized_plural_${idx}_$lang->{id}"},
         });
  }

  $lxdebug->leave_sub();
}

sub save_unit {
  $lxdebug->enter_sub();

  $old_units = AM->retrieve_units(\%myconfig, $form, $form->{"unit_type"}, "resolved_");
  AM->units_in_use(\%myconfig, $form, $old_units);

  @languages = AM->language(\%myconfig, $form, 1);

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
      set_unit_languages($new_units->{$form->{"old_name_$i"}}, \@languages, $i);
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
    set_unit_languages($new_units->{$form->{"old_name_$i"}}, \@languages, $i);
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

sub show_history_search {
	$lxdebug->enter_sub();
	
	$form->{title} = $locale->text("History Search");
    $form->header();
    
    print $form->parse_html_template2("common/search_history");
	
	$lxdebug->leave_sub();
}

sub show_am_history {
	$lxdebug->enter_sub();
	my %search = ( "Artikelnummer" => "parts",
				   "Kundennummer"  => "customer",
				   "Lieferantennummer" => "vendor",
				   "Projektnummer" => "project",
				   "Buchungsnummer" => "oe",
				   "Eingangsrechnungnummer" => "ap",
				   "Ausgangsrechnungnummer" => "ar",
           "Mahnungsnummer" => "dunning"
		);
	my %searchNo = ( "Artikelnummer" => "partnumber",
				     "Kundennummer"  => "customernumber",
				     "Lieferantennummer" => "vendornumber",
				     "Projektnummer" => "projectnummer",
				     "Buchungsnummer" => "ordnumber",
				     "Eingangsrechnungnummer" => "invnumber",
				     "Ausgangsrechnungnummer" => "invnumber",
             "Mahnungsnummer" => "dunning_id"
		);
	
	my $restriction;
	my $tempNo = 0;
	foreach(split(/\,/, $form->{einschraenkungen})) {
		if($tempNo == 0) {
			$restriction .= " AND addition = '" . $_ . "'";
			$tempNo = 1;
		} 
		else {
			$restriction .= " OR addition = '" . $_ . "'";
		}
	}
	$restriction .= (($form->{transdate} ne "" && $form->{reqdate} ne "") 
						? qq| AND st.itime::date >= '| . $form->{transdate} . qq|' AND st.itime::date <= '| . $form->{reqdate} . qq|'|
						: (($form->{transdate} ne "" && $form->{reqdate} eq "") 
							? qq| AND st.itime::date >= '| . $form->{transdate} . qq|'|
							: ($form->{transdate} eq "" && $form->{reqdate} ne "") 
								? qq| AND st.itime::date <= '| . $form->{reqdate} . qq|'|
								: ""
							)
						);
  $restriction .= ($form->{mitarbeiter} eq "" ? "" 
          : ($form->{mitarbeiter} =~ /^[0-9]*$/  
            ? " AND employee_id = " . $form->{mitarbeiter} 
            : " AND employee_id = " . &get_employee_id($form->{mitarbeiter}, $dbh)));
  
	my $dbh = $form->dbconnect(\%myconfig);
	my $query = qq|SELECT trans_id AS id FROM history_erp | . 
                ($form->{'searchid'} ? 
                  qq| WHERE snumbers = '| . $searchNo{$form->{'what2search'}} . qq|_| . $form->{'searchid'} . qq|'| : 
                  qq| WHERE snumbers ~ '^| . $searchNo{$form->{'what2search'}} . qq|'|);

  my $sth = $dbh->prepare($query);
	
	$sth->execute() || $form->dberror($query);
  
  $form->{title} = $locale->text("History Search");
	$form->header();
	
  my $i = 1;
  my $daten = qq||;
  while(my $hash_ref = $sth->fetchrow_hashref()){
    if($i) {
      $daten .= $hash_ref->{id};
      $i = 0;
    }
    else {
      $daten .= " OR trans_id = " . $hash_ref->{id};
    }
  }
  
  my ($sort, $sortby) = split(/\-\-/, $form->{order});
  $sort =~ s/.*\.(.*)$/$1/;

	print $form->parse_html_template2("common/show_history", 
    {"DATEN" => $form->get_history($dbh, $daten, $restriction, $form->{order}),
     "SUCCESS" => ($form->get_history($dbh, $daten, $restriction, $form->{order}) ne "0"),
     "NONEWWINDOW" => 1,
     uc($sort) => 1,
     uc($sort)."BY" => $sortby
    });
	$dbh->disconnect();
  $lxdebug->leave_sub();
}

sub get_employee_id {
	$lxdebug->enter_sub();
	my $query = qq|SELECT id FROM employee WHERE name = '| . $_[0] . qq|'|;
	my $sth = $_[1]->prepare($query);
	$sth->execute() || $form->dberror($query);
	my $return = $sth->fetch();
	$sth->finish();
	return ${$return}[0];
	$lxdebug->leave_sub();
}

sub swap_units {
  $lxdebug->enter_sub();

  my $dir = $form->{"dir"} eq "down" ? "down" : "up";
  my $unit_type = $form->{"unit_type"} eq "dimension" ?
    "dimension" : "service";
  AM->swap_units(\%myconfig, $form, $dir, $form->{"name"}, $unit_type);

  edit_units();

  $lxdebug->leave_sub();
}

sub add_tax {
  $lxdebug->enter_sub();

  $form->{title} =  $locale->text('Add');

  $form->{callback} =
    "$form->{script}?action=add_tax&login=$form->{login}&password=$form->{password}"
    unless $form->{callback};

  _get_taxaccount_selection();

  $form->header();
  
  my $parameters_ref = {
#    ChartTypeIsAccount         => $ChartTypeIsAccount,
  };
  
  # Ausgabe des Templates
  print($form->parse_html_template2('am/edit_tax', $parameters_ref));

  $lxdebug->leave_sub();
}

sub edit_tax {
  $lxdebug->enter_sub();

  $form->{title} =  $locale->text('Edit');

  AM->get_tax(\%myconfig, \%$form);
  _get_taxaccount_selection();

  $form->{rate} = $form->format_amount(\%myconfig, $form->{rate}, 2);

  $form->header();
  
  my $parameters_ref = {
  };
  
  # Ausgabe des Templates
  print($form->parse_html_template2('am/edit_tax', $parameters_ref));

  $lxdebug->leave_sub();
}

sub list_tax {
  $lxdebug->enter_sub();

  AM->taxes(\%myconfig, \%$form);

  map { $_->{rate} = $form->format_amount(\%myconfig, $_->{rate}, 2) } @{ $form->{TAX} };

  $form->{callback} = build_std_url('action=list_tax');

  $form->{title} = $locale->text('Tax-O-Matic');

  $form->header();
  
  # Ausgabe des Templates
  print($form->parse_html_template2('am/list_tax', $parameters_ref));

  $lxdebug->leave_sub();
}

sub _get_taxaccount_selection{
  $lxdebug->enter_sub();

  AM->get_tax_accounts(\%myconfig, \%$form);

  map { $_->{selected} = $form->{chart_id} == $_->{id} } @{ $form->{ACCOUNTS} };

  $lxdebug->leave_sub();
}

sub save_tax {
  $lxdebug->enter_sub();

  $form->isblank("rate", $locale->text('Taxrate missing!'));
  $form->isblank("taxdescription", $locale->text('Taxdescription  missing!'));
  $form->isblank("taxkey", $locale->text('Taxkey  missing!'));

  $form->{rate} = $form->parse_amount(\%myconfig, $form->{rate});

  if ( $form->{rate} < 0 || $form->{rate} >= 100 ) {
    $form->error($locale->text('Tax Percent is a number between 0 and 100'));
  }

  if ( $form->{rate} <= 0.99 && $form->{rate} > 0 ) {
    $form->error($locale->text('Tax Percent is a number between 0 and 100'));
  }  

  AM->save_tax(\%myconfig, \%$form);
  $form->redirect($locale->text('Tax saved!'));

  $lxdebug->leave_sub();
}

sub delete_tax {
  $lxdebug->enter_sub();

  AM->delete_tax(\%myconfig, \%$form);
  $form->redirect($locale->text('Tax deleted!'));

  $lxdebug->leave_sub();
}

sub add_price_factor {
  $lxdebug->enter_sub();

  $form->{title}      = $locale->text('Add Price Factor');
  $form->{callback} ||= build_std_url('action=add_price_factor');
  $form->{fokus}      = 'description';

  $form->header();
  print $form->parse_html_template2('am/edit_price_factor');

  $lxdebug->leave_sub();
}

sub edit_price_factor {
  $lxdebug->enter_sub();

  $form->{title}      = $locale->text('Edit Price Factor');
  $form->{callback} ||= build_std_url('action=add_price_factor');
  $form->{fokus}      = 'description';

  AM->get_price_factor(\%myconfig, $form);

  $form->{factor} = $form->format_amount(\%myconfig, $form->{factor} * 1);

  $form->header();
  print $form->parse_html_template2('am/edit_price_factor');

  $lxdebug->leave_sub();
}

sub list_price_factors {
  $lxdebug->enter_sub();

  AM->get_all_price_factors(\%myconfig, \%$form);

  my $previous;
  foreach my $current (@{ $form->{PRICE_FACTORS} }) {
    if ($previous) {
      $previous->{next_id}    = $current->{id};
      $current->{previous_id} = $previous->{id};
    }

    $current->{factor} = $form->format_amount(\%myconfig, $current->{factor} * 1);

    $previous = $current;
  }

  $form->{callback} = build_std_url('action=list_price_factors');
  $form->{title}    = $locale->text('Price Factors');
  $form->{url_base} = build_std_url('callback');

  $form->header();
  print $form->parse_html_template2('am/list_price_factors');

  $lxdebug->leave_sub();
}

sub save_price_factor {
  $lxdebug->enter_sub();

  $form->isblank("description", $locale->text('Description missing!'));
  $form->isblank("factor", $locale->text('Factor missing!'));

  $form->{factor} = $form->parse_amount(\%myconfig, $form->{factor});

  AM->save_price_factor(\%myconfig, $form);

  $form->{callback} .= '&MESSAGE=' . $form->escape($locale->text('Price factor saved!')) if ($form->{callback});

  $form->redirect($locale->text('Price factor saved!'));

  $lxdebug->leave_sub();
}

sub delete_price_factor {
  $lxdebug->enter_sub();

  AM->delete_price_factor(\%myconfig, \%$form);

  $form->{callback} .= '&MESSAGE=' . $form->escape($locale->text('Price factor deleted!')) if ($form->{callback});

  $form->redirect($locale->text('Price factor deleted!'));

  $lxdebug->leave_sub();
}

sub swap_price_factors {
  $lxdebug->enter_sub();

  AM->swap_sortkeys(\%myconfig, $form, 'price_factors');
  list_price_factors();

  $lxdebug->leave_sub();
}

