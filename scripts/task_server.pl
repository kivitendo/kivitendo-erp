#!/usr/bin/perl

use strict;

my $exe_dir;

BEGIN {
  use FindBin;

  unshift(@INC, $FindBin::Bin . '/../modules/override'); # Use our own versions of various modules (e.g. YAML).
  push   (@INC, $FindBin::Bin . '/..');                  # '.' will be removed from @INC soon.
  push   (@INC, $FindBin::Bin . '/../modules/fallback'); # Only use our own versions of modules if there's no system version.
}

use CGI qw( -no_xhtml);
use Cwd;
use Daemon::Generic;
use Data::Dumper;
use DateTime;
use English qw(-no_match_vars);
use File::Spec;
use List::MoreUtils qw(any);
use List::Util qw(first);
use POSIX qw(setuid setgid);
use SL::Auth;
use SL::DBUpgrade2;
use SL::DB::AuthClient;
use SL::DB::BackgroundJob;
use SL::BackgroundJob::ALL;
use SL::Form;
use SL::Helper::DateTime;
use SL::InstanceConfiguration;
use SL::LXDebug;
use SL::LxOfficeConf;
use SL::Locale;
use SL::Mailer;
use SL::System::Process;
use SL::System::TaskServer;
use Template;

our %lx_office_conf;

sub debug {
  return if !$lx_office_conf{task_server}->{debug};
  $::lxdebug->message(LXDebug::DEBUG1(), join(' ', "task server:", @_));
}

sub enabled_clients {
  return SL::DB::Manager::AuthClient->get_all(where => [ '!task_server_user_id' => undef ]);
}

sub initialize_kivitendo {
  my ($client) = @_;

  chdir $exe_dir;

  package main;

  $::lxdebug       = LXDebug->new;
  $::locale        = Locale->new($::lx_office_conf{system}->{language});
  $::form          = Form->new;
  $::auth          = SL::Auth->new;

  return if !$client;

  $::auth->set_client($client->id);

  $::form->{__ERROR_HANDLER} = sub { die @_ };

  $::instance_conf = SL::InstanceConfiguration->new;
  $::request       = SL::Request->new(
    cgi            => CGI->new({}),
    layout         => SL::Layout::None->new,
  );

  die 'cannot reach auth db'               unless $::auth->session_tables_present;

  $::auth->restore_session;
  $::auth->create_or_refresh_session;

  my $login = $client->task_server_user->login;

  die "cannot find user $login"            unless %::myconfig = $::auth->read_user(login => $login);
  die "cannot find locale for user $login" unless $::locale   = Locale->new($::myconfig{countrycode} || $::lx_office_conf{system}->{language});
}

sub cleanup_kivitendo {
  eval { SL::DB->client->dbh->rollback; };

  $::auth->save_session;
  $::auth->expire_sessions;
  $::auth->reset;

  $::form     = undef;
  $::myconfig = ();
  $::request  = undef;
  $::auth     = undef;
}

sub clean_before_sleeping {
  SL::DBConnect::Cache->disconnect_all_and_clear;
  SL::DB->db_cache->clear;

  File::Temp::cleanup();
}

sub drop_privileges {
  my $user = $lx_office_conf{task_server}->{run_as};
  return unless $user;

  my ($uid, $gid);
  while (my @details = getpwent()) {
    next unless $details[0] eq $user;
    ($uid, $gid) = @details[2, 3];
    last;
  }
  endpwent();

  if (!$uid) {
    print "Error: Cannot drop privileges to ${user}: user does not exist\n";
    exit 1;
  }

  if (!setgid($gid)) {
    print "Error: Cannot drop group privileges to ${user} (group ID $gid): $!\n";
    exit 1;
  }

  if (!setuid($uid)) {
    print "Error: Cannot drop user privileges to ${user} (user ID $uid): $!\n";
    exit 1;
  }
}

