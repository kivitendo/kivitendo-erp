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

require "bin/mozilla/common.pl";
require "bin/mozilla/io.pl";
require "bin/mozilla/arap.pl";

1;

sub edit_config {
  $lxdebug->enter_sub();

  DN->get_config(\%myconfig, \%$form);

  $form->{title}          = $locale->text('Edit Dunning Process Config');
  $form->{callback}     ||= build_std_url("action=edit_config");
  $form->{rowcount}       = 1 + scalar @{ $form->{DUNNING} };
  $form->{rowcount_odd}   = $form->{rowcount} % 2;

  $form->header();
  print $form->parse_html_template("dunning/edit_config");

  $lxdebug->leave_sub();
}

sub add {
  $lxdebug->enter_sub();

  # setup customer selection
  $form->all_vc(\%myconfig, "customer", "AR");

  DN->get_config(\%myconfig, \%$form);

  $form->{SHOW_CUSTOMER_SELECTION}      = $form->{all_customer}    && scalar @{ $form->{all_customer} };
  $form->{SHOW_DUNNING_LEVEL_SELECTION} = $form->{DUNNING}         && scalar @{ $form->{DUNNING} };
  $form->{SHOW_DEPARTMENT_SELECTION}    = $form->{all_departments} && scalar @{ $form->{all_departments} };

  $form->{title}    = $locale->text('Start Dunning Process');
  $form->{jsscript} = 1;
  $form->{fokus}    = "search.customer";
  $form->header();

  print $form->parse_html_template("dunning/add");

  $lxdebug->leave_sub();
}

sub show_invoices {
  $lxdebug->enter_sub();

  DN->get_invoices(\%myconfig, \%$form);
  $form->{title} = $locale->text('Start Dunning Process');

  foreach my $row (@{ $form->{DUNNINGS} }) {
    $row->{DUNNING_CONFIG} = [ map +{ %{ $_ } }, @{ $form->{DUNNING_CONFIG} } ];

    if ($row->{next_dunning_config_id}) {
      map { $_->{SELECTED} = $_->{id} == $row->{next_dunning_config_id} } @{ $row->{DUNNING_CONFIG } };
    }
    map { $row->{$_} = $form->format_amount(\%myconfig, $row->{$_} * 1, -2) } qw(amount fee interest);
  }

  $form->{rowcount}       = scalar @{ $form->{DUNNINGS} };
  $form->{jsscript}       = 1;
  $form->{callback}     ||= build_std_url("action=show_invoices", qw(login password customer invnumber ordnumber groupinvoices minamount dunning_level notes));

  $form->{PRINT_OPTIONS}  = print_options(1);

  $form->header();
  print $form->parse_html_template("dunning/show_invoices");

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
  # saving the history
  if(!exists $form->{addition} && $form->{id} ne "") {
  	$form->{snumbers} = qq|dunning_id_| . $form->{"dunning_id"};
    $form->{addition} = "SAVED FOR DUNNING";
  	$form->save_history($form->dbconnect(\%myconfig));
  }
  # /saving the history 
  $form->redirect($locale->text('Dunning Process Config saved!'));

  $lxdebug->leave_sub();
}

