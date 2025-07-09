package SL::Dispatcher;

use strict;

# Force scripts/locales.pl to parse these templates:
#   parse_html_template('login_screen/auth_db_unreachable')
#   parse_html_template('login_screen/user_login')
#   parse_html_template('generic/error')

use Carp;
use CGI qw( -no_xhtml);
use Config::Std;
use DateTime;
use Encode;
use English qw(-no_match_vars);
use FCGI;
use File::Basename;
use IO::File;
use List::MoreUtils qw(all);
use List::Util qw(first);
use POSIX qw(setlocale);
use SL::Auth;
use SL::Dispatcher::AuthHandler;
use SL::LXDebug;
use SL::LxOfficeConf;
use SL::Locale;
use SL::ClientJS;
use SL::Common;
use SL::Form;
use SL::Helper::DateTime;
use SL::InstanceConfiguration;
use SL::MoreCommon qw(uri_encode);
use SL::Template::Plugin::HTMLFixes;
use SL::User;

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(restart_after_request) ],
);

# Trailing new line is added so that Perl will not add the line
# number 'die' was called in.
use constant END_OF_REQUEST => "END-OF-REQUEST\n";

my %fcgi_file_cache;

sub new {
  my ($class, $interface) = @_;

  my $self           = bless {}, $class;
  $self->{interface} = lc($interface || 'cgi');
  $self->{auth_handler} = SL::Dispatcher::AuthHandler->new;

  # Initialize character type locale to be UTF-8 instead of C:
  foreach my $locale (qw(de_DE.UTF-8 en_US.UTF-8)) {
    last if setlocale('LC_CTYPE', $locale);
  }

  return $self;
}

sub interface_type {
  my ($self) = @_;
  return $self->{interface} eq 'cgi' ? 'CGI' : 'FastCGI';
}

sub is_admin_request {
  my %params = @_;
  return ($params{script} eq 'admin.pl') || (($params{routing_type} eq 'controller') && ($params{script_name} eq 'Admin'));
}

sub pre_request_checks {
  my (%params) = @_;

  _check_for_old_config_files();

  if (!$::auth->session_tables_present && !is_admin_request(%params)) {
    show_error('login_screen/auth_db_unreachable');
  }

  if ($::request->type !~ m/^ (?: html | js | json ) $/x) {
    die $::locale->text("Invalid request type '#1'", $::request->type);
  }
}

sub pre_request_initialization {
  my ($self, %params) = @_;

  $self->unrequire_bin_mozilla;

  $::locale        = Locale->new($::lx_office_conf{system}->{language});
  $::form          = Form->new;
  $::instance_conf = SL::InstanceConfiguration->new;
  $::request       = SL::Request->new(
    cgi            => CGI->new({}),
    layout         => SL::Layout::None->new,
  );

  my $session_result = $::auth->restore_session;
  $::auth->create_or_refresh_session;

  if ($params{client}) {
    $::auth->set_client($params{client}) || die("cannot find client " . $params{client});

    if ($params{login}) {
      die "cannot find user " . $params{login}            unless %::myconfig = $::auth->read_user(login => $params{login});
      die "cannot find locale for user " . $params{login} unless $::locale   = Locale->new($::myconfig{countrycode});

      $::form->{login} = $params{login}; # normaly implicit at login
    }
  }

  return $session_result;
}

sub render_error_ajax {
  my ($error) = @_;

  SL::ClientJS->new
    ->error($error)
    ->render(SL::Controller::Base->new);
}

sub show_error {
  $::lxdebug->enter_sub;
  my $template             = shift;
  my $error_type           = shift || '';
  my %params               = @_;

  $::myconfig{countrycode} = delete($params{countrycode}) || $::lx_office_conf{system}->{language};
  $::locale                = Locale->new($::myconfig{countrycode});
  $::form->{error}         = $::locale->text('The session is invalid or has expired.') if ($error_type eq 'session');
  $::form->{error}         = $::locale->text('Incorrect password!')                    if ($error_type eq 'password');
  $::form->{error}         = $::locale->text('The action is missing or invalid.')      if ($error_type eq 'action');

  return render_error_ajax($::form->{error}) if $::request->is_ajax;

  $::form->header;
  print $::form->parse_html_template($template, \%params);
  $::lxdebug->leave_sub;

  end_request();
}

