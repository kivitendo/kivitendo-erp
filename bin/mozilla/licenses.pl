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
#  Author: Moritz Bunkus
#   Email: m.bunkus@linet-services.de
#     Web: http://www.linet-services.de/
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
# Software license module
#
#======================================================================

use SL::IC;
use SL::IS;
use SL::LICENSES;

require "bin/mozilla/common.pl";

sub quot {
  $lxdebug->enter_sub();
  $_[0] =~ s/\"/\&quot;/g;
  $lxdebug->leave_sub();
  return $_[0];
}

sub form_header {
  $lxdebug->enter_sub();

  $auth->assert('license_edit');

  $form->{jsscript} = 1;
  $form->header();

  print(
    qq|<body>

<form method=post action=$form->{script}>|);
  $lxdebug->leave_sub();
}

sub form_footer {
  $lxdebug->enter_sub();

  $auth->assert('license_edit');

  my @items = qw(old_callback previousform);
  push(@items, @{ $form->{"hidden"} });
  map({
      print("<input type=hidden name=$_ value=\"" . quot($form->{$_}) . "\">\n"
      );
  } @items);

  print(
    qq|<input type="hidden" name="cursor_field" value='$form->{cursor_field}'></form>
</body>
</html>
|);
  $lxdebug->leave_sub();
}

sub set_std_hidden {
  $lxdebug->enter_sub();
  $form->{"hidden"} = ["comment", "validuntil", "quantity", @_];
  $lxdebug->leave_sub();
}

sub print_part_selection {
  $lxdebug->enter_sub();

  $auth->assert('license_edit');

  form_header();
  set_std_hidden("business");

  print(
    qq|

<table width=100%>
  <tr>
    <th class=listtop colspan=5>|
      . $locale->text('Select from one of the items below') . qq|</th>
  </tr>
  <tr height="5"></tr>
  <tr class=listheading>
    <th>&nbsp;</th>
    <th class=listheading>| . $locale->text('Part Number') . qq|</th>
    <th class=listheading>| . $locale->text('Description') . qq|</th>
  </tr>
        |);

  $j = 1;
  for ($i = 1; $i <= scalar(@{ $form->{"parts"} }); $i++) {
    %p = %{ $form->{"parts"}->[$i - 1] };
    if ($i == 1) {
      $checked = "checked";
    } else {
      $checked = "";
    }

    print(
      qq|<tr class=listrow$j>
      <td><input name=ndx class=radio type=radio value=$i $checked></td>
      <td><input name=\"new_partnumber_$i\" type=hidden value=\"|
        . $p{"partnumber"} . qq|\">| . $p{"partnumber"} . qq|</td>
      <td><input name=\"new_description_$i\" type=hidden value=\"|
        . $p{"description"} . qq|\">| . $p{"description"} . qq|</td>
      <input name=\"new_parts_id_$i\" type=hidden value=\"| . $p{"id"} . qq|\">
    </tr>|);

    $j = ($j + 1) % 2;
  }

  print(
    qq|<tr><td colspan=3><hr size=3 noshade></td></tr>
</table>

<input type=hidden name=nextsub value=\"do_add\">
<input type=submit name=action value=| . $locale->text('Continue') . qq|>|);

  form_footer();
  $lxdebug->leave_sub();
}

