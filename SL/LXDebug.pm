package LXDebug;

use constant NONE   => 0;
use constant INFO   => 1;
use constant DEBUG1 => 2;
use constant DEBUG2 => 4;
use constant QUERY  => 8;
use constant TRACE  => 16;
use constant ALL    => 31;

use constant FILE_TARGET   => 0;
use constant STDERR_TARGET => 1;

use POSIX qw(strftime);

my $data_dumper_available;

BEGIN {
  eval("use Data::Dumper");
  $data_dumper_available = $@ ? 0 : 1;

  $global_level      = NONE;
}

sub new {
  my $type = shift;
  my $self = {};

  $self->{"calldepth"}  = 0;
  $self->{"file"}       = "/tmp/lx-office-debug.log";
  $self->{"target"}     = FILE_TARGET;
  $self->{"level"}      = 0;
  $self->{"watchedvars"} = {};

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

  check_watched_form_variables();

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

  $self->check_watched_form_variables();

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

sub message {
  my ($self, $level, $message) = @_;

  $self->check_watched_form_variables();
  $self->_write(level2string($level), $message) if (($self->{"level"} | $global_level) & $level || !$level);
}

sub dump {
  my ($self, $level, $name, $variable) = @_;

  if ($data_dumper_available) {
    $self->message($level, "dumping ${name}:\n" . Dumper($variable));
  } else {
    $self->message($level,
                   "dumping ${name}: Data::Dumper not available; "
                     . "variable cannot be dumped");
  }
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
  join '/', qw(info debug1 debug2 query trace)[ grep { (reverse split //, sprintf "%05b", $_[0])[$_] } 0..4 ]
}

sub watch_form_variable {
  my ($self, $var) = @_;

  $self->{"watchedvars"}->{$var} = $main::form->{$var};
  $self->_write("WATCH", "Adding \$form->{$var} with current value \"$main::form->{$var}\"");
}

sub check_watched_form_variables {
  my ($self) = @_;

  return unless $main::form;

  foreach my $var (sort(keys(%{ $self->{"watchedvars"} }))) {
    if ($main::form->{$var} ne $self->{"watchedvars"}->{$var}) {
      $self->_write("WATCH", "Variable \$form->{$var} changed from \"" .
                    $self->{"watchedvars"}->{$var} . "\" to \"" .
                    $main::form->{$var} . "\"");
      $self->{"watchedvars"}->{$var} = $main::form->{$var};
    }
  }
}

1;
