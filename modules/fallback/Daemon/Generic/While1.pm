# Copyright (C) 2006, David Muir Sharnoff <muir@idiom.com>

package Daemon::Generic::While1;

use strict;
use warnings;
use Carp;
require Daemon::Generic;
require POSIX;
require Exporter;

our @ISA = qw(Daemon::Generic Exporter);
our @EXPORT = @Daemon::Generic::EXPORT;
our $VERSION = 0.3;

sub newdaemon
{
	local($Daemon::Generic::caller) = caller() || 'main';
	local($Daemon::Generic::package) = __PACKAGE__;
	Daemon::Generic::newdaemon(@_);
}

sub gd_setup_signals
{
	my ($self) = @_;
	$SIG{HUP} = sub {
		$self->{gd_sighup} = time;
	};
	my $child;
	$SIG{INT} = sub {
		$self->{gd_sigint} = time;
		#
		# We'll be getting a SIGTERM in a bit if we're not dead, so let's use it.
		#
		$SIG{TERM} = sub {
			$self->gd_quit_event(); 
			kill(15, $child) if $child;  # if we're still alive, let's stay that way
		};
	};
}

sub gd_sleep
{
	my ($self, $period) = @_;
	croak "Sleep period must be defined" unless defined $period;
	my $hires;
	if ($period*1000 != int($period*1000)) {
		$hires = 1;
		require Time::HiRes;
		import Time::HiRes qw(time sleep);
	}
	my $t = time;
	while (time - $t < $period) {
		return if $self->{gd_sigint};
		return if $self->{gd_sighup};
		if ($hires) {
			my $p = (time - $t < 1)
				? time - $t
				: 1;
			sleep($p);
		} else {
			sleep(1);
		}
	}
}

sub gd_run
{
	my ($self) = @_;
	while(1) {
		if ($self->{gd_sigint}) {
			$self->{gd_sigint} = 0;
			$self->gd_quit_event();
		}

		if ($self->{gd_sighup}) {
			$self->{gd_sighup} = 0;
			$self->gd_reconfig_event();
		}

		$self->gd_run_body();
	}
}

sub gd_reconfig_event
{
	my $self = shift;
	print STDERR "Reconfiguration requested\n";
	$self->gd_postconfig($self->gd_preconfig());
}

sub gd_quit_event
{
	print STDERR "Quitting...\n";
	exit(0);
}


sub gd_run_body { die "must override gd_run_body()" }

1;

=head1 NAME

 Daemon::Generic::While1 - Daemon framework with default while(1) loop

=head1 SYNOPSIS

 @ISA = qw(Daemon::Generic::While1);

 sub gd_run_body {
	# stuff
 }

=head1 DESCRIPTION

This is a slight variation on L<Daemon::Generic>: a default
C<gd_run()> provided.  It has a while(1) loop that calls 
C<gd_run_body()> over and over.  It checks for reconifg and
and terminate events and only actions them between calls
to C<gd_run_body()>. 

Terminate events will be forced through after 
C<$Daemon::Generic::force_quit_delay> seconds if
C<gd_run_body()> doesn't return quickly enough.

=head1 SUBCLASS METHODS REQUIRD

The following method is required to be overridden to subclass
Daemon::Generic::While1:

=over 15

=item gd_run_body()

This method will be called over and over.  This method should
include a call to C<sleep(1)> (or a bit more).  Reconfig events
will not interrupt it.  Quit events will only interrupt it 
after 15 seconds.  

=back

=head1 ADDITIONAL METHODS

The following additional methods are available for your use
(as compared to L<Daemon::Generic>):

=over 15

=item gd_sleep($period)

This will sleep for C<$period> seconds but in one-second
intervals so that if a SIGINT or SIGHUP arrives the sleep
period can end more quickly.

Using this makes it safe for C<gd_run_body()> to sleep for
longer than C<$Daemon::Generic::force_quit_delay> seconds 
at a time.

=back

=head1 ADDITIONAL MEMBER DATA

The following additional bits of member data are defined:

=over 15

=item gd_sigint

The time at which an (unprocessed) SIGINT was recevied.

=item gd_sighup

The time at which an (unprocessed) SIGHUP was recevied.

=back

=head1 THANK THE AUTHOR

If you need high-speed internet services (T1, T3, OC3 etc), please 
send me your request-for-quote.  I have access to very good pricing:
you'll save money and get a great service.

=head1 LICENSE

Copyright(C) 2006 David Muir Sharnoff <muir@idiom.com>. 
This module may be used and distributed on the same terms
as Perl itself.