sub print_customer_selection {
  $lxdebug->enter_sub();

  $auth->assert('license_edit');

  form_header();
  set_std_hidden("parts_id", "partnumber", "description");

  print(
    qq|
<table width=100%>
  <tr>
    <th class=listtop colspan=5>|
      . $locale->text('Select from one of the names below') . qq|</th>
  </tr>
  <tr height="5"></tr>
  <tr class=listheading>
    <th>&nbsp;</th>
    <th class=listheading>| . $locale->text('Customer Number') . qq|</th>
    <th class=listheading>| . $locale->text('Company Name') . qq|</th>
    <th class=listheading>| . $locale->text('Street') . qq|</th>
    <th class=listheading>| . $locale->text('Zipcode') . qq|</th>
    <th class=listheading>| . $locale->text('City') . qq|</th>
  </tr>
        |);

  print(qq|<tr><td colspan=6><hr size=3 noshade></td></tr>|);

  $j = 1;
  for ($i = 1; $i <= scalar(@{ $form->{"all_customers"} }); $i++) {
    %c = %{ $form->{"all_customers"}->[$i - 1] };
    if ($i == 1) {
      $checked = "checked";
    } else {
      $checked = "";
    }

    print(
      qq|<tr class=listrow$j>
          <td><input name=ndx class=radio type=radio value=$i $checked></td>
          <td><input name=\"new_customer_id_$i\" type=hidden value=\"|
        . $c{"id"} . qq|\">$c{"customernumber"}</td>
          <td><input name=\"new_customer_name_$i\" type=hidden value=\"|
        . $c{"name"} . qq|\">$c{"name"}</td>
          <td>$c{"street"}</td>
          <td>$c{"zipcode"}</td>
          <td>$c{"city"}</td>
          </tr>|);

    $j = ($j + 1) % 2;
  }

  print(
    qq|
</table>

<input type=hidden name=nextsub value=\"do_add\">
<input type=submit name=action value=| . $locale->text('Continue') . qq|>|);

  form_footer();
  $lxdebug->leave_sub();
}

