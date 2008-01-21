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
# partsgroup, pricegroup administration
#
#======================================================================

use SL::PE;

require "bin/mozilla/common.pl";

1;

# end of main

sub add {
  $lxdebug->enter_sub();

  $auth->assert('config');

  $form->{title} = "Add";

  # construct callback
  $form->{callback} =
    "$form->{script}?action=add&type=$form->{type}"
    unless $form->{callback};

  call_sub("form_$form->{type}_header");
  call_sub("form_$form->{type}_footer");

  $lxdebug->leave_sub();
}

sub edit {
  $lxdebug->enter_sub();

  $auth->assert('config');

  # show history button
  $form->{javascript} = qq|<script type="text/javascript" src="js/show_history.js"></script>|;
  #/show hhistory button
  $form->{title} = "Edit";

  if ($form->{type} eq 'partsgroup') {
    PE->get_partsgroup(\%myconfig, \%$form);
  }
  if ($form->{type} eq 'pricegroup') {
    PE->get_pricegroup(\%myconfig, \%$form);
  }
  call_sub("form_$form->{type}_header");
  call_sub("form_$form->{type}_footer");

  $lxdebug->leave_sub();
}

sub search {
  $lxdebug->enter_sub();

  $auth->assert('config');

  if ($form->{type} eq 'partsgroup') {
    $report        = "partsgroup_report";
    $sort          = 'partsgroup';
    $form->{title} = $locale->text('Groups');

    $number = qq|
	<tr>
	  <th align=right width=1%>| . $locale->text('Group') . qq|</th>
	  <td><input name=partsgroup size=20></td>
	</tr>
|;

  }

  # for pricesgroups
  if ($form->{type} eq 'pricegroup') {
    $report        = "pricegroup_report";
    $sort          = 'pricegroup';
    $form->{title} = $locale->text('Pricegroup');

    $number = qq|
	<tr>
	  <th align=right width=1%>| . $locale->text('Pricegroup') . qq|</th>
	  <td><input name=pricegroup size=20></td>
	</tr>
|;

  }

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=sort value=$sort>
<input type=hidden name=type value=$form->{type}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
        $number
	<tr>
	  <td></td>
	  <td><input name=status class=radio type=radio value=all checked>&nbsp;|
    . $locale->text('All') . qq|
	  <input name=status class=radio type=radio value=orphaned>&nbsp;|
    . $locale->text('Orphaned') . qq|</td>
	</tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<input type=hidden name=nextsub value=$report>

<br>
<input class=submit type=submit name=action value="|
    . $locale->text('Continue') . qq|">
</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub save {
  $lxdebug->enter_sub();

  $auth->assert('config');

  if ($form->{type} eq 'partsgroup') {
    $form->isblank("partsgroup", $locale->text('Group missing!'));
    PE->save_partsgroup(\%myconfig, \%$form);
    $form->redirect($locale->text('Group saved!'));
  }

  # choice pricegroup and save
  if ($form->{type} eq 'pricegroup') {
    $form->isblank("pricegroup", $locale->text('Pricegroup missing!'));
    PE->save_pricegroup(\%myconfig, \%$form);
    $form->redirect($locale->text('Pricegroup saved!'));
  }
  # saving the history
  if(!exists $form->{addition} && $form->{id} ne "") {
    $form->{snumbers} = qq|projectnumber_| . $form->{projectnumber};
  	$form->{addition} = "SAVED";
  	$form->save_history($form->dbconnect(\%myconfig));
  }
  # /saving the history 

  $lxdebug->leave_sub();
}

sub delete {
  $lxdebug->enter_sub();

  $auth->assert('config');

  PE->delete_tuple(\%myconfig, \%$form);

  if ($form->{type} eq 'partsgroup') {
    $form->redirect($locale->text('Group deleted!'));
  }
  if ($form->{type} eq 'pricegroup') {
    $form->redirect($locale->text('Pricegroup deleted!'));
  }
  # saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers} = qq|projectnumber_| . $form->{projectnumber};
  	$form->{addition} = "DELETED";
  	$form->save_history($form->dbconnect(\%myconfig));
  }
  # /saving the history
  $lxdebug->leave_sub();
}

sub continue { call_sub($form->{"nextsub"}); }

