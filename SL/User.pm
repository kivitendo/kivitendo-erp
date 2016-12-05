#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 2001
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
#  Contributors:
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1335, USA.
#=====================================================================
#
# user related functions
#
#=====================================================================

package User;

use IO::File;
use Fcntl qw(:seek);

use SL::DB;
#use SL::Auth;
use SL::DB::AuthClient;
use SL::DB::Employee;
use SL::DBConnect;
use SL::DBUpgrade2;
use SL::DBUtils;
use SL::Iconv;
use SL::Inifile;
use SL::System::InstallationLock;
use SL::DefaultManager;

use strict;

use constant LOGIN_OK                      =>  0;
use constant LOGIN_BASIC_TABLES_MISSING    => -1;
use constant LOGIN_DBUPDATE_AVAILABLE      => -2;
use constant LOGIN_AUTH_DBUPDATE_AVAILABLE => -3;
use constant LOGIN_GENERAL_ERROR           => -4;

sub new {
  $main::lxdebug->enter_sub();

  my ($type, %params) = @_;

  my $self = {};

  if ($params{id} || $params{login}) {
    my %user_data = $main::auth->read_user(%params);
    map { $self->{$_} = $user_data{$_} } keys %user_data;
  }

  $main::lxdebug->leave_sub();

  bless $self, $type;
}

sub country_codes {
  $main::lxdebug->enter_sub();

  local *DIR;

  my %cc       = ();
  my @language = ();

  # scan the locale directory and read in the LANGUAGE files
  opendir(DIR, "locale");

  my @dir = grep(!/(^\.\.?$|\..*)/, readdir(DIR));

  foreach my $dir (@dir) {
    next unless open(my $fh, '<:encoding(UTF-8)', "locale/$dir/LANGUAGE");
    @language = <$fh>;
    close $fh;

    $cc{$dir} = "@language";
  }

  closedir(DIR);

  $main::lxdebug->leave_sub();

  return %cc;
}

sub login {
  my ($self, $form) = @_;

  return LOGIN_GENERAL_ERROR() if !$self->{login} || !$::auth->client;

  my %myconfig = $main::auth->read_user(login => $self->{login});

  # Auth DB upgrades available?
  my $dbupdater_auth = SL::DBUpgrade2->new(form => $form, auth => 1)->parse_dbupdate_controls;
  return LOGIN_AUTH_DBUPDATE_AVAILABLE() if $dbupdater_auth->unapplied_upgrade_scripts($::auth->dbconnect);

  # check if database is down
  my $dbh = SL::DB->client->dbh;

  # we got a connection, check the version
  my ($dbversion) = $dbh->selectrow_array(qq|SELECT version FROM defaults|);
  if (!$dbversion) {
    $dbh->disconnect;
    return LOGIN_BASIC_TABLES_MISSING();
  }

  $self->create_schema_info_table($form, $dbh);

  my $dbupdater        = SL::DBUpgrade2->new(form => $form)->parse_dbupdate_controls;
  my @unapplied_scripts = $dbupdater->unapplied_upgrade_scripts($dbh);
#   $dbh->disconnect;

  if (!@unapplied_scripts) {
    SL::DB::Manager::Employee->update_entries_for_authorized_users;
    return LOGIN_OK();
  }

  # Store the fact that we're applying database upgrades at the
  # moment. That way functions called from the layout modules that may
  # require updated tables can chose only to use basic features.
  $::request->applying_database_upgrades(1);

  $form->{$_} = $::auth->client->{$_} for qw(dbname dbhost dbport dbuser dbpasswd);
  $form->{$_} = $myconfig{$_}         for qw(datestyle);

  $form->{"title"} = $main::locale->text("Dataset upgrade");
  $form->header(no_layout => $form->{no_layout});
  print $form->parse_html_template("dbupgrade/header");

  $form->{dbupdate} = "db" . $::auth->client->{dbname};

  if ($form->{"show_dbupdate_warning"}) {
    print $form->parse_html_template("dbupgrade/warning", { unapplied_scripts => \@unapplied_scripts });
    $::dispatcher->end_request;
  }

  # update the tables
  SL::System::InstallationLock->lock;

  # ignore HUP, QUIT in case the webserver times out
  $SIG{HUP}  = 'IGNORE';
  $SIG{QUIT} = 'IGNORE';

  $self->dbupdate2(form => $form, updater => $dbupdater, database => $::auth->client->{dbname});

  # If $self->dbupdate2 returns than this means all upgrade scripts
  # have been applied successfully, none required user
  # interaction. Otherwise the deeper layers would have called
  # $::dispatcher->end_request already, and return would not have returned to
  # us. Therefore we can now use RDBO instances because their supposed
  # table structures do match the actual structures. So let's ensure
  # that the "employee" table contains the appropriate entries for all
  # users authorized for the current client.
  SL::DB::Manager::Employee->update_entries_for_authorized_users;

  SL::System::InstallationLock->unlock;

  print $form->parse_html_template("dbupgrade/footer");

  return LOGIN_DBUPDATE_AVAILABLE();
}

