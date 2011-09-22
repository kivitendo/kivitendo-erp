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

  } else {
    $main::auth->assert('DOES_NOT_EXIST');
  }
}

sub search {
  $::lxdebug->enter_sub;

  assert_bp_access();

  # setup customer/vendor selection
  BP->get_vc(\%::myconfig, $::form);

  my %label = (
       invoice           => { title => $::locale->text('Sales Invoices'),  invnumber => 1, ordnumber => 1 },
       sales_order       => { title => $::locale->text('Sales Orders'),    ordnumber => 1, },
       purchase_order    => { title => $::locale->text('Purchase Orders'), ordnumber => 1, },
       sales_quotation   => { title => $::locale->text('Quotations'),      quonumber => 1, },
       request_quotation => { title => $::locale->text('RFQs'),            quonumber => 1, },
       check             => { title => $::locale->text('Checks'),          chknumber => 1, },
       receipt           => { title => $::locale->text('Receipts'),        rctnumber => 1, },
  );

  my $bp_accounts = $::form->{type} =~ /check|receipt/
                 && BP->payment_accounts(\%::myconfig, $::form);

  $::form->header;
  print $::form->parse_html_template('bp/search', {
    label         => \%label,
    show_accounts => $bp_accounts,
    account_sub   => sub { ("$_[0]{accno}--$_[0]{description}")x2 },
    vc_keys       => sub { "$_[0]{name}--$_[0]{id}" },
  });

  $::lxdebug->leave_sub;
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
    if (BP->delete_spool(\%myconfig, \%$form));
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

      if (BP->print_spool(\%myconfig, \%$form, "| $selected_printer")) {
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
  my $spool = $::lx_office_conf{paths}->{spool};

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
      qq|<td><a href=$spool/$ref->{spoolfile}>$ref->{spoolfile}</a></td>
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

