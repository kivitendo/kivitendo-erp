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
    adminlogin();
  }
  $::lxdebug->leave_sub;
}

sub adminlogin {
  print $::request->cgi->redirect('controller.pl?action=Admin/login');
}

sub pg_database_administration {
  my $form = $main::form;
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

  $form->header();
  print $form->parse_html_template("admin/dbadmin");
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
    map { $form->{$_} = $::myconfig{$_} = $form->{"${_}_${i}"} } qw(dbname dbhost dbport dbuser dbpasswd);

    print $form->parse_html_template("admin/dbupgrade_header");

    User->dbupdate($form);
    User->dbupdate2(form => $form, updater => SL::DBUpgrade2->new(form => $form)->parse_dbupdate_controls, database => $form->{dbname});

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

1;
