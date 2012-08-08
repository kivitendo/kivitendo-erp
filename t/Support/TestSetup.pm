package Support::TestSetup;

use strict;

use Data::Dumper;
use CGI qw( -no_xhtml);
use SL::Auth;
use SL::Form;
use SL::Locale;
use SL::LXDebug;
use Data::Dumper;
use SL::LxOfficeConf;
use SL::InstanceConfiguration;

sub _login {
  my $login = shift;

  die 'need login' unless $login;

  package main;

  $::lxdebug       = LXDebug->new(file => \*STDERR);
  $::locale        = Locale->new($::lx_office_conf{system}->{language});
  $::form          = Form->new;
  $::auth          = SL::Auth->new;
  $::instance_conf = SL::InstanceConfiguration->new;
  $::request       = { cgi => CGI->new({}) };

  die 'cannot reach auth db'               unless $::auth->session_tables_present;

  $::auth->restore_session;

  require "bin/mozilla/common.pl";

  die "cannot find user $login"            unless %::myconfig = $::auth->read_user(login => $login);

  $::form->{login} = $login; # normaly implicit at login

  die "cannot find locale for user $login" unless $::locale   = Locale->new($::myconfig{countrycode});

  $::instance_conf->init;

  return 1;
}

sub login {
  SL::LxOfficeConf->read;

  my $login        = shift || $::lx_office_conf{testing}{login}        || 'demo';
  _login($login);
}

1;
