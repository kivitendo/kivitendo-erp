#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger, Accounting
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
# Inventory received module
#
#======================================================================

use SL::IR;
use SL::PE;

require "$form->{path}/io.pl";
require "$form->{path}/arap.pl";

1;

# end of main

sub add {
  $lxdebug->enter_sub();

  $form->{title} = $locale->text('Add Vendor Invoice');

  &invoice_links;
  &prepare_invoice;
  &display_form;

  $lxdebug->leave_sub();
}

sub edit {
  $lxdebug->enter_sub();

  $form->{title} = $locale->text('Edit Vendor Invoice');

  &invoice_links;
  &prepare_invoice;
  &display_form;

  $lxdebug->leave_sub();
}

sub invoice_links {
  $lxdebug->enter_sub();

  # create links
  $form->{webdav} = $webdav;

  # set jscalendar
  $form->{jscalendar} = $jscalendar;

  $form->create_links("AP", \%myconfig, "vendor");

  #quote all_vendor Bug 133
  foreach $ref (@{ $form->{all_vendor} }) {
    $ref->{name} = $form->quote($ref->{name});
  }

  if ($form->{all_vendor}) {
    unless ($form->{vendor_id}) {
      $form->{vendor_id} = $form->{all_vendor}->[0]->{id};
    }
  }
  if ($form->{payment_id}) {
    $payment_id = $form->{payment_id};
  }
  if ($form->{language_id}) {
    $language_id = $form->{language_id};
  }
  if ($form->{taxzone_id}) {
    $taxzone_id = $form->{taxzone_id};
  }

  $cp_id = $form->{cp_id};
  IR->get_vendor(\%myconfig, \%$form);
  IR->retrieve_invoice(\%myconfig, \%$form);
  $form->{cp_id} = $cp_id;
 
  if ($payment_id) {
    $form->{payment_id} = $payment_id;
  }
  if ($language_id) {
    $form->{language_id} = $language_id;
  }
  if ($taxzone_id) {
    $form->{taxzone_id} = $taxzone_id;
  }

  # currencies
  @curr = split(/:/, $form->{currencies});
  chomp $curr[0];
  $form->{defaultcurrency} = $curr[0];

  map { $form->{selectcurrency} .= "<option>$_\n" } @curr;

  $form->{oldvendor} = "$form->{vendor}--$form->{vendor_id}";

  # vendors
  if (@{ $form->{all_vendor} }) {
    $form->{vendor} = "$form->{vendor}--$form->{vendor_id}";
    map { $form->{selectvendor} .= "<option>$_->{name}--$_->{id}\n" }
      (@{ $form->{all_vendor} });
  }

  # departments
  if ($form->{all_departments}) {
    $form->{selectdepartment} = "<option>\n";
    $form->{department}       = "$form->{department}--$form->{department_id}";

    map {
      $form->{selectdepartment} .=
        "<option>$_->{description}--$_->{id}\n"
    } (@{ $form->{all_departments} });
  }

  # forex
  $form->{forex} = $form->{exchangerate};
  $exchangerate = ($form->{exchangerate}) ? $form->{exchangerate} : 1;

  foreach $key (keys %{ $form->{AP_links} }) {

    foreach $ref (@{ $form->{AP_links}{$key} }) {
      $form->{"select$key"} .= "<option>$ref->{accno}--$ref->{description}\n";
    }

    if ($key eq "AP_paid") {
      for $i (1 .. scalar @{ $form->{acc_trans}{$key} }) {
        $form->{"AP_paid_$i"} =
          "$form->{acc_trans}{$key}->[$i-1]->{accno}--$form->{acc_trans}{$key}->[$i-1]->{description}";

        # reverse paid
        $form->{"paid_$i"}     = $form->{acc_trans}{$key}->[$i - 1]->{amount};
        $form->{"datepaid_$i"} =
          $form->{acc_trans}{$key}->[$i - 1]->{transdate};
        $form->{"forex_$i"} = $form->{"exchangerate_$i"} =
          $form->{acc_trans}{$key}->[$i - 1]->{exchangerate};
        $form->{"source_$i"} = $form->{acc_trans}{$key}->[$i - 1]->{source};
        $form->{"memo_$i"}   = $form->{acc_trans}{$key}->[$i - 1]->{memo};

        $form->{paidaccounts} = $i;
      }
    } else {
      $form->{$key} =
        "$form->{acc_trans}{$key}->[0]->{accno}--$form->{acc_trans}{$key}->[0]->{description}";
    }

  }

  $form->{paidaccounts} = 1 unless (exists $form->{paidaccounts});

  $form->{AP} = $form->{AP_1} unless $form->{id};

  $form->{locked} =
    ($form->datetonum($form->{invdate}, \%myconfig) <=
     $form->datetonum($form->{closedto}, \%myconfig));

  $lxdebug->leave_sub();
}

