#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (c) 2003
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
# Batch printing
#
#======================================================================

use SL::BP;
use Data::Dumper;
use List::Util qw(first);

1;

require "bin/mozilla/common.pl";

use strict;

# end of main

sub assert_bp_access {
  my $form     = $main::form;

  my %access_map = (
    'invoice'           => 'invoice_edit',
    'sales_order'       => 'sales_order_edit',
    'sales_quotation'   => 'sales_quotation_edit',
    'purchase_order'    => 'purchase_order_edit',
    'request_quotation' => 'request_quotation_edit',
    'check'             => 'cash',
    'receipt'           => 'cash',
  );

  if ($form->{type} && $access_map{$form->{type}}) {
    $main::auth->assert($access_map{$form->{type}});

  } elsif ($form->{type} eq 'packing_list') {
    $main::lxdebug->message(0, "1");
    if (!$main::auth->assert('sales_order_edit', 1)) {
    $main::lxdebug->message(0, "2");
      $main::auth->assert('invoice_edit') ;
    }
    $main::lxdebug->message(0, "3");

  } else {
    $main::auth->assert('DOES_NOT_EXIST');
  }
}

sub search {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  my ($name, $account, $onload);

  assert_bp_access();

  # $locale->text('Sales Invoices')
  # $locale->text('Packing Lists')
  # $locale->text('Sales Orders')
  # $locale->text('Purchase Orders')
  # $locale->text('Quotations')
  # $locale->text('RFQs')
  # $locale->text('Checks')
  # $locale->text('Receipts')

  # setup customer/vendor selection
  BP->get_vc(\%myconfig, \%$form);

  if (@{ $form->{"all_$form->{vc}"} || [] }) {
    map { $name .= "<option>$_->{name}--$_->{id}\n" }
      @{ $form->{"all_$form->{vc}"} };
    $name = qq|<select name=$form->{vc}><option>\n$name</select>|;
  } else {
    $name = qq|<input name=$form->{vc} size=35>|;
  }

  # $locale->text('Customer')
  # $locale->text('Vendor')

  my %label = (
       invoice =>
         { title => 'Sales Invoices', name => 'Customer', l_invnumber => 'Y' },
       packing_list =>
         { title => 'Packing Lists', name => 'Customer', l_invnumber => 'Y' },
       sales_order =>
         { title => 'Sales Orders', name => 'Customer', l_ordnumber => 'Y' },
       purchase_order =>
         { title => 'Purchase Orders', name => 'Vendor', l_ordnumber => 'Y' },
       sales_quotation =>
         { title => 'Quotations', name => 'Customer', l_quonumber => 'Y' },
       request_quotation =>
         { title => 'RFQs', name => 'Vendor', l_quonumber => 'Y' },
       check   => { title => 'Checks',   name => 'Vendor' },
       receipt => { title => 'Receipts', name => 'Customer' });

  $label{invoice}{invnumber} = qq|
        <tr>
          <th align=right nowrap>| . $locale->text('Invoice Number') . qq|</th>
          <td colspan=3><input name=invnumber size=20></td>
        </tr>
|;
  $label{invoice}{ordnumber} = qq|
        <tr>
          <th align=right nowrap>| . $locale->text('Order Number') . qq|</th>
          <td colspan=3><input name=ordnumber size=20></td>
        </tr>
|;
  $label{sales_quotation}{quonumber} = qq|
        <tr>
          <th align=right nowrap>| . $locale->text('Quotation Number') . qq|</th>
          <td colspan=3><input name=quonumber size=20></td>
        </tr>
|;

  $label{check}{chknumber} = qq|
          <tr>
          <th align=right nowrap>| . $locale->text('Reference') . qq|</th>
          <td colspan=3><input name=chknumber size=20></td>
        </tr>
|;

  $label{packing_list}{invnumber}      = $label{invoice}{invnumber};
  $label{packing_list}{ordnumber}      = $label{invoice}{ordnumber};
  $label{sales_order}{ordnumber}       = $label{invoice}{ordnumber};
  $label{purchase_order}{ordnumber}    = $label{invoice}{ordnumber};
  $label{request_quotation}{quonumber} = $label{sales_quotation}{quonumber};
  $label{receipt}{rctnumber}           = $label{check}{chknumber};

  # do one call to text
  $form->{title} =
      $locale->text('Print') . " "
    . $locale->text($label{ $form->{type} }{title});

  if ($form->{type} =~ /(check|receipt)/) {
    if (BP->payment_accounts(\%myconfig, \%$form)) {
      $account = qq|
        <tr>
          <th align=right>| . $locale->text('Account') . qq|</th>
|;

      if ($form->{accounts}) {
        $account .= qq|
          <td colspan=3><select name=account>
|;
        foreach my $ref (@{ $form->{accounts} }) {
          $account .= qq|
          <option>$ref->{accno}--$ref->{description}
|;
        }

        $account .= qq|
          </select>
|;
      } else {
        $account .= qq|
          <td colspan=3><input name=account></td>
|;

      }

      $account .= qq|
         </tr>
|;

    }
  }

  # use JavaScript Calendar or not
  $form->{jsscript} = 1;
  my $jsscript = "";
  my ($button1, $button2);
  if ($form->{jsscript}) {

    # with JavaScript Calendar
    $button1 = qq|
       <td><input name=transdatefrom id=transdatefrom size=11 title="$myconfig{dateformat}" onBlur=\"check_right_date_format(this)\">
       <input type=button name=transdatefrom id="trigger1" value=|
      . $locale->text('button') . qq|></td>
      |;
    $button2 = qq|
       <td><input name=transdateto id=transdateto size=11 title="$myconfig{dateformat}" onBlur=\"check_right_date_format(this)\">
       <input type=button name=transdateto name=transdateto id="trigger2" value=|
      . $locale->text('button') . qq|></td>
     |;

    #write Trigger
    $jsscript =
      Form->write_trigger(\%myconfig, "2", "transdatefrom", "BR", "trigger1",
                          "transdateto", "BL", "trigger2");
  } else {

    # without JavaScript Calendar
    $button1 = qq|
                              <td><input name=transdatefrom id=transdatefrom size=11 title="$myconfig{dateformat}" onBlur=\"check_right_date_format(this)\"></td>|;
    $button2 = qq|
                              <td><input name=transdateto id=transdateto size=11 title="$myconfig{dateformat}" onBlur=\"check_right_date_format(this)\"></td>|;
  }
  $form->{javascript} .= qq|<script type="text/javascript" src="js/common.js"></script>|;
  $form->header;
  $onload = qq|;setupDateFormat('|. $myconfig{dateformat} .qq|', '|. $locale->text("Falsches Datumsformat!") .qq|')|;
  $onload .= qq|;setupPoints('|. $myconfig{numberformat} .qq|', '|. $locale->text("wrongformat") .qq|')|;
  print qq|
<body onLoad="$onload">

<form method=post action=bp.pl>

<input type=hidden name=vc value=$form->{vc}>
<input type=hidden name=type value=$form->{type}>
<input type=hidden name=title value="$form->{title}">

<table width=100%>
  <tr><th class=listtop>$form->{title}</th></tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
        <tr>
          <th align=right>Kunde</th>
          <td colspan=3>$name</td>
        </tr>
        $account
        $label{$form->{type}}{invnumber}
        $label{$form->{type}}{ordnumber}
        $label{$form->{type}}{quonumber}
        $label{$form->{type}}{chknumber}
        $label{$form->{type}}{rctnumber}
        <tr>
          <th align=right nowrap>| . $locale->text('From') . qq|</th>
          $button1
          <th align=right>| . $locale->text('Bis') . qq|</th>
          $button2
        </tr>
        <input type=hidden name=sort value=transdate>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<input type=hidden name=nextsub value=list_spool>

<br>
<input class=submit type=submit name=action value="|
    . $locale->text('Continue') . qq|">

</form>

</body>

$jsscript

</html>
|;

  $main::lxdebug->leave_sub();
}

