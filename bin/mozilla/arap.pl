#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (c) 2002
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
# common routines for gl, ar, ap, is, ir, oe
#

use SL::Projects;

use strict;

# any custom scripts for this one
if (-f "bin/mozilla/custom_arap.pl") {
  eval { require "bin/mozilla/custom_arap.pl"; };
}
if (-f "bin/mozilla/$main::form->{login}_arap.pl") {
  eval { require "bin/mozilla/$main::form->{login}_arap.pl"; };
}

1;

require "bin/mozilla/common.pl";

# end of main

sub check_name {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('general_ledger               | vendor_invoice_edit       | sales_order_edit    | invoice_edit |' .
                'request_quotation_edit       | sales_quotation_edit      | purchase_order_edit | cash         |' .
                'purchase_delivery_order_edit | sales_delivery_order_edit');

  my ($name) = @_;

  $name = $name eq "customer" ? "customer" : "vendor";

  my ($new_name, $new_id) = split /--/, $form->{$name};
  my $i = 0;
  # if we use a selection
  if ($form->{"select$name"}) {
    if ($form->{"old$name"} ne $form->{$name}) {

      # this is needed for is, ir and oe
      $form->{update} = 0;
      # for credit calculations
      $form->{oldinvtotal}  = 0;
      $form->{oldtotalpaid} = 0;
      $form->{calctax}      = 1;

      $form->{"${name}_id"} = $new_id;

      IS->get_customer(\%myconfig, \%$form) if ($name eq 'customer');
      IR->get_vendor(\%myconfig, \%$form) if ($name eq 'vendor');

      $form->{$name} = $form->{"old$name"} = "$new_name--$new_id";

      $i = 1;
    }
  } else {

    # check name, combine name and id
    if ($form->{"old$name"} ne qq|$form->{$name}--$form->{"${name}_id"}|) {

      # this is needed for is, ir and oe
      $form->{update} = 0;

      # for credit calculations
      $form->{oldinvtotal}  = 0;
      $form->{oldtotalpaid} = 0;
      $form->{calctax}      = 1;

      # return one name or a list of names in $form->{name_list}
      if (($i = $form->get_name(\%myconfig, $name)) > 1) {
        &select_name($name);
        exit;
      }

      if ($i == 1) {

        # we got one name
        $form->{"${name}_id"} = $form->{name_list}[0]->{id};
        $form->{$name}        = $form->{name_list}[0]->{name};
        $form->{"old$name"}   = qq|$form->{$name}--$form->{"${name}_id"}|;

        IS->get_customer(\%myconfig, \%$form) if ($name eq 'customer');
        IR->get_vendor(\%myconfig, \%$form) if ($name eq 'vendor');

      } else {

        # name is not on file
        # $locale->text('Customer not on file or locked!')
        # $locale->text('Vendor not on file or locked!')
        my $msg = ucfirst $name . " not on file or locked!";
        $form->error($locale->text($msg));
      }
    }
  }
  $form->language_payment(\%myconfig);

  $main::lxdebug->leave_sub();

  return $i;
}

# $locale->text('Customer not on file!')
# $locale->text('Vendor not on file!')

