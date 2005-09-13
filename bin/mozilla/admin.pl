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
# setup module
# add/edit/delete users
#
#======================================================================

$menufile = "menu.ini";

use SL::Form;
use SL::User;

$form = new Form;

$locale = new Locale $language, "admin";

eval { require DBI; };
$form->error($locale->text('DBI not installed!')) if ($@);

# customization
if (-f "$form->{path}/custom_$form->{script}") {
  eval { require "$form->{path}/custom_$form->{script}"; };
  $form->error($@) if ($@);
}

$form->{stylesheet} = "lx-office-erp.css";
$form->{favicon}    = "favicon.ico";

if ($form->{action}) {

  $subroutine = $locale->findsub($form->{action});

  if ($subroutine eq 'login') {
    if ($form->{rpw}) {
      $form->{rpw} = crypt $form->{rpw}, "ro";
    }
  }

  &check_password;

  &$subroutine;

} else {

  # if there are no drivers bail out
  $form->error($locale->text('No Database Drivers available!'))
    unless (User->dbdrivers);

  # create memberfile
  if (!-f $memberfile) {
    open(FH, ">$memberfile") or $form->error("$memberfile : $!");
    print FH qq|# SQL-Ledger Accounting members

[root login]
password=

|;
    close FH;
  }

  &adminlogin;

}

1;

# end

sub adminlogin {

  $form->{title} =
    qq|Lx-Office ERP $form->{version} | . $locale->text('Administration');

  $form->header;

  print qq|
<body class=admin>


<div align=center>

<a href="http://www.lx-office.org"><img src="image/lx-office-erp.png" border=0></a>
<h1 class=login>|
    . $locale->text('Version')
    . qq| $form->{version}<p>|
    . $locale->text('Administration')
    . qq|</h1>

<form method=post action="$form->{script}">

<table>
  <tr>
    <th>| . $locale->text('Password') . qq|</th>
    <td><input type=password name=rpw></td>
    <td><input type=submit class=submit name=action value="|
    . $locale->text('Login')
    . qq|"></td>
  </tr>
<input type=hidden name=action value=login>
<input type=hidden name=root value="root login">
<input type=hidden name=path value=$form->{path}>
</table>


</form>

<a href=http://www.lx-office.org>Lx-Office |
    . $locale->text('website') . qq|</a>

</div>

</body>
</html>
|;

}

sub login {

  &list_users;

}

sub add_user {

  $form->{title} =
      "Lx-Office ERP "
    . $locale->text('Administration') . " / "
    . $locale->text('Add User');

  $form->{Oracle_sid}    = $sid;
  $form->{Oracle_dbport} = '1521';
  $form->{Oracle_dbhost} = `hostname`;

  if (-f "css/lx-office-erp.css") {
    $myconfig->{stylesheet} = "lx-office-erp.css";
  }
  $myconfig->{vclimit} = 200;

  &form_header;
  &form_footer;

}

sub edit {

  $form->{title} =
      "Lx-Office ERP "
    . $locale->text('Administration') . " / "
    . $locale->text('Edit User');
  $form->{edit} = 1;

  &form_header;
  &form_footer;

}

sub form_footer {

  if ($form->{edit}) {
    $delete =
      qq|<input type=submit class=submit name=action value="|
      . $locale->text('Delete') . qq|">
<input type=hidden name=edit value=1>|;
  }

  print qq|

<input name=callback type=hidden value="$form->{script}?action=list_users&path=$form->{path}&root=$form->{root}&rpw=$form->{rpw}">
<input type=hidden name=root value="$form->{root}">
<input type=hidden name=path value=$form->{path}>
<input type=hidden name=rpw value=$form->{rpw}>

<input type=submit class=submit name=action value="|
    . $locale->text('Save') . qq|">
$delete

</form>

</body>
</html>
|;

}