sub save_dunning {
  $lxdebug->enter_sub();

  my $active=1;
  my @rows = ();
  undef($form->{DUNNING_PDFS});

  if ($form->{groupinvoices}) {
    my %dunnings_for;

    for my $i (1 .. $form->{rowcount}) {
      next unless ($form->{"active_$i"});

      $dunnings_for{$form->{"customer_id_$i"}} ||= {};
      my $dunning_levels = $dunnings_for{$form->{"customer_id_$i"}};

      $dunning_levels->{$form->{"next_dunning_config_id_$i"}} ||= [];
      my $level = $dunning_levels->{$form->{"next_dunning_config_id_$i"}};

      push @{ $level }, { "row"                    => $i,
                          "invoice_id"             => $form->{"inv_id_$i"},
                          "customer_id"            => $form->{"customer_id_$i"},
                          "next_dunning_config_id" => $form->{"next_dunning_config_id_$i"},
                          "email"                  => $form->{"email_$i"}, };
    }

    foreach my $levels (values %dunnings_for) {
      foreach my $level (values %{ $levels }) {
        next unless scalar @{ $level };

        DN->save_dunning(\%myconfig, \%$form, $level, $userspath, $spool, $sendmail);
      }
    }

  } else {
    for my $i (1 .. $form->{rowcount}) {
      next unless $form->{"active_$i"};

      my $level = [ { "row"                    => $i,
                      "invoice_id"             => $form->{"inv_id_$i"},
                      "customer_id"            => $form->{"customer_id_$i"},
                      "next_dunning_config_id" => $form->{"next_dunning_config_id_$i"},
                      "email"                  => $form->{"email_$i"}, } ];
      DN->save_dunning(\%myconfig, \%$form, $level, $userspath, $spool, $sendmail);
    }
  }

  if($form->{DUNNING_PDFS}) {
    DN->melt_pdfs(\%myconfig, \%$form,$spool);
  }

  # saving the history
  if(!exists $form->{addition} && $form->{id} ne "") {
  	$form->{snumbers} = qq|dunning_id_| . $form->{"dunning_id"};
    $form->{addition} = "DUNNING STARTED";
  	$form->save_history($form->dbconnect(\%myconfig));
  }
  # /saving the history

  $form->redirect($locale->text('Dunning Process started for selected invoices!'));

  $lxdebug->leave_sub();
}

sub set_email {
  $lxdebug->enter_sub();


  my $callback = "$form->{script}?action=set_email&";
  map({ $callback .= "$_=" . $form->escape($form->{$_}) . "&" }
      (qw(login password name input_subject input_body input_attachment email_subject email_body email_attachment), grep({ /^[fl]_/ } keys %$form)));

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
      <td><input name=transdatefrom id=transdatefrom size=11 title="$myconfig{dateformat}" onBlur=\"check_right_date_format(this)\">
      <input type=button name=transdatefrom id="trigger1" value=|
      . $locale->text('button') . qq|></td>
      |;
    $button2 = qq|
      <td><input name=transdateto id=transdateto size=11 title="$myconfig{dateformat}" onBlur=\"check_right_date_format(this)\">
      <input type=button name=transdateto id="trigger2" value=|
      . $locale->text('button') . qq|></td>
      |;
    $button3 = qq|
      <td><input name=dunningfrom id=dunningfrom size=11 title="$myconfig{dateformat}" onBlur=\"check_right_date_format(this)\">
      <input type=button name=dunningfrom id="trigger3" value=|
      . $locale->text('button') . qq|></td>
      |;
    $button4 = qq|
      <td><input name=dunningto id=dunningto size=11 title="$myconfig{dateformat}" onBlur=\"check_right_date_format(this)\">
      <input type=button name=dunningto id="trigger4" value=|
      . $locale->text('button') . qq|></td>
      |;

    #write Trigger
    $jsscript =
      Form->write_trigger(\%myconfig, "4", "transdatefrom", "BR", "trigger1", "transdateto", "BR", "trigger2", "dunningfrom", "BR", "trigger3", "dunningto", "BR", "trigger4");
  } else {

    # without JavaScript Calendar
    $button1 =
      qq|<td><input name=transdatefrom id=transdatefrom size=11 title="$myconfig{dateformat}" onBlur=\"check_right_date_format(this)\"></td>|;
    $button2 =
      qq|<td><input name=transdateto id=transdateto size=11 title="$myconfig{dateformat}" onBlur=\"check_right_date_format(this)\"></td>|;
    $button3 =
      qq|<td><input name=dunningfrom id=dunningfrom size=11 title="$myconfig{dateformat}" onBlur=\"check_right_date_format(this)\"></td>|;
    $button4 =
      qq|<td><input name=dunningfrom id=dunningto size=11 title="$myconfig{dateformat}" onBlur=\"check_right_date_format(this)\"></td>|;
  }

  $form->{fokus} = "search.customer";
  $form->{javascript} .= qq|<script type="text/javascript" src="js/common.js"></script>|;
  $form->header;
  $onload = qq|focus()|;
  $onload .= qq|;setupDateFormat('|. $myconfig{dateformat} .qq|', '|. $locale->text("Falsches Datumsformat!") .qq|')|;
  $onload .= qq|;setupPoints('|. $myconfig{numberformat} .qq|', '|. $locale->text("wrongformat") .qq|')|;

  print qq|
