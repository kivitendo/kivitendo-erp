#=====================================================================
# LX-Office ERP
# Copyright (C) 2006
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
# Dunning process module
#
#======================================================================

use SL::IS;
use SL::PE;
use SL::DN;
use Data::Dumper;

require "$form->{path}/io.pl";
require "$form->{path}/arap.pl";

1;

sub edit_config {
  $lxdebug->enter_sub();

  # edit all dunning config data

  $form->header;
  DN->get_config(\%myconfig, \%$form);
  $form->{title} = $locale->text('Edit Dunning Process Config');
  
  $form->{callback} =
    "$form->{script}?action=edit_config&path=$form->{path}&login=$form->{login}&password=$form->{password}"
    unless $form->{callback};

  @column_index = qw(dunning_level dunning_description active auto email payment_terms terms fee interest template);

  $column_header{dunning_level} =
      qq|<th class=listheading>|
    . $locale->text('Dunning Level')
    . qq|</th>|;
  $column_header{dunning_description} =
      qq|<th class=listheading>|
    . $locale->text('Dunning Description')
    . qq|</th>|;
  $column_header{active} =
      qq|<th class=listheading>|
    . $locale->text('Active?')
    . qq|</th>|;
  $column_header{auto} =
      qq|<th class=listheading>|
    . $locale->text('Auto Send?')
    . qq|</th>|;
  $column_header{email} =
      qq|<th class=listheading>|
    . $locale->text('eMail Send?')
    . qq|</th>|;
  $column_header{payment_terms} =
      qq|<th class=listheading>|
    . $locale->text('Fristsetzung')
    . qq|</th>|;
  $column_header{terms} =
      qq|<th class=listheading>|
    . $locale->text('Duedate +Days')
    . qq|</th>|;
  $column_header{fee} =
      qq|<th class=listheading>|
    . $locale->text('Fee')
    . qq|</th>|;
  $column_header{interest} =
      qq|<th class=listheading>|
    . $locale->text('Interest Rate')
    . qq|</th>|;
  $column_header{template} =
      qq|<th class=listheading>|
    . $locale->text('Template')
    . qq|</th>|;
  print qq|
<body>
<script type="text/javascript" src="js/common.js"></script>
<script type="text/javascript" src="js/dunning.js"></script>
<form method=post action=$form->{script}>


<table width=100%>
  <tr>
    <th class=listtop colspan=9>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>|;
  map { print "$column_header{$_}\n" } @column_index;

  print qq|
        </tr>
|;
  my $i = 0;
  foreach $ref (@{ $form->{DUNNING} }) {

    $i++;
    my $j = $i % 2;

    print qq|
        <tr valign=top class=listrow$j>
|;


    $column_data{dunning_level} =
      qq|<td><input type=hidden name=dunning_level_$i size=2 value="$i"><input type=hidden name=id_$i value="$ref->{id}">$i</td>|;
    $column_data{dunning_description}           = qq|<td><input name=dunning_description_$i value="$ref->{dunning_description}"></td>|;
    my $active = ($ref->{active}) ? "checked" : "";
    $column_data{active} =
      qq|<td><input type=checkbox name=active_$i value=1 $active></td>|;
    my $email = ($ref->{email}) ? "checked" : "";
  $column_data{email} =
    qq|<td><input type=checkbox name=email_$i value=1 $email><button type="button" onclick="set_email_window('email_subject_$i', 'email_body_$i', 'email_attachment_$i')">| . $locale->text('L') . qq|</button><input type=hidden name=email_body_$i value="$ref->{email_body}"><input type=hidden name=email_subject_$i value="$ref->{email_subject}"><input type=hidden name=email_attachment_$i value="$ref->{email_attachment}"></td>|;

    my $auto = ($ref->{auto}) ? "checked" : "";
    $column_data{auto} =
      qq|<td><input type=checkbox name=auto_$i value=1 $auto></td>|;
    $column_data{payment_terms}           = qq|<td><input name=payment_terms_$i size=3 value="$ref->{payment_terms}"></td>|;
    $column_data{terms}           = qq|<td><input name=terms_$i size=3 value="$ref->{terms}"></td>|;
    $column_data{fee}           = qq|<td><input name=fee_$i size=5 value="$ref->{fee}"></td>|;
    $column_data{interest}           = qq|<td><input name=interest_$i size=4 value="$ref->{interest}">%</td>|;
    $column_data{template}           = qq|<td><input name=template_$i value="$ref->{template}"></td>|;



    map { print "$column_data{$_}\n" } @column_index;

    print qq|
	</tr>
|;
  }
  $i++;
  my $j = $i % 2;

  print qq|
        <tr valign=top class=listrow$j>
|;


  $column_data{dunning_level} =
    qq|<td><input type=hidden size=2 name=dunning_level_$i value=$i>$i</td>|;
  $column_data{dunning_description}           = qq|<td><input name=dunning_description_$i ></td>|;
  my $active = "";
  $column_data{active} =
    qq|<td><input type=checkbox name=active_$i value=1 $active></td>|;
  my $email = "";
  $column_data{email} =
    qq|<td><input type=checkbox name=email_$i value=1 $email><button type="button" onclick="set_email_window('email_subject_$i', 'email_body_$i', 'email_attachment_$i')">| . $locale->text('L') . qq|</button><input type=hidden name=email_body_$i><input type=hidden name=email_subject_$i><input type=hidden name=email_attachment_$i></td>|;
  my $auto = "";
  $column_data{auto} =
    qq|<td><input type=checkbox name=auto_$i value=1 $auto></td>|;
  $column_data{payment_terms}           = qq|<td><input  size=3 name=payment_terms_$i></td>|;
  $column_data{terms}           = qq|<td><input  size=3 name=terms_$i></td>|;
  $column_data{fee}           = qq|<td><input  size=5 name=fee_$i></td>|;
  $column_data{interest}           = qq|<td><input  size=4 name=interest_$i>%</td>|;
  $column_data{template}           = qq|<td><input name=template_$i></td>|;


  $form->{rowcount} = $i;
  map { print "$column_data{$_}\n" } @column_index;

  print qq|
      </tr>
|;


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
<input name=rowcount type=hidden value="$form->{rowcount}">

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<input class=submit type=submit name=action value="|
    . $locale->text('Save') . qq|">

  </form>

  </body>
  </html>
|;

  $lxdebug->leave_sub();
}