sub prepare_invoice {
  $lxdebug->enter_sub();

  if ($form->{id}) {

    map { $form->{$_} =~ s/\"/&quot;/g } qw(invnumber ordnumber quonumber);

    my $i = 0;
    foreach $ref (@{ $form->{invoice_details} }) {
      $i++;
      map { $form->{"${_}_$i"} = $ref->{$_} } keys %{$ref};

      ($dec) = ($form->{"sellprice_$i"} =~ /\.(\d+)/);
      $dec           = length $dec;
      $decimalplaces = ($dec > 2) ? $dec : 2;

      $form->{"sellprice_$i"} =
        $form->format_amount(\%myconfig, $form->{"sellprice_$i"},
                             $decimalplaces);

      (my $dec_qty) = ($form->{"qty_$i"} =~ /\.(\d+)/);
      $dec_qty = length $dec_qty;

      $form->{"qty_$i"} =
        $form->format_amount(\%myconfig, ($form->{"qty_$i"} * -1), $dec_qty);

      $form->{rowcount} = $i;
    }
  }

  $lxdebug->leave_sub();
}

sub form_header {
  $lxdebug->enter_sub();

  # set option selected
  foreach $item (qw(AP vendor currency department contact)) {
    $form->{"select$item"} =~ s/ selected//;
    $form->{"select$item"} =~
      s/option>\Q$form->{$item}\E/option selected>$form->{$item}/;
  }

  $form->{radier} =
    ($form->current_date(\%myconfig) eq $form->{gldate}) ? 1 : 0;

  #quote selectvendor Bug 133
  $form->{"selectvendor"} = $form->quote($form->{"selectvendor"});

  $form->{exchangerate} =
    $form->format_amount(\%myconfig, $form->{exchangerate});

  $form->{creditlimit} =
    $form->format_amount(\%myconfig, $form->{creditlimit}, 0, "0");
  $form->{creditremaining} =
    $form->format_amount(\%myconfig, $form->{creditremaining}, 0, "0");

  #build contacts
  if ($form->{all_contacts}) {

    $form->{selectcontact} = "";
    foreach $item (@{ $form->{all_contacts} }) {
      if ($form->{cp_id} == $item->{cp_id}) {
        $form->{selectcontact} .=
          "<option selected>$item->{cp_name}--$item->{cp_id}";
      } else {
        $form->{selectcontact} .= "<option>$item->{cp_name}--$item->{cp_id}";
      }
    }
  }

  $exchangerate = "";
  if ($form->{currency} ne $form->{defaultcurrency}) {
    if ($form->{forex}) {
      $exchangerate .= qq|
                <th align=right nowrap>|
        . $locale->text('Exchangerate') . qq|</th>
                <td>$form->{exchangerate}<input type=hidden name=exchangerate value=$form->{exchangerate}></td>
|;
    } else {
      $exchangerate .= qq|
                <th align=right nowrap>|
        . $locale->text('Exchangerate') . qq|</th>
                <td><input name=exchangerate size=10 value=$form->{exchangerate}></td>
|;
    }
  }
  $exchangerate .= qq|
<input type=hidden name=forex value=$form->{forex}>
|;


  if (@{ $form->{TAXZONE} }) {
    $form->{selecttaxzone} = "";
    foreach $item (@{ $form->{TAXZONE} }) {
      if ($item->{id} == $form->{taxzone_id}) {
        $form->{selecttaxzone} .=
          "<option value=$item->{id} selected>" . H($item->{description}) .
          "</option>";
      } else {
        $form->{selecttaxzone} .=
          "<option value=$item->{id}>" . H($item->{description}) . "</option>";
      }

    }
  } else {
    $form->{selecttaxzone} =~ s/ selected//g;
    if ($form->{taxzone_id} ne "") {
      $form->{selecttaxzone} =~ s/value=$form->{taxzone_id}/value=$form->{taxzone_id} selected/;
    }
  }

  $taxzone = qq|
	      <tr>
		<th align=right>| . $locale->text('Steuersatz') . qq|</th>
		<td><select name=taxzone_id>$form->{selecttaxzone}</select></td>
		<input type=hidden name=selecttaxzone value="$form->{selecttaxzone}">
	      </tr>|;



  $vendor =
    ($form->{selectvendor})
    ? qq|<select name=vendor>$form->{selectvendor}</select>\n<input type=hidden name="selectvendor" value="$form->{selectvendor}">|
    : qq|<input name=vendor value="$form->{vendor}" size=35>|;

  $contact =
    ($form->{selectcontact})
    ? qq|<select name=contact>$form->{selectcontact}</select>\n<input type=hidden name="selectcontact" value="$form->{selectcontact}">|
    : qq|<input name=contact value="$form->{contact}" size=35>|;

  $department = qq|
              <tr>
	      <th align="right" nowrap>| . $locale->text('Department') . qq|</th>
	      <td colspan=3><select name=department>$form->{selectdepartment}</select>
	      <input type=hidden name=selectdepartment value="$form->{selectdepartment}">
	      </td>
	    </tr>
| if $form->{selectdepartment};

  $n = ($form->{creditremaining} =~ /-/) ? "0" : "1";

  # use JavaScript Calendar or not
  $form->{jsscript} = $form->{jscalendar};
  $jsscript = "";
  if ($form->{jsscript}) {

    # with JavaScript Calendar
    $button1 = qq|
       <td><input name=invdate id=invdate size=11 title="$myconfig{dateformat}" value=$form->{invdate}></td>
       <td><input type=button name=invdate id="trigger1" value=|
      . $locale->text('button') . qq|></td>
       |;
    $button2 = qq|
       <td width="13"><input name=duedate id=duedate size=11 title="$myconfig{dateformat}" value=$form->{duedate}></td>
       <td width="4"><input type=button name=duedate id="trigger2" value=|
      . $locale->text('button') . qq|></td></td>
     |;

    #write Trigger
    $jsscript =
      Form->write_trigger(\%myconfig, "2", "invdate", "BL", "trigger1",
                          "duedate", "BL", "trigger2");
  } else {

    # without JavaScript Calendar
    $button1 =
      qq|<td><input name=invdate size=11 title="$myconfig{dateformat}" value=$form->{invdate}></td>|;
    $button2 =
      qq|<td width="13"><input name=duedate size=11 title="$myconfig{dateformat}" value=$form->{duedate}></td>|;
  }

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{id}>
<input type=hidden name=title value="$form->{title}">
<input type=hidden name=vc value="vendor">
<input type=hidden name=type value=$form->{type}>
<input type=hidden name=level value=$form->{level}>

<input type=hidden name=creditlimit value=$form->{creditlimit}>
<input type=hidden name=creditremaining value=$form->{creditremaining}>

<input type=hidden name=closedto value=$form->{closedto}>
<input type=hidden name=locked value=$form->{locked}>

<input type=hidden name=shipped value=$form->{shipped}>
<input type=hidden name=storno value=$form->{storno}>
<input type=hidden name=storno_id value=$form->{storno_id}>

<table width=100%>
  <tr class=listtop>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        <tr valign=top>
	  <td>
	    <table>
	      <tr>
		<th align=right nowrap>| . $locale->text('Vendor') . qq|</th>
		<td colspan=3>$vendor</td>

                <th align=richt nowrap>|
    . $locale->text('Contact Person') . qq|</th>
                <td colspan=3>$contact</td>

                <input type=hidden name=vendor_id value=$form->{vendor_id}>
		<input type=hidden name=oldvendor value="$form->{oldvendor}">

	      </tr>
	      <tr>
	        <td></td>
		<td colspan=3>
		  <table>
		    <tr>
		      <th nowrap>| . $locale->text('Credit Limit') . qq|</th>
		      <td>$form->{creditlimit}</td>
		      <td width=20%></td>
		      <th nowrap>| . $locale->text('Remaining') . qq|</th>
		      <td class="plus$n">$form->{creditremaining}</td>
		    </tr>
		  </table>
		</td>
	      <tr>
		<th align=right>| . $locale->text('Record in') . qq|</th>
		<td colspan=3><select name=AP>$form->{selectAP}</select></td>
		<input type=hidden name=selectAP value="$form->{selectAP}">
	      </tr>
              $taxzone
              $department
	      <tr>
		<th align=right nowrap>| . $locale->text('Currency') . qq|</th>
		<td><select name=currency>$form->{selectcurrency}</select></td>
		$exchangerate
	      </tr>
	    </table>
	  </td>
	  <td align=right>
	    <table>
	      <tr>
		<th align=right nowrap>| . $locale->text('Invoice Number') . qq|</th>
		<td><input name=invnumber size=11 value="$form->{invnumber}"></td>
	      </tr>
	      <tr>
		<th align=right nowrap>| . $locale->text('Invoice Date') . qq|</th>
                $button1
	      </tr>
	      <tr>
		<th align=right nowrap>| . $locale->text('Due Date') . qq|</th>
                $button2
	      </tr>
	      <tr>
		<th align=right nowrap>| . $locale->text('Order Number') . qq|</th>
		<td><input name=ordnumber size=11 value="$form->{ordnumber}"></td>
<input type=hidden name=quonumber value="$form->{quonumber}">
	      </tr>
	    </table>
	  </td>
	</tr>
      </table>
    </td>
  </tr>

$jsscript

<input type=hidden name=selectcurrency value="$form->{selectcurrency}">
<input type=hidden name=defaultcurrency value=$form->{defaultcurrency}>
<input type=hidden name=fxgain_accno value=$form->{fxgain_accno}>
<input type=hidden name=fxloss_accno value=$form->{fxloss_accno}>
<input type=hidden name=webdav value=$webdav>

<input type=hidden name=taxpart value="$form->{taxpart}">
<input type=hidden name=taxservice value="$form->{taxservice}">

<input type=hidden name=taxaccounts value="$form->{taxaccounts}">
|;

  foreach $item (split / /, $form->{taxaccounts}) {
    print qq|
<input type=hidden name="${item}_rate" value=$form->{"${item}_rate"}>
<input type=hidden name="${item}_description" value="$form->{"${item}_description"}">
|;
  }

  $lxdebug->leave_sub();
}

sub form_footer {
  $lxdebug->enter_sub();

  $form->{invtotal} = $form->{invsubtotal};

  if (($rows = $form->numtextrows($form->{notes}, 25, 8)) < 2) {
    $rows = 2;
  }
  if (($introws = $form->numtextrows($form->{intnotes}, 35, 8)) < 2) {
    $introws = 2;
  }
  $rows = ($rows > $introws) ? $rows : $introws;
  $notes =
    qq|<textarea name=notes rows=$rows cols=25 wrap=soft>$form->{notes}</textarea>|;
  $intnotes =
    qq|<textarea name=intnotes rows=$rows cols=35 wrap=soft>$form->{intnotes}</textarea>|;

  $form->{taxincluded} = ($form->{taxincluded}) ? "checked" : "";

  $taxincluded = "";
  if ($form->{taxaccounts}) {
    $taxincluded = qq|
		<input name=taxincluded class=checkbox type=checkbox value=1 $form->{taxincluded}> <b>|
      . $locale->text('Tax Included') . qq|</b>
|;
  }

  if (!$form->{taxincluded}) {

    foreach $item (split / /, $form->{taxaccounts}) {
      if ($form->{"${item}_base"}) {
        $form->{invtotal} += $form->{"${item}_total"} =
          $form->round_amount(
                             $form->{"${item}_base"} * $form->{"${item}_rate"},
                             2);
        $form->{"${item}_total"} =
          $form->format_amount(\%myconfig, $form->{"${item}_total"}, 2);

        $tax .= qq|
		<tr>
		  <th align=right>$form->{"${item}_description"}</th>
		  <td align=right>$form->{"${item}_total"}</td>
		</tr>
|;
      }
    }

    $form->{invsubtotal} =
      $form->format_amount(\%myconfig, $form->{invsubtotal}, 2, 0);

    $subtotal = qq|
	      <tr>
		<th align=right>| . $locale->text('Subtotal') . qq|</th>
		<td align=right>$form->{invsubtotal}</td>
	      </tr>
|;

  }

  if ($form->{taxincluded}) {
    foreach $item (split / /, $form->{taxaccounts}) {
      if ($form->{"${item}_base"}) {
        $form->{"${item}_total"} =
          $form->round_amount(
                           ($form->{"${item}_base"} * $form->{"${item}_rate"} /
                              (1 + $form->{"${item}_rate"})
                           ),
                           2);
        $form->{"${item}_base"} =
          $form->round_amount($form->{"${item}_base"}, 2);
        $form->{"${item}_netto"} =
          $form->round_amount(
                          ($form->{"${item}_base"} - $form->{"${item}_total"}),
                          2);
        $form->{"${item}_netto"} =
          $form->format_amount(\%myconfig, $form->{"${item}_netto"}, 2);
        $form->{"${item}_total"} =
          $form->format_amount(\%myconfig, $form->{"${item}_total"}, 2);

        $tax .= qq|
	      <tr>
		<th align=right>Enthaltene $form->{"${item}_description"}</th>
		<td align=right>$form->{"${item}_total"}</td>
	      </tr>
	      <tr>
	        <th align=right>Nettobetrag</th>
		<td align=right>$form->{"${item}_netto"}</td>
	      </tr>
|;
      }
    }

  }

  $form->{oldinvtotal} = $form->{invtotal};
  $form->{invtotal}    =
    $form->format_amount(\%myconfig, $form->{invtotal}, 2, 0);

  print qq|
  <tr>
    <td colspan=$colspan>
      <table cellspacing="0">
	<tr valign=bottom>
	  <td>
	    <table>
	      <tr>
		<th align=left>| . $locale->text('Notes') . qq|</th>
		<th align=left>| . $locale->text('Internal Notes') . qq|</th>
	      </tr>
	      <tr valign=top>
		<td>$notes</td>
		<td>$intnotes</td>
	      </tr>
	    </table>
	  </td>
	  <td colspan=2 align=right width=100%>
	    $taxincluded
	    <br>
	    <table width=100%>
	      $subtotal
	      $tax
	      <tr>0
		<th align=right>| . $locale->text('Total') . qq|</th>
		<td align=right>$form->{invtotal}</td>
	      </tr>
	    </table>
	  </td>
	</tr>
      </table>
    </td>
  </tr>
|;
  if ($webdav) {
    $webdav_list = qq|
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
  <tr>
    <th class=listtop align=left>Dokumente im Webdav-Repository</th>
  </tr>
    <table width=100%>
      <td align=left width=30%><b>Dateiname</b></td>
      <td align=left width=70%><b>Webdavlink</b></td>
|;
    foreach $file (keys %{ $form->{WEBDAV} }) {
      $webdav_list .= qq|
      <tr>
        <td align=left>$file</td>
        <td align=left><a href="$form->{WEBDAV}{$file}">$form->{WEBDAV}{$file}</a></td>
      </tr>
|;
    }
    $webdav_list .= qq|
    </table>
  </tr>
|;

    print $webdav_list;
  }
  print qq|
<input type=hidden name=jscalendar value=$form->{jscalendar}>
|;
  print qq|
  <tr>
    <td colspan=$colspan>
      <table width=100%>
        <tr>
	  <th colspan=6 class=listheading>| . $locale->text('Payments') . qq|</th>
	</tr>
|;

  if ($form->{currency} eq $form->{defaultcurrency}) {
    @column_index = qw(datepaid source memo paid AP_paid);
  } else {
    @column_index = qw(datepaid source memo paid exchangerate AP_paid);
  }

  $column_data{datepaid}     = "<th>" . $locale->text('Date') . "</th>";
  $column_data{paid}         = "<th>" . $locale->text('Amount') . "</th>";
  $column_data{exchangerate} = "<th>" . $locale->text('Exch') . "</th>";
  $column_data{AP_paid}      = "<th>" . $locale->text('Account') . "</th>";
  $column_data{source}       = "<th>" . $locale->text('Source') . "</th>";
  $column_data{memo}         = "<th>" . $locale->text('Memo') . "</th>";

  print qq|
	<tr>
|;
  map { print "$column_data{$_}\n" } @column_index;
  print qq|
	</tr>
|;

  $form->{paidaccounts}++ if ($form->{"paid_$form->{paidaccounts}"});
  for $i (1 .. $form->{paidaccounts}) {

    print qq|
	<tr>
|;

    $form->{"selectAP_paid_$i"} = $form->{selectAP_paid};
    $form->{"selectAP_paid_$i"} =~
      s/option>\Q$form->{"AP_paid_$i"}\E/option selected>$form->{"AP_paid_$i"}/;

    # format amounts
    if ($form->{"paid_$i"}) {
      $form->{"paid_$i"} =
        $form->format_amount(\%myconfig, $form->{"paid_$i"}, 2);
    }
    $form->{"exchangerate_$i"} =
      $form->format_amount(\%myconfig, $form->{"exchangerate_$i"});

    $exchangerate = qq|&nbsp;|;
    if ($form->{currency} ne $form->{defaultcurrency}) {
      if ($form->{"forex_$i"}) {
        $exchangerate =
          qq|<input type=hidden name="exchangerate_$i" value=$form->{"exchangerate_$i"}>$form->{"exchangerate_$i"}|;
      } else {
        $exchangerate =
          qq|<input name="exchangerate_$i" size=10 value=$form->{"exchangerate_$i"}>|;
      }
    }
    $exchangerate .= qq|
<input type=hidden name="forex_$i" value=$form->{"forex_$i"}>
|;

    $column_data{"paid_$i"} =
      qq|<td align=center><input name="paid_$i" size=11 value=$form->{"paid_$i"}></td>|;
    $column_data{"exchangerate_$i"} = qq|<td align=center>$exchangerate</td>|;
    $column_data{"AP_paid_$i"}      =
      qq|<td align=center><select name="AP_paid_$i">$form->{"selectAP_paid_$i"}</select></td>|;
    $column_data{"datepaid_$i"} =
      qq|<td align=center><input name="datepaid_$i" size=11 title="$myconfig{dateformat}" value=$form->{"datepaid_$i"}></td>|;
    $column_data{"source_$i"} =
      qq|<td align=center><input name="source_$i" size=11 value=$form->{"source_$i"}></td>|;
    $column_data{"memo_$i"} =
      qq|<td align=center><input name="memo_$i" size=11 value=$form->{"memo_$i"}></td>|;

    map { print qq|$column_data{"${_}_$i"}\n| } @column_index;

    print qq|
	</tr>
|;
  }

  print qq|
	    <input type=hidden name=oldinvtotal value=$form->{oldinvtotal}>
	    <input type=hidden name=paidaccounts value=$form->{paidaccounts}>
      	    <input type=hidden name=selectAP_paid value="$form->{selectAP_paid}">
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>
<br>
|;

  $invdate  = $form->datetonum($form->{invdate},  \%myconfig);
  $closedto = $form->datetonum($form->{closedto}, \%myconfig);

  if ($form->{id}) {
    print qq|<input class=submit type=submit name=action value="|
      . $locale->text('Post Payment') . qq|">
|;
    print qq|<input class=submit type=submit name=action value="|
      . $locale->text('Storno') . qq|">
| unless ($form->{storno});
    if ($form->{radier}) {
    print qq|
    <input class=submit type=submit name=action value="|
      . $locale->text('Delete') . qq|">
|;
  }
  } else {
    if ($invdate > $closedto) {
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

  print qq|

<input type=hidden name=rowcount value=$form->{rowcount}>

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub update {
  $lxdebug->enter_sub();

  map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) }
    qw(exchangerate creditlimit creditremaining);

  &check_name(vendor);

  &check_project;

  $form->{exchangerate} = $exchangerate
    if (
        $form->{forex} = (
                      $exchangerate =
                        $form->check_exchangerate(
                        \%myconfig, $form->{currency}, $form->{invdate}, 'sell'
                        )));

  for $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"}) {
      map {
        $form->{"${_}_$i"} =
          $form->parse_amount(\%myconfig, $form->{"${_}_$i"})
      } qw(paid exchangerate);

      $form->{"exchangerate_$i"} = $exchangerate
        if (
            $form->{"forex_$i"} = (
                $exchangerate =
                  $form->check_exchangerate(
                  \%myconfig, $form->{currency}, $form->{"datepaid_$i"}, 'sell'
                  )));
    }
  }

  $i            = $form->{rowcount};
  $exchangerate = ($form->{exchangerate}) ? $form->{exchangerate} : 1;

  if (   ($form->{"partnumber_$i"} eq "")
      && ($form->{"description_$i"} eq "")
      && ($form->{"partsgroup_$i"} eq "")) {
    $form->{creditremaining} += ($form->{oldinvtotal} - $form->{oldtotalpaid});
    &check_form;

  } else {

    IR->retrieve_item(\%myconfig, \%$form);

    my $rows = scalar @{ $form->{item_list} };

    if ($rows) {
      $form->{"qty_$i"} = 1 unless ($form->{"qty_$i"});

      if ($rows > 1) {

        &select_item;
        exit;

      } else {

        # override sellprice if there is one entered
        $sellprice = $form->parse_amount(\%myconfig, $form->{"sellprice_$i"});

        map { $form->{item_list}[$i]{$_} =~ s/\"/&quot;/g }
          qw(partnumber description unit);

        map { $form->{"${_}_$i"} = $form->{item_list}[0]{$_} }
          keys %{ $form->{item_list}[0] };

        $s = ($sellprice) ? $sellprice : $form->{"sellprice_$i"};

        ($dec) = ($s =~ /\.(\d+)/);
        $dec           = length $dec;
        $decimalplaces = ($dec > 2) ? $dec : 2;

        if ($sellprice) {
          $form->{"sellprice_$i"} = $sellprice;
        } else {

          # if there is an exchange rate adjust sellprice
          $form->{"sellprice_$i"} /= $exchangerate;
        }

        $amount =
          $form->{"sellprice_$i"} * $form->{"qty_$i"} *
          (1 - $form->{"discount_$i"} / 100);
        $form->{creditremaining} -= $amount;
        $form->{"sellprice_$i"} =
          $form->format_amount(\%myconfig, $form->{"sellprice_$i"},
                               $decimalplaces);
        $form->{"qty_$i"} =
          $form->format_amount(\%myconfig, $form->{"qty_$i"}, $dec_qty);
      }

      &display_form;

    } else {

      # ok, so this is a new part
      # ask if it is a part or service item

      if (   $form->{"partsgroup_$i"}
          && ($form->{"partsnumber_$i"} eq "")
          && ($form->{"description_$i"} eq "")) {
        $form->{rowcount}--;
        $form->{"discount_$i"} = "";
        &display_form;
          } else {

        $form->{"id_$i"}   = 0;
        $form->{"unit_$i"} = $locale->text('ea');

        &new_item;

      }
    }
  }
  $lxdebug->leave_sub();
}

sub storno {
  $lxdebug->enter_sub();

  if ($form->{storno}) {
    $form->error($locale->text('Cannot storno storno invoice!'));
  }

  $form->{storno_id} = $form->{id};
  $form->{storno} = 1;
  $form->{id} = "";
  $form->{invnumber} = "Storno zu " . $form->{invnumber};
  $form->{rowcount}--;

  &post();
  $lxdebug->leave_sub();

}

sub post_payment {
  $lxdebug->enter_sub();
  for $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"}) {
      $datepaid = $form->datetonum($form->{"datepaid_$i"}, \%myconfig);

      $form->isblank("datepaid_$i", $locale->text('Payment date missing!'));

      $form->error($locale->text('Cannot post payment for a closed period!'))
        if ($datepaid <= $closedto);

      if ($form->{currency} ne $form->{defaultcurrency}) {
        $form->{"exchangerate_$i"} = $form->{exchangerate}
          if ($invdate == $datepaid);
        $form->isblank("exchangerate_$i",
                       $locale->text('Exchangerate for payment missing!'));
      }
    }
  }

  ($form->{AP})      = split /--/, $form->{AP};
  ($form->{AP_paid}) = split /--/, $form->{AP_paid};
  $form->redirect($locale->text(' Payment posted!'))
      if (IR->post_payment(\%myconfig, \%$form));
    $form->error($locale->text('Cannot post payment!'));


  $lxdebug->leave_sub();
}

