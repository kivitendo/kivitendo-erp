
# Copyright (C) 2006, David Muir Sharnoff <perl@dave.sharnoff.org>

package Daemon::Generic;

use strict;
use warnings;
require Exporter;
require POSIX;
use Getopt::Long;
use File::Slurp;
use File::Flock;
our @ISA = qw(Exporter);
our @EXPORT = qw(newdaemon);

our $VERSION = 0.71;

our $force_quit_delay = 15;
our $package = __PACKAGE__;
our $caller;

sub newdaemon
{
	my (%args) = @_;
	my $pkg = $caller || caller() || 'main';

	my $foo = bless {}, $pkg;

	unless ($foo->isa($package)) {
		no strict qw(refs);
		my $isa = \@{"${pkg}::ISA"};
		unshift(@$isa, $package);
	}

	bless $foo, 'This::Package::Does::Not::Exist';
	undef $foo;

	new($pkg, %args);
}

sub new
{
	my ($pkg, %args) = @_;

	if ($pkg eq __PACKAGE__) {
		$pkg = caller() || 'main';
	}

	srand(time ^ ($$ << 5))
		unless $args{no_srand};

	my $av0 = $0;
	$av0 =~ s!/!/.!g;

	my $self = {
		gd_args		=> \%args,
		gd_pidfile	=> $args{pidfile},
		gd_logpriority	=> $args{logpriority},
		gd_progname	=> $args{progname}
					? $args{progname}
					: $0,
		gd_pidbase	=> $args{pidbase}
					? $args{pidbase}
					: ($args{progname} 
						? "/var/run/$args{progname}"
						: "/var/run/$av0"),
		gd_foreground	=> $args{foreground} || 0,
		configfile	=> $args{configfile}
					? $args{configfile}
					: ($args{progname}
						? "/etc/$args{progname}.conf"
						: "/etc/$av0"),
		debug		=> $args{debug} || 0,
	};
	bless $self, $pkg;

	$self->gd_getopt;
	$self->gd_parse_argv;

	my $do = $self->{do} = $ARGV[0];

	$self->gd_help		if $do eq 'help';
	$self->gd_version	if $do eq 'version';
	$self->gd_install	if $do eq 'install';
	$self->gd_uninstall	if $do eq 'uninstall';

	$self->gd_pidfile unless $self->{gd_pidfile};

	my %newconfig = $self->gd_preconfig;

	$self->{gd_pidfile} = $newconfig{pidfile} if $newconfig{pidfile};

	print "Configuration looks okay\n" if $do eq 'check';

	my $pidfile = $self->{gd_pidfile};
	my $killed = 0;
	my $locked = 0;
	if (-e $pidfile) {
		if ($locked = lock($pidfile, undef, 'nonblocking')) {
			# old process is dead
			if ($do eq 'status') {
			    print "$0 dead\n";
			    exit 1;
			}
		} else {
			sleep(2) if -M $pidfile < 2/86400;
			my $oldpid = read_file($pidfile);
			chomp($oldpid);
			if ($oldpid) {
				if ($do eq 'stop' or $do eq 'restart') {
					$killed = $self->gd_kill($oldpid);
					$locked = lock($pidfile);
					if ($do eq 'stop') {
						unlink($pidfile);
						exit;
					}
				} elsif ($do eq 'reload') {
					if (kill(1,$oldpid)) {
						print "Requested reconfiguration\n";
						exit;
					} else {
						print "Kill failed: $!\n";
					}
				} elsif ($do eq 'status') {
					if (kill(0,$oldpid)) {
						print "$0 running - pid $oldpid\n";
						$self->gd_check($pidfile, $oldpid);
						exit 0;
					} else {
						print "$0 dead\n";
						exit 1;
					}
				} elsif ($do eq 'check') {
					if (kill(0,$oldpid)) {
						print "$0 running - pid $oldpid\n";
						$self->gd_check($pidfile, $oldpid);
						exit;
					} 
				} elsif ($do eq 'start') {
					print "\u$self->{gd_progname} is already running (pid $oldpid)\n";
					exit; # according to LSB, this is no error
				}
			} else {
				$self->gd_error("Pid file $pidfile is invalid but locked, exiting\n");
			}
		}
	} else {
		$locked = lock($pidfile, undef, 'nonblocking') 
			or die "Could not lock pid file $pidfile: $!";
	}

	if ($do eq 'reload' || $do eq 'stop' || $do eq 'check' || ($do eq 'restart' && ! $killed)) {
		print "No $0 running\n";
	}

	if ($do eq 'stop') {
		unlink($pidfile);
		exit;
	}

	if ($do eq 'status') {
		print "Unused\n";
		exit 3;
	}

	if ($do eq 'check') {
		$self->gd_check($pidfile);
		exit 
	}

	unless ($do eq 'reload' || $do eq 'restart' || $do eq 'start') {
		$self->gd_other_cmd($do, $locked);
	}

	unless ($self->{gd_foreground}) {
		$self->gd_daemonize;
	}

	$locked or lock($pidfile, undef, 'nonblocking') 
		or die "Could not lock PID file $pidfile: $!";

	write_file($pidfile, "$$\n");

	print STDERR "Starting up...\n";

	$self->gd_postconfig(%newconfig);

	$self->gd_setup_signals;

	$self->gd_run;

	unlink($pidfile);
	exit(0);
}

