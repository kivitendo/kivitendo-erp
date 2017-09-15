package LXDebug;

use constant NONE               =>  0;
use constant INFO               =>  1;
use constant DEBUG1             =>  1 << 1;
use constant DEBUG2             =>  1 << 2;
use constant QUERY              =>  1 << 3;
use constant TRACE              =>  1 << 4;
use constant BACKTRACE_ON_ERROR =>  1 << 5;
use constant REQUEST_TIMER      =>  1 << 6;
use constant REQUEST            =>  1 << 7;
use constant WARN               =>  1 << 8;
use constant TRACE2             =>  1 << 9;
use constant SHOW_CALLER        =>  1 << 10;
use constant ALL                => (1 << 11) - 1;
use constant DEVEL              => INFO | DEBUG1 | QUERY | TRACE | BACKTRACE_ON_ERROR | REQUEST_TIMER;

use constant FILE_TARGET   => 0;
use constant STDERR_TARGET => 1;

use Data::Dumper;
use POSIX qw(strftime getpid);
use Scalar::Util qw(blessed refaddr weaken);
use Time::HiRes qw(gettimeofday tv_interval);
use YAML;
use SL::Request ();

use strict;
use utf8;

my ($text_diff_available);

our $global_level = NONE();
our $watch_form   = 0;
our $file_name;

sub new {
  my $type = shift;
  my $self = {};

  _init_globals_from_config();

  $self->{"calldepth"}  = 0;
  $self->{"file"}       = $file_name || "/tmp/lx-office-debug.log";
  $self->{"target"}     = FILE_TARGET;
  $self->{"level"}      = 0;

  while ($_[0]) {
    $self->{ $_[0] } = $_[1];
    shift;
    shift;
  }

  bless($self, $type);
}

my $globals_inited_from_config;
sub _init_globals_from_config {
  return if $globals_inited_from_config;
  $globals_inited_from_config = 1;

  my $cfg = $::lx_office_conf{debug} || {};

  $global_level = NONE() if $cfg->{global_level} =~ /NONE/;
  foreach my $level (grep { $_} split(m/\s+/, $cfg->{global_level})) {
    $global_level |= eval "${level}()";
  }

  $watch_form = $cfg->{watch_form};
  $file_name  = $cfg->{file_name} || "/tmp/lx-office-debug.log";
}

sub set_target {
  my ($self, $target, $file) = @_;

  if ((FILE_TARGET == $target) && $file) {
    $self->{"file"}   = $file;
    $self->{"target"} = FILE_TARGET;

  } elsif (STDERR_TARGET == $target) {
    $self->{"target"} = STDERR_TARGET;
  }
}

sub enter_sub {
  my $self  = shift;
  my $level = shift || 0;

  return 1 unless ($global_level & TRACE);          # ignore if traces aren't active
  return 1 if $level && !($global_level & TRACE2);  # ignore if level of trace isn't active

  my ($package, $filename, $line, $subroutine) = caller(1);
  my ($dummy1, $self_filename, $self_line) = caller(0);

  my $indent = " " x $self->{"calldepth"}++;
  my $time = $self->get_request_time || '';

  if (!defined($package)) {
    $self->_write('sub' . $level, $indent . "\\ $time top-level?\n");
  } else {
    $self->_write('sub' . $level, $indent
                    . "\\ $time ${subroutine} in "
                    . "${self_filename}:${self_line} called from "
                    . "${filename}:${line}\n");
  }
  return 1;
}

sub leave_sub {
  my $self  = shift;
  my $level = shift || 0;

  return 1 unless ($global_level & TRACE);           # ignore if traces aren't active
  return 1 if $level && !($global_level & TRACE2);   # ignore if level of trace isn't active

  my ($package, $filename, $line, $subroutine) = caller(1);
  my ($dummy1, $self_filename, $self_line) = caller(0);

  my $indent = " " x --$self->{"calldepth"};
  my $time = $self->want_request_timer ? $self->get_request_time || '' : '';

  if (!defined($package)) {
    $self->_write('sub' . $level, $indent . "/ $time top-level?\n");
  } else {
    $self->_write('sub' . $level, $indent . "/ $time ${subroutine} in " . "${self_filename}:${self_line}\n");
  }
  return 1;
}

sub show_backtrace {
  my ($self, $force) = @_;

  return 1 unless ($force || ($global_level & BACKTRACE_ON_ERROR));

  $self->message(0, "Starting full caller dump:");
  my $level = 0;
  while (my ($dummy, $filename, $line, $subroutine) = caller $level) {
    $self->message(0, "  ${subroutine} from ${filename}:${line}");
    $level++;
  }

  return 1;
}