sub list_users {

  $form->error($locale->text('File locked!')) if (-f "${memberfile}.LCK");

  open(FH, "$memberfile") or $form->error("$memberfile : $!");

  $nologin = qq|
<input type=submit class=submit name=action value="|
    . $locale->text('Lock System') . qq|">|;

  if (-e "$userspath/nologin") {
    $nologin = qq|
<input type=submit class=submit name=action value="|
      . $locale->text('Unlock System') . qq|">|;
  }

  while (<FH>) {
    chop;

    if (/^\[.*\]/) {
      $login = $_;
      $login =~ s/(\[|\])//g;
    }

    if (/^(name=|company=|templates=|dbuser=|dbdriver=|dbname=|dbhost=)/) {
      chop($var = $&);
      ($null, $member{$login}{$var}) = split /=/, $_, 2;
    }
  }

  close(FH);

  # type=submit $locale->text('Pg Database Administration')
  # type=submit $locale->text('Oracle Database Administration')

  foreach $item (User->dbdrivers) {
    $dbdrivers .=
      qq|<input name=action type=submit class=submit value="|
      . $locale->text("$item Database Administration") . qq|">|;
  }

  $column_header{login}     = qq|<th>| . $locale->text('Login') . qq|</th>|;
  $column_header{name}      = qq|<th>| . $locale->text('Name') . qq|</th>|;
  $column_header{company}   = qq|<th>| . $locale->text('Company') . qq|</th>|;
  $column_header{dbdriver}  = qq|<th>| . $locale->text('Driver') . qq|</th>|;
  $column_header{dbhost}    = qq|<th>| . $locale->text('Host') . qq|</th>|;
  $column_header{dataset}   = qq|<th>| . $locale->text('Dataset') . qq|</th>|;
  $column_header{templates} =
    qq|<th>| . $locale->text('Templates') . qq|</th>|;

  @column_index = qw(login name company dbdriver dbhost dataset templates);

  $form->{title} = "Lx-Office ERP " . $locale->text('Administration');

  $form->header;

  print qq|
<body class=admin>

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
  <tr class=listheading>
    <th>$form->{title}</th>
  </tr>
  <tr size=5></tr>
  <tr>
    <td>
      <table width=100%>
        <tr class=listheading>|;

  map { print "$column_header{$_}\n" } @column_index;

  print qq|
        </tr>
|;

  foreach $key (sort keys %member) {
    $href =
      "$script?action=edit&login=$key&path=$form->{path}&root=$form->{root}&rpw=$form->{rpw}";
    $href =~ s/ /%20/g;

    $member{$key}{templates} =~ s/^$templates\///;
    $member{$key}{dbhost} = $locale->text('localhost')
      unless $member{$key}{dbhost};
    $member{$key}{dbname} = $member{$key}{dbuser}
      if ($member{$key}{dbdriver} eq 'Oracle');

    $column_data{login}     = qq|<td><a href=$href>$key</a></td>|;
    $column_data{name}      = qq|<td>$member{$key}{name}</td>|;
    $column_data{company}   = qq|<td>$member{$key}{company}</td>|;
    $column_data{dbdriver}  = qq|<td>$member{$key}{dbdriver}</td>|;
    $column_data{dbhost}    = qq|<td>$member{$key}{dbhost}</td>|;
    $column_data{dataset}   = qq|<td>$member{$key}{dbname}</td>|;
    $column_data{templates} = qq|<td>$member{$key}{templates}</td>|;

    $i++;
    $i %= 2;
    print qq|
        <tr class=listrow$i>|;

    map { print "$column_data{$_}\n" } @column_index;

    print qq|
        </tr>|;
  }

  print qq|
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=rpw value=$form->{rpw}>
<input type=hidden name=root value="$form->{root}">

<br><input type=submit class=submit name=action value="|
    . $locale->text('Add User') . qq|">
<input type=submit class=submit name=action value="|
    . $locale->text('Change Admin Password') . qq|">

$dbdrivers
$nologin

</form>

| . $locale->text('Click on login name to edit!') . qq|
<br>
|
    . $locale->text(
    'To add a user to a group edit a name, change the login name and save.  A new user with the same variables will then be saved under the new login name.'
    )
    . qq|

<p>

<form method=post action=login.pl>

<table border=0 width=100%>
  <tr class=listheading>
    <th>Lx-Office ERP | . $locale->text('Login') . qq|</th>
  </tr>
  <tr>
    <td>
      <table>
        <tr>
	  <th align=right>| . $locale->text('Name') . qq|</th>
	  <td><input class=login name=login></td>
	  <td>&nbsp;</td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Password') . qq|</th>
	  <td><input class=login type=password name=password></td>
	  <td><input type=submit name=action value="|
    . $locale->text('Login')
    . qq|"></td>
	</tr>
<input type=hidden name=path value=$form->{path}>
      </table>
    </td>
  </tr>
</table>

</form>

<hr size=3 noshade>

</body>
</html>
|;

}

