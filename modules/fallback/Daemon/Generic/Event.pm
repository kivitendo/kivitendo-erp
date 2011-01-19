
# Copyright (C) 2006, David Muir Sharnoff <muir@idiom.com>

package Daemon::Generic::Event;

use strict;
use warnings;
require Daemon::Generic;
require Event;
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
	my $self = shift;
	my $reload_event = Event->signal(
		signal	=> 'HUP',
		desc	=> 'reload on SIGHUP',
		prio	=> 6,
		cb	=> sub { 
			$self->gd_reconfig_event; 
			$self->{gd_timer}->cancel()
				if $self->{gd_timer};
			$self->gd_setup_timer();
		},
	);
	my $quit_event = Event->signal(
		signal	=> 'INT',
		cb	=> sub { $self->gd_quit_event; },
	);
}

sub gd_setup_timer
{
	my $self = shift;
	if ($self->can('gd_run_body')) {
		my $interval = ($self->can('gd_interval') && $self->gd_interval()) || 1;
		$self->{gd_timer} = Event->timer(
			cb		=> [ $self, 'gd_run_body' ],
			interval	=> $interval,
			hard		=> 0,
		);
	}
}

sub gd_run
{
	my $self = shift;
	$self->gd_setup_timer();
	Event::loop();
}

sub gd_quit_event
{
	my $self = shift;
	print STDERR "Quitting...\n";
	Event::unloop_all();
}

1;

=head1 NAME

 Daemon::Generic::Event - Generic daemon framework with Event.pm

=head1 SYNOPSIS

 use Daemon::Generic::Event;

 @ISA = qw(Daemon::Generic::Event);

 sub gd_preconfig {
	# stuff
 }

=head1 DESCRIPTION

Daemon::Generic::Event is a subclass of L<Daemon::Generic> that
predefines some methods:

=over 15

=item gd_run()

Setup a periodic callback to C<gd_run_body()> if there is a C<gd_run_body()>.
Call C<Event::loop()>.  

=item gd_setup_signals()

Bind SIGHUP to call C<gd_reconfig_event()>. 
Bind SIGINT to call C<gd_quit_event()>.

=back

To use Daemon::Generic::Event, you have to provide a C<gd_preconfig()>
method.   It can be empty if you have a C<gd_run_body()>.

Set up your own events in C<gd_preconfig()> and C<gd_postconfig()>.

If you have a C<gd_run_body()> method, it will be called once per
second or every C<gd_interval()> seconds if you have a C<gd_interval()>
method.  Unlike in L<Daemon::Generic::While1>, C<gd_run_body()> should
not include a call to C<sleep()>.

=head1 THANK THE AUTHOR

If you need high-speed internet services (T1, T3, OC3 etc), please 
send me your request-for-quote.  I have access to very good pricing:
you'll save money and get a great service.

=head1 LICENSE

Copyright(C) 2006 David Muir Sharnoff <muir@idiom.com>. 
This module may be used and distributed on the same terms
as Perl itself.