sub gd_check {}

sub gd_more_opt { return() }

sub gd_getopt
{
	my $self = shift;
	Getopt::Long::Configure("auto_version");
	GetOptions(
		'configfile=s'	=> \$self->{configfile},
		'foreground!'	=> \$self->{gd_foreground},
		'debug!'	=> \$self->{debug},
		$self->{gd_args}{options}
			? %{$self->{gd_args}{options}}
			: (),
		$self->gd_more_opt(),
	) or exit($self->gd_usage());

	if (@ARGV < ($self->{gd_args}{minimum_args} || 1)) {
		exit($self->gd_usage());
	}
	if (@ARGV > ($self->{gd_args}{maximum_args} || 1)) {
		exit($self->gd_usage());
	}
}

sub gd_parse_argv { }

sub gd_help
{
	my $self = shift;
	exit($self->gd_usage($self->{gd_args}));
}

sub gd_version
{
	my $self = shift;
	no strict qw(refs);
	my $v = $self->{gd_args}{version} 
		|| ${ref($self)."::VERSION"} 
		|| $::VERSION 
		|| $main::VERSION 
		|| "?";
	print "$self->{gd_progname} - version $v\n";;
	exit;
} 

sub gd_pidfile
{
	my $self = shift;
	my $x = $self->{configfile};
	$x =~ s!/!.!g;
	$self->{gd_pidfile} = "$self->{gd_pidbase}$x.pid";
}

sub gd_other_cmd
{
	my $self = shift;
	$self->gd_usage;
	exit(1);
}

sub gd_redirect_output
{
	my $self = shift;
	return if $self->{gd_foreground};
	my $logname = $self->gd_logname;
	my $p = $self->{gd_logpriority} ? "-p $self->{gd_logpriority}" : "";
	open(STDERR, "|logger $p -t '$logname'") or (print "could not open stderr: $!" && exit(1));
	close(STDOUT);
	open(STDOUT, ">&STDERR") or die "redirect STDOUT -> STDERR: $!";
	close(STDIN);
}

sub gd_daemonize
{
	my $self = shift;
	print "Starting $self->{gd_progname} server\n";
	$self->gd_redirect_output();
	my $pid;
	POSIX::_exit(0) if $pid = fork;
	die "Could not fork: $!" unless defined $pid;
	POSIX::_exit(0) if $pid = fork;
	die "Could not fork: $!" unless defined $pid;

	POSIX::setsid();
	select(STDERR);
	$| = 1;
	print "Sucessfully daemonized\n";
}

sub gd_logname
{
	my $self = shift;
	return $self->{gd_progname}."[$$]";
}

sub gd_reconfig_event
{
	my $self = shift;
	print STDERR "Reconfiguration requested\n";
	$self->gd_postconfig($self->gd_preconfig());
}

sub gd_quit_event
{
	my $self = shift;
	print STDERR "Quitting...\n";
	exit(0);
}

sub gd_setup_signals
{
	my $self = shift;
	$SIG{INT} = sub { $self->gd_quit_event() };
	$SIG{HUP} = sub { $self->gd_reconfig_event() };
}

sub gd_run { die "must defined gd_run()" }

sub gd_error
{
	my $self = shift;
	my $e = shift;
	my $do = $self->{do};
	if ($do && $do eq 'stop') {
		warn $e;
	} else {
		die $e;
	}
}

sub gd_flags_more { return () }

sub gd_flags
{
	my $self = shift;
	return (
		'-c file'	=> "Specify configuration file (instead of $self->{configfile})",
		'-f'		=> "Run in the foreground (don't detach)",
		$self->gd_flags_more
	);
}

sub gd_commands_more { return () }

sub gd_commands
{
	my $self = shift;
	return (
		start		=> "Starts a new $self->{gd_progname} if there isn't one running already",
		stop		=> "Stops a running $self->{gd_progname}",
		reload		=> "Causes a running $self->{gd_progname} to reload it's config file.  Starts a new one if none is running.",
		restart		=> "Stops a running $self->{gd_progname} if one is running.  Starts a new one.",
		$self->gd_commands_more(),
		($self->gd_can_install()
			? ('install' => "Setup $self->{gd_progname} to run automatically after reboot")
			: ()),
		($self->gd_can_uninstall()
			? ('uninstall' => "Do not run $self->{gd_progname} after reboots")
			: ()),
		check		=> "Check the configuration file and report the daemon state",
		help		=> "Display this usage info",
		version		=> "Display the version of $self->{gd_progname}",
	)
}

sub gd_positional_more { return() }

sub gd_alts
{
	my $offset = shift;
	my @results;
	for (my $i = $offset; $i <= $#_; $i += 2) {
		push(@results, $_[$i]);
	}
	return @results;
}