sub print_license_form {
  $lxdebug->enter_sub();

  $auth->assert('license_edit');

  print(
    qq|
<table width=100%>
  <tr>
    <th class=listtop>| . $locale->text("Add License") . qq|</th>
  </tr>
  <tr>
    <table>
      <tr>
        <th align=right>| . $locale->text('Part Number') . qq|</th>
        <td><input name=partnumber value=\"|
      . quot($form->{"partnumber"}) . qq|\"></td>
      </tr>
      <tr>
        <th align=right>| . $locale->text('Description') . qq|</th>
        <td><input name=description value=\"|
      . quot($form->{"description"}) . qq|\"></td>
      </tr>
      <tr>
        <th align=right>| . $locale->text('Company Name') . qq|</th>|);
  if ($form->{"all_customer"}) {
    print(qq|<td><select name=\"customer\">|);
    foreach (@{ $form->{"all_customer"} }) {
      if (!defined($form->{"customer_id"})) {
        $form->{"customer_id"} = $_->{"id"};
      }
      $selected = ($_->{"id"} * 1) == $form->{"customer_id"} ? "selected" : "";
      print(qq|<option $selected> $_->{"name"}--$_->{"id"}</option>|);
    }
    print(qq|</select></td>|);
  } else {
    print(  qq|<td><input name=customer_name value=\"|
          . quot($form->{"customer_name"})
          . qq|\"></td>|);
  }
  print(
    qq|</tr>
      <tr>
        <th align=right>| . $locale->text('Comment') . qq|</th>
        <td><input name=comment value=\"|
      . quot($form->{"comment"}) . qq|\"></td>
      </tr>
      <tr>
        <th align=right>| . $locale->text('Valid until') . qq|</th>
        <td><input id=validuntil name=validuntil value=\"|
      . quot($form->{"validuntil"}) . qq|\">
         <input type="button" name="validuntil" id="trigger_validuntil" value="?"></td>
      </tr>
      <tr>
        <th align=right>| . $locale->text('Quantity') . qq|</th>
        <td><input name=quantity value=\"|
      . quot($form->{"quantity"}) . qq|\"></td>
      </tr>
      <tr>
        <th align=right>| . $locale->text('License key') . qq|</th>
        <td><input name=licensenumber value=\"|
      . quot($form->{"licensenumber"}) . qq|\"></td>
      </tr>
      <tr>
        <th align=right>| . $locale->text('Own Product') . qq|</th>
        <td><input type=checkbox name=own_product value=1 checked></td>
      </tr>
    </table>

    <input type=submit name=action value=\"| . $locale->text('Update') . qq|\">
          |);

  if ($_[0]) {
    print(
      qq|&nbsp;
          <input type=submit name=action value=\"|
        . $locale->text('Save') . qq|\">\n|);
  }
  print(
    qq|
  </tr>

</table>| .
    $form->write_trigger(\%myconfig, 1, "validuntil", "BL",
                         "trigger_validuntil"));

  $lxdebug->leave_sub();
}

sub add {
  $lxdebug->enter_sub();

  $auth->assert('license_edit');

  if (!$lizenzen) {
    $form->error(
                 $locale->text(
                   'The licensing module has been deactivated in lx-erp.conf.')
    );
  }

  $form->{"initial"} = 1;

  do_add();
  $lxdebug->leave_sub();
}

sub do_add {
  $lxdebug->enter_sub();

  $auth->assert('license_edit');

  $form->{"hidden"} = ["parts_id"];
  form_header();

  if ($form->{"ndx"}) {
    $ndx = $form->{"ndx"};
    foreach (keys(%{$form})) {
      next unless (/^new_.*_${ndx}$/);
      s/^new_//;
      s/_${ndx}$//;
      $form->{$_} = $form->{"new_${_}_${ndx}"};
    }
  }

  if ($form->{"customer"}) {
    $form->{"customer_id"} = (split(/--/, $form->{"customer"}))[1];
  }

  if ($form->{"customer_name"}) {
    LICENSES->get_customers(\%myconfig, $form);
    if (scalar(@{ $form->{"all_customers"} }) == 1) {
      %c                       = %{ $form->{"all_customers"}->[0] };
      $form->{"customer_id"}   = $c{"id"};
      $form->{"customer_name"} = $c{"name"};
    } elsif (scalar(@{ $form->{"all_customers"} }) == 0) {
      $form->{"customer_name"} = "";
      delete($form->{"customer_id"});
    } else {
      print_customer_selection();
      return;
    }
  } elsif (defined($form->{"customer_name"})) {
    delete($form->{"customer_id"});
  }

  if ($form->{"partnumber"} || $form->{"description"}) {
    $form->{"sort"} = "p.partnumber";
    $form->{searchitems} = "part";
    IC->all_parts(\%myconfig, $form);
    if (scalar(@{ $form->{"parts"} }) == 1) {
      map({ $form->{$_} = $form->{"parts"}->[0]->{$_}; }
          ("partnumber", "description"));
      $form->{"parts_id"} = $form->{"parts"}->[0]->{"id"};

    } elsif (scalar(@{ $form->{"parts"} }) == 0) {
      map({ $form->{$_} = ""; }("partnumber", "description", "parts_id"));

    } else {
      print_part_selection();
      return;
    }
  } else {
    delete($form->{"parts_id"});
  }

  $form->all_vc(\%myconfig, "customer", "");

  print_license_form($form->{"parts_id"} && $form->{"customer_id"});

  form_footer();
  $lxdebug->leave_sub();
}

sub update {
  $lxdebug->enter_sub();

  $auth->assert('license_edit');

  do_add();

  $lxdebug->leave_sub();
}

sub continue {
  $lxdebug->enter_sub();
  call_sub($form->{"nextsub"});
  $lxdebug->leave_sub();
}

sub save {
  $lxdebug->enter_sub();

  $auth->assert('license_edit');

  ($form->{customername}, $form->{customer_id}) = split /--/,
    $form->{customer};

  $form->isblank("customer", $locale->text('Customer missing!'));

  if (   $form->{quantity} eq ""
      || $form->{quantity} !~ /^[0-9]*$/
      || $form->{quantity} < 1) {
    $form->error($locale->text('Please enter a number of licenses.'));
  }

  if (!$form->{licensenumber} || $form->{licensenumber} eq "") {
    $form->error($locale->text('Please enter a license key.'));
  }

  $rc = LICENSES->save_license(\%myconfig, \%$form);

  # load previous variables
  if ($form->{previousform}) {

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

    $form->{"lizenzen_$form->{row}"} =
      "<option value=$rc>$newform{licensenumber}</option>";
    $form->{rowcount}--;

    delete $form->{action};

    # restore original callback
    $callback = $form->unescape($form->{callback});
    $form->{callback} = $form->unescape($form->{old_callback});
    delete $form->{old_callback};

    # put callback together
    foreach $key (keys %$form) {
      next if (($key eq 'login') || ($key eq 'password') || ('' ne ref $form->{$key}));

      # do single escape for Apache 2.0
      $value = $form->escape($form->{$key}, 1);
      $callback .= qq|&$key=$value|;
    }
    $form->{callback} = $callback;

    # redirect
    $form->redirect;

  } else {
    form_header();

    print("Die Lizenz wurde gespeichert.\n");
    form_footer();
  }

  $lxdebug->leave_sub();
}

sub search {
  $lxdebug->enter_sub();

  $auth->assert('license_edit');

  if (!$lizenzen) {
    $form->error(
                 $locale->text(
                   'The licensing module has been deactivated in lx-erp.conf.')
    );
  }

  form_header();

  print(
    qq|
<table width=100%>
  <tr>
    <th class=listtop>| . $locale->text("Licenses") . qq|</th>
  </tr>
  <tr>
    <table>
      <tr>
        <th align=right>| . $locale->text('Part Number') . qq|</th>
        <td><input name=partnumber></td>
      </tr>
      <tr>
        <th align=right>| . $locale->text('Description') . qq|</th>
        <td><input name=description></td>
      </tr>
      <tr>
        <th align=right>| . $locale->text('Company Name') . qq|</th>
        <td><input name=customer_name></td>
      </tr>
      <tr>
        <th align=right>| . $locale->text('Include in Report') . qq|</th>
        <td><input type=radio name=all value=1 checked>|
      . $locale->text('All')
      . qq|&nbsp;<input type=radio name=all value=0>|
      . $locale->text('Expiring in x month(s)')
      . qq|&nbsp;<input size=4 name=expiring_in value="1"><br>
        <input type=checkbox name=show_expired value=1>|
      . $locale->text('Expired licenses') . qq|</td>
      </tr>
    </table>
  </tr>
  <tr><td colspan=4><hr size=3 noshade></td></tr>
</table>

<input type=hidden name=nextsub value=\"do_search\">
<input type=submit name=action value=\"| . $locale->text('Continue') . qq|\">

        |);

  form_footer();
  $lxdebug->leave_sub();
}

sub do_search {
  $lxdebug->enter_sub();

  $auth->assert('license_edit');

  LICENSES->search(\%myconfig, $form);

  $callback = "";
  map { $callback .= "\&${_}=" . $form->escape($form->{$_}, 1) }
    qw(db partnumber description customer_name all expiring_in show_expired);
  $details    = $form->{"script"} . "?action=details" . $callback . "\&id=";
  $invdetails = "is.pl?action=edit" . $callback . "\&id=";
  $callback   = $form->{"script"} . "?action=do_search" . $callback;

  $form->{"sortby"} = "validuntil" unless ($form->{"sortby"});
  $form->{"sortasc"} *= 1;
  foreach (("partnumber", "description", "name", "validuntil", "invnumber")) {
    $columns{$_} = $callback . "\&sortby=${_}\&sortasc=";
    if ($form->{"sortby"} eq $_) {
      $columns{$_} .= (1 - $form->{"sortasc"});
    } else {
      $columns{$_} .= "1";
    }
  }

  form_header();

  print(
    qq|
<table width=100%>
  <tr>
    <th class=listtop>| . $locale->text("Licenses") . qq|</th>
  </tr>
        |);
  if (scalar(@{ $form->{"licenses"} }) == 0) {
    print(qq|</table>|
            . $locale->text(
                      "No licenses were found that match the search criteria.")
            . qq|</body></html>|);
    exit(0);
  }

  print(
    qq|
  <tr>
    <table>
      <tr>
        <th class=listtop><a class=listheading href=\"|
      . $columns{"partnumber"} . "\">"
      . $locale->text('Part Number')
      . qq|</a></th>
        <th class=listtop><a class=listheading href=\"|
      . $columns{"description"} . "\">"
      . $locale->text('Description')
      . qq|</a></th>
        <th class=listtop><a class=listheading href=\"|
      . $columns{"name"} . "\">" . $locale->text('Company Name') . qq|</a></th>
        <th class=listtop><a class=listheading href=\"|
      . $columns{"validuntil"} . "\">"
      . $locale->text('Valid until')
      . qq|</a></th>
        <th class=listtop><a class=listheading href=\"|
      . $columns{"invnumber"} . "\">"
      . $locale->text('Invoice Number')
      . qq|</a></th>
      </tr>
        |);

  $j = 1;
  for ($i = 0; $i < scalar(@{ $form->{"licenses"} }); $i++) {
    $ref = $form->{"licenses"}->[$i];
    print(
      qq|
          <tr class=listrow$j>
          <td><input type=hidden name=id_$i value=| . $ref->{"id"} . qq|
          <a href=\"${details}$ref->{"id"}\">$ref->{"partnumber"}</a></td>
          <td><a href=\"${details}$ref->{"id"}\">$ref->{"description"}</a></td>
          <td><a href=\"${details}$ref->{"id"}\">$ref->{"name"}</a></td>
          <td><a href=\"${details}$ref->{"id"}\">$ref->{"validuntil"}</a></td>
          <td align=right>|
        . (
        $ref->{"invnumber"}
        ? qq|<a href=\"${invdetails}$ref->{"invnumber"}\">$ref->{"invnumber"}</a>|
        : qq|&nbsp;|
        )
        . qq|</td>
          </tr>|);
    $j = ($j + 1) % 2;
  }

  $form->{"num_licenses"} = scalar(@{ $form->{"licenses"} });
  push(@{ $form->{"hidden"} }, "num_licenses");

  print(
    qq|
    </table>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<p>

<input type=submit name=action value=\"| . $locale->text("Add") . qq|\">
        |);

  form_footer();
  $lxdebug->leave_sub();
}

sub details {
  $lxdebug->enter_sub();

  $auth->assert('license_edit');

  LICENSES->get_license(\%myconfig, $form);
  map(
    { $form->{$_} = $form->{"license"}->{$_}; } keys(%{ $form->{"license"} }));

  form_header();

  print(
    qq|
<table width=100%>
  <tr>
    <th class=listtop>| . $locale->text("View License") . qq|</th>
  </tr>
  <tr>
    <table>
      <tr>
        <th align=right>| . $locale->text('Part Number') . qq|</th>
        <td>$form->{"partnumber"}</td>
      </tr>
      <tr>
        <th align=right>| . $locale->text('Description') . qq|</th>
        <td>$form->{"description"}</td>
      </tr>
      <tr>
        <th align=right>| . $locale->text('Company Name') . qq|</th>
        <td>$form->{"name"}</td>
      </tr>
      <tr>
        <th align=right>| . $locale->text('Comment') . qq|</th>
        <td>$form->{"comment"}</td>
      </tr>
      <tr>
        <th align=right>| . $locale->text('Valid until') . qq|</th>
        <td>$form->{"validuntil"}</td>
      </tr>
      <tr>
        <th align=right>| . $locale->text('Quantity') . qq|</th>
        <td>$form->{"quantity"}</td>
      </tr>
      <tr>
        <th align=right>| . $locale->text('License key') . qq|</th>
        <td>$form->{"licensenumber"}</td>
      </tr>
    </table>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<input type=submit name=action value=\"| . $locale->text("Add") . qq|\">
        |);

  form_footer();
  $lxdebug->leave_sub();
}

1;