sub select_name {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  $main::auth->assert('general_ledger         | vendor_invoice_edit  | sales_order_edit    | invoice_edit |' .
                'request_quotation_edit | sales_quotation_edit | purchase_order_edit | cash');

  my ($table) = @_;

  my @column_index = qw(ndx name address);

  my $label             = ucfirst $table;
  my %column_data;
  $column_data{ndx}  = qq|<th>&nbsp;</th>|;
  $column_data{name} =
    qq|<th class=listheading>| . $locale->text($label) . qq|</th>|;
  $column_data{address} =
    qq|<th class=listheading>| . $locale->text('Address') . qq|</th>|;

  # list items with radio button on a form
  $form->header;

  my $title = $locale->text('Select from one of the names below');

  print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <th class=listtop>$title</th>
  </tr>
  <tr space=5></tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>|;

  map { print "\n$column_data{$_}" } @column_index;

  print qq|
        </tr>
|;

  my $i = 0;
  my $j;
  foreach my $ref (@{ $form->{name_list} }) {
    my $checked = ($i++) ? "" : "checked";

    $ref->{name} =~ s/\"/&quot;/g;

    $column_data{ndx} =
      qq|<td><input name=ndx class=radio type=radio value=$i $checked></td>|;
    $column_data{name} =
      qq|<td><input name="new_name_$i" type=hidden value="$ref->{name}">$ref->{name}</td>|;
    $column_data{address} = qq|<td>$ref->{address}&nbsp;</td>|;

    $j++;
    $j %= 2;
    print qq|
        <tr class=listrow$j>|;

    map { print "\n$column_data{$_}" } @column_index;

    print qq|
        </tr>

<input name="new_id_$i" type=hidden value=$ref->{id}>

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

<input name=lastndx type=hidden value=$i>

|;

  # delete variables
  map { delete $form->{$_} } qw(action name_list header);

  # save all other form variables
  foreach my $key (keys %${form}) {
    next if (($key eq 'login') || ($key eq 'password') || ('' ne ref $form->{$key}));
    $form->{$key} =~ s/\"/&quot;/g;
    print qq|<input name=$key type=hidden value="$form->{$key}">\n|;
  }

  print qq|
<input type=hidden name=nextsub value=name_selected>

<input type=hidden name=vc value=$table>
<br>
<input class=submit type=submit name=action value="|
    . $locale->text('Continue') . qq|">
</form>

</body>
</html>
|;

  $main::lxdebug->leave_sub();
}

sub name_selected {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $main::auth->assert('general_ledger         | vendor_invoice_edit  | sales_order_edit    | invoice_edit |' .
                'request_quotation_edit | sales_quotation_edit | purchase_order_edit | cash');

  # replace the variable with the one checked

  # index for new item
  my $i = $form->{ndx};

  $form->{ $form->{vc} }    = $form->{"new_name_$i"};
  $form->{"$form->{vc}_id"} = $form->{"new_id_$i"};
  $form->{"old$form->{vc}"} =
    qq|$form->{$form->{vc}}--$form->{"$form->{vc}_id"}|;

  # delete all the new_ variables
  for $i (1 .. $form->{lastndx}) {
    map { delete $form->{"new_${_}_$i"} } qw(id name);
  }

  map { delete $form->{$_} } qw(ndx lastndx nextsub);

  IS->get_customer(\%myconfig, \%$form) if ($form->{vc} eq 'customer');
  IR->get_vendor(\%myconfig, \%$form) if ($form->{vc} eq 'vendor');

  &update(1);

  $main::lxdebug->leave_sub();
}

sub check_project {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  $main::auth->assert('general_ledger         | vendor_invoice_edit  | sales_order_edit    | invoice_edit |' .
                'request_quotation_edit | sales_quotation_edit | purchase_order_edit | cash         | report');

  my $nextsub = shift || 'update';

  for my $i (1 .. $form->{rowcount}) {
    my $suffix = $i ? "_$i" : "";
    my $prefix = $i ? "" : "global";
    $form->{"${prefix}project_id${suffix}"} = "" unless $form->{"${prefix}projectnumber$suffix"};
    if ($form->{"${prefix}projectnumber${suffix}"} ne $form->{"old${prefix}projectnumber${suffix}"}) {
      if ($form->{"${prefix}projectnumber${suffix}"}) {

        # get new project
        $form->{projectnumber} = $form->{"${prefix}projectnumber${suffix}"};
        my %params             = map { $_ => $form->{$_} } qw(projectnumber description active);
        my $rows;
        if (($rows = Projects->search_projects(%params)) > 1) {

          # check form->{project_list} how many there are
          $form->{rownumber} = $i;
          &select_project($i ? undef : 1, $nextsub);
          exit;
        }

        if ($rows == 1) {
          $form->{"${prefix}project_id${suffix}"}       = $form->{project_list}->[0]->{id};
          $form->{"${prefix}projectnumber${suffix}"}    = $form->{project_list}->[0]->{projectnumber};
          $form->{"old${prefix}projectnumber${suffix}"} = $form->{project_list}->[0]->{projectnumber};
        } else {

          # not on file
          $form->error($locale->text('Project not on file!'));
        }
      } else {
        $form->{"old${prefix}projectnumber${suffix}"} = "";
      }
    }
  }

  $main::lxdebug->leave_sub();
}

sub select_project {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;
  my $cgi      = $main::cgi;

  $main::auth->assert('general_ledger         | vendor_invoice_edit  | sales_order_edit    | invoice_edit |' .
                'request_quotation_edit | sales_quotation_edit | purchase_order_edit | cash         | report');

  my ($is_global, $nextsub) = @_;

  my @column_index = qw(ndx projectnumber description);

  my %column_data;
  $column_data{ndx}           = qq|<th>&nbsp;</th>|;
  $column_data{projectnumber} = qq|<th>| . $locale->text('Number') . qq|</th>|;
  $column_data{description}   =
    qq|<th>| . $locale->text('Description') . qq|</th>|;

  # list items with radio button on a form
  $form->header;

  my $title = $locale->text('Select from one of the projects below');

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=rownumber value=$form->{rownumber}>

<table width=100%>
  <tr>
    <th class=listtop>$title</th>
  </tr>
  <tr space=5></tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>|;

  map { print "\n$column_data{$_}" } @column_index;

  print qq|
        </tr>
|;

  my $i = 0;
  my $j;
  foreach my $ref (@{ $form->{project_list} }) {
    my $checked = ($i++) ? "" : "checked";

    $ref->{name} =~ s/\"/&quot;/g;

    $column_data{ndx} =
      qq|<td><input name=ndx class=radio type=radio value=$i $checked></td>|;
    $column_data{projectnumber} =
      qq|<td><input name="new_projectnumber_$i" type=hidden value="$ref->{projectnumber}">$ref->{projectnumber}</td>|;
    $column_data{description} = qq|<td>$ref->{description}</td>|;

    $j++;
    $j %= 2;
    print qq|
        <tr class=listrow$j>|;

    map { print "\n$column_data{$_}" } @column_index;

    print qq|
        </tr>

<input name="new_id_$i" type=hidden value=$ref->{id}>

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

<input name=lastndx type=hidden value=$i>

|;

  # delete action variable
  map { delete $form->{$_} } qw(action project_list header update);

  # save all other form variables
  foreach my $key (keys %${form}) {
    next if (($key eq 'login') || ($key eq 'password') || ('' ne ref $form->{$key}));
    $form->{$key} =~ s/\"/&quot;/g;
    print qq|<input name=$key type=hidden value="$form->{$key}">\n|;
  }

  print
      $cgi->hidden('-name' => 'is_global',                '-default' => [$is_global])
    . $cgi->hidden('-name' => 'project_selected_nextsub', '-default' => [$nextsub])
    . qq|<input type=hidden name=nextsub value=project_selected>

<br>
<input class=submit type=submit name=action value="|
    . $locale->text('Continue') . qq|">
</form>

</body>
</html>
|;

  $main::lxdebug->leave_sub();
}

sub project_selected {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  $main::auth->assert('general_ledger         | vendor_invoice_edit  | sales_order_edit    | invoice_edit |' .
                'request_quotation_edit | sales_quotation_edit | purchase_order_edit | cash         | report');

  # replace the variable with the one checked

  # index for new item
  my $i = $form->{ndx};

  my $prefix = $form->{"is_global"} ? "global" : "";
  my $suffix = $form->{"is_global"} ? "" : "_$form->{rownumber}";

  $form->{"${prefix}projectnumber${suffix}"} =
    $form->{"new_projectnumber_$i"};
  $form->{"old${prefix}projectnumber${suffix}"} =
    $form->{"new_projectnumber_$i"};
  $form->{"${prefix}project_id${suffix}"} = $form->{"new_id_$i"};

  # delete all the new_ variables
  for $i (1 .. $form->{lastndx}) {
    map { delete $form->{"new_${_}_$i"} } qw(id projectnumber description);
  }

  my $nextsub = $form->{project_selected_nextsub} || 'update';

  map { delete $form->{$_} } qw(ndx lastndx nextsub is_global project_selected_nextsub);

  call_sub($nextsub);

  $main::lxdebug->leave_sub();
}

sub continue       { call_sub($main::form->{"nextsub"}); }