sub dbconnect_vars {
  $main::lxdebug->enter_sub();

  my ($form, $db) = @_;

  my %dboptions = (
    'yy-mm-dd'   => 'set DateStyle to \'ISO\'',
    'yyyy-mm-dd' => 'set DateStyle to \'ISO\'',
    'mm/dd/yy'   => 'set DateStyle to \'SQL, US\'',
    'dd/mm/yy'   => 'set DateStyle to \'SQL, EUROPEAN\'',
    'dd.mm.yy'   => 'set DateStyle to \'GERMAN\''
  );

  $form->{dboptions} = $dboptions{ $form->{dateformat} };
  $form->{dbconnect} = "dbi:Pg:dbname=${db};host=" . ($form->{dbhost} || 'localhost') . ";port=" . ($form->{dbport} || 5432);

  $main::lxdebug->leave_sub();
}

sub dbsources {
  $main::lxdebug->enter_sub();

  my ($self, $form) = @_;

  my @dbsources = ();
  my ($sth, $query);

  $form->{dbdefault} = $form->{dbuser} unless $form->{dbdefault};
  &dbconnect_vars($form, $form->{dbdefault});

  my $dbh = SL::DBConnect->connect($form->{dbconnect}, $form->{dbuser}, $form->{dbpasswd}, SL::DBConnect->get_options)
    or $form->dberror;

  $query =
    qq|SELECT datname FROM pg_database | .
    qq|WHERE NOT datname IN ('template0', 'template1')|;
  $sth = $dbh->prepare($query);
  $sth->execute() || $form->dberror($query);

  while (my ($db) = $sth->fetchrow_array) {

    if ($form->{only_acc_db}) {

      next if ($db =~ /^template/);

      &dbconnect_vars($form, $db);
      my $dbh = SL::DBConnect->connect($form->{dbconnect}, $form->{dbuser}, $form->{dbpasswd}, SL::DBConnect->get_options)
        or $form->dberror;

      $query =
        qq|SELECT tablename FROM pg_tables | .
        qq|WHERE (tablename = 'defaults') AND (tableowner = ?)|;
      my $sth = $dbh->prepare($query);
      $sth->execute($form->{dbuser}) ||
        $form->dberror($query . " ($form->{dbuser})");

      if ($sth->fetchrow_array) {
        push(@dbsources, $db);
      }
      $sth->finish;
      $dbh->disconnect;
      next;
    }
    push(@dbsources, $db);
  }

  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();

  return @dbsources;
}