sub add {
  $lxdebug->enter_sub();
  # setup customer selection
  $form->all_vc(\%myconfig, "customer", "AR");

  DN->get_config(\%myconfig, \%$form);

  if (@{ $form->{all_customer} }) {
    map { $customer .= "<option>$_->{name}--$_->{id}\n" }
      @{ $form->{all_customer} };
    $customer = qq|<select name=customer><option>\n$customer</select>|;
  } else {
    $customer = qq|<input name=customer size=35>|;
  }

  # dunning levels
  if (@{ $form->{DUNNING} }) {
    $form->{selectdunning_level} = "<option></option\n";
    map {
      $form->{selectdunning_level} .=
        "<option value=$_->{id}>$_->{dunning_description}</option>\n"
    } (@{ $form->{DUNNING} });
  }
  $dunning_level = qq| 
    <tr> 
    <th align=right nowrap>| . $locale->text('Next Dunning Level') . qq|</th>
    <td colspan=3><select name=dunning_level>$form->{selectdunning_level}</select></td>
    </tr>
    | if $form->{selectdunning_level};

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
  $form->{title}   = $locale->text('Start Dunning Process');
  $form->{nextsub} = "show_invoices";

  # use JavaScript Calendar or not
  $form->{jsscript} = $jscalendar;
  $jsscript = "";
  if ($form->{jsscript}) {

    # with JavaScript Calendar
    $button1 = qq|
      <td><input name=paymentuntil id=paymentuntil size=11 title="$myconfig{dateformat}">
      <input type=button name=paymentuntil id="trigger1" value=|
      . $locale->text('button') . qq|></td>
      |;

    #write Trigger
    $jsscript =
      Form->write_trigger(\%myconfig, "1", "paymentuntil", "BR", "trigger1");
  } else {

    # without JavaScript Calendar
    $button1 =
      qq|<td><input name=paymentuntil id=paymentuntil size=11 title="$myconfig{dateformat}"></td>|;
  }
  $form->{fokus} = "search.customer";
  $form->header;
  print qq|
<body onLoad="fokus()">

<form method=post name="search" action=$form->{script}>

<table width=100%>
  <tr><th class=listtop>$form->{title}</th></tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
        <tr>
          <th align=right>| . $locale->text('Customer') . qq|</th>
          <td colspan=3>$customer</td>
        </tr>
        $dunning_level
        $department
        <tr>
          <th align=right nowrap>| . $locale->text('Invoice Number') . qq|</th>
          <td colspan=3><input name=invnumber size=20></td>
        </tr>
        <tr>
          <th align=right nowrap>| . $locale->text('Order Number') . qq|</th>
          <td colspan=3><input name=ordnumber size=20></td>
        </tr>
        <tr>
          <th align=right nowrap>| . $locale->text('Notes') . qq|</th>
          <td colspan=3><input name=notes size=40></td>
        </tr>
        <tr>
          <th align=right nowrap>| . $locale->text('Payment until') . qq|</th>
          $button1
        </tr>
        <input type=hidden name=sort value=transdate>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
  <tr>
    <td>
      <table>
        <tr>
          <th align=right nowrap>| . $locale->text('Minimum Amount') . qq|</th>
          <td><input name=minamount size=6></td>
        </tr>
        <tr>
          <th align=right nowrap>| . $locale->text('Group Invoices') . qq|</th>
          <td><input type=checkbox value=1 name=groupinvoices checked></td>
        </tr>
      </table>
    </td>
  </tr>
</table>

<input type=hidden name=nextsub value=$form->{nextsub}>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<br>
<input class=submit type=submit name=action value="|
    . $locale->text('Continue') . qq|">

</form>

</body>

$jsscript

</html>
|;

  $lxdebug->leave_sub();

}

