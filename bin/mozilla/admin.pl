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

use DBI;
use CGI;

use SL::Form;
use SL::User;
use SL::Common;
use SL::Inifile;

require "bin/mozilla/common.pl";

our $cgi = new CGI('');

$form = new Form;
$form->{"root"} = "root login";

$locale = new Locale $language, "admin";

# customization
if (-f "bin/mozilla/custom_$form->{script}") {
  eval { require "bin/mozilla/custom_$form->{script}"; };
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

  check_password();

  call_sub($subroutine);

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

  adminlogin();

}

1;

# end

sub adminlogin {

  $form->{title} =
    qq|Lx-Office ERP $form->{version} | . $locale->text('Administration');

  $form->header();
  print $form->parse_html_template('admin/adminlogin');
}

sub login {
  list_users();
}

sub list_users {

  $form->error($locale->text('File locked!')) if (-f "${memberfile}.LCK");

  open(FH, "$memberfile") or $form->error("$memberfile : $!");

  my %members;

  while (<FH>) {
    chomp;

    if (/^\[.*\]/) {
      $login = $_;
      $login =~ s/(\[|\])//g;

      $members{$login} = { "login" => $login };
    }

    if (/^([a-z]+)=(.*)/) {
      $members{$login}->{$1} = $2;
    }
  }

  close(FH);

  delete $members{"root login"};
  map { $_->{templates} =~ s|.*/||; } values %members;

  $form->{title}  = "Lx-Office ERP " . $locale->text('Administration');
  $form->{LOCKED} = -e "$userspath/nologin";
  $form->{MEMBERS} = [ @members{sort { lc $a cmp lc $b } keys %members} ];

  $form->header();
  print $form->parse_html_template("admin/list_users");
}

sub add_user {

  $form->{title} =
      "Lx-Office ERP "
    . $locale->text('Administration') . " / "
    . $locale->text('Add User');

  $form->{Oracle_sid}    = $sid;
  $form->{Oracle_dbport} = '1521';
  $form->{Oracle_dbhost} = `hostname`;

  my $myconfig = {
    "vclimit"      => 200,
    "countrycode"  => "de",
    "numberformat" => "1000,00",
    "dateformat"   => "dd.mm.yy",
    "stylesheet"   => "lx-office-erp.css",
  };

  edit_user_form($myconfig);
}

sub edit {

  $form->{title} =
      "Lx-Office ERP "
    . $locale->text('Administration') . " / "
    . $locale->text('Edit User');
  $form->{edit} = 1;

  $form->isblank("login", $locale->text("The login is missing."));

  # get user
  my $myconfig = new User "$memberfile", "$form->{login}";

  $myconfig->{signature} =~ s/\\n/\r\n/g;
  $myconfig->{address}   =~ s/\\n/\r\n/g;

  # strip basedir from templates directory
  $myconfig->{templates} =~ s|.*/||;

  edit_user_form($myconfig);
}