sub gd_usage
{
	my $self = shift;

	require Text::Wrap;
	import Text::Wrap;

	my $col = 15;

	my @flags = $self->gd_flags;
	my @commands = $self->gd_commands;
	my @positional = $self->gd_positional_more;

	my $summary = "Usage: $self->{gd_progname} ";
	my $details = '';
	for my $i (gd_alts(0, @flags)) {
		$summary .= "[ $i ] ";
	}
	$summary .= "{ ";
	$summary .= join(" | ", gd_alts(0, @commands));
	$summary .= " } ";
	$summary .= join(" ", gd_alts(0, @positional));

	my (@all) = (@flags, @commands, @positional);
	while (@all) {
		my ($key, $desc) = splice(@all, 0, 2);
		local($Text::Wrap::columns) = 79;
		$details .= wrap(
			sprintf(" %-${col}s ", $key),
			" " x ($col + 2),
			$desc);
		$details .= "\n";
	}

	print "$summary\n$details";
	return 0;
}

sub gd_install_pre {}
sub gd_install_post {}

sub gd_can_install
{
	my $self = shift;
	require File::Basename;
	my $basename = File::Basename::basename($0);
	if (
		-x "/usr/sbin/update-rc.d"
		&& 
		-x $0
		&& 
		$0 !~ m{^(?:/usr|/var)?/tmp/}
		&&
		eval { symlink("",""); 1 }
		&& 
		-d "/etc/init.d"
		&&
		! -e "/etc/init.d/$basename"
	) {
		return sub {
			$self->gd_install_pre("update-rc.d");
			require Cwd;
			my $abs_path = Cwd::abs_path($0);
			symlink($abs_path, "/etc/init.d/$basename")
				or die "Install failed: symlink /etc/init.d/$basename -> $abs_path: $!\n";
			print "+ /usr/sbin/update-rc.d $basename defaults\n";
			system("/usr/sbin/update-rc.d", $basename, "defaults");
			my $exit = $? >> 8;
			$self->gd_install_post("update-rc.d");
			exit($exit) if $exit;
		};
	}

	return 0;
}

sub gd_install
{
	my $self = shift;
	my $ifunc = $self->gd_can_install();
	die "Install command not supported\n" unless $ifunc;
	&$ifunc($self);
	exit(0);
}

sub gd_uninstall_pre {}
sub gd_uninstall_post {}

sub gd_can_uninstall
{
	my $self = shift;
	require File::Basename;
	my $basename = File::Basename::basename($0);
	require Cwd;
	my $abs_path = Cwd::abs_path($0) || 'no abs path';
	my $link = readlink("/etc/init.d/$basename") || 'no link';
	if (
		$link eq $abs_path
		&& 
		-x "/usr/sbin/update-rc.d"
	) {
		return sub {
			$self->gd_uninstall_pre("update-rc.d");
			unlink("/etc/init.d/$basename");
			print "+ /usr/sbin/update-rc.d $basename remove\n";
			system("/usr/sbin/update-rc.d", $basename, "remove");
			my $exit = $? >> 8;
			$self->gd_uninstall_post("update-rc.d");
			exit($exit) if $exit;
		}
	}
	return 0;
}

sub gd_uninstall
{
	my $self = shift;
	my $ufunc = $self->gd_can_uninstall();
	die "Cannot uninstall\n" unless $ufunc;
	&$ufunc($self);
	exit(0);
}

sub gd_kill
{
	my ($self, $pid) = @_;

	my $talkmore = 0;
	my $killed = 0;
	if (kill(0, $pid)) {
		$killed = 1;
		kill(2,$pid);
		print "Killing $pid\n";
		my $t = time;
		sleep(1) if kill(0, $pid);
		if ($force_quit_delay && kill(0, $pid)) {
			print "Waiting for $pid to die...\n";
			$talkmore = 1;
			while(kill(0, $pid) && time - $t < $force_quit_delay) {
				sleep(1);
			}
		}
		if (kill(15, $pid)) {
			print "Killing $pid with -TERM...\n";
			if ($force_quit_delay) {
				while(kill(0, $pid) && time - $t < $force_quit_delay * 2) {
					sleep(1);
				}
			} else {
				sleep(1) if kill(0, $pid);
			}
		}
		if (kill(9, $pid)) {
			print "Killing $pid with -KILL...\n";
			my $k9 = time;
			my $max = $force_quit_delay * 4;
			$max = 60 if $max < 60;
			while(kill(0, $pid)) {
				if (time - $k9 > $max) {
					print "Giving up on $pid ever dying.\n";
					exit(1);
				}
				print "Waiting for $pid to die...\n";
				sleep(1);
			}
		}
		print "Process $pid is gone\n" if $talkmore;
	} else {
		print "Process $pid no longer running\n";
	}
	return $killed;
}

sub gd_preconfig { die "gd_preconfig() must be redefined"; }

sub gd_postconfig { }


1;