sub show_invoices {
  $lxdebug->enter_sub();

  DN->get_invoices(\%myconfig, \%$form);
  $form->{title} = $locale->text('Start Dunning Process');

  if (@{ $form->{DUNNING_CONFIG} }) {
    foreach $item (@{ $form->{DUNNING_CONFIG} }) {
        $form->{selectdunning} .=
          "<option value=$item->{id}>$item->{dunning_description}</option>";
    }
  }


  $form->{nextsub} = "save_dunning";
  
  $form->{callback} =
    "$form->{script}?action=show_invoices&path=$form->{path}&login=$form->{login}&password=$form->{password}&customer=$form->{customer}&invnumber=$form->{invnumber}&ordnumber=$form->{ordnumber}&paymentuntil=$form->{paymentuntil}&groupinvoices=$form->{groupinvoices}&minamount=$form->{minamount}&dunning_level=$form->{dunning_level}&notes=$form->{notes}"
    unless $form->{callback};

  @column_index = qw(dunning_description active email customername invnumber invdate inv_duedate invamount next_duedate fee interest );

  $column_header{dunning_description} =
      qq|<th class=listheading>|
    . $locale->text('Current / Next Level')
    . qq|</th>|;
  $column_header{active} =
      qq|<th class=listheading>|
    . $locale->text('Active?')
    . qq|</th>|;
  $column_header{email} =
      qq|<th class=listheading>|
    . $locale->text('eMail?')
    . qq|</th>|;
  $column_header{customername} =
      qq|<th class=listheading>|
    . $locale->text('Customername')
    . qq|</th>|;
  $column_header{invnumber} =
      qq|<th class=listheading>|
    . $locale->text('Invno.')
    . qq|</th>|;
  $column_header{inv_duedate} =
      qq|<th class=listheading>|
    . $locale->text('Inv. Duedate')
    . qq|</th>|;
  $column_header{next_duedate} =
      qq|<th class=listheading>|
    . $locale->text('Dunning Duedate')
    . qq|</th>|;
  $column_header{invdate} =
      qq|<th class=listheading>|
    . $locale->text('Invdate')
    . qq|</th>|;
  $column_header{invamount} =
      qq|<th class=listheading>|
    . $locale->text('Amount')
    . qq|</th>|;
  $column_header{fee} =
      qq|<th class=listheading>|
    . $locale->text('Total Fees')
    . qq|</th>|;
  $column_header{interest} =
      qq|<th class=listheading>|
    . $locale->text('Total Interest')
    . qq|</th>|;

  $form->header;


  print qq|
<body>
<script type="text/javascript" src="js/common.js"></script>
<script type="text/javascript" src="js/dunning.js"></script>
<form name=Form method=post action=$form->{script}>


<table width=100%>
  <tr>
    <th class=listtop colspan=9>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>|;
  map { print "$column_header{$_}\n" } @column_index;

  print qq|
        </tr>
|;
  my $i = 0;
  foreach $ref (@{ $form->{DUNNINGS} }) {

    $i++;
    my $j = $i % 2;

    print qq|
        <tr valign=top class=listrow$j>
|;

  $form->{selectdunning} =~ s/ selected//g;
  if ($ref->{next_dunning_id} ne "") {
     $form->{selectdunning} =~ s/value=$ref->{next_dunning_id}/value=$ref->{next_dunning_id} selected/;
  }
  

  $dunning = qq|<select name=next_dunning_id_$i>$form->{selectdunning}</select>|;


    $column_data{dunning_description}           = qq|<td><input type=hidden name=inv_id_$i size=2 value="$ref->{id}"><input type=hidden name=customer_id_$i size=2 value="$ref->{customer_id}">$ref->{dunning_level}:&nbsp;$dunning</td>|;
    my $active = "checked";
    $column_data{active} =
      qq|<td><input type=checkbox name=active_$i value=1 $active></td>|;
    my $email = "checked";
  $column_data{email} =
    qq|<td><input type=checkbox name=email_$i value=1 $email></td>|;
    $column_data{next_duedate}           = qq|<td><input type=hidden name=next_duedate_$i size=6 value="$ref->{next_duedate}">$ref->{next_duedate}</td>|;

    $column_data{inv_duedate}           = qq|<td><input type=hidden name=inv_duedate_$i size=6 value="$ref->{duedate}">$ref->{duedate}</td>|;
    $column_data{invdate}           = qq|<td><input type=hidden name=invdate_$i size=6 value="$ref->{transdate}">$ref->{transdate}</td>|;
    $column_data{invnumber}           = qq|<td><input type=hidden name=invnumber_$i size=6 value="$ref->{invnumber}">$ref->{invnumber}</td>|;
    $column_data{customername}           = qq|<td><input type=hidden name=customername_$i size=6 value="$ref->{customername}">$ref->{customername}</td>|;
    $column_data{invamount}           = qq|<td><input type=hidden name=invamount_$i size=6 value="$ref->{amount}">$ref->{amount}</td>|;
    $column_data{fee}           = qq|<td><input type=hidden name=fee_$i size=5 value="$ref->{fee}">$ref->{fee}</td>|;
    $column_data{interest}           = qq|<td><input type=hidden name=interest_$i size=4 value="$ref->{interest}">$ref->{interest}</td>|;



    map { print "$column_data{$_}\n" } @column_index;

    print qq|
	</tr>
|;
  }

  $form->{rowcount} = $i;

  print qq|
      </table>
    </td>
  </tr>
  <tr>
  <td><hr size=3 noshade></td>
  </tr>
</table>|;
  &print_options;
  print qq|
<br>
<form method=post action=$form->{script}>

<input name=callback type=hidden value="$form->{callback}">
<input name=rowcount type=hidden value="$form->{rowcount}">
<input name=nextsub type=hidden value="$form->{nextsub}">
<input name=groupinvoices type=hidden value="$form->{groupinvoices}">


<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>
<input type="hidden" name="action">
<input type="submit" name="dummy" value="|
    . $locale->text('Continue') . qq|" onclick="this.disabled=true; this.value='| . $locale->text("The dunning process started") . qq|'; document.Form.action.value='| . $locale->text('Continue') . qq|'; document.Form.submit()">

  </form>

  </body>
  </html>
|;


  $lxdebug->leave_sub();

}