sub remove {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  assert_bp_access();

  my $selected = 0;

  for my $i (1 .. $form->{rowcount}) {
    if ($form->{"checked_$i"}) {
      $selected = 1;
      last;
    }
  }

  $form->error('Nothing selected!') unless $selected;

  $form->{title} = $locale->text('Confirm!');

  $form->header;

  print qq|
<body>

<form method=post action=bp.pl>
|;

  map { delete $form->{$_} } qw(action header);

  foreach my $key (keys %$form) {
    next if (($key eq 'login') || ($key eq 'password') || ('' ne ref $form->{$key}));
    print qq|<input type=hidden name=$key value="$form->{$key}">\n|;
  }

  print qq|
<h2 class=confirm>$form->{title}</h2>

<h4>|
    . $locale->text(
          'Are you sure you want to remove the marked entries from the queue?')
    . qq|</h4>

<input name=action class=submit type=submit value="|
    . $locale->text('Yes') . qq|">
</form>

</body>
</html>
|;

  $main::lxdebug->leave_sub();
}

sub yes {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  assert_bp_access();

  $form->info($locale->text('Removing marked entries from queue ...'));
  $form->{callback} .= "&header=1" if $form->{callback};

  $form->redirect($locale->text('Removed spoolfiles!'))
    if (BP->delete_spool(\%myconfig, \%$form, $main::spool));
  $form->error($locale->text('Cannot remove files!'));

  $main::lxdebug->leave_sub();
}

