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

use DBI;
use CGI;
use Encode;
use English qw(-no_match_vars);
use Fcntl;
use File::Copy;
use IO::File;
use POSIX qw(strftime);
use Sys::Hostname;

use SL::Auth;
use SL::Auth::PasswordPolicy;
use SL::Form;
use SL::Iconv;
use SL::Mailer;
use SL::User;
use SL::Common;
use SL::Inifile;
use SL::DBUpgrade2;
use SL::DBUtils;

require "bin/mozilla/common.pl";
require "bin/mozilla/admin_groups.pl";
require "bin/mozilla/admin_printer.pl";

use strict;

our $cgi;
our $form;
our $locale;
our $auth;

sub run {
  $::lxdebug->enter_sub;
  my $session_result = shift;

  $cgi    = $::cgi;
  $form   = $::form;
  $locale = $::locale;
  $auth   = $::auth;

  $::auth->store_root_credentials_in_session($form->{rpw}) if $session_result == SL::Auth->SESSION_OK;

  $form->{stylesheet} = "lx-office-erp.css";
  $form->{favicon}    = "favicon.ico";

  if ($form->{action}) {
    if ($auth->authenticate_root($form->{rpw}) != $auth->OK()) {
      $form->{error_message} = $locale->text('Incorrect Password!');
      $auth->delete_session_value('rpw');
      adminlogin();
    } else {
      if ($auth->session_tables_present()) {
        $::auth->store_root_credentials_in_session($::form->{rpw});
        delete $::form->{rpw};
        _apply_dbupgrade_scripts();
      }

      call_sub($locale->findsub($form->{action}));
    }
  } else {
    # if there are no drivers bail out
    $form->error($locale->text('No Database Drivers available!'))
      unless (User->dbdrivers);

    adminlogin();
  }
  $::lxdebug->leave_sub;
}

sub adminlogin {
  my $form   = $main::form;
  my $locale = $main::locale;

  $form->{title} = qq|Lx-Office ERP $form->{version} | . $locale->text('Administration');

  $form->header();
  print $form->parse_html_template('admin/adminlogin');
}

sub login {
  check_auth_db_and_tables();
  list_users();
}

sub logout {
  $main::auth->destroy_session();
  adminlogin();
}

sub check_auth_db_and_tables {
  my $form   = $main::form;
  my $locale = $main::locale;

  my %params;

  map { $params{"db_${_}"} = $main::auth->{DB_config}->{$_} } keys %{ $auth->{DB_config} };

  if (!$main::auth->check_database()) {
    $form->{title} = $locale->text('Authentification database creation');
    $form->header();
    print $form->parse_html_template('admin/check_auth_database', \%params);

    ::end_of_request();
  }

  if (!$main::auth->check_tables()) {
    $form->{title} = $locale->text('Authentification tables creation');
    $form->header();
    print $form->parse_html_template('admin/check_auth_tables', \%params);

    ::end_of_request();
  }

  my $memberfile = $::lx_office_conf{paths}->{memberfile};
  if (-f $memberfile) {
    my $memberdir = "";

    if ($memberfile =~ m|^.*/|) {
      $memberdir = $&;
    }

    my $backupdir = "${memberdir}member-file-migration";

    $form->{title} = $locale->text('User data migration');
    $form->header();
    print $form->parse_html_template('admin/user_migration', { 'memberfile' => $memberfile,
                                                               'backupdir'  => $backupdir });

    ::end_of_request();
  }
}

sub create_auth_db {
  my $form = $main::form;

  $main::auth->create_database('superuser'          => $form->{db_superuser},
                               'superuser_password' => $form->{db_superuser_password},
                               'template'           => $form->{db_template});
  login();
}

sub create_auth_tables {
  my $form   = $main::form;
  my $locale = $main::locale;

  $main::auth->create_tables();
  $main::auth->set_session_value('rpw', $form->{rpw});
  $main::auth->create_or_refresh_session();

  my $memberfile = $::lx_office_conf{paths}->{memberfile};
  if (!-f $memberfile) {
    # New installation -- create a standard group with full access
    my %members;
    my $group = {
      'name'        => $locale->text('Full Access'),
      'description' => $locale->text('Full access to all functions'),
      'rights'      => { map { $_ => 1 } SL::Auth::all_rights() },
      'members'     => [ map { $_->{id} } values %members ],
    };

    $main::auth->save_group($group);
  }

  _apply_dbupgrade_scripts();
  login();
}