sub message {
  no warnings;
  my ($self, $level, $message) = @_;

  my $show_caller = ($level | $global_level) & SHOW_CALLER();
  $level         &= ~SHOW_CALLER();

  $self->_write(level2string($level), $message, show_caller => $show_caller) if (($self->{"level"} | $global_level) & $level || !$level);
}
sub warn {
  no warnings;
  my ($self, $message) = @_;
  $self->message(WARN, $message);
}

sub clone_for_dump {
  my ($src, $dumped) = @_;

  return undef if !defined($src);

  $dumped ||= {};
  my $addr  = refaddr($src);

  return $dumped->{$addr} if $dumped->{$addr // ''};


  if (blessed($src) && $src->can('as_debug_info')) {
    $dumped->{$addr} = $src->as_debug_info;

  } elsif (ref($src) eq 'ARRAY') {
    $dumped->{$addr} = [];

    foreach my $entry (@{ $src }) {
      my $exists = !!$dumped->{refaddr($entry) // ''};
      push @{ $dumped->{$addr} }, clone_for_dump($entry, $dumped);

      weaken($dumped->{$addr}->[-1]) if $exists;

    }

  } elsif (ref($src) =~ m{^(?:HASH|Form|SL::.+)$}) {
    $dumped->{$addr} = {};

    foreach my $key (keys %{ $src }) {
      my $exists             = !!$dumped->{refaddr($src->{$key}) // ''};
      $dumped->{$addr}->{$key} = clone_for_dump($src->{$key}, $dumped);

      weaken($dumped->{$addr}->{$key}) if $exists;
    }
  }

  return $dumped->{$addr} // "$src";
}

sub dump {
  my ($self, $level, $name, $variable, %options) = @_;

  $variable  = clone_for_dump($variable);
  my $dumper = Data::Dumper->new([$variable]);
  $dumper->Sortkeys(1);
  $dumper->Indent(2);
  $dumper->$_($options{$_}) for keys %options;
  my $output = $dumper->Dump();
  $self->message($level, "dumping ${name}:\n" . $output);

  return $output;
}

sub dump_yaml {
  my ($self, $level, $name, $variable) = @_;

  $self->message($level, "dumping ${name}:\n" . YAML::Dump($variable));
}

sub dump_sql_result {
  my ($self, $level, $prefix, $results) = @_;

  if (!$results || !scalar @{ $results }) {
    $self->message($level, "Empty result set");
    return;
  }

  my %column_lengths = map { $_, length $_ } keys %{ $results->[0] };

  foreach my $row (@{ $results }) {
    map { $column_lengths{$_} = length $row->{$_} if (length $row->{$_} > $column_lengths{$_}) } keys %{ $row };
  }

  my @sorted_names = sort keys %column_lengths;
  my $format       = join '|', map { '%' . $column_lengths{$_} . 's' } @sorted_names;

  $prefix .= ' ' if $prefix;

  $self->message($level, $prefix . sprintf($format, @sorted_names));
  $self->message($level, $prefix . join('+', map { '-' x $column_lengths{$_} } @sorted_names));

  foreach my $row (@{ $results }) {
    $self->message($level, $prefix . sprintf($format, map { $row->{$_} } @sorted_names));
  }
  $self->message($level, $prefix . sprintf('(%d row%s)', scalar @{ $results }, scalar @{ $results } > 1 ? 's' : ''));
}

sub show_diff {
  my ($self, $level, $item1, $item2, %params) = @_;

  if (!$self->_load_text_diff) {
    $self->warn("Perl module Text::Diff is not available");
    return;
  }

  my @texts = map { ref $_ ? YAML::Dump($_) : $_ } ($item1, $item2);

  $self->message($level, Text::Diff::diff(\$texts[0], \$texts[1], \%params));
}

sub _load_text_diff {
  $text_diff_available = eval("use Text::Diff (); 1;") ? 1 : 0 unless defined $text_diff_available;
  return $text_diff_available;
}

sub enable_sub_tracing {
  my ($self) = @_;
  $global_level |= TRACE;
}

sub disable_sub_tracing {
  my ($self) = @_;
  $global_level &= ~ TRACE;
}

sub is_tracing_enabled {
  my ($self) = @_;
  return $global_level & TRACE;
}

sub _write {
  no warnings;
  my ($self, $prefix, $message, %options) = @_;

  my @prefixes = ($prefix);

  if ($options{show_caller}) {
    my $level = 1;
    while (1) {
      my ($package, $filename, $line, $subroutine) = caller($level);

      if (($filename // '') =~ m{LXDebug\.pm$}) {
        $level++;
        next;
      }

      push @prefixes, "${filename}:${line}";
      last;
    }
  }

  $prefix = join ' ', grep { $_ } @prefixes;

  my @now  = gettimeofday();
  my $date = strftime("%Y-%m-%d %H:%M:%S." . sprintf('%03d', int($now[1] / 1000)) . " $$ [" . getpid() . "] ${prefix}: ", localtime($now[0]));
  local *FILE;

  chomp($message);
  $self->_write_raw("${date}${message}\n");
}

sub _write_raw {
  my ($self, $message) = @_;
  local *FILE;
  if ((FILE_TARGET == $self->{"target"})
      && open(FILE, ">>", $self->{"file"})) {
    binmode FILE, ":utf8";
    print FILE $message;
    close FILE;

  } elsif (STDERR_TARGET == $self->{"target"}) {
    print STDERR $message;
  }
}

sub level2string {
  no warnings;
  # use $_[0] as a bit mask and return levelstrings separated by /
  join '/', qw(info debug1 debug2 query trace error_call_trace request_timer WARNING)[ grep { (reverse split //, sprintf "%08b", $_[0])[$_] } 0..7 ]
}

sub begin_request {
  my $self = shift;
  return 1 unless want_request_timer();
  $self->set_request_timer;
}

sub end_request {
  my ($self, %params) = @_;
  return 1 unless want_request_timer();

  $self->_write("time", sprintf('%f (%s/%s)', $self->get_request_time, $params{script_name}, $params{action}));

  $self->{calldepth} = 0;
}

sub log_time {
  my ($self, @slurp) = @_;
  return 1 unless want_request_timer();

  my $now                    = $self->get_request_time;

  return 1 unless $now;

  my $diff                   = $self->{previous_log_time} ? int((($now - ($self->{previous_log_time} // 0)) * 10_000 + 5) / 10) : $now * 10_0000 + 5;
  $self->{previous_log_time} = $now;

  $self->_write("time", "${now}s Δ ${diff}ms" . (@slurp ? " (@slurp)" : ''));
}

sub get_request_time {
  my $self = shift;
  return $self->want_request_timer && $self->{request_start} ? tv_interval($self->{request_start}) : undef;
}

sub set_request_timer {
  my $self = shift;
  $self->{request_start} = [gettimeofday];
}

sub want_request_timer {
  $global_level & REQUEST_TIMER;
}

sub file {
  @_ == 2 ? $_[0]->{file} = $_[1] : $_[0]->{file};
}

sub _by_name {
  my ($self, $level) = @_;
  my $meth = $self->can(uc $level);
  die 'unknown level' unless $meth;
  $meth->();
}

sub level_by_name {
  my ($self, $level, $val) = @_;
  if (@_ == 3) {
    $global_level |=  $self->_by_name($level) if  $val;
    $global_level &= ~$self->_by_name($level) if !$val;
  }
  return $global_level & $self->_by_name($level);
}

sub is_request_logging_enabled {
  my ($self) = @_;
  return $global_level & REQUEST;
}

sub add_request_params {
  my ($self, $key, $value) = @_;
  return unless $self->is_request_logging_enabled;
  return if $key =~ /password/;

  push @{ $::request->{debug}{PARAMS} ||= [] }, [ $key => $value ];
}

sub log_request {
  my ($self, $type, $controller, $action) = @_;
  return unless $self->is_request_logging_enabled;

  my $session_id = $::auth->create_or_refresh_session;

  my $template = <<EOL;
*************************************
 $ENV{REQUEST_METHOD} $ENV{SCRIPT_NAME}    $session_id ($::myconfig{login})
   routing: $type, controller: $controller, action: $action
EOL

  $self->_write('Request', $template);

  my $params = join "\n   ", map {
    "$_->[0] = $_->[1]"
  } @{ $::request->{debug}{PARAMS} || [] };

  $self->_write_raw(<<EOL);

 Params
   $params
EOL
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

LXDebug - kivitendo debugging facilities

=head1 SYNOPSIS

This module provides functions for debugging kivitendo. An instance is
always created as the global variable C<$::lxdebug> at the earliest
possible moment.

Debugging is mostly logging of information. Each log function has a
I<level> and an I<object> to be logged. The configuration file as well
as this module's functions determine which levels get logged, and
which file they're logged to.

=head1 LOG LEVELS

The available log levels are:

=over 4

=item C<NONE>

Always output the message regardless of the active levels. Only use
this temporarily.

=item C<INFO>

Informational, not an error, more important than C<DEBUG1>.

=item C<DEBUG1>

Important debugging information.

=item C<DEBUG2>

Less important debugging information that occurs often and spams the
log.

=item C<QUERY>

Log all queries executed by the L<SL::DBUtils> utility methods.

=item C<TRACE>

Log sub calls and exits via the L<enter_sub>/L<leave_sub> functions,
but only if they're called with a log level that is falsish
(e.g. none, C<undef>, 0).

=item C<TRACE2>

Log sub calls and exits via the L<enter_sub>/L<leave_sub> functions
even if they're called with a log level of 2. Will only have an effect
if C<TRACE> is set as well.

=item C<BACKTRACE_ON_ERROR>

Log a stack trace when an error is output.

=item C<REQUEST_TIMER>

Log each request's total execution time when it finishes.

=item C<WARN>

Important warnings.

=item C<ALL>

All of the above.

=item C<DEVEL>

Shortcut for C<INFO | QUERY | TRACE | BACKTRACE_ON_ERROR | REQUEST_TIMER>.

=back

=head1 CONFIGURATION

C<SL::LXDebug> gets its configuration from the C<[debug]> section of
the C<config/kivitendo.conf> configuration file. The available options
are:

=over 4

=item C<global_level>

A string of log level names that should be activated by
default. Multiple log levels are separated by C<|>.

=item C<watch_form>

A boolean (C<1> or C<0>). Turns on the C<$::form> watch facility. If
this is enabled then any key inside C<$::form> can be monitored for
changes. For example:

  # Start watching 'action'
  $::form->{"Watchdog::action"} = 1;
  # Stop watching 'invtotal'
  $::form->{"Watchdog::invtotal"} = 0;

A log message is written when the watchdog is enabled for a variable
and for each subsequent change. The log message includes the place
(file name and line number) of the instruction changing the key.

Note that this entails a performance penalty. Also only the keys
themselves are monitored -- not the references they point to. E.g. the
following would not trigger a change:

  $::form->{"Watchdog::some_hash"} = 1;
  # Does not trigger:
  $::form->{some_hash}->{some_value} = 42;
  # This does trigger:
  $::form->{some_hash} = { something => 'else' };

=item C<keep_temp_files>

A boolean (C<1> or C<0>). If turned on then certain temporary files
are not removed but kept in the C<users> directory. These include the
temporary files used during printing, e.g. LaTeX files.

=item C<file_name>

The path and file name of the debug log file. Must be a location
writeable by the web server process.

=back

=head1 FUNCTIONS

=over 4

=item C<enter_sub [$level]>

=item C<leave_sub [$level]>

Pairs of these can be put near the beginning/end of a sub. They'll
cause a trace to be written to the log file if the C<TRACE> level is
active.

If C<$level> is given then the log messages will only be logged if the
global log level C<TRACE2> is active as well.

=item C<enable_sub_tracing>

=item C<disable_sub_tracing>

Enables/disables sub tracing with L<enter_sub>/L<leave_sub> temporarily.

=item C<is_tracing_enabled>

Returns whether or not the C<TRACE> debug level is active.

=item C<show_backtrace [$force]>

Logs a stack backtrace if C<$force> is trueish or if the log level
C<BACKTRACE_ON_ERROR> is active.

=item C<message $level, $message>

Logs the message C<$message> if the log level C<$level> is active. The
message will be prefixed with a word describing the log level.

=item C<warn $message>

Equivalent to C<message WARN(), $message>.

=item C<dump $level, $name, $variable>

Logs a message that the variable named C<$name> is dumped along with a
dump of the variable C<$variable> created by the L<Data::Dumper>
module. Will log a warning if said module is not available. Will only
log if the log level C<$level> is active.

=item C<dump_yaml $level, $name, $variable>

Logs a message that the variable named C<$name> is dumped along with a
dump of the variable C<$variable> created by the C<YAML> module. Will
only log if the log level C<$level> is active.

=item C<dump_sql $level, $prefix, $results>

Dumps the result of an SQL query in tabular form. Will only log if the
log level C<$level> is active.

=item C<show_diff $level, $item1, $item2, %params>

Logs a unified diff of the textual representations of C<$item1> and
C<$item2>. Requires the module L<Text::Diff> and logs a warning if
said module is not available.

C<$item1> and C<$item2> are dumped via L<YAML::Dumper> before diffing
if they're non-scalars.

Will only log if the log level C<$level> is active.

=item C<begin_request>

=item C<end_request>

=item C<log_time>

=item C<set_request_timer>

=item C<want_request_timer>

Internal functions used to log the current request's exeuction time
(log level C<REQUEST_TIMER>).

=item C<get_request_time>

Returns the current request's elapsed execution time in seconds.

=item C<file [$file_name]>

Sets and/or returns the file name this instance logs to.

=item C<level_by_name $level[, $val]>

Returns if a log level C<$level> is active. C<$level> is a string
representation, not one of the level constants from above.

If C<$val> is given then said level will be turned on (if C<$val> is
trueish) or off (if C<$val> is falsish).

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>,
Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
