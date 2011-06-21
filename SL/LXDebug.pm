package LXDebug;

use constant NONE               =>  0;
use constant INFO               =>  1;
use constant DEBUG1             =>  1 << 1;
use constant DEBUG2             =>  1 << 2;
use constant QUERY              =>  1 << 3;
use constant TRACE              =>  1 << 4;
use constant BACKTRACE_ON_ERROR =>  1 << 5;
use constant REQUEST_TIMER      =>  1 << 6;
use constant WARN               =>  1 << 7;
use constant ALL                => (1 << 8) - 1;
use constant DEVEL              => INFO | QUERY | TRACE | BACKTRACE_ON_ERROR | REQUEST_TIMER;

use constant FILE_TARGET   => 0;
use constant STDERR_TARGET => 1;

use POSIX qw(strftime getppid);
use Time::HiRes qw(gettimeofday tv_interval);
use YAML;

use strict;

my ($data_dumper_available, $text_diff_available);

our $global_level;
our $watch_form;
our $file_name;

BEGIN {
  eval("use Data::Dumper");
  $data_dumper_available = $@ ? 0 : 1;

  $global_level      = NONE;
  $watch_form        = 0;
}

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
  return 1 if $level && !($global_level & $level);  # ignore if level of trace isn't active

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
  return 1 if $level && !($global_level & $level);   # ignore if level of trace isn't active

  my ($package, $filename, $line, $subroutine) = caller(1);
  my ($dummy1, $self_filename, $self_line) = caller(0);

  my $indent = " " x --$self->{"calldepth"};
  my $time = $self->want_request_timer ? $self->get_request_time : '';

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

  $self->message(BACKTRACE_ON_ERROR, "Starting full caller dump:");
  my $level = 0;
  while (my ($dummy, $filename, $line, $subroutine) = caller $level) {
    $self->message(BACKTRACE_ON_ERROR, "  ${subroutine} from ${filename}:${line}");
    $level++;
  }

  return 1;
}

sub message {
  no warnings;
  my ($self, $level, $message) = @_;

  $self->_write(level2string($level), $message) if (($self->{"level"} | $global_level) & $level || !$level);
}
sub warn {
  no warnings;
  my ($self, $message) = @_;
  $self->message(WARN, $message);
}

sub dump {
  my ($self, $level, $name, $variable) = @_;

  if ($data_dumper_available) {
    my $password;
    if ($variable && ('Form' eq ref $variable) && defined $variable->{password}) {
      $password             = $variable->{password};
      $variable->{password} = 'X' x 8;
    }

    my $dumper = Data::Dumper->new([$variable]);
    $dumper->Sortkeys(1);
    $self->message($level, "dumping ${name}:\n" . $dumper->Dump());

    $variable->{password} = $password if (defined $password);

    # Data::Dumper does not reset the iterator belonging to this hash
    # if 'Sortkeys' is true. Therefore clear the iterator manually.
    # See "perldoc -f each".
    if ($variable && (('HASH' eq ref $variable) || ('Form' eq ref $variable))) {
      keys %{ $variable };
    }

  } else {
    $self->message($level,
                   "dumping ${name}: Data::Dumper not available; "
                     . "variable cannot be dumped");
  }
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
  my ($self, $prefix, $message) = @_;
  my $date = strftime("%Y-%m-%d %H:%M:%S $$ [" . getppid() . "] ${prefix}: ", localtime(time()));
  local *FILE;

  chomp($message);

  if ((FILE_TARGET == $self->{"target"})
      && open(FILE, ">>" . $self->{"file"})) {
    print(FILE "${date}${message}\n");
    close(FILE);

  } elsif (STDERR_TARGET == $self->{"target"}) {
    print(STDERR "${date}${message}\n");
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
  my $self = shift;
  return 1 unless want_request_timer();
  $self->_write("time", $self->get_request_time);

  $self->{calldepth} = 0;
}

sub log_time {
  my $self = shift;
  return 1 unless want_request_timer();
  $self->_write("time", $self->get_request_time);
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

1;