sub post {
  $lxdebug->enter_sub();

  $form->isblank("invdate", $locale->text('Invoice Date missing!'));
  $form->isblank("vendor",  $locale->text('Vendor missing!'));

  # if the vendor changed get new values
  if (&check_name(vendor)) {
    &update;
    exit;
  }

  &validate_items;

  $closedto = $form->datetonum($form->{closedto}, \%myconfig);
  $invdate  = $form->datetonum($form->{invdate},  \%myconfig);

  $form->error($locale->text('Cannot post invoice for a closed period!'))
    if ($invdate <= $closedto);

  $form->isblank("exchangerate", $locale->text('Exchangerate missing!'))
    if ($form->{currency} ne $form->{defaultcurrency});

  for $i (1 .. $form->{paidaccounts}) {
    if ($form->parse_amount(\%myconfig, $form->{"paid_$i"})) {
      $datepaid = $form->datetonum($form->{"datepaid_$i"}, \%myconfig);

      $form->isblank("datepaid_$i", $locale->text('Payment date missing!'));

      $form->error($locale->text('Cannot post payment for a closed period!'))
        if ($datepaid <= $closedto);

      if ($form->{currency} ne $form->{defaultcurrency}) {
        $form->{"exchangerate_$i"} = $form->{exchangerate}
          if ($invdate == $datepaid);
        $form->isblank("exchangerate_$i",
                       $locale->text('Exchangerate for payment missing!'));
      }
    }
  }

  ($form->{AP})      = split /--/, $form->{AP};
  ($form->{AP_paid}) = split /--/, $form->{AP_paid};

  $form->{id} = 0 if $form->{postasnew};


  relink_accounts();
  $form->redirect(  $locale->text('Invoice')
                  . " $form->{invnumber} "
                  . $locale->text('posted!'))
    if (IR->post_invoice(\%myconfig, \%$form));
  $form->error($locale->text('Cannot post invoice!'));

  $lxdebug->leave_sub();
}

sub delete {
  $lxdebug->enter_sub();

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>
|;

  # delete action variable
  map { delete $form->{$_} } qw(action header);

  foreach $key (keys %$form) {
    $form->{$key} =~ s/\"/&quot;/g;
    print qq|<input type=hidden name=$key value="$form->{$key}">\n|;
  }

  print qq|
<h2 class=confirm>| . $locale->text('Confirm!') . qq|</h2>

<h4>|
    . $locale->text('Are you sure you want to delete Invoice Number')
    . qq| $form->{invnumber}</h4>
<p>
<input name=action class=submit type=submit value="|
    . $locale->text('Yes') . qq|">
</form>
|;

  $lxdebug->leave_sub();
}

sub yes {
  $lxdebug->enter_sub();

  $form->redirect($locale->text('Invoice deleted!'))
    if (IR->delete_invoice(\%myconfig, \%$form));
  $form->error($locale->text('Cannot delete invoice!'));

  $lxdebug->leave_sub();
}