<body onLoad="$onload">

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
    "$form->{script}?action=show_dunning&login=$form->{login}&password=$form->{password}&customer=$form->{customer}&invnumber=$form->{invnumber}&ordnumber=$form->{ordnumber}&transdatefrom=$form->{transdatefrom}&transdateto=$form->{transdateto}&dunningfrom=$form->{dunningfrom}&dunningto=$form->{dunningto}&notes=$form->{notes}&showold=$form->{showold}&dunning_level=$form->{dunning_level}"
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
    . $locale->text('Interest')
    . qq|</th>|;

  $form->header;


  print qq|
<body>
<script type="text/javascript" src="js/common.js"></script>
<script type="text/javascript" src="js/dunning.js"></script>
<form method=post action=$form->{script}>


<table width=100%>
  <tr>
    <th class=listtop colspan=10>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>|;
  map { print "$column_header{$_}\n" } @column_index;

  print qq|
        </tr>
|;

  my %columns = (
    "dunning_duedate" => "next_duedate",
    "duedate" => "inv_duedate",
    "transdate" => "invdate",
    "amount" => "invamount",
    );

  my $i = 0;
  my $j = 0;
  my ($previous_dunning_id, $first_row_for_dunning);
  foreach $ref (@{ $form->{DUNNINGS} }) {
    $i++;

    if ($previous_dunning_id != $ref->{dunning_id}) {
      $j++;
      $j = $j % 2;
      $first_row_for_dunning = 1;
    } else {
      $first_row_for_dunning = 0;
    }
    $previous_dunning_id = $ref->{dunning_id};

    print qq|
        <tr valign=top class=listrow$j>
|;

  

    foreach (qw(dunning_date dunning_duedate duedate transdate customername amount fee interest)) {
      my $col = $columns{$_} ? $columns{$_} : $_;
      $column_data{$col} = "<td>" . H($ref->{$_}) . "</td>";
    }

    if ($first_row_for_dunning) {
      $column_data{dunning_description} =
        qq|<td><a href="dn.pl?action=print_dunning&format=pdf&media=screen&| .
        qq|dunning_id=| . E($ref->{dunning_id}) .
        join("", map({ "&${_}=" . E($form->{$_}) } qw(login password callback))) .
        qq|">| . H($ref->{dunning_description}) . qq|</a></td>|;
    } else {
      $column_data{dunning_description} = qq|<td>&nbsp;</td>|;
      $column_data{customername} = qq|<td>&nbsp;</td>|;
    }

    $column_data{invnumber} =
      qq|<td><a href="| . ($ref->{invoice} ? "is.pl" : "ar.pl" ) .
      qq|?action=edit&id=| . H($ref->{id}) .
      join("", map({ "&${_}=" . E($form->{$_}) } qw(login password callback))) .
      qq|">| . H($ref->{invnumber}) . qq|</a></td>|;

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

  DN->print_dunning(\%myconfig, \%$form, $form->{dunning_id}, $userspath, $spool, $sendmail);

  if($form->{DUNNING_PDFS}) {
    DN->melt_pdfs(\%myconfig, \%$form,$spool);
  } else {
    $form->redirect($locale->text('Could not create dunning copy!'));
  }

  $lxdebug->leave_sub();

}

# end of main

