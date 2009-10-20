package SL::Watchdog;

use Data::Dumper;

require Tie::Hash;

our @ISA = qw(Tie::StdHash);

use strict;

my %watched_variables;

sub STORE {
  my ($this, $key, $value) = @_;

  if (substr($key, 0, 10) eq "Watchdog::") {
    substr $key, 0, 10, "";
    foreach $key (split m/[ ,]/, $key) {
      $watched_variables{$key} = $value;
      if ($value) {
        $main::lxdebug->_write("WATCH", "Starting to watch '$key' with current value '$this->{$key}'");
      } else {
        $main::lxdebug->_write("WATCH", "Stopping to watch '$key'");
      }
    }

    return;
  }

  if ($watched_variables{$key}
        && ($this->{$key} ne $value)) {
    my $subroutine = (caller 1)[3];
    my ($self_filename, $self_line) = (caller)[1, 2];
    $main::lxdebug->_write("WATCH",
                           "Value of '$key' changed from '$this->{$key}' to '$value' "
                             . "in ${subroutine} at ${self_filename}:${self_line}");
    if ($watched_variables{$key} > 1) {
      my $level = 1;
      my ($dummy, $filename, $line);

      while (($dummy, $filename, $line, $subroutine) = caller $level) {
        $main::lxdebug->_write("WATCH", "  ${subroutine} from ${filename}:${line}");
        $level++;
      }
    }
  }

  $this->{$key} = $value;
}

sub DELETE {
  my ($this, $key) = @_;

  if ($watched_variables{$key} && ($this->{$key} ne "")) {
    my $subroutine = (caller 1)[3];
    my ($self_filename, $self_line) = (caller)[1, 2];
    $main::lxdebug->_write("WATCH",
                           "Value of '$key' changed from '$this->{$key}' to '' "
                             . "in ${subroutine} at ${self_filename}:${self_line}");
    if ($watched_variables{$key} > 1) {
      my $level = 1;
      my ($dummy, $filename, $line);

      while (($dummy, $filename, $line, $subroutine) = caller $level) {
        $main::lxdebug->_write("WATCH", "  ${subroutine} from ${filename}:${line}");
        $level++;
      }
    }
  }

  delete $this->{$key};
}

1;
