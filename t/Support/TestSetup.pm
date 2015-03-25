package Support::TestSetup;

use strict;

use Data::Dumper;
use CGI qw( -no_xhtml);
use IO::File;
use SL::Auth;
use SL::Form;
use SL::Locale;
use SL::LXDebug;
use Data::Dumper;
use SL::Layout::None;
use SL::LxOfficeConf;
use SL::InstanceConfiguration;
use SL::Request;

sub login {
  $Data::Dumper::Sortkeys = 1;
  $Data::Dumper::Indent   = 2;

  SL::LxOfficeConf->read;

  my $client = 'Unit-Tests';
  my $login  = 'unittests';

  package main;

  $::lxdebug       = LXDebug->new(target => LXDebug::STDERR_TARGET);
  $::lxdebug->disable_sub_tracing;
  $::locale        = Locale->new($::lx_office_conf{system}->{language});
  $::form          = Form->new;
  $::auth          = SL::Auth->new(unit_tests_database => 1);
  die "Cannot find client with ID or name '$client'" if !$::auth->set_client($client);

  $::instance_conf = SL::InstanceConfiguration->new;
  $::request       = SL::Request->new( cgi => CGI->new({}), layout => SL::Layout::None->new );

  die 'cannot reach auth db'               unless $::auth->session_tables_present;

  $::auth->restore_session;

  require "bin/mozilla/common.pl";

  die "cannot find user $login"            unless %::myconfig = $::auth->read_user(login => $login);

  die "cannot find locale for user $login" unless $::locale   = Locale->new($::myconfig{countrycode});

  $SIG{__DIE__} = sub { Carp::confess( @_ ) } if $::lx_office_conf{debug}->{backtrace_on_die};

  return 1;
}

sub templates_cache_writable {
  my $dir = $::lx_office_conf{paths}->{userspath} . '/templates-cache';
  return 1 if -w $dir;

  # Try actually creating a file. Due to ACLs this might be possible
  # even if the basic Unix permissions and Perl's -w test say
  # otherwise.
  my $file = "${dir}/.writetest";
  my $out  = IO::File->new($file, "w") || return 0;
  $out->close;
  unlink $file;

  return 1;
}

1;
