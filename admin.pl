#!/usr/bin/perl

use strict;

BEGIN {
  unshift @INC, "modules/override"; # Use our own versions of various modules (e.g. YAML).
  push    @INC, "modules/fallback"; # Only use our own versions of modules if there's no system version.
  push    @INC, "SL";               # FCGI won't find modules that are not properly named. Help it by inclduging SL
}

use FCGI;
use CGI qw( -no_xhtml);
use SL::Auth;
use SL::LXDebug;
use SL::Locale;
use SL::Common;
use Form;
use Moose;
use Rose::DB;
use Rose::DB::Object;
use File::Basename;

my ($script, $path, $suffix) = fileparse($0, ".pl");
my $request                  = FCGI::Request();

eval { require "config/lx-erp.conf"; };
eval { require "config/lx-erp-local.conf"; } if -f "config/lx-erp-local.conf";
require "bin/mozilla/common.pl";
require "bin/mozilla/installationcheck.pl";
require_main_code($script, $suffix);

# dummy globals
{
  no warnings 'once';
  $::userspath  = "users";
  $::templates  = "templates";
  $::memberfile = "users/members";
  $::sendmail   = "| /usr/sbin/sendmail -t";
  $::lxdebug    = LXDebug->new;
  $::auth       = SL::Auth->new;
  %::myconfig   = ();
}

_pre_startup_checks();

if ($request->IsFastCGI) {
  handle_request() while $request->Accept() >= 0;
} else {
  handle_request();
}

# end

sub handle_request {
  $::lxdebug->enter_sub;
  $::lxdebug->begin_request;
  $::cgi            = CGI->new('');
  $::locale         = Locale->new($::language, $script);
  $::form           = Form->new;
  $::form->{script} = $script . $suffix;

  _pre_request_checks();

  eval {
    if ($script eq 'login' or $script eq 'admin' or $script eq 'kopf') {
      $::form->{titlebar} = "Lx-Office " . $::locale->text('Version') . " $::form->{version}";
      run($::auth->restore_session);
    } elsif ($::form->{action}) {
      # copy from am.pl routines
      $::form->error($::locale->text('System currently down for maintenance!')) if -e "$main::userspath/nologin" && $script ne 'admin';

      my $session_result = $::auth->restore_session;

      _show_error('login/password_error', 'session') if SL::Auth::SESSION_EXPIRED == $session_result;
      %::myconfig = $::auth->read_user($::form->{login});

      _show_error('login/password_error', 'password') unless $::myconfig{login};

      $::locale = Locale->new($::myconfig{countrycode}, $script);

      _show_error('login/password_error', 'password') if SL::Auth::OK != $::auth->authenticate($::form->{login}, $::form->{password}, 0);

      $::auth->set_session_value('login', $::form->{login}, 'password', $::form->{password});
      $::auth->create_or_refresh_session;
      delete $::form->{password};

      map { $::form->{$_} = $::myconfig{$_} } qw(stylesheet charset)
        unless $::form->{action} eq 'save' && $::form->{type} eq 'preferences';

      $::form->set_standard_title;
      call_sub($::locale->findsub($::form->{action}));
    } else {
      $::form->error($::locale->text('action= not defined!'));
    }
  };

  # cleanup
  $::locale   = undef;
  $::form     = undef;
  $::myconfig = ();

  $::lxdebug->end_request;
  $::lxdebug->leave_sub;
}

sub _pre_request_checks {
  _show_error('login/auth_db_unreachable') unless $::auth->session_tables_present;
  $::auth->expire_sessions;
}

sub _show_error {
  $::lxdebug->enter_sub;
  my $template           = shift;
  my $error_type         = shift;
  my $locale             = Locale->new($::language, 'all');
  $::form->{error}       = $::locale->text('The session is invalid or has expired.') if ($error_type eq 'session');
  $::form->{error}       = $::locale->text('Incorrect password!.')                   if ($error_type eq 'password');
  $::myconfig{countrycode} = $::language;
  $::form->{stylesheet}    = 'css/lx-office-erp.css';

  $::form->header;
  print $::form->parse_html_template($template);
  $::lxdebug->leave_sub;

  exit;
}

sub _pre_startup_checks {
  verify_installation();
}

sub require_main_code {
  my ($script, $suffix) = @_;

  require "bin/mozilla/$script$suffix";

  if (-f "bin/mozilla/custom_$script$suffix") {
    eval { require "bin/mozilla/custom_$script$suffix"; };
    $::form->error($@) if ($@);
  }
  if ($::form->{login} && -f "bin/mozilla/$::form->{login}_$::form->{script}") {
    eval { require "bin/mozilla/$::form->{login}_$::form->{script}"; };
    $::form->error($@) if ($@);
  }
}

1;