sub print {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  assert_bp_access();

  $form->get_lists(printers => 'ALL_PRINTERS');
  # use the command stored in the databse or fall back to $myconfig{printer}
  my $selected_printer =  first { $_ } map ({ $_ ->{printer_command} }
                                         grep { $_->{id} eq $form->{printer} }
                                           @{ $form->{ALL_PRINTERS} }),
                                       $myconfig{printer};

  if ($form->{callback}) {
    map { $form->{callback} .= "&checked_$_=1" if $form->{"checked_$_"} }
      (1 .. $form->{rowcount});
    $form->{callback} .= "&header=1";
  }

  for my $i (1 .. $form->{rowcount}) {
    if ($form->{"checked_$i"}) {
      $form->info($locale->text('Printing ... '));

      if (BP->print_spool(\%myconfig, \%$form, $main::spool, "| $selected_printer")) {
        print $locale->text('done');
        $form->redirect($locale->text('Marked entries printed!'));
      }
      ::end_of_request();
    }
  }

  $form->error('Nothing selected!');

  $main::lxdebug->leave_sub();
}

sub list_spool {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  assert_bp_access();

  $form->{ $form->{vc} } = $form->unescape($form->{ $form->{vc} });
  ($form->{ $form->{vc} }, $form->{"$form->{vc}_id"}) =
    split(/--/, $form->{ $form->{vc} });

  BP->get_spoolfiles(\%myconfig, \%$form);

  my $title = $form->escape($form->{title});
  my $href  = "bp.pl?action=list_spool&vc=$form->{vc}&type=$form->{type}&title=$title";

  $title = $form->escape($form->{title}, 1);
  my $callback =
    "bp.pl?action=list_spool&vc=$form->{vc}&type=$form->{type}&title=$title";
  my $option;

  if ($form->{ $form->{vc} }) {
    $callback .= "&$form->{vc}=" . $form->escape($form->{ $form->{vc} }, 1);
    $href .= "&$form->{vc}=" . $form->escape($form->{ $form->{vc} });
    $option =
      ($form->{vc} eq 'customer')
      ? $locale->text('Customer')
      : $locale->text('Vendor');
    $option .= " : $form->{$form->{vc}}";
  }
  if ($form->{account}) {
    $callback .= "&account=" . $form->escape($form->{account}, 1);
    $href .= "&account=" . $form->escape($form->{account});
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('Account') . " : $form->{account}";
  }
  if ($form->{invnumber}) {
    $callback .= "&invnumber=" . $form->escape($form->{invnumber}, 1);
    $href .= "&invnumber=" . $form->escape($form->{invnumber});
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('Invoice Number') . " : $form->{invnumber}";
  }
  if ($form->{ordnumber}) {
    $callback .= "&ordnumber=" . $form->escape($form->{ordnumber}, 1);
    $href .= "&ordnumber=" . $form->escape($form->{ordnumber});
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('Order Number') . " : $form->{ordnumber}";
  }
  if ($form->{quonumber}) {
    $callback .= "&quonumber=" . $form->escape($form->{quonumber}, 1);
    $href .= "&quonumber=" . $form->escape($form->{quonumber});
    $option .= "\n<br>" if ($option);
    $option .= $locale->text('Quotation Number') . " : $form->{quonumber}";
  }

  if ($form->{transdatefrom}) {
    $callback .= "&transdatefrom=$form->{transdatefrom}";
    $href     .= "&transdatefrom=$form->{transdatefrom}";
    $option   .= "\n<br>" if ($option);
    $option   .=
        $locale->text('From') . "&nbsp;"
      . $locale->date(\%myconfig, $form->{transdatefrom}, 1);
  }
  if ($form->{transdateto}) {
    $callback .= "&transdateto=$form->{transdateto}";
    $href     .= "&transdateto=$form->{transdateto}";
    $option   .= "\n<br>" if ($option);
    $option   .=
        $locale->text('To') . "&nbsp;"
      . $locale->date(\%myconfig, $form->{transdateto}, 1);
  }

  my $name = ucfirst $form->{vc};

  my @columns = qw(transdate);
  if ($form->{type} =~ /(invoice|packing_list|check|receipt)/) {
    push @columns, "invnumber";
  }
  if ($form->{type} =~ /_order$/) {
    push @columns, "ordnumber";
  }
  if ($form->{type} =~ /_quotation$/) {
    push @columns, "quonumber";
  }

  push @columns, qw(name spoolfile);
  my @column_index = $form->sort_columns(@columns);
  unshift @column_index, "checked";

  my %column_header;
  my %column_data;

  $column_header{checked}   = "<th class=listheading>&nbsp;</th>";
  $column_header{transdate} =
      "<th><a class=listheading href=$href&sort=transdate>"
    . $locale->text('Date')
    . "</a></th>";
  $column_header{invnumber} =
      "<th><a class=listheading href=$href&sort=invnumber>"
    . $locale->text('Invoice')
    . "</a></th>";
  $column_header{ordnumber} =
      "<th><a class=listheading href=$href&sort=ordnumber>"
    . $locale->text('Order')
    . "</a></th>";
  $column_header{quonumber} =
      "<th><a class=listheading href=$href&sort=quonumber>"
    . $locale->text('Quotation')
    . "</a></th>";
  $column_header{name} =
      "<th><a class=listheading href=$href&sort=name>"
    . $locale->text($name)
    . "</a></th>";
  $column_header{spoolfile} =
    "<th class=listheading>" . $locale->text('Spoolfile') . "</th>";

  $form->header;

  print qq|
<body>

<form method=post action=bp.pl>

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

  # add sort and escape callback, this one we use for the add sub
  $form->{callback} = $callback .= "&sort=$form->{sort}";

  # escape callback for href
  $callback = $form->escape($callback);

  my $i = 0;
  my $j = 0;
  my $spoolfile;

  foreach my $ref (@{ $form->{SPOOL} }) {

    $i++;

    $form->{"checked_$i"} = "checked" if $form->{"checked_$i"};

    if ($ref->{invoice}) {
      $ref->{module} = ($ref->{module} eq 'ar') ? "is" : "ir";
    }
    my $module = "$ref->{module}.pl";

    $column_data{transdate} = "<td>$ref->{transdate}&nbsp;</td>";

    if ($spoolfile eq $ref->{spoolfile}) {
      $column_data{checked} = qq|<td></td>|;
    } else {
      $column_data{checked} =
        qq|<td><input name=checked_$i type=checkbox style=checkbox $form->{"checked_$i"} $form->{"checked_$i"}></td>|;
    }

    $column_data{invnumber} =
      "<td><a href=$module?action=edit&id=$ref->{id}&type=$form->{type}&callback=$callback>$ref->{invnumber}</a></td>";
    $column_data{ordnumber} =
      "<td><a href=$module?action=edit&id=$ref->{id}&type=$form->{type}&callback=$callback>$ref->{ordnumber}</a></td>";
    $column_data{quonumber} =
      "<td><a href=$module?action=edit&id=$ref->{id}&type=$form->{type}&callback=$callback>$ref->{quonumber}</a></td>";
    $column_data{name}      = "<td>$ref->{name}</td>";
    $column_data{spoolfile} =
      qq|<td><a href=$main::spool/$ref->{spoolfile}>$ref->{spoolfile}</a></td>
<input type=hidden name="spoolfile_$i" value=$ref->{spoolfile}>
|;

    $spoolfile = $ref->{spoolfile};

    $j++;
    $j %= 2;
    print "
        <tr class=listrow$j>
";

    map { print "\n$column_data{$_}" } @column_index;

    print qq|
        </tr>
|;

  }

  print qq|
<input type=hidden name=rowcount value=$i>

      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<br>

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=title value="$form->{title}">
<input type=hidden name=vc value="$form->{vc}">
<input type=hidden name=type value="$form->{type}">
<input type=hidden name=sort value="$form->{sort}">

<input type=hidden name=account value="$form->{account}">
|;

#  if ($myconfig{printer}) {
    print qq|
<input type=hidden name=transdateto value=$form->{transdateto}>
<input type=hidden name=transdatefrom value=$form->{transdatefrom}>
<input type=hidden name=invnumber value=$form->{invnumber}>
<input type=hidden name=ordnumber value=$form->{ordnumber}>
<input type=hidden name=quonumber value=$form->{quonumber}>
<input type=hidden name=customer value=$form->{customer}>
<input type=hidden name=vendor value=$form->{vendor}>
<input class=submit type=submit name=action value="|
      . $locale->text('Select all') . qq|">
<input class=submit type=submit name=action value="|
      . $locale->text('Remove') . qq|">
<input class=submit type=submit name=action value="|
      . $locale->text('Print') . qq|">
|;

$form->get_lists(printers=>"ALL_PRINTERS");
print qq|<select name="printer">|;
print map(qq|<option value="$_->{id}">| . H($_->{printer_description}) . qq|</option>|, @{ $form->{ALL_PRINTERS} });
print qq|</select>|;

#  }

  print qq|
</form>

</body>
</html>
|;

  $main::lxdebug->leave_sub();
}

sub select_all {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  assert_bp_access();

  map { $form->{"checked_$_"} = 1 } (1 .. $form->{rowcount});
  &list_spool;

  $main::lxdebug->leave_sub();
}

sub continue { call_sub($main::form->{"nextsub"}); }

