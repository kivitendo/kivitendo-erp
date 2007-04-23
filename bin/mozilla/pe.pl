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
# project administration
# partsgroup administration
#
#======================================================================

use SL::PE;

require "bin/mozilla/common.pl";

1;

# end of main

sub add {
  $lxdebug->enter_sub();

  $form->{title} = "Add";

  # construct callback
  $form->{callback} =
    "$form->{script}?action=add&type=$form->{type}&path=$form->{path}&login=$form->{login}&password=$form->{password}"
    unless $form->{callback};

  call_sub("form_$form->{type}_header");
  call_sub("form_$form->{type}_footer");

  $lxdebug->leave_sub();
}

sub edit {
  $lxdebug->enter_sub();
  # show history button
  $form->{javascript} = qq|<script type="text/javascript" src="js/show_history.js"></script>|;
  #/show hhistory button
  $form->{title} = "Edit";

  if ($form->{type} eq 'project') {
    PE->get_project(\%myconfig, \%$form);
  }
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

  if ($form->{type} eq 'project') {
    $report        = "project_report";
    $sort          = 'projectnumber';
    $form->{title} = $locale->text('Projects');

    $number = qq|
	<tr>
	  <th align=right width=1%>| . $locale->text('Number') . qq|</th>
	  <td>| . $cgi->textfield('-name' => 'projectnumber', '-size' => 20) . qq|</td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Description') . qq|</th>
	  <td>| . $cgi->textfield('-name' => 'description', '-size' => 60) . qq|</td>
	</tr>
  <tr>
    <th>&nbsp;</th>
    <td>| .
    $cgi->radio_group('-name' => 'active', '-default' => 'active',
                      '-values' => ['active', 'inactive', 'both'],
                      '-labels' => { 'active' => ' ' . $locale->text("Active"),
                                     'inactive' => ' ' . $locale->text("Inactive"),
                                     'both' => ' ' . $locale->text("Both") })
    . qq|</td>
  </tr>
|;

  }
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

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<br>
<input class=submit type=submit name=action value="|
    . $locale->text('Continue') . qq|">
</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub project_report {
  $lxdebug->enter_sub();

  map { $form->{$_} = $form->unescape($form->{$_}) }
    (projectnumber, description);
  PE->projects(\%myconfig, \%$form);

  $callback =
    "$form->{script}?action=project_report&type=$form->{type}&path=$form->{path}&login=$form->{login}&password=$form->{password}&status=$form->{status}&active=" .
    E($form->{active});
  $href = $callback;

  if ($form->{status} eq 'all') {
    $option = $locale->text('All');
  }
  if ($form->{status} eq 'orphaned') {
    $option .= $locale->text('Orphaned');
  }
  if ($form->{projectnumber}) {
    $href     .= "&projectnumber=" . $form->escape($form->{projectnumber});
    $callback .= "&projectnumber=$form->{projectnumber}";
    $option   .=
      "\n<br>" . $locale->text('Project') . " : $form->{projectnumber}";
  }
  if ($form->{description}) {
    $href     .= "&description=" . $form->escape($form->{description});
    $callback .= "&description=$form->{description}";
    $option   .=
      "\n<br>" . $locale->text('Description') . " : $form->{description}";
  }

  @column_index = qw(projectnumber description);

  push(@column_index, "active") if ("both" eq $form->{active});

  $column_header{projectnumber} =
      qq|<th><a class=listheading href=$href&sort=projectnumber>|
    . $locale->text('Number')
    . qq|</a></th>|;
  $column_header{description} =
      qq|<th><a class=listheading href=$href&sort=description>|
    . $locale->text('Description')
    . qq|</a></th>|;
  $column_header{active} =
      qq|<th class="listheading">| . $locale->text('Active') . qq|</th>|;

  $form->{title} = $locale->text('Projects');

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
  $form->{callback} = $callback .= "&sort=$form->{sort}";

  # escape callback for href
  $callback = $form->escape($callback);

  foreach $ref (@{ $form->{project_list} }) {

    $i++;
    $i %= 2;

    print qq|
        <tr valign=top class=listrow$i>
|;

    $column_data{projectnumber} =
      qq|<td><a href=$form->{script}?action=edit&type=$form->{type}&status=$form->{status}&id=$ref->{id}&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback>$ref->{projectnumber}</td>|;
    $column_data{description} = qq|<td>$ref->{description}&nbsp;</td>|;
    $column_data{active} =
      qq|<td>| .
      ($ref->{active} ? $locale->text("Yes") : $locale->text("No")) .
      qq|</td>|;

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

<input type=hidden name=path value=$form->{path}>
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

sub form_project_header {
  $lxdebug->enter_sub();

  $form->{title} = $locale->text("$form->{title} Project");

  # $locale->text('Add Project')
  # $locale->text('Edit Project')

  $form->{description} =~ s/\"/&quot;/g;

  my $projectnumber =
    $cgi->textfield('-name' => 'projectnumber', '-size' => 20,
                    '-default' => $form->{projectnumber});

  my $description;
  if (($rows = $form->numtextrows($form->{description}, 60)) > 1) {
    $description =
      $cgi->textarea('-name' => 'description', '-rows' => $rows, '-cols' => 60,
                     '-style' => 'width: 100%', '-wrap' => 'soft',
                     '-default' => $form->{description});
  } else {
    $description =
      $cgi->textfield('-name' => 'description', '-size' => 60,
                      '-default' => $form->{description});
  }

  my $active;
  if ($form->{id}) {
    $active =
      qq|
  <tr>
    <th>&nbsp;</th>
    <td>| .
      $cgi->radio_group('-name' => 'active',
                        '-values' => [1, 0],
                        '-default' => $form->{active} * 1,
                        '-labels' => { 1 => $locale->text("Active"),
                                       0 => $locale->text("Inactive") })
      . qq|</td>
  </tr>
|;
  }

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<input type=hidden name=id value=$form->{id}>
<input type=hidden name=type value=project>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
	<tr>
	  <th align=right>| . $locale->text('Number') . qq|</th>
	  <td>$projectnumber</td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Description') . qq|</th>
	  <td>$description</td>
	</tr>
      $active
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

sub form_project_footer {
  $lxdebug->enter_sub();

  print qq|

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

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

sub save {
  $lxdebug->enter_sub();

  if ($form->{type} eq 'project') {
    $form->isblank("projectnumber", $locale->text('Project Number missing!'));
    PE->save_project(\%myconfig, \%$form);
    $form->redirect($locale->text('Project saved!'));
  }
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

  PE->delete_tuple(\%myconfig, \%$form);

  if ($form->{type} eq 'project') {
    $form->redirect($locale->text('Project deleted!'));
  }
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

  map { $form->{$_} = $form->unescape($form->{$_}) } (partsgroup);
  PE->partsgroups(\%myconfig, \%$form);

  $callback =
    "$form->{script}?action=partsgroup_report&type=$form->{type}&path=$form->{path}&login=$form->{login}&password=$form->{password}&status=$form->{status}";

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
      qq|<td><a href=$form->{script}?action=edit&type=$form->{type}&status=$form->{status}&id=$ref->{id}&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback>$ref->{partsgroup}</td>|;
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

<input type=hidden name=path value=$form->{path}>
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

sub form_partsgroup_header {
  $lxdebug->enter_sub();

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

  print qq|

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

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

  map { $form->{$_} = $form->unescape($form->{$_}) } (pricegroup);
  PE->pricegroups(\%myconfig, \%$form);

  $callback =
    "$form->{script}?action=pricegroup_report&type=$form->{type}&path=$form->{path}&login=$form->{login}&password=$form->{password}&status=$form->{status}";

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
      qq|<td><a href=$form->{script}?action=edit&type=$form->{type}&status=$form->{status}&id=$ref->{id}&path=$form->{path}&login=$form->{login}&password=$form->{password}&callback=$callback>$ref->{pricegroup}</td>|;

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

<input type=hidden name=path value=$form->{path}>
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

#######################
#build up pricegroup_header
#
sub form_pricegroup_header {
  $lxdebug->enter_sub();

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

  print qq|

<input name=callback type=hidden value="$form->{callback}">

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

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