sub partsgroup_report {
  $lxdebug->enter_sub();

  $auth->assert('config');

  map { $form->{$_} = $form->unescape($form->{$_}) } (partsgroup);
  PE->partsgroups(\%myconfig, \%$form);

  $callback =
    "$form->{script}?action=partsgroup_report&type=$form->{type}&status=$form->{status}";

  if ($form->{status} eq 'all') {
    $option = $locale->text('All');
  }
  if ($form->{status} eq 'orphaned') {
    $option .= $locale->text('Orphaned');
  }
  if ($form->{partsgroup}) {
    $callback .= "&partsgroup=$form->{partsgroup}";
    $option   .= "\n<br>" . $locale->text('Group') . " : $form->{partsgroup}";
  }

  @column_index = $form->sort_columns(qw(partsgroup));

  $column_header{partsgroup} =
    qq|<th class=listheading width=90%>| . $locale->text('Group') . qq|</th>|;

  $form->{title} = $locale->text('Groups');

  $form->header;

  print qq|
<body>

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

  map { print "$column_header{$_}\n" } @column_index;

  print qq|
        </tr>
|;

  # escape callback
  $form->{callback} = $callback;

  # escape callback for href
  $callback = $form->escape($callback);

  foreach $ref (@{ $form->{item_list} }) {

    $i++;
    $i %= 2;

    print qq|
        <tr valign=top class=listrow$i>
|;

    $column_data{partsgroup} =
      qq|<td><a href=$form->{script}?action=edit&type=$form->{type}&status=$form->{status}&id=$ref->{id}&callback=$callback>$ref->{partsgroup}</td>|;
    map { print "$column_data{$_}\n" } @column_index;

    print "
        </tr>
";
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

<input type=hidden name=type value=$form->{type}>

<input class=submit type=submit name=action value="|
    . $locale->text('Add') . qq|">

  </form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub form_partsgroup_header {
  $lxdebug->enter_sub();

  $auth->assert('config');

  $form->{title} = $locale->text("$form->{title} Group");

  # $locale->text('Add Group')
  # $locale->text('Edit Group')

  $form->{partsgroup} =~ s/\"/&quot;/g;

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{id}>
<input type=hidden name=type value=$form->{type}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
	<tr>
	  <th align=right>| . $locale->text('Group') . qq|</th>

          <td><input name=partsgroup size=30 value="$form->{partsgroup}"></td>
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

sub form_partsgroup_footer {
  $lxdebug->enter_sub();

  $auth->assert('config');

  print qq|

<input name=callback type=hidden value="$form->{callback}">

<br><input type=submit class=submit name=action value="|
    . $locale->text('Save') . qq|">
|;

  if ($form->{id} && $form->{orphaned}) {
    print qq|
<input type=submit class=submit name=action value="|
      . $locale->text('Delete') . qq|">|;
  }

# button for saving history
print qq|
  	<input type=button onclick=set_history_window(|
  	. $form->{id} 
  	. qq|); name=history id=history value=|
  	. $locale->text('history') 
  	. qq|>|;
# /button for saving history
  print qq|
</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

#################################
# get pricesgroups and build up html-code
#
sub pricegroup_report {
  $lxdebug->enter_sub();

  $auth->assert('config');

  map { $form->{$_} = $form->unescape($form->{$_}) } (pricegroup);
  PE->pricegroups(\%myconfig, \%$form);

  $callback =
    "$form->{script}?action=pricegroup_report&type=$form->{type}&status=$form->{status}";

  if ($form->{status} eq 'all') {
    $option = $locale->text('All');
  }
  if ($form->{status} eq 'orphaned') {
    $option .= $locale->text('Orphaned');
  }
  if ($form->{pricegroup}) {
    $callback .= "&pricegroup=$form->{pricegroup}";
    $option   .=
      "\n<br>" . $locale->text('Pricegroup') . " : $form->{pricegroup}";
  }

  @column_index = $form->sort_columns(qw(pricegroup));

  $column_header{pricegroup} =
      qq|<th class=listheading width=90%>|
    . $locale->text('Pricegroup')
    . qq|</th>|;

  $form->{title} = $locale->text('Pricegroup');

  $form->header;

  print qq|
<body>

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

  map { print "$column_header{$_}\n" } @column_index;

  print qq|
        </tr>
|;

  # escape callback
  $form->{callback} = $callback;

  # escape callback for href
  $callback = $form->escape($callback);

  foreach $ref (@{ $form->{item_list} }) {

    $i++;
    $i %= 2;

    print qq|
        <tr valign=top class=listrow$i>
|;
    $column_data{pricegroup} =
      qq|<td><a href=$form->{script}?action=edit&type=$form->{type}&status=$form->{status}&id=$ref->{id}&callback=$callback>$ref->{pricegroup}</td>|;

    map { print "$column_data{$_}\n" } @column_index;

    print "
        </tr>
";
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

<input type=hidden name=type value=$form->{type}>

<input class=submit type=submit name=action value="|
    . $locale->text('Add') . qq|">

  </form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

#######################
#build up pricegroup_header
#
sub form_pricegroup_header {
  $lxdebug->enter_sub();

  $auth->assert('config');

  # $locale->text('Add Pricegroup')
  # $locale->text('Edit Pricegroup')

  $form->{title} = $locale->text("$form->{title} Pricegroup");

  $form->{pricegroup} =~ s/\"/&quot;/g;

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{id}>
<input type=hidden name=type value=$form->{type}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table width=100%>
	<tr>
	  <th align=right>| . $locale->text('Preisgruppe') . qq|</th>
          <td><input name=pricegroup size=30 value="$form->{pricegroup}"></td>
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
######################
#build up pricegroup_footer
#
sub form_pricegroup_footer {
  $lxdebug->enter_sub();

  $auth->assert('config');

  print qq|

<input name=callback type=hidden value="$form->{callback}">

<br><input type=submit class=submit name=action value="|
    . $locale->text('Save') . qq|">
|;

  if ($form->{id} && $form->{orphaned}) {
    print qq|
<input type=submit class=submit name=action value="|
      . $locale->text('Delete') . qq|">|;
  }

# button for saving history
print qq|
  	<input type=button onclick=set_history_window(|
  	. $form->{id} 
  	. qq|); name=history id=history value=|
  	. $locale->text('history') 
  	. qq|>|;
# /button for saving history
  print qq|
</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}