sub save {
  $lxdebug->enter_sub();

  for my $i (1 .. $form->{rowcount}) {
    if ($form->{"dunning_description_$i"} ne "") {
      $form->isblank("dunning_level_$i", $locale->text('Dunning Level missing in row '). $i);
      $form->isblank("dunning_description_$i", $locale->text('Dunning Description missing in row '). $i);
      $form->isblank("terms_$i", $locale->text('Terms missing in row '). $i);
      $form->isblank("payment_terms_$i", $locale->text('Payment Terms missing in row '). $i);
    }
  }

  DN->save_config(\%myconfig, \%$form);
  $form->redirect($locale->text('Dunning Process Config saved!'));

  $lxdebug->leave_sub();
}

sub save_dunning {
  $lxdebug->enter_sub();

  my $active=1;
  my @rows = ();
  undef($form->{DUNNING_PDFS});
  if ($form->{groupinvoices}) {
    while ($active) {
      $lastcustomer = 0;
      $form->{inv_ids} = "";
      $active = 0;
      @rows = ();
      for my $i (1 .. $form->{rowcount}) {
        $form->{"active_$i"} *= 1;
        $lastcustomer = $form->{"customer_id_$i"} unless ($lastcustomer);
        if ($form->{"active_$i"} && ($form->{"customer_id_$i"} == $lastcustomer)) {
          if ($form->{inv_ids}) {
            $form->{inv_ids} .= qq|,$form->{"inv_id_$i"}|;
          } else {
            $form->{inv_ids} = qq|($form->{"inv_id_$i"}|;
          }
          $form->{"active_$i"} = 0;
          $form->{"customer_id_$i"} = 0;
          push(@rows, $i);
        } elsif ($form->{"active_$i"}) {
          $active = 1;
        } else {
          $form->{"customer_id_$i"} = 0;
        }
      }
      if ($form->{inv_ids} ne "") {
        $form->{inv_ids} .= ")";
        DN->save_dunning(\%myconfig, \%$form, \@rows, $userspath,$spool, $sendmail);
      }
    }
  } else {
    for my $i (1 .. $form->{rowcount}) {
      if ($form->{"active_$i"}) {
        @rows = ();
        $form->{inv_ids} = qq|($form->{"inv_id_$i"})|;
        push(@rows, $i);
        DN->save_dunning(\%myconfig, \%$form, \@rows, $userspath,$spool, $sendmail);
      }
    }
  }
  if($form->{DUNNING_PDFS}) {
    DN->melt_pdfs(\%myconfig, \%$form,$spool);
  }

  $form->redirect($locale->text('Dunning Process started for selected invoices!'));

  $lxdebug->leave_sub();
}
  
sub set_email {
  $lxdebug->enter_sub();


  my $callback = "$form->{script}?action=set_email&";
  map({ $callback .= "$_=" . $form->escape($form->{$_}) . "&" }
      (qw(login path password name input_subject input_body input_attachment email_subject email_body email_attachment), grep({ /^[fl]_/ } keys %$form)));

  if ($form->{email_attachment}) {
    $form->{email_attachment} = "checked";
  }
  $form->{"title"} = $locale->text("Set eMail text");
  $form->header();
  print($form->parse_html_template("dunning/set_email"));

  $lxdebug->leave_sub();
}

sub search {
  $lxdebug->enter_sub();
  # setup customer selection
  $form->all_vc(\%myconfig, "customer", "AR");

  DN->get_config(\%myconfig, \%$form);

  if (@{ $form->{all_customer} }) {
    map { $customer .= "<option>$_->{name}--$_->{id}\n" }
      @{ $form->{all_customer} };
    $customer = qq|<select name=customer><option>\n$customer</select>|;
  } else {
    $customer = qq|<input name=customer size=35>|;
  }

  # dunning levels
  if (@{ $form->{DUNNING} }) {
    $form->{selectdunning_level} = "<option></option\n";
    map {
      $form->{selectdunning_level} .=
        "<option value=$_->{id}>$_->{dunning_description}</option>\n"
    } (@{ $form->{DUNNING} });
  }
  $dunning_level = qq| 
    <tr> 
    <th align=right nowrap>| . $locale->text('Next Dunning Level') . qq|</th>
    <td colspan=3><select name=dunning_level>$form->{selectdunning_level}</select></td>
    </tr>
    | if $form->{selectdunning_level};

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
  $form->{title}   = $locale->text('Search Dunning');
  $form->{nextsub} = "show_dunning";

  # use JavaScript Calendar or not
  $form->{jsscript} = $jscalendar;
  $jsscript = "";
  if ($form->{jsscript}) {

    # with JavaScript Calendar
    $button1 = qq|
      <td><input name=transdatefrom id=transdatefrom size=11 title="$myconfig{dateformat}">
      <input type=button name=transdatefrom id="trigger1" value=|
      . $locale->text('button') . qq|></td>
      |;
    $button2 = qq|
      <td><input name=transdateto id=transdateto size=11 title="$myconfig{dateformat}">
      <input type=button name=transdateto id="trigger2" value=|
      . $locale->text('button') . qq|></td>
      |;
    $button3 = qq|
      <td><input name=dunningfrom id=dunningfrom size=11 title="$myconfig{dateformat}">
      <input type=button name=dunningfrom id="trigger3" value=|
      . $locale->text('button') . qq|></td>
      |;
    $button4 = qq|
      <td><input name=dunningto id=dunningto size=11 title="$myconfig{dateformat}">
      <input type=button name=dunningto id="trigger4" value=|
      . $locale->text('button') . qq|></td>
      |;

    #write Trigger
    $jsscript =
      Form->write_trigger(\%myconfig, "4", "transdatefrom", "BR", "trigger1", "transdateto", "BR", "trigger2", "dunningfrom", "BR", "trigger3", "dunningto", "BR", "trigger4");
  } else {

    # without JavaScript Calendar
    $button1 =
      qq|<td><input name=transdatefrom id=transdatefrom size=11 title="$myconfig{dateformat}"></td>|;
    $button2 =
      qq|<td><input name=transdateto id=transdateto size=11 title="$myconfig{dateformat}"></td>|;
    $button1 =
      qq|<td><input name=dunningfrom id=dunningfrom size=11 title="$myconfig{dateformat}"></td>|;
    $button1 =
      qq|<td><input name=dunningfrom id=dunningto size=11 title="$myconfig{dateformat}"></td>|;
  }

  $form->{fokus} = "search.customer";
  $form->header;
  print qq|
<body onLoad="fokus()">

<form method=post name="search" action=$form->{script}>

<table width=100%>
  <tr><th class=listtop>$form->{title}</th></tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
        <tr>
          <th align=right>| . $locale->text('Customer') . qq|</th>
          <td colspan=3>$customer</td>
        </tr>
        $dunning_level
        $department
        <tr>
          <th align=right nowrap>| . $locale->text('Invoice Number') . qq|</th>
          <td colspan=3><input name=invnumber size=20></td>
        </tr>
        <tr>
          <th align=right nowrap>| . $locale->text('Order Number') . qq|</th>
          <td colspan=3><input name=ordnumber size=20></td>
        </tr>
        <tr>
          <th align=right nowrap>| . $locale->text('Notes') . qq|</th>
          <td colspan=3><input name=notes size=40></td>
        </tr>
        <tr>
          <th align=right nowrap>| . $locale->text('Invdate from') . qq|</th>
          $button1
          <th align=right nowrap>| . $locale->text('To') . qq|</th>
          $button2
        </tr>
        <tr>
          <th align=right nowrap>| . $locale->text('Dunning Date from') . qq|</th>
          $button3
          <th align=right nowrap>| . $locale->text('To') . qq|</th>
          $button4
        </tr>

        <input type=hidden name=sort value=transdate>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
  <tr>
    <td>
      <table>
        <tr>
          <th align=right nowrap>| . $locale->text('Show old dunnings') . qq|</th>
          <td><input type=checkbox value=1 name=showold></td>
        </tr>
      </table>
    </td>
  </tr>
</table>

<input type=hidden name=nextsub value=$form->{nextsub}>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<br>
<input class=submit type=submit name=action value="|
    . $locale->text('Continue') . qq|">

</form>

</body>

$jsscript

</html>
|;

  $lxdebug->leave_sub();

}

sub show_dunning {
  $lxdebug->enter_sub();

  DN->get_dunning(\%myconfig, \%$form);
  $form->{title} = $locale->text('Dunning overview');




  
  $form->{callback} =
    "$form->{script}?action=show_dunning&path=$form->{path}&login=$form->{login}&password=$form->{password}&customer=$form->{customer}&invnumber=$form->{invnumber}&ordnumber=$form->{ordnumber}&transdatefrom=$form->{transdatefrom}&transdateto=$form->{transdateto}&dunningfrom=$form->{dunningfrom}&dunningto=$form->{dunningto}&notes=$form->{notes}&showold=$form->{showold}&dunning_level=$form->{dunning_level}"
    unless $form->{callback};

  @column_index = qw(dunning_description customername invnumber invdate inv_duedate invamount dunning_date next_duedate fee interest );

  $column_header{dunning_description} =
      qq|<th class=listheading>|
    . $locale->text('Dunning Level')
    . qq|</th>|;
  $column_header{customername} =
      qq|<th class=listheading>|
    . $locale->text('Customername')
    . qq|</th>|;
  $column_header{invnumber} =
      qq|<th class=listheading>|
    . $locale->text('Invnumber')
    . qq|</th>|;
  $column_header{inv_duedate} =
      qq|<th class=listheading>|
    . $locale->text('Invoice Duedate')
    . qq|</th>|;
  $column_header{dunning_date} =
      qq|<th class=listheading>|
    . $locale->text('Dunning Date')
    . qq|</th>|;
  $column_header{next_duedate} =
      qq|<th class=listheading>|
    . $locale->text('Dunning Duedate')
    . qq|</th>|;
  $column_header{invdate} =
      qq|<th class=listheading>|
    . $locale->text('Invdate')
    . qq|</th>|;
  $column_header{invamount} =
      qq|<th class=listheading>|
    . $locale->text('Amount')
    . qq|</th>|;
  $column_header{fee} =
      qq|<th class=listheading>|
    . $locale->text('Total Fees')
    . qq|</th>|;
  $column_header{interest} =
      qq|<th class=listheading>|
    . $locale->text('Total Interest')
    . qq|</th>|;

  $form->header;


  print qq|
<body>
<script type="text/javascript" src="js/common.js"></script>
<script type="text/javascript" src="js/dunning.js"></script>
<form method=post action=$form->{script}>


<table width=100%>
  <tr>
    <th class=listtop colspan=9>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>|;
  map { print "$column_header{$_}\n" } @column_index;

  print qq|
        </tr>
|;
  my $i = 0;
  foreach $ref (@{ $form->{DUNNINGS} }) {

    $i++;
    my $j = $i % 2;

    print qq|
        <tr valign=top class=listrow$j>
|;

  

  $dunning = qq|<select name=next_dunning_id_$i>$form->{selectdunning}</select>|;
    my $script = "";
    if ($ref->{invoice}) {
      $script = "is.pl";
    } else {
      $script = "ar.pl";
    }
    $column_data{dunning_description}           = qq|<td><a href=dn.pl?action=print_dunning&dunning_id=$ref->{dunning_id}&format=pdf&media=screen&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$form->{callback}>$ref->{dunning_description}</a></td>|;
    my $active = "checked";
    $column_data{dunning_date}           = qq|<td>$ref->{dunning_date}</td>|;
    $column_data{next_duedate}           = qq|<td>$ref->{dunning_duedate}</td>|;

    $column_data{inv_duedate}           = qq|<td>$ref->{duedate}</td>|;
    $column_data{invdate}           = qq|<td>$ref->{transdate}</td>|;
    $column_data{invnumber}           = qq|<td><a href=$script?action=edit&id=$ref->{id}&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$form->{callback}>$ref->{invnumber}</a></td>|;
    $column_data{customername}           = qq|<td>$ref->{customername}</td>|;
    $column_data{invamount}           = qq|<td>$ref->{amount}</td>|;
    $column_data{fee}           = qq|<td>$ref->{fee}</td>|;
    $column_data{interest}           = qq|<td>$ref->{interest}</td>|;



    map { print "$column_data{$_}\n" } @column_index;

    print qq|
	</tr>
|;
  }

  $form->{rowcount} = $i;

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
<input name=rowcount type=hidden value="$form->{rowcount}">
<input name=nextsub type=hidden value="$form->{nextsub}">


<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

  </form>

  </body>
  </html>
|;


  $lxdebug->leave_sub();

}

sub print_dunning {
  $lxdebug->enter_sub();

  DN->print_dunning(\%myconfig, \%$form, $form->{dunning_id}, $userspath,$spool, $sendmail);

  if($form->{DUNNING_PDFS}) {
    DN->melt_pdfs(\%myconfig, \%$form,$spool);
  } else {
    $form->redirect($locale->text('Could not create dunning copy!'));
  }

  $lxdebug->leave_sub();

}

# end of main

