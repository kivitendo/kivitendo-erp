package LXDebug;

use constant {
  NONE   => 0,
  INFO   => 1,
  DEBUG1 => 2,
  DEBUG2 => 3,

  FILE_TARGET   => 0,
  STDERR_TARGET => 1 };

use POSIX qw(strftime);

my $data_dumper_available;

BEGIN {
  eval("use Data::Dumper");
  $data_dumper_available = $@ ? 0 : 1;

  $global_level      = NONE;
  $global_trace_subs = 0;
}

sub new {
  my $type = shift;
  my $self = {};

  $self->{"calldepth"}  = 0;
  $self->{"file"}       = "/tmp/lx-office-debug.log";
  $self->{"target"}     = FILE_TARGET;
  $self->{"level"}      = 0;
  $self->{"trace_subs"} = 0;

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
  my ($self) = @_;

  if (!$self->{"trace_subs"} && !$global_trace_subs) {
    return;
  }

  my ($package, $filename, $line, $subroutine) = caller(1);
  my ($dummy1, $self_filename, $self_line) = caller(0);

  my $indent = "  " x $self->{"calldepth"};
  $self->{"calldepth"} += 1;

  if (!defined($package)) {
    $self->_write("enter_sub", $indent . "top-level?\n");
  } else {
    $self->_write("enter_sub",
                  $indent
                    . "${subroutine} in "
                    . "${self_filename}:${self_line} called from "
                    . "${filename}:${line}\n");
  }
}

sub leave_sub {
  my ($self) = @_;

  if (!$self->{"trace_subs"} && !$global_trace_subs) {
    return;
  }

  my ($package, $filename, $line, $subroutine) = caller(1);
  my ($dummy1, $self_filename, $self_line) = caller(0);

  $self->{"calldepth"} -= 1;
  my $indent = "  " x $self->{"calldepth"};

  if (!defined($package)) {
    $self->_write("leave_sub", $indent . "top-level?\n");
  } else {
    $self->_write("leave_sub",
            $indent . "${subroutine} in " . "${self_filename}:${self_line}\n");
  }
}

sub message {
  my ($self, $level, $message) = @_;
  my ($log_level) = $self->{"level"};

  if ($global_level && ($global_level > $log_level)) {
    $log_level = $global_level;
  }

  if ($log_level >= $level) {
    $self->_write(INFO == $level
                  ? "info"
                  : DEBUG1 == $level ? "debug1" : "debug2",
                  $message);
  }
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
  $self->{"trace_subs"} = 1;
}

sub disable_sub_tracing {
  my ($self) = @_;
  $self->{"trace_subs"} = 1;
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

1;
