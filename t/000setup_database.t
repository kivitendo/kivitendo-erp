#!/usr/bin/perl

use strict;

use lib 't';

use SL::DB::Helper::ALL;

use Data::Dumper;
use Test::More;

use SL::Auth;
use SL::DBConnect;
use SL::Form;
use SL::InstanceConfiguration;
use SL::LXDebug;
use SL::Layout::None;
use SL::LxOfficeConf;
use Support::TestSetup;

our ($db_cfg, $dbh, $superuser_dbh);

sub dbg {
  # diag(@_);
}

sub dbh_do {
  my ($dbh, $query, %params) = @_;

  if (ref($query)) {
    return if $query->execute(@{ $params{bind} || [] });
    BAIL_OUT($dbh->errstr);
  }

  return if $dbh->do($query, undef, @{ $params{bind} || [] });

  BAIL_OUT($params{message} . ": " . $dbh->errstr) if $params{message};
  BAIL_OUT("Query failed: " . $dbh->errstr . " ; query: $query");
}

sub verify_configuration {
  SL::LxOfficeConf->read;

  my %config = %{ $::lx_office_conf{'testing/database'} || {} };
  my @unset  = sort grep { !$config{$_} } qw(host port db user template);

  BAIL_OUT("Missing entries in configuration in section [testing/database]: " . join(' ', @unset)) if @unset;
}

sub setup {
  package main;

  $SIG{__DIE__}    = sub { Carp::confess( @_ ) } if $::lx_office_conf{debug}->{backtrace_on_die};
  $::lxdebug       = LXDebug->new(target => LXDebug::STDERR_TARGET);
  $::lxdebug->disable_sub_tracing;
  $::locale        = Locale->new($::lx_office_conf{system}->{language});
  $::form          = Support::TestSetup->create_new_form;
  $::auth          = SL::Auth->new(unit_tests_database => 1);
  $::locale        = Locale->new('de');
  $::instance_conf = SL::InstanceConfiguration->new;
  $db_cfg          = $::lx_office_conf{'testing/database'};
}

sub drop_and_create_database {
  my @dbi_options = (
    'dbi:Pg:dbname=' . $db_cfg->{template} . ';host=' . $db_cfg->{host} . ';port=' . $db_cfg->{port},
    $db_cfg->{user},
    $db_cfg->{password},
    SL::DBConnect->get_options,
  );

  my $dbh_template = SL::DBConnect->connect(@dbi_options) || BAIL_OUT("No database connection to the template database: " . $DBI::errstr);
  my $auth_dbh     = $::auth->dbconnect(1);

  if ($auth_dbh) {
    dbg("Database exists; dropping");
    $auth_dbh->disconnect;

    dbh_do($dbh_template, "DROP DATABASE \"" . $db_cfg->{db} . "\"", message => "Database could not be dropped");
  }

  dbg("Creating database");

  dbh_do($dbh_template, "CREATE DATABASE \"" . $db_cfg->{db} . "\" TEMPLATE \"" . $db_cfg->{template} . "\" ENCODING 'UNICODE'", message => "Database could not be created");
  $dbh_template->disconnect;
}

sub report_success {
  $dbh->disconnect;
  $superuser_dbh->disconnect if $superuser_dbh;
  ok(1, "Database has been set up successfully.");
  done_testing();
}