sub dbcreate {
  $main::lxdebug->enter_sub();

  my ($self, $form) = @_;

  &dbconnect_vars($form, $form->{dbdefault});
  my $dbh =
    SL::DBConnect->connect($form->{dbconnect}, $form->{dbuser}, $form->{dbpasswd}, SL::DBConnect->get_options)
    or $form->dberror;
  $form->{db} =~ s/\"//g;

  my @dboptions;

  push @dboptions, "ENCODING = " . $dbh->quote($form->{"encoding"}) if $form->{"encoding"};
  if ($form->{"dbdefault"}) {
    my $dbdefault = $form->{"dbdefault"};
    $dbdefault =~ s/[^a-zA-Z0-9_\-]//g;
    push @dboptions, "TEMPLATE = $dbdefault";
  }

  my $query = qq|CREATE DATABASE "$form->{db}"|;
  $query   .= " WITH " . join(" ", @dboptions) if @dboptions;

  # Ignore errors if the database exists.
  $dbh->do($query);

  $dbh->disconnect;

  &dbconnect_vars($form, $form->{db});

  # make a shim myconfig so that rose db connections work
  $::myconfig{$_}     = $form->{$_} for qw(dbhost dbport dbuser dbpasswd);
  $::myconfig{dbname} = $form->{db};

  $dbh = SL::DBConnect->connect($form->{dbconnect}, $form->{dbuser}, $form->{dbpasswd}, SL::DBConnect->get_options)
    or $form->dberror;

  my $dbupdater = SL::DBUpgrade2->new(form => $form, return_on_error => 1, silent => 1)->parse_dbupdate_controls;
  # create the tables
  $dbupdater->process_query($dbh, "sql/lx-office.sql");
  $dbupdater->process_query($dbh, "sql/$form->{chart}-chart.sql");

  $query = qq|UPDATE defaults SET coa = ?|;
  do_query($form, $dbh, $query, map { $form->{$_} } qw(chart));

  $dbh->disconnect;

  # update new database
  $self->dbupdate2(form => $form, updater => $dbupdater, database => $form->{db}, silent => 1);

  $dbh = SL::DBConnect->connect($form->{dbconnect}, $form->{dbuser}, $form->{dbpasswd}, SL::DBConnect->get_options)
    or $form->dberror;

  $query = "SELECT * FROM currencies WHERE name = ?";
  my $curr = selectfirst_hashref_query($form, $dbh, $query, $form->{defaultcurrency});
  if (!$curr->{id}) {
    do_query($form, $dbh, "INSERT INTO currencies (name) VALUES (?)", $form->{defaultcurrency});
    $curr = selectfirst_hashref_query($form, $dbh, $query, $form->{defaultcurrency});
  }

  $query = qq|UPDATE defaults SET
    accounting_method = ?,
    profit_determination = ?,
    inventory_system = ?,
    precision = ?,
    currency_id = ?,
    feature_balance = ?,
    feature_datev = ?,
    feature_erfolgsrechnung = ?,
    feature_eurechnung = ?,
    feature_ustva = ?
  |;
  do_query($form, $dbh, $query,
    $form->{accounting_method},
    $form->{profit_determination},
    $form->{inventory_system},
    $form->parse_amount(\%::myconfig, $form->{precision_as_number}),
    $curr->{id},
    $form->{feature_balance},
    $form->{feature_datev},
    $form->{feature_erfolgsrechnung},
    $form->{feature_eurechnung},
    $form->{feature_ustva}
  );

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub dbdelete {
  $main::lxdebug->enter_sub();

  my ($self, $form) = @_;
  $form->{db} =~ s/\"//g;

  &dbconnect_vars($form, $form->{dbdefault});
  my $dbh = SL::DBConnect->connect($form->{dbconnect}, $form->{dbuser}, $form->{dbpasswd}, SL::DBConnect->get_options)
    or $form->dberror;
  my $query = qq|DROP DATABASE "$form->{db}"|;
  do_query($form, $dbh, $query);

  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub calc_version {
  $main::lxdebug->enter_sub(2);

  my (@v, $version, $i);

  @v = split(/\./, $_[0]);
  while (scalar(@v) < 4) {
    push(@v, 0);
  }
  $version = 0;
  for ($i = 0; $i < 4; $i++) {
    $version *= 1000;
    $version += $v[$i];
  }

  $main::lxdebug->leave_sub(2);
  return $version;
}

sub cmp_script_version {
  my ($a_from, $a_to, $b_from, $b_to);
  my ($i, $res_a, $res_b);
  my ($my_a, $my_b) = do { no warnings 'once'; ($a, $b) };

  $my_a =~ s/.*-upgrade-//;
  $my_a =~ s/.sql$//;
  $my_b =~ s/.*-upgrade-//;
  $my_b =~ s/.sql$//;
  my ($my_a_from, $my_a_to) = split(/-/, $my_a);
  my ($my_b_from, $my_b_to) = split(/-/, $my_b);

  $res_a = calc_version($my_a_from);
  $res_b = calc_version($my_b_from);

  if ($res_a == $res_b) {
    $res_a = calc_version($my_a_to);
    $res_b = calc_version($my_b_to);
  }

  return $res_a <=> $res_b;
}

sub create_schema_info_table {
  $main::lxdebug->enter_sub();

  my ($self, $form, $dbh) = @_;

  my $query = "SELECT tag FROM schema_info LIMIT 1";
  if (!$dbh->do($query)) {
    $dbh->rollback();
    $query =
      qq|CREATE TABLE schema_info (| .
      qq|  tag text, | .
      qq|  login text, | .
      qq|  itime timestamp DEFAULT now(), | .
      qq|  PRIMARY KEY (tag))|;
    $dbh->do($query) || $form->dberror($query);
  }

  $main::lxdebug->leave_sub();
}

sub dbupdate2 {
  my ($self, %params) = @_;

  my $form            = $params{form};
  my $dbupdater       = $params{updater};
  my $db              = $params{database};
  my $silent          = $params{silent};

  map { $_->{description} = SL::Iconv::convert($_->{charset}, 'UTF-8', $_->{description}) } values %{ $dbupdater->{all_controls} };

  &dbconnect_vars($form, $db);

  my $dbh = SL::DBConnect->connect($form->{dbconnect}, $form->{dbuser}, $form->{dbpasswd}, SL::DBConnect->get_options) or $form->dberror;

  $dbh->do($form->{dboptions}) if ($form->{dboptions});

  $self->create_schema_info_table($form, $dbh);

  my @upgradescripts = $dbupdater->unapplied_upgrade_scripts($dbh);

  foreach my $control (@upgradescripts) {
    # Apply upgrade. Control will only return to us if the upgrade has
    # been applied correctly and if the update has not requested user
    # interaction.
    $main::lxdebug->message(LXDebug->DEBUG2(), "Applying Update $control->{file}");
    print $form->parse_html_template("dbupgrade/upgrade_message2", $control) unless $silent;

    $dbupdater->process_file($dbh, "sql/Pg-upgrade2/$control->{file}", $control);
  }

  $dbh->disconnect;
}

sub data {
  +{ %{ $_[0] } }
}

sub get_default_myconfig {
  my ($self_or_class, %user_config) = @_;
  my $defaults = SL::DefaultManager->new($::lx_office_conf{system}->{default_manager});

  return (
    countrycode  => $defaults->language('de'),
    css_path     => 'css',      # Needed for menunew, see SL::Layout::Base::get_stylesheet_for_user
    dateformat   => $defaults->dateformat('dd.mm.yy'),
    numberformat => $defaults->numberformat('1.000,00'),
    stylesheet   => $defaults->stylesheet('kivitendo.css'),
    timeformat   => $defaults->timeformat('hh:mm'),
    %user_config,
  );
}

1;