sub migrate_users {
  $main::lxdebug->enter_sub();

  my $form      = $main::form;
  my $locale    = $main::locale;

  my $memberdir = "";

  my $memberfile = $::lx_office_conf{paths}->{memberfile};
  if ($memberfile =~ m|^.*/|) {
    $memberdir = $&;
  }

  my $backupdir = "${memberdir}member-file-migration";

  if (! -d $backupdir && !mkdir $backupdir, 0700) {
    $form->error(sprintf($locale->text('The directory "%s" could not be created:\n%s'), $backupdir, $!));
  }

  copy $memberfile, "users/member-file-migration/members";

  my $in = IO::File->new($memberfile, "r");

  $form->error($locale->text('Could not open the old memberfile.')) if (!$in);

  my (%members, $login);

  while (<$in>) {
    chomp;

    next if (m/^\s*\#/);

    if (m/^\[.*\]/) {
      $login = $_;
      $login =~ s/(\[|\])//g;
      $login =~ s/^\s*//;
      $login =~ s/\s*$//;

      $members{$login} = { "login" => $login };
      next;
    }

    if ($login && m/=/) {
      my ($key, $value) = split m/\s*=\s*/, $_, 2;
      $key   =~ s|^\s*||;
      $value =~ s|\s*$||;

      $value =~ s|\\r||g;
      $value =~ s|\\n|\n|g;

      $members{$login}->{$key} = $value;
    }
  }

  $in->close();

  delete $members{"root login"};

  map { $_->{dbpasswd} = unpack 'u', $_->{dbpasswd} } values %members;

  while (my ($login, $params) = each %members) {
    $main::auth->save_user($login, %{ $params });
    $main::auth->change_password($login, $params->{password}, 1);

    my $conf_file = "${memberdir}${login}.conf";

    if (-f $conf_file) {
      copy   $conf_file, "${backupdir}/${login}.conf";
      unlink $conf_file;
    }
  }

  unlink $memberfile;

  my @member_list = sort { lc $a->{login} cmp lc $b->{login} } values %members;

  $form->{title} = $locale->text('User data migration');
  $form->header();
  print $form->parse_html_template('admin/user_migration_done', { 'MEMBERS' => \@member_list });

  $main::lxdebug->leave_sub();
}

sub create_standard_group_ask {
  my $form   = $main::form;
  my $locale = $main::locale;

  $form->{title} = $locale->text('Create a standard group');

  $form->header();
  print $form->parse_html_template("admin/create_standard_group_ask");
}

sub create_standard_group {
  my $form    = $main::form;
  my $locale  = $main::locale;

  my %members = $main::auth->read_all_users();

  my $groups  = $main::auth->read_groups();

  foreach my $group (values %{$groups}) {
    if (($form->{group_id} != $group->{id})
        && ($form->{name} eq $group->{name})) {
      $form->show_generic_error($locale->text("A group with that name does already exist."));
    }
  }

  my $group = {
    'name'        => $locale->text('Full Access'),
    'description' => $locale->text('Full access to all functions'),
    'rights'      => { map { $_ => 1 } SL::Auth::all_rights() },
    'members'     => [ map { $_->{id} } values %members ],
  };

  $main::auth->save_group($group);

  user_migration_complete(1);
}

sub dont_create_standard_group {
  user_migration_complete(0);
}

sub user_migration_complete {
  my $standard_group_created = shift;

  my $form                   = $main::form;
  my $locale                 = $main::locale;

  $form->{title} = $locale->text('User migration complete');
  $form->header();

  print $form->parse_html_template('admin/user_migration_complete', { 'standard_group_created' => $standard_group_created });
}

sub list_users {
  my $form    = $main::form;
  my $locale  = $main::locale;

  my %members = $main::auth->read_all_users();

  delete $members{"root login"};

  for (values %members) {
    $_->{templates} =~ s|.*/||;
    $_->{login_url} =  $::locale->is_utf8 ? Encode::encode('utf-8-strict', $_->{login}) : $_->{login_url};
  }

  $form->{title}   = "Lx-Office ERP " . $locale->text('Administration');
  $form->{LOCKED}  = -e _nologin_file_name();
  $form->{MEMBERS} = [ @members{sort { lc $a cmp lc $b } keys %members} ];

  $form->header();
  print $form->parse_html_template("admin/list_users");
}

sub add_user {
  my $form         = $main::form;
  my $locale       = $main::locale;

  $form->{title}   = "Lx-Office ERP " . $locale->text('Administration') . " / " . $locale->text('Add User');

# Note: Menu Style 'v3' is not compatible to all browsers!
# "menustyle"    => "old" sets the HTML Menu to default.
  my $myconfig     = {
    "vclimit"      => 200,
    "countrycode"  => "de",
    "numberformat" => "1.000,00",
    "dateformat"   => "dd.mm.yy",
    "stylesheet"   => "lx-office-erp.css",
    "menustyle"    => "old",
    dbport         => $::auth->{DB_config}->{port} || 5432,
    dbuser         => $::auth->{DB_config}->{user} || 'lxoffice',
    dbhost         => $::auth->{DB_config}->{host} || 'localhost',
  };


  edit_user_form($myconfig);
}

sub edit_user {
  my $form       = $main::form;
  my $locale     = $main::locale;

  $form->{title} = "Lx-Office ERP " . $locale->text('Administration') . " / " . $locale->text('Edit User');
  $form->{edit}  = 1;

  $form->isblank("login", $locale->text("The login is missing."));

  # get user
  my $myconfig = new User($form->{login});

  # strip basedir from templates directory
  $myconfig->{templates} =~ s|.*/||;

  edit_user_form($myconfig);
}

sub edit_user_form {
  my ($myconfig) = @_;

  my $form       = $main::form;
  my $locale     = $main::locale;

  my @valid_dateformats = qw(mm-dd-yy mm/dd/yy dd-mm-yy dd/mm/yy dd.mm.yy yyyy-mm-dd);
  $form->{ALL_DATEFORMATS} = [ map { { "format" => $_, "selected" => $_ eq $myconfig->{dateformat} } } @valid_dateformats ];

  my @valid_numberformats = ('1,000.00', '1000.00', '1.000,00', '1000,00');
  $form->{ALL_NUMBERFORMATS} = [ map { { "format" => $_, "selected" => $_ eq $myconfig->{numberformat} } } @valid_numberformats ];

  my %countrycodes = User->country_codes;
  $form->{ALL_COUNTRYCODES} = [];
  foreach my $countrycode (sort { $countrycodes{$a} cmp $countrycodes{$b} } keys %countrycodes) {
    push @{ $form->{ALL_COUNTRYCODES} }, { "value"    => $countrycode,
                                           "name"     => $countrycodes{$countrycode},
                                           "selected" => $countrycode eq $myconfig->{countrycode} };
  }

  # is there a templates basedir
  if (!-d $::lx_office_conf{paths}->{templates}) {
    $form->error(sprintf($locale->text("The directory %s does not exist."), $::lx_office_conf{paths}->{templates}));
  }

  opendir TEMPLATEDIR, $::lx_office_conf{paths}->{templates} or $form->error($::lx_office_conf{paths}->{templates} . " : $ERRNO");
  my @all     = readdir(TEMPLATEDIR);
  my @alldir  = sort grep { -d ($::lx_office_conf{paths}->{templates} . "/$_") && !/^\.\.?$/ } @all;
  my @allhtml = sort grep { -f ($::lx_office_conf{paths}->{templates} . "/$_") &&  /\.html$/ } @all;
  closedir TEMPLATEDIR;

  @alldir = grep !/\.(html|tex|sty|odt|xml|txb)$/, @alldir;
  @alldir = grep !/^(webpages|\.svn)$/, @alldir;

  @allhtml = reverse grep !/Default/, @allhtml;
  push @allhtml, 'Default';
  @allhtml = reverse @allhtml;

  $form->{ALL_TEMPLATES} = [ map { { "name", => $_, "selected" => $_ eq $myconfig->{templates} } } @alldir ];

  my $lastitem = $allhtml[0];
  $lastitem =~ s/-.*//g;
  $form->{ALL_MASTER_TEMPLATES} = [ { "name" => $lastitem, "selected" => $lastitem eq "German" } ];
  foreach my $item (@allhtml) {
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

  my $groups = [];

  if ($form->{edit}) {
    my $user_id    = $main::auth->get_user_id($form->{login});
    my $all_groups = $main::auth->read_groups();

    foreach my $group (values %{ $all_groups }) {
      push @{ $groups }, $group if (grep { $user_id == $_ } @{ $group->{members} });
    }

    $groups = [ sort { lc $a->{name} cmp lc $b->{name} } @{ $groups } ];
  }

  $form->{CAN_CHANGE_PASSWORD} = $main::auth->can_change_password();

  $form->header();
  print $form->parse_html_template("admin/edit_user", { 'GROUPS' => $groups });
}

sub save_user {
  my $form          = $main::form;
  my $locale        = $main::locale;

  $form->{dbdriver} = 'Pg';

  # no spaces allowed in login name
  $form->{login} =~ s|\s||g;
  $form->isblank("login", $locale->text('Login name missing!'));

  # check for duplicates
  if (!$form->{edit}) {
    my %members = $main::auth->read_all_users();
    if ($members{$form->{login}}) {
      $form->show_generic_error($locale->text('Another user with the login #1 does already exist.', $form->{login}), 'back_button' => 1);
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
  if (!-d $::lx_office_conf{paths}->{templates}) {
    $form->error(sprintf($locale->text("The directory %s does not exist."), $::lx_office_conf{paths}->{templates}));
  }

  # add base directory to $form->{templates}
  $form->{templates} =~ s|.*/||;
  $form->{templates} =  $::lx_office_conf{paths}->{templates} . "/$form->{templates}";

  my $myconfig = new User($form->{login});

  $form->isblank("dbname", $locale->text('Dataset missing!'));
  $form->isblank("dbuser", $locale->text('Database User missing!'));

  foreach my $item (keys %{$form}) {
    $myconfig->{$item} = $form->{$item};
  }

  delete $myconfig->{stylesheet};
  if ($form->{userstylesheet}) {
    $myconfig->{stylesheet} = $form->{userstylesheet};
  }

  $myconfig->save_member();

  $form->{templates}       =~ s|.*/||;
  $form->{templates}       =  $::lx_office_conf{paths}->{templates} . "/$form->{templates}";
  $form->{mastertemplates} =~ s|.*/||;

  # create user template directory and copy master files
  if (!-d "$form->{templates}") {
    umask(002);

    if (mkdir "$form->{templates}", oct("771")) {

      umask(007);

      # copy templates to the directory
      opendir TEMPLATEDIR, $::lx_office_conf{paths}->{templates} or $form->error($::lx_office_conf{paths}->{templates} . " : $ERRNO");
      my @templates = grep /$form->{mastertemplates}.*?\.(html|tex|sty|odt|xml|txb)$/,
        readdir TEMPLATEDIR;
      closedir TEMPLATEDIR;

      foreach my $file (@templates) {
        open(TEMP, $::lx_office_conf{paths}->{templates} . "/$file")
          or $form->error($::lx_office_conf{paths}->{templates} . "/$file : $ERRNO");

        $file =~ s/\Q$form->{mastertemplates}\E-//;
        open(NEW, ">$form->{templates}/$file")
          or $form->error("$form->{templates}/$file : $ERRNO");

        while (my $line = <TEMP>) {
          print NEW $line;
        }
        close(TEMP);
        close(NEW);
      }
    } else {
      $form->error("$ERRNO: $form->{templates}");
    }
  }

  # Add new user to his groups.
  if (ref $form->{new_user_group_ids} eq 'ARRAY') {
    my $all_groups = $main::auth->read_groups();
    my %user       = $main::auth->read_user($form->{login});

    foreach my $group_id (@{ $form->{new_user_group_ids} }) {
      my $group = $all_groups->{$group_id};

      next if !$group;

      push @{ $group->{members} }, $user{id};
      $main::auth->save_group($group);
    }
  }

  if ($main::auth->can_change_password()
      && defined $form->{new_password}
      && ($form->{new_password} ne '********')) {
    my $verifier = SL::Auth::PasswordPolicy->new;
    my $result   = $verifier->verify($form->{new_password}, 1);

    if ($result != SL::Auth::PasswordPolicy->OK()) {
      $form->error($::locale->text('The settings were saved, but the password was not changed.') . ' ' . join(' ', $verifier->errors($result)));
    }

    $main::auth->change_password($form->{login}, $form->{new_password});
  }

  $form->redirect($locale->text('User saved!'));
}

sub save_user_as_new {
  my $form       = $main::form;

  $form->{login} = $form->{new_user_login};
  delete @{$form}{qw(edit new_user_login)};

  save_user();
}

sub delete_user {
  my $form      = $main::form;
  my $locale    = $main::locale;

  my %members   = $main::auth->read_all_users();
  my $templates = $members{$form->{login}}->{templates};

  $main::auth->delete_user($form->{login});

  if ($templates) {
    my $templates_in_use = 0;

    foreach my $login (keys %members) {
      next if $form->{login} eq $login;
      next if $members{$login}->{templates} ne $templates;
      $templates_in_use = 1;
      last;
    }

    if (!$templates_in_use && -d $templates) {
      unlink <$templates/*>;
      rmdir $templates;
    }
  }

  $form->redirect($locale->text('User deleted!'));

}

sub login_name {
  my $login = shift;

  $login =~ s/\[\]//g;
  return ($login) ? $login : undef;

}

sub get_value {
  my $line           = shift;
  my ($null, $value) = split(/=/, $line, 2);

  # remove comments
  $value =~ s/\s#.*//g;

  # remove any trailing whitespace
  $value =~ s/^\s*(.*?)\s*$/$1/;

  $value;
}

sub pg_database_administration {
  my $form = $main::form;

  $form->{dbdriver} = 'Pg';
  dbselect_source();

}

sub dbselect_source {
  my $form           = $main::form;
  my $locale         = $main::locale;

  $form->{dbport}    = $::auth->{DB_config}->{port} || 5432;
  $form->{dbuser}    = $::auth->{DB_config}->{user} || 'lxoffice';
  $form->{dbdefault} = 'template1';
  $form->{dbhost}    = $::auth->{DB_config}->{host} || 'localhost';

  $form->{title}     = "Lx-Office ERP / " . $locale->text('Database Administration');

  # Intentionnaly disabled unless fixed to work with the authentication DB.
  $form->{ALLOW_DBBACKUP} = 0; # "$pg_dump_exe" ne "DISABLED";

  $form->header();
  print $form->parse_html_template("admin/dbadmin");
}

sub test_db_connection {
  my $form   = $main::form;
  my $locale = $main::locale;

  $form->{dbdriver} = 'Pg';
  User::dbconnect_vars($form, $form->{dbname});

  my $dbh = DBI->connect($form->{dbconnect}, $form->{dbuser}, $form->{dbpasswd});

  $form->{connection_ok} = $dbh ? 1 : 0;
  $form->{errstr}        = $DBI::errstr;

  $dbh->disconnect() if ($dbh);

  $form->{title} = $locale->text('Database Connection Test');
  $form->header();
  print $form->parse_html_template("admin/test_db_connection");
}

sub continue {
  call_sub($main::form->{"nextsub"});
}

sub update_dataset {
  my $form              = $main::form;
  my $locale            = $main::locale;

  $form->{title}        = "Lx-Office ERP " . $locale->text('Database Administration') . " / " . $locale->text('Update Dataset');

  my @need_updates      = User->dbneedsupdate($form);
  $form->{NEED_UPDATES} = \@need_updates;
  $form->{ALL_UPDATED}  = !scalar @need_updates;

  $form->header();
  print $form->parse_html_template("admin/update_dataset");
}

sub dbupdate {
  my $form            = $main::form;
  my $locale          = $main::locale;

  $form->{stylesheet} = "lx-office-erp.css";
  $form->{title}      = $locale->text("Dataset upgrade");
  $form->header();

  my $rowcount           = $form->{rowcount} * 1;
  my @update_rows        = grep { $form->{"update_$_"} } (1 .. $rowcount);
  $form->{NOTHING_TO_DO} = !scalar @update_rows;
  my $saved_form         = save_form();

  $| = 1;

  print $form->parse_html_template("admin/dbupgrade_all_header");

  foreach my $i (@update_rows) {
    restore_form($saved_form);

    %::myconfig = ();
    map { $form->{$_} = $::myconfig{$_} = $form->{"${_}_${i}"} } qw(dbname dbdriver dbhost dbport dbuser dbpasswd);

    print $form->parse_html_template("admin/dbupgrade_header");

    $form->{dbupdate}        = $form->{dbname};
    $form->{$form->{dbname}} = 1;

    User->dbupdate($form);
    User->dbupdate2($form, SL::DBUpgrade2->new(form => $form, dbdriver => $form->{dbdriver})->parse_dbupdate_controls);

    print $form->parse_html_template("admin/dbupgrade_footer");
  }

  print $form->parse_html_template("admin/dbupgrade_all_done");
}

sub create_dataset {
  my $form           = $main::form;
  my $locale         = $main::locale;

  $form->{dbsources} = join " ", map { "[${_}]" } sort User->dbsources($form);

  $form->{CHARTS}    = [];

  opendir SQLDIR, "sql/." or $form->error($ERRNO);
  foreach my $item (sort grep /-chart\.sql\z/, readdir SQLDIR) {
    next if ($item eq 'Default-chart.sql');
    $item =~ s/-chart\.sql//;
    push @{ $form->{CHARTS} }, { "name"     => $item,
                                 "selected" => $item eq "Germany-DATEV-SKR03EU" };
  }
  closedir SQLDIR;

  my $default_charset = $::lx_office_conf{system}->{dbcharset};
  $default_charset ||= Common::DEFAULT_CHARSET;

  my $cluster_encoding = User->dbclusterencoding($form);
  if ($cluster_encoding && ($cluster_encoding =~ m/^(?:UTF-?8|UNICODE)$/i)) {
    if ($::lx_office_conf{system}->{dbcharset} !~ m/^UTF-?8$/i) {
      $form->show_generic_error($locale->text('The selected  PostgreSQL installation uses UTF-8 as its encoding. ' .
                                              'Therefore you have to configure Lx-Office to use UTF-8 as well.'),
                                'back_button' => 1);
    }

    $form->{FORCE_DBENCODING} = 'UNICODE';

  } else {
    $form->{DBENCODINGS} = [];

    foreach my $encoding (@Common::db_encodings) {
      push @{ $form->{DBENCODINGS} }, { "dbencoding" => $encoding->{dbencoding},
                                        "label"      => $encoding->{label},
                                        "selected"   => $encoding->{charset} eq $default_charset };
    }
  }

  $form->{title} = "Lx-Office ERP " . $locale->text('Database Administration') . " / " . $locale->text('Create Dataset');

  $form->header();
  print $form->parse_html_template("admin/create_dataset");
}

sub dbcreate {
  my $form   = $main::form;
  my $locale = $main::locale;

  $form->isblank("db", $locale->text('Dataset missing!'));

  User->dbcreate(\%$form);

  $form->{title} = "Lx-Office ERP " . $locale->text('Database Administration') . " / " . $locale->text('Create Dataset');

  $form->header();
  print $form->parse_html_template("admin/dbcreate");
}

sub delete_dataset {
  my $form      = $main::form;
  my $locale    = $main::locale;

  my @dbsources = User->dbsources_unused($form);
  $form->error($locale->text('Nothing to delete!')) unless @dbsources;

  $form->{title}     = "Lx-Office ERP " . $locale->text('Database Administration') . " / " . $locale->text('Delete Dataset');
  $form->{DBSOURCES} = [ map { { "name", $_ } } sort @dbsources ];

  $form->header();
  print $form->parse_html_template("admin/delete_dataset");
}

sub dbdelete {
  my $form   = $main::form;
  my $locale = $main::locale;

  if (!$form->{db}) {
    $form->error($locale->text('No Dataset selected!'));
  }

  User->dbdelete(\%$form);

  $form->{title} = "Lx-Office ERP " . $locale->text('Database Administration') . " / " . $locale->text('Delete Dataset');
  $form->header();
  print $form->parse_html_template("admin/dbdelete");
}

sub backup_dataset {
  my $form       = $main::form;
  my $locale     = $main::locale;

  $form->{title} = "Lx-Office ERP " . $locale->text('Database Administration') . " / " . $locale->text('Backup Dataset');

  if ($::lx_office_conf{applications}->{pg_dump} eq "DISABLED") {
    $form->error($locale->text('Database backups and restorations are disabled in the configuration.'));
  }

  my @dbsources         = sort User->dbsources($form);
  $form->{DATABASES}    = [ map { { "dbname" => $_ } } @dbsources ];
  $form->{NO_DATABASES} = !scalar @dbsources;

  my $username  = getpwuid $UID || "unknown-user";
  my $hostname  = hostname() || "unknown-host";
  $form->{from} = "Lx-Office Admin <${username}\@${hostname}>";

  $form->header();
  print $form->parse_html_template("admin/backup_dataset");
}

sub backup_dataset_start {
  my $form       = $main::form;
  my $locale     = $main::locale;

  $form->{title} = "Lx-Office ERP " . $locale->text('Database Administration') . " / " . $locale->text('Backup Dataset');

  my $pg_dump_exe = $::lx_office_conf{applications}->{pg_dump} || "pg_dump";

  if ("$pg_dump_exe" eq "DISABLED") {
    $form->error($locale->text('Database backups and restorations are disabled in the configuration.'));
  }

  $form->isblank("dbname", $locale->text('The dataset name is missing.'));
  $form->isblank("to", $locale->text('The email address is missing.')) if $form->{destination} eq "email";

  my $tmpdir = "/tmp/lx_office_backup_" . Common->unique_id();
  mkdir $tmpdir, 0700 || $form->error($locale->text('A temporary directory could not be created:') . " $ERRNO");

  my $pgpass = IO::File->new("${tmpdir}/.pgpass", O_WRONLY | O_CREAT, 0600);

  if (!$pgpass) {
    unlink $tmpdir;
    $form->error($locale->text('A temporary file could not be created:') . " $ERRNO");
  }

  print $pgpass "$form->{dbhost}:$form->{dbport}:$form->{dbname}:$form->{dbuser}:$form->{dbpasswd}\n";
  $pgpass->close();

  $ENV{HOME} = $tmpdir;

  my @args = ("-Ft", "-c", "-o", "-h", $form->{dbhost}, "-U", $form->{dbuser});
  push @args, ("-p", $form->{dbport}) if ($form->{dbport});
  push @args, $form->{dbname};

  my $cmd  = "$pg_dump_exe " . join(" ", map { s/\\/\\\\/g; s/\"/\\\"/g; $_ } @args);
  my $name = "dataset_backup_$form->{dbname}_" . strftime("%Y%m%d", localtime()) . ".tar";

  if ($form->{destination} ne "email") {
    my $in = IO::File->new("$cmd |");

    if (!$in) {
      unlink "${tmpdir}/.pgpass";
      rmdir $tmpdir;

      $form->error($locale->text('The pg_dump process could not be started.'));
    }

    print "content-type: application/x-tar\n";
    print "content-disposition: attachment; filename=\"${name}\"\n\n";

    while (my $line = <$in>) {
      print $line;
    }

    $in->close();

    unlink "${tmpdir}/.pgpass";
    rmdir $tmpdir;

  } else {
    my $tmp = $tmpdir . "/dump_" . Common::unique_id();

    if (system("$cmd > $tmp") != 0) {
      unlink "${tmpdir}/.pgpass", $tmp;
      rmdir $tmpdir;

      $form->error($locale->text('The pg_dump process could not be started.'));
    }

    my $mail = new Mailer;

    map { $mail->{$_} = $form->{$_} } qw(from to cc subject message);

    $mail->{charset}     = $::lx_office_conf{system}->{dbcharset} || Common::DEFAULT_CHARSET;
    $mail->{attachments} = [ { "filename" => $tmp, "name" => $name } ];
    $mail->send();

    unlink "${tmpdir}/.pgpass", $tmp;
    rmdir $tmpdir;

    $form->{title} = "Lx-Office ERP " . $locale->text('Database Administration') . " / " . $locale->text('Backup Dataset');

    $form->header();
    print $form->parse_html_template("admin/backup_dataset_email_done");
  }
}

sub restore_dataset {
  my $form       = $main::form;
  my $locale     = $main::locale;

  $form->{title} = "Lx-Office ERP " . $locale->text('Database Administration') . " / " . $locale->text('Restore Dataset');

  if ($::lx_office_conf{applications}->{pg_restore} eq "DISABLED") {
    $form->error($locale->text('Database backups and restorations are disabled in the configuration.'));
  }

  my $default_charset   = $::lx_office_conf{system}->{dbcharset};
  $default_charset    ||= Common::DEFAULT_CHARSET;

  $form->{DBENCODINGS}  = [];

  foreach my $encoding (@Common::db_encodings) {
    push @{ $form->{DBENCODINGS} }, { "dbencoding" => $encoding->{dbencoding},
                                      "label"      => $encoding->{label},
                                      "selected"   => $encoding->{charset} eq $default_charset };
  }

  $form->header();
  print $form->parse_html_template("admin/restore_dataset");
}

sub restore_dataset_start {
  my $form       = $main::form;
  my $locale     = $main::locale;

  $form->{title} = "Lx-Office ERP " . $locale->text('Database Administration') . " / " . $locale->text('Restore Dataset');

  my $pg_restore_exe = $::lx_office_conf{applications}->{pg_restore} || "pg_restore";

  if ("$pg_restore_exe" eq "DISABLED") {
    $form->error($locale->text('Database backups and restorations are disabled in the configuration.'));
  }

  $form->isblank("new_dbname", $locale->text('The dataset name is missing.'));
  $form->isblank("content", $locale->text('No backup file has been uploaded.'));

  # Create temporary directories. Write the backup file contents to a temporary
  # file. Create a .pgpass file with the username and password for the pg_restore
  # utility.

  my $tmpdir = "/tmp/lx_office_backup_" . Common->unique_id();
  mkdir $tmpdir, 0700 || $form->error($locale->text('A temporary directory could not be created:') . " $ERRNO");

  my $pgpass = IO::File->new("${tmpdir}/.pgpass", O_WRONLY | O_CREAT, 0600);

  if (!$pgpass) {
    unlink $tmpdir;
    $form->error($locale->text('A temporary file could not be created:') . " $ERRNO");
  }

  print $pgpass "$form->{dbhost}:$form->{dbport}:$form->{new_dbname}:$form->{dbuser}:$form->{dbpasswd}\n";
  $pgpass->close();

  $ENV{HOME} = $tmpdir;

  my $tmp = $tmpdir . "/dump_" . Common::unique_id();
  my $tmpfile;

  if (substr($form->{content}, 0, 2) eq "\037\213") {
    $tmpfile = IO::File->new("| gzip -d > $tmp");
    $tmpfile->binary();

  } else {
    $tmpfile = IO::File->new($tmp, O_WRONLY | O_CREAT | O_BINARY, 0600);
  }

  if (!$tmpfile) {
    unlink "${tmpdir}/.pgpass";
    rmdir $tmpdir;

    $form->error($locale->text('A temporary file could not be created:') . " $ERRNO");
  }

  print $tmpfile $form->{content};
  $tmpfile->close();

  delete $form->{content};

  # Try to connect to the database. Find out if a database with the same name exists.
  # If yes, then drop the existing database. Create a new one with the name and encoding
  # given by the user.

  User::dbconnect_vars($form, "template1");

  my %myconfig = map { $_ => $form->{$_} } grep /^db/, keys %{ $form };
  my $dbh      = $form->dbconnect(\%myconfig) || $form->dberror();

  my ($query, $sth);

  $form->{new_dbname} =~ s|[^a-zA-Z0-9_\-]||g;

  $query = qq|SELECT COUNT(*) FROM pg_database WHERE datname = ?|;
  my ($count) = selectrow_query($form, $dbh, $query, $form->{new_dbname});
  if ($count) {
    do_query($form, $dbh, qq|DROP DATABASE $form->{new_dbname}|);
  }

  my $found = 0;
  foreach my $item (@Common::db_encodings) {
    if ($item->{dbencoding} eq $form->{dbencoding}) {
      $found = 1;
      last;
    }
  }
  $form->{dbencoding} = "LATIN9" unless $form->{dbencoding};

  do_query($form, $dbh, qq|CREATE DATABASE $form->{new_dbname} ENCODING ? TEMPLATE template0|, $form->{dbencoding});

  $dbh->disconnect();

  # Spawn pg_restore on the temporary file.

  my @args = ("-h", $form->{dbhost}, "-U", $form->{dbuser}, "-d", $form->{new_dbname});
  push @args, ("-p", $form->{dbport}) if ($form->{dbport});
  push @args, $tmp;

  my $cmd = "$pg_restore_exe " . join(" ", map { s/\\/\\\\/g; s/\"/\\\"/g; $_ } @args);

  my $in = IO::File->new("$cmd 2>&1 |");

  if (!$in) {
    unlink "${tmpdir}/.pgpass", $tmp;
    rmdir $tmpdir;

    $form->error($locale->text('The pg_restore process could not be started.'));
  }

  $English::AUTOFLUSH = 1;

  $form->header();
  print $form->parse_html_template("admin/restore_dataset_start_header");

  while (my $line = <$in>) {
    print $line;
  }
  $in->close();

  $form->{retval} = $CHILD_ERROR >> 8;
  print $form->parse_html_template("admin/restore_dataset_start_footer");

  unlink "${tmpdir}/.pgpass", $tmp;
  rmdir $tmpdir;
}

sub unlock_system {
  my $form   = $main::form;
  my $locale = $main::locale;

  unlink _nologin_file_name();;

  $form->{callback} = "admin.pl?action=list_users";

  $form->redirect($locale->text('Lockfile removed!'));

}

sub lock_system {
  my $form   = $main::form;
  my $locale = $main::locale;

  open(FH, ">" . _nologin_file_name())
    or $form->error($locale->text('Cannot create Lock!'));
  close(FH);

  $form->{callback} = "admin.pl?action=list_users";

  $form->redirect($locale->text('Lockfile created!'));

}

sub yes {
  call_sub($main::form->{yes_nextsub});
}

sub no {
  call_sub($main::form->{no_nextsub});
}

sub add {
  call_sub($main::form->{add_nextsub});
}

sub edit {
  my $form = $main::form;

  $form->{edit_nextsub} ||= 'edit_user';

  call_sub($form->{edit_nextsub});
}

sub delete {
  my $form     = $main::form;

  $form->{delete_nextsub} ||= 'delete_user';

  call_sub($form->{delete_nextsub});
}

sub save {
  my $form = $main::form;

  $form->{save_nextsub} ||= 'save_user';

  call_sub($form->{save_nextsub});
}

sub back {
  call_sub($main::form->{back_nextsub});
}

sub dispatcher {
  my $form   = $main::form;
  my $locale = $main::locale;

  foreach my $action (qw(create_standard_group dont_create_standard_group
                         save_user delete_user save_user_as_new)) {
    if ($form->{"action_${action}"}) {
      call_sub($action);
      return;
    }
  }

  call_sub($form->{default_action}) if ($form->{default_action});

  $form->error($locale->text('No action defined.'));
}

sub _apply_dbupgrade_scripts {
  ::end_of_request() if SL::DBUpgrade2->new(form => $::form, dbdriver => 'Pg', auth => 1)->apply_admin_dbupgrade_scripts(1);
}

sub _nologin_file_name {
  return $::lx_office_conf{paths}->{userspath} . '/nologin';
}

1;
