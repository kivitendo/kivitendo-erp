package LXDebug;

use constant NONE               =>  0;
use constant INFO               =>  1;
use constant DEBUG1             =>  1 << 1;
use constant DEBUG2             =>  1 << 2;
use constant QUERY              =>  1 << 3;
use constant TRACE              =>  1 << 4;
use constant BACKTRACE_ON_ERROR =>  1 << 5;
use constant ALL                => (1 << 6) - 1;
use constant DEVEL              => INFO | QUERY | TRACE | BACKTRACE_ON_ERROR;

use constant FILE_TARGET   => 0;
use constant STDERR_TARGET => 1;

use POSIX qw(strftime);

use YAML;

use strict;

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
  my ($self, $level, $message) = @_;

  $self->_write(level2string($level), $message) if (($self->{"level"} | $global_level) & $level || !$level);
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