sub edit_user_form {
  my ($myconfig) = @_;

  my @valid_dateformats = qw(mm-dd-yy mm/dd/yy dd-mm-yy dd/mm/yy dd.mm.yy yyyy-mm-dd);
  $form->{ALL_DATEFORMATS} = [ map { { "format" => $_, "selected" => $_ eq $myconfig->{dateformat} } } @valid_dateformats ];

  my @valid_numberformats = qw(1,000.00 1000.00 1.000,00 1000,00);
  $form->{ALL_NUMBERFORMATS} = [ map { { "format" => $_, "selected" => $_ eq $myconfig->{numberformat} } } @valid_numberformats ];

  %countrycodes = User->country_codes;
  $form->{ALL_COUNTRYCODES} = [];
  foreach $countrycode (sort { $countrycodes{$a} cmp $countrycodes{$b} } keys %countrycodes) {
    push @{ $form->{ALL_COUNTRYCODES} }, { "value"    => $countrycode,
                                           "name"     => $countrycodes{$countrycode},
                                           "selected" => $countrycode eq $myconfig->{countrycode} };
  }

  # is there a templates basedir
  if (!-d "$templates") {
    $form->error(sprintf($locale->text("The directory %s does not exist."), $templates));
  }

  opendir TEMPLATEDIR, "$templates/." or $form->error("$templates : $!");
  my @all     = readdir(TEMPLATEDIR);
  my @alldir  = sort grep { -d "$templates/$_" && !/^\.\.?$/ } @all;
  my @allhtml = sort grep { -f "$templates/$_" && /\.html$/ } @all;
  closedir TEMPLATEDIR;

  @alldir = grep !/\.(html|tex|sty|odt|xml|txb)$/, @alldir;
  @alldir = grep !/^(webpages|\.svn)$/, @alldir;

  @allhtml = reverse grep !/Default/, @allhtml;
  push @allhtml, 'Default';
  @allhtml = reverse @allhtml;

  $form->{ALL_TEMPLATES} = [ map { { "name", => $_, "selected" => $_ eq $myconfig->{templates} } } @alldir ];

  $lastitem = $allhtml[0];
  $lastitem =~ s/-.*//g;
  $form->{ALL_MASTER_TEMPLATES} = [ { "name" => $lastitem, "selected" => $lastitem eq "German" } ];
  foreach $item (@allhtml) {
    $item =~ s/-.*//g;
    next if ($item eq $lastitem);

    push @{ $form->{ALL_MASTER_TEMPLATES} }, { "name" => $item, "selected" => $item eq "German" };
    $lastitem = $item;
  }

  # css dir has styles that are not intended as general layouts.
  # reverting to hardcoded list
  $form->{ALL_STYLESHEETS} = [ map { { "name" => $_, "selected" => $_ eq $myconfig->{stylesheet} } } qw(lx-office-erp.css Win2000.css) ];

  $form->{"menustyle_" . $myconfig->{menustyle} } = 1;

  map { $form->{"myc_${_}"} = $myconfig->{$_} } keys %{ $myconfig };

  map { $form->{"Pg_${_}"} = $myconfig->{$_} } qw(dbhost dbport dbname dbuser dbpasswd);

  # access control
  my @acsorder = ();
  my %acs      = ();
  my %excl     = ();
  open(FH, $menufile) or $form->error("$menufile : $!");

  while ($item = <FH>) {
    next unless $item =~ /\[/;
    next if $item =~ /\#/;

    $item =~ s/(\[|\])//g;
    chomp $item;

    my ($level, $menuitem);

    if ($item =~ /--/) {
      ($level, $menuitem) = split /--/, $item, 2;
    } else {
      $level    = $item;
      $menuitem = $item;
      push @acsorder, $item;
    }

    $acs{$level} ||= [];
    push @{ $acs{$level} }, $menuitem;

  }

  foreach $item (split(/;/, $myconfig->{acs})) {
    ($key, $value) = split /--/, $item, 2;
    $excl{$key}{$value} = 1;
  }

  $form->{ACLS}    = [];
  $form->{all_acs} = "";

  foreach $key (@acsorder) {
    my $acl = { "checked" => $form->{login} ? !$excl{$key}->{$key} : 1,
                "name"    => "${key}--${key}",
                "title"   => $key,
                "SUBACLS" => [], };
    $form->{all_acs} .= "${key}--${key};";

    foreach $item (@{ $acs{$key} }) {
      next if ($key eq $item);

      my $subacl = { "checked" => $form->{login} ? !$excl{$key}->{$item} : 1,
                     "name"    => "${key}--${item}",
                     "title"   => $item };
      push @{ $acl->{SUBACLS} }, $subacl;
      $form->{all_acs} .= "${key}--${item};";
    }
    push @{ $form->{ACLS} }, $acl;
  }

  chop $form->{all_acs};

  $form->header();
  print $form->parse_html_template("admin/edit_user");
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
    $form->error(sprintf($locale->text("The directory %s does not exist."), $templates));
  }

  # add base directory to $form->{templates}
  $form->{templates} =~ s|.*/||;
  $form->{templates} =  "$templates/$form->{templates}";

  $myconfig = new User "$memberfile", "$form->{login}";

  # redo acs variable and delete all the acs codes
  my @acs;
  foreach $item (split m|;|, $form->{all_acs}) {
    my $name =  "ACS_${item}";
    $name    =~ s| |+|g;
    push @acs, $item if !$form->{$name};
    delete $form->{$name};
  }
  $form->{acs} = join ";", @acs;

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

  $form->{templates}       =~ s|.*/||;
  $form->{templates}       =  "${templates}/$form->{templates}";
  $form->{mastertemplates} =~ s|.*/||;

  # create user template directory and copy master files
  if (!-d "$form->{templates}") {
    umask(002);

    if (mkdir "$form->{templates}", oct("771")) {

      umask(007);

      # copy templates to the directory
      opendir TEMPLATEDIR, "$templates/." or $form - error("$templates : $!");
      @templates = grep /$form->{mastertemplates}.*?\.(html|tex|sty|xml|txb)$/,
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
  $form->error($locale->text('File locked!')) if (-f ${memberfile} . LCK);
  open(FH, ">${memberfile}.LCK") or $form->error("${memberfile}.LCK : $!");
  close(FH);

  my $members = Inifile->new($memberfile);
  my $templates = $members->{$form->{login}}->{templates};
  delete $members->{$form->{login}};
  $members->write();
  unlink "${memberfile}.LCK";

  if ($templates) {
    my $templates_in_use = 0;
    foreach $login (keys %{ $members }) {
      next if $login =~ m/^[A-Z]+$/;
      next if $members->{$login}->{templates} ne $templates;
      $templates_in_use = 1;
      last;
    }

    if (!$templates_in_use && -d $templates) {
      unlink <$templates/*>;
      rmdir $templates;
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

  $form->header();
  print $form->parse_html_template("admin/change_admin_password");
}

sub change_password {
  if ($form->{"password"} ne $form->{"password_again"}) {
    $form->{title} =
      qq|Lx-Office ERP |
      . $locale->text('Administration') . " / "
      . $locale->text('Change Admin Password');

    $form->header();
    $form->error($locale->text("The passwords do not match."));
  }

  $root->{password} = $form->{password};

  $root->{'root login'} = 1;
  $root->save_member($memberfile);

  $form->{callback} =
    "$form->{script}?action=list_users&rpw=$root->{password}";

  $form->redirect($locale->text('Password changed!'));
}

sub check_password {
  $root = new User "$memberfile", $form->{root};

  if (!defined($root->{password}) || ($root->{password} ne $form->{rpw})) {
    $form->error($locale->text('Incorrect Password!'));
  }

}

sub pg_database_administration {

  $form->{dbdriver} = 'Pg';
  dbselect_source();

}

sub oracle_database_administration {

  $form->{dbdriver} = 'Oracle';
  dbselect_source();

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

  dbdriver_defaults();

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
    <td><input name="dbuser" size="10" value="$form->{dbuser}"></td>
    <th align=right>| . $locale->text('Password') . qq|</th>
    <td><input type="password" name="dbpasswd" size="10"></td>

  </tr>

  <tr>

    <th align=right>$form->{connectstring}</th>
    <td colspan=3><input name=dbdefault size=10 value=$form->{dbdefault}></td>

  </tr>

</table>

</td></tr>
</table>

<input name=callback type=hidden value="$form->{script}?action=list_users&rpw=$form->{rpw}">
<input type=hidden name=rpw value=$form->{rpw}>

<br>

<input type=submit class=submit name=action value="|
    . $locale->text('Create Dataset') . qq|">|;
# Vorübergehend Deaktiviert
# <input type=submit class=submit name=action value="|
#     . $locale->text('Update Dataset') . qq|">
print qq| <input type=submit class=submit name=action value="|
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
  call_sub($form->{"nextsub"});
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
  my $field_id = 0;
  foreach $key (sort keys %needsupdate) {
    if ($needsupdate{$key} ne $form->{dbversion}) {
      $upd .= qq|<input id="$field_id" name="db$key" type="checkbox" value="1" checked> $key\n|;
      $form->{dbupdate} .= "db$key ";
      $field_id++;
    }
  }

  chop $form->{dbupdate};

  if ($form->{dbupdate}) {

    print qq|
<table width=100%>
<form method=post action=$form->{script}>

<input type=hidden name="dbdriver"  value="$form->{dbdriver}">
<input type=hidden name="dbhost"    value="$form->{dbhost}">
<input type=hidden name="dbport"    value="$form->{dbport}">
<input type=hidden name="dbuser"    value="$form->{dbuser}">
<input type=hidden name="dbpasswd"  value="$form->{dbpasswd}">
<input type=hidden name="dbdefault" value="$form->{dbdefault}">

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

<input name=callback type=hidden value="$form->{script}?action=list_users&rpw=$form->{rpw}">

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
  $form->{"stylesheet"} = "lx-office-erp.css";
  $form->{"title"} = $main::locale->text("Dataset upgrade");
  $form->header();
  my $dbname =
    join(" ",
         map({ s/\s//g; s/^db//; $_; }
             grep({ $form->{$_} }
                  split(/\s+/, $form->{"dbupdate"}))));
  print($form->parse_html_template("dbupgrade/header",
                                   { "dbname" => $dbname }));

  User->dbupdate(\%$form);

  print qq|
<hr>

| . $locale->text('Dataset updated!') . qq|

<br>

<a id="enddatasetupdate" href="admin.pl?action=login&| .
join("&", map({ "$_=" . $form->escape($form->{$_}); } qw(rpw))) .
qq|">| . $locale->text("Continue") . qq|</a>|;

}

sub create_dataset {
  $form->{dbsources} = join " ", map { "[${_}]" } sort User->dbsources(\%$form);

  $form->{CHARTS} = [];

  opendir SQLDIR, "sql/." or $form - error($!);
  foreach $item (sort grep /-chart\.sql\z/, readdir SQLDIR) {
    next if ($item eq 'Default-chart.sql');
    $item =~ s/-chart\.sql//;
    push @{ $form->{CHARTS} }, { "name"     => $item,
                                 "selected" => $item eq "Germany-DATEV-SKR03EU" };
  }
  closedir SQLDIR;

  my $default_charset = $dbcharset;
  $default_charset ||= Common::DEFAULT_CHARSET;

  $form->{DBENCODINGS} = [];

  foreach my $encoding (@Common::db_encodings) {
    push @{ $form->{DBENCODINGS} }, { "dbencoding" => $encoding->{dbencoding},
                                      "label"      => $encoding->{label},
                                      "selected"   => $encoding->{charset} eq $default_charset };
  }

  $form->{title} =
      "Lx-Office ERP "
    . $locale->text('Database Administration') . " / "
    . $locale->text('Create Dataset');

  $form->header();
  print $form->parse_html_template("admin/create_dataset");
}

sub dbcreate {
  $form->isblank("db", $locale->text('Dataset missing!'));

  User->dbcreate(\%$form);

  $form->{title} =
      "Lx-Office ERP "
    . $locale->text('Database Administration') . " / "
    . $locale->text('Create Dataset');

  $form->header();
  print $form->parse_html_template("admin/dbcreate");
}

sub delete_dataset {
  @dbsources = User->dbsources_unused(\%$form, $memberfile);
  $form->error($locale->text('Nothing to delete!')) unless @dbsources;

  $form->{title} =
      "Lx-Office ERP "
    . $locale->text('Database Administration') . " / "
    . $locale->text('Delete Dataset');
  $form->{DBSOURCES} = [ map { { "name", $_ } } sort @dbsources ];

  $form->header();
  print $form->parse_html_template("admin/delete_dataset");
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

  $form->header();
  print $form->parse_html_template("admin/dbdelete");
}

sub unlock_system {

  unlink "$userspath/nologin";

  $form->{callback} =
    "$form->{script}?action=list_users&rpw=$root->{password}";

  $form->redirect($locale->text('Lockfile removed!'));

}

sub lock_system {

  open(FH, ">$userspath/nologin")
    or $form->error($locale->text('Cannot create Lock!'));
  close(FH);

  $form->{callback} =
    "$form->{script}?action=list_users&rpw=$root->{password}";

  $form->redirect($locale->text('Lockfile created!'));

}
