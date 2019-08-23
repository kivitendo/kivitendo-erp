package SL::System::TaskServer;

use strict;

use parent qw(Rose::Object);

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(last_command_output) ],
);

use File::Slurp;
use File::Spec::Functions qw(:ALL);
use File::Temp;
use Sys::Hostname ();

use SL::System::Process;

use constant {
  OK           =>  0,
  ERR_PID_FILE => -1,
  ERR_PROCESS  => -2,
};

use constant PID_BASE => "users/pid";

my $node_id;

sub status {
  my ($self) = @_;

  my $pid = $self->_read_pid;
  return ERR_PID_FILE unless $pid;

  return kill(0, $pid) ? OK : ERR_PROCESS;
}

sub is_running {
  my ($self) = @_;

  return $self->status == OK;
}

sub start {
  my ($self) = @_;

  return $self->_run_script_command('start');
}

sub start_if_not_running {
  my ($self) = @_;

  $self->start unless $self->is_running;
}

sub stop {
  my ($self) = @_;

  return $self->_run_script_command('stop');
}

sub wake_up {
  my ($self) = @_;

  my $pid = $self->_read_pid;
  return undef unless $pid;
  return kill('ALRM', $pid) ? 1 : undef;
}

sub node_id {
  return $node_id if $node_id;

  $node_id = ($::lx_office_conf{task_server} // {})->{node_id} || Sys::Hostname::hostname();

  return $node_id;
}

#
# private methods
#

sub _read_pid {
  my ($self) = @_;

  my $exe_dir = SL::System::Process->exe_dir;

  foreach my $conf (qw(kivitendo.conf lx_office.conf kivitendo.conf.default)) {
    my $pid_file_path = catfile(catdir($exe_dir, splitdir(PID_BASE())), "config.${conf}.pid");

    return join('', read_file($pid_file_path)) * 1 if -f $pid_file_path;
  }
}

sub _run_script_command {
  my ($self, $command) = @_;

  my $exe              = catfile(catdir(SL::System::Process->exe_dir, 'scripts'), 'task_server.pl');
  my $temp_file        = File::Temp->new;
  my $file_name        = $temp_file->filename;

  $temp_file->close;

  system "${exe} ${command} >> ${file_name} 2>&1";

  $self->last_command_output(read_file($file_name));

  return $? == 0 ? 1 : undef;
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::System::TaskServer - programmatic interface to the external task server component

=head1 SYNOPSIS

  # Create interface
  my $task_server = SL->TaskServer->new;

  # Start the server if it is not running
  if (!$task_server->is_running) {
    $task_server->start;
  }

  # Stop it if it is running
  if ($task_server->is_running) {
    $task_server->stop;
  }

=head1 FUNCTIONS

=over 4

=item C<is_running>

Returns C<trueish> if the server is running. This is done by using
Perl's C<kill> function with a "signal" of C<0> for the process ID
which in turn is read from the daemon's PID file.

If the PID file is not found or if C<kill> returns a non-successful
value then a C<falsish> value is returned.

=item C<last_command_output>

Returns the output of the last C<system> command executed, e.g. from a
call to L<start> or L<stop>.

=item C<start>

Starts the task server. Does not check whether or not it is running,
neither before not after trying to start it.

Returns C<1> if the system command C<./scripts/task_server.pl start>
exits with an exit code of C<0> and C<undef> otherwise.

The command's output can be queried with L<last_command_output>.

=item C<status>

Queries the task server status. Returns one of these values:

=over 4

=item *

C<OK> or C<0>: the task server is running and signals can be sent to
it.

=item *

C<ERR_PID_FILE> or C<-1>: the PID file could not be found or read

=item *

C<ERR_PROCESS> or C<-2>: the PID file could was found and read, but
it's not possible to send signals to the process, e.g. because it is
not running or owned by a different user ID.

=back

=item C<stop>

Stops the task server. Does not check whether or not it is running,
neither before not after trying to start it.

Returns C<1> if the system command C<./scripts/task_server.pl stop>
exits with an exit code of C<0> and C<undef> otherwise.

The command's output can be queried with L<last_command_output>.

=item C<wake_up>

Sends a signal to the task server process causing it to wake up and
process its job queue immediately.

Returns C<1> if the signal could be sent and C<undef> otherwise.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