sub pre_startup_setup {
  my ($self) = @_;

  SL::LxOfficeConf->read;

  eval {
    package main;
    require "bin/mozilla/common.pl";
    require "bin/mozilla/installationcheck.pl";
  } or die $EVAL_ERROR;

  # canonial globals. if it's not here, chances are it will get refactored someday.
  {
    no warnings 'once';
    $::lxdebug     = LXDebug->new;
    $::auth        = SL::Auth->new;
    $::form        = undef;
    $::request     = undef;
    %::myconfig    = User->get_default_myconfig;
  }

  $SIG{__WARN__} = sub {
    $::lxdebug->warn(@_);
  };

  $SIG{__DIE__} = sub { Carp::confess( @_ ) } if $::lx_office_conf{debug}->{backtrace_on_die};

  $self->_cache_file_modification_times;
}

sub pre_startup_checks {
  ::verify_installation();
}

sub pre_startup {
  my ($self) = @_;
  $self->pre_startup_setup;
  $self->pre_startup_checks;
}

sub require_main_code {
  $::lxdebug->enter_sub;
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
  if ($::form->{login} && -f "bin/mozilla/$::form->{login}_$script") {
    eval {
      package main;
      require "bin/mozilla/$::form->{login}_$script";
    };
    $::form->error($EVAL_ERROR) if ($EVAL_ERROR);
  }
  $::lxdebug->leave_sub;
}

sub _require_controller {
  my $controller =  shift;
  $controller    =~ s|[^A-Za-z0-9_]||g;
  $controller    =  "SL/Controller/${controller}";

  eval {
    package main;
    require "${controller}.pm";
  } or die $EVAL_ERROR;
}

sub _run_controller {
  "SL::Controller::$_[0]"->new->_run_action($_[1]);
}

sub handle_all_requests {
  my ($self) = @_;

  my $request = FCGI::Request();
  while ($request->Accept() >= 0) {
    $self->handle_request($request);

    $self->restart_after_request(1) if $self->_interface_is_fcgi && SL::System::Process::memory_usage_is_too_high();
    $request->LastCall              if $self->restart_after_request;
  }

  exec $0 if $self->restart_after_request;
}