sub form_header {

  # if there is a login, get user
  if ($form->{login}) {

    # get user
    $myconfig = new User "$memberfile", "$form->{login}";

    $myconfig->{signature} =~ s/\\n/\r\n/g;
    $myconfig->{address}   =~ s/\\n/\r\n/g;

    # strip basedir from templates directory
    $myconfig->{templates} =~ s/^$templates\///;

    # $myconfig->{dbpasswd} = unpack 'u', $myconfig->{dbpasswd};
  }

  foreach $item (qw(mm-dd-yy mm/dd/yy dd-mm-yy dd/mm/yy dd.mm.yy yyyy-mm-dd)) {
    $dateformat .=
      ($item eq $myconfig->{dateformat})
      ? "<option selected>$item\n"
      : "<option>$item\n";
  }

  foreach $item (qw(1,000.00 1000.00 1.000,00 1000,00)) {
    $numberformat .=
      ($item eq $myconfig->{numberformat})
      ? "<option selected>$item\n"
      : "<option>$item\n";
  }

  %countrycodes = User->country_codes;
  $countrycodes = "";
  foreach $key (sort { $countrycodes{$a} cmp $countrycodes{$b} }
                keys %countrycodes) {
    $countrycodes .=
      ($myconfig->{countrycode} eq $key)
      ? "<option selected value=$key>$countrycodes{$key}"
      : "<option value=$key>$countrycodes{$key}";
  }
  $countrycodes = qq|<option value="">American English\n$countrycodes|;

  # is there a templates basedir
  if (!-d "$templates") {
    $form->error(  $locale->text('Directory')
                 . ": $templates "
                 . $locale->text('does not exist'));
  }

  opendir TEMPLATEDIR, "$templates/." or $form->error("$templates : $!");
  @all = grep !/^\.\.?$/, readdir TEMPLATEDIR;
  closedir TEMPLATEDIR;

  @allhtml = sort grep /\.html/, @all;
  @alldir = grep !/\.(html|tex)$/, @all;

  @allhtml = reverse grep !/Default/, @allhtml;
  push @allhtml, 'Default';
  @allhtml = reverse @allhtml;

  foreach $item (@alldir) {
    if ($item eq $myconfig->{templates}) {
      $usetemplates .= qq|<option selected>$item\n|;
    } else {
      $usetemplates .= qq|<option>$item\n|;
    }
  }

  $lastitem = $allhtml[0];
  $lastitem =~ s/-.*//g;
  $mastertemplates = qq|<option>$lastitem\n|;
  foreach $item (@allhtml) {
    $item =~ s/-.*//g;

    if ($item ne $lastitem) {
      $mastertemplates .= qq|<option>$item\n|;
      $lastitem = $item;
    }
  }

  opendir CSS, "css/.";
  @all = grep /.*\.css$/, readdir CSS;
  closedir CSS;

  foreach $item (@all) {
    if ($item eq $myconfig->{stylesheet}) {
      $selectstylesheet .= qq|<option selected>$item\n|;
    } else {
      $selectstylesheet .= qq|<option>$item\n|;
    }
  }
  $selectstylesheet .= "<option>\n";

  $form->header;

  print qq|
<body class=admin>

<form method=post action=$form->{script}>

<table width=100%>
  <tr class=listheading><th colspan=2>$form->{title}</th></tr>
  <tr size=5></tr>
  <tr valign=top>
    <td>
      <table>
	<tr>
	  <th align=right>| . $locale->text('Login') . qq|</th>
	  <td><input name=login value="$myconfig->{login}"></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Password') . qq|</th>
	  <td><input type=password name=password size=8 value=$myconfig->{password}></td>
	  <input type=hidden name=old_password value=$myconfig->{password}>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Name') . qq|</th>
	  <td><input name=name size=15 value="$myconfig->{name}"></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('E-mail') . qq|</th>
	  <td><input name=email size=30 value="$myconfig->{email}"></td>
	</tr>
	<tr valign=top>
	  <th align=right>| . $locale->text('Signature') . qq|</th>
	  <td><textarea name=signature rows=3 cols=35>$myconfig->{signature}</textarea></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Phone') . qq|</th>
	  <td><input name=tel size=14 value="$myconfig->{tel}"></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Fax') . qq|</th>
	  <td><input name=fax size=14 value="$myconfig->{fax}"></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Company') . qq|</th>
	  <td><input name=company size=35 value="$myconfig->{company}"></td>
	</tr>
	<tr valign=top>
	  <th align=right>| . $locale->text('Address') . qq|</th>
	  <td><textarea name=address rows=4 cols=35>$myconfig->{address}</textarea></td>
	</tr>
        <tr valign=top>
	  <th align=right>| . $locale->text('Steuernummer') . qq|</th>
	  <td><input name=steuernummer size=14 value="$myconfig->{steuernummer}"></td>
	</tr>
        <tr valign=top>
	  <th align=right>| . $locale->text('Ust-IDNr') . qq|</th>
	  <td><input name=ustid size=14 value="$myconfig->{ustid}"></td>
	</tr>
        <tr valign=top>
	  <th align=right>| . $locale->text('DUNS-Nr') . qq|</th>
	  <td><input name=duns size=14 value="$myconfig->{duns}"></td>
	</tr>
      </table>
    </td>
    <td>
      <table>
	<tr>
	  <th align=right>| . $locale->text('Date Format') . qq|</th>
	  <td><select name=dateformat>$dateformat</select></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Number Format') . qq|</th>
	  <td><select name=numberformat>$numberformat</select></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Dropdown Limit') . qq|</th>
	  <td><input name=vclimit value="$myconfig->{vclimit}"></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Language') . qq|</th>
	  <td><select name=countrycode>$countrycodes</select></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Character Set') . qq|</th>
	  <td><input name=charset value="$myconfig->{charset}"></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Stylesheet') . qq|</th>
	  <td><select name=userstylesheet>$selectstylesheet</select></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Printer') . qq|</th>
	  <td><input name=printer size=20 value="$myconfig->{printer}"></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Use Templates') . qq|</th>
	  <td><select name=usetemplates>$usetemplates</select></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('New Templates') . qq|</th>
	  <td><input name=newtemplates></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Setup Templates') . qq|</th>
	  <td><select name=mastertemplates>$mastertemplates</select></td>
	</tr>
	<input type=hidden name=templates value=$myconfig->{templates}>
      </table>
    </td>
  </tr>
  <tr class=listheading>
    <th colspan=2>| . $locale->text('Database') . qq|</th>
  </tr>|;

  # list section for database drivers
  foreach $item (User->dbdrivers) {

    print qq|
  <tr>
    <td colspan=2>
      <table>
	<tr>|;

    $checked = "";
    if ($myconfig->{dbdriver} eq $item) {
      map { $form->{"${item}_$_"} = $myconfig->{$_} }
        qw(dbhost dbport dbuser dbpasswd dbname sid);
      $checked = "checked";
    }

    print qq|
	  <th align=right>| . $locale->text('Driver') . qq|</th>
	  <td><input name=dbdriver type=radio class=radio value=$item $checked>&nbsp;$item</td>
	  <th align=right>| . $locale->text('Host') . qq|</th>
	  <td><input name="${item}_dbhost" size=30 value=$form->{"${item}_dbhost"}></td>
	</tr>
	<tr>|;

    if ($item eq 'Pg') {
      print qq|
	  <th align=right>| . $locale->text('Dataset') . qq|</th>
	  <td><input name=Pg_dbname size=15 value=$form->{Pg_dbname}></td>
	  <th align=right>| . $locale->text('Port') . qq|</th>
	  <td><input name=Pg_dbport size=4 value=$form->{Pg_dbport}></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('User') . qq|</th>
	  <td><input name="${item}_dbuser" size=15 value=$form->{"${item}_dbuser"}></td>
	  <th align=right>| . $locale->text('Password') . qq|</th>
	  <td><input name="${item}_dbpasswd" type=password size=10 value=$form->{"${item}_dbpasswd"}></td>
	</tr>|;

    }

    if ($item eq 'Oracle') {
      print qq|
	  <th align=right>SID</th>
	  <td><input name=Oracle_sid value=$form->{Oracle_sid}></td>
	  <th align=right>| . $locale->text('Port') . qq|</th>
	  <td><input name=Oracle_dbport size=4 value=$form->{Oracle_dbport}></td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Dataset') . qq|</th>
	  <td><input name="${item}_dbuser" size=15 value=$form->{"${item}_dbuser"}></td>
	  <th align=right>| . $locale->text('Password') . qq|</th>
	  <td><input name="${item}_dbpasswd" type=password size=10 value=$form->{"${item}_dbpasswd"}></td>
	  
	</tr>|;
    }

    print qq|
	<input type=hidden name=old_dbpasswd value=$myconfig->{dbpasswd}>
      </table>
    </td>
  </tr>
  <tr>
    <td colspan=2><hr size=2 noshade></td>
  </tr>
|;

  }

  # access control
  open(FH, $menufile) or $form->error("$menufile : $!");

  # scan for first menu level
  @a = <FH>;
  close(FH);

  if (open(FH, "custom_$menufile")) {
    push @a, <FH>;
  }
  close(FH);

  foreach $item (@a) {
    next unless $item =~ /\[/;
    next if $item =~ /\#/;

    $item =~ s/(\[|\])//g;
    chop $item;

    if ($item =~ /--/) {
      ($level, $menuitem) = split /--/, $item, 2;
    } else {
      $level    = $item;
      $menuitem = $item;
      push @acsorder, $item;
    }

    push @{ $acs{$level} }, $menuitem;

  }

  %role = ('admin'      => $locale->text('Administrator'),
           'user'       => $locale->text('User'),
           'manager'    => $locale->text('Manager'),
           'supervisor' => $locale->text('Supervisor'));

  $selectrole = "";
  foreach $item (qw(user supervisor manager admin)) {
    $selectrole .=
      ($myconfig->{role} eq $item)
      ? "<option selected value=$item>$role{$item}\n"
      : "<option value=$item>$role{$item}\n";
  }

  print qq|
  <tr class=listheading>
    <th colspan=2>| . $locale->text('Access Control') . qq|</th>
  </tr>
  <tr>
    <td><select name=role>$selectrole</select></td>
  </tr>
|;

  foreach $item (split /;/, $myconfig->{acs}) {
    ($key, $value) = split /--/, $item, 2;
    $excl{$key}{$value} = 1;
  }

  foreach $key (@acsorder) {

    $checked = "checked";
    if ($form->{login}) {
      $checked = ($excl{$key}{$key}) ? "" : "checked";
    }

    # can't have variable names with spaces
    # the 1 is for apache 2
    $item = $form->escape("${key}--$key", 1);

    $acsheading = $key;
    $acsheading =~ s/ /&nbsp;/g;

    $acsheading = qq|
    <th align=left><input name="$item" class=checkbox type=checkbox value=1 $checked>&nbsp;$acsheading</th>\n|;
    $menuitems .= "$item;";
    $acsdata = "
    <td>";

    foreach $item (@{ $acs{$key} }) {
      next if ($key eq $item);

      $checked = "checked";
      if ($form->{login}) {
        $checked = ($excl{$key}{$item}) ? "" : "checked";
      }

      $acsitem = $form->escape("${key}--$item", 1);

      $acsdata .= qq|
    <br><input name="$acsitem" class=checkbox type=checkbox value=1 $checked>&nbsp;$item|;
      $menuitems .= "$acsitem;";
    }

    $acsdata .= "
    </td>";

    print qq|
  <tr valign=top>$acsheading $acsdata
  </tr>
|;
  }

  print qq|<input type=hidden name=acs value="$menuitems">
|;
  if ($webdav) {
    @webdavdirs =
      qw(angebote bestellungen rechnungen anfragen lieferantenbestellungen einkaufsrechnungen);
    foreach $directory (@webdavdirs) {
      if ($myconfig->{$directory}) {
        $webdav{"${directory}c"} = "checked";
      } else {
        $webdav{"${directory}c"} = "";
      }
    }
    print qq|  
   <tr>
    <td colspan=2><hr size=3 noshade></td>
  </tr>
  <tr class=listheading>
    <th colspan=2>| . $locale->text('WEBDAV-Zugriff') . qq|</th>
  </tr>
  <table width=100%>
	<tr>
	<td><input name=angebote class=checkbox type=checkbox value=1 $webdav{angebotec}>&nbsp;Angebot</td>
	<td><input name=bestellungen class=checkbox type=checkbox value=1 $webdav{bestellungenc}>&nbsp;Bestellung</td> 
	<td><input name=rechnungen class=checkbox type=checkbox value=1 $webdav{rechnungenc}>&nbsp;Rechnung</td>
	</tr>
	<tr>
	<td><input name=anfragen class=checkbox type=checkbox value=1 $webdav{anfragenc}>&nbsp;Angebot</td>
	<td><input name=lieferantenbestellungen class=checkbox type=checkbox value=1 $webdav{lieferantenbestellungenc}>&nbsp;Lieferantenbestellung</td> 
	<td><input name=einkaufsrechnungen class=checkbox type=checkbox value=1 $webdav{einkaufsrechnungenc}>&nbsp;Einkaufsrechnung</td>
	</tr>
  </table>    
  <tr>
    <td colspan=2><hr size=3 noshade></td>
  </tr>
|;
  }
  print qq|
</table>
</div>
|;

}

sub save {

  # no driver checked
  $form->error($locale->text('Database Driver not checked!'))
    unless $form->{dbdriver};

  # no spaces allowed in login name
  ($form->{login}) = split / /, $form->{login};

  $form->isblank("login", $locale->text('Login name missing!'));

  # check for duplicates
  if (!$form->{edit}) {
    $temp = new User "$memberfile", "$form->{login}";

    if ($temp->{login}) {
      $form->error("$form->{login} " . $locale->text('is already a member!'));
    }
  }

  # no spaces allowed in directories
  ($form->{newtemplates}) = split / /, $form->{newtemplates};

  if ($form->{newtemplates}) {
    $form->{templates} = $form->{newtemplates};
  } else {
    $form->{templates} =
      ($form->{usetemplates}) ? $form->{usetemplates} : $form->{login};
  }

  # is there a basedir
  if (!-d "$templates") {
    $form->error(  $locale->text('Directory')
                 . ": $templates "
                 . $locale->text('does not exist'));
  }

  # add base directory to $form->{templates}
  $form->{templates} = "$templates/$form->{templates}";

  $myconfig = new User "$memberfile", "$form->{login}";

  # redo acs variable and delete all the acs codes
  @acs = split /;/, $form->{acs};

  $form->{acs} = "";
  foreach $item (@acs) {
    $item = $form->escape($item, 1);

    if (!$form->{$item}) {
      $form->{acs} .= $form->unescape($form->unescape($item)) . ";";
    }
    delete $form->{$item};
  }

  # check which database was filled in
  if ($form->{dbdriver} eq 'Oracle') {
    $form->{sid}      = $form->{Oracle_sid},;
    $form->{dbhost}   = $form->{Oracle_dbhost},;
    $form->{dbport}   = $form->{Oracle_dbport};
    $form->{dbpasswd} = $form->{Oracle_dbpasswd};
    $form->{dbuser}   = $form->{Oracle_dbuser};
    $form->{dbname}   = $form->{Oracle_dbuser};

    $form->isblank("dbhost", $locale->text('Hostname missing!'));
    $form->isblank("dbport", $locale->text('Port missing!'));
    $form->isblank("dbuser", $locale->text('Dataset missing!'));
  }
  if ($form->{dbdriver} eq 'Pg') {
    $form->{dbhost}   = $form->{Pg_dbhost};
    $form->{dbport}   = $form->{Pg_dbport};
    $form->{dbpasswd} = $form->{Pg_dbpasswd};
    $form->{dbuser}   = $form->{Pg_dbuser};
    $form->{dbname}   = $form->{Pg_dbname};

    $form->isblank("dbname", $locale->text('Dataset missing!'));
    $form->isblank("dbuser", $locale->text('Database User missing!'));
  }

  if ($webdav) {
    @webdavdirs =
      qw(angebote bestellungen rechnungen anfragen lieferantenbestellungen einkaufsrechnungen);
    foreach $directory (@webdavdirs) {
      if ($form->{$directory}) {
        $form->{$directory} = $form->{$directory};
      } else {
        $form->{$directory} = 0;
      }
    }
  }

  foreach $item (keys %{$form}) {
    $myconfig->{$item} = $form->{$item};
  }

  delete $myconfig->{stylesheet};
  if ($form->{userstylesheet}) {
    $myconfig->{stylesheet} = $form->{userstylesheet};
  }

  $myconfig->save_member($memberfile, $userspath);

  if ($webdav) {
    @webdavdirs =
      qw(angebote bestellungen rechnungen anfragen lieferantenbestellungen einkaufsrechnungen);
    foreach $directory (@webdavdirs) {
      $file = "webdav/" . $directory . "/webdav-user";
      if ($form->{$directory}) {
        if (open(HTACCESS, "$file")) {
          while (<HTACCESS>) {
            ($login, $password) = split(/:/, $_);
            if ($login ne $form->{login}) {
              $newfile .= $_;
            }
          }
          close(HTACCESS);
        }
        open(HTACCESS, "> $file") or die "cannot open $file $!\n";
        $newfile .= $myconfig->{login} . ":" . $myconfig->{password} . "\n";
        print(HTACCESS $newfile);
        close(HTACCESS);
      } else {
        $form->{$directory} = 0;
        if (open(HTACCESS, "$file")) {
          while (<HTACCESS>) {
            ($login, $password) = split(/:/, $_);
            if ($login ne $form->{login}) {
              $newfile .= $_;
            }
          }
          close(HTACCESS);
        }
        open(HTACCESS, "> $file") or die "cannot open $file $!\n";
        print(HTACCESS $newfile);
        close(HTACCESS);
      }
    }
  }

  # create user template directory and copy master files
  if (!-d "$form->{templates}") {
    umask(002);

    if (mkdir "$form->{templates}", oct("771")) {

      umask(007);

      # copy templates to the directory
      opendir TEMPLATEDIR, "$templates/." or $form - error("$templates : $!");
      @templates = grep /$form->{mastertemplates}.*?\.(html|tex)$/,
        readdir TEMPLATEDIR;
      closedir TEMPLATEDIR;

      foreach $file (@templates) {
        open(TEMP, "$templates/$file")
          or $form->error("$templates/$file : $!");

        $file =~ s/$form->{mastertemplates}-//;
        open(NEW, ">$form->{templates}/$file")
          or $form->error("$form->{templates}/$file : $!");

        while ($line = <TEMP>) {
          print NEW $line;
        }
        close(TEMP);
        close(NEW);
      }
    } else {
      $form->error("$!: $form->{templates}");
    }
  }

  $form->redirect($locale->text('User saved!'));

}

sub delete {

  $form->{templates} =
    ($form->{templates})
    ? "$templates/$form->{templates}"
    : "$templates/$form->{login}";

  $form->error($locale->text('File locked!')) if (-f ${memberfile} . LCK);
  open(FH, ">${memberfile}.LCK") or $form->error("${memberfile}.LCK : $!");
  close(FH);

  open(CONF, "+<$memberfile") or $form->error("$memberfile : $!");

  @config = <CONF>;

  seek(CONF, 0, 0);
  truncate(CONF, 0);

  while ($line = shift @config) {

    if ($line =~ /^\[/) {
      last if ($line =~ /\[$form->{login}\]/);
      $login = &login_name($line);
    }

    if ($line =~ /^templates=/) {
      $user{$login} = &get_value($line);
    }

    print CONF $line;
  }

  # remove everything up to next login or EOF
  # and save template variable
  while ($line = shift @config) {
    if ($line =~ /^templates=/) {
      $templatedir = &get_value($line);
    }
    last if ($line =~ /^\[/);
  }

  # this one is either the next login or EOF
  print CONF $line;

  $login = &login_name($line);

  while ($line = shift @config) {
    if ($line =~ /^\[/) {
      $login = &login_name($line);
    }

    if ($line =~ /^templates=/) {
      $user{$login} = &get_value($line);
    }

    print CONF $line;
  }

  close(CONF);
  unlink "${memberfile}.LCK";

  # scan %user for $templatedir
  foreach $login (keys %user) {
    last if ($found = ($templatedir eq $user{$login}));
  }

  # if found keep directory otherwise delete
  if (!$found) {

    # delete it if there is a template directory
    $dir = "$form->{templates}";
    if (-d "$dir") {
      unlink <$dir/*.html>;
      unlink <$dir/*.tex>;
      rmdir "$dir";
    }
  }

  # delete config file for user
  unlink "$userspath/$form->{login}.conf";

  $form->redirect($locale->text('User deleted!'));

}

sub login_name {
  my $login = shift;

  $login =~ s/\[\]//g;
  return ($login) ? $login : undef;

}

sub get_value {
  my $line = shift;

  my ($null, $value) = split(/=/, $line, 2);

  # remove comments
  $value =~ s/\s#.*//g;

  # remove any trailing whitespace
  $value =~ s/^\s*(.*?)\s*$/$1/;

  $value;
}

sub change_admin_password {

  $form->{title} =
      qq|Lx-Office ERP |
    . $locale->text('Administration') . " / "
    . $locale->text('Change Admin Password');

  $form->header;

  print qq|
<body class=admin>


<h2>| . $locale->text('Change Admin Password') . qq|</h2>

<form method=post action=$form->{script}>

<b>|
    . $locale->text('Password')
    . qq|</b> <input type=password name=password size=8>

<input type=hidden name=root value="$form->{root}">
<input type=hidden name=path value=$form->{path}>
<input type=hidden name=rpw value=$form->{rpw}>

<p>
<input type=submit class=submit name=action value="|
    . $locale->text('Change Password') . qq|">

</form>

</body>
</html>
|;

}

sub change_password {

  $root->{password} = $form->{password};

  $root->{'root login'} = 1;
  $root->save_member($memberfile);

  $form->{callback} =
    "$form->{script}?action=list_users&path=$form->{path}&root=$form->{root}&rpw=$root->{password}";

  $form->redirect($locale->text('Password changed!'));

}

sub check_password {

  $root = new User "$memberfile", $form->{root};

  if ($root->{password}) {
    if ($root->{password} ne $form->{rpw}) {
      $form->error($locale->text('Incorrect Password!'));
    }
  }

}

sub pg_database_administration {

  $form->{dbdriver} = 'Pg';
  &dbselect_source;

}

sub oracle_database_administration {

  $form->{dbdriver} = 'Oracle';
  &dbselect_source;

}

sub dbdriver_defaults {

  # load some defaults for the selected driver
  %driverdefaults = (
                     'Pg' => { dbport        => '5432',
                               dbuser        => 'postgres',
                               dbdefault     => 'template1',
                               dbhost        => 'localhost',
                               connectstring => $locale->text('Connect to')
                     },
                     'Oracle' => { dbport        => '1521',
                                   dbuser        => 'oralin',
                                   dbdefault     => $sid,
                                   dbhost        => `hostname`,
                                   connectstring => 'SID'
                     });

  map { $form->{$_} = $driverdefaults{ $form->{dbdriver} }{$_} }
    keys %{ $driverdefaults{Pg} };

}

sub dbselect_source {

  &dbdriver_defaults;

  $msg{Pg} =
    $locale->text(
    'Leave host and port field empty unless you want to make a remote connection.'
    );
  $msg{Oracle} =
    $locale->text(
           'You must enter a host and port for local and remote connections!');

  $form->{title} =
    "Lx-Office ERP / " . $locale->text('Database Administration');

  $form->header;

  print qq|
<body class=admin>


<center>
<h2>$form->{title}</h2>

<form method=post action=$form->{script}>

<table>
<tr><td>

<table>

  <tr class=listheading>
    <th colspan=4>| . $locale->text('Database') . qq|</th>
  </tr>

<input type=hidden name=dbdriver value=$form->{dbdriver}>

  <tr><td>
   <table>

  <tr>

    <th align=right>| . $locale->text('Host') . qq|</th>
    <td><input name=dbhost size=25 value=$form->{dbhost}></td>
    <th align=right>| . $locale->text('Port') . qq|</th>
    <td><input name=dbport size=5 value=$form->{dbport}></td>

  </tr>

  <tr>

    <th align=right>| . $locale->text('User') . qq|</th>
    <td><input name=dbuser size=10 value=$form->{dbuser}></td>
    <th align=right>| . $locale->text('Password') . qq|</th>
    <td><input type=password name=dbpasswd size=10></td>

  </tr>
  
  <tr>

    <th align=right>$form->{connectstring}</th>
    <td colspan=3><input name=dbdefault size=10 value=$form->{dbdefault}></td>

  </tr>

</table>

</td></tr>
</table>

<input name=callback type=hidden value="$form->{script}?action=list_users&path=$form->{path}&root=$form->{root}&rpw=$form->{rpw}">
<input type=hidden name=root value="$form->{root}">
<input type=hidden name=path value=$form->{path}>
<input type=hidden name=rpw value=$form->{rpw}>

<br>

<input type=submit class=submit name=action value="|
    . $locale->text('Create Dataset') . qq|">
<input type=submit class=submit name=action value="|
    . $locale->text('Update Dataset') . qq|">
<input type=submit class=submit name=action value="|
    . $locale->text('Delete Dataset') . qq|">

</form>

</td></tr>
</table>

<p>|
    . $locale->text(
    'This is a preliminary check for existing sources. Nothing will be created or deleted at this stage!'
    )

    . qq|
<br>$msg{$form->{dbdriver}}


</body>
</html>
|;

}

sub continue {

  &{ $form->{nextsub} };

}

sub update_dataset {

  %needsupdate = User->dbneedsupdate(\%$form);

  $form->{title} =
      "Lx-Office ERP "
    . $locale->text('Database Administration') . " / "
    . $locale->text('Update Dataset');

  $form->header;

  print qq|
<body class=admin>


<center>
<h2>$form->{title}</h2>
|;

  foreach $key (sort keys %needsupdate) {
    if ($needsupdate{$key} ne $form->{dbversion}) {
      $upd .= qq|<input name="db$key" type=checkbox value=1 checked> $key\n|;
      $form->{dbupdate} .= "db$key ";
    }
  }

  chop $form->{dbupdate};

  if ($form->{dbupdate}) {

    print qq|
<table width=100%>
<form method=post action=$form->{script}>

<input type=hidden name=dbdriver value=$form->{dbdriver}>
<input type=hidden name=dbhost value=$form->{dbhost}>
<input type=hidden name=dbport value=$form->{dbport}>
<input type=hidden name=dbuser value=$form->{dbuser}>
<input type=hidden name=dbpasswd value=$form->{dbpasswd}>
<input type=hidden name=dbdefault value=$form->{dbdefault}>

<tr class=listheading>
  <th>| . $locale->text('The following Datasets need to be updated') . qq|</th>
</tr>
<tr>
<td>

$upd

</td>
</tr>
<tr>
<td>

<input name=dbupdate type=hidden value="$form->{dbupdate}">

<input name=callback type=hidden value="$form->{script}?action=list_users&path=$form->{path}&root=$form->{root}&rpw=$form->{rpw}">

<input type=hidden name=root value="$form->{root}">
<input type=hidden name=path value=$form->{path}>
<input type=hidden name=rpw value=$form->{rpw}>

<input type=hidden name=nextsub value=dbupdate>

<hr size=3 noshade>

<br>
<input type=submit class=submit name=action value="|
      . $locale->text('Continue') . qq|">

</td></tr>
</table>
</form>
|;

  } else {

    print $locale->text('All Datasets up to date!');

  }

  print qq|

</body>
</html>
|;

}

sub dbupdate {

  User->dbupdate(\%$form);

  $form->redirect($locale->text('Dataset updated!'));

}

sub create_dataset {

  foreach $item (sort User->dbsources(\%$form)) {
    $dbsources .= "[$item] ";
  }

  opendir SQLDIR, "sql/." or $form - error($!);
  foreach $item (sort grep /-chart\.sql/, readdir SQLDIR) {
    next if ($item eq 'Default-chart.sql');
    $item =~ s/-chart\.sql//;
    push @charts,
      qq| <input name=chart class=radio type=radio value="$item">&nbsp;$item|;
  }
  closedir SQLDIR;

  $selectencoding = qq|<option>
  <option value=SQL_ASCII>ASCII
  <option value=EUC_JP>Japanese Extended UNIX Code
  <option value=EUC_CN>Chinese Extended UNIX Code
  <option value=EUC_KR>Korean Extended UNIX Code
  <option value=EUC_TW>Taiwan Extended UNIX Code
  <option value=UNICODE>UTF-8 Unicode
  <option value=MULE_INTERNAL>Mule internal type
  <option value=LATIN1>ISO 8859-1
  <option value=LATIN2>ISO 8859-2
  <option value=LATIN3>ISO 8859-3
  <option value=LATIN4>ISO 8859-4
  <option value=LATIN5>ISO 8859-5
  <option value=KOI8>KOI8-R
  <option value=WIN>Windows CP1251
  <option value=ALT>Windows CP866
  |;

  $form->{title} =
      "Lx-Office ERP "
    . $locale->text('Database Administration') . " / "
    . $locale->text('Create Dataset');

  $form->header;

  print qq|
<body class=admin>


<center>
<h2>$form->{title}</h2>

<form method=post action=$form->{script}>

<table width=100%>
  <tr class=listheading>
    <th colspan=2>&nbsp;</th>
  </tr>

  <tr>

    <th align=right nowrap>| . $locale->text('Existing Datasets') . qq|</th>
    <td>$dbsources</td>

  </tr>
  
  <tr>

    <th align=right nowrap>| . $locale->text('Create Dataset') . qq|</th>
    <td><input name=db></td>

  </tr>

  <tr>

    <th align=right nowrap>| . $locale->text('Multibyte Encoding') . qq|</th>
    <td><select name=encoding>$selectencoding</select></td>

  </tr>
 
  <tr>

    <th align=right nowrap>|
    . $locale->text('Create Chart of Accounts')
    . qq|</th>
    <td>@charts</td>

  </tr>
 
  <tr><td colspan=2>
<p>
<input type=hidden name=dbdriver value=$form->{dbdriver}>
<input type=hidden name=dbuser value=$form->{dbuser}>
<input type=hidden name=dbhost value=$form->{dbhost}>
<input type=hidden name=dbport value=$form->{dbport}>
<input type=hidden name=dbpasswd value=$form->{dbpasswd}>
<input type=hidden name=dbdefault value=$form->{dbdefault}>

<input name=callback type=hidden value="$form->{script}?action=list_users&path=$form->{path}&root=$form->{root}&rpw=$form->{rpw}">

<input type=hidden name=root value="$form->{root}">
<input type=hidden name=path value=$form->{path}>
<input type=hidden name=rpw value=$form->{rpw}>

<input type=hidden name=nextsub value=dbcreate>

<hr size=3 noshade>

<br>
<input type=submit class=submit name=action value="|
    . $locale->text('Continue') . qq|">

  </td></tr>
</table>

</form>


</body>
</html>
|;

}

sub dbcreate {

  $form->isblank("db", $locale->text('Dataset missing!'));

  User->dbcreate(\%$form);

  $form->{title} =
      "Lx-Office ERP "
    . $locale->text('Database Administration') . " / "
    . $locale->text('Create Dataset');

  $form->header;

  print qq|
<body class=admin>


<center>
<h2>$form->{title}</h2>

<form method=post action=$form->{script}>|

    . $locale->text('Dataset')
    . " $form->{db} "
    . $locale->text('successfully created!')

    . qq|

<input type=hidden name=root value="$form->{root}">
<input type=hidden name=path value="$form->{path}">
<input type=hidden name=rpw value="$form->{rpw}">

<input type=hidden name=nextsub value=list_users>

<p><input type=submit class=submit name=action value="|
    . $locale->text('Continue') . qq|">
</form>


</body>
</html>
|;

}

sub delete_dataset {

  if (@dbsources = User->dbsources_unused(\%$form, $memberfile)) {
    foreach $item (sort @dbsources) {
      $dbsources .=
        qq|<input name=db class=radio type=radio value=$item>&nbsp;$item |;
    }
  } else {
    $form->error($locale->text('Nothing to delete!'));
  }

  $form->{title} =
      "Lx-Office ERP "
    . $locale->text('Database Administration') . " / "
    . $locale->text('Delete Dataset');

  $form->header;

  print qq|
<body class=admin>

<h2>$form->{title}</h2>

<form method=post action=$form->{script}>

<table width=100%>
  <tr class=listheading>
    <th>|
    . $locale->text('The following Datasets are not in use and can be deleted')
    . qq|</th>
  </tr>

  <tr>
    <td>
    $dbsources
    </td>
  </tr>
  
  <tr><td>
<p>
<input type=hidden name=dbdriver value=$form->{dbdriver}>
<input type=hidden name=dbuser value=$form->{dbuser}>
<input type=hidden name=dbhost value=$form->{dbhost}>
<input type=hidden name=dbport value=$form->{dbport}>
<input type=hidden name=dbpasswd value=$form->{dbpasswd}>
<input type=hidden name=dbdefault value=$form->{dbdefault}>

<input name=callback type=hidden value="$form->{script}?action=list_users&path=$form->{path}&root=$form->{root}&rpw=$form->{rpw}">

<input type=hidden name=root value="$form->{root}">
<input type=hidden name=path value="$form->{path}">
<input type=hidden name=rpw value="$form->{rpw}">

<input type=hidden name=nextsub value=dbdelete>

<hr size=3 noshade>

<br>
<input type=submit class=submit name=action value="|
    . $locale->text('Continue') . qq|">

  </td></tr>
</table>

</form>

</body>
</html>
|;

}

sub dbdelete {

  if (!$form->{db}) {
    $form->error($locale->text('No Dataset selected!'));
  }

  User->dbdelete(\%$form);

  $form->{title} =
      "Lx-Office ERP "
    . $locale->text('Database Administration') . " / "
    . $locale->text('Delete Dataset');

  $form->header;

  print qq|
<body class=admin>


<center>
<h2>$form->{title}</h2>

<form method=post action=$form->{script}>

$form->{db} | . $locale->text('successfully deleted!')

    . qq|

<input type=hidden name=root value="$form->{root}">
<input type=hidden name=path value="$form->{path}">
<input type=hidden name=rpw value="$form->{rpw}">

<input type=hidden name=nextsub value=list_users>

<p><input type=submit class=submit name=action value="|
    . $locale->text('Continue') . qq|">
</form>


</body>
</html>
|;

}

sub unlock_system {

  unlink "$userspath/nologin";

  $form->{callback} =
    "$form->{script}?action=list_users&path=$form->{path}&root=$form->{root}&rpw=$root->{password}";

  $form->redirect($locale->text('Lockfile removed!'));

}

sub lock_system {

  open(FH, ">$userspath/nologin")
    or $form->error($locale->text('Cannot create Lock!'));
  close(FH);

  $form->{callback} =
    "$form->{script}?action=list_users&path=$form->{path}&root=$form->{root}&rpw=$root->{password}";

  $form->redirect($locale->text('Lockfile created!'));

}

