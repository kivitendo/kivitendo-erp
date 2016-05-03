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

use strict;

# any custom scripts for this one
if (-f "bin/mozilla/custom_arap.pl") {
  eval { require "bin/mozilla/custom_arap.pl"; };
}
if (-f "bin/mozilla/$::myconfig{login}_arap.pl") {
  eval { require "bin/mozilla/$::myconfig{login}_arap.pl"; };
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

  my ($name, %params) = @_;

  $name = $name eq "customer" ? "customer" : "vendor";

  my ($new_name,$new_id) = $form->{$name} =~ /^(.*?)--(\d+)$/;
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

      _reset_salesman_id();
      delete @{ $form }{qw(payment_id)};

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
      $i = $form->get_name(\%myconfig, $name);

      if ($i > 1) {
        if ($params{no_select}) {
          # $locale->text('Customer')
          # $locale->text('Vendor')
          $form->error($locale->text("More than one #1 found matching, please be more specific.", $locale->text(ucfirst $name)));
        } else {
          &select_name($name);
          $::dispatcher->end_request;
        }
      }

      if ($i == 1) {

        # we got one name
        $form->{"${name}_id"} = $form->{name_list}[0]->{id};
        $form->{$name}        = $form->{name_list}[0]->{name};
        $form->{"old$name"}   = qq|$form->{$name}--$form->{"${name}_id"}|;

        _reset_salesman_id();
        delete @{ $form }{qw(payment_id)};

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

  $main::auth->assert('general_ledger         | vendor_invoice_edit  | sales_order_edit    | invoice_edit | sales_delivery_order_edit |' .
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
    <h1>$title</h1>

<form method=post action=$form->{script}>

<table width=100%>
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
|;

  $main::lxdebug->leave_sub();
}

sub name_selected {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $main::auth->assert('general_ledger         | vendor_invoice_edit  | sales_order_edit    | invoice_edit | sales_delivery_order_edit | ' .
                'request_quotation_edit | sales_quotation_edit | purchase_order_edit | cash');

  # replace the variable with the one checked

  # index for new item
  my $i = $form->{ndx};

  _reset_salesman_id();

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

# Reset the $::form field 'salesman_id' to the ID of the currently
# logged in user. Useful when changing to a customer/vendor that has
# no salesman listed in their master data.
sub _reset_salesman_id {
  my $current_employee   = SL::DB::Manager::Employee->current;
  $::form->{salesman_id} = $current_employee->id if $current_employee && exists $::form->{salesman_id};
}

sub select_project {
  $::lxdebug->enter_sub;

  $::auth->assert('general_ledger         | vendor_invoice_edit  | sales_order_edit    | invoice_edit |' .
                  'request_quotation_edit | sales_quotation_edit | purchase_order_edit | cash         | report');

  my ($is_global, $nextsub) = @_;
  my $project_list = delete $::form->{project_list};

  map { delete $::form->{$_} } qw(action header update);

  my @hiddens;
  for my $key (keys %$::form) {
    next if $key eq 'login' || $key eq 'password' || '' ne ref $::form->{$key};
    push @hiddens, { key => $key, value => $::form->{$key} };
  }
  push @hiddens, { key => 'is_global',                value => $is_global },
                 { key => 'project_selected_nextsub', value => $nextsub };

  $::form->header;
  print $::form->parse_html_template('arap/select_project', { hiddens => \@hiddens, project_list => $project_list });

  $::lxdebug->leave_sub;
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

1;

__END__

=head1 NAME

arap.pl - helper functions or customer/vendor retrieval

=head1 SYNOPSIS

 check_name('vendor')

=head1 DESCRIPTION

Don't use anyting in this file without extreme care, and even then be prepared for massive headaches.

It's a collection of helper routines that wrap the customer/vendor dropdown/textfield duality into something even complexer.

=head1 FUNCTIONS

=head2 check_name customer|vendor

check_name was originally meant to update the selected customer or vendor. The
way it does that has generted more hate than almost any other part of this
software.

What it does is:

=over 4

=item *

It checks if a vendor or customer is given. No failsafe, vendor fallback if
$_[0] is something fancy.

=item *

It assumes, that there is a field named customer or vendor in $form.

=item *

It assumes, that this field is filled with name--id, and tries to split that.
sql ledger uses that combination to get ids into the select keys.

=item *

It looks for a field selectcustomer or selectvendor in $form. sql ledger used
to store a copy of the html select in there. (again, don't ask)

=item *

If this field exists, it looks for a field called oldcustomer or oldvendor, in
which the old name--id string was stored in sql ledger, and compares those.

=item *

if they don't match, it will set customer_id or vendor_id in $form, load the
entry (which will clobber everything in $form named like a column in customer
oder vendor) and return.

=item *

If there was no select* entry, it assumes that vclimit was lower than the
number of entries, and that an input field was generated. In that case the
splitting is omitted (since users don't generally include ids in entered names)

=item *

It looks for a *_id field, and combines it with the given input into a name--id
entry and compares it to the old* entry. (Missing any of these will instantly
break check_namea.

=item *

If those do not match, $form->get_name is called to get matching results.
get_name only matches by *number and name, not by id, don't try to get it to do
so.

=item *

The results are stored in $form>{name_list} but a count is returned, and
checked.

=item *

If only one result was found, *_id, * and old* are copied into $form, the entry
is loaded (like above, clobbering)

=item *

If there is more than one, a selection dialog is rendered

=item *

If none is found, an error is generated.

=back

=head3 I built a customer/vendor box somewhere and it doesn't work, what's wrong?

Make sure a select* field is given if and only if you render a select box. The
actual contents are ignored, but recognition fails if not present.

Make sure old* and *_id fields are set correctly (name--id form for old*). They
are necessary in all steps and branches.

Since get_customer and get_vendor clobber a lot of fields, make sure what
changes exactly.

=head3 select- version works fine, but things go awry when I use a textbox, any idea?

If there is more than one match, check_name will display a select form, that
will redirect to the original C<nextsub>. Unfortunately any hidden vars or
input fields will be lost in the process unless saved before in a callback.

If you still want to use it, you can disable this feature, like this:

  check_name('customer', no_select => 1)

In that case multiple matches will trigger an error.

Otherwise you'll have to care to include a complete state in callback.

=cut