sub handle_request {
  my $self         = shift;
  $self->{request} = shift;

  $::lxdebug->enter_sub;
  $::lxdebug->begin_request;

  my ($script, $path, $suffix, $script_name, $action, $routing_type);

  my $session_result = $self->pre_request_initialization;

  $::request->read_cgi_input($::form);

  my %routing;
  eval { %routing = $self->_route_request($ENV{SCRIPT_NAME}); 1; } or return;
  ($routing_type, $script_name, $action) = @routing{qw(type controller action)};
  $::lxdebug->log_request($routing_type, $script_name, $action);

  $::request->type(lc($routing{request_type} || 'html'));

  if ($routing_type eq 'old') {
    $::form->{action}  =  lc $::form->{action};
    $::form->{action}  =~ s/( |-|,|\#)/_/g;

   ($script, $path, $suffix) = fileparse($script_name, ".pl");
    require_main_code($script, $suffix) unless $script eq 'admin';

    $::form->{script} = $script . $suffix;

  } else {
    _require_controller($script_name);
    $::form->{script} = "controller.pl";
  }

  eval {
    pre_request_checks(script => $script, action => $action, routing_type => $routing_type, script_name => $script_name);

    if (   SL::System::InstallationLock->is_locked
        && !is_admin_request(script => $script, script_name => $script_name, routing_type => $routing_type)) {
      $::form->error($::locale->text('System currently down for maintenance!'));
    }

    # For compatibility with a lot of database upgrade scripts etc:
    # Re-write request to old 'login.pl?action=login' to new
    # 'LoginScreen' controller. Make sure to load its code!
    if (($script eq 'login') && ($action eq 'login')) {
      ($routing_type, $script, $script_name, $action) = qw(controller controller LoginScreen login);
      _require_controller('LoginScreen');
    }

    if (   (($script eq 'login') && !$action)
        || ($script eq 'admin')
        || (SL::Auth::SESSION_EXPIRED() == $session_result)) {
      $self->handle_login_error(routing_type => $routing_type,
                                script       => $script,
                                controller   => $script_name,
                                action       => $action,
                                error        => 'session');
    }

    my %auth_result = $self->{auth_handler}->handle(
      routing_type => $routing_type,
      script       => $script,
      controller   => $script_name,
      action       => $action,
    );

    $self->end_request unless $auth_result{auth_ok};

    delete @{ $::form }{ grep { m/^\{AUTH\}/ } keys %{ $::form } } unless $auth_result{keep_auth_vars};

    if ($action) {
      $::form->set_standard_title;
      if ($routing_type eq 'old') {
        ::call_sub('::' . $::locale->findsub($action));
      } else {
        _run_controller($script_name, $action);
      }
    } else {
      $::form->error($::locale->text('action= not defined!'));
    }

    1;
  } or do {
    if (substr($EVAL_ERROR, 0, length(END_OF_REQUEST())) ne END_OF_REQUEST()) {
      my $error = $EVAL_ERROR;
      print STDERR $error;

      if ($::request->is_ajax) {
        eval { render_error_ajax($error) };
      } else {
        $::form->{label_error} = $::request->{cgi}->pre($error);
        chdir SL::System::Process::exe_dir;
        eval { show_error('generic/error') };
      }
    }
  };

  $::form->footer;

  if ($self->_interface_is_fcgi) {
    # fcgi? send send reponse on its way before cleanup.
    $self->{request}->Flush;
    $self->{request}->Finish;
  }

  $::lxdebug->end_request(routing_type => $routing_type, script_name => $script_name, action => $action);

  # cleanup
  $::auth->save_session;
  $::auth->expire_sessions;
  $::auth->reset;

  $::locale   = undef;
  $::form     = undef;
  %::myconfig = ();
  $::request  = undef;

  SL::DBConnect::Cache->reset_all;

  $self->_watch_for_changed_files;

  $::lxdebug->leave_sub;
}

sub reply_with_json_error {
  my ($self, %params) = @_;

  my %errors = (
    session  => { code => '401 Unauthorized',          text => 'session expired' },
    password => { code => '401 Unauthorized',          text => 'incorrect username or password' },
    action   => { code => '400 Bad request',           text => 'incorrect or missing action' },
    access   => { code => '403 Forbidden',             text => 'no permissions for accessing this function' },
    _default => { code => '500 Internal server error', text => 'general server-side error' },
  );

  my $error = $errors{$params{error}} // $errors{_default};
  my $reply = SL::JSON::to_json({ status => 'failed', error => $error->{text} });

  print $::request->cgi->header(
    -type    => 'application/json',
    -charset => 'utf-8',
    -status  => $error->{code},
  );

  print $reply;

  $self->end_request;
}

sub handle_login_error {
  my ($self, %params) = @_;

  return $self->reply_with_json_error(error => $params{error}) if $::request->type eq 'json';

  my $action          = ($params{script} // '') =~ m/^admin/i ? 'Admin/login' : 'LoginScreen/user_login';
  $action            .= '&error=' . $params{error} if $params{error};

  my $redirect_url = "controller.pl?action=${action}";

  if (   $action =~ m/LoginScreen\/user_login/
      && $params{action}
      && 'get' eq lc($ENV{REQUEST_METHOD})
      && !_is_callback_blacklisted(map {$_ => $params{$_}} qw(routing_type script controller action) )
  ) {

    require SL::Controller::Base;
    my $controller = SL::Controller::Base->new;

    delete $params{error};
    delete $params{routing_type};
    delete @{ $::form }{ grep { m/^\{AUTH\}/ } keys %{ $::form } };

    my $callback   = $controller->url_for(%params, %{$::form});
    $redirect_url .= '&callback=' . uri_encode($callback);
  }

  print $::request->cgi->redirect($redirect_url);
  $self->end_request;
}

sub _is_callback_blacklisted {
  my (%params) = @_;

  # You can give a name only, then all actions are blackisted.
  # Or you can give name and action, then only this action is blacklisted
  # examples:
  # {name => 'is',      action => 'edit'}
  # {name => 'Project', action => 'edit'},
  my @script_blacklist = (
    {name => 'admin'},
    {name => 'login'},
  );

  my @controller_blacklist = (
    {name => 'Admin'},
    {name => 'LoginScreen'},
  );

  my ($name, $blacklist);
  if ('old' eq ($params{routing_type} // '')) {
    $name      = $params{script};
    $blacklist = \@script_blacklist;
  } else {
    $name      = $params{controller};
    $blacklist = \@controller_blacklist;
  }

  foreach my $bl (@$blacklist) {
    return 1 if _is_name_action_blacklisted($bl->{name}, $bl->{action}, $name, $params{action});
  }

  return;
}

sub _is_name_action_blacklisted {
  my ($blacklisted_name, $blacklisted_action, $name, $action) = @_;

  return 1 if ($name // '') eq $blacklisted_name && !$blacklisted_action;
  return 1 if ($name // '') eq $blacklisted_name && ($action // '') eq $blacklisted_action;
  return;
}

sub unrequire_bin_mozilla {
  my $self = shift;
  return unless $self->_interface_is_fcgi;

  for (keys %INC) {
    next unless m#^bin/mozilla/#;
    next if /\bcommon.pl$/;
    next if /\binstallationcheck.pl$/;
    delete $INC{$_};
  }
}

sub _interface_is_fcgi {
  my $self = shift;
  return $self->{interface} =~ m/^(?:fastcgi|fcgid|fcgi)$/;
}

sub _route_request {
  my ($self, $script_name) = @_;

  return $script_name =~ m/dispatcher\.pl$/ ? (type => 'old',        $self->_route_dispatcher_request)
       : $script_name =~ m/controller\.pl/  ? (type => 'controller', $self->_route_controller_request)
       :                                      (type => 'old',        controller => $script_name, action => $::form->{action});
}

sub _route_dispatcher_request {
  my ($self)  = @_;
  my $name_re = qr{[a-z]\w*};
  my ($script_name, $action);

  eval {
    die "Unroutable request -- invalid module name.\n" if !$::form->{M} || ($::form->{M} !~ m/^${name_re}$/);
    $script_name = $::form->{M} . '.pl';

    if ($::form->{A}) {
      $action = $::form->{A};

    } else {
      $action = first { m/^A_${name_re}$/ } keys %{ $::form };
      die "Unroutable request -- invalid action name.\n" if !$action;

      delete $::form->{$action};
      $action = substr $action, 2;
    }

    delete @{$::form}{qw(M A)};

    1;
  } or do {
    $::form->{label_error} = $::request->{cgi}->pre($EVAL_ERROR);
    show_error('generic/error');
  };

  return (controller => $script_name, action => $action);
}

sub _route_controller_request {
  my ($self) = @_;
  my ($controller, $action, $request_type);

  eval {
    # Redirect simple requests to controller.pl without any GET/POST
    # param to the login page.
    $self->handle_login_error(error => 'action') if !$::form->{action};

    # Show an error if the »action« parameter doesn't match the
    # pattern »Controller/action«.
    $::form->{action}      =~ m|^ ( [A-Z] [A-Za-z0-9_]* ) / ( [a-z] [a-z0-9_]* ) ( \. [a-zA-Z]+ )? $|x || die "Unroutable request -- invalid controller/action.\n";
    ($controller, $action) =  ($1, $2);
    delete $::form->{action};

    $request_type = $3 ? lc(substr($3, 1)) : 'html';

    1;
  } or do {
    $::form->{label_error} = $::request->{cgi}->pre($EVAL_ERROR);
    show_error('generic/error');
  };

  return (controller => $controller, action => $action, request_type => $request_type);
}

sub _cache_file_modification_times {
  my ($self) = @_;

  return unless $self->_interface_is_fcgi && $::lx_office_conf{debug}->{restart_fcgi_process_on_changes};

  require File::Find;
  require POSIX;

  my $wanted = sub {
    return unless $File::Find::name =~ m/\.(?:pm|f?pl|html|conf|conf\.default)$/;
    $fcgi_file_cache{ $File::Find::name } = (stat $File::Find::name)[9];
  };

  my $cwd = POSIX::getcwd();
  File::Find::find($wanted, map { "${cwd}/${_}" } qw(config bin SL templates/design40_webpages));
  map { my $name = "${cwd}/${_}"; $fcgi_file_cache{$name} = (stat $name)[9] } qw(admin.pl dispatcher.fpl);
}

sub _watch_for_changed_files {
  my ($self) = @_;

  return unless $self->_interface_is_fcgi && $::lx_office_conf{debug}->{restart_fcgi_process_on_changes};

  my $ok = all { (stat($_))[9] == $fcgi_file_cache{$_} } keys %fcgi_file_cache;
  return if $ok;
  $::lxdebug->message(LXDebug::DEBUG1(), "Program modifications detected. Restarting.");
  $self->restart_after_request(1);
}

sub get_standard_filehandles {
  my $self = shift;

  return $self->{interface} =~ m/f(?:ast)cgi/i ? $self->{request}->GetHandles() : (\*STDIN, \*STDOUT, \*STDERR);
}

sub _check_for_old_config_files {
  my @old_files = grep { -f "config/${_}" } qw(authentication.pl console.conf lx-erp.conf lx-erp-local.conf);
  return unless @old_files;

  $::form->{title} = $::locale->text('Old configuration files');
  $::form->header;
  print $::form->parse_html_template('login_screen/old_configuration_files', { FILES => \@old_files });

  end_request();
}

sub end_request {
  die SL::Dispatcher->END_OF_REQUEST;
}

1;
