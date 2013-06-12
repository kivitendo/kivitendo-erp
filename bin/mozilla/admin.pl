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
use Encode;
use English qw(-no_match_vars);
use Fcntl;
use File::Copy;
use File::Find;
use File::Spec;
use Cwd;
use IO::Dir;
use IO::File;
use POSIX qw(strftime);
use Sys::Hostname;

use SL::Auth;
use SL::Auth::PasswordPolicy;
use SL::DB::AuthClient;
use SL::DB::AuthUser;
use SL::Form;
use SL::Iconv;
use SL::Mailer;
use SL::User;
use SL::Common;
use SL::Inifile;
use SL::DBUpgrade2;
use SL::DBUtils;
use SL::Template;

require "bin/mozilla/common.pl";

use strict;

# parserhappy(R):

#  $locale->text('periodic')
#  $locale->text('income')
#  $locale->text('perpetual')
#  $locale->text('balance')

our $cgi;
our $form;
our $locale;
our $auth;

sub run {
  $::lxdebug->enter_sub;
  my $session_result = shift;

  $form   = $::form;
  $locale = $::locale;
  $auth   = $::auth;

  $::request->{layout} = SL::Layout::Dispatcher->new(style => 'admin');
  $::request->{layout}->use_stylesheet("lx-office-erp.css");
  $form->{favicon}    = "favicon.ico";

  if ($form->{action}) {
    if ($auth->authenticate_root($form->{'{AUTH}admin_password'}) != $auth->OK()) {
      $auth->punish_wrong_login;
      $form->{error} = $locale->text('Incorrect password!');
      $auth->delete_session_value('admin_password');
      adminlogin();
    } else {
      if ($auth->session_tables_present()) {
        delete $::form->{'{AUTH}admin_password'};
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

  $form->{title} = qq|kivitendo $form->{version} | . $locale->text('Administration');

  $form->header();
  print $form->parse_html_template('admin/adminlogin');
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

  $form->{title}     = "kivitendo / " . $locale->text('Database Administration');

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

  $form->{title}        = "kivitendo " . $locale->text('Database Administration') . " / " . $locale->text('Update Dataset');

  my @need_updates      = User->dbneedsupdate($form);
  $form->{NEED_UPDATES} = \@need_updates;
  $form->{ALL_UPDATED}  = !scalar @need_updates;

  $form->header();
  print $form->parse_html_template("admin/update_dataset");
}

sub dbupdate {
  my $form            = $main::form;
  my $locale          = $main::locale;

  $::request->{layout}->use_stylesheet("lx-office-erp.css");
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

  tie my %dir_h, 'IO::Dir', 'sql/';
  foreach my $item (map { s/-chart\.sql$//; $_ } sort grep { /-chart\.sql\z/ && !/Default-chart.sql\z/ } keys %dir_h) {
    push @{ $form->{CHARTS} }, { name     => $item,
                                 selected => $item eq "Germany-DATEV-SKR03EU" };
  }

  $form->{ACCOUNTING_METHODS}    = [ map { { name => $_, selected => $_ eq 'cash'     } } qw(accrual cash)       ];
  $form->{INVENTORY_SYSTEMS}     = [ map { { name => $_, selected => $_ eq 'periodic' } } qw(perpetual periodic) ];
  $form->{PROFIT_DETERMINATIONS} = [ map { { name => $_, selected => $_ eq 'income'   } } qw(balance income)     ];

  my $default_charset = $::lx_office_conf{system}->{dbcharset} || Common::DEFAULT_CHARSET;

  my $cluster_encoding = User->dbclusterencoding($form);
  if ($cluster_encoding && ($cluster_encoding =~ m/^(?:UTF-?8|UNICODE)$/i)) {
    if ($::lx_office_conf{system}->{dbcharset} !~ m/^UTF-?8$/i) {
      $form->show_generic_error($locale->text('The selected  PostgreSQL installation uses UTF-8 as its encoding. ' .
                                              'Therefore you have to configure kivitendo to use UTF-8 as well.'),
                                'back_button' => 1);
    }

    $form->{FORCE_DBENCODING} = 'UNICODE';

  } else {
    $form->{DBENCODINGS} = [ map { { %{$_}, selected => $_->{charset} eq $default_charset } } @Common::db_encodings ];
  }

  $form->{title} = "kivitendo " . $locale->text('Database Administration') . " / " . $locale->text('Create Dataset');

  $form->header();
  print $form->parse_html_template("admin/create_dataset");
}

sub dbcreate {
  my $form   = $main::form;
  my $locale = $main::locale;

  $form->isblank("db", $locale->text('Dataset missing!'));
  $form->isblank("defaultcurrency", $locale->text('Default currency missing!'));

  User->dbcreate(\%$form);

  $form->{title} = "kivitendo " . $locale->text('Database Administration') . " / " . $locale->text('Create Dataset');

  $form->header();
  print $form->parse_html_template("admin/dbcreate");
}

sub delete_dataset {
  my $form      = $main::form;
  my $locale    = $main::locale;

  my @dbsources = User->dbsources_unused($form);
  $form->error($locale->text('Nothing to delete!')) unless @dbsources;

  $form->{title}     = "kivitendo " . $locale->text('Database Administration') . " / " . $locale->text('Delete Dataset');
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

  $form->{title} = "kivitendo " . $locale->text('Database Administration') . " / " . $locale->text('Delete Dataset');
  $form->header();
  print $form->parse_html_template("admin/dbdelete");
}

sub backup_dataset {
  my $form       = $main::form;
  my $locale     = $main::locale;

  $form->{title} = "kivitendo " . $locale->text('Database Administration') . " / " . $locale->text('Backup Dataset');

  if ($::lx_office_conf{applications}->{pg_dump} eq "DISABLED") {
    $form->error($locale->text('Database backups and restorations are disabled in the configuration.'));
  }

  my @dbsources         = sort User->dbsources($form);
  $form->{DATABASES}    = [ map { { "dbname" => $_ } } @dbsources ];
  $form->{NO_DATABASES} = !scalar @dbsources;

  my $username  = getpwuid $UID || "unknown-user";
  my $hostname  = hostname() || "unknown-host";
  $form->{from} = "kivitendo Admin <${username}\@${hostname}>";

  $form->header();
  print $form->parse_html_template("admin/backup_dataset");
}

sub backup_dataset_start {
  my $form       = $main::form;
  my $locale     = $main::locale;

  $form->{title} = "kivitendo " . $locale->text('Database Administration') . " / " . $locale->text('Backup Dataset');

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

    $form->{title} = "kivitendo " . $locale->text('Database Administration') . " / " . $locale->text('Backup Dataset');

    $form->header();
    print $form->parse_html_template("admin/backup_dataset_email_done");
  }
}

sub restore_dataset {
  my $form       = $main::form;
  my $locale     = $main::locale;

  $form->{title} = "kivitendo " . $locale->text('Database Administration') . " / " . $locale->text('Restore Dataset');

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

  $form->{title} = "kivitendo " . $locale->text('Database Administration') . " / " . $locale->text('Restore Dataset');

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

sub _search_templates {
  my %templates = SL::Template->available_templates;

  return ($templates{print_templates}, $templates{master_templates});
}

1;