sub notify_on_failure {
  my (%params) = @_;

  my $cfg = $lx_office_conf{'task_server/notify_on_failure'} || {};

  return if any { !$cfg->{$_} } qw(send_email_to email_from email_subject email_template);

  chdir $exe_dir;

  return debug("Template " . $cfg->{email_template} . " missing!") unless -f $cfg->{email_template};

  my $email_to = $cfg->{send_email_to};
  if ($email_to !~ m{\@}) {
    my %user = $::auth->read_user(login => $email_to);
    return debug("cannot find user for notification $email_to") unless %user;

    $email_to = $user{email};
    return debug("user for notification " . $user{login} . " doesn't have a valid email address") unless $email_to =~ m{\@};
  }

  my $template  = Template->new({
    INTERPOLATE => 0,
    EVAL_PERL   => 0,
    ABSOLUTE    => 1,
    CACHE_SIZE  => 0,
    ENCODING    => 'utf8',
  });

  return debug("Could not create Template instance") unless $template;

  $params{client} = $::auth->client;

  eval {
    my $body;
    $template->process($cfg->{email_template}, \%params, \$body);

    Mailer->new(
      from         => $cfg->{email_from},
      to           => $email_to,
      subject      => $cfg->{email_subject},
      content_type => 'text/plain',
      charset      => 'utf-8',
      message      => $body,
    )->send;

    1;
  } or do {
    debug("Sending a failure notification failed with an exception: $@");
  };
}

sub gd_preconfig {
  my $self = shift;

  SL::LxOfficeConf->read($self->{configfile});

  die "Missing section [task_server] in config file" unless $lx_office_conf{task_server};

  if ($lx_office_conf{task_server}->{login} || $lx_office_conf{task_server}->{client}) {
    print STDERR <<EOT;
ERROR: The keys 'login' and/or 'client' are still present in the
section [task_server] in the configuration file. These keys are
deprecated. You have to configure the clients for which to run the
task server in the web admin interface.

The task server will refuse to start until the keys have been removed from
the configuration file.
EOT
    exit 2;
  }

  initialize_kivitendo();

  my $dbupdater_auth = SL::DBUpgrade2->new(form => $::form, auth => 1)->parse_dbupdate_controls;
  if ($dbupdater_auth->unapplied_upgrade_scripts($::auth->dbconnect)) {
    print STDERR <<EOT;
The authentication database requires an upgrade. Please login to
kivitendo's administration interface in order to apply it. The task
server cannot start until the upgrade has been applied.
EOT
    exit 2;
  }

  drop_privileges();

  return ();
}

sub run_once_for_all_clients {
  initialize_kivitendo();

  my $clients = enabled_clients();

  foreach my $client (@{ $clients }) {
    debug("Running for client ID " . $client->id . " (" . $client->name . ")");

    my $ok = eval {
      initialize_kivitendo($client);

      my $jobs = SL::DB::Manager::BackgroundJob->get_all_need_to_run;

      if (@{ $jobs }) {
        debug(" Executing the following jobs: " . join(' ', map { $_->package_name } @{ $jobs }));
      } else {
        debug(" No jobs to execute found");
      }

      foreach my $job (@{ $jobs }) {
        # Provide fresh global variables in case legacy code modifies
        # them somehow.
        initialize_kivitendo($client);

        my $history = $job->run;

        debug("   Executed job " . $job->package_name .
              "; result: " . (!$history ? "no return value" : $history->has_failed ? "failed" : "succeeded") .
              ($history && $history->has_failed ? "; error: " . $history->error_col : ""));

        notify_on_failure(history => $history) if $history && $history->has_failed;
      }

      1;
    };

    if (!$ok) {
      my $error = $EVAL_ERROR;
      debug("Exception during execution: ${error}");
      notify_on_failure(exception => $error);
    }

    cleanup_kivitendo();
  }
}

sub gd_run {
  while (1) {
    $SIG{'ALRM'} = 'IGNORE';

    run_once_for_all_clients();

    debug("Sleeping");

    clean_before_sleeping();

    my $seconds = 60 - (localtime)[0];
    if (!eval {
      $SIG{'ALRM'} = sub {
        $SIG{'ALRM'} = 'IGNORE';
        debug("Got woken up by SIGALRM");
        die "Alarm!\n"
      };
      sleep($seconds < 30 ? $seconds + 60 : $seconds);
      1;
    }) {
      die $@ unless $@ eq "Alarm!\n";
    }
  }
}

$exe_dir = SL::System::Process->exe_dir;
chdir($exe_dir) || die "Cannot change directory to ${exe_dir}\n";

mkdir SL::System::TaskServer::PID_BASE() if !-d SL::System::TaskServer::PID_BASE();

my $file = first { -f } ("${exe_dir}/config/kivitendo.conf", "${exe_dir}/config/lx_office.conf", "${exe_dir}/config/kivitendo.conf.default");

die "No configuration file found." unless $file;

$file = File::Spec->abs2rel(Cwd::abs_path($file), Cwd::abs_path($exe_dir));

newdaemon(configfile => $file,
          progname   => 'kivitendo-background-jobs',
          pidbase    => SL::System::TaskServer::PID_BASE() . '/',
          );

1;
