package SL::Dispatcher;

use strict;

use CGI qw( -no_xhtml);
use English qw(-no_match_vars);
use SL::Auth;
use SL::LXDebug;
use SL::Locale;
use SL::Common;
use Form;
use Moose;
use Rose::DB;
use Rose::DB::Object;
use File::Basename;

sub pre_request_checks {
  show_error('login/auth_db_unreachable') unless $::auth->session_tables_present;
  $::auth->expire_sessions;
}

sub show_error {
  $::lxdebug->enter_sub;
  my $template           = shift;
  my $error_type         = shift || '';
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

sub pre_startup_setup {
  eval {
    package main;
    require "config/lx-erp.conf";
  };
  eval {
    package main;
    require "config/lx-erp-local.conf";
  } if -f "config/lx-erp-local.conf";

  eval {
    package main;
    require "bin/mozilla/common.pl";
    require "bin/mozilla/installationcheck.pl";
  } or die $EVAL_ERROR;

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
}

sub pre_startup_checks {
  ::verify_installation();
}

sub pre_startup {
  pre_startup_setup();
  pre_startup_checks();
}

sub require_main_code {
  my ($script, $suffix) = @_;

  eval {
    package main;
    require "bin/mozilla/$script$suffix";
  } or die $EVAL_ERROR;

  if (-f "bin/mozilla/custom_$script$suffix") {
    eval {
      package main;
      require "bin/mozilla/custom_$script$suffix";
    };
    $::form->error($EVAL_ERROR) if ($EVAL_ERROR);
  }
  if ($::form->{login} && -f "bin/mozilla/$::form->{login}_$::form->{script}") {
    eval {
      package main;
      require "bin/mozilla/$::form->{login}_$::form->{script}";
    };
    $::form->error($EVAL_ERROR) if ($EVAL_ERROR);
  }
}

sub handle_request {
  $::lxdebug->enter_sub;
  $::lxdebug->begin_request;

  my $interface = lc(shift || 'cgi');
  my $script_name;

  if ($interface =~ m/^(?:fastcgi|fcgid|fcgi)$/) {
    $script_name = $ENV{SCRIPT_NAME};
    unrequire_bin_mozilla();

  } else {
    $script_name = $0;
  }

  my ($script, $path, $suffix) = fileparse($script_name, ".pl");
  require_main_code($script, $suffix);

  $::cgi            = CGI->new('');
  $::locale         = Locale->new($::language, $script);
  $::form           = Form->new;
  $::form->{script} = $script . $suffix;

  pre_request_checks();

  eval {
    if ($script eq 'login' or $script eq 'admin' or $script eq 'kopf') {
      $::form->{titlebar} = "Lx-Office " . $::locale->text('Version') . " $::form->{version}";
      ::run($::auth->restore_session);

    } elsif ($::form->{action}) {
      # copy from am.pl routines
      $::form->error($::locale->text('System currently down for maintenance!')) if -e "$main::userspath/nologin" && $script ne 'admin';

      my $session_result = $::auth->restore_session;

      show_error('login/password_error', 'session') if SL::Auth::SESSION_EXPIRED == $session_result;
      %::myconfig = $::auth->read_user($::form->{login});

      show_error('login/password_error', 'password') unless $::myconfig{login};

      $::locale = Locale->new($::myconfig{countrycode}, $script);

      show_error('login/password_error', 'password') if SL::Auth::OK != $::auth->authenticate($::form->{login}, $::form->{password}, 0);

      $::auth->set_session_value('login', $::form->{login}, 'password', $::form->{password});
      $::auth->create_or_refresh_session;
      delete $::form->{password};

      map { $::form->{$_} = $::myconfig{$_} } qw(stylesheet charset)
        unless $::form->{action} eq 'save' && $::form->{type} eq 'preferences';

      $::form->set_standard_title;
      ::call_sub('::' . $::locale->findsub($::form->{action}));

    } else {
      $::form->error($::locale->text('action= not defined!'));
    }

    1;
  } or do {
    $::form->{label_error} = $::cgi->pre($EVAL_ERROR);
    show_error('generic/error');
  };

  # cleanup
  $::locale   = undef;
  $::form     = undef;
  $::myconfig = ();

  $::lxdebug->end_request;
  $::lxdebug->leave_sub;
}

sub unrequire_bin_mozilla {
  for (keys %INC) {
    next unless m#^bin/mozilla/#;
    next if /\bcommon.pl$/;
    next if /\binstallationcheck.pl$/;
    delete $INC{$_};
  }
}

1;
