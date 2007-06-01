package LXDebug;

use constant NONE               => 0;
use constant INFO               => 1;
use constant DEBUG1             => 2;
use constant DEBUG2             => 4;
use constant QUERY              => 8;
use constant TRACE              => 16;
use constant BACKTRACE_ON_ERROR => 32;
use constant ALL                => 63;

use constant FILE_TARGET   => 0;
use constant STDERR_TARGET => 1;

use POSIX qw(strftime);

use YAML;

my $data_dumper_available;

our $global_level;
our $watch_form;

BEGIN {
  eval("use Data::Dumper");
  $data_dumper_available = $@ ? 0 : 1;

  $global_level      = NONE;
  $watch_form        = 0;
}

sub new {
  my $type = shift;
  my $self = {};

  $self->{"calldepth"}  = 0;
  $self->{"file"}       = "/tmp/lx-office-debug.log";
  $self->{"target"}     = FILE_TARGET;
  $self->{"level"}      = 0;

  while ($_[0]) {
    $self->{ $_[0] } = $_[1];
    shift;
    shift;
  }

  bless($self, $type);
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
  my ($self, $level) = @_;
  $level *= 1;

  return 1 unless ($global_level & TRACE);          # ignore if traces aren't active
  return 1 if $level && !($global_level & $level);  # ignore if level of trace isn't active

  my ($package, $filename, $line, $subroutine) = caller(1);
  my ($dummy1, $self_filename, $self_line) = caller(0);

  my $indent = " " x $self->{"calldepth"}++;

  if (!defined($package)) {
    $self->_write('sub' . $level, $indent . "\\ top-level?\n");
  } else {
    $self->_write('sub' . $level, $indent
                    . "\\ ${subroutine} in "
                    . "${self_filename}:${self_line} called from "
                    . "${filename}:${line}\n");
  }
  return 1;
}

sub leave_sub {
  my ($self, $level) = @_;
  $level *= 1;

  return 1 unless ($global_level & TRACE);           # ignore if traces aren't active
  return 1 if $level && !($global_level & $level);   # ignore if level of trace isn't active

  my ($package, $filename, $line, $subroutine) = caller(1);
  my ($dummy1, $self_filename, $self_line) = caller(0);

  my $indent = " " x --$self->{"calldepth"};

  if (!defined($package)) {
    $self->_write('sub' . $level, $indent . "/ top-level?\n");
  } else {
    $self->_write('sub' . $level, $indent . "/ ${subroutine} in " . "${self_filename}:${self_line}\n");
  }
  return 1;
}

sub show_backtrace {
  my ($self) = @_;

  return 1 unless ($global_level & BACKTRACE_ON_ERROR);

  $self->message(BACKTRACE_ON_ERROR, "Starting full caller dump:");
  my $level = 0;
  while (my ($dummy, $filename, $line, $subroutine) = caller $level) {
    $self->message(BACKTRACE_ON_ERROR, "  ${subroutine} from ${filename}:${line}");
    $level++;
  }

  return 1;
}

sub message {
  my ($self, $level, $message) = @_;

  $self->_write(level2string($level), $message) if (($self->{"level"} | $global_level) & $level || !$level);
}

sub dump {
  my ($self, $level, $name, $variable) = @_;

  if ($data_dumper_available) {
    my $dumper = Data::Dumper->new([$variable]);
    $dumper->Sortkeys(1);
    $self->message($level, "dumping ${name}:\n" . $dumper->Dump());
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

sub enable_sub_tracing {
  my ($self) = @_;
  $self->{level} | TRACE;
}

sub disable_sub_tracing {
  my ($self) = @_;
  $self->{level} & ~ TRACE;
}

sub _write {
  my ($self, $prefix, $message) = @_;
  my $date = strftime("%Y-%m-%d %H:%M:%S $$ ${prefix}: ", localtime(time()));
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
  # use $_[0] as a bit mask and return levelstrings separated by /
  join '/', qw(info debug1 debug2 query trace error_call_trace)[ grep { (reverse split //, sprintf "%05b", $_[0])[$_] } 0..5 ]
}

1;
