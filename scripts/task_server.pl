#!/usr/bin/perl

use strict;

my $exe_dir;

BEGIN {
  use FindBin;
  use lib "$FindBin::Bin/..";

  use SL::System::Process;
  $exe_dir = SL::System::Process::exe_dir;

  unshift @INC, "${exe_dir}/modules/override"; # Use our own versions of various modules (e.g. YAML).
  push    @INC, "${exe_dir}/modules/fallback"; # Only use our own versions of modules if there's no system version.
  unshift @INC, $exe_dir;

  chdir($exe_dir) || die "Cannot change directory to ${exe_dir}\n";
}

use CGI qw( -no_xhtml);
use Cwd;
use Daemon::Generic;
use Data::Dumper;
use DateTime;
use English qw(-no_match_vars);
use File::Spec;
use List::Util qw(first);
use POSIX qw(setuid setgid);
use SL::Auth;
use SL::DB::BackgroundJob;
use SL::BackgroundJob::ALL;
use SL::Form;
use SL::Helper::DateTime;
use SL::InstanceConfiguration;
use SL::LXDebug;
use SL::LxOfficeConf;
use SL::Locale;
use SL::System::TaskServer;

our %lx_office_conf;

sub debug {
  return if !$lx_office_conf{task_server}->{debug};
  $::lxdebug->message(0, @_);
}

sub lxinit {
  my $login  = $lx_office_conf{task_server}->{login};
  my $client = $lx_office_conf{task_server}->{client};

  package main;

  $::lxdebug       = LXDebug->new;
  $::locale        = Locale->new($::lx_office_conf{system}->{language});
  $::form          = Form->new;
  $::auth          = SL::Auth->new;
  die "No client configured or no client found with the name/ID '$client'" unless $::auth->set_client($client);
  $::instance_conf = SL::InstanceConfiguration->new;
  $::request       = { cgi => CGI->new({}) };

  die 'cannot reach auth db'               unless $::auth->session_tables_present;

  $::auth->restore_session;

  require "bin/mozilla/common.pl";

  die "cannot find user $login"            unless %::myconfig = $::auth->read_user(login => $login);
  die "cannot find locale for user $login" unless $::locale   = Locale->new('de');
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

sub gd_preconfig {
  my $self = shift;

  SL::LxOfficeConf->read($self->{configfile});

  die "Missing section [task_server] in config file"                 unless $lx_office_conf{task_server};
  die "Missing key 'login' in section [task_server] in config file"  unless $lx_office_conf{task_server}->{login};
  die "Missing key 'client' in section [task_server] in config file" unless $lx_office_conf{task_server}->{client};

  drop_privileges();
  lxinit();

  return ();
}

sub gd_run {
  while (1) {
    my $ok = eval {
      debug("Retrieving jobs");

      my $jobs = SL::DB::Manager::BackgroundJob->get_all_need_to_run;

      debug("  Found: " . join(' ', map { $_->package_name } @{ $jobs })) if @{ $jobs };

      foreach my $job (@{ $jobs }) {
        # Provide fresh global variables in case legacy code modifies
        # them somehow.
        $::locale = Locale->new($::lx_office_conf{system}->{language});
        $::form   = Form->new;

        chdir $exe_dir;

        $job->run;
      }

      1;
    };

    debug("Exception during execution: ${EVAL_ERROR}") if !$ok;
    debug("Sleeping");

    my $seconds = 60 - (localtime)[0];
    if (!eval {
      local $SIG{'ALRM'} = sub {
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

chdir $exe_dir;

mkdir SL::System::TaskServer::PID_BASE() if !-d SL::System::TaskServer::PID_BASE();

my $file = first { -f } ("${exe_dir}/config/kivitendo.conf", "${exe_dir}/config/lx_office.conf", "${exe_dir}/config/kivitendo.conf.default");

die "No configuration file found." unless $file;

$file = File::Spec->abs2rel(Cwd::abs_path($file), Cwd::abs_path($exe_dir));

newdaemon(configfile => $file,
          progname   => 'kivitendo-background-jobs',
          pidbase    => SL::System::TaskServer::PID_BASE() . '/',
          );

1;