sub apply_dbupgrade {
  my ($dbupdater, $control_or_file) = @_;

  my $file    = ref($control_or_file) ? ("sql/Pg-upgrade2" . ($dbupdater->{auth} ? "-auth" : "") . "/$control_or_file->{file}") : $control_or_file;
  my $control = ref($control_or_file) ? $control_or_file                                                                        : undef;

  dbg("Applying $file");

  my $script_dbh = $control && $control->{superuser_privileges} ? ($superuser_dbh // $dbh) : $dbh;
  my $error      = $dbupdater->process_file($script_dbh, $file, $control);

  BAIL_OUT("Error applying $file: $error") if $error;
}

sub create_initial_schema {
  dbg("Creating initial schema");

  my @dbi_options = (
    'dbi:Pg:dbname=' . $db_cfg->{db} . ';host=' . $db_cfg->{host} . ';port=' . $db_cfg->{port},
    $db_cfg->{user},
    $db_cfg->{password},
    SL::DBConnect->get_options(PrintError => 0, PrintWarn => 0),
  );

  $dbh           = SL::DBConnect->connect(@dbi_options) || BAIL_OUT("Database connection failed: " . $DBI::errstr);
  $::auth->{dbh} = $dbh;
  my $dbupdater  = SL::DBUpgrade2->new(form => $::form, return_on_error => 1, silent => 1);
  my $coa        = 'Germany-DATEV-SKR03EU';

  if ($db_cfg->{superuser_user} && ($db_cfg->{superuser_user} ne $db_cfg->{user})) {
    @dbi_options = (
      'dbi:Pg:dbname=' . $db_cfg->{db} . ';host=' . $db_cfg->{host} . ';port=' . $db_cfg->{port},
      $db_cfg->{superuser_user},
      $db_cfg->{superuser_password},
      SL::DBConnect->get_options(PrintError => 0, PrintWarn => 0),
    );

    $superuser_dbh = SL::DBConnect->connect(@dbi_options) || BAIL_OUT("Database superuser connection failed: " . $DBI::errstr);
  }

  apply_dbupgrade($dbupdater, "sql/lx-office.sql");
  apply_dbupgrade($dbupdater, "sql/${coa}-chart.sql");

  dbh_do($dbh, qq|UPDATE defaults SET coa = '${coa}', accounting_method = 'cash', profit_determination = 'income', inventory_system = 'periodic', curr = 'EUR'|);
  dbh_do($dbh, qq|CREATE TABLE schema_info (tag TEXT, login TEXT, itime TIMESTAMP DEFAULT now(), PRIMARY KEY (tag))|);
}

sub create_initial_auth_schema {
  dbg("Creating initial auth schema");

  my $dbupdater = SL::DBUpgrade2->new(form => $::form, return_on_error => 1, auth => 1);
  apply_dbupgrade($dbupdater, 'sql/auth_db.sql');
}

sub apply_upgrades {
  my %params            = @_;
  my $dbupdater         = SL::DBUpgrade2->new(form => $::form, return_on_error => 1, auth => $params{auth});
  my @unapplied_scripts = $dbupdater->unapplied_upgrade_scripts($dbh);

  apply_dbupgrade($dbupdater, $_) for @unapplied_scripts;
}

sub create_client_user_and_employee {
  dbg("Creating client, user, group and employee");

  dbh_do($dbh, qq|DELETE FROM auth.clients|);
  dbh_do($dbh, qq|INSERT INTO auth.clients (id, name, dbhost, dbport, dbname, dbuser, dbpasswd, is_default) VALUES (1, 'Unit-Tests', ?, ?, ?, ?, ?, TRUE)|,
         bind => [ @{ $db_cfg }{ qw(host port db user password) } ]);
  dbh_do($dbh, qq|INSERT INTO auth."user"         (id,        login)    VALUES (1, 'unittests')|);
  dbh_do($dbh, qq|INSERT INTO auth."group"        (id,        name)     VALUES (1, 'Vollzugriff')|);
  dbh_do($dbh, qq|INSERT INTO auth.clients_users  (client_id, user_id)  VALUES (1, 1)|);
  dbh_do($dbh, qq|INSERT INTO auth.clients_groups (client_id, group_id) VALUES (1, 1)|);
  dbh_do($dbh, qq|INSERT INTO auth.user_group     (user_id,   group_id) VALUES (1, 1)|);

  my %config                 = (
    default_printer_id       => '',
    template_format          => '',
    default_media            => '',
    email                    => 'unit@tester',
    tel                      => '',
    dateformat               => 'dd.mm.yy',
    show_form_details        => '',
    name                     => 'Unit Tester',
    signature                => '',
    hide_cvar_search_options => '',
    numberformat             => '1.000,00',
    favorites                => '',
    copies                   => '',
    menustyle                => 'v3',
    fax                      => '',
    stylesheet               => 'design40.css',
    mandatory_departments    => 0,
    countrycode              => 'de',
  );

  my $sth = $dbh->prepare(qq|INSERT INTO auth.user_config (user_id, cfg_key, cfg_value) VALUES (1, ?, ?)|) || BAIL_OUT($dbh->errstr);
  dbh_do($dbh, $sth, bind => [ $_, $config{$_} ]) for sort keys %config;
  $sth->finish;

  $sth = $dbh->prepare(qq|INSERT INTO auth.group_rights (group_id, "right", granted) VALUES (1, ?, TRUE)|) || BAIL_OUT($dbh->errstr);
  dbh_do($dbh, $sth, bind => [ $_ ]) for sort $::auth->all_rights;
  $sth->finish;

  dbh_do($dbh, qq|INSERT INTO employee (id, login, name) VALUES (1, 'unittests', 'Unit Tester')|);

  $::auth->set_client(1) || BAIL_OUT("\$::auth->set_client(1) failed");
  %::myconfig = $::auth->read_user(login => 'unittests');
}

verify_configuration();
setup();
drop_and_create_database();
create_initial_schema();
create_initial_auth_schema();
apply_upgrades(auth => 1);
create_client_user_and_employee();
apply_upgrades();
report_success();

1;
