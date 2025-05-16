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
  $::form          = Support::TestSetup->create_new_form;
  $::auth          = SL::Auth->new(unit_tests_database => 1);
  die "Cannot find client with ID or name '$client'" if !$::auth->set_client($client);

  $::instance_conf = SL::InstanceConfiguration->new;
  $::request       = Support::TestSetup->create_new_request;

  die 'cannot reach auth db'               unless $::auth->session_tables_present;

  $::auth->restore_session;

  require "bin/mozilla/common.pl";

  die "cannot find user $login"            unless %::myconfig = $::auth->read_user(login => $login);

  die "cannot find locale for user $login" unless $::locale   = Locale->new($::myconfig{countrycode});

  $SIG{__DIE__} = sub { Carp::confess( @_ ) } if $::lx_office_conf{debug}->{backtrace_on_die};


  return 1;
}

sub create_new_form { Form->new('') }

sub create_new_request {
  my $self = shift;

  my $request = SL::Request->new(
    cgi    => CGI->new({}),
    layout => SL::Layout::None->new,
    @_,
  );

  $request->presenter->{template} = Template->new(template_config()) || die;

  return $request;
}

sub template_config {
  return {
    INTERPOLATE  => 0,
    EVAL_PERL    => 0,
    ABSOLUTE     => 1,
    CACHE_SIZE   => 0,
    PLUGIN_BASE  => 'SL::Template::Plugin',
    INCLUDE_PATH => '.:templates/design40_webpages/',
    COMPILE_DIR  => 'users/templates-cache-for-tests',
    COMPILE_EXT  => '.tcc',
    ENCODING     => 'utf8',
  };
}

1;
